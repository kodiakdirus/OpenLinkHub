"""Asynchronous Qt transport for OpenLinkHub's versioned client contract."""

from __future__ import annotations

import json
from typing import Any, Callable, Mapping
from urllib.parse import urlsplit

from PyQt6.QtCore import (
    QDateTime,
    QObject,
    QTimer,
    QUrl,
    pyqtProperty,
    pyqtSignal,
    pyqtSlot,
)
from PyQt6.QtNetwork import (
    QNetworkAccessManager,
    QNetworkReply,
    QNetworkRequest,
)

from .models import (
    ApiEnvelope,
    ContractSnapshot,
    LegacySnapshot,
    PayloadError,
    VersionedDocument,
)


JsonCallback = Callable[[dict[str, Any] | None, str | None], None]


class BackendController(QObject):
    """Own the loopback connection and normalized QML state."""

    modeChanged = pyqtSignal()
    connectionChanged = pyqtSignal()
    dataChanged = pyqtSignal()
    refreshChanged = pyqtSignal()
    apiCallCountChanged = pyqtSignal()
    commandChanged = pyqtSignal()
    lightingRuntimeChanged = pyqtSignal()

    def __init__(
        self,
        *,
        endpoint: str = "http://127.0.0.1:27003",
        refresh_interval_ms: int = 3000,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._validate_endpoint(endpoint)
        self._endpoint = endpoint.rstrip("/")
        self._manager = QNetworkAccessManager(self)
        self._timer = QTimer(self)
        self._timer.setInterval(max(1000, refresh_interval_ms))
        self._timer.timeout.connect(self.refresh)

        self._lighting_runtime: dict[str, Any] = {}
        self._runtime_refreshing = False
        self._runtime_epoch = 0
        self._runtime_cancel_pending = False
        self._runtime_lease_id = ""
        self._mode = "demo"
        self._connection_state = "demo"
        self._status_text = "Demo data"
        self._error_message = ""
        self._last_updated = ""
        self._contract_version = ""
        self._contract_source = "Demo data"
        self._contract_revision = 0
        self._telemetry_revision = 0
        self._snapshot_etag = ""
        self._refreshing = False
        self._api_call_count = 0
        self._command_busy = False
        self._command_status = "idle"
        self._command_message = ""
        self._refresh_after_command = False
        self._generation = 0
        self._refresh_cycle = 0
        self._devices: list[dict[str, Any]] = []
        self._lighting_profiles: dict[str, Any] = {}
        self._telemetry: dict[str, Any] = {}
        self._overview_metrics: list[dict[str, Any]] = []
        self._cooling_zones: list[dict[str, Any]] = []
        self._zone_values: dict[str, str] = {}

    @staticmethod
    def _valid_runtime_state(state: Any) -> bool:
        if not isinstance(state, dict):
            return False
        revision = state.get("revision")
        if type(revision) is not int or not 0 <= revision <= 2**53 - 1:
            return False
        if state.get("mode") not in {"unknown", "software-live", "hardware-memory", "transitioning"}:
            return False
        if state.get("renderer") not in {"running", "stalled", "stopped", "unavailable"}:
            return False
        members, operations = state.get("members"), state.get("operations")
        if not isinstance(members, list) or not all(isinstance(item, str) and item for item in members):
            return False
        if not isinstance(operations, list) or not all(isinstance(item, str) and item in {"recover", "identify"} for item in operations):
            return False
        lease = state.get("lease")
        return lease is None or (isinstance(lease, dict) and all(isinstance(lease.get(key), str) and lease[key] for key in ("id", "deviceId", "expiresAt", "status")))

    @pyqtProperty("QVariantMap", notify=lightingRuntimeChanged)
    def lightingRuntime(self) -> dict[str, Any]:
        return self._lighting_runtime

    @pyqtSlot()
    def refreshLightingRuntime(self) -> None:
        if self._mode != "live" or self._runtime_refreshing:
            return
        self._runtime_refreshing = True
        generation = self._generation
        epoch = self._runtime_epoch

        def accept(payload: dict[str, Any] | None, error: str | None) -> None:
            self._runtime_refreshing = False
            if generation != self._generation or epoch != self._runtime_epoch:
                return
            if error or not payload or payload.get("apiVersion") != "1.0" or payload.get("kind") != "lighting-runtime" or not self._valid_runtime_state(payload.get("data")):
                self._lighting_runtime = {"mode": "unknown", "renderer": "unavailable", "operations": []}
            else:
                self._lighting_runtime = payload["data"]
                if not self._lighting_runtime.get("lease"):
                    self._runtime_lease_id = ""
            self.lightingRuntimeChanged.emit()

        self._get_document("/api/v1/lighting/runtime", accept)

    def _runtime_command(self, action: str, device_id: str = "") -> None:
        if self._mode != "live":
            return
        if self._command_busy:
            if action == "cancel":
                self._runtime_cancel_pending = True
            return
        state = self._lighting_runtime
        if action != "cancel" and action not in state.get("operations", []):
            self._set_command(False, "rejected", "Refresh lighting status; this operation is not published.")
            return
        if action == "identify" and device_id not in state.get("members", []):
            self._set_command(False, "rejected", "This device is not a published Cluster member.")
            return
        payload: dict[str, Any] = {"expectedRevision": state.get("revision", 0)}
        if action == "identify":
            payload.update(deviceId=device_id, durationMs=3000)
            if self._runtime_lease_id:
                payload["leaseId"] = self._runtime_lease_id
        if action == "cancel":
            if not self._runtime_lease_id:
                return
            payload = {"leaseId": self._runtime_lease_id}
        self._runtime_epoch += 1
        generation = self._generation
        self._set_command(True, "working", "Updating temporary lighting control…")

        def accept(document: dict[str, Any] | None, error: str | None) -> None:
            if generation != self._generation:
                return
            self._runtime_epoch += 1
            if error or not document or document.get("apiVersion") != "1.0" or document.get("kind") != "lighting-runtime-result" or not isinstance(document.get("data"), dict):
                self._set_command(False, "unverified", error or "The lighting result could not be verified.")
            else:
                result = document["data"]
                self._set_command(False, str(result.get("status", "unverified")), str(result.get("message", "Lighting outcome unverified.")))
                observed = result.get("state")
                lease = observed.get("lease") if isinstance(observed, dict) else None
                lease = lease if isinstance(lease, dict) else {}
                if action == "identify" and result.get("status") == "identifying":
                    self._runtime_lease_id = str(lease.get("id", ""))
                elif action == "cancel" and result.get("status") == "restored":
                    self._runtime_lease_id = ""
            if self._runtime_cancel_pending:
                self._runtime_cancel_pending = False
                self.cancelLightingIdentification()
            self.refreshLightingRuntime()

        path = "/api/v1/lighting/recover" if action == "recover" else "/api/v1/lighting/identify"
        self._put_document(path, payload, accept, method=b"DELETE" if action == "cancel" else b"PUT")

    @pyqtSlot()
    def recoverLighting(self) -> None:
        self._runtime_command("recover")

    @pyqtSlot(str)
    def identifyLighting(self, device_id: str) -> None:
        self._runtime_command("identify", device_id)

    @pyqtSlot()
    def cancelLightingIdentification(self) -> None:
        self._runtime_command("cancel")

    @staticmethod
    def _validate_endpoint(endpoint: str) -> None:
        parsed = urlsplit(endpoint)
        if parsed.scheme != "http":
            raise ValueError("Phase 1 supports plain HTTP on loopback only.")
        if parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
            raise ValueError("Phase 1 refuses non-loopback OpenLinkHub endpoints.")
        if parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("The OpenLinkHub endpoint must be a simple loopback URL.")

    @pyqtProperty(str, notify=modeChanged)
    def mode(self) -> str:
        return self._mode

    @pyqtProperty(str, notify=connectionChanged)
    def connectionState(self) -> str:
        return self._connection_state

    @pyqtProperty(str, notify=connectionChanged)
    def statusText(self) -> str:
        return self._status_text

    @pyqtProperty(str, notify=connectionChanged)
    def errorMessage(self) -> str:
        return self._error_message

    @pyqtProperty(str, notify=connectionChanged)
    def lastUpdated(self) -> str:
        return self._last_updated

    @pyqtProperty(str, notify=connectionChanged)
    def contractVersion(self) -> str:
        return self._contract_version

    @pyqtProperty(str, notify=connectionChanged)
    def contractSource(self) -> str:
        return self._contract_source

    @pyqtProperty(int, notify=connectionChanged)
    def contractRevision(self) -> int:
        return self._contract_revision

    @pyqtProperty(int, notify=connectionChanged)
    def telemetryRevision(self) -> int:
        return self._telemetry_revision

    @pyqtProperty(bool, notify=connectionChanged)
    def connected(self) -> bool:
        return self._connection_state in {"connected", "degraded"}

    @pyqtProperty(bool, notify=refreshChanged)
    def refreshing(self) -> bool:
        return self._refreshing

    @pyqtProperty(int, notify=apiCallCountChanged)
    def apiCallCount(self) -> int:
        return self._api_call_count

    @pyqtProperty(bool, notify=commandChanged)
    def commandBusy(self) -> bool:
        return self._command_busy

    @pyqtProperty(str, notify=commandChanged)
    def commandStatus(self) -> str:
        return self._command_status

    @pyqtProperty(str, notify=commandChanged)
    def commandMessage(self) -> str:
        return self._command_message

    @pyqtProperty("QVariantList", notify=dataChanged)
    def devices(self) -> list[dict[str, Any]]:
        return self._devices

    @pyqtProperty(bool, notify=dataChanged)
    def lightingAssignmentAvailable(self) -> bool:
        for device in self._devices:
            for tab in device.get("tabs", []):
                editor = tab.get("lightingEditor", {})
                for target in editor.get("targets", []):
                    if "assign-profile" in target.get("operations", []):
                        return True
        return False

    @pyqtProperty(bool, notify=dataChanged)
    def lightingOwnershipAvailable(self) -> bool:
        return any(
            "change-controller" in self._lighting_ownership(device.get("id", "")).get("operations", [])
            for device in self._devices
        )

    @pyqtProperty("QVariantMap", notify=dataChanged)
    def telemetry(self) -> dict[str, Any]:
        return self._telemetry

    @pyqtProperty("QVariantList", notify=dataChanged)
    def overviewMetrics(self) -> list[dict[str, Any]]:
        return self._overview_metrics

    @pyqtProperty("QVariantList", notify=dataChanged)
    def coolingZones(self) -> list[dict[str, Any]]:
        return self._cooling_zones

    @pyqtProperty("QVariantMap", notify=dataChanged)
    def zoneValues(self) -> dict[str, str]:
        return self._zone_values

    @pyqtSlot(str)
    def setMode(self, mode: str) -> None:
        normalized = mode.strip().casefold()
        if normalized not in {"demo", "live"} or normalized == self._mode:
            return
        self._lighting_runtime = {}
        self._runtime_lease_id = ""
        self.lightingRuntimeChanged.emit()
        self._mode = normalized
        self.modeChanged.emit()

        if normalized == "demo":
            self._timer.stop()
            self._generation += 1
            self._set_refreshing(False)
            self._set_contract("", "Demo data", 0, 0)
            self._snapshot_etag = ""
            self._refresh_after_command = False
            self._set_command(False, "idle", "")
            self._set_connection("demo", "Demo data", "")
            return

        # Force a fresh device-filtered lighting library whenever Live mode is
        # entered, while keeping the last good data visible during the request.
        self._refresh_cycle = 0
        self._timer.start()
        self.refresh()

    @pyqtSlot()
    def refresh(self) -> None:
        if self._mode != "live" or self._refreshing:
            return

        self._generation += 1
        generation = self._generation
        self._set_refreshing(True)
        # A routine poll is not a connectivity transition. Keep the last known
        # state visible so the application chrome does not flash every cycle.
        if not self._devices or self._connection_state in {"demo", "offline"}:
            self._set_connection("connecting", "Connecting…", "")

        self._get_document(
            "/api/v1/snapshot",
            lambda payload, error: self._accept_contract(
                generation,
                payload,
                error,
            ),
            etag=self._snapshot_etag,
        )

    @pyqtSlot(str, str, str)
    def updateLabel(self, device_id: str, target_id: str, label: str) -> None:
        if self._command_busy:
            return
        if self._mode != "live" or self._contract_version != "1.0":
            self._set_command(
                False,
                "rejected",
                "Label editing requires an OpenLinkHub service with the versioned write contract.",
            )
            return
        cleaned = label.strip()
        if len(cleaned) > 64:
            self._set_command(False, "rejected", "Use no more than 64 characters.")
            return

        self._set_command(True, "working", "Applying label…")
        self._put_document(
            "/api/v1/devices/label",
            {
                "expectedRevision": self._contract_revision,
                "deviceId": device_id,
                "targetId": target_id,
                "label": cleaned,
            },
            self._accept_label_command,
        )

    @pyqtSlot(str, str, str)
    def assignLightingProfile(
        self,
        device_id: str,
        target_id: str,
        profile_id: str,
    ) -> None:
        if self._command_busy:
            return
        if self._mode != "live" or self._contract_version != "1.0":
            self._set_command(
                False,
                "rejected",
                "Lighting assignment requires the versioned write contract.",
            )
            return
        target = self._lighting_target(device_id, target_id)
        if target is None or "assign-profile" not in target.get("operations", []):
            self._set_command(
                False,
                "rejected",
                "That lighting target does not publish profile assignment.",
            )
            return
        supported = target.get("supportedProfileIds", [])
        if not profile_id or profile_id not in supported:
            self._set_command(
                False,
                "rejected",
                "Choose an effect published for this lighting target.",
            )
            return

        self._set_command(True, "working", "Applying lighting effect…")
        self._put_document(
            "/api/v1/lighting/assignment",
            {
                "expectedRevision": self._contract_revision,
                "deviceId": device_id,
                "targetId": target_id,
                "profileId": profile_id,
            },
            self._accept_lighting_command,
        )

    @pyqtSlot(str, str, str)
    def changeLightingController(
        self,
        device_id: str,
        expected_controller: str,
        requested_controller: str,
    ) -> None:
        if self._command_busy:
            return
        if self._mode != "live" or self._contract_version != "1.0":
            self._set_command(False, "rejected", "Lighting ownership changes require the versioned write contract.")
            return
        ownership = self._lighting_ownership(device_id)
        if "change-controller" not in ownership.get("operations", []):
            self._set_command(False, "rejected", "That device does not publish a lighting-controller transition.")
            return
        if ownership.get("controller") != expected_controller:
            self._set_command(False, "rejected", "The lighting controller changed; refresh and review the transition again.")
            return
        if requested_controller not in {"individual", "rgb-cluster"}:
            self._set_command(False, "rejected", "Choose Individual devices or RGB Cluster.")
            return

        self._set_command(True, "working", "Changing lighting controller…")
        self._put_document(
            "/api/v1/lighting/ownership",
            {
                "expectedRevision": self._contract_revision,
                "deviceId": device_id,
                "expectedController": expected_controller,
                "requestedController": requested_controller,
            },
            self._accept_lighting_ownership_command,
        )

    def _lighting_target(
        self,
        device_id: str,
        target_id: str,
    ) -> dict[str, Any] | None:
        for device in self._devices:
            if device.get("id") != device_id:
                continue
            for tab in device.get("tabs", []):
                if tab.get("name") != "Lighting":
                    continue
                editor = tab.get("lightingEditor", {})
                for target in editor.get("targets", []):
                    if target.get("key") == target_id:
                        return target
            return None
        return None

    def _lighting_ownership(self, device_id: str) -> dict[str, Any]:
        for device in self._devices:
            if device.get("id") != device_id:
                continue
            for tab in device.get("tabs", []):
                if tab.get("name") == "Lighting":
                    ownership = tab.get("lightingEditor", {}).get("ownership", {})
                    return ownership if isinstance(ownership, dict) else {}
            break
        return {}

    def _accept_label_command(
        self,
        payload: dict[str, Any] | None,
        error: str | None,
    ) -> None:
        if payload is None:
            self._set_command(False, "rejected", error or "The label request failed.")
            return
        try:
            document = VersionedDocument.from_mapping(payload, kind="command-result")
        except (PayloadError, TypeError, ValueError) as parse_error:
            self._set_command(False, "rejected", str(parse_error))
            return

        result = document.data
        status = str(result.get("status", "rejected"))
        message = str(result.get("message", "The label request was rejected."))
        self._contract_revision = document.revision
        self.connectionChanged.emit()
        self._set_command(False, status, message)
        self._snapshot_etag = ""
        self._refresh_after_command = True
        if not self._refreshing:
            self._refresh_after_command = False
            QTimer.singleShot(0, self.refresh)

    def _accept_lighting_command(
        self,
        payload: dict[str, Any] | None,
        error: str | None,
    ) -> None:
        if payload is None:
            self._set_command(
                False,
                "rejected",
                error or "The lighting assignment failed.",
            )
            return
        try:
            document = VersionedDocument.from_mapping(payload, kind="command-result")
        except (PayloadError, TypeError, ValueError) as parse_error:
            self._set_command(False, "rejected", str(parse_error))
            return

        result = document.data
        status = str(result.get("status", "rejected"))
        message = str(
            result.get("message", "The lighting assignment was rejected.")
        )
        self._contract_revision = document.revision
        self.connectionChanged.emit()
        self._set_command(False, status, message)
        self._snapshot_etag = ""
        self._refresh_after_command = True
        if not self._refreshing:
            self._refresh_after_command = False
            QTimer.singleShot(0, self.refresh)

    def _accept_lighting_ownership_command(
        self,
        payload: dict[str, Any] | None,
        error: str | None,
    ) -> None:
        if payload is None:
            self._set_command(False, "rejected", error or "The lighting controller change failed.")
            return
        try:
            document = VersionedDocument.from_mapping(payload, kind="command-result")
        except (PayloadError, TypeError, ValueError) as parse_error:
            self._set_command(False, "rejected", str(parse_error))
            return
        result = document.data
        self._contract_revision = document.revision
        self.connectionChanged.emit()
        self._set_command(
            False,
            str(result.get("status", "rejected")),
            str(result.get("message", "The lighting controller change was rejected.")),
        )
        self._snapshot_etag = ""
        self._refresh_after_command = True
        if not self._refreshing:
            self._refresh_after_command = False
            QTimer.singleShot(0, self.refresh)

    def _accept_contract(
        self,
        generation: int,
        payload: dict[str, Any] | None,
        _error: str | None,
    ) -> None:
        if generation != self._generation:
            return
        if payload is not None and payload.get("_notModified") is True:
            self._last_updated = QDateTime.currentDateTime().toString("HH:mm:ss")
            self._set_connection(
                "connected",
                f"Live · {len(self._devices)} devices",
                "",
            )
            self._set_refreshing(False)
            return
        if payload is not None:
            try:
                document = VersionedDocument.from_mapping(
                    payload,
                    kind="snapshot",
                )
                snapshot = ContractSnapshot(document.data).build()
            except (PayloadError, TypeError, ValueError):
                pass
            else:
                self._snapshot_etag = str(payload.get("_etag", ""))
                self._finish_contract(snapshot, document)
                return

        # OpenLinkHub releases before contract 1.0 route this path through the
        # generic /api/ handler and return a valid but incompatible legacy
        # payload. Strict document validation makes that a silent fallback.
        self._refresh_legacy(generation)

    def _refresh_legacy(self, generation: int) -> None:
        results: dict[str, Any] = {}
        errors: list[str] = []
        pending_base = {"inventory", "battery", "cpu", "gpu"}
        self._refresh_cycle += 1
        refresh_lighting = (
            not self._lighting_profiles
            or self._refresh_cycle % 10 == 1
        )
        if refresh_lighting:
            pending_base.add("lighting")
        pending_details: set[str] = set()

        def maybe_finish() -> None:
            if generation != self._generation or pending_base or pending_details:
                return
            self._finish_refresh(results, errors)

        def accept_base(name: str, envelope: dict[str, Any] | None, error: str | None) -> None:
            if generation != self._generation:
                return
            pending_base.discard(name)
            if error:
                errors.append(f"{name}: {error}")
            elif envelope is not None:
                results[name] = envelope

            if name == "inventory" and envelope is not None:
                records = envelope.get("devices")
                if isinstance(records, dict):
                    for device_id, wrapper in records.items():
                        if not isinstance(wrapper, dict):
                            continue
                        product = str(wrapper.get("Product", ""))
                        if wrapper.get("Hidden") or product.casefold() == "cluster":
                            continue
                        pending_details.add(str(device_id))

                    for device_id in tuple(pending_details):
                        self._get_json(
                            f"/api/devices/{device_id}",
                            lambda payload, detail_error, current=device_id: accept_detail(
                                current, payload, detail_error
                            ),
                        )
            maybe_finish()

        def accept_detail(
            device_id: str,
            envelope: dict[str, Any] | None,
            error: str | None,
        ) -> None:
            if generation != self._generation:
                return
            pending_details.discard(device_id)
            if error:
                errors.append(f"device {device_id}: {error}")
            elif envelope is not None:
                results.setdefault("details", {})[device_id] = envelope.get("device")
            maybe_finish()

        self._get_json(
            "/api/devices/",
            lambda payload, error: accept_base("inventory", payload, error),
        )
        self._get_json(
            "/api/batteryStats",
            lambda payload, error: accept_base("battery", payload, error),
        )
        self._get_json(
            "/api/cpuTemp/clean",
            lambda payload, error: accept_base("cpu", payload, error),
        )
        self._get_json(
            "/api/gpuTemp/clean",
            lambda payload, error: accept_base("gpu", payload, error),
        )
        if refresh_lighting:
            self._get_json(
                "/api/color/",
                lambda payload, error: accept_base("lighting", payload, error),
            )

    def _get_json(self, path: str, callback: JsonCallback) -> None:
        request = QNetworkRequest(QUrl(self._endpoint + path))
        request.setRawHeader(b"Accept", b"application/json")
        request.setRawHeader(b"User-Agent", b"OpenLinkHub-Plasma-Phase1")
        request.setTransferTimeout(4500)
        reply = self._manager.get(request)
        self._api_call_count += 1
        self.apiCallCountChanged.emit()

        def finished() -> None:
            status = reply.attribute(QNetworkRequest.Attribute.HttpStatusCodeAttribute)
            body = bytes(reply.readAll())
            network_error = reply.error()
            network_message = reply.errorString()
            reply.deleteLater()

            if network_error != QNetworkReply.NetworkError.NoError:
                callback(None, f"{network_message} ({status or 'no HTTP status'})")
                return
            if not isinstance(status, int) or status < 200 or status >= 300:
                callback(None, f"HTTP {status or 'unknown'}")
                return

            try:
                envelope = ApiEnvelope.from_bytes(body)
            except PayloadError as error:
                callback(None, str(error))
                return
            callback(
                {
                    "code": envelope.code,
                    "status": envelope.status,
                    "message": envelope.message,
                    "data": envelope.data,
                    "device": envelope.device,
                    "devices": envelope.devices,
                    "dashboard": envelope.dashboard,
                },
                None,
            )

        reply.finished.connect(finished)

    def _get_document(
        self,
        path: str,
        callback: JsonCallback,
        *,
        etag: str = "",
    ) -> None:
        request = QNetworkRequest(QUrl(self._endpoint + path))
        request.setRawHeader(b"Accept", b"application/json")
        request.setRawHeader(b"User-Agent", b"OpenLinkHub-Plasma-Phase2")
        if etag:
            request.setRawHeader(b"If-None-Match", etag.encode("ascii"))
        request.setTransferTimeout(4500)
        reply = self._manager.get(request)
        self._api_call_count += 1
        self.apiCallCountChanged.emit()

        def finished() -> None:
            status = reply.attribute(QNetworkRequest.Attribute.HttpStatusCodeAttribute)
            body = bytes(reply.readAll())
            network_error = reply.error()
            network_message = reply.errorString()
            response_etag = bytes(reply.rawHeader(b"ETag")).decode(
                "ascii",
                errors="ignore",
            )
            reply.deleteLater()

            if status == 304:
                callback({"_notModified": True, "_etag": response_etag}, None)
                return
            if network_error != QNetworkReply.NetworkError.NoError:
                callback(None, f"{network_message} ({status or 'no HTTP status'})")
                return
            if not isinstance(status, int) or status < 200 or status >= 300:
                callback(None, f"HTTP {status or 'unknown'}")
                return
            try:
                decoded = json.loads(body)
            except (UnicodeDecodeError, json.JSONDecodeError):
                callback(None, "The service returned malformed JSON.")
                return
            if not isinstance(decoded, dict):
                callback(None, "The service response is not a JSON object.")
                return
            decoded["_etag"] = response_etag
            callback(decoded, None)

        reply.finished.connect(finished)

    def _put_document(
        self,
        path: str,
        payload: Mapping[str, Any],
        callback: JsonCallback,
        *,
        method: bytes = b"PUT",
    ) -> None:
        request = QNetworkRequest(QUrl(self._endpoint + path))
        request.setRawHeader(b"Accept", b"application/json")
        request.setRawHeader(b"Content-Type", b"application/json")
        request.setRawHeader(b"User-Agent", b"OpenLinkHub-Plasma-Phase3")
        request.setTransferTimeout(4500)
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        if method == b"DELETE" and path == "/api/v1/lighting/identify":
            reply = self._manager.sendCustomRequest(request, b"DELETE", body)
        else:
            reply = self._manager.put(request, body)
        self._api_call_count += 1
        self.apiCallCountChanged.emit()

        def finished() -> None:
            status = reply.attribute(QNetworkRequest.Attribute.HttpStatusCodeAttribute)
            body = bytes(reply.readAll())
            network_error = reply.error()
            network_message = reply.errorString()
            reply.deleteLater()

            if network_error != QNetworkReply.NetworkError.NoError and not body:
                callback(None, f"{network_message} ({status or 'no HTTP status'})")
                return
            try:
                decoded = json.loads(body)
            except (UnicodeDecodeError, json.JSONDecodeError):
                callback(None, f"The service returned malformed JSON (HTTP {status or 'unknown'}).")
                return
            if not isinstance(decoded, dict):
                callback(None, "The service response is not a JSON object.")
                return
            callback(decoded, None)

        reply.finished.connect(finished)

    def _finish_contract(
        self,
        snapshot: Mapping[str, Any],
        document: VersionedDocument,
    ) -> None:
        self._devices = list(snapshot["devices"])
        self._telemetry = dict(snapshot["telemetry"])
        self._overview_metrics = list(snapshot["overviewMetrics"])
        self._cooling_zones = list(snapshot["coolingZones"])
        self._zone_values = dict(snapshot["zoneValues"])
        self._last_updated = QDateTime.currentDateTime().toString("HH:mm:ss")
        self._set_contract(
            document.api_version,
            "Versioned service contract",
            document.revision,
            document.telemetry_revision,
        )
        self.dataChanged.emit()
        self._set_connection(
            "connected",
            f"Live · {len(self._devices)} devices",
            "",
        )
        self._set_refreshing(False)

    def _finish_refresh(self, results: dict[str, Any], errors: list[str]) -> None:
        inventory = results.get("inventory")
        if not isinstance(inventory, dict) or not isinstance(inventory.get("devices"), dict):
            state = "degraded" if self._devices else "offline"
            message = "Live data stale" if self._devices else "Service unavailable"
            error = "; ".join(errors) or "Device inventory unavailable."
            self._set_connection(state, message, error)
            self._set_refreshing(False)
            return

        try:
            lighting_profiles = _data_mapping(results.get("lighting"))
            if lighting_profiles:
                self._lighting_profiles = dict(lighting_profiles)
            snapshot = LegacySnapshot(
                inventory=inventory,
                details=results.get("details", {}),
                batteries=_data_mapping(results.get("battery")),
                lighting_profiles=self._lighting_profiles,
                cpu_temperature=_data_value(results.get("cpu")),
                gpu_temperature=_data_value(results.get("gpu")),
            ).build()
        except (PayloadError, TypeError, ValueError) as error:
            self._set_connection("offline", "Invalid service data", str(error))
            self._set_refreshing(False)
            return

        self._devices = snapshot["devices"]
        self._telemetry = snapshot["telemetry"]
        self._overview_metrics = snapshot["overviewMetrics"]
        self._cooling_zones = snapshot["coolingZones"]
        self._zone_values = snapshot["zoneValues"]
        self._last_updated = QDateTime.currentDateTime().toString("HH:mm:ss")
        self._set_contract("", "Legacy compatibility adapter", 0, 0)
        self._snapshot_etag = ""
        self.dataChanged.emit()

        if errors:
            self._set_connection(
                "degraded",
                f"Live · {len(self._devices)} devices · partial data",
                "; ".join(errors),
            )
        else:
            self._set_connection(
                "connected",
                f"Live · {len(self._devices)} devices",
                "",
            )
        self._set_refreshing(False)

    def _set_connection(self, state: str, status: str, error: str) -> None:
        changed = (
            state != self._connection_state
            or status != self._status_text
            or error != self._error_message
        )
        self._connection_state = state
        self._status_text = status
        self._error_message = error
        if changed:
            self.connectionChanged.emit()

    def _set_contract(
        self,
        version: str,
        source: str,
        revision: int,
        telemetry_revision: int,
    ) -> None:
        changed = (
            version != self._contract_version
            or source != self._contract_source
            or revision != self._contract_revision
            or telemetry_revision != self._telemetry_revision
        )
        self._contract_version = version
        self._contract_source = source
        self._contract_revision = revision
        self._telemetry_revision = telemetry_revision
        if changed:
            self.connectionChanged.emit()

    def _set_refreshing(self, refreshing: bool) -> None:
        if refreshing == self._refreshing:
            return
        self._refreshing = refreshing
        self.refreshChanged.emit()
        if not refreshing and self._refresh_after_command:
            self._refresh_after_command = False
            QTimer.singleShot(0, self.refresh)

    def _set_command(self, busy: bool, status: str, message: str) -> None:
        changed = (
            busy != self._command_busy
            or status != self._command_status
            or message != self._command_message
        )
        self._command_busy = busy
        self._command_status = status
        self._command_message = message
        if changed:
            self.commandChanged.emit()


def _data_mapping(envelope: Any) -> Mapping[str, Any]:
    if not isinstance(envelope, dict):
        return {}
    data = envelope.get("data")
    return data if isinstance(data, Mapping) else {}


def _data_value(envelope: Any) -> Any:
    return envelope.get("data") if isinstance(envelope, dict) else None

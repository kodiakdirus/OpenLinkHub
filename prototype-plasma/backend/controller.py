"""Asynchronous, GET-only Qt transport for OpenLinkHub."""

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
    """Own the read-only loopback connection and normalized QML state."""

    modeChanged = pyqtSignal()
    connectionChanged = pyqtSignal()
    dataChanged = pyqtSignal()
    refreshChanged = pyqtSignal()
    apiCallCountChanged = pyqtSignal()

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
        self._generation = 0
        self._refresh_cycle = 0
        self._devices: list[dict[str, Any]] = []
        self._lighting_profiles: dict[str, Any] = {}
        self._telemetry: dict[str, Any] = {}
        self._overview_metrics: list[dict[str, Any]] = []
        self._cooling_zones: list[dict[str, Any]] = []
        self._zone_values: dict[str, str] = {}

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

    @pyqtProperty("QVariantList", notify=dataChanged)
    def devices(self) -> list[dict[str, Any]]:
        return self._devices

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
        self._mode = normalized
        self.modeChanged.emit()

        if normalized == "demo":
            self._timer.stop()
            self._generation += 1
            self._set_refreshing(False)
            self._set_contract("", "Demo data", 0, 0)
            self._snapshot_etag = ""
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


def _data_mapping(envelope: Any) -> Mapping[str, Any]:
    if not isinstance(envelope, dict):
        return {}
    data = envelope.get("data")
    return data if isinstance(data, Mapping) else {}


def _data_value(envelope: Any) -> Any:
    return envelope.get("data") if isinstance(envelope, dict) else None

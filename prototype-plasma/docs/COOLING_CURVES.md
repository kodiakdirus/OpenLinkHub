# Existing fan-curve editing

In Live mode, Cooling → Manage cooling profiles opens the saved fan curves.
Demo mode retains the mock profile manager. The live editor selects Radiator20
when available. Edit temperature/output points, then explicitly Save fan curve.
Saving updates every fan assigned to that named profile immediately; it does
not change pump points, sensor source, zero-RPM policy, or channel assignments.
This editor is intended for the deployed service's graphProfiles=true mode.

The client uses existing loopback routes GET /api/temperatures/ and
PUT /api/temperatures/updateGraph with updateType=1. Catalog GET legitimately
returns legacy status=0; PUT requires read-back verification rather than
assuming HTTP 200 proves success. No new server or service restart is required.
This is an explicit legacy cooling write path, separate from the versioned
lighting contract. It does not publish new versioned cooling capabilities.

Input validation requires 2–32 finite points, temperature 0–200 C, output 0–100%,
strictly increasing temperatures and nondecreasing output. Existing service
minimums and coolant protection remain in the driver. Point edits are drafts;
telemetry polls never replace them. Reset draft restores the loaded curve.
Reload is available after discarding the draft. Sensor and pump controls are
not offered by this fan-only editor.

Before writing, a fresh full-profile read must match the loaded baseline. The
client then saves a mode-0600 recovery copy under
$XDG_STATE_HOME/openlinkhub-plasma/cooling-backups (default ~/.local/state).
Backup failure prevents writing. Save is serialized in the client and followed
by full-profile read-back, including the untouched pump curve and metadata.
An uncertain response triggers read-back, never an automatic write retry.
Mode changes invalidate pending prechecks and stale UI callbacks.

The legacy API has no atomic conditional update. The fresh-read comparison
cannot prevent another client writing between comparison and save. Avoid
simultaneous curve editing in the WebUI and Plasma client. If read-back differs
or fails, the UI reports an unverified outcome and retains the draft/backup;
it does not blindly overwrite a potentially newer profile to roll back.
For recovery, use the backup's before.points["1"] as the original fan points;
reload current state before restoring through an explicitly reviewed save.

Validation: client tests cover invalid input, Demo isolation, stale baselines,
backup failure, fan-only payloads, read-back mismatch, uncertain responses,
duplicate saves, mode changes and private recovery files. Read-only live render
and QML smoke tests supplement tests without changing hardware profiles.

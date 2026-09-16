# OpenLinkHub Plasma public alpha

OpenLinkHub Plasma is a community desktop client. The GUI and the OpenLinkHub
hardware service are installed and versioned separately. This alpha is not a
claim of upstream endorsement or full Web UI feature parity.

## Install the testing package

Install Flatpak through your distribution, then download the `.flatpak` bundle
and its `.sha256` file from this fork's GitHub prerelease. The first target is
Linux x86_64. A first installation also downloads the shared KDE runtime.

From the download directory:

```bash
sha256sum -c openlinkhub-plasma-0.1.0a2-x86_64.flatpak.sha256
flatpak install --user ./openlinkhub-plasma-0.1.0a2-x86_64.flatpak
flatpak run io.github.kodiakdirus.OpenLinkHubPlasma
```

The application also appears as **OpenLinkHub Plasma** in your launcher. Its
first launch uses Demo. Choose Live to connect to `http://127.0.0.1:27003`.
If the service is missing, the GUI explains the connection problem and Demo
remains available. Install/start the service separately using its own directions.
The GUI installer does not install a daemon, change USB permissions, or replace
the existing service. Closing or removing the GUI leaves that service running.

**Service → Backend setup → Review setup…** stays available at any time. A small
inline reminder appears in Demo or legacy compatibility mode after startup
settles. Closing it remembers your choice across launches; resetting appearance
does not turn it back on. The setup panel can re-enable the reminder. A
versioned service connection suppresses it, even when some devices are read-only.
Connection failures retain their normal retry banner with a Backend setup action,
without adding another reminder above it.

Setup only opens when selected. Opening the panel does not probe, install, patch
or restart a service. **Connect to existing service** explicitly switches to
Live and checks the local service. The installation guide opens in your browser.
There is no compatible testing-backend package or in-app service installer yet;
the panel states that limitation. Setup can be revisited after installing a
service separately. A GUI update cannot unlock unfinished GUI editors.

For the next alpha, download its bundle and run `flatpak install --user` on it.
These standalone testing bundles do not provide an automatic update feed.
Remove the application with:

```bash
flatpak uninstall --user io.github.kodiakdirus.OpenLinkHubPlasma
```

Flatpak keeps presentation settings under
`~/.var/app/io.github.kodiakdirus.OpenLinkHubPlasma/config/openlinkhub-plasma/`.
They are separate from a source checkout's settings. Uninstall normally retains
them; `--delete-data` also removes this application's settings and local cooling
recovery copies. It does not remove service-owned profiles.

## Backend compatibility

| Service | What to expect |
| --- | --- |
| None / unreachable | Demo works; Live shows connection guidance. |
| Legacy API | Reported telemetry and device information; existing fan-curve editing where its legacy API is available. Versioned label and lighting operations are unavailable. |
| Compatible versioned API 1.0 | Device labels, lighting assignment/ownership and runtime operations appear only where explicitly published. |

There is no claimed minimum upstream release number for API 1.0 yet. This
branch contains additive service changes that may not exist in an upstream
installation. The service version string alone does not prove those changes are
present. The client validates the API documents and capability declarations.
A testing release must identify the exact backend commit/build it was tested
against; no custom backend binary is included in the GUI bundle.

Input/audio/display configuration, global profiles, automations, integration
setup, and lighting effect-definition writes are not implemented in Live.
Demo exposes design previews. A configured Cluster scene and running renderer
do not prove that every physical LED received the last frame.

## Useful tests

1. Launch with no service; confirm Demo works and Live explains the problem.
2. Connect to your existing service and compare inventory/telemetry with the Web UI.
3. Navigate Lighting, Input and Displays; check that each shows relevant controls.
4. Change appearance, rearrange cells, restart, and check persistence.
5. Check the configured lighting scene against your service configuration. Saved
   individual effects should be marked inactive while Cluster controls lighting.
6. If testing a supported write, change one setting deliberately and check the
   reported result and the physical device. Report unverified outcomes as such.

For bug reports, include the GUI version, distribution, desktop/session type,
device models, reproduction steps, expected result, and actual result. Under
**Service → Save diagnostics…**, export and inspect the JSON, then attach it to
an issue in this fork. The export contains version/capability summaries and
excludes device identifiers, labels, profile names, paths, and raw logs. Nothing
is uploaded automatically. Review screenshots separately for personal labels.

## Package permissions

Wayland/X11 and graphics access support the desktop window. Network access is
needed for the loopback HTTP API; Flatpak's network permission is broader than
loopback, although this client rejects non-loopback endpoints. No blanket host
filesystem or USB device access is granted. Diagnostics use the file chooser.

# Independent client packaging

Application ID: `io.github.kodiakdirus.OpenLinkHubPlasma`.
Executable: `openlinkhub-plasma`. Current alpha: `0.1.0a2`.
The ID belongs to this community fork; adoption upstream can be discussed
without blocking testing. Preserve one source tree while shipping the client
on its own schedule. This package does not include the Go service.

## Build

Install Flatpak, flatpak-builder, AppStream compose/validation tools, Python 3,
and setuptools >=77. Add Flathub to your user installation:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
python3 prototype-plasma/scripts/build-release.py --output prototype-plasma/dist
prototype-plasma/scripts/build-flatpak.sh
```

The Flatpak script fetches the matching KDE Platform/SDK and PyQt BaseApp,
builds the package, runs Demo smoke and fixture tests, then emits a `.flatpak`
bundle and checksum under `prototype-plasma/dist`. `FLATPAK_BUILDER` can point
to a specific builder executable. All build/dependency installation is per-user.
The runtime branch is pinned in the manifest; individual runtime commits track
that maintained branch. Build outputs record the actual commits in Flatpak metadata.

The source script emits a wheel, client-only source archive, and `SHA256SUMS`.
The wheel includes all QML and desktop assets. Native installation requires
distro-provided PyQt6, Kirigami, Qt Quick Controls/Layouts/Dialogs, the KDE desktop
style and Breeze icons. Do not mix a pip-downloaded Qt runtime with incompatible
distro QML plugins. For a native development install, use a virtual environment
with system site packages and install the wheel with `--no-deps`.

The client source archive builds outside the Go repository. Service-source audit
tests need the full repository; runtime/client tests use bundled fixtures.

## Release workflow

`.github/workflows/plasma-package.yml` builds on relevant pull requests and
manual dispatch. Artifacts are available from the workflow run. A
`plasma-v0.1.0a2` tag additionally creates a **draft prerelease**, leaving public
publication to a maintainer. Tag and application versions must match.

Before publishing that draft:

- Review the bundle, wheel, source archive, checksums and release notes.
- Record the tested service build/commit and which features were exercised.
- Check a clean user installation and a non-Plasma desktop, including the
  diagnostics save portal; automated offscreen tests do not cover the real portal.
- Attach Demo screenshots without private device names and retain the alpha label.

Publish downloadable bundles first. A signed Flatpak repository/update feed and
Flathub submission can follow once the app identity and compatibility policy
are settled. The initial workflow does not submit to Flathub or update a service.

## Upstream contribution boundaries

Prepare focused reviews for (1) additive service/API changes with their own
service tests, and (2) this optional desktop client and its packaging. Describe
the client as an HTTP consumer and keep device access, policy, and persistence
in the service. Upstream builds must not acquire GUI dependencies unless the
desktop target is explicitly selected. Do not create a separately maintained
copy of the client just to distribute binaries.

The client carries the repository's GPLv3 license. Release artifacts retain it;
the source archive accompanies the binary package. AppStream metadata is CC0.

References: [KDE Python Flatpak packaging](https://develop.kde.org/docs/getting-started/python/python-flatpak/),
[Flatpak sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).

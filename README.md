# FreeBar

A tiny native macOS menu bar utility that shows available storage.

`Mac 183G | T7 742G`

## What it does

Displays the Mac's available storage and mounted local external drives directly in the menu bar. No Dock icon, windows, dashboards, or decorative icons. Click for **Refresh**, **Launch at Login**, and **Quit FreeBar**.

Capacities refresh about every five seconds. Mount, unmount, rename, and wake events trigger discovery immediately; a one-minute fallback recovers from missed events or temporarily unavailable metadata. Unchanged titles are not reassigned.

## Requirements

- macOS 13 Ventura or later; Apple Silicon, running natively (arm64).
- Swift 5.9+ and a macOS SDK. **Apple Command Line Tools are sufficient to build and install**: `xcode-select --install`. Full Xcode is not required for the app.
- For `swift test`, select full Xcode: the standalone Command Line Tools installation tested here does not include XCTest.

Verified on macOS 26.5 with Xcode's Swift 6.3.3 and standalone Command Line Tools Swift 6.2.4. macOS 13 is the declared deployment target, not a separately tested runtime.

## Install

The GitHub repository is private; cloning requires authorized access.

```bash
git clone https://github.com/Ilcoach/FreeBar.git
cd FreeBar
./install.sh
```

From the existing local project:

```bash
cd <project-root>stall.sh
```

Installs and opens `~/Applications/FreeBar.app`, without `sudo`. Repeating the command builds release, stops the old instance, and safely replaces it; the old bundle is retained until launch succeeds. Unrelated bundles and symlinks at the destination are rejected.

Launch at Login is initially off. Toggle it in FreeBar's menu. A checkmark means enabled; a mixed mark means macOS approval is pending in **System Settings → General → Login Items**. Registration uses `SMAppService`; reinstall preserves the setting. On failure, FreeBar beeps and supplies an error tooltip rather than opening another window.

The installer uses an ad-hoc signature and a stable local bundle-identifier requirement. This private build is not Developer ID signed or notarized; do not treat it as a public distribution package.

## Uninstall

```bash
./uninstall.sh
```

Stops FreeBar, unregisters Launch at Login, and removes only `~/Applications/FreeBar.app`. If unregistering fails, the app is retained so you can retry. Project sources and user files remain untouched. FreeBar creates no custom settings files; macOS may retain its own disabled Login Items history.

## Development

```bash
swift build
swift build -c release
swift test
./install.sh
```

Launch the assembled `.app`, not the bare SwiftPM executable: `Info.plist` supplies the menu-bar-only lifecycle and ServiceManagement identity. Version metadata lives in `Resources/Info.plist`.

To reproduce the Command Line Tools build without changing the system's selected toolchain:

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build --scratch-path .build/clt -c release
```

See [TESTING.md](TESTING.md) for executed checks and remaining manual tests.

## Storage detection

- **Mac** appears once, using the writable APFS Data filesystem, with `/` as fallback. System, VM, Preboot, Recovery, and other internal mounts are not listed separately.
- Uses Foundation's `volumeAvailableCapacityForImportantUsage`: space macOS considers available for important user data, including reclaimable space. If unsupported, falls back to `volumeAvailableCapacity`. It is not total capacity or opportunistic capacity and may exceed `df`'s immediately free space.
- Uses decimal units: `M` = 10⁶ bytes, `G` = 10⁹, `T` = 10¹². Whole MB/GB; at most two TB decimals with trailing zeroes removed. `?` means unavailable, not zero.
- Reads the cached native mount table without probing network shares. Disk Arbitration physical-transport metadata and Foundation visibility/volume metadata filter external SSDs, HDDs, USB sticks, and SD cards. Virtual transports (including APFS disk images), non-local filesystems, and hidden/non-browsable helper mounts are excluded, without blacklisting user volume names.
- External volumes are sorted by name, with stable UUID tie-breaking. Names longer than 12 grapheme clusters are truncated safely. Separately mounted user volumes on the same external disk remain separate entries and may share APFS free space.

Disk inspection runs on one utility queue, off the UI thread. Mount identity is checked before and after external capacity reads; disappearing/unreadable volumes are skipped. No App Sandbox or additional entitlements: this manually installed app needs only system volume metadata, and sandboxing would add unnecessary access/packaging complexity.

## Privacy

Fully local. No telemetry, networking, analytics, update checks, accounts, or file scanning. Only filesystem/volume metadata is queried; no user filenames or file contents are collected. No third-party dependencies or runtime shell polling.

## Limitations

- iPhone/iPad storage is not supported in v1.
- Only normally mounted local physical storage volumes are considered. Unknown transports or missing identifying metadata are deliberately omitted; no network, DMG, or virtual-disk support.
- macOS controls menu bar space: many connected volumes can exceed the available width.
- Launch-at-login approval and behavior across an actual logout/reboot still depend on macOS policy; see the test report.

MIT licensed; repository visibility remains private.

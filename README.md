# FreeBar

A tiny native macOS menu bar utility that shows the storage you actually have available — on your Mac and on connected local drives.

```text
Mac 183G | T7 742G
```

FreeBar is intentionally simple: no dashboard, no cleaner, no analytics, no cloud service. It keeps available storage visible in the macOS menu bar and stays out of the way.

## What it does

FreeBar displays the Mac's available storage directly in the menu bar and automatically adds normally mounted local physical storage such as external SSDs, HDDs, USB drives, and SD cards.

When a drive is mounted, unmounted, renamed, disconnected, or the Mac wakes from sleep, FreeBar refreshes its volume list automatically. Available capacity is refreshed about every five seconds without shell polling.

There is no Dock icon and no main application window.

Click the menu bar item for only three actions:

- **Refresh**
- **Launch at Login**
- **Quit FreeBar**

## Example

```text
Mac 183G
Mac 183G | T7 742G
Mac 183G | T7 742G | USB 28G
```

`Mac` always represents the main writable storage used by macOS. External drives use their mounted volume name and are shown in a deterministic order.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon (arm64)
- Swift 5.9+ and a macOS SDK when building from source

Apple Command Line Tools are sufficient to build and install FreeBar:

```bash
xcode-select --install
```

Full Xcode is not required to build the application. It may be required for the XCTest suite on systems where the standalone Command Line Tools do not include XCTest.

## Install

Clone the repository and run the installer:

```bash
git clone https://github.com/alessandroviola-dev/FreeBar.git
cd FreeBar
./install.sh
```

FreeBar is installed to:

```text
~/Applications/FreeBar.app
```

No `sudo` is required.

Running `./install.sh` again safely rebuilds and replaces the installed copy. The previous app bundle is retained until the new build launches successfully, allowing the installer to roll back if replacement fails.

The application is ad-hoc signed for local installation. It is not currently distributed as a notarized Developer ID binary, so installation is source-based for now.

## Uninstall

From the cloned repository:

```bash
./uninstall.sh
```

The uninstaller stops FreeBar, unregisters Launch at Login, and removes only:

```text
~/Applications/FreeBar.app
```

It does not delete the repository, user files, or unrelated preferences.

## How storage is measured

FreeBar prefers Foundation's `volumeAvailableCapacityForImportantUsage` and falls back to `volumeAvailableCapacity` when needed.

The displayed number therefore represents storage macOS considers practically available for important user data, including reclaimable space. It may differ from the raw immediately-free value reported by tools such as `df`.

Units are decimal:

- `M` = 10⁶ bytes
- `G` = 10⁹ bytes
- `T` = 10¹² bytes

Whole MB/GB values are preferred. TB values use at most two useful decimal places.

## External drive detection

FreeBar uses native macOS APIs only:

- AppKit
- Foundation
- Disk Arbitration
- ServiceManagement

The app reads the cached native mount table and uses Disk Arbitration and Foundation metadata to distinguish real local storage from system, virtual, and network mounts.

Typical supported devices include:

- external SSDs
- external HDDs
- USB flash drives
- SD cards
- other normally mounted local physical storage

FreeBar deliberately excludes:

- macOS APFS helper/system volumes such as VM, Preboot, Recovery, and Update
- mounted DMG images
- virtual filesystems
- network shares
- ambiguous mounts that cannot be identified safely as physical local storage

Known physical transports are recognized directly. For unfamiliar transport strings, FreeBar requires native USB/PCI hardware ancestry before accepting the volume. This keeps the filter conservative without depending solely on a hard-coded transport-name list.

Mount identity is checked both before and after capacity reads. If a drive disappears during a refresh, FreeBar skips it instead of accidentally reading the filesystem now occupying the old mount path.

Read-only physical drives are not automatically excluded: FreeBar reports connected physical storage, not filesystem write permission.

## Architecture and performance

FreeBar is a native Swift/AppKit utility with no third-party dependencies.

Storage reads run serially on a utility queue outside the UI thread. Mount/unmount topology changes are event-driven; a lightweight timer updates capacity. Refresh requests are coalesced so disk reads do not overlap, and stale asynchronous work from an earlier monitor lifecycle cannot update a restarted monitor.

The menu bar title is only reassigned when its resulting text actually changes.

The project is designed to remain running continuously with negligible idle CPU usage and no recurring child processes.

## Privacy

FreeBar is fully local.

- No telemetry
- No analytics
- No accounts
- No networking
- No advertising
- No update service
- No file scanning
- No user-file contents are read

Only filesystem and device metadata required to identify mounted storage and available capacity is queried.

FreeBar includes Apple's `PrivacyInfo.xcprivacy` manifest. Required-reason declarations cover only the system APIs used to display available disk capacity and monotonic uptime used for internal refresh timing. The app declares no collected data and no tracking.

## Launch at Login

FreeBar uses Apple's modern `SMAppService` API on macOS 13+.

Enable or disable it from the FreeBar menu. If macOS requires explicit approval, the menu reflects that state and can direct you to **System Settings → General → Login Items**.

Reinstalling FreeBar preserves the system login-item registration.

## Build and test

Debug build:

```bash
swift build
```

Release build:

```bash
swift build -c release --arch arm64
```

Tests:

```bash
swift test
```

Warnings-as-errors verification:

```bash
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
```

The current hardening pass completed **10 XCTest tests with 0 failures**, covering formatting, Unicode-safe display names, ordering, physical-volume filtering, live storage reads, privacy manifest behavior, and StorageMonitor lifecycle/coalescing behavior.

See [`TESTING.md`](TESTING.md) for the detailed verification matrix.

## Project structure

```text
FreeBar/
├── Package.swift
├── Sources/FreeBar/
├── Resources/
│   ├── Info.plist
│   └── PrivacyInfo.xcprivacy
├── Tests/FreeBarTests/
├── scripts/
├── install.sh
├── uninstall.sh
├── README.md
├── TESTING.md
├── LICENSE
└── .gitignore
```

## Limitations

- iPhone/iPad storage is not supported in v1 because modern macOS does not expose those devices as ordinary mounted filesystem volumes.
- Only normally mounted local physical storage is considered.
- Missing or insufficient hardware identity is deliberately treated conservatively rather than risking false positives.
- macOS ultimately controls available menu bar width, so many simultaneously connected volumes may exceed available space.
- The current public distribution method builds the app locally from source; there is not yet a notarized downloadable release binary.

## Contributing

Bug reports and focused improvements are welcome. Please keep the core product principle intact: FreeBar should remain a tiny, native, single-purpose utility rather than becoming a general system monitor or storage-management suite.

## License

FreeBar is released under the MIT License. See [`LICENSE`](LICENSE).

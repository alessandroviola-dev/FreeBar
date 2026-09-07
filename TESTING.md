# Verification — FreeBar 0.1.0

Executed on 2026-09-06, macOS 26.5, Apple Silicon arm64. No external physical drive was attached. The installed app was left running with Launch at Login **off** after testing.

| Check | Result | Evidence |
| --- | --- | --- |
| Debug build | PASS | `swift build -Xswiftc -warnings-as-errors`, Xcode Swift 6.3.3; no warnings. |
| Release build and installation | PASS | Both Xcode Swift 6.3.3 and standalone Command Line Tools Swift 6.2.4; final install also ran with `DEVELOPER_DIR=/Library/Developer/CommandLineTools`. |
| XCTest suite | PASS | 10 XCTest tests, zero failures, with warnings treated as errors: existing capacity/name/order/live-read coverage; privacy-manifest schema/reason coverage; unknown transport/filter coverage; and three deterministic StorageMonitor lifecycle/coalescing/restart tests. The final Swift Testing runner's separate `0 tests` line does not replace this XCTest result. |
| Tests using only Command Line Tools | NOT SUPPORTED | Installed CLT lacks XCTest (`no such module 'XCTest'`). App build/install works; README explicitly requires Xcode for the test suite. |
| Native bundle | PASS | `file`: arm64 Mach-O; `vtool`: deployment target 13.0; plist lint and strict code-signature verification passed. Approximately 200 KB installed. |
| Menu bar / no Dock | PASS | Screenshot showed `Mac 36G`; Accessibility tree showed a native status item and exactly Refresh, Launch at Login, separator, Quit FreeBar. `NSRunningApplication.activationPolicy` was accessory (1). |
| Main storage once / system helpers | PASS | Live reads and status title contained one Mac, without Data/System/VM/Preboot/Recovery duplicates. |
| Automatic capacity refresh | PASS | Created 1,500 MiB of temporary data under ignored `.build/`, then removed it. Without clicking Refresh, observed `Mac 36G → Mac 35G → Mac 36G` within polling intervals. Test data removed. |
| Manual Refresh | PASS | Invoked actual menu action through Accessibility; action succeeded, app remained responsive with current capacity. |
| Quit / restart / single instance | PASS | Actual Quit menu action terminated the process. Restart and repeated `open` calls produced one FreeBar process. |
| Launch at Login toggle | PASS | Actual menu actions changed checkmark on/off. `sfltool dumpbtm` independently confirmed enabled/disabled state for the installed bundle. |
| Login state across reinstall | PASS | Enabled registration and menu checkmark survived release replacement. Disabled afterward. |
| Reinstall / uninstall | PASS | Repeated installation, installation launched from `/tmp`, removal while login was enabled, idempotent second removal, then reinstall. Uninstall disabled the system registration and removed the app/process. |
| Installer safety | PASS | In a disposable test HOME, both scripts rejected a different bundle identifier; uninstall rejected a symlink. Unrelated sentinel files remained intact. Bash syntax checks passed. |
| APFS disk images | PASS | Mounted a fresh 128 MB APFS DMG normally and with `-nobrowse`; native metadata reported Virtual Interface. It never appeared in live reads/title; app survived mount/unmount. Existing iOS Simulator disk image was also excluded. Test image detached. The hardening filter additionally walks native IOKit ancestry for unfamiliar transports and rejects virtual backing. |
| Network exclusion | PASS (logic) | Non-local metadata rejected in tests; source filters cached kernel mount flags before any volume capacity query. Live network-share mounting was not tested. |
| CPU / memory / subprocesses | PASS | Twelve samples over approximately one minute: instantaneous CPU 0.0%, RSS approximately 42.5 MiB and stable; CPU time increased approximately 0.30 seconds. No child processes. This is a sanity check, not a long-term leak test. |
| Privacy manifest | PASS | `Resources/PrivacyInfo.xcprivacy` passed `plutil -lint`; XCTest verified its exact DiskSpace `85F4.1` and SystemBootTime `35F9.1` declarations and empty collection/tracking declarations. Installation verifies and compares the bundled copy. |
| Networking / dependencies | PASS (inspection) | No network implementation, third-party dependencies, or subprocess calls in app source; linked libraries are Apple system libraries. Repeated `lsof` checks found no app network sockets. This is not an exhaustive packet trace. |

## Remaining manual checks

**NOT TESTED** (hardware/session changes not performed):

- Attach one external physical SSD, then a second USB/SD device; verify deterministic names/capacities. **User-reported PASS** before this hardening pass; not re-executed here.
- Unmount and physically unplug those devices, including during an active read; verify prompt removal and no crash. **User-reported PASS** before this hardening pass; not re-executed here.
- Sleep/wake with attached storage, then inspect the title. **User-reported PASS** before this hardening pass; not re-executed here.
- Actual automatic launch after logout/reboot, and the macOS approval-required/error paths.
- A real network share, older supported macOS releases, light/dark switching, and long-duration resource usage.

No unresolved build failures or known application defects remain. The hardware-dependent checks above must not be interpreted as passing results.

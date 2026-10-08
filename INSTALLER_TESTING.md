# Installer verification (local, 2026-10-08)

Canonical destination: `/Applications/FreeBar.app`. There is no per-user installation fallback and no creation of `~/Applications`. An existing verified legacy bundle is moved into the transaction backup, then discarded only after canonical launch and privacy-manifest verification succeed. Rollback restores existing bundles at their original paths. Uninstall validates both locations before executing either bundle or removing anything. Invalid bundles/signatures and symlinked bundles or Applications directories are refused.

## Results

- `bash -n install.sh uninstall.sh scripts/common.sh scripts/build-release.sh`: PASS.
- `python3 scripts/test-installer.py`: 15 scenarios PASS (fresh, canonical-only, legacy-only, coexistence, legacy/canonical wrong IDs, bad signature, bundle/parent symlinks, rollback on launch failure or missing process, uninstall, absent uninstall, unregister failure retention, exact executable process selection).
- `swift test`: 10 XCTest tests PASS, zero failures.
- `swift build -c release --arch arm64 -Xswiftc -warnings-as-errors`: PASS.
- `git diff --check`: PASS.
- Read-only verification of installed bundle ID and `codesign --verify --deep --strict`: PASS.
- Installed process retained PID 33561; installed executable modification time remained 2026-09-07. No real install/uninstall, app termination, GitHub Actions, push or release creation.

## Closure validation (2026-10-08)

The 15 installer scenarios, 10 XCTest tests (zero failures), Bash syntax, release arm64 build with warnings-as-errors, and diff whitespace checks were rerun successfully before the local checkpoint. No operational bundle, preferences or historical backup was modified. BTM_UNVERIFIED: the single authorized elevated read-only dump required sudo authentication; launchctl/LaunchAgents inspection did not establish enabled Login Item status. Real GUI, migration, reboot and publication remain deferred.

## Limits

Sandbox tests copy the scripts, redirect paths into a temporary directory, and mock build/signing/launch/process/login-item tools. The process-selection test also mocks Bash `kill`; it sends no real signals. These tests do not establish real LaunchServices or SMAppService behavior. Real migration, login approval and rollback under filesystem/permission failures remain manual checks. Check Launch at Login after migrating a legacy copy. If rollback cannot safely stop the new app or restore a backup, staging is retained for recovery rather than deleted.

`scripts/build-release.sh` was inspected and syntax-checked; it packages into `dist`, does not install into either Applications directory, and was not executed.

#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$ROOT/scripts/common.sh"
check_existing_app
check_existing_app "$LEGACY_APP"
for app in "$APP" "$LEGACY_APP"; do
    [[ ! -e "$app" || -w $(dirname "$app") ]] || fail "Directory is not writable: $(dirname "$app")"
done
for app in "$APP" "$LEGACY_APP"; do
    [[ -e "$app" ]] || continue
    stop_installed_app "$app"
    # Run the verified executable in its own bundle to unregister its login item.
    "$app/Contents/MacOS/FreeBar" --unregister-login || fail "Launch at Login could not be removed; retained: $app"
    rm -rf -- "$app"
done
# No settings files are created by FreeBar. Leave all unrelated preferences untouched.
printf 'FreeBar uninstalled. Project source and user files were left untouched.\n'

#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$ROOT/scripts/common.sh"
check_existing_app

if [[ ! -e "$APP" ]]; then
    printf 'FreeBar is not installed at %s\n' "$APP"
    exit 0
fi
stop_installed_app
# Run inside the installed bundle so SMAppService.mainApp identifies the right app.
# If unregister fails, retain the app so the user can retry rather than orphan a login item.
"$APP/Contents/MacOS/FreeBar" --unregister-login || fail 'Launch at Login could not be removed; app retained. Disable it in System Settings and retry.'
rm -rf -- "$APP"
# No settings files are created by FreeBar. Leave all unrelated preferences untouched.
printf 'FreeBar uninstalled. Project source and user files were left untouched.\n'

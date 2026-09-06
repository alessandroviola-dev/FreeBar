#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$ROOT/scripts/common.sh"

[[ $(uname -m) == arm64 ]] || fail 'Run from a native Apple Silicon terminal (not Rosetta).'
command -v swift >/dev/null || fail 'Install Apple Command Line Tools: xcode-select --install'
xcode-select -p >/dev/null 2>&1 || fail 'Install Apple Command Line Tools: xcode-select --install'
xcrun --sdk macosx --show-sdk-path >/dev/null || fail 'A macOS SDK is required.'
xcrun --find codesign >/dev/null || fail 'codesign is required.'
check_existing_app

printf 'Building FreeBar (release, arm64)…\n'
cd "$ROOT"
swift build -c release --arch arm64
BIN=$(swift build -c release --arch arm64 --show-bin-path)
[[ -x "$BIN/FreeBar" ]] || fail 'Build did not produce the FreeBar executable.'

mkdir -p "$HOME/Applications"
STAGE=$(mktemp -d "$HOME/Applications/.FreeBar-install.XXXXXX")
BACKUP="$STAGE/previous.app"
NEW="$STAGE/FreeBar.app"
REPLACED=0
COMMITTED=0
cleanup() {
    local result=$?
    if [[ $COMMITTED == 0 && $REPLACED == 1 ]]; then
        stop_installed_app
        rm -rf -- "$APP"
        if [[ -d "$BACKUP" ]]; then
            mv -- "$BACKUP" "$APP"
            /usr/bin/open "$APP" || true
        fi
    fi
    rm -rf -- "$STAGE"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$NEW/Contents/MacOS" "$NEW/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$NEW/Contents/Info.plist"
cp "$BIN/FreeBar" "$NEW/Contents/MacOS/FreeBar"
chmod 755 "$NEW/Contents/MacOS/FreeBar"
plutil -lint "$NEW/Contents/Info.plist" >/dev/null
# Stable local designated requirement keeps this private app's identity across builds.
# This is ad-hoc signing, not Developer ID signing or notarization.
codesign --force --sign - --identifier "$BUNDLE_ID" \
    --requirements "=designated => identifier \"$BUNDLE_ID\"" "$NEW"
codesign --verify --strict "$NEW"

stop_installed_app
# Both renames occur on the same filesystem; keep the old bundle until launch succeeds.
if [[ -e "$APP" ]]; then mv -- "$APP" "$BACKUP"; fi
REPLACED=1
mv -- "$NEW" "$APP"
/usr/bin/open "$APP"
sleep 2
[[ -n $(installed_pids) ]] || fail 'The installed application did not remain running.'
COMMITTED=1
printf 'FreeBar installed and running: %s\n' "$APP"

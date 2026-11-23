#!/bin/bash
# Builds Cat.pock (a Pock widget) and optionally installs it.
#   ./build.sh              build only
#   ./build.sh --install    build, back up Pock prefs, install, add to the Touch Bar, relaunch Pock
#   ./build.sh --uninstall  remove the widget and take it off the Touch Bar layout
#
# The cat sprites are not included. Download the free "Cat 2D Pixel Art" pack by Mattz Art from
# https://xzany.itch.io/cat-2d-pixel-art and put the zip next to this script (or set CAT_ZIP=/path/to.zip,
# or CAT_SPRITES=/path/to/Sprites for an already-extracted folder).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SPRITES_URL="https://xzany.itch.io/cat-2d-pixel-art"

find_pock() {
  if [[ -n "${POCK_APP:-}" ]]; then echo "$POCK_APP"; return; fi
  for p in "/Applications/Pock.app" "$HOME/Applications/Pock.app" "$HOME/Downloads/Pock.app"; do
    [[ -d "$p" ]] && { echo "$p"; return; }
  done
  mdfind "kMDItemCFBundleIdentifier == 'com.pigigaldi.pock'" 2>/dev/null | grep -v '/AppTranslocation/' | head -1
}

find_zip() {
  if [[ -n "${CAT_ZIP:-}" ]]; then echo "$CAT_ZIP"; return; fi
  for dir in "$ROOT" "$ROOT/.." "$HOME/Downloads"; do
    for name in "FULL_Cat 2D Pixel Art.zip" "FREE_Cat 2D Pixel Art.zip"; do
      [[ -f "$dir/$name" ]] && { echo "$dir/$name"; return; }
    done
  done
}

POCK_APP="$(find_pock)"
ZIP="$(find_zip)"
BUILD="$ROOT/build"
BUNDLE="$BUILD/Cat.pock"
WIDGETS="$HOME/Library/Application Support/Pock/Widgets"
WIDGET_ID="com.local.pock.Cat"

quit_pock() {
  osascript -e 'tell application id "com.pigigaldi.pock" to quit' >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Pock >/dev/null || return 0; sleep 0.5; done
  pkill -x Pock || true
  sleep 1
}

set_cat_in_layout() {  # $1 = add | remove
  defaults export com.pigigaldi.pock - | /usr/bin/python3 -I -c '
import plistlib, sys
action = sys.argv[1]
prefs = plistlib.loads(sys.stdin.buffer.read())
cfg = prefs.setdefault("NSTouchBarConfig: PockTouchBarController", {})
items = [i for i in cfg.get("CurrentItems", []) if i != "com.local.pock.Cat"]
if action == "add":
    pos = items.index("com.pigigaldi.pock.Dock") if "com.pigigaldi.pock.Dock" in items else len(items)
    items.insert(pos, "com.local.pock.Cat")
cfg["CurrentItems"] = items
sys.stdout.buffer.write(plistlib.dumps(prefs))
' "$1" | defaults import com.pigigaldi.pock -
}

if [[ "${1:-}" == "--uninstall" ]]; then
  quit_pock
  rm -rf "$WIDGETS/Cat.pock"
  set_cat_in_layout remove
  open "$POCK_APP"
  echo "Cat widget removed from Pock and from the Touch Bar layout."
  exit 0
fi

[[ -n "$POCK_APP" && -d "$POCK_APP" ]] || { echo "Pock.app not found. Install Pock from https://pock.app or set POCK_APP=/path/to/Pock.app"; exit 1; }
if [[ -z "${CAT_SPRITES:-}" && ( -z "$ZIP" || ! -f "$ZIP" ) ]]; then
  echo "Cat sprites not found."
  echo "Download the free \"Cat 2D Pixel Art\" pack by Mattz Art from:"
  echo "  $SPRITES_URL"
  echo "and put the zip next to build.sh (or set CAT_ZIP=/path/to.zip or CAT_SPRITES=/path/to/Sprites)."
  exit 1
fi

echo "==> Preparing build folder"
rm -rf "$BUILD"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources/Sprites"

echo "==> Adding sprites"
if [[ -n "${CAT_SPRITES:-}" ]]; then
  cp "$CAT_SPRITES"/*.png "$BUNDLE/Contents/Resources/Sprites/"
else
  unzip -o -j -q "$ZIP" "*/Sprites/*.png" -d "$BUNDLE/Contents/Resources/Sprites"
fi
for f in "IDLE" "WALK" "RUN" "ATTACK 1" "HURT" "JUMP" "RUNNING JUMP"; do
  [[ -f "$BUNDLE/Contents/Resources/Sprites/$f.png" ]] || { echo "Missing sprite sheet: $f.png"; exit 1; }
done

# Builds the widget binary for one architecture into build/arch/<arch>/Cat. Returns non-zero on failure.
build_arch() {
  local arch="$1" out="$BUILD/arch/$1"
  mkdir -p "$out/modules"
  swiftc -emit-module -parse-as-library -swift-version 5 -target "$arch-apple-macos11" \
    -module-name PockKit -suppress-warnings \
    "$ROOT/vendor/pockkit/PockKit/Sources/Protocols/PKWidget.swift" \
    "$ROOT/vendor/pockkit/PockKit/Sources/Protocols/PKWidgetPreference.swift" \
    -emit-module-path "$out/modules/PockKit.swiftmodule" || return 1
  swiftc -emit-library -parse-as-library -swift-version 5 -O -target "$arch-apple-macos11" \
    -module-name Cat \
    -I "$out/modules" \
    -F "$POCK_APP/Contents/Frameworks" -framework PockKit \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -Xlinker -install_name -Xlinker @rpath/Cat.pock/Contents/MacOS/Cat \
    "$ROOT"/Sources/*.swift \
    -o "$out/Cat" || return 1
}

# Universal build: Apple silicon and Intel Touch Bar MacBooks.
echo "==> Compiling widget (Apple silicon + Intel)"
BUILT=()
for arch in arm64 x86_64; do
  if build_arch "$arch"; then BUILT+=("$BUILD/arch/$arch/Cat"); else echo "warning: could not build for $arch"; fi
done
if [[ ${#BUILT[@]} -eq 0 ]]; then echo "Build failed for every architecture."; exit 1; fi
lipo -create "${BUILT[@]}" -output "$BUNDLE/Contents/MacOS/Cat"

cp "$ROOT/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$BUNDLE"
codesign --verify --verbose=1 "$BUNDLE"
echo "Built $BUNDLE ($(lipo -archs "$BUNDLE/Contents/MacOS/Cat"))"

if [[ "${1:-}" == "--install" ]]; then
  echo "==> Backing up Pock preferences"
  mkdir -p "$ROOT/backups"
  BACKUP="$ROOT/backups/pock-prefs-$(date +%Y%m%d-%H%M%S).plist"
  defaults export com.pigigaldi.pock "$BACKUP"
  echo "Backup: $BACKUP"

  echo "==> Quitting Pock"
  quit_pock

  echo "==> Installing widget"
  mkdir -p "$WIDGETS"
  rm -rf "$WIDGETS/Cat.pock"
  cp -R "$BUNDLE" "$WIDGETS/"

  echo "==> Adding the cat between Status and Dock"
  set_cat_in_layout add
  defaults read com.pigigaldi.pock "NSTouchBarConfig: PockTouchBarController"

  echo "==> Relaunching Pock"
  open "$POCK_APP"
  echo "Done. The cat should appear on your Touch Bar between Status and the Dock."
fi

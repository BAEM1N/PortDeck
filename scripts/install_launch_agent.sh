#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="PortDeck"
LEGACY_APP_NAME="PortMenuBar"
APP_SRC="$ROOT_DIR/dist/$APP_NAME.app"
APP_DST="$HOME/Applications/$APP_NAME.app"
LEGACY_APP_DST="$HOME/Applications/$LEGACY_APP_NAME.app"
LABEL="com.baem1n.portdeck"
LEGACY_LABEL="com.baem1n.portmenubar"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LEGACY_PLIST_PATH="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
BIN_PATH="$APP_DST/Contents/MacOS/$APP_NAME"

if [[ ! -x "$APP_SRC/Contents/MacOS/$APP_NAME" ]]; then
  echo "App bundle not found at $APP_SRC"
  echo "Run: ./scripts/package_app.sh"
  exit 1
fi

mkdir -p "$HOME/Applications"
mkdir -p "$HOME/Library/LaunchAgents"

launchctl bootout "gui/$UID" "$LEGACY_PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$LEGACY_PLIST_PATH"
rm -rf "$LEGACY_APP_DST"

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN_PATH</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>/tmp/$LABEL.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/$LABEL.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$UID" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$PLIST_PATH"
launchctl enable "gui/$UID/$LABEL"
launchctl kickstart -k "gui/$UID/$LABEL"

echo "Installed app to: $APP_DST"
echo "Installed LaunchAgent: $PLIST_PATH"

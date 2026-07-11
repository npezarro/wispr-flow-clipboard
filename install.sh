#!/bin/bash
# Installs the Wispr Flow -> clipboard watcher as a per-user LaunchAgent.
# Idempotent: safe to re-run to upgrade.
set -euo pipefail

LABEL="com.wispr-flow.clipboard"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DST="$BIN_DIR/wispr-clip-watch.sh"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_DST="$AGENT_DIR/$LABEL.plist"
LOG="$HOME/Library/Logs/wispr-flow-clipboard.log"

command -v sqlite3 >/dev/null || { echo "error: sqlite3 not found"; exit 1; }

echo "Installing watcher script -> $SCRIPT_DST"
mkdir -p "$BIN_DIR" "$AGENT_DIR" "$(dirname "$LOG")"
cp "$SRC_DIR/wispr-clip-watch.sh" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"

echo "Generating LaunchAgent -> $PLIST_DST"
sed -e "s#__PREFIX__#$HOME#g" -e "s#__LOG__#$LOG#g" \
    "$SRC_DIR/com.wispr-flow.clipboard.plist" > "$PLIST_DST"

echo "Loading LaunchAgent"
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST_DST"

sleep 1
if launchctl print "gui/$UID_NUM/$LABEL" 2>/dev/null | grep -q "state = running"; then
  echo "Installed and running. Dictate in Wispr Flow; the text lands on your clipboard."
  echo "Log: $LOG"
else
  echo "warning: service did not report running; check $LOG"
fi

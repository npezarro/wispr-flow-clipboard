#!/bin/bash
# Removes the Wispr Flow -> clipboard watcher.
set -euo pipefail

LABEL="com.wispr-flow.clipboard"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "$HOME/.local/bin/wispr-clip-watch.sh"

echo "Uninstalled. (Log at ~/Library/Logs/wispr-flow-clipboard.log left in place; remove manually if desired.)"

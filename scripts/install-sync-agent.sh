#!/usr/bin/env bash
#
# Installs sync-main.sh as a macOS LaunchAgent so it runs without a terminal open.
#
#   ./scripts/install-sync-agent.sh            # install, checking every 2 minutes
#   ./scripts/install-sync-agent.sh --uninstall
#
# A LaunchAgent rather than a long-running loop: launchd restarts it after a
# reboot, and a single-shot script on an interval leaves nothing running between
# checks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.shawnsemmes.tallyist.sync"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
INTERVAL="${SYNC_INTERVAL:-120}"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed ${LABEL}."
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>${REPO_ROOT}/scripts/sync-main.sh</string>
	</array>
	<key>StartInterval</key>
	<integer>${INTERVAL}</integer>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>${REPO_ROOT}/.git/sync-main.log</string>
	<key>StandardErrorPath</key>
	<string>${REPO_ROOT}/.git/sync-main.log</string>
	<key>WorkingDirectory</key>
	<string>${REPO_ROOT}</string>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed ${LABEL}, checking every ${INTERVAL}s."
echo "Log:       ${REPO_ROOT}/.git/sync-main.log"
echo "Uninstall: ./scripts/install-sync-agent.sh --uninstall"

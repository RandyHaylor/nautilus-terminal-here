#!/usr/bin/env bash
#
# uninstall.sh — remove the Nautilus "terminal here" tool.
#
# Stops/disables the service, removes installed files and the path cache, and
# reminds you to remove the GNOME custom shortcut by hand.

set -euo pipefail

bin_dir="$HOME/.local/bin"
service_dest="$HOME/.config/systemd/user/nautilus-path-watcher.service"
cache_dir="$HOME/.cache/nautilus-paths"

# 1. Disable and stop the service (ignore failure if already gone).
systemctl --user disable --now nautilus-path-watcher.service 2>/dev/null || true
echo "[ok] Service disabled/stopped."

# 2. Remove installed files.
rm -f "$service_dest"
rm -f "$bin_dir/terminal-here.sh"
rm -f "$bin_dir/nautilus-path-watcher.sh"
rm -f "$bin_dir/nautilus-path-watcher.py"
rm -rf "$cache_dir"
echo "[ok] Removed installed scripts, service unit, and path cache."

# 3. Reload systemd so the removed unit is forgotten.
systemctl --user daemon-reload
echo "[ok] systemd user daemon reloaded."

# 4. Remind about the manual shortcut.
cat <<'EOF'

Note: the GNOME custom keyboard shortcut (Super+T -> Terminal Here) is not
removed automatically. Remove it by hand:

  Settings -> Keyboard -> View and Customize Shortcuts
    -> Custom Shortcuts -> (select "Terminal Here") -> remove

Uninstall complete.
EOF

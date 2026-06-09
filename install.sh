#!/usr/bin/env bash
#
# install.sh — install the Nautilus "terminal here" tool.
#
# Installs the launcher + watcher into ~/.local/bin, installs and starts the
# systemd user service, then prints manual instructions for binding the
# Super+T keyboard shortcut. The shortcut is intentionally NOT set
# automatically unless you pass --set-shortcut (see below).

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$repo_dir/src"
systemd_src="$repo_dir/systemd/nautilus-path-watcher.service"

bin_dir="$HOME/.local/bin"
service_dir="$HOME/.config/systemd/user"
service_dest="$service_dir/nautilus-path-watcher.service"

launcher_path="$bin_dir/terminal-here.sh"

set_shortcut=false
if [[ "${1:-}" == "--set-shortcut" ]]; then
    set_shortcut=true
fi

# 1. Verify X11.
if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    echo "ERROR: XDG_SESSION_TYPE is '${XDG_SESSION_TYPE:-unset}', expected 'x11'." >&2
    echo "This tool only works on an X11 session (Wayland is unsupported)." >&2
    echo "Log out and choose 'Ubuntu on Xorg' at the login screen, then retry." >&2
    exit 1
fi
echo "[ok] X11 session detected."

# 2. Verify dependencies.
missing=()
command -v xdotool        >/dev/null 2>&1 || missing+=("xdotool")
command -v xprop          >/dev/null 2>&1 || missing+=("xprop (x11-utils)")
command -v dbus-monitor   >/dev/null 2>&1 || missing+=("dbus-monitor (dbus)")
command -v gnome-terminal >/dev/null 2>&1 || missing+=("gnome-terminal")
command -v python3        >/dev/null 2>&1 || missing+=("python3")
command -v systemctl      >/dev/null 2>&1 || missing+=("systemctl")

if (( ${#missing[@]} > 0 )); then
    echo "ERROR: missing required dependencies:" >&2
    for m in "${missing[@]}"; do
        echo "  - $m" >&2
    done
    # 3. Print apt command.
    echo >&2
    echo "Install them with:" >&2
    echo "  sudo apt install xdotool x11-utils dbus gnome-terminal python3" >&2
    exit 1
fi
echo "[ok] All dependencies present."

# 4. Install scripts to ~/.local/bin (preserving executable bits via install -m).
mkdir -p "$bin_dir"
install -m 0755 "$src_dir/terminal-here.sh"          "$bin_dir/terminal-here.sh"
install -m 0755 "$src_dir/nautilus-path-watcher.sh"  "$bin_dir/nautilus-path-watcher.sh"
install -m 0755 "$src_dir/nautilus-path-watcher.py"  "$bin_dir/nautilus-path-watcher.py"
echo "[ok] Installed scripts to $bin_dir"

# 5. Install the systemd user service.
# 6. The shipped unit already uses %h/.local/bin/nautilus-path-watcher.sh, so
#    no rewrite is needed; install it verbatim.
mkdir -p "$service_dir"
install -m 0644 "$systemd_src" "$service_dest"
echo "[ok] Installed service to $service_dest"

# 7. Enable and start the watcher.
systemctl --user daemon-reload
systemctl --user enable --now nautilus-path-watcher.service
echo "[ok] Enabled and started nautilus-path-watcher.service"

# 8. Print manual shortcut instructions (or set it if requested).
if $set_shortcut; then
    echo
    echo "[--set-shortcut] Attempting to bind Super+T via gsettings..."
    base="org.gnome.settings-daemon.plugins.media-keys"
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal-here/"
    gsettings set "$base" custom-keybindings "['$path']"
    gsettings set "$base.custom-keybinding:$path" name 'Terminal Here'
    gsettings set "$base.custom-keybinding:$path" command "$launcher_path"
    gsettings set "$base.custom-keybinding:$path" binding '<Super>t'
    echo "[ok] Bound Super+T to $launcher_path (if it didn't take, set it manually below)."
else
    cat <<EOF

============================================================
 Final manual step: bind the keyboard shortcut
============================================================
 Settings -> Keyboard -> View and Customize Shortcuts
   -> Custom Shortcuts -> Add Shortcut

   Name:     Terminal Here
   Command:  $launcher_path
   Shortcut: Super+T
============================================================

 (Manual is the default and is safer. Re-run with
  './install.sh --set-shortcut' to attempt it automatically.)
EOF
fi

echo
echo "Done. Open a Nautilus window, focus it, and press Super+T."

#!/usr/bin/env bash
#
# terminal-here.sh
#
# Opens gnome-terminal in the folder shown by the currently focused Nautilus
# window. Falls back to a plain gnome-terminal if the focused window is not
# Nautilus, or if no cached path is available for it.
#
# How the X11 -> Nautilus-window mapping works:
#   - Every GTK window on X11 carries a window property named
#     _GTK_WINDOW_OBJECT_PATH, e.g. "/org/gnome/Nautilus/window/3".
#   - The trailing integer ("3") is Nautilus' internal window id.
#   - The companion watcher (nautilus-path-watcher.py) listens for Nautilus
#     D-Bus signals and writes the current folder of each window to:
#         ~/.cache/nautilus-paths/<window-id>
#   - So: focused X11 window -> object path -> window id -> cache file -> path.
#
# This avoids clipboard hacks and menu automation entirely.

set -u

cache="$HOME/.cache/nautilus-paths"

# Ask X11 which window currently has input focus, then dump its properties.
active_id="$(xdotool getactivewindow 2>/dev/null || true)"
props="$(xprop -id "$active_id" 2>/dev/null || true)"

# Only attempt the Nautilus path lookup if the focused window is Nautilus.
if echo "$props" | grep -qi 'WM_CLASS.*Nautilus'; then
    # Extract the GTK object path and reduce it to the trailing window id.
    object_path="$(echo "$props" | sed -n 's/^_GTK_WINDOW_OBJECT_PATH.*= "\(.*\)"/\1/p')"
    win_id="${object_path##*/}"

    # Read the folder the watcher cached for this specific window id.
    # Per-window caching is what makes duplicate basenames (aa1/src vs aa2/src)
    # resolve correctly: each Nautilus window has its own cache file.
    path="$(cat "$cache/$win_id" 2>/dev/null || true)"

    if [[ -d "$path" ]]; then
        gnome-terminal --working-directory="$path" &
        exit 0
    fi
fi

# Fallback: not Nautilus, or no usable cached path.
gnome-terminal &

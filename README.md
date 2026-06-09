# nautilus-terminal-here

Open a terminal in the folder shown by the **currently focused Nautilus
window** with a single keyboard shortcut (Super+T).

It correctly handles **multiple Nautilus windows at once**, including windows
showing folders with **duplicate basenames** (e.g. `aa1/src` and `aa2/src`):
each window is tracked by its own internal id, so the right path always wins.

## Requirements

- **Ubuntu GNOME** with **Nautilus** (the GNOME Files file manager).
- **X11 session.** Check with `echo "$XDG_SESSION_TYPE"` — it must print `x11`.
- `gnome-terminal`, `xdotool`, `xprop` (from `x11-utils`), `dbus-monitor`
  (from `dbus`), `python3`, and `systemctl --user`.

### Wayland is not supported

This tool finds the focused window by inspecting X11 window properties with
`xdotool` and `xprop`. Under Wayland, that focused-window inspection is not
reliable (clients cannot freely query each other's surfaces), so the lookup
does not work. Use an **X11 / "Ubuntu on Xorg"** session.

## How it works

There are no clipboard hacks and no menu automation. The design maps the
focused X11 window to a cached folder path:

1. A background **watcher** (systemd user service) runs `dbus-monitor` and
   listens for Nautilus' `org.freedesktop.FileManager1` `PropertiesChanged`
   signals, which carry `OpenWindowsWithLocations` — the folder each open
   Nautilus window is showing.
2. The watcher caches each window's folder to
   `~/.cache/nautilus-paths/<window-id>` (one file per window — this is what
   makes duplicate basenames resolve correctly).
3. When you press Super+T, the **launcher** reads the focused X11 window's
   `_GTK_WINDOW_OBJECT_PATH` property (e.g.
   `/org/gnome/Nautilus/window/3`), takes the trailing window id, reads the
   matching cache file, and runs
   `gnome-terminal --working-directory="<cached path>"`.
4. If the focused window is not Nautilus, or no cached path is available, it
   just opens a normal `gnome-terminal`.

## Install

```bash
git clone https://github.com/RandyHaylor/nautilus-terminal-here.git
cd nautilus-terminal-here
./install.sh
```

The installer verifies the X11 session and dependencies, installs the scripts
to `~/.local/bin`, installs and starts the systemd user service, and prints
the final manual step:

> Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts → Add Shortcut
> - **Name:** Terminal Here
> - **Command:** `/home/<user>/.local/bin/terminal-here.sh`
> - **Shortcut:** Super+T

Binding the shortcut is left manual on purpose (safer than scripting GNOME
settings). If you prefer, `./install.sh --set-shortcut` will attempt to bind
Super+T via `gsettings`.

## Uninstall

```bash
./uninstall.sh
```

This disables/removes the service, the installed scripts, and the path cache.
Remove the GNOME custom shortcut manually (the script reminds you how).

## Troubleshooting

```bash
# Is the watcher service healthy?
systemctl --user status nautilus-path-watcher.service

# Follow the watcher logs live.
journalctl --user -u nautilus-path-watcher.service -f

# Are the watcher and dbus-monitor processes actually running?
pgrep -af 'nautilus-path-watcher|dbus-monitor'

# What paths has the watcher cached, per window?
find ~/.cache/nautilus-paths -maxdepth 1 -type f -print -exec cat {} \;

# Click a Nautilus window when the cursor turns into crosshairs, then look
# for the _GTK_WINDOW_OBJECT_PATH line to confirm the window id.
xprop | grep _GTK_WINDOW_OBJECT_PATH
```

## License

MIT — see [LICENSE](LICENSE).

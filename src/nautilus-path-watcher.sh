#!/usr/bin/env bash
#
# nautilus-path-watcher.sh
#
# Long-running watcher started by the systemd user service. It hands off
# (via exec) to the Python watcher, which runs dbus-monitor itself and
# maintains the per-window path cache.
#
# Nautilus implements the org.freedesktop.FileManager1 interface and emits
# PropertiesChanged signals whose body includes OpenWindowsWithLocations:
# a mapping of window object paths to the folder URIs they currently display.
#
# exec matters: it makes the Python process the service's main process, so
# if it dies systemd notices and restarts the unit.

mkdir -p "$HOME/.cache/nautilus-paths"

exec "$HOME/.local/bin/nautilus-path-watcher.py"

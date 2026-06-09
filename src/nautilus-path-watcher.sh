#!/usr/bin/env bash
#
# nautilus-path-watcher.sh
#
# Long-running watcher started by the systemd user service. It tails the
# session bus for org.freedesktop.DBus.Properties signals and pipes them into
# the Python parser, which maintains the per-window path cache.
#
# Nautilus implements the org.freedesktop.FileManager1 interface and emits
# PropertiesChanged signals whose body includes OpenWindowsWithLocations:
# a mapping of window object paths to the folder URIs they currently display.

mkdir -p "$HOME/.cache/nautilus-paths"

# stdbuf -oL forces line buffering so the parser sees signals promptly.
stdbuf -oL dbus-monitor "type='signal',interface='org.freedesktop.DBus.Properties'" \
  | "$HOME/.local/bin/nautilus-path-watcher.py"

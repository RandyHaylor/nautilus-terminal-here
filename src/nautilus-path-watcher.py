#!/usr/bin/env python3
#
# nautilus-path-watcher.py
#
# Runs `dbus-monitor` as a child process, reads its line-oriented output and
# maintains a per-Nautilus-window cache of the folder each window is showing.
#
# The relevant signal body (OpenWindowsWithLocations) renders in dbus-monitor
# output as alternating strings: a window object path followed by its folder
# URI, e.g.
#
#     string "/org/gnome/Nautilus/window/3"
#     ...
#     string "file:///home/user/aa1/src"
#
# We track the most recently seen window object path, and when the next
# file:// URI appears we write it to the cache file for that window id. Each
# window has its own cache file, so duplicate folder basenames across
# different windows (aa1/src vs aa2/src) never collide.
#
# Robustness:
#   - This script owns dbus-monitor. If dbus-monitor exits, this script exits
#     non-zero; if this script dies, systemd tears down the whole unit. Either
#     way the service stops and `Restart=always` brings it back, instead of
#     leaving a half-dead pipeline that looks healthy.
#   - A bad line or failed write is logged (to the journal) and skipped rather
#     than killing the watcher.
#   - Cache files are written atomically (temp file + rename), so a failure
#     mid-write never leaves an empty or truncated cache file.

import os
import re
import subprocess
import sys
import traceback
import urllib.parse

cache = os.path.expanduser("~/.cache/nautilus-paths")
os.makedirs(cache, exist_ok=True)

# Matches a Nautilus window object path; group(2) is the trailing window id.
window_re = re.compile(r'^\s*string "(/org/gnome/Nautilus/window/(\d+))"')
# Matches a file:// folder URI.
uri_re = re.compile(r'^\s*string "(file://[^"]+)"')

MONITOR_CMD = [
    # stdbuf -oL forces line buffering so signals arrive promptly.
    "stdbuf", "-oL",
    "dbus-monitor",
    "type='signal',interface='org.freedesktop.DBus.Properties'",
]


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def write_cache(win_id, path):
    dest = os.path.join(cache, win_id)
    tmp = dest + ".tmp"
    with open(tmp, "w", encoding="utf-8", errors="replace") as f:
        f.write(path + "\n")
    os.replace(tmp, dest)


def main():
    proc = subprocess.Popen(
        MONITOR_CMD,
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    log(f"watching (dbus-monitor pid {proc.pid})")

    current_window = None
    for line in proc.stdout:
        try:
            wm = window_re.match(line)
            if wm:
                current_window = wm.group(2)
                continue

            um = uri_re.match(line)
            if um and current_window:
                uri = um.group(1)
                # Strip the "file://" scheme (7 chars) and percent-decode.
                path = urllib.parse.unquote(uri[7:])
                write_cache(current_window, path)
                current_window = None
        except Exception:
            log(f"error handling line {line!r}; skipping")
            traceback.print_exc(file=sys.stderr)
            current_window = None

    rc = proc.wait()
    log(f"dbus-monitor exited with code {rc}; exiting so systemd restarts us")
    sys.exit(1)


if __name__ == "__main__":
    main()

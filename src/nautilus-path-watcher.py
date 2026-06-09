#!/usr/bin/env python3
#
# nautilus-path-watcher.py
#
# Reads the line-oriented output of `dbus-monitor` on stdin and maintains a
# per-Nautilus-window cache of the folder each window is showing.
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

import os
import re
import sys
import urllib.parse

cache = os.path.expanduser("~/.cache/nautilus-paths")
os.makedirs(cache, exist_ok=True)

# Matches a Nautilus window object path; group(2) is the trailing window id.
window_re = re.compile(r'^\s*string "(/org/gnome/Nautilus/window/(\d+))"')
# Matches a file:// folder URI.
uri_re = re.compile(r'^\s*string "(file://[^"]+)"')

current_window = None

for line in sys.stdin:
    wm = window_re.match(line)
    if wm:
        current_window = wm.group(2)
        continue

    um = uri_re.match(line)
    if um and current_window:
        uri = um.group(1)
        # Strip the "file://" scheme (7 chars) and percent-decode the path.
        path = urllib.parse.unquote(uri[7:])
        with open(os.path.join(cache, current_window), "w") as f:
            f.write(path + "\n")
        current_window = None

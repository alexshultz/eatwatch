#!/bin/sh
# The app icon is stored as ASCII so the repository can carry the exact bytes.
# The iPhone and Watch catalogs use the same PNG.
set -e
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
base64 -D -i "$root/Supporting/AppIcon.base64" -o "$root/EatWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cp "$root/EatWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png" \
  "$root/EatWatchWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

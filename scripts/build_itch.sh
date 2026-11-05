#!/usr/bin/env bash
# Builds the web version and zips it for itch.io (upload as an HTML game,
# tick "This file will be played in the browser").
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn
mkdir -p dist
version=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
out="dist/tiny-week-zine-web-$version.zip"
rm -f "$out"
(cd build/web && zip -qr "../../$out" .)
echo "$out ($(du -h "$out" | cut -f1))"

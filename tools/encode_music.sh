#!/bin/sh
# Re-encodes downloaded music (assets/music/*.src.mp3) to small mono mp3s for the web build.
# Tracks are Kevin MacLeod (incompetech.com), CC BY 4.0: see CREDITS.md.
cd "$(dirname "$0")/../assets/music" || exit 1
for f in *.src.mp3; do
	[ -e "$f" ] || continue
	n="${f%.src.mp3}"
	ffmpeg -loglevel error -y -i "$f" -ac 1 -ar 32000 -b:a 64k "$n.mp3" && rm "$f"
done
ls -la

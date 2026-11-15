#!/bin/sh
# Rebuild farlanding_icon.png (512 px) and preview sizes from the SVG.
# Needs rsvg-convert (brew install librsvg).
set -e
cd "$(dirname "$0")"
rsvg-convert -w 512 -h 512 farlanding_icon.svg -o farlanding_icon.png

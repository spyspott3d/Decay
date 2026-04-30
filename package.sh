#!/bin/bash
set -e

VERSION=$(grep "^## Version:" Decay/Decay.toc | awk '{print $3}')
ZIP_NAME="Decay-${VERSION}.zip"

rm -f "$ZIP_NAME"

cd "$(dirname "$0")"
zip -r "$ZIP_NAME" Decay/ Decay_Options/ \
  -x "Decay/.git*" \
  -x "Decay/*.md" \
  -x "Decay/.luacheckrc" \
  -x "Decay_Options/.git*" \
  -x "Decay_Options/*.md"

echo "Built: $ZIP_NAME"

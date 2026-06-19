#!/usr/bin/env bash
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get

if [ -z "${CLOUDINARY_CLOUD_NAME:-}" ]; then
  echo "Missing required Netlify environment variable: CLOUDINARY_CLOUD_NAME"
  exit 1
fi

if [ -z "${CLOUDINARY_UPLOAD_PRESET:-}" ]; then
  echo "Missing required Netlify environment variable: CLOUDINARY_UPLOAD_PRESET"
  exit 1
fi

flutter build web --release --base-href / \
  --dart-define=CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-}" \
  --dart-define=CLOUDINARY_UPLOAD_PRESET="${CLOUDINARY_UPLOAD_PRESET:-}" \
  --dart-define=CLOUDINARY_DOCUMENT_UPLOAD_PRESET="${CLOUDINARY_DOCUMENT_UPLOAD_PRESET:-}"

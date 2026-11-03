#!/bin/bash
set -e

git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=DEMO=false \
  --dart-define=API_URL=https://landview-api.onrender.com
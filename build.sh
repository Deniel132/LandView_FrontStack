set -e

FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  rm -rf "$FLUTTER_DIR"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=DEMO=false \
  --dart-define=API_URL=https://landview-api.onrender.com
#!/usr/bin/env bash
# CI: tải Godot (bản editor) và export templates đúng phiên bản, in đường dẫn file chạy editor.
# Dùng: tools/ci/install_godot.sh linux|macos   (biến GODOT_VERSION, mặc định 4.7.2)
set -euo pipefail
VERSION=${GODOT_VERSION:-4.7.2}
OS=$1
BASE="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
DEST="$HOME/godot-ci"
mkdir -p "$DEST"
cd "$DEST"
case "$OS" in
  linux)
    TEMPLATES="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
    [ -x godot ] || { curl -fsSL -o g.zip "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip"; unzip -q g.zip; mv "Godot_v${VERSION}-stable_linux.x86_64" godot; rm g.zip; }
    BIN="$DEST/godot" ;;
  macos)
    TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/${VERSION}.stable"
    [ -d Godot.app ] || { curl -fsSL -o g.zip "$BASE/Godot_v${VERSION}-stable_macos.universal.zip"; unzip -q g.zip; rm g.zip; }
    BIN="$DEST/Godot.app/Contents/MacOS/Godot" ;;
  *) echo "hệ điều hành không hỗ trợ: $OS" >&2; exit 2 ;;
esac
if [ ! -f "$TEMPLATES/version.txt" ]; then
  curl -fsSL -o t.tpz "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -q t.tpz
  mkdir -p "$TEMPLATES"
  mv templates/* "$TEMPLATES/"
  rm -rf templates t.tpz
fi
echo "$BIN"

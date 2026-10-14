#!/usr/bin/env bash
# Export bản Web rồi đẩy lên repo public chỉ chứa bản build (GitHub Pages). Mã nguồn vẫn ở repo private.
# Dùng: tools/deploy_web.sh            (repo mặc định: quzkhanh/neon-harbor-web, nhánh main, thư mục gốc)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
REPO=${WEB_REPO:-quzkhanh/neon-harbor-web}
SOURCE=$(git rev-parse --short HEAD 2>/dev/null || echo "chưa commit")

mkdir -p build/web
"$GODOT" --headless --path game --export-release "Web" ../build/web/index.html
for f in index.html index.wasm index.pck index.js; do [ -f "build/web/$f" ] || { echo "thiếu build/web/$f"; exit 1; }; done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
gh repo clone "$REPO" "$WORK" -- --quiet
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r build/web/. "$WORK/"
touch "$WORK/.nojekyll"  # phục vụ file nguyên trạng, không qua Jekyll
git -C "$WORK" add -A
if git -C "$WORK" diff --cached --quiet; then echo "Bản build không đổi, không cần deploy."; exit 0; fi
git -C "$WORK" commit -q -m "Deploy Neon Harbor web build from source $SOURCE"
git -C "$WORK" push -q origin HEAD:main
echo "Đã đẩy lên https://github.com/$REPO — trang: https://${REPO%%/*}.github.io/${REPO##*/}/"

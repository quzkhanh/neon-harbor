#!/usr/bin/env bash
# SPEC mục 12: export Linux + Web, chụp ảnh bản Linux trong thành phố, kiểm tra bản Web (curl 200 + chơi thử trong Chrome),
# ghi kích thước .wasm/.pck trước và sau gzip.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
fail=0
mkdir -p build/linux build/web reference/shots

echo "== Export Linux"
"$GODOT" --headless --path game --export-release "Linux" ../build/linux/NeonHarbor.x86_64 2>&1 | grep -E "ERROR|error" | head
[ -x build/linux/NeonHarbor.x86_64 ] && ls -la build/linux/NeonHarbor.x86_64 || { echo "FAIL: thiếu file Linux"; fail=1; }

echo "== Export Web"
"$GODOT" --headless --path game --export-release "Web" ../build/web/index.html 2>&1 | grep -E "ERROR|error" | head
for f in index.html index.wasm index.pck; do [ -f "build/web/$f" ] || { echo "FAIL: thiếu build/web/$f"; fail=1; }; done

echo "== Bản Linux chụp ảnh trong thành phố"
rm -f reference/shots/export_linux_city_walk_en.png
rm -rf build/shots; DISPLAY=${DISPLAY:-:0} timeout 90 build/linux/NeonHarbor.x86_64 -- --shot=city_walk --lang=en --shot-dir="$PWD/build/shots" 2>&1 | grep -E "^SHOT|ERROR" | head -5
if [ -f build/shots/city_walk_en.png ]; then
  cp build/shots/city_walk_en.png reference/shots/export_linux_city_walk_en.png; echo "PASS: có ảnh trong thành phố từ bản export"
else echo "FAIL: bản export không chụp được ảnh trong thành phố"; fail=1; fi

echo "== Kích thước Web"
for f in index.wasm index.pck; do
  raw=$(stat -c %s "build/web/$f"); gz=$(gzip -9 -c "build/web/$f" | wc -c)
  printf "%-11s %8.2f MB  gzip %8.2f MB\n" "$f" "$(echo "$raw/1048576" | bc -l)" "$(echo "$gz/1048576" | bc -l)"
done

echo "== Bản Web: curl + chơi thử trong Chrome"
PORT=8061
python3 -m http.server $PORT -d build/web > /dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1
for f in index.html index.wasm index.pck index.js; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/$f"); echo "$f -> $code"; [ "$code" = 200 ] || fail=1
done
node tools/checks/web_play.mjs "http://localhost:$PORT/index.html" reference/shots || fail=1
[ $fail -eq 0 ] && echo "EXPORT: PASS" || echo "EXPORT: FAIL"
exit $fail

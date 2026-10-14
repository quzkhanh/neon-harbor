#!/usr/bin/env bash
# Chạy toàn bộ kiểm tra tự động (SPEC mục 11, bước 1–8). Exit code khác 0 là fail.
# Ảnh chụp: tools/checks/take_shots.sh · Hiệu năng Web: tools/checks/web_perf.sh · Export: tools/checks/export.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
fail=0
step() { echo; echo "== $1"; }
run_test() {  # run_test <tên> <script> [thư mục game]
  local out code
  out=$(timeout 300 "$GODOT" --headless --path "${3:-game}" -s "res://tests/$2" 2>&1); code=$?
  echo "$out" | grep -E "^(FAIL|  ✗)|PASS|FAIL|^smoke:|^font_coverage:" | head -20
  return $code
}

step "1. Import sạch (xoá game/.godot)"
rm -rf game/.godot
out=$(timeout 300 "$GODOT" --headless --path game --import 2>&1); code=$?
# Godot 4.7.2 thỉnh thoảng abort (134) lúc thoát sau khi import xong, không có dòng ERROR nào (lỗi engine,
# coredump chỉ có frame của engine). Gặp đúng kiểu đó thì import sạch lại một lần và in cảnh báo.
if [ $code -eq 134 ] && ! echo "$out" | grep -q "ERROR"; then
  echo "CẢNH BÁO: Godot abort khi thoát sau import (exit 134, không có ERROR) — import sạch lại lần 2"
  rm -rf game/.godot
  out=$(timeout 300 "$GODOT" --headless --path game --import 2>&1); code=$?
fi
if [ $code -ne 0 ] || echo "$out" | grep -q "ERROR"; then echo "$out" | grep "ERROR" | head; echo "FAIL (exit $code)"; fail=1; else echo "PASS: không có dòng ERROR"; fi

step "2. validate_map.py"
python3 tools/checks/validate_map.py || fail=1

step "3. check_i18n.py"
python3 tools/checks/check_i18n.py || fail=1

step "4. font_coverage.gd"
run_test FONT font_coverage.gd || fail=1

step "5. smoke.gd"
run_test SMOKE smoke.gd || fail=1

step "6. missions.gd"
run_test MISSIONS missions.gd || fail=1

step "7. touch.gd"
run_test TOUCH touch.gd || fail=1

step "7a. Chơi thử như người (phím/chuột thật qua hàng đợi input + 60 giây bấm loạn)"
out=$(timeout 900 "$GODOT" --headless --path game -s res://tests/playtest.gd -- --monkey=60 2>&1); code=$?
echo "$out" | grep -E "^(->|   |FAIL)|PLAYTEST" | head -30
[ $code -eq 0 ] || fail=1

step "7b. Bot tự chơi NV1/NV2 bằng vật lý thật (chỉ báo cáo, không làm fail)"
timeout 600 "$GODOT" --headless --fixed-fps 60 --path game -s res://tests/bot_play.gd 2>&1 | grep -E "^BOT N"

step "8. Thử ngược (bộ kiểm tra phải FAIL khi có lỗi)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
expect_fail() {  # expect_fail <mô tả> <lệnh...>
  if "${@:2}" > "$TMP/out.txt" 2>&1; then echo "  KHÔNG ĐẠT: $1 — bộ kiểm tra vẫn PASS"; fail=1
  else echo "  ĐẠT: $1 -> $(grep -E 'LỖI|FAIL|✗' "$TMP/out.txt" | head -1)"; fi
}
cp -r game "$TMP/hard" && echo '	text = "Hello world"' >> "$TMP/hard/scripts/ui/pause_menu.gd"
expect_fail "chèn chữ viết cứng vào pause_menu.gd" python3 tools/checks/check_i18n.py "$TMP/hard"
cp -r game "$TMP/nokey" && sed -i '/^SHOP_TITLE,/d' "$TMP/nokey/i18n/strings.csv"
expect_fail "xoá khoá SHOP_TITLE khỏi strings.csv" python3 tools/checks/check_i18n.py "$TMP/nokey"
cp -r game "$TMP/broken" && sed -i 's/^func _check_crashes(before: Vector2) -> void:/&\n\tvar oops: int = "không phải số"/' "$TMP/broken/scripts/actors/vehicle.gd"
expect_fail "chèn lỗi script vào vehicle.gd" run_test SMOKE smoke.gd "$TMP/broken"
cp game/maps/city.txt "$TMP/map.txt" && sed -i '4s/</>/12' "$TMP/map.txt"
expect_fail "đảo hướng một ô làn đường" python3 tools/checks/validate_map.py "$TMP/map.txt"

echo
if [ $fail -eq 0 ]; then echo "CHECK_ALL: PASS"; else echo "CHECK_ALL: FAIL"; fi
exit $fail

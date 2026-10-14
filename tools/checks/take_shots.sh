#!/usr/bin/env bash
# Chụp ảnh thật (cửa sổ trên DISPLAY) cho từng tình huống vào reference/shots/: tiếng Anh, tiếng Việt, và pseudolocalization.
# Dùng: tools/checks/take_shots.sh [tên ...]   (mặc định: tất cả). Danh sách tình huống: game/scripts/autoload/shot.gd
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
OUT="$PWD/reference/shots"
SHOTS=("$@")
[ ${#SHOTS[@]} -eq 0 ] && SHOTS=(menu settings city_walk combat driving wanted3 shop dialog mission_complete death hospital pause touch ad_debug)
mkdir -p "$OUT"
shoot() {  # shoot <tên> <tham số...>
  local extra=()
  [ "$1" = touch ] && extra+=(--touch)
  DISPLAY=${DISPLAY:-:0} timeout 45 "$GODOT" --path game -- --shot="$1" --shot-dir="$OUT" "${extra[@]}" "${@:2}" 2>&1 | grep -E "^SHOT|SCRIPT ERROR" || echo "THIẾU ẢNH: $1 $*"
}
for s in "${SHOTS[@]}"; do
  shoot "$s" --lang=en
  shoot "$s" --lang=vi
  shoot "$s" --lang=en --pseudo
done

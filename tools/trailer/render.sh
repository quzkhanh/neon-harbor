#!/usr/bin/env bash
# Quay clip trailer bằng Movie Maker của Godot: mỗi cảnh × mỗi khung hình → MP4 (H.264, 60 khung/giây, có tiếng game)
# kèm mốc sự kiện JSON (số khung hình tính từ đầu clip) để dựng video.
# Dùng: tools/trailer/render.sh [cảnh ...]   (mặc định: tất cả; danh sách ở game/scripts/trailer/trailer_scenes.gd)
# Biến môi trường: OUT (mặc định ../neon-harbor-trailer/clips), LANG_CODE (vi|en, mặc định vi),
#                  ASPECTS (mặc định "9x16 4x5 16x9").
# Cửa sổ game bị giới hạn bởi màn hình (trừ cả taskbar) nên không quay bằng --resolution được: script render từ một
# bản sao tạm của game/ có override.cfg chuyển sang stretch "viewport" (Movie Maker ghi đúng kích thước viewport,
# cửa sổ chỉ hiện bằng nửa cho vừa màn hình), không đụng project thật.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
OUT=${OUT:-$(realpath -m "$PWD/../neon-harbor-trailer/clips")}
LANG_CODE=${LANG_CODE:-vi}
read -ra ASPECT_LIST <<< "${ASPECTS:-9x16 4x5 16x9}"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(pigeons incident chase dog night)
declare -A SIZE=([9x16]=1080x1920 [4x5]=1080x1350 [16x9]=1920x1080)
FPS=60  # khớp Trailer.FPS

mkdir -p "$OUT"
WORK=$(mktemp -d "$OUT/.work.XXXX")
trap 'rm -rf "$WORK"' EXIT
cp -r game "$WORK/game"

fail=0
for aspect in "${ASPECT_LIST[@]}"; do
  size=${SIZE[$aspect]:-}
  [ -z "$size" ] && { echo "LỖI: khung hình không hỗ trợ: $aspect (có: ${!SIZE[*]})"; fail=1; continue; }
  w=${size%x*}
  h=${size#*x}
  printf '[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\nwindow/stretch/mode="viewport"\n\n[editor]\n\nmovie_writer/video_quality=0.95\n' \
    "$w" "$h" $((w / 2)) $((h / 2)) > "$WORK/game/override.cfg"
  for scene in "${SCENES[@]}"; do
    name="${scene}_${aspect}_${LANG_CODE}"
    raw="$WORK/$name.avi"
    events="$OUT/$name.json"
    log="$OUT/$name.log"
    rm -f "$events"
    DISPLAY=${DISPLAY:-:0} timeout 900 "$GODOT" --path "$WORK/game" --write-movie "$raw" --fixed-fps $FPS \
      -- --trailer="$scene" --lang="$LANG_CODE" --events="$events" > "$log" 2>&1
    code=$?
    if [ $code -ne 0 ] || [ ! -s "$events" ] || grep -q "SCRIPT ERROR" "$log"; then
      echo "LỖI: $name (exit $code, log: $log)"
      grep -E "ERROR" "$log" | head -5
      fail=1
      continue
    fi
    start=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['start_frame'] / $FPS)" "$events")
    if ffmpeg -v error -y -ss "$start" -i "$raw" -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p \
        -c:a aac -b:a 192k -movflags +faststart "$OUT/$name.mp4"; then
      rm -f "$raw" "$log"
      echo "OK: $OUT/$name.mp4"
    else
      echo "LỖI: ffmpeg không nén được $name"
      fail=1
    fi
  done
done
exit $fail

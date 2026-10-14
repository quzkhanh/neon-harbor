#!/usr/bin/env bash
# Chép phần asset Kenney (CC0) mà game dùng từ vendor/ vào game/assets/vendor/.
set -euo pipefail
cd "$(dirname "$0")/../.."
SHOOT=vendor/kenney-top-down-shooter
RACE=vendor/kenney-racing-pack/PNG
UI=vendor/kenney-ui-pack
OUT=game/assets/vendor
mkdir -p "$OUT"/{chars,cars,objects,ui,sounds}
cp "$SHOOT/Tilesheet/tilesheet_complete.png" "$OUT/"
for dir in "Hitman 1" "Man Blue" "Man Brown" "Man Old" "Soldier 1" "Survivor 1" "Woman Green"; do
  cp "$SHOOT/PNG/$dir"/*.png "$OUT/chars/"
done
for c in red_1 red_2 red_3 red_5 blue_1 blue_2 blue_3 green_1 green_2 green_3 yellow_1 yellow_3 black_1 black_2 black_3; do
  cp "$RACE/Cars/car_$c.png" "$OUT/cars/"
done
cp "$RACE"/Motorcycles/*.png "$OUT/cars/"
for o in skidmark_short_1 cone_straight barrel_red tires_white; do cp "$RACE/Objects/$o.png" "$OUT/objects/"; done
cp "$UI/PNG/Yellow/Default/star.png" "$OUT/ui/star.png"
cp "$UI/PNG/Grey/Default/star_outline.png" "$OUT/ui/star_outline.png"
cp "$UI/PNG/Grey/Default/arrow_basic_w_small.png" "$UI/PNG/Grey/Default/arrow_basic_e_small.png" "$OUT/ui/"
cp "$UI/PNG/Grey/Default/button_round_flat.png" "$UI/PNG/Grey/Default/button_round_line.png" "$OUT/ui/"
cp "$UI/Sounds/click-a.ogg" "$UI/Sounds/switch-a.ogg" "$UI/Sounds/tap-a.ogg" "$OUT/sounds/"
for pack in kenney-top-down-shooter kenney-racing-pack kenney-ui-pack; do
  cp "vendor/$pack/License.txt" "$OUT/LICENSE-$pack.txt"
done
echo "vendor assets -> $OUT ($(find "$OUT" -type f | wc -l) files)"

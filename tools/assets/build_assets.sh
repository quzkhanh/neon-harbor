#!/usr/bin/env bash
# Dựng lại toàn bộ asset của game: chép asset Kenney, bảng tile tường, sprite, âm thanh, nhạc.
set -euo pipefail
cd "$(dirname "$0")"
./copy_vendor.sh
python3 build_wall_table.py
python3 make_sprites.py
python3 make_world_sprites.py
python3 make_sfx.py
python3 make_sfx_extra.py
python3 make_music.py

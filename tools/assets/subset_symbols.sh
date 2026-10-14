#!/usr/bin/env bash
# Cắt Noto Sans Math (OFL) chỉ còn vài ký hiệu game dùng (∞, mũi tên) làm font dự phòng thứ hai.
# Cần fonttools: python3 -m venv /tmp/venv && /tmp/venv/bin/pip install fonttools
# Dùng: tools/assets/subset_symbols.sh <NotoSansMath-Regular.ttf> [pyftsubset]
set -euo pipefail
cd "$(dirname "$0")/../.."
SRC=${1:?đường dẫn NotoSansMath-Regular.ttf}
SUBSET=${2:-pyftsubset}
"$SUBSET" "$SRC" --unicodes="U+221E,U+2190-2193" --output-file=game/assets/fonts/NotoSansMath-Symbols.ttf
ls -la game/assets/fonts/NotoSansMath-Symbols.ttf

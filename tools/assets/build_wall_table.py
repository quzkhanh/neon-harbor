#!/usr/bin/env python3
"""Đọc tilesheet Kenney, phân loại tile tường theo viền 4 cạnh + 4 góc, ghi game/data/wall_tiles.json.

Chữ ký: 8 bit theo thứ tự T,R,B,L,tl,tr,br,bl. Một bit bật khi đoạn biên đó có viền màu.
Bộ cam là gốc; bộ gỗ lệch +9, bộ xanh xám lệch +171 (cùng bố cục trong tilesheet).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "vendor/kenney-top-down-shooter/Tilesheet/tilesheet_complete.png"
OUT = ROOT / "game/data/wall_tiles.json"
COLS = 27
ORANGE = list(range(109, 118)) + list(range(136, 145)) + list(range(163, 171)) + \
    list(range(190, 197)) + list(range(217, 224)) + list(range(244, 251))
SETS = {"orange": 0, "wood": 9, "steel": 171}
DARK = np.array([74, 74, 74])


def tile(sheet, n):
    i = n - 1
    c, r = i % COLS, i // COLS
    return sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64]


def signature(t):
    opaque = t[..., 3] > 200
    if opaque.mean() < 0.95:
        return None
    rim = opaque & (np.abs(t[..., :3] - DARK).sum(-1) > 20)
    bands = [rim[1:5, 20:44], rim[20:44, 59:63], rim[59:63, 20:44], rim[20:44, 1:5],
             rim[1:5, 1:5], rim[1:5, 59:63], rim[59:63, 59:63], rim[59:63, 1:5]]
    return sum(1 << k for k, b in enumerate(bands) if b.mean() > 0.8)


def main():
    sheet = np.array(Image.open(SHEET).convert("RGBA")).astype(int)
    table = {}
    for name, offset in SETS.items():
        sigs = {}
        for n in ORANGE:
            s = signature(tile(sheet, n + offset))
            if s is None or s in sigs:
                continue
            sigs[s] = n + offset
        table[name] = {str(s): n for s, n in sorted(sigs.items())}
    OUT.write_text(json.dumps(table, indent=1) + "\n")
    print({k: len(v) for k, v in table.items()}, "->", OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())

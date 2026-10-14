#!/usr/bin/env python3
"""Kiểm tra bản đồ ASCII của Neon Harbor.

Dùng: python3 tools/checks/validate_map.py [đường_dẫn_map]   (mặc định game/maps/city.txt)
Exit code khác 0 nếu có lỗi:
  - định dạng: các dòng dài bằng nhau, ký tự hợp lệ, đúng 1 P/G/r/d/k/m, có ít nhất 1 S/H/R, đủ 1/2/3 (mỗi số đúng 1);
  - mọi điểm quan trọng đi bộ tới được từ P (BFS qua ô không đặc);
  - lưới làn đường liên thông có hướng (xe tự lái không kẹt ngõ cụt) — cùng quy tắc với scripts/world/lanes.gd;
  - cửa hàng, bệnh viện, gara, tiệm sơn xe nằm cạnh vỉa hè.
"""
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MAP = ROOT / "game/maps/city.txt"

SOLID = set("#Tx~")
LANES = {"<": (-1, 0), ">": (1, 0), "^": (0, -1), "v": (0, 1)}
ROAD = set(LANES) | {"+", "="}
FLOORS = set(",\".~_-:") | ROAD
SPECIAL_ONE = "PGrdkm"
SPECIAL_SOME = "SHR"
MISSIONS = "123"
SPECIAL_MANY = "cbMha"
VALID = FLOORS | SOLID | set(SPECIAL_ONE + SPECIAL_SOME + MISSIONS + SPECIAL_MANY)
NEEDS_SIDEWALK = "SHGR"
DIRS = [(1, 0), (0, 1), (-1, 0), (0, -1)]


class Grid:
    def __init__(self, rows):
        self.rows = rows
        self.h = len(rows)
        self.w = len(rows[0]) if rows else 0

    def at(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.rows[y][x]
        return "#"

    def cells(self, chars):
        return [(x, y) for y, row in enumerate(self.rows) for x, c in enumerate(row) if c in chars]


def check_format(g, errors):
    widths = {len(r) for r in g.rows}
    if len(widths) != 1:
        errors.append(f"các dòng dài không bằng nhau: {sorted(widths)}")
    for y, row in enumerate(g.rows):
        for x, c in enumerate(row):
            if c not in VALID:
                errors.append(f"ký tự không hợp lệ {c!r} tại ({x},{y})")
    for c in SPECIAL_ONE + MISSIONS:
        n = len(g.cells(c))
        if n != 1:
            errors.append(f"cần đúng 1 ô {c!r}, đang có {n}")
    for c in SPECIAL_SOME:
        if not g.cells(c):
            errors.append(f"cần ít nhất 1 ô {c!r}")


def check_walk(g, errors):
    start = g.cells("P")
    if not start:
        return
    seen = {start[0]}
    queue = deque(seen)
    while queue:
        x, y = queue.popleft()
        for dx, dy in DIRS:
            n = (x + dx, y + dy)
            if n not in seen and g.at(*n) not in SOLID and 0 <= n[0] < g.w and 0 <= n[1] < g.h:
                seen.add(n)
                queue.append(n)
    for c in SPECIAL_ONE + SPECIAL_SOME + MISSIONS + SPECIAL_MANY:
        for cell in g.cells(c):
            if cell not in seen:
                errors.append(f"ô {c!r} tại {cell} không đi bộ tới được từ P")


def can_enter(g, x, y, d):
    while g.at(x, y) == "=":
        x, y = x + d[0], y + d[1]
    c = g.at(x, y)
    return c == "+" or LANES.get(c) == d


def successors(g, state):
    (x, y), h = state
    c = g.at(x, y)
    if c in LANES or c == "=":
        d = LANES.get(c, h)
        n = (x + d[0], y + d[1])
        if g.at(*n) in ROAD and can_enter(g, *n, d):
            yield (n, d)
        return
    for d in DIRS:
        if d == (-h[0], -h[1]):
            continue
        n = (x + d[0], y + d[1])
        nc = g.at(*n)
        if nc == "+" or (nc in ROAD and can_enter(g, *n, d)):
            yield (n, d)


def reach(g, start, edges):
    seen = {start}
    queue = deque([start])
    while queue:
        s = queue.popleft()
        for n in edges(s):
            if n not in seen:
                seen.add(n)
                queue.append(n)
    return seen


def check_lanes(g, errors):
    lane_states = [((x, y), LANES[g.at(x, y)]) for x, y in g.cells(LANES)]
    if not lane_states:
        errors.append("bản đồ không có làn đường")
        return
    for (x, y) in g.cells("="):
        if not any(g.at(x + dx, y + dy) in ROAD for dx, dy in DIRS):
            errors.append(f"vạch qua đường ({x},{y}) không nằm trên đường")
    forward = reach(g, lane_states[0], lambda s: successors(g, s))
    for s in forward:
        if next(successors(g, s), None) is None:
            errors.append(f"ngõ cụt: ô {s[0]} hướng {s[1]}")
    reverse = {}
    for s in forward:
        for n in successors(g, s):
            reverse.setdefault(n, []).append(s)
    backward = reach(g, lane_states[0], lambda s: reverse.get(s, []))
    for s in lane_states:
        if s not in forward:
            errors.append(f"làn {s[0]} không tới được từ mạng đường chính")
        elif s not in backward:
            errors.append(f"từ làn {s[0]} không quay lại được mạng đường chính")


def check_facilities(g, errors):
    for c in NEEDS_SIDEWALK:
        for x, y in g.cells(c):
            if not any(g.at(x + dx, y + dy) == "," for dx, dy in DIRS):
                errors.append(f"{c!r} tại ({x},{y}) không nằm cạnh vỉa hè")


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_MAP
    rows = [r for r in path.read_text(encoding="utf-8").splitlines() if r.strip()]
    g = Grid(rows)
    errors = []
    check_format(g, errors)
    if not errors:
        check_walk(g, errors)
        check_lanes(g, errors)
        check_facilities(g, errors)
    for e in errors[:40]:
        print("LỖI:", e)
    if errors:
        print(f"validate_map: FAIL ({len(errors)} lỗi) — {path.name}")
        return 1
    lanes = len(g.cells(LANES))
    print(f"validate_map: PASS — {path.name} {g.w}x{g.h}, {lanes} ô làn, {len(g.cells('='))} ô vạch qua đường")
    return 0


if __name__ == "__main__":
    sys.exit(main())

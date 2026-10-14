#!/usr/bin/env python3
"""Dựng bản đồ thành phố Neon Harbor: game/maps/city.txt và game/data/districts.json.

Khu cảng vẽ tay (tools/maps/harbor.txt, nơi diễn ra 3 nhiệm vụ) được ghép nguyên vẹn vào giữa phía nam;
8 khu còn lại dựng từ lưới đường chung + mẫu khối nhà theo từng khu, có một con sông chạy dọc phía tây
(chỉ qua được bằng cầu). Tất định (seed cố định): chạy lại cho ra đúng file cũ. Game chỉ đọc city.txt.

Dùng: python3 tools/maps/build_city.py   rồi   python3 tools/checks/validate_map.py
"""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARBOR = ROOT / "tools/maps/harbor.txt"
OUT_MAP = ROOT / "game/maps/city.txt"
OUT_DISTRICTS = ROOT / "game/data/districts.json"
SEED = 20261014

# Cột "v" của đường dọc và hàng "<" của đường ngang (mỗi đường rộng 2 ô). Khu cảng dùng đúng lưới này.
XS = [3, 21, 39, 57, 75, 89, 107, 125, 143, 161, 179, 197, 215, 233]
YS = [3, 21, 39, 57, 75, 93, 111, 129, 145, 161, 173]
W, H = 238, 186
HARBOR_AT = (86, 126)  # góc trên trái của harbor.txt trong thành phố
RIVER = 4  # ô lưới giữa XS[4] và XS[5] là sông
BRIDGES = {1, 4, 6, 8}  # chỉ số YS có cầu qua sông
SHORE = YS[-1] + 3  # hàng đầu của cầu tàu ven biển (trên đó là vỉa hè)
SEA = SHORE + 5  # từ hàng này trở xuống là biển

# Khu theo vùng lưới: cột (tây, giữa, đông) x hàng (bắc, trung tâm, nam).
ZONES = [["HILLSIDE", "DOWNTOWN", "UPTOWN"], ["MARKET", "MIDTOWN", "EASTSIDE"], ["RAILYARD", "HARBOR", "MARINA"]]
ZONE_X = [0, (XS[RIVER] + XS[RIVER + 1]) // 2 + 1, XS[9] + 1, W]  # ranh giới: giữa sông, giữa đường
ZONE_Y = [0, YS[3] + 1, YS[7] + 1, H]

# Khối gộp nhiều ô lưới (i0, j0, i1, j1) và kiểu khối.
MERGES = [(10, 0, 11, 1, "park"), (6, 4, 7, 4, "stadium"), (1, 8, 2, 8, "yard"), (11, 4, 11, 5, "park")]
# Cửa hàng súng S, bệnh viện H, tiệm sơn xe R ngoài khu cảng: ô lưới -> ký hiệu.
PLACES = {
    (6, 1): "S", (2, 5): "S", (10, 5): "S",
    (1, 1): "H", (12, 2): "H", (8, 3): "H", (0, 7): "H",
    (3, 3): "R", (9, 1): "R", (12, 8): "R",
}


class City:
    def __init__(self):
        self.g = [[","] * W for _ in range(H)]
        self.rng = random.Random(SEED)

    def set(self, x, y, ch):
        if 0 <= x < W and 0 <= y < H:
            self.g[y][x] = ch

    def at(self, x, y):
        return self.g[y][x] if 0 <= x < W and 0 <= y < H else "#"

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, ch)

    def text(self):
        return "\n".join("".join(row) for row in self.g) + "\n"


def zone(x, y):
    col = next(i for i in range(3) if x < ZONE_X[i + 1])
    row = next(j for j in range(3) if y < ZONE_Y[j + 1])
    return ZONES[row][col]


def merge_of(i, j):
    for m in MERGES:
        if m[0] <= i <= m[2] and m[1] <= j <= m[3]:
            return m
    return None


def h_segment(i, j):
    """Đường ngang ở hàng YS[j] giữa XS[i] và XS[i+1] (ngăn ô (i, j-1) với (i, j))."""
    if i == RIVER:
        return j in BRIDGES
    m = merge_of(i, j)
    return not (m and j > m[1] and merge_of(i, j - 1) == m)


def v_segment(i, j):
    """Đường dọc ở cột XS[i] giữa YS[j] và YS[j+1] (ngăn ô (i-1, j) với (i, j))."""
    m = merge_of(i, j)
    return not (m and i > m[0] and merge_of(i - 1, j) == m)


def roads(c):
    arms = {}
    for j, y in enumerate(YS):
        for i in range(len(XS) - 1):
            if h_segment(i, j):
                for x in range(XS[i] + 2, XS[i + 1]):
                    c.set(x, y, "<")
                    c.set(x, y + 1, ">")
                arms.setdefault((i, j), []).append((1, 0))
                arms.setdefault((i + 1, j), []).append((-1, 0))
    for i, x in enumerate(XS):
        for j in range(len(YS) - 1):
            if v_segment(i, j):
                for y in range(YS[j] + 2, YS[j + 1]):
                    c.set(x, y, "v")
                    c.set(x + 1, y, "^")
                arms.setdefault((i, j), []).append((0, 1))
                arms.setdefault((i, j + 1), []).append((0, -1))
    for (i, j), dirs in arms.items():
        x, y = XS[i], YS[j]
        c.fill(x, y, x + 1, y + 1, "+")
        if len(dirs) < 3:
            continue
        for dx, dy in dirs:  # vạch qua đường ở ô đầu tiên của mỗi nhánh
            if dx:
                cx = x + 2 if dx > 0 else x - 1
                c.set(cx, y, "=")
                c.set(cx, y + 1, "=")
            else:
                cy = y + 2 if dy > 0 else y - 1
                c.set(x, cy, "=")
                c.set(x + 1, cy, "=")


def blocks():
    """Các khối (x0, y0, x1, y1, i, j, kiểu) phía trong vòng vỉa hè, trừ sông và khu cảng."""
    seen = set()
    for j in range(len(YS) - 1):
        for i in range(len(XS) - 1):
            if i == RIVER or (i, j) in seen:
                continue
            m = merge_of(i, j) or (i, j, i, j, "")
            for jj in range(m[1], m[3] + 1):
                for ii in range(m[0], m[2] + 1):
                    seen.add((ii, jj))
            x0, y0 = XS[m[0]] + 3, YS[m[1]] + 3
            x1, y1 = XS[m[2] + 1] - 2, YS[m[3] + 1] - 2
            yield x0, y0, x1, y1, i, j, m[4]


# ---------- Mẫu khối ----------

def trees_along(c, x0, y0, x1, y1, step, rng, odds=0.8):
    for x in range(x0, x1 + 1, step):
        for y in (y0, y1):
            if rng.random() < odds:
                c.set(x, y, "T")


def tower(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1 - 2, "#")
    c.fill(x0, y1 - 1, x1, y1, ":")
    for x in range(x0 + 1, x1, 4):
        c.set(x, y1, "T")


def twin(c, r, rng):
    x0, y0, x1, y1 = r
    mid = (x0 + x1) // 2 + rng.choice([-2, 0, 2])
    c.fill(x0, y0, mid - 1, y1, "#")
    c.fill(mid + 1, y0, x1, y1, "#")
    c.fill(mid, y0, mid, y1, ",")
    split = (y0 + y1) // 2
    c.fill(mid + 1, split, x1, split, ",")


def plaza(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ":")
    for y in range(y0 + 1, y1, 4):
        for x in range(x0 + 1, x1, 4):
            c.set(x, y, "T")
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    c.fill(cx, cy, cx + 1, cy + 1, "~")
    c.set(cx - 1, cy, "h")


def parking(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, "-")
    for y in (y0 + 1, y1 - 1):
        for x in range(x0 + 1, x1, 2):
            roll = rng.random()
            if roll < 0.18:
                c.set(x, y, "c")
            elif roll < 0.24:
                c.set(x, y, "b")


def office(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ":")
    c.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 2, "#")
    trees_along(c, x0, y0, x1, y1, 3, rng, 0.5)


def houses(c, r, rng, lot=5, size=3):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, '"')
    for ly in range(y0, y1 - size + 1, lot):
        for lx in range(x0, x1 - size + 1, lot):
            hx, hy = lx + 1, ly + 1
            if hx + size - 1 <= x1 and hy + size - 1 <= y1:
                c.fill(hx, hy, hx + size - 1, hy + size - 1, "#")
                c.set(hx + size // 2, hy + size, ",")
            if rng.random() < 0.6:
                c.set(lx, ly, "T")


def park(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, '"')
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    rx, ry = max((x1 - x0) // 4, 2), max((y1 - y0) // 4, 2)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                c.set(x, y, "~")
    c.fill(x0, cy - ry - 2, x1, cy - ry - 2, ",")
    c.fill(x0, cy + ry + 2, x1, cy + ry + 2, ",")
    c.fill(cx - rx - 2, y0, cx - rx - 2, y1, ",")
    c.fill(cx + rx + 2, y0, cx + rx + 2, y1, ",")
    c.set(cx, cy - ry - 2, "h")
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if c.at(x, y) == '"' and rng.random() < 0.1:
                c.set(x, y, "T")


def stadium(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ":")
    c.fill(x0 + 2, y0 + 2, x1 - 2, y1 - 2, '"')
    trees_along(c, x0, y0, x1, y1, 3, rng)
    c.set(x0 + 1, y0 + 1, "h")
    c.set(x1 - 1, y1 - 1, "a")


def market(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ":")
    for x in range(x0, x1 + 1, 5):
        c.fill(x, y0, min(x + 3, x1), y0 + 2, "#")
    for y in range(y0 + 5, y1, 3):
        for x in range(x0 + 1, x1, 3):
            if rng.random() < 0.7:
                c.set(x, y, "M")


def shops(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ",")
    for y in range(y0, y1 - 1, 4):
        for x in range(x0, x1 - 1, 4):
            c.fill(x, y, min(x + 2, x1), min(y + 2, y1), "#")


def warehouse(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ".")
    c.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 3, "#")
    for x in range(x0 + 1, x1, 3):
        if rng.random() < 0.5:
            c.set(x, y1 - 1, "x")


def containers(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, ".")
    for y in range(y0 + 1, y1, 3):
        for x in range(x0 + 1, x1 - 1, 4):
            if rng.random() < 0.75:
                c.fill(x, y, x + 2, y, "x")
    c.set(x1, y1, "a")


def apartments(c, r, rng):
    x0, y0, x1, y1 = r
    c.fill(x0, y0, x1, y1, '"')
    c.fill(x0, y0, x1, y0 + 2, "#")
    c.fill(x0, y0, x0 + 2, y1 - 2, "#")
    c.fill(x1 - 2, y0, x1, y1 - 2, "#")
    c.set((x0 + x1) // 2, (y0 + y1) // 2 + 1, "T")


STYLES = {
    "DOWNTOWN": [tower, tower, twin, twin, plaza, parking],
    "MIDTOWN": [office, office, twin, parking, plaza],
    "HILLSIDE": [houses, houses, houses, park],
    "UPTOWN": [lambda c, r, rng: houses(c, r, rng, 7, 4), houses, park],
    "MARKET": [market, shops, shops, parking],
    "EASTSIDE": [apartments, apartments, office, parking, plaza],
    "RAILYARD": [warehouse, warehouse, containers, parking],
    "MARINA": [houses, parking, plaza, lambda c, r, rng: houses(c, r, rng, 7, 4)],
}
MERGED = {"park": park, "stadium": stadium, "yard": lambda c, r, rng: (warehouse(c, (r[0], r[1], (r[0] + r[2]) // 2, r[3]), rng), containers(c, ((r[0] + r[2]) // 2 + 1, r[1], r[2], r[3]), rng))}


def place(c, r, ch):
    """Cửa (S/H/R) ở giữa mép dưới khối, trên vỉa hè; ngay sau cửa là toà nhà 3x2."""
    x0, y0, x1, y1 = r
    cx = (x0 + x1) // 2
    c.fill(cx - 1, y1 - 1, cx + 1, y1, "#")
    c.set(cx, y1 + 1, ch)


# ---------- Sông, bờ biển, khu cảng ----------

def river(c):
    x0, x1 = XS[RIVER] + 2, XS[RIVER + 1] - 1
    bridge_rows = {y + d for j in BRIDGES for y in [YS[j]] for d in range(-1, 3)}
    for y in range(H):
        if y in bridge_rows:
            for x in range(x0, x1 + 1):
                if c.at(x, y) not in "<>+=":
                    c.set(x, y, ",")
            continue
        for x in range(x0, x1 + 1):
            c.set(x, y, "~" if y >= SHORE or x0 + 2 <= x <= x1 - 2 else ("," if x in (x0, x1) else '"'))
        if y % 4 == 0 and y < SHORE:
            c.set(x0 + 1, y, "T")
            c.set(x1 - 1, y, "T")


def shore(c, x0, x1, kind):
    rng = c.rng
    for x in range(x0, x1 + 1):
        for y in range(SHORE, H):
            if y >= SEA:
                ch = "~"
            elif kind == "MARINA":
                ch = "." if y < SEA - 2 else "_"
            else:
                ch = "_"
            c.set(x, y, ch)
        if kind == "MARINA" and rng.random() < 0.12:
            c.set(x, SHORE, "T")
        elif kind != "MARINA" and rng.random() < 0.15:
            c.set(x, SHORE + 1 + rng.randrange(3), "x")
    for x in range(x0 + 6, x1 - 2, 14):  # cầu tàu nhô ra biển
        c.fill(x, SEA, x + 2, SEA + 2, "_")


def paste_harbor(c):
    rows = [r for r in HARBOR.read_text(encoding="utf-8").splitlines() if r.strip()]
    ox, oy = HARBOR_AT
    for ly in range(2, len(rows)):
        for lx in range(2, len(rows[0]) - 2):
            ch, here = rows[ly][lx], c.at(ox + lx, oy + ly)
            if here in "<>^v+=" and ch not in "<>^v+=":
                continue  # đường từ khu khác chạy vào khu cảng
            c.set(ox + lx, oy + ly, ch)


def border(c):
    for y in range(H):
        for x in (0, 1, W - 2, W - 1):
            c.set(x, y, "#" if y < SEA else "~")
    for x in range(W):
        if c.at(x, 0) != "~":
            c.set(x, 0, "#")
            c.set(x, 1, "#")


def build():
    c = City()
    roads(c)
    for x0, y0, x1, y1, i, j, kind in blocks():
        r = (x0, y0, x1, y1)
        style = MERGED[kind] if kind else c.rng.choice(STYLES.get(zone(x0, y0), [plaza]))
        style(c, r, c.rng)
        if (i, j) in PLACES:
            place(c, r, PLACES[(i, j)])
    river(c)
    shore(c, 2, XS[RIVER] + 1, "RAILYARD")
    shore(c, XS[9] + 2, W - 3, "MARINA")
    paste_harbor(c)
    border(c)
    return c


def districts():
    out = []
    for row in range(3):
        for col in range(3):
            x, y = ZONE_X[col], ZONE_Y[row]
            out.append({"key": "DISTRICT_" + ZONES[row][col], "rect": [x, y, ZONE_X[col + 1] - x, ZONE_Y[row + 1] - y]})
    return out


def main():
    c = build()
    OUT_MAP.write_text(c.text(), encoding="utf-8")
    OUT_DISTRICTS.write_text(json.dumps(districts(), indent=1) + "\n", encoding="utf-8")
    print(f"{OUT_MAP.relative_to(ROOT)}: {W}x{H}; {OUT_DISTRICTS.relative_to(ROOT)}: {len(districts())} khu")


if __name__ == "__main__":
    main()

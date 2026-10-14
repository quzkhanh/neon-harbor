"""Sinh sprite thủ tục cho Neon Harbor theo phong cách Kenney (mảng màu phẳng, viền tối, góc bo nhẹ).

Tạo ra trong game/assets/sprites/:
  weapons/icon_<id>.png  biểu tượng vũ khí nhìn ngang 192x96 (shop, HUD), cùng một tỉ lệ điểm ảnh
  ui/icon_*.png          ổ khoá, máu, giáp, tiền
  fx/*.png               chớp nòng, vỏ đạn, quầng sáng, khói, tia lửa, rocket, lựu đạn, vết cháy, lửa, vũng máu
  items/*.png            vật phẩm nhặt được nhìn từ trên xuống

Chạy từ gốc repo:  python3 tools/assets/make_sprites.py
Chỉ cần python3 + Pillow + numpy. Kết quả tất định: chạy lại cho ra đúng các file cũ.
Mọi hình được vẽ ở độ phân giải gấp S lần rồi thu nhỏ bằng LANCZOS để có khử răng cưa.
"""
from math import cos, pi, sin, sqrt
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/sprites"
S = 4

OUTLINE = "#24272c"
METAL = "#3b3f46"
METAL_LIGHT = "#5b616b"
METAL_HI = "#7b838f"
WOOD = "#c9894a"
WOOD_DARK = "#9d6634"
ORANGE = "#e86a17"
OLIVE = "#5d7a3a"
OLIVE_LIGHT = "#7a9a4c"
OLIVE_DARK = "#465c2b"
RED = "#d6402e"
RED_LIGHT = "#ef6a55"
RED_DARK = "#a52f22"
BLUE = "#3b86d6"
BLUE_LIGHT = "#6aa9ea"
BLUE_DARK = "#2a64a8"
GREEN = "#4fa356"
GREEN_LIGHT = "#86cf7f"
GREEN_DARK = "#367a3c"
PAPER = "#efe6c8"
BRASS = "#e0b03c"
BRASS_DARK = "#a77a22"
BRASS_HI = "#f6d77a"
CARDBOARD = "#c8935a"
CARDBOARD_DARK = "#a2703f"
TAPE = "#e6c890"
WHITE = "#f2f4f6"
WHITE_SHADE = "#cfd6de"
GLASS = "#7fd0ea"

WEAPON_SIZE = (192, 96)
WEAPON_OUTLINE = 3.5


def dilate(mask, r):
    """Nở mặt nạ theo đĩa bán kính r (pixel ở độ phân giải lớn)."""
    h, w = mask.shape
    padded = np.pad(mask.astype(np.int32), r)
    cs = np.pad(np.cumsum(padded, axis=1), ((0, 0), (1, 0)))
    out = np.zeros_like(mask, dtype=bool)
    for dy in range(-r, r + 1):
        k = int(sqrt(r * r - dy * dy))
        rows = cs[r + dy:r + dy + h]
        out |= (rows[:, r + k + 1:r + k + 1 + w] - rows[:, r - k:r - k + w]) > 0
    return out


class Art:
    """Khung vẽ: toạ độ tính theo pixel đích, vẽ thật ở độ phân giải gấp S lần."""

    def __init__(self, w, h, origin=(0, 0)):
        self.w, self.h = w, h
        self.ox, self.oy = origin
        self.img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _p(self, pts):
        return [((x + self.ox) * S, (y + self.oy) * S) for x, y in pts]

    def _box(self, box):
        x0, y0, x1, y1 = box
        (a, b), (c, d) = self._p([(x0, y0), (x1, y1)])
        return [a, b, c - 1, d - 1]

    def rect(self, box, fill, r=0):
        self.d.rounded_rectangle(self._box(box), r * S, fill=fill)

    def poly(self, pts, fill):
        self.d.polygon(self._p(pts), fill=fill)

    def ellipse(self, box, fill):
        self.d.ellipse(self._box(box), fill=fill)

    def line(self, pts, fill, width):
        self.d.line(self._p(pts), fill=fill, width=round(width * S), joint="curve")

    def hole(self, box, edge, r=None):
        """Đục lỗ trong suốt, mép lỗ có viền tối dày `edge`. Gọi sau outline()."""
        x0, y0, x1, y1 = box
        radius = min(x1 - x0, y1 - y0) / 2 if r is None else r
        self.rect(box, OUTLINE, radius)
        self.rect((x0 + edge, y0 + edge, x1 - edge, y1 - edge), (0, 0, 0, 0), max(radius - edge, 0))

    def outline(self, width, color=OUTLINE):
        """Viền tối quanh toàn bộ hình hiện có."""
        mask = np.array(self.img)[:, :, 3] > 0
        grown = dilate(mask, round(width * S))
        base = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        base.paste(Image.new("RGBA", self.img.size, color), mask=Image.fromarray(grown.astype(np.uint8) * 255))
        base.alpha_composite(self.img)
        self.img = base
        self.d = ImageDraw.Draw(self.img)

    def done(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def weapon_art():
    return Art(240, 140, origin=(20, 20))


def centered(art, size=WEAPON_SIZE):
    """Đặt hình vào giữa khung đích, giữ nguyên tỉ lệ điểm ảnh chung."""
    bbox = art.img.getbbox()
    crop = art.img.crop(bbox)
    w, h = size
    assert crop.width <= (w - 16) * S and crop.height <= (h - 16) * S, crop.size
    canvas = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    x = ((w * S - crop.width) // 2) // S * S
    y = ((h * S - crop.height) // 2) // S * S
    canvas.alpha_composite(crop, (x, y))
    return canvas.resize(size, Image.LANCZOS)


def ellipse_span(cx, cy, rx, ry, y):
    """Nửa bề rộng của elip tại hàng y."""
    t = (y - cy) / ry
    return rx * sqrt(max(0.0, 1 - t * t))


def curve(p0, p1, p2, n=12):
    """Các điểm trên đường cong Bezier bậc hai."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * t * (1 - t), t * t
        pts.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return pts


def trigger_guard(a, box):
    """Vòng cò dưới thân súng; y0 là mép dưới thân, lỗ được đục sau khi viền."""
    x0, y0, x1, y1 = box
    a.rect((x0, y0 - 4, x1, y1), METAL, 5)
    a.outline(WEAPON_OUTLINE)
    a.hole((x0 + 3, y0, x1 - 3, y1 - 3), 1.5, r=3)
    a.line([(x0 + 6, y0 + 1), (x0 + 7, y0 + 4), (x0 + 6, y0 + 7)], OUTLINE, 2.5)


# ---------- A. Vũ khí ----------

def icon_pistol():
    a = weapon_art()
    a.poly([(16, 22), (40, 22), (34, 60), (8, 58)], METAL)
    a.poly([(19, 30), (34, 30), (30, 53), (13, 52)], WOOD)
    for y in (36, 42, 48):
        a.line([(18, y), (30, y)], WOOD_DARK, 1.5)
    a.rect((12, 16, 82, 28), METAL, 2)
    a.rect((8, 4, 86, 20), METAL_LIGHT, 3)
    a.rect((12, 6, 82, 9), METAL_HI, 1)
    for x in (14, 19, 24):
        a.line([(x, 11), (x, 17)], METAL, 2)
    a.rect((86, 8, 92, 16), METAL, 1)
    a.rect((76, 1, 81, 5), METAL)
    trigger_guard(a, (36, 28, 58, 41))
    return centered(a)


def icon_smg():
    a = weapon_art()
    a.rect((0, 2, 8, 34), METAL, 2)
    a.rect((4, 5, 34, 11), METAL_LIGHT)
    a.rect((4, 25, 38, 30), METAL_LIGHT)
    a.poly([(42, 24), (56, 24), (52, 54), (37, 53)], METAL)
    a.poly([(44, 30), (53, 30), (50, 48), (41, 47)], ORANGE)
    a.rect((72, 22, 84, 62), METAL_LIGHT, 2)
    a.rect((70, 58, 86, 65), METAL, 2)
    a.rect((32, 4, 102, 27), METAL, 3)
    a.rect((38, 0, 94, 5), METAL_LIGHT, 1)
    a.rect((40, 10, 74, 15), METAL_LIGHT, 2)
    a.rect((80, 10, 96, 18), METAL_HI, 2)
    a.rect((84, 12, 92, 16), METAL, 1)
    a.rect((102, 10, 120, 19), METAL_LIGHT, 1)
    a.rect((118, 8, 126, 21), METAL, 2)
    a.poly([(108, 10), (110, 3), (115, 3), (115, 10)], METAL)
    trigger_guard(a, (54, 27, 72, 40))
    return centered(a)


def icon_shotgun():
    a = weapon_art()
    a.poly([(60, 13), (60, 27), (48, 29), (8, 41), (0, 41), (0, 16), (8, 13)], WOOD)
    a.poly([(42, 22), (56, 20), (56, 25), (45, 27)], WOOD_DARK)
    a.rect((0, 15, 6, 42), METAL, 2)
    a.rect((92, 8, 166, 16), METAL_LIGHT, 2)
    a.rect((92, 17, 156, 24), METAL, 2)
    a.rect((150, 16, 158, 25), METAL_LIGHT, 2)
    a.ellipse((160, 5, 165, 10), METAL_HI)
    a.rect((56, 8, 96, 27), METAL, 3)
    a.rect((62, 12, 90, 17), METAL_LIGHT, 2)
    a.rect((106, 14, 144, 29), WOOD, 3)
    for x in range(112, 140, 6):
        a.line([(x, 17), (x, 26)], WOOD_DARK, 2)
    trigger_guard(a, (64, 27, 82, 39))
    return centered(a)


def icon_rifle():
    a = weapon_art()
    a.poly([(0, 6), (8, 4), (42, 10), (42, 24), (8, 34), (0, 34)], METAL)
    a.rect((10, 15, 34, 20), METAL_LIGHT, 2)
    a.rect((0, 4, 5, 35), OUTLINE, 2)
    a.poly([(54, 22), (68, 22), (61, 50), (47, 48)], METAL)
    outer = curve((76, 22), (80, 44), (94, 60))
    inner = curve((92, 22), (94, 40), (106, 54))
    a.poly(outer + inner[::-1], METAL_LIGHT)
    a.poly(curve((79, 25), (82, 40), (90, 52), 6) + curve((95, 49), (88, 38), (87, 25), 6), METAL_HI)
    a.rect((40, 7, 100, 25), METAL, 2)
    a.rect((46, 2, 94, 8), METAL_LIGHT, 1)
    for x in range(50, 92, 6):
        a.rect((x, 2, x + 2, 5), METAL)
    a.rect((98, 8, 140, 24), METAL_LIGHT, 4)
    for x in range(104, 134, 8):
        a.rect((x, 13, x + 5, 19), METAL, 2)
    a.poly([(134, 8), (136, 0), (141, 0), (141, 8)], METAL)
    a.rect((140, 12, 158, 19), METAL)
    a.rect((156, 10, 166, 21), METAL, 2)
    a.outline(WEAPON_OUTLINE)
    return centered(a)


def icon_sniper():
    a = weapon_art()
    stock = [(0, 18), (8, 16), (36, 20), (58, 21), (62, 25), (62, 33), (44, 33), (36, 42),
             (8, 46), (0, 46)]
    a.poly(stock, WOOD)
    a.poly([(10, 22), (34, 24), (30, 28), (10, 28)], WOOD_DARK)
    a.rect((0, 16, 6, 47), METAL, 2)
    a.rect((94, 25, 136, 33), WOOD, 3)
    a.rect((96, 21, 160, 27), METAL_LIGHT, 1)
    a.rect((156, 18, 166, 30), METAL, 2)
    a.rect((160, 22, 164, 26), OUTLINE)
    a.rect((56, 19, 98, 32), METAL, 2)
    a.line([(84, 26), (90, 32)], METAL_LIGHT, 3)
    a.ellipse((87, 29, 94, 36), METAL_HI)
    a.rect((72, 12, 78, 20), METAL)
    a.rect((100, 12, 106, 20), METAL)
    a.poly([(52, 3), (60, 6), (60, 14), (52, 17)], METAL)
    a.rect((58, 5, 116, 14), METAL_LIGHT, 3)
    a.rect((62, 6, 112, 8), METAL_HI, 1)
    a.rect((82, 0, 90, 6), METAL, 1)
    a.poly([(112, 5), (124, 1), (124, 18), (112, 14)], METAL)
    a.rect((122, 2, 126, 17), GLASS, 1)
    a.outline(WEAPON_OUTLINE)
    return centered(a)


def icon_grenade():
    a = weapon_art()
    cx, cy, rx, ry = 22, 36, 18, 21
    a.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), OLIVE)
    a.ellipse((cx - 13, cy - 16, cx - 2, cy - 4), OLIVE_LIGHT)
    for y in (cy - 7, cy + 7):
        half = ellipse_span(cx, cy, rx, ry, y) - 1
        a.line([(cx - half, y), (cx + half, y)], OLIVE_DARK, 2.5)
    a.line([(cx, cy - ry + 3), (cx, cy + ry - 3)], OLIVE_DARK, 2.5)
    a.rect((14, 8, 30, 18), METAL, 2)
    a.poly([(18, 6), (36, 8), (44, 16), (44, 34), (39, 34), (38, 18), (32, 13), (18, 12)], METAL_LIGHT)
    a.rect((0, 0, 16, 16), METAL_LIGHT, 8)
    a.line([(13, 9), (18, 9)], METAL_LIGHT, 3)
    a.outline(WEAPON_OUTLINE)
    a.hole((0, 0, 16, 16), 4.2)
    return centered(a)


def icon_flamethrower():
    a = weapon_art()
    a.rect((0, 8, 14, 30), METAL, 3)
    a.poly([(30, 22), (44, 22), (40, 50), (25, 49)], METAL)
    a.rect((112, 22, 122, 44), METAL, 2)
    a.rect((10, 10, 92, 25), METAL, 3)
    a.rect((18, 14, 46, 18), METAL_LIGHT, 2)
    a.rect((88, 13, 146, 21), METAL_LIGHT)
    a.rect((92, 7, 140, 26), METAL_LIGHT, 4)
    for x in range(98, 136, 9):
        a.rect((x, 12, x + 5, 21), METAL, 2)
    a.poly([(140, 12), (156, 6), (162, 6), (162, 28), (156, 28), (140, 22)], ORANGE)
    a.rect((156, 6, 162, 28), "#c4540f", 1)
    a.rect((146, 2, 152, 8), RED)
    a.rect((50, 26, 106, 52), RED, 12)
    a.rect((56, 30, 98, 35), RED_LIGHT, 3)
    for x in (64, 90):
        a.rect((x, 26, x + 4, 52), RED_DARK)
    a.rect((72, 21, 80, 28), METAL, 1)
    a.outline(WEAPON_OUTLINE)
    return centered(a)


def icon_bazooka():
    a = weapon_art()
    a.poly([(62, 26), (74, 26), (70, 50), (57, 49)], METAL)
    a.rect((98, 26, 108, 44), METAL, 2)
    a.poly([(154, 12), (160, 12), (166, 19), (160, 26), (154, 26)], RED)
    a.poly([(0, 6), (18, 10), (18, 28), (0, 32)], OLIVE_DARK)
    a.rect((14, 9, 152, 29), OLIVE, 4)
    a.rect((20, 12, 144, 16), OLIVE_LIGHT, 2)
    for x in (46, 108):
        a.rect((x, 8, x + 6, 30), OLIVE_DARK, 1)
    a.rect((142, 6, 154, 32), OLIVE_DARK, 2)
    a.rect((24, 26, 44, 35), METAL, 3)
    a.poly([(70, 9), (73, 0), (81, 0), (84, 9)], METAL)
    a.rect((74, 2, 80, 5), GLASS)
    a.outline(WEAPON_OUTLINE)
    return centered(a)


# ---------- B. Biểu tượng giao diện ----------

def icon_lock():
    a = Art(64, 64)
    a.rect((17, 4, 47, 42), "#9aa3ae", 15)
    a.rect((24, 11, 40, 42), (0, 0, 0, 0), 8)
    a.rect((10, 26, 54, 59), "#d5dae1", 6)
    a.rect((10, 50, 54, 59), "#b4bcc6", 6)
    a.rect((10, 50, 54, 54), "#b4bcc6")
    a.rect((14, 29, 50, 33), "#eef1f4", 2)
    a.ellipse((27, 35, 37, 45), OUTLINE)
    a.poly([(30, 42), (34, 42), (35.5, 52), (28.5, 52)], OUTLINE)
    a.outline(3)
    return a.done()


def icon_health():
    a = Art(48, 48)
    a.rect((4, 4, 44, 44), RED_DARK, 9)
    a.rect((4, 4, 44, 40), RED, 9)
    a.rect((19, 10, 29, 37), WHITE, 2)
    a.rect((10, 18, 38, 28), WHITE, 2)
    a.outline(2.5)
    return a.done()


def icon_armor():
    a = Art(48, 48)
    left = [(24, 4), (7, 9.5)] + curve((7, 9.5), (6, 32), (24, 44))[1:]
    a.poly(left + [(24, 44)], BLUE_LIGHT)
    right = [(24, 4), (41, 9.5)] + curve((41, 9.5), (42, 32), (24, 44))[1:]
    a.poly(right, BLUE)
    inner_l = [(24, 9), (11, 13)] + curve((11, 13), (11, 30), (24, 39))[1:]
    inner_r = [(24, 9), (37, 13)] + curve((37, 13), (37, 30), (24, 39))[1:]
    a.poly(inner_l, BLUE)
    a.poly(inner_r, BLUE_DARK)
    a.outline(2.5)
    return a.done()


def banknote(a, box, angle, fill, light, dark):
    """Tờ tiền xoay một góc nhỏ quanh tâm."""
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    def rot(pts):
        c, s = cos(angle), sin(angle)
        return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]

    a.poly(rot([(x0, y0), (x1, y0), (x1, y1), (x0, y1)]), fill)
    a.poly(rot([(x0 + 3, y0 + 3), (x1 - 3, y0 + 3), (x1 - 3, y1 - 3), (x0 + 3, y1 - 3)]), dark)
    a.poly(rot([(x0 + 5, y0 + 5), (x1 - 5, y0 + 5), (x1 - 5, y1 - 5), (x0 + 5, y1 - 5)]), fill)
    r = (y1 - y0) / 2 - 6
    a.poly(rot([(cx + r * cos(t * pi / 8), cy + r * sin(t * pi / 8)) for t in range(16)]), light)


def icon_money():
    a = Art(48, 48)
    banknote(a, (8, 8, 42, 28), -0.3, GREEN_DARK, GREEN, "#2c6531")
    banknote(a, (4, 17, 42, 39), 0, GREEN, GREEN_LIGHT, GREEN_DARK)
    a.rect((28, 17, 33, 39), PAPER)
    a.outline(2.5)
    return a.done()


# ---------- C. Hiệu ứng ----------

def soft(img, radius):
    return img.filter(ImageFilter.GaussianBlur(radius * S))


def muzzle_flash():
    a = Art(64, 32)
    a.poly([(0, 16), (18, 6), (62, 16), (18, 26)], "#ff8a1f")
    a.poly([(4, 13), (34, 1), (24, 14)], "#ff8a1f")
    a.poly([(4, 19), (34, 31), (24, 18)], "#ff8a1f")
    a.poly([(0, 16), (14, 9), (46, 16), (14, 23)], "#ffd23f")
    a.ellipse((0, 11, 22, 21), "#fffbe6")
    a.img = soft(a.img, 0.6)
    return a.done()


def shell():
    a = Art(10, 5)
    a.rect((1, 1, 9, 4), BRASS, 0.5)
    a.rect((1, 1.5, 9, 2), BRASS_HI)
    a.rect((1, 0.75, 2.5, 4.25), BRASS_DARK)
    a.outline(0.75, "#6e4f16")
    return a.done()


def radial(size):
    """Khoảng cách chuẩn hoá tới tâm (0 ở tâm, 1 ở mép)."""
    c = (size - 1) / 2
    y, x = np.mgrid[0:size, 0:size]
    return np.hypot(x - c, y - c) / (size / 2), np.arctan2(y - c, x - c)


def from_arrays(rgb, alpha):
    data = np.dstack([np.broadcast_to(rgb, alpha.shape + (3,)), np.clip(alpha, 0, 1) * 255])
    return Image.fromarray(data.astype(np.uint8), "RGBA")


def glow():
    r, _ = radial(128)
    t = np.clip(r, 0, 1)
    alpha = (1 - t * t * (3 - 2 * t)) ** 1.6
    return from_arrays(np.array([255, 255, 255]), alpha)


def blobs(size, circles, blur):
    """Mặt nạ mềm từ nhiều hình tròn (toạ độ theo tỉ lệ 0..1)."""
    img = Image.new("L", (size * S, size * S), 0)
    d = ImageDraw.Draw(img)
    for x, y, r in circles:
        d.ellipse([(x - r) * size * S, (y - r) * size * S, (x + r) * size * S, (y + r) * size * S], 255)
    img = img.filter(ImageFilter.GaussianBlur(blur * size * S)).resize((size, size), Image.LANCZOS)
    return np.array(img) / 255.0


def smoke():
    puff = [(0.5, 0.5, 0.25)] + [(0.5 + 0.19 * cos(k * pi / 4 + 0.3), 0.5 + 0.17 * sin(k * pi / 4 + 0.3),
                                  0.13 + 0.02 * (k % 2)) for k in range(8)]
    alpha = blobs(64, puff, 0.045)
    light = blobs(64, [(x - 0.05, y - 0.06, r * 0.8) for x, y, r in puff], 0.06)[:, :, None]
    dark, bright = np.array([138, 144, 154]), np.array([214, 218, 225])
    return from_arrays(dark + (bright - dark) * light, alpha * 0.85)


def spark():
    a = Art(16, 16)
    a.poly([(0.5, 8), (6.5, 6.8), (8, 0.5), (9.5, 6.8), (15.5, 8), (9.5, 9.2), (8, 15.5), (6.5, 9.2)], "#ffd84a")
    a.ellipse((5, 5, 11, 11), "#fffbe6")
    a.img = soft(a.img, 0.3)
    return a.done()


def rocket():
    a = Art(36, 12)
    a.poly([(10, 4), (3.5, 1.6), (6, 4)], OLIVE_DARK)
    a.poly([(10, 8), (3.5, 10.4), (6, 8)], OLIVE_DARK)
    a.rect((2, 4.5, 8, 7.5), METAL)
    a.rect((6, 3.5, 28, 8.5), OLIVE, 1)
    a.rect((8, 4.25, 27, 5.5), OLIVE_LIGHT)
    a.rect((22, 3.5, 23.5, 8.5), OLIVE_DARK)
    a.poly([(28, 3.5), (31.5, 3.5), (34, 6), (31.5, 8.5), (28, 8.5)], RED)
    a.outline(1)
    return a.done()


def grenade():
    a = Art(16, 16)
    a.ellipse((2, 2, 14, 14), OLIVE)
    a.ellipse((3.5, 3.5, 8, 8), OLIVE_LIGHT)
    a.line([(2.5, 8), (13.5, 8)], OLIVE_DARK, 1)
    a.ellipse((6, 6, 10, 10), METAL)
    a.line([(8, 8), (13, 12)], METAL_LIGHT, 1.5)
    a.outline(1)
    return a.done()


def scorch():
    r, theta = radial(96)
    rng = np.random.default_rng(7)
    edge = 0.62 + sum(rng.uniform(0.02, 0.07) * np.sin(k * theta + rng.uniform(0, 2 * pi)) for k in range(2, 8))
    rays = 0.12 * np.clip(np.sin(9 * theta + 1.3) * np.sin(5 * theta + 0.4), 0, 1) ** 2
    t = r / (edge + rays)
    core = np.clip((1 - t) / 0.45, 0, 1) ** 1.3
    mask = Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    alpha = np.array(mask) / 255.0 * 0.6
    rgb = np.dstack([28 - 10 * core, 24 - 9 * core, 20 - 8 * core])
    return from_arrays(rgb, alpha)


def flame():
    alpha = blobs(32, [(0.5, 0.55, 0.26), (0.38, 0.45, 0.16), (0.6, 0.4, 0.17), (0.5, 0.3, 0.14)], 0.09)
    heat = (alpha ** 2.2)[:, :, None]
    outer, mid, core = np.array([255, 106, 26]), np.array([255, 180, 58]), np.array([255, 242, 168])
    rgb = np.where(heat < 0.6, outer + (mid - outer) * (heat / 0.6), mid + (core - mid) * ((heat - 0.6) / 0.4))
    return from_arrays(rgb, alpha)


def blood():
    r, theta = radial(96)
    rng = np.random.default_rng(11)
    edge = 0.55 + sum(rng.uniform(0.02, 0.06) * np.sin(k * theta + rng.uniform(0, 2 * pi)) for k in range(2, 7))
    pool = np.clip((edge - r) / 0.05, 0, 1)
    drops = blobs(96, [(0.5 + 0.4 * cos(a), 0.5 + 0.4 * sin(a), rr) for a, rr in
                       [(0.4, 0.035), (1.9, 0.028), (2.6, 0.04), (4.1, 0.03), (5.3, 0.025)]], 0.004)
    alpha = np.maximum(pool, drops)
    shade = np.clip(1 - r / 0.6, 0, 1)[:, :, None]
    rgb = np.array([150, 18, 24]) + np.array([50, 8, 8]) * shade
    return from_arrays(rgb, alpha * 0.9)


# ---------- D. Vật phẩm (nhìn từ trên) ----------

def cash():
    a = Art(32, 24)
    a.rect((4, 6, 30, 22), GREEN_DARK, 1)
    a.rect((2.75, 3, 28, 19), GREEN, 1)
    a.rect((4, 5, 26, 17), GREEN_DARK, 1)
    a.rect((5, 6, 25, 16), GREEN, 1)
    a.ellipse((10, 8, 17, 14), GREEN_LIGHT)
    a.rect((18, 3, 22, 19), PAPER)
    a.outline(1.25)
    return a.done()


def briefcase():
    a = Art(40, 30)
    a.rect((13, 2.75, 27, 10), METAL_HI, 3)
    a.rect((3, 8, 37, 28), "#6b4126", 3)
    a.rect((3, 8, 37, 25), "#8a5530", 3)
    a.rect((6, 11, 34, 13), "#a46a3f", 1)
    a.rect((8, 8, 13, 12), METAL_HI, 1)
    a.rect((27, 8, 32, 12), METAL_HI, 1)
    a.outline(1.25)
    a.hole((15.5, 4.25, 24.5, 8.5), 1, r=1)
    return a.done()


def medkit():
    a = Art(32, 28)
    a.rect((11, 2.75, 21, 6), METAL, 1)
    a.rect((3, 5, 29, 26), WHITE_SHADE, 3)
    a.rect((3, 5, 29, 23), WHITE, 3)
    a.rect((13.5, 8, 18.5, 21), RED, 1)
    a.rect((9.5, 12, 22.5, 17), RED, 1)
    a.outline(1.25)
    return a.done()


def armor_vest():
    a = Art(32, 32)
    left = curve((16, 9), (12, 9), (12, 3.5))[:-1] + [(12, 3.5), (5, 3.5)] + curve((5, 3.5), (5, 10), (2.5, 11.5))[1:]
    left += [(2.5, 27), (5, 29.5), (16, 29.5)]
    a.poly(left + [(32 - x, y) for x, y in reversed(left)], BLUE)
    a.rect((5, 12, 14, 22), BLUE_DARK, 1.5)
    a.rect((18, 12, 27, 22), BLUE_DARK, 1.5)
    a.rect((6, 13, 13, 15), BLUE_LIGHT, 1)
    a.rect((19, 13, 26, 15), BLUE_LIGHT, 1)
    a.rect((2.5, 23, 29.5, 26), METAL_LIGHT)
    a.line([(16, 9), (16, 29)], BLUE_DARK, 1)
    a.outline(1.25)
    return a.done()


def package():
    a = Art(28, 28)
    a.rect((3, 3, 25, 25), CARDBOARD, 1)
    a.rect((3, 22, 25, 25), CARDBOARD_DARK, 1)
    a.rect((12, 3, 16, 25), TAPE)
    a.rect((17.5, 15, 23, 20), WHITE, 0.5)
    a.outline(1.25)
    return a.done()


SPRITES = {
    "weapons/icon_pistol.png": icon_pistol,
    "weapons/icon_smg.png": icon_smg,
    "weapons/icon_shotgun.png": icon_shotgun,
    "weapons/icon_rifle.png": icon_rifle,
    "weapons/icon_sniper.png": icon_sniper,
    "weapons/icon_grenade.png": icon_grenade,
    "weapons/icon_flamethrower.png": icon_flamethrower,
    "weapons/icon_bazooka.png": icon_bazooka,
    "ui/icon_lock.png": icon_lock,
    "ui/icon_health.png": icon_health,
    "ui/icon_armor.png": icon_armor,
    "ui/icon_money.png": icon_money,
    "fx/muzzle_flash.png": muzzle_flash,
    "fx/shell.png": shell,
    "fx/glow.png": glow,
    "fx/smoke.png": smoke,
    "fx/spark.png": spark,
    "fx/rocket.png": rocket,
    "fx/grenade.png": grenade,
    "fx/scorch.png": scorch,
    "fx/flame.png": flame,
    "fx/blood.png": blood,
    "items/cash.png": cash,
    "items/briefcase.png": briefcase,
    "items/medkit.png": medkit,
    "items/armor_vest.png": armor_vest,
    "items/package.png": package,
}


def main():
    for name, make in SPRITES.items():
        path = OUT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        make().save(path, optimize=True)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()

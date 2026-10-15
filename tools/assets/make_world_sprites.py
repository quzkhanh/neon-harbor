#!/usr/bin/env python3
"""Sprite tự sinh cho đợt mở rộng (xe, truy nã 5 sao, việc phụ, cận chiến, thuyền), cùng phong cách make_sprites.py.

Tạo ra trong game/assets/sprites/:
  ui/icon_car.png, ui/icon_nitro.png      bảng xe trên HUD
  weapons/icon_fists.png, icon_bat.png     vũ khí cận chiến (cùng tỉ lệ với icon súng)
  items/token.png, items/badge.png         xu neon sưu tầm, huy hiệu hối lộ (giảm sao)
  world/spikes.png, world/ramp.png         dải đinh của rào chắn, dốc nhảy
  world/heli.png, world/rotor.png          trực thăng cảnh sát (thân hướng sang phải) và cánh quạt
  world/boat_red.png, world/boat_blue.png  thuyền máy (mũi hướng sang phải)

Chạy từ gốc repo:  python3 tools/assets/make_world_sprites.py   (tất định)
"""
from math import cos, pi, sin

from make_sprites import (BLUE, BLUE_DARK, BLUE_LIGHT, BRASS, BRASS_DARK, BRASS_HI, GLASS, METAL, METAL_HI,
                          METAL_LIGHT, OUT, OUTLINE, RED, RED_DARK, RED_LIGHT, ROOT, WHITE, WHITE_SHADE, WOOD,
                          WOOD_DARK, Art, centered, curve, weapon_art)

SKIN = "#e8b07a"
SKIN_DARK = "#c98d58"
YELLOW = "#f5c518"
NAVY = "#1d2a44"
NAVY_LIGHT = "#2f4166"
CYAN = "#2de2e6"
CYAN_DARK = "#159ca0"


def icon_car():
    a = Art(48, 48)
    a.rect((12, 3, 36, 45), RED_DARK, 8)
    a.rect((12, 3, 36, 42), RED, 8)
    a.rect((15, 11, 33, 19), GLASS, 3)
    a.rect((15, 30, 33, 36), GLASS, 2)
    a.rect((14, 4, 19, 7), "#fff4b0", 1)
    a.rect((29, 4, 34, 7), "#fff4b0", 1)
    a.outline(2.5)
    return a.done()


def icon_nitro():
    a = Art(48, 48)
    a.poly([(16, 34), (24, 47), (32, 34)], "#ff9a2e")
    a.poly([(19, 34), (24, 43), (29, 34)], "#ffe066")
    a.rect((14, 9, 34, 36), BLUE_DARK, 6)
    a.rect((14, 9, 34, 33), BLUE, 6)
    a.rect((17, 12, 22, 30), BLUE_LIGHT, 2)
    a.rect((19, 2, 29, 10), METAL_LIGHT, 2)
    a.outline(2.5)
    return a.done()


def icon_fists():
    a = weapon_art()
    a.rect((20, 20, 96, 72), SKIN_DARK, 18)
    a.rect((20, 16, 96, 66), SKIN, 18)
    for x in (24, 42, 60, 78):
        a.rect((x, 6, x + 18, 34), SKIN, 9)
        a.line([(x + 3, 30), (x + 15, 30)], SKIN_DARK, 2)
    a.poly([(20, 44), (52, 40), (58, 52), (24, 60)], SKIN_DARK)
    a.rect((88, 30, 128, 64), "#3b4a6b", 8)
    a.outline(3.5)
    return centered(a)


def icon_bat():
    a = weapon_art()
    pts = [(0, 34), (10, 30), (50, 28), (125, 19), (146, 21), (150, 34), (146, 47), (125, 49), (50, 40), (10, 38)]
    a.poly(pts, WOOD)
    a.poly([(50, 28), (125, 19), (146, 21), (148, 27), (125, 26), (50, 34)], "#e0a565")
    a.rect((0, 26, 34, 42), "#2b2f36", 4)
    for x in (6, 15, 24):
        a.line([(x, 27), (x + 4, 41)], METAL, 2)
    a.rect((-6, 24, 4, 44), WOOD_DARK, 3)
    a.outline(3.5)
    return centered(a)


def token():
    a = Art(28, 28)
    a.ellipse((2, 2, 26, 26), CYAN_DARK)
    a.ellipse((2, 2, 26, 24), CYAN)
    a.ellipse((7, 6, 21, 20), "#9ff7f9")
    a.poly([(14, 7), (19, 13), (14, 19), (9, 13)], CYAN_DARK)
    a.outline(1.25)
    return a.done()


def star_points(cx, cy, r_out, r_in, n=5, rot=-pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        t = rot + i * pi / n
        pts.append((cx + r * cos(t), cy + r * sin(t)))
    return pts


def badge():
    a = Art(32, 32)
    a.poly(star_points(16, 17, 14, 7, 6), BRASS_DARK)
    a.poly(star_points(16, 16, 14, 7, 6), BRASS)
    a.ellipse((11, 11, 21, 21), BRASS_HI)
    a.ellipse((13, 13, 19, 19), BRASS_DARK)
    a.outline(1.25)
    return a.done()


def spikes():
    a = Art(128, 20)
    a.rect((0, 6, 128, 14), "#2b2f36", 2)
    for i in range(16):
        x = 2 + i * 8
        a.poly([(x, 7), (x + 4, 0), (x + 6, 7)], METAL_HI)
        a.poly([(x, 13), (x + 4, 20), (x + 6, 13)], METAL_LIGHT)
    a.outline(1)
    return a.done()


def ramp():
    """Dốc nhìn từ trên: thấp ở trái, cao ở phải (sọc vàng đen, mép cao sáng)."""
    a = Art(64, 64)
    a.rect((2, 4, 62, 60), "#3a3d45", 3)
    for i in range(7):
        x0 = 4 + i * 9
        a.poly([(x0, 6), (x0 + 5, 6), (x0 + 5, 58), (x0, 58)], YELLOW if i % 2 == 0 else "#2b2f36")
    a.rect((54, 4, 62, 60), "#ffe066", 2)
    for y in (16, 30, 44):
        a.poly([(34, y), (20, y - 6), (20, y + 6)], (255, 255, 255, 170))
    a.outline(1.5)
    return a.done()


def heli():
    a = Art(150, 70, origin=(0, 0))
    a.rect((4, 30, 70, 40), NAVY, 4)
    a.rect((0, 22, 14, 48), NAVY, 3)
    a.ellipse((-2, 26, 16, 44), METAL_LIGHT)
    a.ellipse((50, 10, 136, 60), NAVY)
    a.ellipse((54, 14, 132, 54), NAVY_LIGHT)
    a.ellipse((104, 18, 140, 52), GLASS)
    a.ellipse((110, 24, 132, 40), "#c8f0fa")
    a.rect((70, 24, 100, 46), WHITE, 6)
    a.rect((74, 30, 96, 40), BLUE, 3)
    a.rect((60, 6, 104, 10), METAL, 2)
    a.rect((60, 60, 104, 64), METAL, 2)
    a.outline(2)
    return a.done()


def rotor():
    a = Art(200, 200, origin=(100, 100))
    for k in range(4):
        t = k * pi / 2 + 0.2
        c, s = cos(t), sin(t)
        pts = [(-6, 4), (96, 6), (98, 0), (96, -6), (-6, -4)]
        a.poly([(x * c - y * s, x * s + y * c) for x, y in pts], (40, 44, 52, 190))
    a.ellipse((-12, -12, 12, 12), METAL)
    a.ellipse((-6, -6, 6, 6), METAL_HI)
    return a.done()


def boat(main, dark):
    a = Art(120, 52, origin=(0, 0))
    hull = [(4, 8)] + curve((70, 4), (112, 8), (118, 26))[:-1] + curve((118, 26), (112, 44), (70, 48)) + [(4, 44)]
    a.poly(hull, dark)
    inner = [(8, 12)] + curve((70, 9), (106, 12), (112, 26))[:-1] + curve((112, 26), (106, 40), (70, 43)) + [(8, 40)]
    a.poly(inner, WHITE)
    a.poly([(8, 12), (60, 10), (60, 15), (8, 17)], main)
    a.poly([(8, 35), (60, 37), (60, 42), (8, 40)], main)
    a.rect((40, 17, 64, 35), WHITE_SHADE, 4)
    a.poly([(64, 16), (76, 20), (76, 32), (64, 36)], GLASS)
    a.rect((44, 20, 56, 32), "#3b4a6b", 3)
    a.rect((0, 20, 8, 32), METAL, 2)
    a.outline(2)
    return a.done()


SPRITES = {
    "ui/icon_car.png": icon_car,
    "ui/icon_nitro.png": icon_nitro,
    "weapons/icon_fists.png": icon_fists,
    "weapons/icon_bat.png": icon_bat,
    "items/token.png": token,
    "items/badge.png": badge,
    "world/spikes.png": spikes,
    "world/ramp.png": ramp,
    "world/heli.png": heli,
    "world/rotor.png": rotor,
    "world/boat_red.png": lambda: boat(RED, RED_DARK),
    "world/boat_blue.png": lambda: boat(BLUE, BLUE_DARK),
}


def main():
    for name, make in SPRITES.items():
        path = OUT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        make().save(path, optimize=True)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()

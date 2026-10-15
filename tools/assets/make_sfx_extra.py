#!/usr/bin/env python3
"""Âm thanh cho đợt mở rộng (nitro, trực thăng, mưa, cận chiến, nước, đua xe, thành tựu), cùng bộ hàm của make_sfx.py.

Chạy: python3 tools/assets/make_sfx_extra.py   (tất định; ghi vào game/assets/audio/sfx/)
"""
import numpy as np

import make_sfx as m
from make_sfx import SR, T, coin, dec, filt, midi, note, osc, saw_harm, svf_bp, thump

rng = np.random.default_rng(20261015)


def noise(t):
    return rng.uniform(-1, 1, len(t))


def nitro():
    t = T(0.7)
    sweep = svf_bp(noise(t), 400 + 2600 * np.clip(t / 0.5, 0, 1), 2.0)
    env = np.clip(t / 0.05, 0, 1) * np.exp(-np.maximum(t - 0.2, 0) / 0.25)
    return 1.4 * sweep * env + 0.5 * thump(t, 90, 45, 0.3)


def heli():
    t = T(1.0)
    blade = 12.0
    phase = (t * blade) % 1.0
    chop = np.exp(-phase / 0.12)
    body = filt(noise(t), 60, 700, loop=True)
    hum = osc(np.full(len(t), 36.0), [(1, 1), (2, 0.4), (3, 0.2)])  # 36 chu kỳ trọn trong vòng 1 s
    return 1.2 * body * chop + 0.25 * hum


def rain():
    t = T(2.0)
    hiss = filt(noise(t), 1200, 7000, loop=True)
    drops = np.zeros(len(t))
    for at in rng.uniform(0, 2.0, 70):
        f = rng.uniform(2500, 5000)
        drops += osc(np.full(len(t), f)) * dec(t, 0.004, at) * rng.uniform(0.2, 0.6)
    return 0.6 * hiss + filt(drops, 1500, 8000, loop=True)


def punch():
    t = T(0.25)
    return np.tanh(2.0 * (thump(t, 160, 55, 0.07) + 0.8 * filt(noise(t), 100, 1500) * dec(t, 0.02)))


def swing():
    t = T(0.22)
    x = svf_bp(noise(t), 600 + 1800 * np.sin(np.pi * np.clip(t / 0.2, 0, 1)), 1.5)
    return x * np.sin(np.pi * np.clip(t / 0.2, 0, 1)) ** 2


def splash():
    t = T(0.6)
    wash = filt(noise(t), 300, 3500) * (np.clip(t / 0.02, 0, 1) * dec(t, 0.18))
    bubbles = sum(osc(np.full(len(t), rng.uniform(500, 1200)) * (1 + 0.5 * np.clip((t - at) / 0.05, 0, 1)))
                  * dec(t, 0.03, at) for at in rng.uniform(0.05, 0.4, 6))
    return wash + 0.3 * bubbles


def tire_pop():
    t = T(0.8)
    bang = np.tanh(2.5 * (thump(t, 200, 60, 0.05) + filt(noise(t), 200, 4000) * dec(t, 0.015)))
    hiss = filt(noise(t), 2500, 9000) * np.clip((t - 0.03) / 0.02, 0, 1) * dec(t, 0.3, 0.03)
    return bang + 0.4 * hiss


def beep():
    t = T(0.2)
    return note(t, 0.0, 0.15, 880, [(1, 1), (3, 0.2)], 0.003)


def beep_go():
    t = T(0.5)
    return note(t, 0.0, 0.4, 1320, [(1, 1), (3, 0.2)], 0.003, 0.3)


def checkpoint():
    t = T(0.4)
    return coin(t, 0.0, 1175, 0.08) + coin(t, 0.07, 1568, 0.15)


def achievement():
    t = T(1.0)
    x = sum(note(t, i * 0.09, 0.09, midi(n), saw_harm(midi(n), rolloff=2000)) for i, n in enumerate([72, 76, 79, 84]))
    return x + note(t, 0.36, 0.5, midi(88), saw_harm(midi(88), rolloff=2500), 0.01, 0.35)


SOUNDS = {
    "nitro": (nitro, -6, False), "heli": (heli, -8, True), "rain": (rain, -16, True),
    "punch": (punch, -4, False), "swing": (swing, -10, False), "splash": (splash, -8, False),
    "tire_pop": (tire_pop, -4, False), "beep": (beep, -12, False), "beep_go": (beep_go, -10, False),
    "checkpoint": (checkpoint, -10, False), "achievement": (achievement, -9, False),
}


def main():
    m.OUT.mkdir(parents=True, exist_ok=True)
    for name, (fn, gain, loop) in SOUNDS.items():
        m.write_wav(m.OUT / f"{name}.wav", m.finish(fn(), gain, loop))
        print(f"{name}.wav")


if __name__ == "__main__":
    main()

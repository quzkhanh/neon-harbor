#!/usr/bin/env python3
"""Tổng hợp toàn bộ hiệu ứng âm thanh của game bằng numpy, ghi ra game/assets/audio/sfx/<tên>.wav.

WAV mono, 16-bit, 22050 Hz. Kết quả cố định (seed cố định), chạy lại cho ra cùng file.
Âm lặp (flame, engine, siren, skid) được dựng từ thành phần tuần hoàn chia hết độ dài vòng
và lọc nhiễu theo kiểu vòng tròn (FFT), nên nối đuôi vào đầu không có tiếng tách.

Chạy: python3 tools/assets/make_sfx.py
"""
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/audio/sfx"
SR = 22050
rng = np.random.default_rng(20261014)


def T(dur):
    return np.arange(int(round(dur * SR))) / SR


def noise(t):
    return rng.uniform(-1, 1, len(t))


def filt(x, lo=0, hi=0, order=2, loop=False):
    """Lọc thông dải bằng FFT. loop=True lọc vòng tròn để giữ tính liền mạch."""
    n = len(x) if loop else 1 << (2 * len(x) - 1).bit_length()
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 1e-6)
    h = np.ones_like(f)
    if hi:
        h /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        h /= np.sqrt(1 + (lo / f) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, n) * h, n)[:len(x)]


def dec(t, tau, at=0.0):
    u = t - at
    return np.where(u >= 0, np.exp(-np.maximum(u, 0) / tau), 0.0)


def osc(freq, harmonics=(1,)):
    """Dao động theo tần số tức thời; harmonics là danh sách (bậc, biên độ) hoặc bậc."""
    ph = 2 * np.pi * np.concatenate(([0.0], np.cumsum(freq)[:-1])) / SR
    out = np.zeros_like(ph)
    for h in harmonics:
        k, a = h if isinstance(h, tuple) else (h, 1.0)
        out += a * np.sin(k * ph)
    return out


def thump(t, f0, f1, tau, at=0.0):
    u = np.maximum(t - at, 0)
    return osc(f1 + (f0 - f1) * np.exp(-u / (tau * 0.5))) * dec(t, tau, at)


def saw_harm(f, top=5000, rolloff=2500):
    return [(k, (1 / k) / (1 + (k * f / rolloff) ** 2)) for k in range(1, int(top / f) + 1)]


def note(t, at, dur, f, harm, attack=0.004, tau=None):
    u = t - at
    env = np.clip(u / attack, 0, 1) * np.clip(1 - (u - dur) / 0.04, 0, 1)
    if tau:
        env *= np.exp(-np.maximum(u, 0) / tau)
    return osc(np.full(len(t), f), harm) * env


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def svf_bp(x, fc, q=1.4):
    """Lọc thông dải quét tần số (state-variable), dùng cho tiếng vút."""
    y, lp, bp = np.zeros_like(x), 0.0, 0.0
    fs = (2 * np.sin(np.pi * np.minimum(fc, 3200) / SR)).tolist()
    for i, xi in enumerate(x.tolist()):
        hp = xi - lp - bp / q
        bp += fs[i] * hp
        lp += fs[i] * bp
        y[i] = bp
    return y


def echo(x, taps):
    out = x.copy()
    for delay, gain in taps:
        d = int(delay * SR)
        out[d:] += gain * filt(x, 150, 2500)[:len(x) - d]
    return out


# --- Súng ---

def pistol():
    t = T(0.25)
    return np.tanh(1.5 * (filt(noise(t), 800, 7000) * dec(t, 0.012) + 0.8 * filt(noise(t), 150, 2000) * dec(t, 0.045)
                          + 0.55 * thump(t, 260, 90, 0.04)))


def smg():
    t = T(0.12)
    return np.tanh(2 * (filt(noise(t), 1500, 9000) * dec(t, 0.006) + 0.6 * filt(noise(t), 300, 3000) * dec(t, 0.014)
                        + 0.5 * thump(t, 280, 120, 0.016)))


def shotgun():
    t = T(0.5)
    crack = sum(filt(noise(t), 500, 6000) * dec(t, 0.02, at) for at in (0.0, 0.004, 0.009))
    x = (crack + 1.6 * filt(noise(t), 80, 1500) * dec(t, 0.09) + 0.5 * filt(noise(t), 40, 400) * dec(t, 0.18)
         + 0.6 * thump(t, 170, 55, 0.12))
    return np.tanh(1.4 * x)


def rifle():
    t = T(0.3)
    return np.tanh(2 * (1.2 * filt(noise(t), 2000, 10000) * dec(t, 0.005) + filt(noise(t), 400, 4000) * dec(t, 0.025)
                        + 0.35 * thump(t, 200, 85, 0.035) + 0.25 * filt(noise(t), 200, 1500) * dec(t, 0.1)))


def sniper():
    t = T(0.9)
    x = (2.0 * filt(noise(t), 1500, 10000) * dec(t, 0.006) + 1.3 * filt(noise(t), 200, 3000) * dec(t, 0.04)
         + 0.5 * thump(t, 140, 55, 0.08))
    tail = 0.12 * filt(noise(t), 100, 1200) * (1 - dec(t, 0.05)) * dec(t, 0.25)
    return np.tanh(1.3 * echo(x, [(0.11, 0.35), (0.24, 0.22), (0.4, 0.13), (0.58, 0.07)]) + tail)


def rocket():
    t = T(0.6)
    env = (1 - dec(t, 0.03)) * dec(t, 0.22)
    whoosh = svf_bp(noise(t), 400 + 2200 * (1 - np.exp(-t / 0.12)) * np.exp(-t / 0.5))
    return (0.8 * thump(t, 160, 60, 0.04) + 0.5 * filt(noise(t), 600, 5000) * dec(t, 0.01)
            + 1.4 * whoosh * env + 0.7 * filt(noise(t), 30, 200) * env)


def throw():
    t = T(0.25)
    bell = np.sin(np.pi * t / t[-1]) ** 2
    return svf_bp(noise(t), 300 + 700 * bell, q=2.0) * bell


def flame():
    t = T(1.0)
    flicker = 1 + sum(0.12 * np.sin(2 * np.pi * k * t + rng.uniform(0, 6.3)) for k in rng.integers(3, 18, 5))
    sparks = np.zeros(len(t))
    sparks[rng.integers(0, len(t), 70)] = rng.uniform(-1, 1, 70)
    return (filt(noise(t), 150, 3000, loop=True) * flicker + 1.5 * filt(noise(t), 40, 250, loop=True)
            + 2.5 * filt(sparks, 1000, 6000, loop=True))


# --- Va chạm, nổ ---

def explosion():
    t = T(1.6)
    w = dec(t, 0.15)
    body = (w * filt(noise(t), 60, 2500) + (1 - w) * 1.6 * filt(noise(t), 30, 600)) * (1 - dec(t, 0.005)) * dec(t, 0.45)
    x = (filt(noise(t), 200, 6000) * dec(t, 0.03) + 1.5 * body + 0.7 * thump(t, 100, 35, 0.3)
         + 1.2 * filt(noise(t), 20, 120) * (1 - dec(t, 0.08)) * dec(t, 0.7))
    return np.tanh(2.2 * x)


def impact():
    t = T(0.15)
    ping = osc(1900 + 700 * np.exp(-t / 0.03), [1, (2.4, 0.3)]) * dec(t, 0.035, 0.004)
    return filt(noise(t), 2500, 9000) * dec(t, 0.004) + 0.4 * filt(noise(t), 200, 1500) * dec(t, 0.01) + 0.35 * ping


def hit():
    t = T(0.12)
    return np.tanh(1.5 * (1.3 * filt(noise(t), 100, 1200) * dec(t, 0.025) + 0.6 * thump(t, 180, 80, 0.035)))


def click(t, at, freqs, tau, body=0.0):
    x = filt(noise(t), 2000, 9000) * dec(t, 0.003, at) + body * thump(t, 260, 140, 0.02, at)
    return x + 0.3 * sum(osc(np.full(len(t), f)) for f in freqs) * dec(t, tau, at)


def reload():
    t = T(0.5)
    return click(t, 0.04, [1800, 2650], 0.012, 0.3) + 1.2 * click(t, 0.31, [1500, 2300], 0.018, 0.6)


def empty():
    t = T(0.08)
    return click(t, 0.003, [3200, 4700], 0.006)


def hurt():
    t = T(0.2)
    return np.tanh(1.4 * (0.8 * thump(t, 200, 70, 0.06) + filt(noise(t), 60, 600) * dec(t, 0.05)))


# --- Xe ---

def engine():
    t = T(1.0)
    f0 = 60.0
    harm = [(k, (k ** -0.9) / (1 + (k * f0 / 450) ** 2)) for k in range(1, 24)]
    hum = osc(np.full(len(t), f0), harm) * (1 + 0.25 * np.sin(2 * np.pi * 30 * t) + 0.05 * np.sin(2 * np.pi * 3 * t))
    puffs = (0.5 + 0.5 * np.sin(2 * np.pi * f0 * t)) ** 4
    return hum + 0.5 * filt(noise(t), 40, 500, loop=True) * puffs


def looped_freq(f):
    """Co giãn tần số để số chu kỳ trong vòng lặp là số nguyên (pha liền mạch)."""
    cycles = f.sum() / SR
    return f * round(cycles) / cycles


def siren():
    t = T(1.6)
    step = np.where((t % 0.8) < 0.4, 870.0, 650.0)
    f = looped_freq(filt(step - step.mean(), 0, 30, loop=True) + step.mean())
    return np.tanh(1.5 * osc(f, [(1, 1), (2, 0.15), (3, 0.33), (5, 0.15), (7, 0.07)]))


def skid():
    t = T(0.8)
    base = 1.25
    jitter = sum(rng.uniform(5, 25) * np.sin(2 * np.pi * base * k * t + rng.uniform(0, 6.3))
                 for k in rng.integers(4, 48, 8))
    f = looped_freq(1450 + jitter)
    amp = 0.85 + 0.15 * np.sin(2 * np.pi * base * 12 * t)
    return amp * osc(f, [(1, 1), (2, 0.4), (3, 0.15)]) + 0.4 * filt(noise(t), 800, 5000, loop=True)


def horn():
    t = T(0.4)
    sq = lambda f: osc(np.full(len(t), f), [(k, 1 / k / (1 + (k * f / 2000) ** 2)) for k in range(1, 12, 2)])
    env = np.clip(t / 0.01, 0, 1) * np.clip((t[-1] - t) / 0.05, 0, 1)
    return np.tanh(2 * (sq(392) + sq(396) + 0.9 * sq(494) + 0.9 * sq(490)) * env / 4)


def crash():
    t = T(0.5)
    grains = sum(dec(t, rng.uniform(0.006, 0.025), at) for at in rng.exponential(0.08, 28))
    metal = sum(osc(np.full(len(t), rng.uniform(400, 3500))) * dec(t, rng.uniform(0.06, 0.2)) for _ in range(8))
    return np.tanh(1.3 * (filt(noise(t), 400, 6000) * grains * 0.5 + 0.12 * metal + thump(t, 120, 50, 0.06)))


def door():
    t = T(0.25)
    latch = filt(noise(t), 2000, 8000)
    return (0.7 * thump(t, 140, 60, 0.05) + 1.3 * filt(noise(t), 80, 900) * dec(t, 0.03)
            + 0.3 * latch * dec(t, 0.003) + 0.2 * latch * dec(t, 0.003, 0.06))


# --- Giao diện ---

def coin(t, at, f, tau):
    return osc(np.full(len(t), f), [1, (2, 0.25), (2.76, 0.12)]) * dec(t, tau, at) * np.clip((t - at) / 0.002, 0, 1)


def cash():
    t = T(0.35)
    return coin(t, 0.0, 988, 0.06) + coin(t, 0.075, 1319, 0.11)


def pickup():
    t = T(0.2)
    f = 520 * 2 ** np.clip(t / 0.12, 0, 1)
    return osc(f, [1, (3, 0.11)]) * np.clip(t / 0.005, 0, 1) * dec(t, 0.06)


def mission_complete():
    t = T(1.6)
    x = sum(note(t, i * 0.12, 0.11, midi(m), saw_harm(midi(m))) for i, m in enumerate([67, 72, 74, 79]))
    return x + sum(note(t, 0.5, 1.0, midi(m), saw_harm(midi(m), rolloff=1800), 0.01, 0.6) for m in (72, 76, 79, 84))


def mission_fail():
    t = T(1.2)
    x = sum(note(t, i * 0.24, 0.21, midi(m), saw_harm(midi(m), rolloff=900)) for i, m in enumerate([69, 65]))
    f = midi(62) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t)) * (1 - 0.03 * np.clip((t - 0.8) / 0.3, 0, 1))
    tail = osc(f, saw_harm(midi(62), rolloff=900)) * np.clip((t - 0.48) / 0.01, 0, 1) * dec(t, 0.35, 0.48)
    return x + tail


def star():
    t = T(0.6)
    sq = lambda f: [(k, 1 / k / (1 + (k * f / 2500) ** 2)) for k in range(1, 8, 2)]
    return sum(note(t, i * 0.15, 0.12, f, sq(f), 0.003) for i, f in enumerate([1047, 784, 1047, 784]))


# Tên: (hàm, độ lớn dB so với -1 dBFS, có lặp hay không)
SOUNDS = {
    "pistol": (pistol, 0, False), "smg": (smg, -1, False), "shotgun": (shotgun, -1, False),
    "rifle": (rifle, 0, False), "sniper": (sniper, 0, False), "rocket": (rocket, -1, False),
    "throw": (throw, -8, False), "flame": (flame, 0, True), "explosion": (explosion, 0, False),
    "impact": (impact, -5, False), "hit": (hit, -5, False), "reload": (reload, -5, False),
    "empty": (empty, -5, False), "engine": (engine, -7, True), "siren": (siren, -15, True),
    "skid": (skid, -10, True), "horn": (horn, -12, False), "crash": (crash, -4, False),
    "door": (door, -3, False), "cash": (cash, -10, False), "pickup": (pickup, -14, False),
    "mission_complete": (mission_complete, -9, False), "mission_fail": (mission_fail, -13, False),
    "star": (star, -15, False), "hurt": (hurt, -7, False),
}


def finish(x, gain_db, loop):
    x = filt(x, 25, loop=loop)
    if not loop:
        n_in, n_out = int(0.0015 * SR), int(0.015 * SR)
        x[:n_in] *= np.linspace(0, 1, n_in)
        x[-n_out:] *= np.cos(np.linspace(0, np.pi / 2, n_out)) ** 2
    return x / np.abs(x).max() * 10 ** ((gain_db - 1) / 20)


def write_wav(path, x):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (fn, gain, loop) in SOUNDS.items():
        write_wav(OUT / f"{name}.wav", finish(fn(), gain, loop))
        print(f"{name}.wav")


if __name__ == "__main__":
    main()

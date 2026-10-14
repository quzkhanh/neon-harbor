#!/usr/bin/env python3
"""Tổng hợp nhạc nền của game (synthwave tối, La thứ, 105 BPM) và ghi ra game/assets/audio/music/theme.ogg.

Một vòng lặp 32 ô nhịp (~73 giây), stereo 44100 Hz, mã hoá OGG Vorbis bằng ffmpeg.
Mọi nốt được dựng vào bộ đệm dài hơn vòng lặp rồi phần đuôi được cộng vòng về đầu;
delay và reverb tính theo kiểu vòng tròn, nên điểm nối vòng không có khoảng lặng hay tiếng tách.
Giai điệu, hợp âm và âm sắc đều tự soạn trong file này. Seed cố định nên kết quả không đổi.

Chạy: python3 tools/assets/make_music.py   (cần ffmpeg có libvorbis)
"""
import subprocess
import tempfile
import wave
from functools import lru_cache
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/audio/music/theme.ogg"
SR = 44100
STEP = 6300  # một nốt móc kép ở 105 BPM, tròn số mẫu
BARS = 32
L = BARS * 16 * STEP
TAIL = 32 * STEP
rng = np.random.default_rng(105)

# Vòng hợp âm 8 ô nhịp, mỗi hợp âm 2 ô: Am - F - Dm - E
CHORDS = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59]]
# Giai điệu chính: (bước móc kép trong vòng 8 ô, độ dài bước, nốt MIDI)
LEAD = [(0, 6, 76), (6, 2, 74), (8, 4, 72), (12, 4, 74), (16, 12, 76), (28, 4, 69),
        (32, 6, 77), (38, 2, 76), (40, 4, 72), (44, 4, 69), (48, 12, 72),
        (64, 6, 74), (70, 2, 77), (72, 8, 81), (80, 4, 79), (84, 4, 77), (88, 8, 74),
        (96, 8, 76), (104, 4, 74), (108, 4, 71), (112, 12, 68), (124, 4, 71)]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def chord(bar):
    return CHORDS[(bar // 2) % 4]


@lru_cache(None)
def table(shape, f, cutoff):
    k = np.arange(1, max(2, int(min(cutoff, SR * 0.45) / f)) + 1)
    amp = 1 / k if shape == "saw" else (k % 2) / k
    return (amp[:, None] * np.sin(2 * np.pi * np.outer(k, np.arange(4097) / 4096))).sum(0)


def osc(f, n, shape="saw", cutoff=5000):
    """Dao động bảng sóng giới hạn dải (không răng cưa phổ)."""
    f = np.broadcast_to(np.asarray(f, float), (n,))
    ph = (rng.random() + np.cumsum(f) / SR) % 1
    return np.interp(ph * 4096, np.arange(4097), table(shape, round(float(f.mean())), cutoff))


def env(n, a, r, tau=None):
    t = np.arange(n) / SR
    e = np.minimum(t / a, 1) * np.clip((t[-1] - t) / r, 0, 1)
    return e * np.exp(-t / tau) if tau else e


def filt(x, lo=0, hi=0):
    """Lọc FFT vòng tròn theo trục thời gian, giữ vòng lặp liền mạch."""
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / SR), 1e-6)
    h = 1 / np.sqrt(1 + (f / hi) ** 4) if hi else np.ones_like(f)
    if lo:
        h /= np.sqrt(1 + (lo / f) ** 4)
    return np.fft.irfft(np.fft.rfft(x, axis=0) * (h[:, None] if x.ndim > 1 else h), len(x), axis=0)


def buf(ch=1):
    return np.zeros((L + TAIL, ch)) if ch > 1 else np.zeros(L + TAIL)


def place(b, step, sig):
    s = step * STEP
    b[s:s + len(sig)] += sig


def fold(x):
    x = x.copy()
    x[:TAIL] += x[L:]
    return x[:L]


# --- Trống ---

def kick_hit():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(45 + 85 * np.exp(-t / 0.03)) / SR) * np.exp(-t / 0.2)
    return (body + 0.3 * rng.uniform(-1, 1, n) * np.exp(-t / 0.004)) * env(n, 0.001, 0.02)


def snare_hit():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    return (filt(noise, 1200, 7000) * np.exp(-t / 0.1) + 0.6 * np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05)
            + 0.5 * filt(noise, 0, 1000) * np.exp(-t / 0.05)) * env(n, 0.001, 0.02)


def hat_hit(tau):
    n = int(6 * tau * SR)
    return filt(rng.uniform(-1, 1, n), 7000) * np.exp(-np.arange(n) / SR / tau) * env(n, 0.001, 0.01)


def kick_steps(bar):
    return (0, 4, 8, 12) if bar >= 4 else (0, 8)


def drums():
    kick, snare, hats = buf(), buf(), buf()
    k, s, ch, oh = kick_hit(), snare_hit(), hat_hit(0.03), hat_hit(0.18)
    for bar in range(BARS):
        b = bar * 16
        for step in kick_steps(bar):
            place(kick, b + step, k)
        if bar >= 4:
            place(snare, b + 4, s)
            place(snare, b + 12, s)
        for step in range(16):
            place(hats, b + step, oh * 0.6 if step == 14 else ch * (0.5, 0.25, 0.9, 0.3)[step % 4])
    return fold(kick), fold(snare), fold(hats)


def sidechain():
    """Nén theo nhịp trống kick (nhịp thở đặc trưng của synthwave)."""
    hits = np.zeros(L)
    hits[[(bar * 16 + s) * STEP for bar in range(BARS) for s in kick_steps(bar)]] = 1
    t = np.arange(int(0.5 * SR)) / SR
    k = np.zeros(L)
    k[:len(t)] = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.15)
    return 1 - 0.55 * np.minimum(np.fft.irfft(np.fft.rfft(hits) * np.fft.rfft(k), L), 1)


# --- Nhạc cụ ---

def bass():
    b = buf()
    n = int(STEP * 0.85)
    for bar in range(BARS):
        root = chord(bar)[0] - 12
        for step in range(16):
            f = hz(root + 12 if step % 4 == 3 else root)
            sig = osc(f, n, "saw", 2500) * env(n, 0.003, 0.01, 0.1) + 0.6 * osc(f, n, "square", 500) * env(n, 0.003, 0.01)
            place(b, bar * 16 + step, sig * (1.0 if step % 2 == 0 else 0.75))
    return filt(fold(b), 30, 900)


def pad():
    b = buf(2)
    n = 32 * STEP + int(0.6 * SR)
    for bar in range(0, BARS, 2):
        e = env(n, 0.4, 0.6)
        for m in chord(bar) + [chord(bar)[0] + 12]:
            left = osc(hz(m) * 2 ** (-9 / 1200), n, "saw", 3000) + 0.7 * osc(hz(m), n, "saw", 3000)
            right = osc(hz(m) * 2 ** (9 / 1200), n, "saw", 3000) + 0.7 * osc(hz(m), n, "saw", 3000)
            place(b, bar * 16, np.stack([left, right], 1) * e[:, None])
    return filt(fold(b), 80, 1600)


def arp():
    b = buf()
    for bar in range(8, BARS):
        notes = [m + 12 for m in chord(bar)] + [chord(bar)[0] + 24]
        for step in range(16):
            m = notes[(0, 1, 2, 3, 1, 2, 3, 2)[step % 8]]
            place(b, bar * 16 + step, osc(hz(m), STEP, "square", 4000) * env(STEP, 0.002, 0.01, 0.09))
    return filt(fold(b), 150, 3000)


def lead():
    b = buf()
    for start in (16 * 16, 24 * 16):
        for step, length, m in LEAD:
            n = length * STEP + int(0.12 * SR)
            t = np.arange(n) / SR
            f = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.3, 1))
            sig = osc(f, n, "saw", 3500) + 0.5 * osc(f, n, "square", 3500)
            place(b, start + step, sig * env(n, 0.015, 0.12))
    return filt(fold(b), 200, 3200)


# --- Hiệu ứng ---

def pingpong(x, d=3 * STEP, fb=0.45, taps=6):
    out = np.zeros((L, 2))
    for i in range(1, taps + 1):
        out[:, i % 2] += fb ** i * np.roll(x, i * d)
    return filt(out, 200, 2500)


def reverb(x, secs=2.2):
    n = int(secs * SR)
    t = np.arange(n) / SR
    out = np.zeros((L, 2))
    for ch in range(2):
        ir = np.zeros(L)
        ir[int(0.02 * SR):int(0.02 * SR) + n] = rng.uniform(-1, 1, n) * np.exp(-t * 6.9 / secs)
        ir = filt(ir, 0, 4500)
        out[:, ch] = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir / np.sqrt((ir ** 2).sum())), L)
    return out


def stereo(x, pan=0.0):
    return np.stack([x * np.sqrt(0.5 - pan / 2), x * np.sqrt(0.5 + pan / 2)], 1)


def mix():
    kick, snare, hats = drums()
    duck = sidechain()[:, None]
    sn, ar, ld = 0.6 * snare, 0.18 * arp(), 0.16 * lead()
    master = (stereo(0.9 * kick) + stereo(sn) + stereo(0.2 * hats, 0.3)
              + stereo(0.5 * bass()) * duck + 0.08 * pad() * duck + stereo(ar, -0.2) + stereo(ld)
              + 0.35 * pingpong(ar + ld) + 0.3 * reverb(sn + ar + ld))
    master -= master.mean(0)
    return master / np.abs(master).max() * 10 ** (-3 / 20)


def main():
    x = mix()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "theme.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(OUT)],
                       check=True)
    print(f"{OUT.relative_to(ROOT)}: {L / SR:.1f}s, {OUT.stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()

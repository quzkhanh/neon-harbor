#!/usr/bin/env python3
"""Tạo một trang HTML xem trước duy nhất (tự chứa, < 512 KB): ảnh chụp thật + trình phát âm thanh.

Dùng: python3 tools/checks/make_preview.py [file_ra]   (mặc định reference/preview.html)
Ảnh lấy từ reference/shots/ (chạy tools/checks/take_shots.sh trước), âm thanh từ game/assets/audio/.
Ảnh nén WebP, âm thanh nén Ogg Opus bằng ffmpeg để vừa giới hạn kích thước.
"""
import base64
import io
import subprocess
import sys
from html import escape
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "reference/shots"
AUDIO = ROOT / "game/assets/audio"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "reference/preview.html"
WIDTH = 640
QUALITY = 52
MUSIC_SECONDS = 24
LIMIT = 512 * 1024

GALLERY = [
    ("menu_vi", "Menu (tiếng Việt)"),
    ("city_walk_en", "Đi bộ trong thành phố"),
    ("combat_en", "Bắn nhau với Red Fangs"),
    ("driving_en", "Lái xe, drift"),
    ("wanted3_vi", "Truy nã 3 sao"),
    ("shop_vi", "Cửa hàng súng"),
    ("dialog_vi", "Hộp thoại nhiệm vụ"),
    ("mission_complete_en", "Hoàn thành nhiệm vụ + nút quảng cáo"),
    ("hospital_vi", "Bệnh viện sau khi chết"),
    ("touch_vi", "Điều khiển cảm ứng"),
    ("shop_en_pseudo", "Pseudolocalization (chữ dài hơn 40%)"),
    ("web_play", "Bản Web trong Chrome"),
]
SOUNDS = [("pistol", "Súng lục"), ("shotgun", "Shotgun"), ("sniper", "Bắn tỉa"), ("explosion", "Nổ"),
          ("siren", "Còi cảnh sát"), ("horn", "Còi xe"), ("cash", "Nhặt tiền"), ("mission_complete", "Xong nhiệm vụ")]


def image_uri(name):
    im = Image.open(SHOTS / f"{name}.png").convert("RGB")
    im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=QUALITY, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()


def audio_uri(path, seconds=None, bitrate="24k"):
    cmd = ["ffmpeg", "-v", "error", "-i", str(path)]
    if seconds:
        cmd += ["-t", str(seconds), "-af", f"afade=t=out:st={seconds - 2}:d=2"]
    cmd += ["-ac", "1", "-c:a", "libopus", "-b:a", bitrate, "-f", "ogg", "-"]
    data = subprocess.run(cmd, check=True, capture_output=True).stdout
    return "data:audio/ogg;base64," + base64.b64encode(data).decode()


def main():
    cards = []
    for name, caption in GALLERY:
        if (SHOTS / f"{name}.png").exists():
            cards.append(f'<figure><img src="{image_uri(name)}" alt="{escape(caption)}"><figcaption>{escape(caption)}</figcaption></figure>')
    music = audio_uri(AUDIO / "music/theme.ogg", MUSIC_SECONDS, "32k")
    sounds = "".join(
        f'<div class="snd"><span>{escape(label)}</span><audio controls preload="none" src="{audio_uri(AUDIO / f"sfx/{n}.wav")}"></audio></div>'
        for n, label in SOUNDS)
    html = f"""<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Neon Harbor — xem trước</title>
<style>
body{{margin:0;font-family:system-ui,sans-serif;background:#0d0f19;color:#f2f4ff}}
main{{max-width:1320px;margin:auto;padding:16px}}
h1{{color:#ff3d7f;margin:4px 0}} h2{{margin:20px 0 8px;font-size:18px;color:#2de2e6}}
p{{color:#9aa3c7;margin:4px 0 12px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}}
figure{{margin:0;background:#121626;border:1px solid #2e3760;border-radius:10px;overflow:hidden}}
img{{width:100%;display:block}} figcaption{{padding:8px 10px;font-size:14px}}
.snd{{display:flex;align-items:center;gap:10px;margin:6px 0}} .snd span{{min-width:120px;font-size:14px}}
audio{{width:100%;max-width:420px;height:36px}}
</style></head><body><main>
<h1>Neon Harbor</h1><p>Lát cắt dọc: ảnh chụp thật trong game (Godot 4.7.2), nhạc nền và hiệu ứng âm thanh tự sinh.</p>
<h2>Ảnh chụp</h2><div class="grid">{''.join(cards)}</div>
<h2>Nhạc nền ({MUSIC_SECONDS} giây đầu)</h2><audio controls preload="none" src="{music}"></audio>
<h2>Hiệu ứng âm thanh</h2>{sounds}
</main></body></html>"""
    OUT.write_text(html, encoding="utf-8")
    size = OUT.stat().st_size
    print(f"preview: {OUT} — {size / 1024:.0f} KB, {len(cards)} ảnh, {len(SOUNDS)} âm thanh")
    return 0 if size <= LIMIT else 1


if __name__ == "__main__":
    sys.exit(main())

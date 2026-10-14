#!/usr/bin/env python3
"""Kiểm tra đa ngôn ngữ của Neon Harbor.

Dùng: python3 tools/checks/check_i18n.py [thư_mục_game]   (mặc định game/)
Fail (exit 1) nếu:
  - (bỏ qua game/tests/: không phải chữ hiển thị trong game)
  - có chữ thường gán vào text/tooltip_text/title (.gd, .tscn) hoặc truyền vào Ui.label/button/live_label mà không phải khoá;
  - khoá dùng trong code/scene/dữ liệu mà thiếu trong strings.csv, hoặc ô dịch trống;
  - {tham_số} lệch giữa các ngôn ngữ;
  - khoá trong CSV không còn được dùng (khoá X_PLURAL được tính là dùng khi X được dùng: LiveLabel gọi tr_n).
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY_SHAPE = re.compile(r"^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
ASSIGN = re.compile(r'\b(text|tooltip_text|title)\s*=\s*"((?:[^"\\]|\\.)*)"')
UI_CALL = re.compile(r'\bUi\.(label|button|live_label)\(\s*"((?:[^"\\]|\\.)*)"')
PARAM = re.compile(r"\{([a-z_][a-z0-9_]*)\}")
PLURAL = "_PLURAL"


def load_csv(path, errors):
    with path.open(encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    header, body = rows[0], rows[1:]
    if header[0] != "keys" or len(header) < 3:
        errors.append(f"tiêu đề CSV phải là keys,<ngôn ngữ>...: {header}")
    table = {}
    for i, row in enumerate(body, start=2):
        if len(row) != len(header):
            errors.append(f"strings.csv dòng {i}: số cột {len(row)} khác {len(header)}")
            continue
        key = row[0]
        if key in table:
            errors.append(f"khoá trùng: {key}")
        table[key] = dict(zip(header[1:], row[1:]))
    return header[1:], table


def scan_sources(game, keys, errors):
    used = set()
    for path in sorted(game.rglob("*")):
        if path.suffix not in (".gd", ".tscn", ".json") or ".godot" in path.parts or "tests" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(game)
        for n, line in enumerate(text.splitlines(), start=1):
            if line.lstrip().startswith("#"):
                continue
            for m in STRING.finditer(line):
                lit = m.group(1)
                if lit in keys:
                    used.add(lit)
                elif KEY_SHAPE.match(lit) and path.suffix != ".json" or (path.suffix == ".json" and KEY_SHAPE.match(lit) and _json_text_field(line, lit)):
                    errors.append(f"{rel}:{n}: khoá {lit!r} không có trong strings.csv")
            if path.suffix in (".gd", ".tscn"):
                for m in list(ASSIGN.finditer(line)) + list(UI_CALL.finditer(line)):
                    lit = m.group(2)
                    if lit and lit not in keys:
                        errors.append(f"{rel}:{n}: chữ viết cứng {lit!r} (phải là khoá dịch)")
    return used


def check_table(langs, table, errors):
    for key, values in table.items():
        for lang in langs:
            if values.get(lang, "").strip() == "":
                errors.append(f"khoá {key}: ô dịch '{lang}' trống")
        params = {lang: set(PARAM.findall(values.get(lang, ""))) for lang in langs}
        first = params[langs[0]]
        for lang in langs[1:]:
            if params[lang] != first:
                errors.append(f"khoá {key}: tham số lệch {langs[0]}={sorted(first)} {lang}={sorted(params[lang])}")


def main():
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game"
    errors = []
    langs, table = load_csv(game / "i18n/strings.csv", errors)
    keys = set(table)
    used = scan_sources(game, keys, errors)
    used |= {k for k in keys if k.endswith(PLURAL) and k[: -len(PLURAL)] in used}
    check_table(langs, table, errors)
    for key in sorted(keys - used):
        errors.append(f"khoá {key} trong CSV không còn được dùng")
    for e in errors:
        print("LỖI:", e)
    if errors:
        print(f"check_i18n: FAIL ({len(errors)} lỗi)")
        return 1
    print(f"check_i18n: PASS — {len(keys)} khoá, ngôn ngữ: {', '.join(langs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

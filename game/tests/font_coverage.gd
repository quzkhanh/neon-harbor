extends "res://tests/harness.gd"
## Mọi ký tự trong mọi cột ngôn ngữ của strings.csv đều có trong chuỗi font (font chính + dự phòng).

const CSV := "res://i18n/strings.csv"
const WEIGHTS := ["Regular", "SemiBold", "Bold", "ExtraBold"]
const FONT := "res://assets/fonts/BeVietnamPro-%s.ttf"
const FALLBACKS := ["res://assets/fonts/NotoSans-Regular.ttf", "res://assets/fonts/NotoSansMath-Symbols.ttf"]


func _run() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	var header := f.get_csv_line()
	var chars := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		for i in range(1, mini(row.size(), header.size())):
			for c in row[i]:
				chars[c] = header[i]
	var fallbacks: Array = FALLBACKS.map(func(p: String) -> Font: return load(p))
	var fallback_only := 0
	for weight in WEIGHTS:
		var main: Font = load(FONT % weight)
		for c in chars:
			var code: int = c.unicode_at(0)
			if code < 32:
				continue
			var in_main := main.has_char(code)
			if not in_main and not fallbacks.any(func(fb: Font) -> bool: return fb.has_char(code)):
				expect(false, "thiếu ký tự %s (U+%04X, cột %s) trong font %s và font dự phòng" % [c, code, chars[c], weight])
			elif not in_main and weight == WEIGHTS[0]:
				fallback_only += 1
	print("font_coverage: %d ký tự, %d ký tự chỉ có ở font dự phòng" % [chars.size(), fallback_only])
	finish("FONT_COVERAGE")

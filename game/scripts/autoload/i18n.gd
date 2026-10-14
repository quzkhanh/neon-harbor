extends Node
## Autoload `I18n`: nạp bảng dịch, chọn ngôn ngữ, định dạng tiền và số theo ngôn ngữ.
## Định dạng cũng nằm trong bảng dịch (FMT_MONEY, FMT_THOUSANDS) nên thêm ngôn ngữ không phải sửa code.

signal language_changed(lang: String)

const LANGUAGES := ["en", "vi"]
const FALLBACK := "en"
const TRANSLATION_PATH := "res://i18n/strings.%s.translation"

var language := FALLBACK


func _ready() -> void:
	for lang in LANGUAGES:
		TranslationServer.add_translation(load(TRANSLATION_PATH % lang))
	set_language(system_language())


func system_language() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LANGUAGES else FALLBACK


func set_language(lang: String) -> void:
	language = lang if lang in LANGUAGES else FALLBACK
	TranslationServer.set_locale(language)
	language_changed.emit(language)


## Chữ có tham số: lấy bản dịch gốc, thay {tham_số}, rồi mới pseudo hoá (nếu bật) để không làm hỏng tên tham số.
## Có tham số "n" thì dùng số nhiều (khoá + "_PLURAL").
func fmt(key: String, params := {}) -> String:
	var msg := raw(key, params.get("n", -1)).format(params)
	return TranslationServer.pseudolocalize(msg) if TranslationServer.pseudolocalization_enabled else msg


## Bản dịch chưa pseudo hoá.
func raw(key: String, n := -1) -> String:
	var t := TranslationServer.get_translation_object(language)
	var msg := str(t.get_plural_message(key, key + "_PLURAL", n) if n >= 0 else t.get_message(key)) if t else ""
	return msg if msg != "" else key


func number(n: int) -> String:
	var digits := str(absi(n))
	var sep := raw("FMT_THOUSANDS")
	var out := ""
	while digits.length() > 3:
		out = sep + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func money(n: int) -> String:
	return raw("FMT_MONEY").format({"amount": number(n)})

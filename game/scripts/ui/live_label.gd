class_name LiveLabel
extends Label
## Nhãn có tham số: `tr(key).format(params())`, tự dựng lại khi đổi ngôn ngữ hoặc khi gọi refresh().
## Có tham số "n" thì dùng số nhiều (xem I18n.fmt).

var key := ""
var params := func() -> Dictionary: return {}


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func setup(new_key: String, new_params := Callable()) -> LiveLabel:
	key = new_key
	if new_params.is_valid():
		params = new_params
	refresh()
	return self


func refresh() -> void:
	if key == "":
		text = ""
		return
	text = I18n.fmt(key, params.call())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()

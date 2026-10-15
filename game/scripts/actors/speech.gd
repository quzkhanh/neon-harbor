class_name Speech
extends Node2D
## Câu thoại ngắn hiện trên đầu một người (khoá dịch), tự mờ đi. Mỗi người chỉ một câu: nói câu mới thì câu cũ biến mất.

const LIFE := 3.2
const RISE := 58.0
const PAD := Vector2(10, 4)
const FONT_SIZE := 15
const MAX_WIDTH := 230.0  # câu dài hơn thì xuống dòng
const NODE_NAME := "Speech"


static func say(who: Node2D, key: String, params := {}, color := Palette.TEXT) -> void:
	var old := who.get_node_or_null(NODE_NAME)
	if old:
		old.free()
	var s := Speech.new()
	s.name = NODE_NAME
	s.z_index = 23
	s.z_as_relative = false
	var panel := PanelContainer.new()
	var style := UiTheme.box(Color(Palette.BG, 0.88), 8, 2, color)
	style.content_margin_left = PAD.x
	style.content_margin_right = PAD.x
	style.content_margin_top = PAD.y
	style.content_margin_bottom = PAD.y
	panel.add_theme_stylebox_override("panel", style)
	var label := Ui.label(I18n.fmt(key, params) if params else key, "WorldLabel")
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	panel.add_child(label)
	s.add_child(panel)
	panel.resized.connect(func() -> void: panel.position = Vector2(-panel.size.x * 0.5, -RISE - panel.size.y))
	who.add_child(s)
	if label.get_combined_minimum_size().x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = MAX_WIDTH
	panel.reset_size()  # lúc tạo (chưa vào cây) kích thước tính theo theme mặc định, to hơn thật


func _ready() -> void:
	var t := create_tween()
	t.tween_interval(LIFE)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)

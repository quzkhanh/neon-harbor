class_name DialogBox
extends Modal
## Hộp thoại nhiệm vụ: chân dung (sprite nhân vật), tên, câu thoại chạy chữ; bấm để qua.

const SPEAKERS_PATH := "res://data/speakers.json"
const PORTRAIT := "res://assets/vendor/chars/%s_stand.png"
const CHARS_PER_SEC := 60.0
const PORTRAIT_SCALE := 2.6
const BOTTOM_SPACE := 250

var lines: Array
var _index := -1
var _speakers: Dictionary
var _portrait: Sprite2D
var _name: Label
var _text: Label
var _tween: Tween


func _init(dialog_lines: Array) -> void:
	super()
	lines = dialog_lines
	cancellable = false


func _build(content: VBoxContainer) -> void:
	var center: Control = panel.get_parent()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -BOTTOM_SPACE
	get_child(0).color = Color(Palette.DIM_SCREEN, 0.25)
	_speakers = JSON.parse_string(FileAccess.get_file_as_string(SPEAKERS_PATH))
	var row := Ui.hbox(22)
	content.add_child(row)
	var well := PanelContainer.new()
	well.theme_type_variation = "IconWell"
	row.add_child(well)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(110, 110)
	well.add_child(frame)
	# Sprite nhìn từ trên xuống xoay dọc để thành chân dung (đầu hướng lên).
	_portrait = Sprite2D.new()
	_portrait.rotation = -PI * 0.5
	_portrait.scale = Vector2.ONE * PORTRAIT_SCALE
	_portrait.position = frame.custom_minimum_size * 0.5
	frame.add_child(_portrait)
	var col := Ui.vbox(6)
	col.custom_minimum_size.x = 640
	row.add_child(col)
	_name = Ui.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_name.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(_name)
	_text = Ui.label("", "", HORIZONTAL_ALIGNMENT_LEFT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.y = 64
	col.add_child(_text)
	col.add_child(Ui.live_label("DIALOG_CONTINUE", func() -> Dictionary: return {"key": InputSetup.key_label(&"interact")}, "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT))
	_next()


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _tween and _tween.is_running():
			_tween.kill()
			_text.visible_ratio = 1.0
		else:
			_next()


func _next() -> void:
	_index += 1
	if _index >= lines.size():
		close()
		return
	var line: Dictionary = lines[_index]
	var who: Dictionary = _speakers[line.who]
	_portrait.texture = load(PORTRAIT % who.skin)
	_name.text = who.name
	_text.text = line.line
	_text.visible_ratio = 0.0
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, tr(line.line).length() / CHARS_PER_SEC)
	Sfx.play("ui_move", -10.0)

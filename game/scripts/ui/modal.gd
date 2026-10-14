class_name Modal
extends CanvasLayer
## Lớp phủ giữa màn hình: nền mờ + panel. Lớp con dựng nội dung trong `_build(box)` và gọi `close(kết quả)`.

signal closed(result: Variant)

const LAYER := 50

var box: VBoxContainer
var panel: PanelContainer
var cancel_result: Variant = null
var cancellable := true


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Palette.DIM_SCREEN
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	box = Ui.vbox(16)
	panel.add_child(box)
	_build(box)


func _build(_box: VBoxContainer) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if cancellable and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close(cancel_result)


func close(result: Variant = null) -> void:
	closed.emit(result)
	queue_free()


## Hàng nút dọc, nối focus; trả về mảng nút.
func button_column(keys: Array, variations := {}) -> Array:
	var buttons := []
	for key in keys:
		var b := Ui.button(key, variations.get(key, ""))
		box.add_child(b)
		buttons.append(b)
	Ui.focus_chain.call_deferred(buttons)
	return buttons

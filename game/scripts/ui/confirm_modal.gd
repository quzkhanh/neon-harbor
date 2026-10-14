class_name ConfirmModal
extends Modal
## Hỏi xác nhận (Có/Không). Kết quả: true nếu đồng ý.

var message_key: String
var params: Dictionary
var buttons_keys: Array


func _init(key: String, message_params := {}, yes_key := "CONFIRM_YES", no_key := "CONFIRM_NO") -> void:
	super()
	message_key = key
	params = message_params
	buttons_keys = [yes_key, no_key]
	cancel_result = false


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 440
	var msg := Ui.live_label(message_key, func() -> Dictionary: return params, "SubLabel")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(msg)
	var buttons := button_column(buttons_keys, {buttons_keys[0]: "AccentButton"})
	buttons[0].pressed.connect(close.bind(true))
	buttons[1].pressed.connect(close.bind(false))

class_name ConfirmModal
extends Modal
## Hỏi xác nhận (Có/Không). Kết quả: true nếu đồng ý.

var message_key: String


func _init(key: String) -> void:
	super()
	message_key = key
	cancel_result = false


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 440
	var msg := Ui.label(message_key, "SubLabel")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(msg)
	var buttons := button_column(["CONFIRM_YES", "CONFIRM_NO"], {"CONFIRM_YES": "AccentButton"})
	buttons[0].pressed.connect(close.bind(true))
	buttons[1].pressed.connect(close.bind(false))

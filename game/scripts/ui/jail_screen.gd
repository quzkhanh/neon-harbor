class_name JailScreen
extends Modal
## Chờ ngồi tù: đếm ngược JAIL_SECONDS giây, không bỏ qua được, hết giờ thì tự đóng.

var _left := Tuning.JAIL_SECONDS
var _countdown: LiveLabel


func _init() -> void:
	super()
	cancellable = false


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 480
	content.add_child(Ui.label("JAIL_TITLE", "TitleLabel"))
	_countdown = Ui.live_label("JAIL_COUNTDOWN", func() -> Dictionary: return {"sec": ceili(_left)}, "SubLabel")
	content.add_child(_countdown)


func _process(delta: float) -> void:
	var before := ceili(_left)
	_left -= delta
	if _left <= 0.0:
		close()
	elif ceili(_left) != before:
		_countdown.refresh()

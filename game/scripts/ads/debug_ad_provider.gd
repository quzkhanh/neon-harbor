extends AdProvider
## Provider giả lập (`-- --ads=debug`): lớp phủ "AD" khoảng 2 giây, có nút xem hết hoặc bỏ dở.

signal _closed(completed: bool)

var overlay: CanvasLayer
var finish_button: Button
var skip_button: Button


func supports_rewarded() -> bool:
	return true


func show_rewarded(placement: String) -> bool:
	return await _show(placement, true)


func show_interstitial(placement: String) -> void:
	await _show(placement, false)


func _show(placement: String, rewarded: bool) -> bool:
	overlay = AdOverlay.build(placement, rewarded)
	add_child(overlay)
	finish_button = overlay.find_child("Finish", true, false)
	skip_button = overlay.find_child("Skip", true, false)
	finish_button.pressed.connect(func() -> void: _closed.emit(true))
	skip_button.pressed.connect(func() -> void: _closed.emit(false))
	var bar: ProgressBar = overlay.find_child("Progress", true, false)
	var tween := create_tween()
	tween.tween_property(bar, "value", bar.max_value, Tuning.AD_DEBUG_DURATION)
	tween.finished.connect(func() -> void: _closed.emit(true))
	var completed: bool = await _closed
	tween.kill()
	overlay.queue_free()
	overlay = null
	return completed

extends SceneTree
## Khung test chung: bắt mọi lỗi engine/script bằng Logger, hàm chờ frame, assert, kết thúc có exit code.
## Script test được biên dịch trước khi autoload tồn tại: chỉ truy cập game qua root.get_node() (duck typing).

const TEST_SAVE := "user://test_save.json"
var watchdog_sec := 60.0


class ErrorCatcher extends Logger:
	var errors := PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var catcher := ErrorCatcher.new()
var failures := PackedStringArray()
var game: Node


func _initialize() -> void:
	OS.add_logger(catcher)
	create_timer(watchdog_sec, true, false, true).timeout.connect(_on_watchdog)
	_start.call_deferred()


## Test bị treo (thường do lỗi script làm coroutine dừng giữa chừng): báo FAIL thay vì chờ mãi.
func _on_watchdog() -> void:
	failures.append("quá %d giây, test bị treo" % watchdog_sec)
	finish("TIMEOUT")


func _start() -> void:
	game = root.get_node("Game")
	game.save_path = TEST_SAVE
	game.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_run()


## Ghi đè ở từng test.
func _run() -> void:
	pass


func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("  ✗ " + message)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func open_scene(path: String) -> Node:
	change_scene_to_file(path)
	await frames(3)
	return current_scene


func open_city() -> Node:
	paused = false
	return await open_scene(game.CITY_SCENE)


## Gửi action như phím thật (tới cả _unhandled_input).
func tap(action: StringName) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(1)


## Đóng mọi hộp thoại đang mở trong thành phố, tối đa `limit` lần.
func close_overlays(city: Node, limit := 12) -> void:
	for i in limit:
		await frames(2)
		if city == null or not is_instance_valid(city) or city.overlays.current == null:
			return
		city.overlays.current.close()


func finish(test_name: String) -> void:
	var engine_errors := PackedStringArray()
	for e in catcher.errors:
		engine_errors.append("lỗi engine/script: " + e)
	failures = engine_errors + failures
	for f in failures:
		printerr("FAIL: " + f)
	print("%s %s" % [test_name, "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	game.quit(0 if failures.is_empty() else 1)

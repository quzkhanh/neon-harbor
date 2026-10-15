class_name Trailer
extends Node
## Quay clip trailer bằng Movie Maker của Godot (`tools/trailer/render.sh` gọi):
## `godot --write-movie <file.avi> --fixed-fps 60 --path game -- --trailer=<cảnh> [--lang=vi|en] [--events=<file.json>]`
## Dựng cảnh trong thành phố (ẩn HUD, camera zoom theo cạnh ngắn của khung hình), rồi ghi mốc sự kiện theo số khung
## hình ra JSON để lúc dựng video đặt điểm cắt, chữ, tiếng whoosh đúng khoảnh khắc. Nhạc nền tắt (thêm khi dựng),
## giữ tiếng trong game. Dùng save tạm như Shot để không đụng save thật.

const SAVE := "user://trailer_save.json"
const FPS := 60  # khớp `--fixed-fps` trong render.sh
const SETTLE := 30
const VIEW_SHORT := 520.0  # px thế giới theo cạnh ngắn khung hình: khung dọc zoom gần hơn để xe, người không bé tí
const PUNCH := 1.15  # giật zoom khi nổ, tông xe; CameraRig tự nhả dần về zoom thường

var scene_name := ""
var lang := ""
var events_path := ""
var city: City
var _events: Array[Dictionary] = []
var _start_frame := 0


func _init(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--trailer="):
			scene_name = arg.trim_prefix("--trailer=")
		elif arg.begins_with("--lang="):
			lang = arg.trim_prefix("--lang=")
		elif arg.begins_with("--events="):
			events_path = arg.trim_prefix("--events=")


func _ready() -> void:
	if not scene_name in TrailerScenes.NAMES:
		push_error("Trailer: không có cảnh '%s' (có: %s)" % [scene_name, ", ".join(TrailerScenes.NAMES)])
		Game.quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	seed(11)
	Game.save_path = SAVE
	Game.reset_progress()
	Game.settings.lang = lang
	Game.settings.tutorial = false
	Game.settings.music = 0.0
	Game.apply_settings()
	Game.missions_done.assign(range(1, Game.mission_count() + 1))  # không còn vòng tròn giao nhiệm vụ trong khung hình
	Game.go(Game.CITY_SCENE)
	await frames(SETTLE)
	city = get_tree().current_scene
	city.hud.visible = false
	var view := get_viewport().get_visible_rect().size
	city.camera.zoom_scale = minf(view.x, view.y) / VIEW_SHORT
	city.camera.zoom = Vector2.ONE * city.camera.zoom_scale
	_start_frame = Engine.get_frames_drawn()
	mark("start")
	await TrailerScenes.run(scene_name, self)
	mark("end")
	_write()
	Game.quit()


## Ghi một mốc: số khung hình tính từ lúc cảnh bắt đầu (bỏ phần nạp game ở đầu video).
func mark(event: String) -> void:
	var frame := Engine.get_frames_drawn() - _start_frame
	_events.append({"event": event, "frame": frame, "t": snappedf(frame / float(FPS), 0.001)})


func punch() -> void:
	city.camera.zoom *= PUNCH


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _write() -> void:
	var data := {"scene": scene_name, "lang": lang, "size": [get_viewport().size.x, get_viewport().size.y], "start_frame": _start_frame, "events": _events}
	if events_path == "":
		print(JSON.stringify(data))
		return
	var file := FileAccess.open(events_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))

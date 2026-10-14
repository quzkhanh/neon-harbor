extends Node
## Autoload `Shot`: `-- --shot=<tên> [--lang=en|vi] [--pseudo] [--shot-dir=<thư mục>]`
## dựng sẵn tình huống, chụp viewport rồi thoát. Dùng save tạm để không đụng save thật.
## `--shot=perf` (trên Web: `index.html?shot=perf`): thành phố với dân/xe tối đa và truy nã 3 sao, in FPS trung bình.

const DEFAULT_DIR := "user://shots"
const SHOT_SAVE := "user://shot_save.json"
const SETTLE := 45
const PERF_WARMUP := 5.0
const PERF_SECONDS := 20
const PERF_HEALTH := 1000000.0
const SCENARIOS := [
	"menu", "settings", "city_walk", "combat", "driving", "wanted3", "shop", "dialog",
	"mission_complete", "death", "hospital", "pause", "touch", "ad_debug",
]

var _name := ""
var _dir := DEFAULT_DIR
var _lang := ""
var _pseudo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("location.search")).trim_prefix("?")
		for part in query.split("&", false):
			args.append("--" + part)
	for arg in args:
		if arg.begins_with("--shot="):
			_name = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-dir="):
			_dir = arg.trim_prefix("--shot-dir=")
		elif arg.begins_with("--lang="):
			_lang = arg.trim_prefix("--lang=")
		elif arg == "--pseudo":
			_pseudo = true
	if _name in SCENARIOS or _name == "perf":
		_run.call_deferred()
	elif _name != "":
		push_error("Shot: không có tình huống '%s' (có: %s)" % [_name, ", ".join(SCENARIOS)])


func _run() -> void:
	seed(7)
	Game.save_path = SHOT_SAVE
	Game.reset_progress()
	Game.settings.lang = _lang
	Game.apply_settings()
	TranslationServer.pseudolocalization_enabled = _pseudo
	AudioServer.set_bus_mute(0, true)
	if _name == "perf":
		await _perf()
		return
	if _name in ["menu", "settings"]:
		await _menu()
	else:
		await _city()
	if not _name in ["combat", "driving"]:
		await _frames(SETTLE)
	_save()


func _menu() -> void:
	await _frames(SETTLE)
	if _name == "settings":
		get_tree().current_scene._settings()


func _city() -> void:
	Game.add_money(2450)
	Game.armor = 60.0
	Game.go(Game.CITY_SCENE)
	await _frames(SETTLE)
	var city: City = get_tree().current_scene
	var p := city.player
	match _name:
		"city_walk":
			await _hold([&"move_right"], 50)
		"combat":
			await _combat(city)
		"driving":
			await _drive(city)
		"wanted3":
			Game.set_stars(3)
			await _frames(420)
		"shop":
			city.overlays.show_shop()
		"dialog":
			p.global_position = city.missions.giver_pos(1)
			await _frames(40)
		"mission_complete":
			Ads.use_provider("debug")
			Game.missions_done.append(1)
			city.overlays.show_mission_complete(1, 500, ["smg"])
		"death", "hospital":
			Ads.use_provider("debug")
			p.take_hit(500.0, Vector2.RIGHT, null)
			while city.overlays.current == null:
				await _frames(1)
			if _name == "hospital":
				await _frames(10)
				city.overlays.current.close(false)
				await _frames(30)
		"pause":
			city.overlays.show_pause()
		"ad_debug":
			Ads.use_provider("debug")
			Ads.show_rewarded("double_reward")
			await _frames(30)


func _perf() -> void:
	Game.go(Game.CITY_SCENE)
	await _frames(SETTLE)
	Game.set_stars(3)
	Game.health = PERF_HEALTH
	await get_tree().create_timer(PERF_WARMUP).timeout
	var samples: Array[float] = []
	for i in PERF_SECONDS:
		await get_tree().create_timer(1.0).timeout
		samples.append(Engine.get_frames_per_second())
	var city: City = get_tree().current_scene
	var avg: float = samples.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / samples.size()
	print("PERF fps_avg=%.1f fps_min=%d giây=%d người=%d xe=%d cảnh_sát=%d" % [avg, samples.min(), samples.size(),
		city.population.peds().size(), get_tree().get_nodes_in_group("vehicles").size(), city.police.cops().size()])
	if not OS.has_feature("web"):
		Game.quit()


func _combat(city: City) -> void:
	Game.owned["rifle"] = {"mag": 30, "reserve": 90}
	Game.select_weapon("rifle")
	var p := city.player
	p.global_position = MapData.cell_center(Vector2i(30, 26)) + Vector2(0, 280)
	for offset in [Vector2(260, -40), Vector2(330, 60), Vector2(300, 150)]:
		var g := city.spawn_npc(Gangster, p.global_position + offset)
		g.alert()
	await _frames(20)
	await _hold([&"aim_right", &"fire"], 26, false)
	# Bấm máy ngay frame vừa nổ súng để thấy lửa đầu nòng và vệt đạn.
	var fired_at := p.gun.cooldown
	while p.gun.cooldown <= fired_at:
		fired_at = p.gun.cooldown
		await _frames(1)
	await _frames(1)  # ảnh viewport là frame đã vẽ xong


func _drive(city: City) -> void:
	var cell := Vector2i(10, 20)
	var v := city.spawn_vehicle("car", cell, 0.0, "car_red_1")
	city.player.global_position = v.global_position + Vector2(0, 50)
	await _frames(5)
	city.player.enter_vehicle(v)
	await _hold([&"accelerate"], 70)
	await _hold([&"accelerate", &"steer_right", &"handbrake"], 16, false)


func _hold(actions: Array, frames: int, release := true) -> void:
	for a in actions:
		Input.action_press(a)
	await _frames(frames)
	if release:
		for a in actions:
			Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var suffix := ("_" + _lang if _lang != "" else "") + ("_pseudo" if _pseudo else "")
	var path := _dir.path_join(_name + suffix + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s -> %s (%s)" % [_name, ProjectSettings.globalize_path(path), error_string(err)])
	Game.quit()

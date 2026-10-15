extends Node
## Autoload `Shot`: `-- --shot=<tên> [--lang=en|vi] [--pseudo] [--shot-dir=<thư mục>]`
## dựng sẵn tình huống, chụp viewport rồi thoát. Dùng save tạm để không đụng save thật.
## `--shot=perf` (trên Web: `index.html?shot=perf`): thành phố với dân/xe tối đa, truy nã 5 sao (trực thăng, đặc nhiệm,
## rào chắn) và trời mưa, in FPS trung bình.

const DEFAULT_DIR := "user://shots"
const SHOT_SAVE := "user://shot_save.json"
const SETTLE := 45
const PERF_WARMUP := 5.0
const PERF_SECONDS := 20
const PERF_HEALTH := 1000000.0
const COMBAT_CELL := Vector2i(5, -5)  # tính từ điểm xuất phát P (khu cảng)
const DRIVE_CELL := Vector2i(-15, -11)
const CORPSE_CELL := Vector2i(6, -9)
const SCENARIOS := [
	"menu", "settings", "help", "help_basics", "city_walk", "combat", "driving", "moto", "wanted3", "shop", "dialog",
	"mission_complete", "death", "hospital", "pause", "touch", "corpses", "map",
	"downtown", "market", "uptown", "marina", "tutorial",
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
	if _name in SCENARIOS or _name in ShotScenes.NAMES or _name == "perf":
		_run.call_deferred()
	elif _name != "":
		push_error("Shot: không có tình huống '%s' (có: %s)" % [_name, ", ".join(SCENARIOS)])


func _run() -> void:
	seed(7)
	Game.save_path = SHOT_SAVE
	Game.reset_progress()
	Game.settings.lang = _lang
	Game.settings.tutorial = _name == "tutorial"
	Game.apply_settings()
	TranslationServer.pseudolocalization_enabled = _pseudo
	AudioServer.set_bus_mute(0, true)
	if _name == "perf":
		await _perf()
		return
	if _name in ["menu", "settings", "help", "help_basics"]:
		await _menu()
	else:
		await _city()
	if not _name in ["combat", "driving", "moto", "corpses"] and not _name in ShotScenes.NAMES:
		await _frames(SETTLE)
	_save()


func _menu() -> void:
	await _frames(SETTLE)
	if _name == "settings":
		get_tree().current_scene._open(SettingsPanel)
	elif _name.begins_with("help"):
		get_tree().current_scene._open(HelpPanel)
		await _frames(SETTLE)
		if _name == "help_basics":
			get_tree().current_scene.get_child(-1)._show(1)


func _city() -> void:
	Game.add_money(2450)
	Game.armor = 60.0
	Game.go(Game.CITY_SCENE)
	await _frames(SETTLE)
	var city: City = get_tree().current_scene
	var p := city.player
	if _name in ShotScenes.NAMES:
		await ShotScenes.run(_name, city, self)
	match _name:
		"city_walk":
			await _hold([&"move_right"], 50)
		"combat":
			await _combat(city)
		"driving":
			await _drive(city)
		"moto":
			await _drive(city, "moto", "motorcycle_red")
		"wanted3":
			Game.set_stars(3)
			await _frames(420)
		"shop":
			city.overlays.show_shop()
		"dialog":
			p.global_position = city.missions.giver_pos(1)
			await _frames(40)
		"mission_complete":
			Game.missions_done.append(1)
			city.overlays.show_mission_complete(1, 500, ["smg"])
		"death", "hospital":
			city.missions.start(1, false)
			await _frames(5)
			p.take_hit(500.0, Vector2.RIGHT, null)
			while city.overlays.current == null:
				await _frames(1)
			if _name == "hospital":
				await _frames(10)
				city.overlays.current.close(DeathScreen.Revive.HOSPITAL)
				await _frames(30)
		"pause":
			city.overlays.show_pause()
		"corpses":
			await _corpses(city)
		"map":
			p.global_position = city.missions.giver_pos(1)
			await _frames(5)
			city.overlays.open(MapScreen.new(city))
		"downtown", "market", "uptown", "marina":
			p.global_position = _district_spot(city, "DISTRICT_" + _name.to_upper())
			_camera_snap(city)
			await _hold([&"move_right"], 50)


func _perf() -> void:
	Game.go(Game.CITY_SCENE)
	await _frames(SETTLE)
	Game.set_stars(Tuning.MAX_STARS)
	get_tree().current_scene.get_node("Weather").set_raining(true)
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
	Game.owned["rifle"] = {"mag": 30}
	Game.select_weapon("rifle")
	var p := city.player
	p.global_position = MapData.cell_center(city.data.find("P") + COMBAT_CELL) + Vector2(0, 280)
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


func _drive(city: City, kind := "car", sprite := "car_red_1") -> void:
	var v := city.spawn_vehicle(kind, city.data.find("P") + DRIVE_CELL, 0.0, sprite)
	city.player.global_position = v.global_position + Vector2(0, 50)
	await _frames(5)
	city.player.enter_vehicle(v)
	await _hold([&"move_right"], 70)
	await _hold([&"move_right", &"move_down", &"handbrake"], 16, false)


## Xác người: hai người vừa bị hạ (vũng máu, dấu X), một tên bị thương (thanh máu), một người bị xe tông ngã.
## Ô vỉa hè gần tâm khu `key` nhất.
func _district_spot(city: City, key: String) -> Vector2:
	for d in DataDB.districts():
		if d.key == key:
			var r: Array = d.rect
			var center := Vector2i(int(r[0] + r[2] / 2), int(r[1] + r[3] / 2))
			for radius in 30:
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						if city.data.at(center + Vector2i(dx, dy)) == ",":
							return MapData.cell_center(center + Vector2i(dx, dy))
	return city.player.global_position


func _camera_snap(city: City) -> void:
	city.camera.global_position = city.player.global_position


func _corpses(city: City) -> void:
	var p := city.player
	p.global_position = MapData.cell_center(city.data.find("P") + CORPSE_CELL)
	p.face(PI)
	var victims: Array[Npc] = []
	for offset in [Vector2(-220, -70), Vector2(-260, 60), Vector2(-150, 140)]:
		victims.append(city.spawn_npc(Pedestrian, p.global_position + offset))
	var gang := city.spawn_npc(Gangster, p.global_position + Vector2(-340, -10))
	await _frames(5)
	victims[0].take_hit(500.0, Vector2.LEFT, p)
	await _frames(90)
	gang.take_hit(30.0, Vector2.LEFT, p)
	victims[2].knock_down(Vector2(-80, 0), 1.0, null)
	victims[1].take_hit(500.0, Vector2.LEFT, p)
	await _frames(12)


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

extends "res://tests/harness.gd"
## Chơi thử như người thật bằng phím/chuột gửi qua hàng đợi input (đi qua focus giao diện và _unhandled_input):
## menu -> Chơi mới -> cửa hàng (mua súng) -> NV1 -> tạm dừng/cài đặt/đổi ngôn ngữ -> truy nã -> chết -> đứng dậy tại chỗ
## -> cướp xe -> bán ở gara -> về menu -> Chơi tiếp -> pha bấm loạn ngẫu nhiên. Bắt mọi lỗi engine/script.
## Chạy (nên có cửa sổ): godot --path game -s res://tests/playtest.gd [-- --monkey=<giây> --seed=<số>]

const TILE := 64.0
const MONKEY_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_Q, KEY_R, KEY_SPACE, KEY_ESCAPE, KEY_ENTER,
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]

var monkey_seconds := 90.0
var monkey_seed := 12345
var step := ""


func _initialize() -> void:
	watchdog_sec = 900.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--monkey="):
			monkey_seconds = arg.trim_prefix("--monkey=").to_float()
		elif arg.begins_with("--seed="):
			monkey_seed = arg.trim_prefix("--seed=").to_int()
	super()


func _run() -> void:
	game.reset_progress()
	await _step("menu -> Chơi mới", _menu_new_game)
	var city: Node = current_scene
	await _step("vào cửa hàng, mua súng săn", _shop.bind(city))
	await _step("NV1 bằng phím thật", _mission1.bind(city))
	await _step("hướng dẫn người mới đi tới bước cuối dù bỏ qua bước bản đồ/bắn", _tutorial_progress.bind(city))
	await _step("tạm dừng -> cài đặt -> đổi ngôn ngữ -> tiếp tục", _pause_settings.bind(city))
	await _step("bắn bừa -> truy nã -> chết -> đứng dậy tại chỗ", _wanted_death.bind(city))
	await _step("cướp xe -> bán ở gara", _carjack_sell.bind(city))
	await _step("về menu -> Chơi tiếp", _menu_continue.bind(city))
	if monkey_seconds > 0.0:
		await _step("bấm loạn %d giây" % monkey_seconds, _monkey)
	finish("PLAYTEST")


func _step(name: String, body: Callable) -> void:
	step = name
	var errors_before := catcher.errors.size()
	print("-> " + name)
	await body.call()
	for i in range(errors_before, catcher.errors.size()):
		print("   LỖI trong bước '%s': %s" % [name, catcher.errors[i]])


# --- Input thật ---

func key(code: Key, hold := 2) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await physics(hold)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await physics(2)


func click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await physics(2)


func steer_walk(p: Node, goal: Vector2) -> void:
	var city: Node = current_scene
	var route: PackedVector2Array = city.path(p.global_position, goal)
	var next := route[1] if route.size() > 1 else goal
	press_dir((next - p.global_position).normalized())


## Giữ các phím di chuyển theo hướng `d` (đi bộ, và lái xe ở kiểu lái mặc định).
func press_dir(d: Vector2) -> void:
	for pair in [[&"move_left", -d.x], [&"move_right", d.x], [&"move_up", -d.y], [&"move_down", d.y]]:
		if pair[1] > 0.2:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## Ô `ch` gần người chơi nhất (bản đồ có nhiều cửa hàng/bệnh viện).
func nearest(city: Node, ch: String) -> Vector2:
	var best := Vector2.INF
	for cell in city.data.find_all(ch):
		var pos: Vector2 = city.data.cell_center(cell)
		if pos.distance_to(city.player.global_position) < best.distance_to(city.player.global_position):
			best = pos
	return best


func stop_moving() -> void:
	for a in [&"move_left", &"move_right", &"move_up", &"move_down", &"accelerate", &"brake", &"steer_left", &"steer_right", &"fire", &"aim_left", &"aim_right"]:
		Input.action_release(a)


func walk_to(goal: Vector2, radius := 30.0, max_frames := 900) -> bool:
	var p: Node = current_scene.player
	for i in max_frames:
		if p.global_position.distance_to(goal) < radius or paused:
			stop_moving()
			return true
		steer_walk(p, goal)
		await physics(1)
	stop_moving()
	return false


func until(cond: Callable, frames := 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await physics(1)
	return false


# --- Các bước ---

func _menu_new_game() -> void:
	await open_scene(game.MENU_SCENE)
	await physics(20)
	await key(KEY_ENTER)
	expect(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.CITY_SCENE, 300), "Enter ở menu không vào được thành phố")
	await physics(30)


func _shop(city: Node) -> void:
	var door: Vector2 = nearest(city, "S")
	await walk_to(door + Vector2(0, TILE), 20.0)
	await walk_to(door, 20.0)
	expect(await until(func() -> bool: return city.overlays.current != null, 120), "đi vào cửa không mở cửa hàng")
	game.add_money(1000)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	await physics(10)
	expect(game.owned.has("shotgun"), "mua súng săn bằng phím không thành công (focus: %s)" % city.get_viewport().gui_get_focus_owner())
	await key(KEY_ESCAPE)
	expect(await until(func() -> bool: return city.overlays.current == null and not paused, 60), "Esc không đóng cửa hàng")
	await walk_to(door + Vector2(0, TILE * 2), 20.0)


func _tutorial_progress(city: Node) -> void:
	var tut: Node = city.get_node_or_null("Tutorial")
	expect(tut == null or tut._index >= 5, "hướng dẫn kẹt ở bước %s" % (tut._index if tut else -1))
	print("   hướng dẫn: %s" % ("đã xong" if tut == null else "bước %d" % tut._index))


func _mission1(city: Node) -> void:
	expect(await walk_to(city.missions.giver_pos(1), 20.0), "không đi tới được điểm NV1")
	expect(await until(func() -> bool: return city.overlays.current != null, 120), "không mở hội thoại NV1")
	for i in 6:
		await key(KEY_E)
		await physics(5)
	expect(await until(func() -> bool: return city.missions.current != null, 120), "NV1 không bắt đầu sau hội thoại")
	var bike: Node = city.missions.current.bike
	await walk_to(bike.global_position, 50.0)
	await key(KEY_E)
	expect(city.player.vehicle == bike, "phím E không lên được xe máy")
	# Lái tới điểm giao: bấm phím hướng về điểm kế tiếp trên đường, như người chơi.
	var goal: Vector2 = city.missions.cell_pos_of("d")
	for i in 3600:
		if city.missions.current == null or paused or city.player.vehicle == null:
			break
		var v: Node = city.player.vehicle
		var route: PackedVector2Array = city.path(v.global_position, goal, true)
		var target := route[mini(2, route.size() - 1)] if route.size() > 1 else goal
		press_dir((target - v.global_position).normalized())
		await physics(1)
	stop_moving()
	for i in 12:
		await physics(10)
		if city.overlays.current:
			await key(KEY_E)
			await key(KEY_ENTER)
	print("   NV1 xong: %s, tiền %d, nv=%s, overlay=%s, xe=%s, paused=%s, obj=%s, vị trí=%s đích=%s" % [1 in game.missions_done, game.money,
		city.missions.current, city.overlays.current, city.player.vehicle, paused, game.objective, city.player.global_position, goal])


func _pause_settings(city: Node) -> void:
	if city.player.vehicle:
		await key(KEY_E)
	await key(KEY_ESCAPE)
	expect(city.overlays.current != null and paused, "Esc không mở menu tạm dừng")
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await physics(5)
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	await physics(5)
	expect(game.settings.lang == "vi", "đổi sang tiếng Việt bằng phím không được (lang=%s)" % game.settings.lang)
	await key(KEY_LEFT)
	await key(KEY_ENTER)
	await key(KEY_ESCAPE)
	await physics(5)
	await key(KEY_ESCAPE)
	expect(await until(func() -> bool: return city.overlays.current == null and not paused, 60), "không thoát được menu tạm dừng")


func _wanted_death(city: Node) -> void:
	game.select_weapon("shotgun")
	var p: Node = city.player
	for i in 40:
		var peds := get_nodes_in_group("peds").filter(func(n: Node) -> bool: return n.alive)
		if peds.is_empty():
			break
		var target: Node = peds[0]
		for a in [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]:
			Input.action_release(a)
		var d: Vector2 = (target.global_position - p.global_position).normalized()
		Input.action_press(&"aim_right" if d.x > 0 else &"aim_left", absf(d.x))
		Input.action_press(&"aim_down" if d.y > 0 else &"aim_up", absf(d.y))
		await click(Vector2(640, 360))
		await physics(30)
	print("   sao truy nã: %d, heat %.0f, người đi đường còn sống %d, đạn %s" % [game.stars, game.heat, get_nodes_in_group("peds").filter(func(n: Node) -> bool: return n.alive).size(), game.ammo()])
	game.armor = 0.0
	p.take_hit(500.0, Vector2.RIGHT, null)
	expect(await until(func() -> bool: return city.overlays.current != null, 200), "chết không hiện màn chết")
	var died_at: Vector2 = p.global_position
	await key(KEY_ENTER)
	await physics(20)
	expect(p.alive and p.global_position.distance_to(died_at) < 40.0, "Enter ở màn chết không hồi sinh tại chỗ")


func _carjack_sell(city: Node) -> void:
	var p: Node = city.player
	var cars: Array = city.population.cars.filter(func(v: Node) -> bool: return is_instance_valid(v) and not v.wrecked)
	if cars.is_empty():
		print("   không có xe tự lái nào gần để cướp")
		return
	var car: Node = cars[0]
	p.global_position = car.global_position + Vector2(0, 70)
	await physics(2)
	await key(KEY_E)
	expect(p.vehicle == car, "không cướp được xe đang chạy")
	car.global_position = city.missions.cell_pos_of("G") + Vector2(0, TILE)
	car.velocity = Vector2.ZERO
	await physics(10)
	var money: int = game.money
	await key(KEY_E)
	await physics(5)
	expect(game.money > money and p.vehicle == null, "bán xe ở gara không được (tiền %d -> %d)" % [money, game.money])


func _menu_continue(city: Node) -> void:
	await key(KEY_ESCAPE)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	expect(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.MENU_SCENE, 300), "Về menu không được")
	await physics(20)
	await key(KEY_ENTER)
	expect(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.CITY_SCENE, 300), "Chơi tiếp không vào được thành phố")
	await physics(30)


## Bấm loạn: phím, chuột, giữ di chuyển/ga ngẫu nhiên — săn crash.
func all_weapons() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))


func _monkey() -> void:
	seed(monkey_seed)
	game.add_money(20000)
	game.missions_done = [1, 2, 3]
	for w in all_weapons():
		game.owned[w.id] = {"mag": int(w.mag), "reserve": maxi(int(w.reserve_max), 0) if int(w.reserve_max) >= 0 else -1}
	var frames := int(monkey_seconds * 60.0)
	var i := 0
	while i < frames:
		var roll := randf()
		if roll < 0.55:
			await key(MONKEY_KEYS[randi() % MONKEY_KEYS.size()], randi_range(1, 40))
			i += 4
		elif roll < 0.8:
			await click(Vector2(randf_range(0, 1280), randf_range(0, 720)))
			i += 4
		else:
			var a: StringName = [&"move_left", &"move_right", &"move_up", &"move_down", &"fire", &"accelerate"][randi() % 6]
			Input.action_press(a)
			var hold := randi_range(10, 90)
			await physics(hold)
			Input.action_release(a)
			i += hold
		if current_scene == null:
			await physics(5)
		elif current_scene.scene_file_path != game.CITY_SCENE:
			# Không để bấm loạn chọn "Thoát" ở menu: quay lại thành phố.
			await open_city()
	stop_moving()
	print("   bấm loạn xong ở cảnh %s, tạm dừng=%s" % [current_scene.scene_file_path if current_scene else "?", paused])

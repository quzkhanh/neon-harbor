extends "res://tests/harness.gd"
## Nước và cho vui (đợt 8): Jay bơi được (chậm, không bắn, hết hơi thì mất máu), xe không lao xuống nước, thuyền chạy trên
## nước và không lên bờ; mã gian lận (siêu xe, bất tử, xác sống cắn), dùng gian lận thì không nhận thành tựu.
## Chạy: godot --headless --path game -s res://tests/water.gd


func _run() -> void:
	var city := await open_city()
	await close_overlays(city)
	city.population.set_process(false)
	await _check_swim(city)
	await _check_boat(city)
	await _check_car_stays_dry(city)
	await _check_cheats(city)
	finish("WATER")


func _cell(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * 64.0


func _boat_cell(city: Node) -> Vector2i:
	var b: Array = load("res://scripts/core/data_db.gd").extras().boats[0]
	return Vector2i(int(b[0]), int(b[1]))


func _check_swim(city: Node) -> void:
	var p: Node = city.player
	var sea: Vector2i = _boat_cell(city) + Vector2i(4, 1)
	expect(city.data.at(sea) == "~", "ô thử bơi không phải nước (%s)" % city.data.at(sea))
	p.global_position = _cell(sea)
	await physics(5)
	expect(p.swim.active, "xuống nước mà không bơi")
	var start: Vector2 = p.global_position
	Input.action_press(&"move_down")
	await physics(30)
	Input.action_release(&"move_down")
	expect(p.global_position.distance_to(start) > 20.0, "bơi không di chuyển được")
	p.global_position = _cell(Vector2i(sea.x, 300))
	await physics(2)
	expect(city.data.world_rect().has_point(p.global_position), "bơi ra được ngoài bản đồ")
	p.global_position = _cell(sea)
	await physics(2)
	var mag: int = game.ammo().mag
	Input.action_press(&"fire")
	await physics(20)
	Input.action_release(&"fire")
	expect(game.ammo().mag == mag, "đang bơi mà vẫn bắn được")
	p.swim.breath = 0.2
	var hp: float = game.health
	await physics(60)
	expect(game.health < hp, "hết hơi dưới nước mà không mất máu")
	p.global_position = _cell(_boat_cell(city) + Vector2i(-1, -1))
	await physics(5)
	expect(not p.swim.active, "lên bờ mà vẫn đang bơi (%s)" % city.data.at(_boat_cell(city) + Vector2i(-1, -1)))
	game.health = 100.0


func _check_boat(city: Node) -> void:
	var boat: Node = null
	for v in get_nodes_in_group("vehicles"):
		if v.kind == "boat":
			boat = v
	expect(boat != null, "không có thuyền ở bến")
	if boat == null:
		return
	city.player.global_position = boat.global_position + Vector2(-70, 0)
	await physics(3)
	city.player.enter_vehicle(boat)
	game.settings.steering = "classic"
	var start: Vector2 = boat.global_position
	Input.action_press(&"accelerate")
	await physics(150)
	Input.action_release(&"accelerate")
	game.settings.steering = "screen"
	expect(boat.global_position.distance_to(start) > 150.0, "thuyền không chạy")
	expect(city.data.at(Vector2i(boat.global_position / 64.0)) == "~", "thuyền chạy lên bờ")
	boat.global_position = start
	boat.rotation = -PI * 0.5
	boat.velocity = Vector2(0, -400)
	await physics(60)
	expect(city.data.at(Vector2i(boat.global_position / 64.0)) == "~", "lao thuyền vào cầu tàu mà lên được bờ")
	city.player.exit_vehicle()
	await physics(3)


func _check_car_stays_dry(city: Node) -> void:
	var sea: Vector2i = _boat_cell(city)
	var shore := sea + Vector2i(-1, -4)
	var car: Node = city.spawn_vehicle("car", shore, PI * 0.5)
	for i in 90:
		car.velocity = Vector2(0, 350)
		await physics_frame
	expect(city.data.at(Vector2i(car.global_position / 64.0)) != "~", "xe lao được xuống nước")
	car.queue_free()


func _type(word: String) -> void:
	for ch in word:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch)
		Input.parse_input_event(e)
		await frames(1)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await frames(1)


func _check_cheats(city: Node) -> void:
	var p: Node = city.player
	p.global_position = _cell(Vector2i(30, 24))
	await physics(3)
	var cars: int = get_nodes_in_group("vehicles").size()
	await _type("FASTLANE")
	await physics(2)
	expect(get_nodes_in_group("vehicles").size() == cars + 1, "gõ FASTLANE mà không có siêu xe")
	await _type("NEONGOD")
	p.take_hit(50.0, Vector2.RIGHT, null)
	expect(game.god and game.health == 100.0, "gõ NEONGOD mà vẫn mất máu")
	await _type("NEONGOD")
	expect(not game.god, "gõ lại NEONGOD mà không tắt bất tử")
	await _type("DEADTOWN")
	var zombie: Node = city.spawn_npc(load("res://scripts/actors/pedestrian.gd"), p.global_position + Vector2(120, 0))
	zombie.add_to_group("peds")
	await physics(150)
	expect(zombie.zombie and game.health < 100.0, "đêm xác sống: người đi đường không thành xác sống / không cắn (máu %.0f)" % game.health)
	await _type("DEADTOWN")
	game.health = 100.0
	game.bump("kills")
	await physics(80)
	expect(not game.marked("achievements").has("first_blood"), "đã gian lận mà vẫn nhận thành tựu")

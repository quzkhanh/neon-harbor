extends "res://tests/harness.gd"
## Chiến đấu (đợt 8): tay không luôn có, đấm trúng người phía trước (không tốn đạn, không trúng phía sau); gậy bán ở
## cửa hàng; giá súng giảm nửa; bắn từ trong xe; giữ phím đổi súng mở vòng chọn (thời gian chậm lại), nhả để chọn,
## bấm nhanh vẫn đổi súng kế; người có súng bị chọc thì bắn trả; người chứng kiến tiếng súng gọi cảnh sát.
## Chạy: godot --headless --path game -s res://tests/combat.gd

const ROAD := Vector2i(30, 22)


func _run() -> void:
	var city := await open_city()
	await close_overlays(city)
	city.population.set_process(false)
	for p in get_nodes_in_group("peds"):
		p.queue_free()
	await physics(2)
	var weapons: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var price := {}
	for w in weapons:
		price[w.id] = int(w.price)
	expect(price.smg == 300 and price.bazooka == 3000 and price.bat > 0, "giá súng chưa giảm nửa / gậy không bán: %s" % price)
	expect(game.owned.has("fists"), "không có sẵn tay không")
	await _check_melee(city)
	await _check_wheel(city)
	await _check_drive_by(city)
	await _check_provoke(city)
	await _check_witness(city)
	finish("COMBAT")


func _ped(city: Node, pos: Vector2) -> Node:
	var ped: Node = city.spawn_npc(load("res://scripts/actors/pedestrian.gd"), pos)
	ped.add_to_group("peds")
	return ped


func _check_melee(city: Node) -> void:
	var p: Node = city.player
	game.select_weapon("fists")
	await physics(2)
	var front := _ped(city, p.global_position + Vector2(40, 0))
	var behind := _ped(city, p.global_position + Vector2(-40, 0))
	await physics(2)
	front.set_physics_process(false)
	behind.set_physics_process(false)
	p.aim_angle = 0.0
	p.gun.cooldown = 0.0
	var ex: Array[RID] = [p.get_rid()]
	p.gun.try_fire(p, p.muzzle_position(), 0.0, ex)
	expect(front.health < front.max_health, "đấm không trúng người phía trước")
	expect(behind.health == behind.max_health, "đấm trúng cả người phía sau")
	expect(p.gun.reloading <= 0.0 and game.owned.fists.mag == 0, "tay không mà tốn đạn / phải nạp")
	expect(front._stagger > 0.0 and front.knocked <= 0.0, "cú đấm đầu không làm nạn nhân lảo đảo / ngã luôn")
	expect(p.get_children().any(func(c: Node) -> bool: return c.get_script() and c.get_script().resource_path.ends_with("swing_arc.gd")), "đấm mà không có vệt chém")
	expect(Engine.time_scale < 1.0, "đấm trúng mà không khựng hình")
	for i in 2:
		p.gun.cooldown = 0.0
		p.gun.try_fire(p, p.muzzle_position(), 0.0, ex)
	expect(p.gun.combo == 3 and front.knocked > 0.0, "cú thứ 3 liên tiếp không làm ngã (combo %d)" % p.gun.combo)
	p.gun.cooldown = -1.0
	p.gun.try_fire(p, p.muzzle_position(), 0.0, ex)
	expect(p.gun.combo == 1, "nghỉ lâu rồi đánh tiếp mà combo không về cú 1")
	await create_timer(0.3, true, false, true).timeout
	expect(Engine.time_scale == 1.0, "hết khựng hình mà thời gian không trở lại bình thường")
	front.queue_free()
	behind.queue_free()
	game.clear_wanted()
	game.money = 5000
	expect(game.buy_weapon("bat") and game.current == "bat", "không mua được gậy bóng chày")


func _check_wheel(city: Node) -> void:
	game.select_weapon("pistol")
	await tap(&"weapon_next")
	expect(game.current != "pistol", "bấm nhanh phím đổi súng mà không đổi")
	var e := InputEventAction.new()
	e.action = &"weapon_next"
	e.pressed = true
	Input.parse_input_event(e)
	await physics(40)
	var wheel: Node = city.player._wheel
	expect(is_instance_valid(wheel) and Engine.time_scale < 0.5, "giữ phím đổi súng mà không mở vòng chọn / không chậm lại")
	if is_instance_valid(wheel):
		wheel.set_process(false)  # giữ ô đã chọn, không theo chuột
		wheel._index = wheel._ids.find("pistol")
	var r := InputEventAction.new()
	r.action = &"weapon_next"
	r.pressed = false
	Input.parse_input_event(r)
	await frames(3)
	expect(not is_instance_valid(wheel) and Engine.time_scale == 1.0, "nhả phím mà vòng chọn chưa đóng / thời gian chưa trở lại")
	# Giữ phím đổi súng rồi lên xe: vòng chọn phải đóng, thời gian không được kẹt chậm.
	Input.parse_input_event(e)
	await physics(40)
	var car: Node = city.spawn_vehicle("car", ROAD, 0.0)
	city.player.enter_vehicle(car)
	Input.parse_input_event(r)
	await physics(5)
	expect(not is_instance_valid(city.player._wheel) and Engine.time_scale == 1.0, "lên xe khi đang mở vòng chọn súng: thời gian kẹt chậm")
	city.player.exit_vehicle()
	car.queue_free()


func _check_drive_by(city: Node) -> void:
	game.owned["smg"] = {"mag": 30}
	game.select_weapon("smg")
	var car: Node = city.spawn_vehicle("car", ROAD, 0.0)
	city.player.global_position = car.global_position + Vector2(0, 70)
	await physics(2)
	city.player.enter_vehicle(car)
	var target: Node = city.spawn_npc(load("res://scripts/actors/gangster.gd"), car.global_position + Vector2(260, 0))
	await physics(2)
	target.set_physics_process(false)
	var hp: float = car.hp
	Input.action_press(&"aim_right")
	Input.action_press(&"fire")
	await physics(40)
	Input.action_release(&"fire")
	Input.action_release(&"aim_right")
	expect(target.health < target.max_health, "bắn từ xe không trúng tên đứng cạnh xe")
	expect(car.hp == hp, "bắn từ xe trúng chính xe mình")
	city.player.exit_vehicle()
	target.queue_free()
	car.queue_free()


func _check_provoke(city: Node) -> void:
	game.health = 100.0
	game.armor = 0.0
	var p: Node = city.player
	var ped := _ped(city, p.global_position + Vector2(160, 0))
	await physics(2)
	ped.provoke()
	var fired := false
	for i in 240:
		await physics_frame
		fired = fired or ped.gun.cooldown > 0.0
	expect(fired and ped.pose != "stand", "người bị chọc giận không bắn trả")
	ped.queue_free()
	game.health = 100.0


func _check_witness(city: Node) -> void:
	game.clear_wanted()
	await physics(2)
	var p: Node = city.player
	var ped := _ped(city, p.global_position + Vector2(-200, 0))
	await physics(2)
	game.select_weapon("pistol")
	p.gun.cooldown = 0.0
	p.gun.reloading = 0.0
	var ex: Array[RID] = [p.get_rid()]
	p.gun.try_fire(p, p.muzzle_position(), PI * 0.5, ex)
	await physics(60 * 5)
	expect(game.heat >= 45.0 or game.stars > 0, "người chứng kiến tiếng súng mà không gọi cảnh sát (nhiệt %.0f)" % game.heat)
	ped.queue_free()

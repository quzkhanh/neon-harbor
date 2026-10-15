extends "res://tests/harness.gd"
## Việc phụ (đợt 8) qua API kiểm thử: đua xe (đếm ngược, đối thủ chạy, qua hết checkpoint thì về nhất, lưu kỷ lục),
## giao hàng (5 đơn + thưởng), càn quét (8 tên), taxi (đón, trả khách, xuống xe là nghỉ), tuần tra (phá xe, hạ nghi phạm),
## xu neon (nhặt một lần, lưu qua save), dốc nhảy (bay rồi tiếp đất được tiền).
## Chạy: godot --headless --path game -s res://tests/activities.gd

const MAX_WAIT := 600


func _run() -> void:
	watchdog_sec = 240.0
	var city := await open_city()
	await close_overlays(city)
	game.settings.tutorial = false
	city.population.set_process(false)
	game.health = 100000.0
	await _check_race(city)
	await _check_delivery(city)
	await _check_sweep(city)
	await _check_taxi(city)
	await _check_vigilante(city)
	await _check_token(city)
	await _check_ramp(current_scene)
	finish("ACTIVITIES")


func _cell_pos(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0


func _drive(city: Node, kind: String, pos: Vector2) -> Node:
	var v: Node = city.spawn_vehicle(kind, Vector2i(pos / 64.0), 0.0)
	v.global_position = pos
	city.player.global_position = pos + Vector2(0, 70)
	await physics(2)
	city.player.enter_vehicle(v)
	await physics(2)
	return v


func _leave(city: Node) -> void:
	if city.player.vehicle:
		city.player.exit_vehicle()
	await physics(3)
	expect(city.activities.current == null, "xuống xe mà việc phụ %s vẫn chạy" % city.activities.kind)


func _check_race(city: Node) -> void:
	var q: Vector2 = _cell_pos(city.data.find("Q"))
	var car := await _drive(city, "sports", q)
	await physics(3)
	expect(city.interactions.prompt == "HINT_EXIT", "trong xe ở cờ đua mà phím E không còn là xuống xe (%s)" % city.interactions.prompt)
	car.velocity = Vector2(300, 0)
	await physics(30)
	expect(city.activities.current == null, "chạy ngang qua cờ đua (không dừng) mà cuộc đua đã bắt đầu")
	car.global_position = q
	car.velocity = Vector2.ZERO
	await physics(80)
	var race: Node = city.activities.current
	expect(race != null and city.activities.kind == "race", "dừng xe trên cờ đua mà không bắt đầu đua")
	if race == null:
		return
	expect(race._rivals.size() == 3, "đua: %d đối thủ (mong 3)" % race._rivals.size())
	expect(not city.player.controls_enabled, "đang đếm ngược mà vẫn lái được")
	city.player.exit_vehicle()
	city.player.global_position = race._rivals[0].global_position + Vector2(0, 50)
	await physics(2)
	expect(city.interactions.nearest_vehicle() != race._rivals[0], "cướp được xe đối thủ đua (xe nhiệm vụ do NPC lái)")
	city.player.global_position = car.global_position + Vector2(0, 50)
	await physics(2)
	city.player.enter_vehicle(car)
	await physics(60 * 3 + 20)
	expect(city.player.controls_enabled and race._running, "đếm ngược xong mà chưa xuất phát")
	var start: Vector2 = race._rivals[0].global_position
	await physics(90)
	expect(race._rivals[0].global_position.distance_to(start) > 150.0, "đối thủ không chạy")
	var money: int = game.money
	var index: int = race.index
	for p in race._points:
		car.global_position = p
		car.velocity = Vector2.ZERO
		await physics(3)
	await physics(3)
	expect(city.activities.current == null, "qua hết checkpoint mà cuộc đua chưa kết thúc")
	expect(game.money == money + 1200, "về nhất mà tiền thưởng sai (%d)" % (game.money - money))
	expect(game.stat("races_won") == 1 and float(game.stats.get("race_best_%d" % index, 0.0)) > 0.0, "chưa lưu thắng/kỷ lục đua")
	city.player.exit_vehicle()
	car.queue_free()


func _check_delivery(city: Node) -> void:
	city.player.global_position = _cell_pos(city.data.find("J"))
	await physics(3)
	expect(city.interactions.prompt == "HINT_DELIVERY", "đứng ở trạm giao hàng mà không có gợi ý (%s)" % city.interactions.prompt)
	await tap(&"interact")
	await physics(2)
	var job: Node = city.activities.current
	expect(job != null and city.activities.kind == "delivery", "không nhận được việc giao hàng")
	if job == null:
		return
	var money: int = game.money
	for i in 5:
		expect(is_instance_valid(job) and job._target.distance_to(city.player.global_position) > 300.0, "đơn %d quá gần / việc đã kết thúc sớm" % (i + 1))
		if not is_instance_valid(job):
			break
		city.player.global_position = job._target
		await physics(3)
	expect(city.activities.current == null and game.stat("deliveries") == 5, "giao đủ 5 đơn mà việc chưa xong (%d đơn)" % game.stat("deliveries"))
	expect(game.money - money > 5 * 60 + 400, "giao hàng: tiền công %d" % (game.money - money))


func _check_sweep(city: Node) -> void:
	city.player.global_position = _cell_pos(city.data.find("K"))
	await physics(3)
	expect(city.interactions.prompt == "HINT_SWEEP", "đứng ở điểm càn quét mà không có gợi ý (%s)" % city.interactions.prompt)
	await tap(&"interact")
	await physics(3)
	var job: Node = city.activities.current
	var gang := get_nodes_in_group("gang").filter(func(g: Node) -> bool: return g.alive)
	expect(job != null and gang.size() == 8, "càn quét: %d tên (mong 8)" % gang.size())
	var money: int = game.money
	for g in gang:
		g.take_hit(999.0, Vector2.RIGHT, city.player)
	await physics(3)
	expect(city.activities.current == null and game.money == money + 1500, "hạ hết mà càn quét chưa xong / tiền sai")


func _check_taxi(city: Node) -> void:
	var road: Vector2 = _cell_pos(Vector2i(30, 22))
	var taxi := await _drive(city, "taxi", road)
	await physics(3)
	var job: Node = city.activities.current
	expect(job != null and city.activities.kind == "taxi", "lên taxi mà không có khách")
	if job == null:
		return
	taxi.global_position = job._target
	taxi.velocity = Vector2.ZERO
	await physics(3)
	expect(job._riding, "dừng cạnh khách mà khách không lên xe")
	var money: int = game.money
	taxi.global_position = job._target
	taxi.velocity = Vector2.ZERO
	await physics(3)
	expect(game.money > money and game.stat("fares") == 1, "trả khách mà không được tiền")
	await _leave(city)
	taxi.queue_free()


func _check_vigilante(city: Node) -> void:
	game.clear_wanted()
	var cruiser := await _drive(city, "police", _cell_pos(Vector2i(30, 22)))
	await physics(3)
	var job: Node = city.activities.current
	expect(job != null and city.activities.kind == "vigilante", "lái xe cảnh sát mà không có tuần tra")
	if job == null:
		return
	var crook_car: Node = job._car
	expect(is_instance_valid(crook_car) and crook_car.autopilot != null, "tuần tra: không có xe nghi phạm bỏ chạy")
	crook_car.take_hit(crook_car.hp * 0.8, Vector2.RIGHT, city.player)
	await physics(3)
	expect(is_instance_valid(job._crook), "xe nghi phạm hỏng mà hắn không nhảy ra")
	var money: int = game.money
	if is_instance_valid(job._crook):
		job._crook.take_hit(999.0, Vector2.RIGHT, city.player)
	await physics(3)
	expect(game.money == money + 250 and job.level == 2, "hạ nghi phạm: tiền +%d, lượt %d" % [game.money - money, job.level])
	await _leave(city)
	cruiser.queue_free()


func _check_token(city: Node) -> void:
	var cell: Vector2i = city.data.find("o")
	var money: int = game.money
	city.player.global_position = _cell_pos(cell)
	await physics(5)
	expect(game.marked("tokens").size() == 1 and game.money == money + 100, "nhặt xu neon: %d xu, tiền +%d" % [game.marked("tokens").size(), game.money - money])
	game.save_game()
	game.reset_progress()
	game.load_game()
	expect(game.marked("tokens").has("%d,%d" % [cell.x, cell.y]), "xu neon đã nhặt không được lưu")
	var again := await open_city()
	await close_overlays(again)
	var items: Array = again.effects.get_children().filter(func(n: Node) -> bool: return n is Area2D and n.global_position.distance_to(_cell_pos(cell)) < 4.0)
	expect(items.is_empty(), "vào lại thành phố mà xu đã nhặt vẫn còn")


func _check_ramp(city: Node) -> void:
	city.population.set_process(false)
	var r: Array = load("res://scripts/core/data_db.gd").extras().ramps[0]
	var dir := Vector2(float(r[2]), float(r[3]))
	var ramp: Vector2 = _cell_pos(Vector2i(int(r[0]), int(r[1])))
	var car := await _drive(city, "sports", ramp - dir * 64.0 * 4.0)
	car.rotation = dir.angle()
	var money: int = game.money
	var flew := false
	for i in 120:
		car.velocity = dir * 420.0
		await physics_frame
		if car.stunt.air > 0.0:
			flew = true
			break
	expect(flew, "lao qua dốc mà xe không bay")
	await physics(100)
	expect(car.stunt.air <= 0.0 and car.collision_layer != 0, "xe không tiếp đất / không bật lại va chạm")
	expect(game.money > money and game.marked("jump_ids").size() == 1, "nhảy dốc không được thưởng")

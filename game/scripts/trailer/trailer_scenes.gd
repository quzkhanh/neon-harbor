class_name TrailerScenes
extends RefCounted
## Các cảnh quay trailer (Trailer gọi). Mỗi cảnh tự chọn chỗ, dọn khu vực, dàn nhân vật, diễn rồi trả về;
## mốc sự kiện ghi qua `t.mark`. Đường ngang được ưu tiên: khung dọc thấy được cả hai bên đường.

const NAMES := ["pigeons", "incident", "chase", "dog", "night"]
const RUN := 6  # ô đường thẳng + vỉa hè liền mỗi bên chỗ dựng cảnh
const ACROSS_MAX := 5  # tìm vỉa hè bên kia đường trong chừng này ô
const QUIET_RADIUS := 900.0
const MAX_WAIT := 600  # khung hình: chờ một diễn biến tối đa chừng này rồi đi tiếp
const PIGEONS := 10
const STAR_EVERY := 150
const CHASE_HOLD := 360
const ARGUE_CUT := 4.0  # giây cãi nhau trước khi chuyển sang ẩu đả (trailer luôn có đoạn ẩu đả)
const FIRE_FRAMES := 120
const NIGHT_TAIL := 90  # khung hình đi tiếp sau câu thoại cuối
const LINE_RANGE := 110.0  # Jay đi tới gần chừng này thì người đó nói
const LANE_GAP := 20.0  # Jay đi sát mép đường, người đứng sát mép nhà: không chặn đường nhau
const DOG_STOP := 120.0  # chó dừng ngoài tầm giật mình vì Jay (Critter.SPECS.dog.scare)


static func run(scene_name: String, t: Trailer) -> void:
	match scene_name:
		"pigeons":
			await _pigeons(t)
		"incident":
			await _incident(t)
		"chase":
			await _chase(t)
		"dog":
			await _dog(t)
		"night":
			await _night(t)


## Ông lão cho bồ câu ăn bên vỉa hè; xe thể thao lao qua bấm còi, cả bầy bay lên. Jay đứng xem bên kia đường.
static func _pigeons(t: Trailer) -> void:
	var city := t.city
	Game.clock = 16.5
	var curb := _curb(city, city.player.global_position)
	var walk := MapData.cell_center(curb.lane + curb.side)
	_quiet(city, walk)
	var feeder := _ped(city, walk + Vector2(curb.side) * 18.0, "feeder")
	feeder.add_to_group("feeders")
	feeder.scripted = true
	feeder.face(-Vector2(curb.side).angle())
	var flock: Array[Critter] = []
	for i in PIGEONS:
		flock.append(_critter(city, "pigeon", walk + Vector2(curb.dir) * randf_range(-90.0, 90.0) + Vector2(curb.side) * randf_range(-24.0, 10.0)))
	_watch_from_across(city, curb, walk)
	var v := city.spawn_vehicle("sports", curb.lane - curb.dir * 14, Vector2(curb.dir).angle(), "car_red_5")
	var driver := GotoDriver.new(city)
	driver.target = MapData.cell_center(curb.lane + curb.dir * 16)
	driver.ratio = 1.0
	driver.waiting = true
	v.autopilot = driver
	v.has_npc_driver = true
	t.mark("feeding")
	await t.frames(40)
	Speech.say(feeder, Speech.pick(PedTalk.QUIRK_LINES.feeder))
	await _until(t, func() -> bool: return not feeder.has_node(Speech.NODE_NAME))  # bong bóng thoại không che xe lao qua
	driver.waiting = false
	t.mark("car_go")
	await _until(t, func() -> bool: return v.global_position.distance_to(walk) < 300.0)
	v.honk()
	t.mark("honk")
	await _until(t, func() -> bool: return flock.any(func(c: Critter) -> bool: return c._flee_time > 0.0))
	t.mark("flock_up")
	t.punch()
	await t.frames(150)


## Hai xe tông đuôi nhau, tài xế xuống cãi, rồi ẩu đả, làm lành, lên xe đi. Xe phía sau dồn lại bấm còi.
static func _incident(t: Trailer) -> void:
	var city := t.city
	Game.clock = 20.5
	var spawner: RoadIncidents = city.get_node("RoadIncidents")
	spawner.set_process(false)
	var curb := _curb(city, city.player.global_position)
	var crash := MapData.cell_center(curb.lane)
	for v in city.get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(crash) < 400.0:
			v.queue_free()
	_watch_from_across(city, curb, crash)
	await t.frames(30)
	spawner._stage(curb.lane)
	var incident := spawner._active
	t.mark("crash")
	t.punch()
	var phase := -1
	for i in MAX_WAIT * 4:
		if not is_instance_valid(incident) or incident._phase == RoadIncident.Phase.DONE:
			break
		if incident._phase != phase:
			phase = incident._phase
			t.mark(RoadIncident.Phase.keys()[phase].to_lower())
		if phase == RoadIncident.Phase.ARGUE and incident._t > ARGUE_CUT:
			incident._enter(RoadIncident.Phase.FIGHT)
		if phase == RoadIncident.Phase.LEAVE and incident._t > 3.0:
			break
		await t.frames(1)


## Rượt đuổi đêm mưa: truy nã tăng dần từ 1 lên 5 sao trên tuyến đua, Jay đốt nitro và drift qua góc cua.
## Xe và Jay không chết được (giữ đầy máu) để cảnh không bị cắt ngang.
static func _chase(t: Trailer) -> void:
	var city := t.city
	var p := city.player
	Game.clock = 22.5
	await t.frames(3)  # để Weather thấy giờ mới trước, kẻo lần tung xúc xắc đầu giờ tắt mưa
	city.get_node("Weather").set_raining(true)
	var race: Dictionary = DataDB.extras().races[0]
	var route: Array[Vector2] = []
	for point in race.points:
		route.append(Vector2(float(point[0]), float(point[1])) * Tuning.TILE)
	var start_cell := Vector2i(int(race.start[0]), int(race.start[1]))
	var heading := Vector2(float(race.heading[0]), float(race.heading[1]))
	for v in city.get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(MapData.cell_center(start_cell)) < 300.0:
			v.queue_free()
	var car := city.spawn_vehicle("super", start_cell, heading.angle(), "car_yellow_5")
	p.global_position = car.global_position + Vector2(0, 50)
	await t.frames(3)
	p.enter_vehicle(car)
	car.autopilot = TrailerPilot.new(city, route)
	var wrecks := {}
	var level := 0
	for frame in STAR_EVERY * Tuning.MAX_STARS + CHASE_HOLD:
		if frame % STAR_EVERY == 0 and level < Tuning.MAX_STARS:
			level += 1
			Game.set_stars(level)
			t.mark("stars_%d" % level)
		Game.health = Tuning.MAX_HEALTH
		car.hp = float(car.spec.hp)
		for v in city.get_tree().get_nodes_in_group("vehicles"):
			if v.wrecked and not wrecks.has(v):
				wrecks[v] = true
				t.mark("explosion")
				t.punch()
		await t.frames(1)


## Bắn cả băng tiểu liên vào con chó: đạn đi xuyên qua, chó không hề hấn gì, sủa một tiếng rồi chạy lại chỗ Jay.
static func _dog(t: Trailer) -> void:
	var city := t.city
	var p := city.player
	Game.clock = 14.0
	var curb := _curb(city, p.global_position)
	var walk := MapData.cell_center(curb.lane + curb.side)
	_quiet(city, walk)
	var along := Vector2(curb.dir)
	p.global_position = walk - along * 90.0
	city.camera.global_position = p.global_position
	var dog := _critter(city, "dog", walk + along * 80.0)
	dog.coat = Palette.DOG_COATS[0]
	dog._idle = INF
	dog._art.rotation = (-along).angle()
	Game.grant_weapon("smg")
	var aim := &"aim_right" if along.x > 0.0 else &"aim_left"
	Input.action_press(aim)
	await t.frames(40)
	t.mark("fire")
	Input.action_press(&"fire")
	for i in FIRE_FRAMES:
		Game.clear_wanted()
		await t.frames(1)
	Input.action_release(&"fire")
	Input.action_release(aim)
	t.mark("cease")
	await t.frames(30)
	Game.clear_wanted()
	Speech.say(dog, Speech.pick(Critter.SPECS.dog.bark))
	t.mark("bark")
	dog._idle = 0.0
	dog._goal = p.global_position + along * DOG_STOP
	await t.frames(150)


## Phố đêm: Jay đi bộ dọc vỉa hè qua người say, người làm ca đêm, kẻ đứng góc phố; tới gần ai thì người đó nói.
static func _night(t: Trailer) -> void:
	var city := t.city
	var p := city.player
	Game.clock = 23.5
	var curb := _curb(city, p.global_position)
	var walk := MapData.cell_center(curb.lane + curb.side)
	_quiet(city, walk)
	var along := Vector2(curb.dir)
	var inward := Vector2(curb.side)
	p.global_position = walk - along * Tuning.TILE * 3.0 - inward * LANE_GAP
	p.aim_angle = along.angle()
	city.camera.global_position = p.global_position
	var waiting: Array[Pedestrian] = []
	var gap := 0.0
	for quirk in ["drunk", "nightshift", "loiter"]:
		var ped := _ped(city, walk + along * Tuning.TILE * gap + inward * LANE_GAP, quirk)
		ped.scripted = true
		ped.face((-along).angle())
		waiting.append(ped)
		gap += 3.0  # người cuối vẫn trong đoạn vỉa hè thẳng RUN ô
	t.mark("walk")
	var move := &"move_right" if along.x > 0.0 else &"move_left"
	Input.action_press(move)
	var last: Pedestrian = null
	for i in MAX_WAIT:
		if waiting.is_empty():
			break
		for ped in waiting:
			if ped.global_position.distance_to(p.global_position) < LINE_RANGE:
				if last:
					Speech.clear(last)  # mỗi lúc một người nói: bong bóng thoại dài (tiếng Anh) không đè lên nhau
				last = ped
				Speech.say(ped, Speech.pick(PedTalk.QUIRK_LINES[ped.quirk]))
				t.mark("line_" + ped.quirk)
				waiting.erase(ped)
				break
		await t.frames(1)
	await t.frames(NIGHT_TAIL)
	Input.action_release(move)


## Ô làn đường ngang gần `near` có RUN ô thẳng mỗi bên, sát vỉa hè liền mạch, và có vỉa hè bên kia đường.
## Trả về {lane, dir: hướng làn, side: từ làn về phía vỉa hè, across: ô vỉa hè bên kia}.
static func _curb(city: City, near: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for ch in MapData.LANES:
		var dir: Vector2i = MapData.LANES[ch]
		if dir.y != 0:
			continue
		for cell in city.data.find_all(ch):
			var d := MapData.cell_center(cell).distance_to(near)
			if d >= best_d:
				continue
			for side in [Vector2i.UP, Vector2i.DOWN]:
				var across := _across(city, cell, -side)
				if across.x >= 0 and _clear_run(city, cell, dir, side):
					best = {"lane": cell, "dir": dir, "side": side, "across": across}
					best_d = d
	return best


static func _clear_run(city: City, cell: Vector2i, dir: Vector2i, side: Vector2i) -> bool:
	for k in range(-RUN, RUN + 1):
		var c := cell + dir * k
		if city.data.lane_dir(c) != dir or city.data.at(c + side) != ",":
			return false
	return true


static func _across(city: City, cell: Vector2i, step: Vector2i) -> Vector2i:
	for k in range(1, ACROSS_MAX + 1):
		if city.data.at(cell + step * k) == ",":
			return cell + step * k
	return Vector2i(-1, -1)


## Jay đứng vỉa hè bên kia đường nhìn sang: camera (nhìn trước theo hướng ngắm) lấy được cả hai bên.
static func _watch_from_across(city: City, curb: Dictionary, target: Vector2) -> void:
	var p := city.player
	p.global_position = MapData.cell_center(curb.across)
	p.aim_angle = (target - p.global_position).angle()
	p.face(p.aim_angle)
	city.camera.global_position = p.global_position


## Dọn người, thú, xe quanh chỗ quay và tắt các bộ sinh mới, để cảnh chỉ có những gì đã dàn.
static func _quiet(city: City, center: Vector2) -> void:
	city.population.set_process(false)
	city.get_node("Critters").set_process(false)
	city.get_node("RoadIncidents").set_process(false)
	for group in ["peds", "critters", "vehicles"]:
		for n in city.get_tree().get_nodes_in_group(group):
			if n.global_position.distance_to(center) < QUIET_RADIUS:
				n.queue_free()


static func _ped(city: City, pos: Vector2, quirk: String) -> Pedestrian:
	var ped: Pedestrian = city.spawn_npc(Pedestrian, pos)
	ped.add_to_group("peds")
	ped.quirk = quirk  # đặt sau _ready (lúc đó quirk được tung ngẫu nhiên)
	ped.skin = Pedestrian.QUIRK_SKINS.get(quirk, ped.skin)
	ped.set_pose("stand")
	return ped


static func _critter(city: City, kind: String, pos: Vector2) -> Critter:
	var c := Critter.new()
	c.kind = kind
	c.city = city
	c.global_position = pos
	city.actors.add_child(c)
	return c


static func _until(t: Trailer, done: Callable) -> void:
	for i in MAX_WAIT:
		if done.call():
			return
		await t.frames(1)

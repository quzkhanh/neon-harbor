extends "res://tests/harness.gd"
## Bot tự chơi bằng vật lý và input thật (chỉ báo cáo, không làm fail check_all):
##  - NV1: lên xe máy, lái theo đường A* tới điểm giao, lần lượt bằng 2 kiểu lái; đo thời gian và số lần va chạm.
##  - NV2: cầm tiểu liên + giáp như người chơi đã mua, đấu súng với 6 tên Red Fangs; đo máu còn lại.
## Chạy: godot --headless --fixed-fps 60 --path game -s res://tests/bot_play.gd

const LOOKAHEAD := 2
const LIMIT_M1 := 75
const TILE := 64.0  # test không được tham chiếu class_name của game (Tuning)
const MAX_SECONDS := 120.0


func _initialize() -> void:
	watchdog_sec = 600.0
	super()


func _run() -> void:
	for mode in ["screen", "classic"]:
		game.missions_done = []
		await _bot_mission1(await open_city(), mode)
	game.missions_done = [1]
	var city := await open_city()
	await _bot_mission2(city)
	finish("BOT")


func _start_mission(city: Node, n: int) -> Node:
	city.player.global_position = city.missions.giver_pos(n)
	for i in 60:
		await physics(1)
		if city.overlays.current:
			break
	await close_overlays(city)
	await physics(5)
	return city.missions.current


## `mode` "screen": bấm phím hướng về điểm kế tiếp trên đường (như người mới chơi, không tự phanh/lùi);
## "classic": tự tính ga/phanh/lái theo thân xe và tự lùi khi kẹt.
func _bot_mission1(city: Node, mode: String) -> void:
	game.settings.steering = mode
	var mission := await _start_mission(city, 1)
	var p: Node = city.player
	var bike: Node = mission.bike
	await _walk_to(city, bike.global_position, 70.0)
	await tap(&"interact")
	if p.vehicle != mission.bike:
		print("BOT NV1 (%s): không lên được xe máy" % mode)
		return
	var goal: Vector2 = mission.cell_pos("d")
	var t := 0.0
	var stuck := 0.0
	var reverse := 0.0
	var crashes := 0
	var path: PackedVector2Array = city.path(p.vehicle.global_position, goal, true)
	while is_instance_valid(mission) and city.missions.current == mission and not paused and t < MAX_SECONDS:
		var v: Node = p.vehicle
		if v == null:
			break
		while path.size() > 1 and v.global_position.distance_to(path[0]) < TILE * 1.2:
			path.remove_at(0)
		var target: Vector2 = path[mini(LOOKAHEAD - 1, path.size() - 1)] if path.size() > 0 else goal
		var speed: float = v.velocity.length()
		if mode == "screen":
			_set_vec(&"move_left", &"move_right", &"move_up", &"move_down", (target - v.global_position).normalized())
		else:
			var diff: float = angle_difference(v.rotation, (target - v.global_position).angle())
			_hold_action(&"steer_right", clampf(diff * 2.5, 0.0, 1.0))
			_hold_action(&"steer_left", clampf(-diff * 2.5, 0.0, 1.0))
			var sharp := absf(diff) > 0.7
			_hold_action(&"accelerate", 0.0 if reverse > 0.0 else (0.35 if sharp else 1.0))
			_hold_action(&"brake", 1.0 if reverse > 0.0 or (sharp and speed > 260.0) else 0.0)
			stuck = stuck + 1.0 / 60.0 if speed < 30.0 else 0.0
			if stuck > 1.0:
				reverse = 0.8
				stuck = 0.0
				path = city.path(v.global_position, goal, true)
			reverse -= 1.0 / 60.0
		var hp_before: float = v.hp
		await physics(1)
		if is_instance_valid(v) and v.hp < hp_before:
			crashes += 1
		t += 1.0 / 60.0
	for a in [&"steer_right", &"steer_left", &"accelerate", &"brake", &"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
	var hp := int(bike.hp) if is_instance_valid(bike) else -1
	await close_overlays(city)
	print("BOT NV1 (%s): %s sau %.1f giây lái (giới hạn %d giây), %d lần va chạm, máu xe máy %d" % [
		mode, "HOÀN THÀNH" if 1 in game.missions_done else "CHƯA XONG", t, LIMIT_M1, crashes, hp])
	game.settings.steering = "screen"


func _bot_mission2(city: Node) -> void:
	game.owned["smg"] = {"mag": 30}
	game.select_weapon("smg")
	game.add_armor(100.0)
	var mission := await _start_mission(city, 2)
	var p: Node = city.player
	p.global_position = city.missions.cell_pos_of("r") + Vector2(-9, -3) * TILE
	var t := 0.0
	var strafe := 1.0
	while t < MAX_SECONDS and p.alive and get_nodes_in_group("gang").any(func(g: Node) -> bool: return g.alive):
		var target := _nearest_gang(p)
		var to: Vector2 = target.global_position - p.global_position
		var los := _clear(p, target.global_position)
		var move := Vector2.ZERO
		if not los or to.length() > 330.0:
			var route: PackedVector2Array = city.path(p.global_position, target.global_position)
			move = ((route[1] if route.size() > 1 else target.global_position) - p.global_position).normalized()
		else:
			if fmod(t, 1.6) < 1.0 / 60.0:
				strafe = -strafe
			move = to.normalized().rotated(PI * 0.5) * strafe
		_set_vec(&"move_left", &"move_right", &"move_up", &"move_down", move)
		_set_vec(&"aim_left", &"aim_right", &"aim_up", &"aim_down", to.normalized())
		_hold_action(&"fire", 1.0 if los and to.length() < 520.0 else 0.0)
		await physics(1)
		t += 1.0 / 60.0
	for a in [&"move_left", &"move_right", &"move_up", &"move_down", &"aim_left", &"aim_right", &"aim_up", &"aim_down", &"fire"]:
		Input.action_release(a)
	var left := get_nodes_in_group("gang").filter(func(g: Node) -> bool: return g.alive).size()
	print("BOT NV2: %s sau %.1f giây, còn %d/6 tên, máu %d, giáp %d" % [
		"SỐNG SÓT" if p.alive else "GỤC", t, left, int(game.health), int(game.armor)])
	await close_overlays(city)


func _walk_to(city: Node, goal: Vector2, radius: float) -> void:
	var p: Node = city.player
	for i in 600:
		if p.global_position.distance_to(goal) < radius:
			break
		var route: PackedVector2Array = city.path(p.global_position, goal)
		var next := route[1] if route.size() > 1 else goal
		_set_vec(&"move_left", &"move_right", &"move_up", &"move_down", (next - p.global_position).normalized())
		await physics(1)
	_set_vec(&"move_left", &"move_right", &"move_up", &"move_down", Vector2.ZERO)


func _nearest_gang(p: Node) -> Node:
	var best: Node = null
	for g in get_nodes_in_group("gang"):
		if g.alive and (best == null or g.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = g
	return best


func _clear(p: Node, pos: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(p.global_position, pos, 1)
	return p.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _hold_action(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _set_vec(left: StringName, right: StringName, up: StringName, down: StringName, v: Vector2) -> void:
	_hold_action(left, maxf(-v.x, 0.0))
	_hold_action(right, maxf(v.x, 0.0))
	_hold_action(up, maxf(-v.y, 0.0))
	_hold_action(down, maxf(v.y, 0.0))


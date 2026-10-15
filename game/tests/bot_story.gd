extends "res://tests/harness.gd"
## Bot lái thật (vật lý thật, phím di chuyển thật, dòng xe và cảnh sát thật) qua các nhiệm vụ lái xe của chương 2–3,
## để chắc chúng chơi được không cần dịch chuyển (chỉ báo cáo, không làm fail check_all):
##  - NV3: cướp xe ở bến tàu, cắt đuôi 2 sao ở tiệm sửa xe, đưa về gara; NV4: bám đuôi xe đưa tin tới kho; NV6: lái xe gài bom (giữ tốc độ) tới kho xăng rồi nhảy ra;
##  - NV7: đón Vince rồi chở tới nơi an toàn khi xe Red Fangs truy đuổi;
##  - NV5: giữ quán trước 3 đợt; NV8: cướp xe chở tiền, lái tới tiệm sửa xe xoá 3 sao, đưa về gara;
##  - NV9: tấn công kho, hạ trùm, cướp xe gần nhất chạy tới tiệm sửa xe xoá 4 sao.
## Chạy: godot --headless --fixed-fps 60 --path game -s res://tests/bot_story.gd

const TILE := 64.0
const LOOKAHEAD := 2
const MAX_SECONDS := 150.0
const DIRS := [&"move_left", &"move_right", &"move_up", &"move_down"]

var _path := PackedVector2Array()
var _path_age := 0.0
var _stuck := 0.0
var _back := 0.0


func _initialize() -> void:
	watchdog_sec = 900.0
	super()


func _run() -> void:
	for n in [3, 4, 5, 6, 7, 8, 9]:
		game.missions_done = range(1, n)
		game.money = 3000  # đủ trả tiệm sửa xe như người chơi đã qua nhiều nhiệm vụ
		game.health = 100.0
		game.armor = 0.0
		game.clear_wanted()
		var city := await open_city()
		await close_overlays(city)
		game.settings.tutorial = false
		var mission := await _begin(city, n)
		var notices := []
		game.notice.connect(func(text: String) -> void: notices.append(text))
		var t: float = await call("_m%d" % n, city, mission)
		_release()
		var hp: int = int(game.health)
		await close_overlays(city)
		var done: bool = n in game.missions_done
		print("BOT NV%d: %s sau %.1f giây, máu %d, còn sống %s; thông báo cuối: %s" % [n, "HOÀN THÀNH" if done else "CHƯA XONG", t,
			hp, city.player.alive, notices.slice(-2)])
		for i in 300:  # xong NV9 thì game sang màn kết: chờ chuyển cảnh xong rồi mới mở lượt sau
			if not done or n != 9 or (current_scene and current_scene.scene_file_path == game.ENDING_SCENE):
				break
			await frames(1)
	finish("BOT_STORY")


func _begin(city: Node, n: int) -> Node:
	city.player.global_position = city.missions.giver_pos(n)
	for i in 120:
		await physics(1)
		if city.overlays.current or city.missions.current:
			break
	await close_overlays(city)
	await physics(5)
	return city.missions.current


func _running(city: Node, mission: Variant) -> bool:
	return is_instance_valid(mission) and city.missions.current == mission and city.player.alive


## Lên chiếc xe gần nhất (đi tới cạnh rồi bấm E như người chơi).
func _board(city: Node, v: Node) -> void:
	city.player.global_position = v.global_position + Vector2.from_angle(v.rotation + PI * 0.5) * (v.size.y * 0.5 + 24.0)
	await physics(3)
	await tap(&"interact")
	await physics(3)


## Một bước lái kiểu "theo hướng phím": bấm phím hướng về điểm kế tiếp trên đường A* (tính lại mỗi giây);
## kẹt thì bấm ngược hướng một lúc để xe lùi ra. `stop` thì nhả hết phím (xe tự dừng).
func _drive_step(city: Node, goal: Vector2, stop := false) -> void:
	var v: Node = city.player.vehicle
	if v == null or stop:
		_release()
		return
	_path_age -= 1.0 / 60.0
	if _path_age <= 0.0 or _path.is_empty():
		_path_age = 1.0
		_path = city.path(v.global_position, goal, true)
	while _path.size() > 1 and v.global_position.distance_to(_path[0]) < TILE * 1.2:
		_path.remove_at(0)
	var target: Vector2 = _path[mini(LOOKAHEAD - 1, _path.size() - 1)] if _path.size() > 0 else goal
	var dir: Vector2 = (target - v.global_position).normalized()
	_stuck = _stuck + 1.0 / 60.0 if v.velocity.length() < 30.0 else 0.0
	if _stuck > 1.5:
		_stuck = 0.0
		_back = 0.7
	if _back > 0.0:
		_back -= 1.0 / 60.0
		dir = -Vector2.from_angle(v.rotation)
	_press(dir)


func _press(dir: Vector2) -> void:
	var amounts := [maxf(-dir.x, 0.0), maxf(dir.x, 0.0), maxf(-dir.y, 0.0), maxf(dir.y, 0.0)]
	for i in DIRS.size():
		if amounts[i] > 0.05:
			Input.action_press(DIRS[i], amounts[i])
		else:
			Input.action_release(DIRS[i])


func _release() -> void:
	for a in DIRS:
		Input.action_release(a)


func _m4(city: Node, mission: Node) -> float:
	await _board(city, mission._car)
	var t := 0.0
	while _running(city, mission) and t < MAX_SECONDS:
		var courier: Node = mission.courier
		if not is_instance_valid(courier):
			break
		var me: Vector2 = city.player.vehicle.global_position if city.player.vehicle else city.player.global_position
		_drive_step(city, courier.global_position, me.distance_to(courier.global_position) < 330.0)
		await physics(1)
		t += 1.0 / 60.0
	return t


func _m6(city: Node, mission: Node) -> float:
	await _board(city, mission.car)
	var depot: Vector2 = mission.cell_pos("F")
	var t := 0.0
	while _running(city, mission) and t < MAX_SECONDS:
		var car: Node = city.player.vehicle
		if car and car.global_position.distance_to(depot) < 300.0:
			_release()
			await tap(&"interact")
		elif car:
			_drive_step(city, depot)
		await physics(1)
		t += 1.0 / 60.0
	return t


func _m7(city: Node, mission: Node) -> float:
	var best: Node = null
	for v in get_nodes_in_group("vehicles"):
		if best == null or v.global_position.distance_to(city.player.global_position) < best.global_position.distance_to(city.player.global_position):
			best = v
	await _board(city, best)
	var t := 0.0
	while _running(city, mission) and t < MAX_SECONDS:
		var goal: Vector2 = mission.cell_pos("e" if mission._aboard else "i")
		var v: Node = city.player.vehicle
		_drive_step(city, goal, v != null and v.global_position.distance_to(goal) < 100.0)
		await physics(1)
		t += 1.0 / 60.0
	return t


func _m5(city: Node, mission: Node) -> float:
	return await _fight(city, mission, mission.cell_pos("y"), func() -> bool: return false, 60.0)


func _m9(city: Node, mission: Node) -> float:
	var t: float = await _fight(city, mission, mission.cell_pos("w"), func() -> bool: return mission._escaping, 450.0)
	return t + await _escape(city, mission)


func _m3(city: Node, mission: Node) -> float:
	return await _steal_and_deliver(city, mission, mission.car)


func _m8(city: Node, mission: Node) -> float:
	return await _steal_and_deliver(city, mission, mission.truck)


## Cướp xe nhiệm vụ, cắt đuôi ở tiệm sửa xe, đưa về gara (NV3, NV8).
func _steal_and_deliver(city: Node, mission: Node, car: Node) -> float:
	await _board(city, car)
	var t := 0.0
	while _running(city, mission) and t < MAX_SECONDS:
		if game.stars > 0:
			t += await _escape(city, mission)
			if not _running(city, mission):
				break
		_drive_step(city, mission.cell_pos("G"))
		await physics(1)
		t += 1.0 / 60.0
	return t


## Cắt đuôi như người chơi: không có xe thì lấy xe gần nhất, lái tới tiệm sửa xe gần nhất rồi bấm E (trả tiền, xoá sao).
func _escape(city: Node, mission: Node) -> float:
	var t := 0.0
	var p: Node = city.player
	while _running(city, mission) and game.stars > 0 and t < MAX_SECONDS:
		if p.vehicle == null:
			var car := _nearest_car(city)
			if car:
				await _board(city, car)
		var shop := _nearest(city.interactions._resprays, p.global_position)
		if p.vehicle and p.vehicle.global_position.distance_to(shop) < 110.0:
			_release()
			if city.interactions.prompt == "HINT_RESPRAY":
				await tap(&"interact")
		else:
			_drive_step(city, shop)
		await physics(1)
		t += 1.0 / 60.0
	return t


func _nearest(spots: Array, from: Vector2) -> Vector2:
	var best: Vector2 = spots[0]
	for s in spots:
		if from.distance_to(s) < from.distance_to(best):
			best = s
	return best


func _nearest_car(city: Node) -> Node:
	var best: Node = null
	for v in get_nodes_in_group("vehicles"):
		if v.wrecked or v.burning or v.has_npc_driver or v.kind == "boat":
			continue
		if best == null or v.global_position.distance_to(city.player.global_position) < best.global_position.distance_to(city.player.global_position):
			best = v
	return best


## Đấu súng như người chơi: không thấy địch thì đi tới cách `anchor` chừng `hold` px (đứng chờ địch ra, không lao vào
## giữa ổ), thấy thì vừa bắn vừa né ngang (như bot NV2).
func _fight(city: Node, mission: Node, anchor: Vector2, done: Callable, hold: float) -> float:
	var p: Node = city.player
	var t := 0.0
	var strafe := 1.0
	var aims := [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]
	while _running(city, mission) and not done.call() and t < MAX_SECONDS:
		var target := _nearest_gang(p)
		var move := Vector2.ZERO
		var aim := Vector2.ZERO
		var fire := false
		if target == null:
			var route: PackedVector2Array = city.path(p.global_position, anchor)
			move = ((route[1] if route.size() > 1 else anchor) - p.global_position).normalized() if p.global_position.distance_to(anchor) > hold else Vector2.ZERO
		else:
			var to: Vector2 = target.global_position - p.global_position
			var los := _clear(p, target.global_position)
			aim = to.normalized()
			fire = los and to.length() < 520.0
			if not los or to.length() > 330.0:
				var route: PackedVector2Array = city.path(p.global_position, target.global_position)
				move = ((route[1] if route.size() > 1 else target.global_position) - p.global_position).normalized()
			else:
				if fmod(t, 1.6) < 1.0 / 60.0:
					strafe = -strafe
				move = to.normalized().rotated(PI * 0.5) * strafe
		_press(move)
		for i in aims.size():
			var amount: float = [maxf(-aim.x, 0.0), maxf(aim.x, 0.0), maxf(-aim.y, 0.0), maxf(aim.y, 0.0)][i]
			if amount > 0.05:
				Input.action_press(aims[i], amount)
			else:
				Input.action_release(aims[i])
		if fire:
			Input.action_press(&"fire")
		else:
			Input.action_release(&"fire")
		await physics(1)
		t += 1.0 / 60.0
	if t >= MAX_SECONDS:
		var b = mission.boss
		print("  HẾT GIỜ: boss sống=%s ô=%s cách=%d thấy=%s; gang sống=%s" % [b.alive, city.data.at(Vector2i(b.global_position / 64.0)), b.global_position.distance_to(p.global_position), _clear(p, b.global_position),
			get_nodes_in_group("gang").filter(func(g): return g.alive).map(func(g): return "%s@%d" % [city.data.at(Vector2i(g.global_position / 64.0)), g.global_position.distance_to(p.global_position)])])
	for a in aims + [&"fire"]:
		Input.action_release(a)
	return t


## Tên gần nhất trong tầm, ưu tiên tên đang lộ (bắn được ngay) hơn tên nấp sau tường.
func _nearest_gang(p: Node) -> Node:
	var best: Node = null
	var best_score := INF
	for g in get_nodes_in_group("gang"):
		var d: float = g.global_position.distance_to(p.global_position)
		var score := d + (0.0 if _clear(p, g.global_position) else 1000.0)
		if g.alive and d < 700.0 and score < best_score:
			best = g
			best_score = score
	return best


func _clear(p: Node, pos: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(p.global_position, pos, 1)
	return p.get_world_2d().direct_space_state.intersect_ray(q).is_empty()

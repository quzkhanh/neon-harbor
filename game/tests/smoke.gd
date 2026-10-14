extends "res://tests/harness.gd"
## Smoke test: nạp menu, thành phố, cửa hàng, màn kết. Trong thành phố giả lập 600 frame vật lý:
## đi bộ, bắn, lên xe, lái, xuống xe. Bắt mọi lỗi engine/script. Assert HUD tồn tại, nhân vật trong bản đồ.
## Chạy: godot --headless --path game -s res://tests/smoke.gd

const WALK := 100
const SHOOT := 100
const DRIVE := 260
const BRAKE := 90
const SETTLE := 50  # tổng = 600 frame vật lý (chưa kể bước hồi quy xe nổ)
const TILE := 64  # khớp Tuning.TILE
const GREEN_BUSH := Vector2i(20, 6)  # tile 183 của Kenney: (183 - 1) % 27, (183 - 1) / 27


func _run() -> void:
	var menu := await open_scene(game.MENU_SCENE)
	expect(menu.find_children("*", "Button", true, false).size() >= 3, "menu: thiếu nút")

	var city := await open_city()
	var player: Node = city.player
	var world: Rect2 = city.data.world_rect()
	expect(get_first_node_in_group("hud") != null, "thành phố: không có HUD")
	expect(world.has_point(player.global_position), "người chơi ngoài bản đồ lúc vào")

	# Hướng dẫn người mới: có khi chơi mới; bấm "Tắt" trong Cài đặt giữa lúc chơi thì biến mất ngay.
	expect(city.get_node_or_null("Tutorial") != null, "chơi mới mà không có hướng dẫn")
	var settings: Node = load("res://scripts/ui/settings_panel.gd").new()
	city.add_child(settings)
	await frames(2)
	var off: Array = settings.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "TUTORIAL_OFF")
	expect(off.size() == 1, "Cài đặt không có nút tắt hướng dẫn")
	if off.size() == 1:
		off[0].pressed.emit()
	settings.close()
	await frames(3)
	expect(city.get_node_or_null("Tutorial") == null, "tắt hướng dẫn trong Cài đặt mà khung hướng dẫn vẫn hiện")
	game.settings.tutorial = true
	await _check_building_depth(city)
	await _check_drop_in_physics_callback(city)

	var walk_start: Vector2 = player.global_position
	Input.action_press(&"move_left")
	await physics(WALK)
	Input.action_release(&"move_left")
	var walked: float = player.global_position.distance_to(walk_start)
	expect(walked > 100.0, "người chơi không đi được (đi %d px)" % walked)

	var mag_before: int = game.ammo().mag
	Input.action_press(&"aim_left")
	Input.action_press(&"fire")
	await physics(SHOOT)
	Input.action_release(&"fire")
	Input.action_release(&"aim_left")
	expect(game.ammo().mag != mag_before or player.gun.reloading > 0.0, "bắn không tốn đạn")

	var car: Node = city.spawn_vehicle("car", Vector2i(10, 22), 0.0)
	player.global_position = car.global_position + Vector2(0, 60)
	await physics(5)
	await tap(&"interact")
	expect(player.vehicle == car, "không lên được xe")
	# Lái theo hướng phím (mặc định): sang phải rồi rẽ xuống, bấm ngược hướng để phanh.
	var start: Vector2 = car.global_position
	Input.action_press(&"move_right")
	await physics(DRIVE / 2)
	Input.action_release(&"move_right")
	Input.action_press(&"move_down")
	await physics(DRIVE / 2)
	Input.action_release(&"move_down")
	var driven: float = car.global_position.distance_to(start)
	expect(driven > 200.0, "xe không chạy (đi %d px)" % driven)
	expect(absf(angle_difference(car.rotation, PI * 0.5)) < 0.5, "bấm xuống mà xe không quay xuống (góc %.2f)" % car.rotation)
	Input.action_press(&"move_up")
	await physics(BRAKE)
	Input.action_release(&"move_up")
	expect(car.velocity.dot(Vector2.DOWN) < 60.0, "bấm ngược hướng mà xe không phanh")
	# Kiểu cổ điển: ga + xoay thân xe (đặt lại xe trên làn trước).
	game.settings.steering = "classic"
	car.global_position = city.data.cell_center(Vector2i(10, 22))
	car.rotation = 0.0
	car.velocity = Vector2.ZERO
	start = car.global_position
	Input.action_press(&"accelerate")
	await physics(DRIVE / 2)
	Input.action_release(&"accelerate")
	expect(car.global_position.distance_to(start) > 100.0, "kiểu lái cổ điển: xe không chạy")
	game.settings.steering = "screen"
	Input.action_press(&"handbrake")
	await physics(BRAKE)
	Input.action_release(&"handbrake")
	await tap(&"interact")
	expect(player.vehicle == null, "không xuống được xe")
	await physics(SETTLE)
	expect(world.has_point(player.global_position), "người chơi ra ngoài bản đồ: %s" % player.global_position)

	# Hồi quy: xe bị một NPC bắn, NPC đó bị giải phóng trước khi xe nổ -> không được lỗi script.
	var wreck: Node = city.spawn_vehicle("car", Vector2i(10, 22), 0.0)
	var shooter: Node = city.spawn_npc(load("res://scripts/actors/cop.gd"), wreck.global_position + Vector2(0, 300))
	wreck.take_hit(500.0, Vector2.RIGHT, shooter)
	shooter.queue_free()
	await physics(200)
	expect(wreck.wrecked, "xe hết máu không nổ")

	city.overlays.show_shop()
	await frames(5)
	expect(city.overlays.current != null and city.overlays.current.scene_file_path.ends_with("shop.tscn"), "không mở được cửa hàng")
	city.overlays.current.close()
	await frames(3)

	var ending := await open_scene(game.ENDING_SCENE)
	expect(ending.find_children("*", "Button", true, false).size() >= 2, "màn kết: thiếu nút")
	print("smoke: đi bộ %d px, lái xe %d px" % [walked, driven])
	finish("SMOKE")


## Nhà nổi khối: mái ô nhà ở tâm camera không lệch; camera dời sang trái thì mái lệch sang phải (ra xa tâm).
## Vòng nhiệm vụ vẽ trên mái.
func _check_building_depth(city: Node) -> void:
	var depth: Node = city.map.get_node_or_null("BuildingDepth")
	expect(depth != null, "không có BuildingDepth")
	if depth == null:
		return
	var cell := _inner_building(city.data)
	var p := Vector2(cell) * TILE + Vector2.ONE * TILE * 0.5
	var camera: Node = city.camera
	var target: Node = camera.target
	camera.target = null
	camera.global_position = p
	await frames(3)
	var still := _roof_shift(depth, cell, p)
	expect(still.length() < 1.0, "mái nhà ở tâm camera vẫn lệch %s" % still)
	camera.global_position = p - Vector2(300, 0)
	await frames(3)
	var shift := _roof_shift(depth, cell, p)
	expect(shift.x > 5.0 and absf(shift.y) < 1.0, "camera bên trái mà mái không lệch sang phải: %s" % shift)
	camera.global_position = target.global_position  # trả camera về chỗ cũ, dân/xe sinh quanh khung hình
	camera.target = target
	# Rung màn hình đổi tâm camera mỗi frame: mái phải dùng tâm của chính frame đó, không trễ một frame.
	var roof: int = _roof_index(depth, cell)
	camera.add_trauma(100.0)
	for i in 6:
		await frames(1)
		var want: Vector2 = (p - camera.get_screen_center_position()) * depth._rise[roof]
		var got := _roof_shift(depth, cell, p)
		expect(got.distance_to(want) < 0.5, "mái trễ so với camera khi rung: lệch %s, đúng ra %s" % [got, want])
	# Đổi transform node TileMapLayer làm Godot cập nhật lại mọi ô (đo có cửa sổ: thêm ~3,5 ms/frame, headless không thấy),
	# nên lớp phải giữ transform node gốc và chỉ dịch qua RenderingServer.
	for layer in depth.get_children():
		expect(layer.transform == Transform2D.IDENTITY, "lớp %s bị đổi transform node (tốn CPU mỗi frame)" % layer.name)
	for m in get_nodes_in_group("markers"):
		expect(m.z_index > depth.z_index, "vòng nhiệm vụ bị mái che (z %d <= %d)" % [m.z_index, depth.z_index])
	var shadows: Node = city.map.get_node_or_null("Shadows")
	expect(shadows != null and shadows.get_cell_source_id(cell) != -1, "nhà không có bóng đổ")
	for tree in city.data.find_all("T"):
		if city.data.floor_of(tree) in [":", "."]:
			var coords: Vector2i = city.map.get_node("Props").get_cell_atlas_coords(tree)
			expect(coords == GREEN_BUSH, "bụi cam đứng trên nền gạch/đất ở %s" % tree)


func _roof_shift(depth: Node, cell: Vector2i, p: Vector2) -> Vector2:
	var i := _roof_index(depth, cell)
	return Vector2.INF if i < 0 else depth.view_transform(i) * p - p


## Thứ tự lớp mái chứa ô `cell` trong BuildingDepth (-1 nếu không có).
func _roof_index(depth: Node, cell: Vector2i) -> int:
	for layer in depth.get_children():
		if layer.name in ["Roof0", "Roof1"] and layer.get_cell_source_id(cell) != -1:
			return layer.get_index()
	return -1


## Một ô nhà cách biên map đủ xa để camera không bị limit_* chặn.
func _inner_building(data: Object) -> Vector2i:
	for cell in data.find_all("#"):
		if cell.x > 20 and cell.y > 20 and cell.x < data.size.x - 20 and cell.y < data.size.y - 20:
			return cell
	return Vector2i(-1, -1)


## Vật rơi (tiền/hộp máu) sinh ra ngay trong callback va chạm (xe tông chết tên băng đảng) không được gây lỗi
## "Can't change this state while flushing queries"; harness bắt lỗi engine nên chỉ cần tái hiện đúng tình huống.
func _check_drop_in_physics_callback(city: Node) -> void:
	var probe := Area2D.new()
	probe.collision_mask = city.player.collision_layer
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = TILE
	probe.add_child(shape)
	var pickup_script := load("res://scripts/actors/pickup.gd")
	var spawned := [0]
	probe.body_entered.connect(func(_body: Node) -> void:
		pickup_script.spawn_cash(city.effects, city.player.global_position, 1)
		spawned[0] += 1)
	probe.global_position = city.player.global_position + Vector2(0, TILE * 3)
	city.add_child(probe)
	await physics(3)
	probe.global_position = city.player.global_position
	await physics(5)
	expect(spawned[0] > 0, "không tái hiện được: callback va chạm không chạy")
	probe.queue_free()

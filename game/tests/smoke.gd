extends "res://tests/harness.gd"
## Smoke test: nạp menu, thành phố, cửa hàng, màn kết. Trong thành phố giả lập 600 frame vật lý:
## đi bộ, bắn, lên xe, lái, xuống xe. Bắt mọi lỗi engine/script. Assert HUD tồn tại, nhân vật trong bản đồ.
## Chạy: godot --headless --path game -s res://tests/smoke.gd

const WALK := 100
const SHOOT := 100
const DRIVE := 260
const BRAKE := 90
const SETTLE := 50  # tổng = 600 frame vật lý (chưa kể bước hồi quy xe nổ)


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

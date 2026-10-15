extends "res://tests/harness.gd"
## Truy nã 5 sao (đợt 8): HUD 5 sao; trực thăng tới, rọi đèn thấy người chơi, bắn rơi được; xe đặc nhiệm thả
## 3 lính súng trường; rào chắn chặn phía trước xe đang chạy, dải đinh làm thủng lốp; huy hiệu hối lộ giảm 1 sao.
## Chạy: godot --headless --path game -s res://tests/wanted.gd

const ROAD := Vector2i(30, 22)


func _run() -> void:
	var city := await open_city()
	city.population.set_process(false)
	game.set_stars(5)
	await frames(3)
	expect(game.stars == 5, "set_stars(5) mà còn %d sao" % game.stars)
	var hud: Node = get_first_node_in_group("hud")
	expect(hud._stars.size() == 5, "HUD có %d ô sao" % hud._stars.size())
	await _check_heli(city)
	await _check_swat(city)
	await _check_roadblock(city)
	await _check_badge(city)
	finish("WANTED")


func _check_heli(city: Node) -> void:
	game.health = 100000.0  # trực thăng bắn trong lúc chờ: không để chết
	var heli: Node = null
	for i in 600:
		await physics_frame
		heli = city.police.heli
		if is_instance_valid(heli) and heli.sees_player():
			break
	expect(is_instance_valid(heli), "5 sao mà không có trực thăng")
	if not is_instance_valid(heli):
		return
	expect(heli.sees_player() and city.police._seen(), "trực thăng tới mà không thấy người chơi")
	var cop: Node = get_nodes_in_group("cops")[0] if get_nodes_in_group("cops").size() > 0 else null
	if cop:
		heli.take_hit(9999.0, Vector2.RIGHT, cop)
		expect(heli.sees_player(), "đạn cảnh sát bắn rơi trực thăng của chính họ")
	var heat: float = game.heat
	heli.take_hit(9999.0, Vector2.RIGHT, city.player)
	await physics(5)
	expect(game.heat > heat or game.heat >= 760.0 - 0.1, "bắn rơi trực thăng mà nhiệt truy nã không tăng")
	expect(not heli.sees_player(), "trực thăng rơi rồi vẫn rọi thấy người chơi")
	await physics(240)
	expect(not is_instance_valid(heli), "xác trực thăng không biến mất")
	expect(not is_instance_valid(city.police.heli), "vừa bắn rơi đã có trực thăng mới")
	game.health = 100.0


func _check_swat(city: Node) -> void:
	for c in get_nodes_in_group("cops"):  # giới hạn tổng số cảnh sát: dọn chỗ trước
		c.queue_free()
	await frames(2)
	var van: Node = city.spawn_vehicle("swat", ROAD, 0.0)
	van.global_position = city.player.global_position + Vector2(200, 0)  # gần camera, kẻo Police dọn lính ở xa
	var is_swat := func(c: Node) -> bool: return c.skin == "robot1"
	var before: int = get_nodes_in_group("cops").filter(is_swat).size()
	city.police._deploy(van)
	await physics(3)
	var swat := get_nodes_in_group("cops").filter(is_swat)
	expect(swat.size() - before == 3, "xe đặc nhiệm thả %d lính (mong 3)" % (swat.size() - before))
	for s in swat:
		expect(s.gun.def.id == "rifle" and s.max_health > 100.0, "lính đặc nhiệm: súng %s, máu %d" % [s.gun.def.id, s.max_health])
	van.queue_free()


func _check_roadblock(city: Node) -> void:
	var v: Node = city.spawn_vehicle("car", ROAD, 0.0)
	city.player.global_position = v.global_position + Vector2(0, 60)
	await physics(2)
	city.player.enter_vehicle(v)
	city.camera.global_position = v.global_position
	await frames(2)
	var spot: Dictionary = city.police.roadblocks.find_spot(v.global_position, Vector2(400, 0))
	expect(not spot.is_empty(), "không tìm được chỗ lập rào chắn trên đường thẳng phía trước")
	if spot.is_empty():
		return
	expect(spot.center.x > v.global_position.x + 600.0 and absf(spot.center.y - v.global_position.y) < 64.0, "rào chắn không nằm phía trước trên cùng con đường: %s" % spot.center)
	for c in get_nodes_in_group("cops"):  # giới hạn tổng số cảnh sát: dọn chỗ trước
		c.queue_free()
	await frames(2)
	var cops_before: int = get_nodes_in_group("cops").size()
	city.police.roadblocks._build(spot)
	await physics(3)
	expect(get_nodes_in_group("cops").size() - cops_before == 2, "rào chắn không có 2 cảnh sát")
	var strips: Array = city.effects.get_children().filter(func(n: Node) -> bool: return n is Area2D and n.has_signal("body_entered") and n.get_script() and n.get_script().resource_path.ends_with("spike_strip.gd"))
	expect(strips.size() == 1, "rào chắn không có dải đinh")
	if strips.size() == 1:
		v.global_position = strips[0].global_position - Vector2(120, 0)
		v.velocity = Vector2(300, 0)
		await physics(40)
		expect(v.flat, "chạy qua dải đinh mà không thủng lốp")
	city.player.exit_vehicle()
	city.police.roadblocks.clear_all()


func _check_badge(city: Node) -> void:
	game.clear_wanted()
	await physics(3)
	var badge: Vector2 = (Vector2(city.data.find("W")) + Vector2(0.5, 0.5)) * 64.0
	city.player.global_position = badge
	await physics(10)
	expect(game.stars == 0, "không bị truy nã mà vẫn nhặt được huy hiệu")
	city.player.global_position = badge + Vector2(200, 0)
	game.set_stars(3)
	await physics(5)
	city.player.global_position = badge
	await physics(10)
	expect(game.stars == 2, "nhặt huy hiệu hối lộ: còn %d sao (mong 2)" % game.stars)

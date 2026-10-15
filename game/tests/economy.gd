extends "res://tests/harness.gd"
## Kinh tế và tiến trình (đợt 8): mua nhà an toàn, nghỉ/thuê đàn em (đi theo, ngồi cùng xe), cất xe vào gara (còn
## sau khi vào lại), mua cơ sở kinh doanh (nửa đêm trả tiền), tủ đồ (trang phục cuối khoá tới khi xong cốt truyện),
## thành tựu, màn thống kê. Chạy: godot --headless --path game -s res://tests/economy.gd


func _run() -> void:
	watchdog_sec = 120.0
	var city := await open_city()
	await close_overlays(city)
	game.settings.tutorial = false
	city.population.set_process(false)
	game.money = 50000
	var props: Node = city.properties
	var p: Node = city.player
	p.global_position = props.safehouses[0]
	await physics(3)
	expect(city.interactions.prompt == "HINT_BUY_SAFEHOUSE", "đứng ở cửa nhà an toàn mà không có gợi ý mua (%s)" % city.interactions.prompt)
	await tap(&"interact")
	expect(props.owns("safehouses", 0) and game.money == 50000 - 3000, "mua nhà an toàn: sở hữu %s, tiền %d" % [props.owns("safehouses", 0), game.money])
	await physics(3)
	expect(city.interactions.prompt == "HINT_SAFEHOUSE", "nhà đã mua mà không có gợi ý vào nhà (%s)" % city.interactions.prompt)
	await tap(&"interact")
	await frames(3)
	expect(city.overlays.current != null and city.overlays.current.get_script().resource_path.ends_with("safehouse_menu.gd"), "không mở menu nhà an toàn")
	city.overlays.current.close("hire")
	await frames(3)
	var allies := get_nodes_in_group("allies")
	expect(allies.size() == 1 and game.money == 47000 - 500, "thuê đàn em: %d người, tiền %d" % [allies.size(), game.money])
	if allies.size() == 1:
		await _check_ally(city, allies[0])
	await _check_garage(city)
	city = current_scene
	await _check_business(city)
	await _check_wardrobe(city)
	await _check_achievements(city)
	finish("ECONOMY")


func _check_ally(city: Node, ally: Node) -> void:
	var p: Node = city.player
	p.global_position += Vector2(0, 260)
	await physics(150)
	expect(ally.global_position.distance_to(p.global_position) < 220.0, "đàn em không đi theo (cách %.0f px)" % ally.global_position.distance_to(p.global_position))
	var car: Node = city.spawn_vehicle("car", Vector2i(p.global_position / 64.0), 0.0)
	car.global_position = p.global_position + Vector2(0, 60)
	await physics(2)
	p.enter_vehicle(car)
	await physics(3)
	expect(not ally.visible, "Jay lên xe mà đàn em vẫn đứng ngoài")
	p.exit_vehicle()
	await physics(3)
	expect(ally.visible and ally.global_position.distance_to(p.global_position) < 120.0, "Jay xuống xe mà đàn em không xuất hiện lại")
	car.queue_free()


func _check_garage(city: Node) -> void:
	var props: Node = city.properties
	var car: Node = city.spawn_vehicle("super", Vector2i(props.safehouses[0] / 64.0), 0.0, "car_green_5")
	car.global_position = props.safehouses[0] + Vector2(0, 90)
	city.player.global_position = car.global_position + Vector2(60, 0)
	await physics(2)
	city.player.enter_vehicle(car)
	await physics(3)
	expect(city.interactions.prompt == "HINT_STORE_CAR", "lái xe tới nhà an toàn mà không có gợi ý cất xe (%s)" % city.interactions.prompt)
	await tap(&"interact")
	expect(city.player.vehicle == null and game.stats.get("garage_0", {}).get("sprite", "") == "car_green_5", "cất xe vào gara không được")
	var again := await open_city()
	await close_overlays(again)
	var found := get_nodes_in_group("vehicles").filter(func(v: Node) -> bool: return v.sprite_name == "car_green_5" and v.global_position.distance_to(again.properties.safehouses[0]) < 400.0)
	expect(found.size() == 1, "vào lại thành phố mà xe trong gara không còn (%d)" % found.size())
	if found.size() == 1:
		again.player.enter_vehicle(found[0])
		again.interactions._sell(found[0])
		await frames(2)
		expect(not game.stats.has("garage_0"), "bán xe lấy từ gara mà gara vẫn giữ xe (nhân bản tiền)")
		game.stats["garage_0"] = {"kind": "super", "sprite": "car_green_5"}


func _check_business(city: Node) -> void:
	city.population.set_process(false)
	var props: Node = city.properties
	city.player.global_position = props.businesses[0]
	await physics(3)
	expect(city.interactions.prompt == "HINT_BUY_BUSINESS", "đứng ở cửa cơ sở kinh doanh mà không có gợi ý mua (%s)" % city.interactions.prompt)
	var before: int = game.money
	await tap(&"interact")
	expect(props.owns("businesses", 0) and game.money == before - 4000, "mua cơ sở kinh doanh không được")
	game.clock = 23.995
	await physics(30)
	expect(game.money == before - 4000 + 400, "qua nửa đêm mà không có thu nhập (tiền %d)" % game.money)


func _check_wardrobe(city: Node) -> void:
	game.set_skin("robot1")
	await frames(2)
	expect(city.player.skin == "robot1" and game.skin == "robot1", "thay trang phục không được")
	expect(not game.skin_unlocked("zombie1"), "trang phục cuối mở trước khi xong cốt truyện")
	city.overlays.open(load("res://scripts/ui/wardrobe.gd").new())
	await frames(3)
	expect(city.overlays.current != null, "không mở được tủ đồ")
	city.overlays.current.close()
	await frames(3)


func _check_achievements(city: Node) -> void:
	game.bump("kills")
	await physics(80)
	expect(game.marked("achievements").has("first_blood"), "hạ người đầu tiên mà không có thành tựu")
	city.overlays.open(load("res://scripts/ui/stats_panel.gd").new())
	await frames(3)
	expect(city.overlays.current != null, "không mở được màn thống kê")
	city.overlays.current.close()
	await frames(3)
	expect(game.stat("play_s") > 0 and game.stat("walk_px") >= 0, "thống kê thời gian chơi không chạy")

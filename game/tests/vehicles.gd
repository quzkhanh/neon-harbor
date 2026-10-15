extends "res://tests/harness.gd"
## Xe (đợt 8): mọi loại xe sinh được, xe nhỏ nhỏ hơn xe thường; nitro vượt tốc tối đa rồi cạn bình và nạp lại;
## lốp thủng thì chậm hẳn, tiệm sửa xe vá lại; giá bán theo dữ liệu; còi làm người đi đường tránh.
## Chạy: godot --headless --path game -s res://tests/vehicles.gd

const ROAD := Vector2i(30, 22)  # hàng 22 là làn hướng phải chạy suốt bề ngang thành phố
const RUN := 150


func _run() -> void:
	var city := await open_city()
	city.population.set_process(false)  # dòng xe sinh thêm có thể chắn làn thử nitro
	game.settings.steering = "classic"
	_check_kinds(city)
	await _check_nitro(city)
	await _check_flat_and_repair(city)
	await _check_horn(city)
	game.settings.steering = "screen"
	finish("VEHICLES")


func _check_kinds(city: Node) -> void:
	var sizes := {}
	for kind in ["moto", "compact", "car", "pickup", "taxi", "sports", "super", "police", "swat"]:
		var v: Node = city.spawn_vehicle(kind, ROAD + Vector2i(0, 40), 0.0)
		sizes[kind] = v.size
		expect(v.hp > 0.0 and v.body.texture != null, "xe %s không có sprite/máu" % kind)
		expect(city.interactions.sell_price(v) == int(v.spec.sell), "giá bán %s sai" % kind)
		v.queue_free()
	expect(sizes.compact.x < sizes.car.x * 0.85, "xe nhỏ không nhỏ hơn xe thường (%s vs %s)" % [sizes.compact, sizes.car])
	var kinds := {}
	for i in 400:
		var k: String = load("res://scripts/core/data_db.gd").traffic_kind()
		kinds[k] = kinds.get(k, 0) + 1
	expect(not kinds.has("police") and not kinds.has("swat"), "dòng xe có xe cảnh sát: %s" % kinds)
	expect(kinds.get("car", 0) > kinds.get("super", 0), "siêu xe không hiếm hơn xe thường: %s" % kinds)


## Lái thẳng trên làn dài: có nitro thì vượt tốc tối đa; giữ tới cạn thì tắt và nạp lại dần.
func _check_nitro(city: Node) -> void:
	var v := await _drive_car(city)
	Input.action_press(&"accelerate")
	await physics(RUN)
	var plain: float = v.forward_speed()
	Input.action_press(&"nitro")
	var top := 0.0
	var emptied := false
	for i in 200:
		await physics_frame
		top = maxf(top, v.forward_speed())
		emptied = emptied or v.nitro.fuel <= 0.0
	Input.action_release(&"nitro")
	Input.action_release(&"accelerate")
	var max_speed := float(v.spec.max_speed)
	expect(plain <= max_speed + 1.0, "không nitro mà vượt tốc tối đa (%.0f > %.0f)" % [plain, max_speed])
	expect(top > max_speed * 1.15, "nitro không tăng tốc (đỉnh %.0f, tối đa %.0f)" % [top, max_speed])
	expect(emptied and not v.nitro.active, "giữ nitro hơn 3 giây mà bình chưa cạn (%.2f)" % v.nitro.fuel)
	await physics(120)
	expect(v.nitro.fuel > 0.2, "nitro không nạp lại (%.2f)" % v.nitro.fuel)
	city.player.exit_vehicle()


## Thủng lốp: chạy chậm hẳn; tiệm sửa xe (không có sao) vẫn nhận sửa: đầy máu, vá lốp, mất tiền.
func _check_flat_and_repair(city: Node) -> void:
	var v := await _drive_car(city)
	v.pop_tires()
	Input.action_press(&"accelerate")
	await physics(RUN * 2)
	Input.action_release(&"accelerate")
	expect(v.flat and v.forward_speed() < float(v.spec.max_speed) * 0.7, "thủng lốp mà vẫn chạy %.0f" % v.forward_speed())
	v.hp = 20.0
	v.velocity = Vector2.ZERO
	var shop: Vector2 = city.interactions._resprays[0]
	v.global_position = shop
	game.clear_wanted()
	game.money = 1000
	await physics(5)
	expect(city.interactions.prompt == "HINT_RESPRAY", "xe hỏng ở tiệm sửa mà không có gợi ý sửa (%s)" % city.interactions.prompt)
	await tap(&"interact")
	expect(not v.flat and v.hp >= float(v.spec.hp), "sửa xe: lốp/máu chưa hồi (lốp thủng %s, máu %.0f)" % [v.flat, v.hp])
	expect(game.money == 1000 - 250, "sửa xe: tiền sai (%d)" % game.money)
	await physics(5)
	expect(city.interactions.prompt != "HINT_RESPRAY", "xe lành, không sao mà vẫn gợi ý sửa")
	city.player.exit_vehicle()


func _check_horn(city: Node) -> void:
	var v := await _drive_car(city)
	var ped: Node = city.spawn_npc(load("res://scripts/actors/pedestrian.gd"), v.global_position + Vector2(150, 0))
	ped.add_to_group("peds")
	await physics(2)
	await tap(&"horn")
	await physics(2)
	expect(ped._flee_time > 0.0, "bấm còi mà người phía trước không tránh")
	ped.queue_free()
	city.player.exit_vehicle()


func _drive_car(city: Node) -> Node:
	for car in get_nodes_in_group("vehicles"):
		if not car.is_player_driven():
			car.queue_free()
	var v: Node = city.spawn_vehicle("car", ROAD, 0.0)
	city.player.global_position = v.global_position + Vector2(0, 60)
	await physics(3)
	city.player.enter_vehicle(v)
	await physics(3)
	return v

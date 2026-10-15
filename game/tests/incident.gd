extends "res://tests/harness.gd"
## Sự cố giao thông (đợt 11): hai xe đâm nhau, tài xế xuống xe cãi nhau (có khi đánh nhau), làm lành rồi lên xe đi tiếp;
## xe phía sau dồn lại chờ; đánh vào tài xế thì thôi kịch bản. Chạy: godot --headless --path game -s res://tests/incident.gd


func _run() -> void:
	var city := await open_city()
	city.population.set_process(false)
	var spawner: Node = city.get_node("RoadIncidents")
	spawner.set_process(false)
	var cell := _straight_cell(spawner)
	city.player.global_position = Vector2(cell) * 64.0 + Vector2(0, 700)
	spawner._stage(cell)
	var incident: Node = spawner._active
	var cars: Array = incident.cars.duplicate()
	expect(cars.size() == 2 and cars[0].hazard and cars[1].hazard, "hai xe không bật đèn cảnh báo")
	expect(cars[0].autopilot == null and cars[1].autopilot == null, "xe đâm nhau mà vẫn tự chạy")
	await physics(60 * 3)
	expect(incident._peds.size() == 2 and incident._peds[0] != null, "tài xế không xuống xe")
	expect(incident._phase >= 1, "vụ va chạm không chuyển sang cãi nhau")
	var spoke := false
	for i in 60 * 12:
		await physics(1)
		spoke = spoke or incident._peds[0] != null and incident._peds[0].get_node_or_null("Speech") != null
		if not is_instance_valid(incident):
			break
	expect(spoke, "hai tài xế không nói câu nào")
	await physics(60 * 40)
	expect(not is_instance_valid(incident), "vụ va chạm không kết thúc sau 50 giây")
	expect(cars[0].autopilot != null and cars[1].autopilot != null, "xong vụ mà xe không chạy tiếp (%s, %s)" % [cars[0].autopilot, cars[1].autopilot])
	expect(not cars[0].hazard and not cars[1].hazard, "xong vụ mà đèn cảnh báo vẫn nháy")
	var peds_left := root.get_tree().get_nodes_in_group("peds").filter(func(p: Node) -> bool: return p.scripted).size()
	expect(peds_left == 0, "còn %d người kẹt trong kịch bản" % peds_left)
	await _aborted_case(city, spawner)
	finish("INCIDENT")


## Đánh vào tài xế giữa chừng: kịch bản dừng, hai người thành người đi đường thường.
func _aborted_case(city: Node, spawner: Node) -> void:
	var cell := _straight_cell(spawner, 40)
	spawner._stage(cell)
	var incident: Node = spawner._active
	await physics(60 * 3)
	var ped: Node = incident._peds[0]
	ped.take_hit(1.0, Vector2.RIGHT, city.player)
	await physics(5)
	expect(not is_instance_valid(incident), "đánh tài xế mà vụ va chạm vẫn chạy")
	expect(not ped.scripted, "tài xế bị đánh vẫn ở trong kịch bản")


func _straight_cell(spawner: Node, skip := 0) -> Vector2i:
	var n := 0
	for cell in spawner._lanes:
		if spawner._straight(cell):
			if n >= skip:
				return cell
			n += 1
	return Vector2i.ZERO


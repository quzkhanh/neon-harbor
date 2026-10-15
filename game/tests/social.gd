extends "res://tests/harness.gd"
## Tương tác với NPC (đợt 10): bị chĩa súng (ngắm có chủ đích) thì giơ tay rồi đánh rơi ví (người thấy báo cảnh sát), người có súng thì
## bắn lại; người máu nóng bị đấm thì đấm trả, người khác sợ hãi bỏ chạy; bắt chuyện (phím tương tác) ra câu thoại;
## việc vặt tìm đồ đánh rơi (trả đồ được tiền, người nhờ chết là thất bại); Red Fangs chọc ghẹo trước khi bắn;
## Lucky Live (streamer ở góc phố): lên sóng khi Jay tới gần, bắt chuyện, việc lấy lại điện thoại, chết thì có lại.
## Chạy: godot --headless --path game -s res://tests/social.gd


func _run() -> void:
	var city := await open_city()
	await close_overlays(city)
	city.population.set_process(false)
	for p in get_nodes_in_group("peds"):
		p.queue_free()
	await physics(2)
	await _check_holdup(city)
	await _check_brawl(city)
	await _check_talk(city)
	await _check_errand(city)
	await _check_taunt(city)
	await _check_lucky(city)
	finish("SOCIAL")


func _ped(city: Node, offset: Vector2, armed := false, brawler := false) -> Node:
	var ped: Node = city.spawn_npc(load("res://scripts/actors/pedestrian.gd"), city.player.global_position + offset)
	ped.add_to_group("peds")
	ped.armed = armed
	if armed:
		ped.gun = load("res://scripts/combat/gun.gd").new(load("res://scripts/core/data_db.gd").weapon("pistol"))
	else:
		ped.gun = null
	ped.brawler = brawler
	return ped


func _bubble(who: Node, node_name: String) -> bool:
	return who.get_node_or_null(node_name) != null


func _pickups(city: Node) -> Array:
	return city.effects.get_children().filter(func(c: Node) -> bool: return c.get_script() and c.get_script().resource_path.ends_with("pickup.gd"))


func _clear(city: Node, nodes: Array) -> void:
	for n in nodes + _pickups(city):
		if is_instance_valid(n):
			n.queue_free()
	game.clear_wanted()
	game.health = 100.0
	await physics(2)


func _check_holdup(city: Node) -> void:
	var p: Node = city.player
	game.select_weapon("pistol")
	var victim := _ped(city, Vector2(150, 0))
	var witness := _ped(city, Vector2(0, -160))
	witness.set_physics_process(false)  # đứng yên: tự đi lang thang có thể khuất sau toà nhà ngay cạnh
	await physics(30)
	expect(victim.pose == "stand" and victim._flee_time <= 0.0, "cầm súng đứng yên (không ngắm) mà người phía trước đã giơ tay")
	victim.global_position = p.global_position + Vector2(150, 0)  # người này tự đi lang thang trong lúc chờ
	Input.action_press(&"aim_right")
	await physics(30)
	expect(victim.pose == "hold" and victim.velocity.length() < 1.0, "bị chĩa súng mà không đứng im giơ tay (%s)" % victim.pose)
	expect(_bubble(victim, "Emote"), "bị chĩa súng mà không có bong bóng giật mình")
	var money: int = game.money
	await physics(80)
	var wallets := _pickups(city).filter(func(c: Node) -> bool: return c.global_position.distance_to(p.global_position) < 200.0)
	expect(wallets.size() > 0, "chĩa súng đủ lâu mà không rơi ví")
	expect(victim._flee_time > 0.0 and victim.pose == "stand", "rơi ví xong mà không hạ tay bỏ chạy")
	expect(witness._report > 0.0, "người đứng cạnh thấy trấn lột mà không báo cảnh sát")
	if wallets.size() > 0:
		p.global_position = wallets[0].global_position
		await physics(5)
		expect(game.money > money, "nhặt ví mà không được tiền")
	Input.action_release(&"aim_right")
	var gunman := _ped(city, Vector2(-150, 0), true)
	Input.action_press(&"aim_left")
	await physics(5)
	Input.action_release(&"aim_left")
	expect(gunman._angry > 0.0, "người có súng bị chĩa súng mà không rút súng ra")
	await _clear(city, [victim, witness, gunman])


func _check_brawl(city: Node) -> void:
	var p: Node = city.player
	game.select_weapon("fists")
	var ex: Array[RID] = [p.get_rid()]
	var fighter := _ped(city, Vector2(40, 0), false, true)
	var coward := _ped(city, Vector2(-40, 0))
	await physics(2)
	p.gun.cooldown = 0.0
	p.gun.try_fire(p, p.muzzle_position(), 0.0, ex)
	p.gun.cooldown = 0.0
	p.gun.try_fire(p, p.muzzle_position(), PI, ex)
	await physics(2)
	expect(fighter._angry > 0.0 and fighter.gun != null and fighter.gun.def.kind == "melee", "người máu nóng bị đấm mà không đấm lại")
	expect(_bubble(fighter, "Speech"), "người đấm lại mà không buông câu nào")
	expect(coward._flee_time > 0.0 and coward._angry <= 0.0, "người nhát bị đấm mà không bỏ chạy")
	expect(_bubble(coward, "Emote"), "người nhát bị đấm mà không có bong bóng sợ")
	p.set_physics_process(false)
	var health: float = game.health
	for i in 240:
		await physics_frame
		if game.health < health:
			break
	p.set_physics_process(true)
	expect(game.health < health, "người máu nóng không đấm trúng Jay")
	await _clear(city, [fighter, coward])


func _check_talk(city: Node) -> void:
	var p: Node = city.player
	game.select_weapon("fists")
	var ped := _ped(city, Vector2(30, 0))
	await physics(3)
	expect(city.interactions.prompt == "HINT_TALK", "đứng cạnh người đi đường mà không có gợi ý bắt chuyện (%s)" % city.interactions.prompt)
	await tap(&"interact")
	await physics(2)
	expect(_bubble(ped, "Speech"), "bắt chuyện mà người đi đường không nói gì")
	expect(ped._chat > 0.0 and ped.velocity.length() < 1.0, "bắt chuyện mà người đi đường vẫn đi tiếp")
	if city.activities.current:
		city.activities._end(city.activities.current)
	await _clear(city, [ped])
	expect(p.alive, "Jay chết trong lúc test bắt chuyện")


func _check_errand(city: Node) -> void:
	var p: Node = city.player
	var home: Vector2 = p.global_position
	var asker := _ped(city, Vector2(30, 0))
	await physics(2)
	city.activities.start("errand", 0, asker)
	await physics(3)
	var job: Node = city.activities.current
	expect(job != null and asker.waiting and not asker.is_in_group("peds"), "nhận việc vặt mà người nhờ không đứng chờ")
	var item: Node = job._spawned[0] if job else null
	expect(is_instance_valid(item), "việc vặt không có món đồ để tìm")
	if is_instance_valid(item):
		p.global_position = item.global_position
		await physics(5)
		expect(job._found, "tới chỗ món đồ mà không nhặt được")
	var money: int = game.money
	p.global_position = asker.global_position + Vector2(0, 30)
	await physics(5)
	expect(city.activities.current == null and game.money > money, "mang đồ về trả mà không được tiền / việc chưa xong")
	expect(asker.is_in_group("peds") and not asker.waiting, "xong việc vặt mà người nhờ vẫn đứng chờ")
	p.global_position = home
	# Người nhờ chết: thất bại.
	city.activities.start("errand", 0, asker)
	await physics(2)
	asker.take_hit(500.0, Vector2.RIGHT, null)
	await physics(3)
	expect(city.activities.current == null and asker.is_in_group("peds"), "người nhờ chết mà việc vặt chưa thất bại")
	await _clear(city, [asker])


func _check_taunt(city: Node) -> void:
	var gang: Node = city.spawn_npc(load("res://scripts/actors/gangster.gd"), city.player.global_position + Vector2(200, 0))
	await physics(3)
	expect(gang.alerted and _bubble(gang, "Speech"), "Red Fangs thấy Jay mà không chọc ghẹo")
	expect(gang._react > 0.6, "Red Fangs chọc ghẹo mà bắn luôn, không dừng lại")
	await _clear(city, [gang])


func _check_lucky(city: Node) -> void:
	var p: Node = city.player
	var spot: Node = city.streamer
	var lucky: Node = spot.lucky
	var home: Vector2 = p.global_position
	expect(is_instance_valid(lucky) and lucky.alive and city.data.is_ped_walkable(spot.CELL), "không có Lucky ở góc phố")
	p.global_position = lucky.global_position + Vector2(0, 40)
	await physics(3)
	expect(city.interactions.prompt == "HINT_TALK", "đứng cạnh Lucky mà không có gợi ý bắt chuyện (%s)" % city.interactions.prompt)
	lucky._next_line = 0.0
	await physics(2)
	expect(_bubble(lucky, "Speech"), "Jay ở gần mà Lucky không nói gì trên sóng")
	# Việc vặt: quật ngã tên trộm, mang điện thoại về.
	p.global_position = home
	city.activities.start("phone")
	await physics(2)
	var job: Node = city.activities.current
	var thief: Node = job.thief if job else null
	expect(is_instance_valid(thief) and thief.heat_on_hit == 0.0, "không có tên trộm / đánh tên trộm vẫn bị truy nã")
	await physics(30)
	expect(is_instance_valid(thief) and thief._flee_time > 0.0, "tên trộm không bỏ chạy")
	if is_instance_valid(thief):
		thief.knock_down(Vector2.RIGHT * 100.0, 5.0, p)
	await physics(2)
	expect(job._found and game.heat == 0.0, "quật ngã tên trộm mà không lấy lại được điện thoại / bị tính phạm tội")
	var money: int = game.money
	p.global_position = lucky.global_position + Vector2(0, 40)
	await physics(3)
	expect(city.activities.current == null and game.money > money, "mang điện thoại về trả Lucky mà không được tiền")
	# Tên trộm chạy thoát: thất bại.
	city.activities.start("phone")
	await physics(2)
	city.activities.current.thief.global_position = p.global_position + Vector2(1500, 0)
	await physics(2)
	expect(city.activities.current == null, "tên trộm chạy thoát mà việc chưa thất bại")
	await _clear(city, [thief])
	# Lucky chết: khi góc phố khuất màn hình thì có Lucky mới.
	lucky.take_hit(500.0, Vector2.RIGHT, null)
	spot._respawn = 0.0
	p.global_position = home + Vector2(2000, 0)
	city.camera.global_position = p.global_position
	await physics(30)
	expect(is_instance_valid(spot.lucky) and spot.lucky != lucky and spot.lucky.alive, "Lucky chết mà không có lại")
	p.global_position = home
	game.clear_wanted()

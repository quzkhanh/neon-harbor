class_name ShotScenes
extends RefCounted
## Tình huống chụp ảnh của đợt mở rộng (Shot gọi sang để shot.gd không phình ra).

const NAMES := ["nitro", "wanted5", "roadblock", "race", "noon", "dusk", "rain", "wheel", "stats", "safehouse", "wardrobe", "boat", "zombies", "death_home", "melee", "bat_idle", "holdup", "talk", "taunt", "chatter", "critters", "quirks", "incident", "night_life", "lucky"]


static func run(scene_name: String, city: City, shot: Node) -> void:
	match scene_name:
		"nitro":
			await _nitro(city, shot)
		"wanted5":
			await _wanted5(city, shot)
		"roadblock":
			await _roadblock(city, shot)
		"race":
			await _race(city, shot)
		"wheel":
			for id in ["smg", "shotgun", "rifle", "grenade", "bat"]:
				Game.grant_weapon(id)
			Game.select_weapon("pistol")
			var e := InputEventAction.new()  # action_press không sinh event cho _unhandled_input
			e.action = &"weapon_next"
			e.pressed = true
			Input.parse_input_event(e)
			await shot._frames(40)
		"stats":
			Game.missions_done = [1, 2, 3, 4]
			for id in ["first_blood", "five_stars", "courier"]:
				Game.mark("achievements", id)
			Game.stats.merge({"kills": 37, "walk_px": 52000, "drive_px": 410000, "max_stars": 5, "play_s": 5400, "races_won": 2, "fares": 6})
			city.overlays.open(StatsPanel.new())
			await shot._frames(10)
		"safehouse":
			Game.mark("safehouses", "0")
			city.player.global_position = city.properties.safehouses[0]
			await shot._frames(5)
			city.properties._open_safehouse()
			await shot._frames(10)
		"wardrobe":
			city.overlays.open(Wardrobe.new())
			await shot._frames(10)
		"boat":
			var b: Array = DataDB.extras().boats[1]
			var boat: Vehicle = null
			for v in city.get_tree().get_nodes_in_group("vehicles"):
				if v.kind == "boat" and (boat == null or v.global_position.distance_to(MapData.cell_center(Vector2i(int(b[0]), int(b[1])))) < 10.0):
					boat = v
			city.player.global_position = boat.global_position + Vector2(-70, 0)
			city.camera.global_position = boat.global_position
			await shot._frames(5)
			city.player.enter_vehicle(boat)
			await shot._hold([&"move_down"], 50, false)
		"zombies":
			Game.clock = 1.0
			Game.zombies = true
			for i in 6:
				var z := city.spawn_npc(Pedestrian, city.player.global_position + Vector2.from_angle(i * 1.1) * randf_range(160, 300))
				z.add_to_group("peds")
			await shot._frames(60)
		"death_home":
			Game.mark("safehouses", "0")
			city.missions.start(1, false)
			await shot._frames(5)
			city.player.take_hit(500.0, Vector2.RIGHT, null)
			while city.overlays.current == null:
				await shot._frames(1)
			await shot._frames(10)
		"lucky":
			var lucky := city.streamer.lucky
			city.player.global_position = lucky.global_position + Vector2(70, 30)
			await shot._frames(30)
			lucky.say("LUCKY_LIVE_2")
			await shot._frames(10)
		"melee", "bat_idle", "holdup", "talk", "taunt", "chatter", "critters", "quirks", "incident", "night_life":
			await _social(scene_name, city, shot)
		"noon", "dusk", "rain":
			Game.clock = {"noon": 12.0, "dusk": 18.6, "rain": 22.0}[scene_name]
			if scene_name == "rain":
				await shot._frames(3)  # để Weather thấy giờ mới trước, kẻo lần tung xúc xắc đầu giờ tắt mưa
				city.get_node("Weather").set_raining(true)
			await shot._hold([&"move_up"], 400 if scene_name == "rain" else 60)


static func _nitro(city: City, shot: Node) -> void:
	var v := city.spawn_vehicle("super", Vector2i(60, 22), 0.0, "car_yellow_5")
	city.player.global_position = v.global_position + Vector2(0, 50)
	await shot._frames(5)
	city.player.enter_vehicle(v)
	await shot._hold([&"move_right"], 60, false)
	await shot._hold([&"nitro"], 30, false)


static func _wanted5(city: City, shot: Node) -> void:
	Game.health = 100000.0
	Game.set_stars(5)
	await shot._frames(420)
	Game.health = 80.0
	Game.vitals_changed.emit()


static func _roadblock(city: City, shot: Node) -> void:
	Game.set_stars(4)
	var v := city.spawn_vehicle("car", Vector2i(30, 22), 0.0, "car_blue_1")
	city.player.global_position = v.global_position + Vector2(0, 50)
	await shot._frames(5)
	city.player.enter_vehicle(v)
	await shot._frames(5)
	var spot := city.police.roadblocks.find_spot(v.global_position, Vector2(400, 0))
	city.police.roadblocks._build(spot)
	v.global_position = spot.center - spot.along * Tuning.TILE * 7.0 + Vector2(0, Tuning.TILE * 0.5)
	city.camera.global_position = v.global_position
	await shot._hold([&"move_right"], 30, false)


static func _race(city: City, shot: Node) -> void:
	var q := MapData.cell_center(city.data.find("Q"))
	var v := city.spawn_vehicle("sports", MapData.world_to_cell(q), 0.0)
	city.player.global_position = q + Vector2(0, 60)
	await shot._frames(5)
	city.player.enter_vehicle(v)
	city.activities.start("race", city.activities._race_index(q))
	await shot._frames(175)
	await shot._hold([&"move_right"], 50, false)


## Cận chiến (vệt chém + sao tóe), bị chĩa súng (giơ tay), bắt chuyện, Red Fangs chọc ghẹo.
static func _social(scene_name: String, city: City, shot: Node) -> void:
	var p := city.player
	city.population.set_process(false)
	for n in city.get_tree().get_nodes_in_group("peds"):
		n.queue_free()
	p.aim_angle = 0.0
	if scene_name == "taunt":
		city.spawn_npc(Gangster, p.global_position + Vector2(170, -20))
		await shot._frames(20)
		return
	if scene_name == "critters":
		var x := 200.0
		for kind in ["pigeon", "cat", "dog", "crab", "gull"]:
			var c := Critter.new()
			c.kind = kind
			c.city = city
			c.global_position = p.global_position + Vector2(x, -40.0 if kind == "gull" else 30.0)
			city.actors.add_child(c)
			x += 85.0
		await shot._frames(60)
		return
	if scene_name == "incident":
		var spawner: RoadIncidents = city.get_node("RoadIncidents")
		spawner.set_process(false)
		var best := Vector2i.ZERO
		for cell in spawner._lanes:
			if spawner._straight(cell) and (best == Vector2i.ZERO or MapData.cell_center(cell).distance_to(p.global_position) < MapData.cell_center(best).distance_to(p.global_position)):
				best = cell
		for v in city.get_tree().get_nodes_in_group("vehicles"):
			if v.global_position.distance_to(MapData.cell_center(best)) < 400.0:
				v.queue_free()
		city.population.set_process(false)
		spawner._stage(best)
		p.global_position = spawner._active.cars[0].global_position + Vector2(0, 140)
		await shot._frames(60 * 4)
		return
	if scene_name == "night_life":
		Game.clock = 23.5
		var x := 100.0
		for q in ["drunk", "nightshift", "loiter"]:
			var ped := city.spawn_npc(Pedestrian, p.global_position + Vector2(x, -20.0 if q == "loiter" else 25.0))
			ped.add_to_group("peds")
			ped.quirk = q
			ped.skin = Pedestrian.QUIRK_SKINS.get(q, ped.skin)
			ped.set_pose("stand")
			ped._next_quirk_line = 0.5
			x += 90.0
		await shot._frames(120)
		return
	if scene_name == "quirks":
		for q in [["robot1", "robot", 150.0], ["manOld", "feeder", 330.0]]:
			var ped := city.spawn_npc(Pedestrian, p.global_position + Vector2(q[2], 0))
			ped.add_to_group("peds")
			ped.skin = q[0]
			ped.set_pose("stand")
			ped.quirk = q[1]
			if q[1] == "feeder":
				ped.add_to_group("feeders")
				for i in 5:
					var c := Critter.new()
					c.kind = "pigeon"
					c.city = city
					c.global_position = ped.global_position + Vector2.from_angle(i * 1.3) * 70.0
					city.actors.add_child(c)
			else:
				Speech.say(ped, Speech.pick("PED_ROBOT"))
		await shot._frames(150)
		return
	if scene_name == "chatter":
		var a := city.spawn_npc(Pedestrian, p.global_position + Vector2(110, -20))
		var b := city.spawn_npc(Pedestrian, p.global_position + Vector2(160, 10))
		a.add_to_group("peds")
		b.add_to_group("peds")
		city.get_node("PedChatter")._talk(a, b)
		await shot._frames(175)
		return
	var ped := city.spawn_npc(Pedestrian, p.global_position + Vector2(44 if scene_name == "melee" else 120, 0))
	ped.add_to_group("peds")
	ped.armed = false
	ped.gun = null
	match scene_name:
		"melee":
			Game.grant_weapon("bat")
			Game.select_weapon("bat")
			await shot._frames(5)
			p.gun.cooldown = 0.0
			p.gun.try_fire(p, p.muzzle_position(), 0.0, [p.get_rid()])
			await shot._frames(3)
		"bat_idle":
			Game.grant_weapon("bat")
			Game.select_weapon("bat")
			await shot._frames(5)
		"holdup":
			Game.select_weapon("pistol")
			Input.action_press(&"aim_right")
			await shot._frames(40)
		"talk":
			Game.select_weapon("fists")
			ped.global_position = p.global_position + Vector2(36, 0)
			await shot._frames(3)
			ped.chat()
			Speech.say(ped, "PED_TIP_RESPRAY")
			await shot._frames(10)

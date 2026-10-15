class_name ShotScenes
extends RefCounted
## Tình huống chụp ảnh của đợt mở rộng (Shot gọi sang để shot.gd không phình ra).

const NAMES := ["nitro", "wanted5", "roadblock", "race", "noon", "dusk", "rain", "wheel", "stats", "safehouse", "wardrobe", "boat", "zombies"]


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
	await shot._frames(200)
	await shot._hold([&"move_right"], 50, false)

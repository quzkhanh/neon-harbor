class_name City
extends Node2D
## Cảnh thành phố: dựng bản đồ, người chơi, camera, xe đậu sẵn, các hệ thống (dân, cảnh sát,
## nhiệm vụ, tương tác) và giao diện. State nằm ở autoload Game; cảnh này chỉ điều phối.

signal player_respawned

var map: CityMap
var data: MapData
var nav: AStarGrid2D
var drive_nav: AStarGrid2D
var player: Player
var camera: CameraRig
var actors: Node2D
var effects: Node2D
var hud: Hud
var population: Population
var police: Police
var missions: Missions
var activities: Activities
var properties: Properties
var streamer: StreamerSpot
var interactions: Interactions
var overlays: Overlays
var _warm: Array[Texture2D] = []  # sprite xe/người nạp sẵn: lần đầu xe loại mới xuất hiện không bị khựng


func _ready() -> void:
	if Game.health <= 0.0:
		Game.revive()
	_warm_textures()
	map = CityMap.new()
	add_child(map)
	map.build()
	data = map.data
	Vehicle.map = data
	_build_nav()
	add_child(Ramps.new())
	effects = Node2D.new()
	effects.name = "Effects"
	effects.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # vòng nhiệm vụ, vật phẩm, hiệu ứng: dịch theo frame hoặc đứng yên
	add_child(effects)
	Fx.root = effects
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	add_child(DayNight.new(self))
	player = Player.new()
	player.global_position = MapData.cell_center(data.find("P"))
	actors.add_child(player)
	player.died.connect(_on_player_died)
	camera = CameraRig.new()
	add_child(camera)
	camera.setup(data.world_rect(), player)
	add_child(Weather.new(camera))
	for cell in data.find_all("c"):
		spawn_vehicle(DataDB.traffic_kind(), cell, randf() * TAU)
	for cell in data.find_all("m") + data.find_all("b"):
		spawn_vehicle("moto", cell, -PI * 0.5)
	for b in DataDB.extras().boats:
		spawn_vehicle("boat", Vector2i(int(b[0]), int(b[1])), PI * 0.5)
	population = Population.new(self)
	add_child(population)
	police = Police.new(self)
	add_child(police)
	interactions = Interactions.new(self)
	add_child(interactions)
	add_child(PickupSpots.new(self))
	missions = Missions.new(self)
	add_child(missions)
	activities = Activities.new(self)
	add_child(activities)
	properties = Properties.new(self)
	add_child(properties)
	streamer = StreamerSpot.new(self)
	add_child(streamer)
	add_child(Achievements.new(self))
	add_child(Cheats.new(self))
	hud = Hud.new(self)
	add_child(hud)
	overlays = Overlays.new(self)
	add_child(overlays)
	if TouchControls.wanted():
		add_child(TouchControls.new())
	Music.play()
	if Tutorial.wanted() and Game.missions_done.is_empty():
		add_child(Tutorial.new(self))
	elif Game.missions_done.size() < Game.mission_count():
		get_tree().create_timer(Tuning.START_HINT_DELAY).timeout.connect(func() -> void:
			Game.notice.emit(I18n.fmt("HINT_MAP_SHOPS", {"key": InputSetup.key_label(&"map")})))


func _exit_tree() -> void:
	Fx.root = null
	Vehicle.map = null


func _warm_textures() -> void:
	for kind in DataDB.vehicles():
		var spec := DataDB.vehicle(kind)
		for sprite in spec.sprites:
			_warm.append(load(spec.get("sprite_dir", Vehicle.CAR_DIR) % sprite))
	for skin in Tuning.SKINS + ["manBlue"]:  # + cảnh sát
		for pose in ["stand", "gun", "machine", "hold", "reload", "silencer"]:
			_warm.append(load(Human.CHAR_DIR % [skin, pose]))


## Hai lưới A*: đi bộ (mọi ô không đặc) và lái xe (ưu tiên lòng đường).
func _build_nav() -> void:
	nav = _grid(1.0)
	drive_nav = _grid(Tuning.OFFROAD_COST)


func _grid(offroad_cost: float) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, data.size)
	grid.cell_size = Vector2.ONE * Tuning.TILE
	grid.offset = Vector2.ONE * Tuning.TILE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if data.is_solid(cell):
				grid.set_point_solid(cell)
			elif not data.is_road(cell):
				grid.set_point_weight_scale(cell, offroad_cost)
	return grid


## Đường đi (toạ độ thế giới) giữa hai điểm qua các ô không đặc; `driving` thì ưu tiên lòng đường.
func path(from: Vector2, to: Vector2, driving := false) -> PackedVector2Array:
	var a := _open_cell(MapData.world_to_cell(from))
	var b := _open_cell(MapData.world_to_cell(to))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return PackedVector2Array()
	return (drive_nav if driving else nav).get_point_path(a, b, true)


func _open_cell(cell: Vector2i) -> Vector2i:
	if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
		return cell
	for d in MapData.DIRS:
		if nav.is_in_boundsv(cell + d) and not nav.is_point_solid(cell + d):
			return cell + d
	return Vector2i(-1, -1)


func spawn_vehicle(kind: String, cell: Vector2i, angle: float, sprite := "") -> Vehicle:
	var v := Vehicle.new().setup(kind, sprite)
	v.global_position = MapData.cell_center(cell)
	v.rotation = angle
	actors.add_child(v)
	return v


func spawn_npc(script: GDScript, pos: Vector2) -> Npc:
	var npc: Npc = script.new()
	npc.city = self
	npc.global_position = pos
	actors.add_child(npc)
	return npc


func view_rect() -> Rect2:
	return camera.view_rect()


func _on_player_died(_human: Human) -> void:
	missions.on_player_died()
	activities.on_player_died()
	await get_tree().create_timer(Tuning.DEATH_SCREEN_DELAY).timeout
	overlays.show_death()


## Hồi sinh theo lựa chọn ở màn chết (DeathScreen.Revive).
func respawn(choice: DeathScreen.Revive) -> void:
	var pos := player.global_position
	var here := choice == DeathScreen.Revive.HERE
	if here:
		var fee := Game.pay_fee(Tuning.REVIVE_HERE_FEE)
		Game.notice.emit(I18n.fmt("NOTICE_REVIVE_FEE", {"fee": I18n.money(fee)}))
	if here:
		Game.revive()
		pos = nearest_land(pos)
	elif choice == DeathScreen.Revive.RETRY or choice == DeathScreen.Revive.SAFEHOUSE:  # miễn phí, xoá truy nã
		Game.clear_wanted()
		Game.revive()
		police.clear_all()
		if choice == DeathScreen.Revive.RETRY:
			pos = missions.giver_pos(missions.retry_mission)
		else:
			pos = properties.nearest_home(pos)
			Game.notice.emit(tr("NOTICE_SAFEHOUSE_WAKE"))
	else:
		var fee := Game.hospital_respawn()
		Game.notice.emit(I18n.fmt("NOTICE_HOSPITAL", {"fee": I18n.money(fee)}))
		police.clear_all()
		pos = nearest_hospital(pos)
	player.respawn(pos, Tuning.REVIVE_GRACE if here else 0.0)
	camera.global_position = pos
	player_respawned.emit()
	if choice == DeathScreen.Revive.RETRY:
		missions.start(missions.retry_mission, false)
	missions.retry_mission = 0


## Hồi sinh tại chỗ khi chết đuối: đưa lên ô đi được gần nhất. Không ở dưới nước thì giữ nguyên chỗ
## (đứng sát gốc cây/thùng vẫn là chỗ hợp lệ dù ô đó tính là "đặc").
func nearest_land(from: Vector2) -> Vector2:
	var c0 := MapData.world_to_cell(from)
	if data.at(c0) != "~":
		return from
	for r in range(1, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and data.in_bounds(c) and not data.is_solid(c):
					return MapData.cell_center(c)
	return from


func nearest_hospital(from: Vector2) -> Vector2:
	var best := Vector2.INF
	for cell in data.find_all("H"):
		var pos := MapData.cell_center(cell)
		if from.distance_to(pos) < from.distance_to(best):
			best = pos
	return best

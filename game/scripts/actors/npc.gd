class_name Npc
extends Human
## NPC: di chuyển theo đường A*, kiểm tra tầm nhìn, bắn có sai số, báo tội khi bị người chơi tấn công.
## Hành vi riêng nằm ở lớp con (Pedestrian, Cop, Gangster).

const BAR_SIZE := Vector2(34, 5)
const BAR_OFFSET := Vector2(-17, -34)

var city: City
var gun: Gun
var heat_on_hit := 0.0
var heat_on_kill := 0.0
var _hit_by_player := false
var _path := PackedVector2Array()
var _path_timer := 0.0
var _react := 0.0
var _corpse_timer := Tuning.CORPSE_TIME
var _bar_time := 0.0


func _ready() -> void:
	super()
	add_to_group("listeners")


func _physics_process(delta: float) -> void:
	if _bar_time > 0.0:
		_bar_time -= delta
		queue_redraw()
	if not alive:
		_corpse_timer -= delta
		if _corpse_timer <= 0.0 and _corpse_timer + delta > 0.0:
			var t := create_tween()
			t.tween_property(self, "modulate:a", 0.0, Tuning.CORPSE_FADE)
			t.tween_callback(queue_free)
		return
	if gun:
		gun.tick(delta)
	_think(delta)


## Thanh máu nhỏ trên đầu, chỉ hiện một lúc sau khi trúng đòn.
func _draw() -> void:
	if not alive or _bar_time <= 0.0:
		return
	var a := clampf(_bar_time / 0.3, 0.0, 1.0)
	var r := Rect2(BAR_OFFSET, BAR_SIZE)
	draw_rect(r.grow(1.5), Color(Palette.OUTLINE, a))
	draw_rect(Rect2(r.position, Vector2(BAR_SIZE.x * clampf(health / max_health, 0.0, 1.0), BAR_SIZE.y)), Color(Palette.HEALTH, a))


## Ghi đè ở lớp con.
func _think(_delta: float) -> void:
	pass


func hear_gunshot(_pos: Vector2, _shooter: Node) -> void:
	pass


func player() -> Player:
	return city.player


func can_see(pos: Vector2, max_dist := Tuning.NPC_SIGHT) -> bool:
	if global_position.distance_to(pos) > max_dist:
		return false
	var q := PhysicsRayQueryParameters2D.create(global_position, pos, Tuning.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Vị trí cần nhắm: người chơi, hoặc xe họ đang lái.
func player_target() -> Node2D:
	var p := player()
	return p.vehicle if p.vehicle else p


## Đi theo đường A* tới `goal` (tính lại định kỳ).
func walk_to(goal: Vector2, speed: float, delta: float) -> void:
	_path_timer -= delta
	if _path_timer <= 0.0 or _path.is_empty():
		_path_timer = Tuning.PATH_REFRESH
		_path = city.path(global_position, goal)
		if _path.size() > 1:
			_path.remove_at(0)
	while _path.size() > 1 and global_position.distance_to(_path[0]) < Tuning.TILE * 0.4:
		_path.remove_at(0)
	var next := goal if _path.size() <= 1 else _path[0]
	walk_dir((next - global_position).normalized() * speed, delta)


func walk_dir(desired: Vector2, delta: float) -> void:
	move(desired, delta)
	if desired.length() > 1.0:
		face(lerp_angle(facing, desired.angle(), minf(10.0 * delta, 1.0)))


## Ngắm và bắn sau thời gian phản xạ.
func shoot_at(pos: Vector2, delta: float) -> void:
	move(Vector2.ZERO, delta)
	face(lerp_angle(facing, (pos - global_position).angle(), minf(12.0 * delta, 1.0)))
	_react -= delta
	if _react > 0.0 or gun == null:
		return
	var error := deg_to_rad(randf_range(-Tuning.NPC_AIM_ERROR_DEG, Tuning.NPC_AIM_ERROR_DEG))
	var exclude: Array[RID] = [get_rid()]
	gun.try_fire(self, muzzle_position(), facing + error, exclude)


func _on_damaged(_amount: float, source: Node) -> void:
	_bar_time = Tuning.HEALTH_BAR_TIME
	_react = minf(_react, Tuning.NPC_REACTION)
	if source is Player and not _hit_by_player:
		_hit_by_player = true
		Game.add_heat(heat_on_hit)
	_on_attacked(source)


## Ghi đè ở lớp con: phản ứng khi bị tấn công.
func _on_attacked(_source: Node) -> void:
	pass


func _die(dir: Vector2, source: Node) -> void:
	super(dir, source)
	queue_redraw()
	if source is Player:
		Game.add_heat(heat_on_kill)
		Fx.kill_mark(global_position + Vector2(0, BAR_OFFSET.y))
		Sfx.play("kill")

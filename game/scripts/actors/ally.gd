class_name Ally
extends Npc
## Đàn em thuê ở nhà an toàn: đi theo Jay, bắn kẻ thù gần nhất (Red Fangs; cả cảnh sát khi đang bị truy nã).
## Jay lên xe thì đàn em ngồi cùng (ẩn đi), xuống xe thì xuất hiện lại bên cạnh.

const FOLLOW := 110.0

var _riding := false


func _ready() -> void:
	skin = "soldier1"
	max_health = Tuning.ALLY_HEALTH
	gun = Gun.new(DataDB.weapon("smg"))
	pose = str(gun.def.pose)
	super()
	add_to_group("allies")
	body.modulate = Palette.ALLY_TINT


func _think(delta: float) -> void:
	var p := player()
	if p.vehicle or p.swim.active:  # đàn em không bơi: chờ Jay lên bờ rồi xuất hiện lại
		_ride(true)
		global_position = p.global_position
		return
	_ride(false)
	var enemy := _enemy()
	if enemy:
		shoot_at(enemy.global_position, delta)
	elif global_position.distance_to(p.global_position) > FOLLOW:
		_react = Tuning.NPC_REACTION
		walk_to(p.global_position, Tuning.WALK_SPEED * 0.95, delta)
	else:
		move(Vector2.ZERO, delta)


func _ride(on: bool) -> void:
	if on == _riding:
		return
	_riding = on
	visible = not on
	collision_layer = 0 if on else Tuning.LAYER_ACTORS
	collision_mask = 0 if on else Tuning.MASK_HUMAN
	if not on:
		var spot := player().global_position + Vector2(randf_range(-40, 40), 40)
		global_position = spot if not city.data.is_solid(MapData.world_to_cell(spot)) else player().global_position
		reset_physics_interpolation()


func _enemy() -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.NPC_SHOOT_RANGE
	var foes := get_tree().get_nodes_in_group("gang")
	if Game.stars > 0:
		foes.append_array(get_tree().get_nodes_in_group("cops"))
	for f in foes:
		var d: float = global_position.distance_to(f.global_position)
		if f.alive and d < best_d and can_see(f.global_position):
			best = f
			best_d = d
	return best


func take_hit(amount: float, dir: Vector2, source: Variant, knockback := 0.0) -> void:
	if not _riding:
		super(amount, dir, source, knockback)

class_name Player
extends Human
## Jay: đi bộ, ngắm (chuột / analog phải / joystick ảo), bắn, đổi súng, nạp đạn. Lái xe: xem Vehicle.

var vehicle: Vehicle
var gun := Gun.new({}, true)
var aim_angle := 0.0
var controls_enabled := true
var _walk_velocity := Vector2.ZERO
var _mouse_active_ms := -100000
var _grace := 0.0


func _ready() -> void:
	skin = "hitman1"
	max_health = Tuning.MAX_HEALTH
	super()
	add_to_group("player")
	Game.weapons_changed.connect(_sync_weapon)
	_sync_weapon()


func _sync_weapon() -> void:
	if gun.def.get("id", "") != Game.current:
		gun.def = Game.weapon_def()
		gun.reloading = 0.0
		gun.cooldown = 0.2
	set_pose("reload" if gun.reloading > 0.0 else str(gun.def.pose))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active_ms = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if not alive or vehicle or not controls_enabled:
		return
	if event.is_action_pressed("reload") and gun.start_reload():
		set_pose("reload")
	elif event.is_action_pressed("weapon_next"):
		Game.cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		Game.cycle_weapon(-1)
	else:
		var ids := DataDB.weapons()
		for i in mini(ids.size(), InputSetup.WEAPON_SLOTS):
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				Game.select_weapon(ids[i].id)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _grace > 0.0:
		_grace -= delta
		body.modulate.a = 1.0 if _grace <= 0.0 else 0.45 + 0.4 * absf(sin(_grace * 14.0))
	if vehicle:
		global_position = vehicle.global_position
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if controls_enabled else Vector2.ZERO
	_walk_velocity = _walk_velocity.move_toward(input * Tuning.WALK_SPEED, Tuning.WALK_ACCEL * delta)
	move(_walk_velocity, delta)
	_update_aim(input)
	face(aim_angle)
	if gun.tick(delta):
		set_pose(str(gun.def.pose))
	if controls_enabled and Input.is_action_pressed("fire"):
		gun.try_fire(self, muzzle_position(), aim_angle, [get_rid()])
		if gun.reloading > 0.0:
			set_pose("reload")


func _update_aim(move_input: Vector2) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		aim_angle = stick.angle()
	elif Time.get_ticks_msec() - _mouse_active_ms < Tuning.MOUSE_AIM_IDLE * 1000.0:
		aim_angle = (get_global_mouse_position() - global_position).angle()
	elif move_input.length() > 0.3:
		aim_angle = move_input.angle()


func aim_vector() -> Vector2:
	return Vector2.from_angle(aim_angle)


func enter_vehicle(v: Vehicle) -> void:
	vehicle = v
	visible = false
	collision_layer = 0
	collision_mask = 0
	_walk_velocity = Vector2.ZERO
	v.set_driver(self)


func exit_vehicle() -> void:
	var v := vehicle
	vehicle = null
	global_position = v.exit_point()
	if v.velocity.length() > Tuning.BAIL_SPEED:
		knocked = Tuning.KNOCKDOWN_TIME * 0.5
		knock_velocity = v.velocity * 0.5
	visible = true
	collision_layer = Tuning.LAYER_ACTORS
	collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_VEHICLES | Tuning.LAYER_ACTORS
	v.set_driver(null)


func respawn(pos: Vector2, grace := 0.0) -> void:
	_grace = grace
	if vehicle:
		exit_vehicle()
	global_position = pos
	alive = true
	knocked = 0.0
	knock_velocity = Vector2.ZERO
	collision_layer = Tuning.LAYER_ACTORS
	collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_VEHICLES | Tuning.LAYER_ACTORS
	z_index = 0
	body.modulate = Color.WHITE
	_sync_weapon()


func _apply_damage(amount: float, dir: Vector2, source: Node) -> void:
	if _grace > 0.0:
		return
	if amount > 2.0:
		Sfx.play("hurt", -4.0)
		Fx.shake(amount * 0.15)
	if Game.damage_player(amount) and alive:
		alive = false
		_die(dir, source)

class_name Player
extends Human
## Jay: đi bộ, ngắm (chuột / analog phải / joystick ảo), bắn, đổi súng, nạp đạn, bơi (chậm, không bắn, hết hơi thì
## mất máu). Lái xe: xem Vehicle.

var vehicle: Vehicle
var gun := Gun.new({}, true)
var _held_bat: HeldBat
var aim_angle := 0.0
var aiming := false  # đang ngắm có chủ đích (chuột, analog/joystick phải), không phải hướng ngắm đi theo hướng chạy
var controls_enabled := true
var _walk_velocity := Vector2.ZERO
var _mouse_active_ms := -100000
var _grace := 0.0
var _since_hurt := 0.0
var _swap_held := -1.0  # giây đang giữ phím đổi súng (-1: không giữ); giữ đủ lâu thì mở vòng chọn súng
var _wheel: WeaponWheel
var _wheel_opened := false
var swim := Swim.new()


func _ready() -> void:
	_sync_look()
	max_health = Tuning.MAX_HEALTH
	super()
	collision_mask = Tuning.MASK_SWIMMER
	add_to_group("player")
	_held_bat = HeldBat.new(self)
	body.add_child(_held_bat)
	Game.weapons_changed.connect(_sync_weapon)
	Game.skin_changed.connect(func() -> void:
		_sync_look()
		set_pose(pose)
		refresh_hair())
	_sync_weapon()


func _sync_look() -> void:
	skin = Game.skin
	hair_style = Game.hair
	hair_color = Palette.HAIR[Game.hair_color]


func _sync_weapon() -> void:
	if gun.def.get("id", "") != Game.current:
		gun.def = Game.weapon_def()
		gun.reloading = 0.0
		gun.cooldown = 0.2
	set_pose("reload" if gun.reloading > 0.0 else str(gun.def.pose))
	_held_bat.equipped = gun.def.get("id", "") == "bat"


func _input(event: InputEvent) -> void:
	# Chạm sinh chuột giả (DEVICE_ID_EMULATION): không tính là ngắm bằng chuột, kẻo Jay quay về phía ngón tay.
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_active_ms = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("weapon_next") and _swap_held >= 0.0:
		_release_swap()
		return
	if not alive or not controls_enabled:
		return
	if vehicle:
		if event.is_action_pressed("horn"):
			vehicle.honk()
		return
	if event.is_action_pressed("reload") and gun.start_reload():
		set_pose("reload")
	elif event.is_action_pressed("weapon_next"):
		_swap_held = 0.0
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
	_since_hurt += delta
	_update_wheel(delta)
	if _since_hurt > Tuning.REGEN_DELAY and Game.health < Tuning.REGEN_CAP:
		Game.heal(minf(Tuning.REGEN_RATE * delta, Tuning.REGEN_CAP - Game.health))
	if _grace > 0.0:
		_grace -= delta
		body.modulate.a = 1.0 if _grace <= 0.0 else 0.45 + 0.4 * absf(sin(_grace * 14.0))
	if vehicle:
		global_position = vehicle.global_position
		_drive_by(delta)
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if controls_enabled else Vector2.ZERO
	swim.update(self, delta)
	var speed := Tuning.SWIM_SPEED if swim.active else Tuning.WALK_SPEED
	_walk_velocity = _walk_velocity.move_toward(input * speed, Tuning.WALK_ACCEL * delta)
	move(_walk_velocity, delta)
	if Vehicle.map:  # biển ở mép bản đồ không có tường: không cho bơi ra ngoài
		global_position = global_position.clamp(Vector2.ONE * Tuning.TILE * 2.0, Vehicle.map.world_rect().end - Vector2.ONE * Tuning.TILE * 2.0)
	_update_aim(input)
	face(aim_angle)
	if gun.tick(delta):
		set_pose(str(gun.def.pose))
	if controls_enabled and not swim.active and Input.is_action_pressed("fire"):
		gun.try_fire(self, muzzle_position(), aim_angle, [get_rid()])
		if gun.reloading > 0.0:
			set_pose("reload")


func _update_aim(move_input: Vector2) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	aiming = true
	if stick.length() > 0.3:
		aim_angle = AimAssist.pick(self, stick.angle(), float(gun.def.range))
	elif Time.get_ticks_msec() - _mouse_active_ms < Tuning.MOUSE_AIM_IDLE * 1000.0:
		aim_angle = (get_global_mouse_position() - global_position).angle()
	else:
		aiming = false
	if not aiming and move_input.length() > 0.3:
		aim_angle = move_input.angle()


## Nhả phím đổi súng: đang mở vòng thì cầm ô đã chọn, bấm nhanh thì đổi súng kế.
func _release_swap() -> void:
	_swap_held = -1.0
	if is_instance_valid(_wheel):
		_wheel.pick()
	elif not _wheel_opened and alive and controls_enabled and not vehicle:
		Game.cycle_weapon(1)
	_wheel_opened = false


func _update_wheel(delta: float) -> void:
	if _swap_held < 0.0:
		return
	if vehicle or not controls_enabled or not Input.is_action_pressed("weapon_next"):  # lỡ mất lần nhả (lên xe, tạm dừng...)
		_swap_held = -1.0
		_wheel_opened = false
		if is_instance_valid(_wheel):
			_wheel.queue_free()
		return
	_swap_held += delta / Engine.time_scale
	if _swap_held >= Tuning.WHEEL_HOLD and not is_instance_valid(_wheel) and Game.owned_ids().size() > 1:
		_wheel = WeaponWheel.new()
		_wheel_opened = true
		get_tree().current_scene.add_child(_wheel)


## Bắn từ trong xe (súng ngắn, tiểu liên): ngắm bằng chuột / analog phải / joystick phải; không có thì bắn thẳng
## theo mũi xe. Đạn bay ra từ mép thân xe phía hướng ngắm, không trúng chính xe mình.
func _drive_by(delta: float) -> void:
	gun.tick(delta)
	if not controls_enabled or not Input.is_action_pressed("fire") or not gun.def.get("driveby", false):
		return
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		aim_angle = stick.angle()
	elif Time.get_ticks_msec() - _mouse_active_ms < Tuning.MOUSE_AIM_IDLE * 1000.0:
		aim_angle = (get_global_mouse_position() - vehicle.global_position).angle()
	else:
		aim_angle = vehicle.rotation
	var origin := vehicle.global_position + Vector2.from_angle(aim_angle) * vehicle.size.y * 0.6
	gun.try_fire(self, origin, aim_angle, [get_rid(), vehicle.get_rid()])


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
	reset_physics_interpolation()
	if v.velocity.length() > Tuning.BAIL_SPEED:
		knocked = Tuning.KNOCKDOWN_TIME * 0.5
		knock_velocity = v.velocity * 0.5
	visible = true
	collision_layer = Tuning.LAYER_ACTORS
	collision_mask = Tuning.MASK_SWIMMER
	v.set_driver(null)


## Ngồi trong xe thì xe chịu đòn thay (nổ, đạn lạc); xe cháy thì Jay tự nhảy ra.
func take_hit(amount: float, dir: Vector2, source: Variant, knockback := 0.0) -> void:
	if vehicle == null:
		super(amount, dir, source, knockback)


## Vài giây không mất máu (nhấp nháy), vd. vừa nhảy khỏi xe gài bom.
func shield(seconds: float) -> void:
	_grace = maxf(_grace, seconds)


func respawn(pos: Vector2, grace := 0.0) -> void:
	_grace = grace
	swim = Swim.new()
	if vehicle:
		exit_vehicle()
	global_position = pos
	reset_physics_interpolation()
	alive = true
	knocked = 0.0
	knock_velocity = Vector2.ZERO
	collision_layer = Tuning.LAYER_ACTORS
	collision_mask = Tuning.MASK_SWIMMER
	z_index = 0
	body.modulate = Color.WHITE
	_sync_weapon()


func _apply_damage(amount: float, dir: Vector2, source: Node) -> void:
	if _grace > 0.0:
		return
	_since_hurt = 0.0
	if amount > 2.0:
		Sfx.play("hurt", -4.0)
		Fx.shake(amount * 0.15)
	if Game.damage_player(amount) and alive:
		alive = false
		_die(dir, source)

class_name CameraRig
extends Camera2D
## Camera bám người chơi, nhìn trước theo hướng ngắm (đi bộ) hoặc vận tốc (lái xe).
## Dịch `position` (không dùng offset) để limit_* vẫn giữ khung hình trong bản đồ; offset chỉ dùng để rung.
## Physics interpolation chỉ nội suy 2D phía server (không có get_global_transform_interpolated), nên camera tắt nội suy tự động
## và tự nội suy vị trí mục tiêu giữa hai tick vật lý: bám theo đúng chỗ nhân vật đang được vẽ, không giật theo nhịp 60Hz.

const ZOOM_WALK := 1.0
const ZOOM_DRIVE := 0.78
const ZOOM_SMOOTH := 2.0
const TELEPORT := 256.0  # mục tiêu nhảy xa hơn chừng này trong một tick: dịch chuyển tức thời, không nội suy

var target: Player
var trauma := 0.0
var zoom_scale := 1.0  # nhân thêm vào zoom tự động (quay trailer: khung dọc cần zoom gần hơn)
var _bounds := Rect2()
var _tick_from := Vector2.ZERO
var _tick_to := Vector2.ZERO
var _look := Vector2.ZERO
var _shake_time := 0.0
var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.frequency = 1.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # trước khi vào cây, không thì Camera2D tự ép sang cập nhật theo tick
	process_physics_priority = 1  # sau Player/Vehicle: lấy vị trí đã di chuyển của chính tick này


func _ready() -> void:
	add_to_group("camera_rig")


func setup(world: Rect2, player: Player) -> void:
	_bounds = world
	target = player
	limit_left = int(world.position.x)
	limit_top = int(world.position.y)
	limit_right = int(world.end.x)
	limit_bottom = int(world.end.y)
	global_position = player.global_position
	_tick_from = _followed()
	_tick_to = _tick_from
	make_current()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount / Tuning.SHAKE_MAX_OFFSET, 1.0)


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	_tick_from = _tick_to
	_tick_to = _followed()
	if _tick_from.distance_to(_tick_to) > TELEPORT:
		_tick_from = _tick_to


func _followed() -> Vector2:
	return target.vehicle.global_position if target.vehicle else target.global_position


func _process(delta: float) -> void:
	if target == null:
		return
	var v := target.vehicle
	var look := Vector2.ZERO
	var zoom_goal := ZOOM_WALK
	if v:
		look = v.velocity * Tuning.LOOK_AHEAD_DRIVING
		zoom_goal = lerpf(ZOOM_WALK, ZOOM_DRIVE, clampf(v.velocity.length() / float(v.spec.max_speed), 0.0, 1.0) + 0.3)
	elif target.alive:
		look = target.aim_vector() * Tuning.LOOK_AHEAD
	_look = _look.lerp(look, 1.0 - exp(-Tuning.LOOK_SMOOTH * delta))
	var goal := _tick_from.lerp(_tick_to, Engine.get_physics_interpolation_fraction()) + _look
	zoom = zoom.lerp(Vector2.ONE * zoom_goal * zoom_scale, minf(ZOOM_SMOOTH * delta, 1.0))
	var half := get_viewport_rect().size / zoom * 0.5
	goal = goal.clamp(_bounds.position + half, (_bounds.end - half).max(_bounds.position + half))
	global_position = global_position.lerp(goal, 1.0 - exp(-Tuning.CAMERA_SMOOTH * delta))
	trauma = maxf(trauma - Tuning.SHAKE_DECAY * delta, 0.0)
	var amount := trauma * trauma * Tuning.SHAKE_MAX_OFFSET
	_shake_time += delta * Tuning.SHAKE_FREQ
	offset = Vector2(_noise.get_noise_2d(_shake_time, 0.0), _noise.get_noise_2d(0.0, _shake_time)) * amount


## Tâm khung hình thật (để spawn/despawn ngoài màn hình).
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - size * 0.5, size)

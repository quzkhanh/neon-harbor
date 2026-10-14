class_name CameraRig
extends Camera2D
## Camera bám người chơi, nhìn trước theo hướng ngắm (đi bộ) hoặc vận tốc (lái xe).
## Dịch `position` (không dùng offset) để limit_* vẫn giữ khung hình trong bản đồ; offset chỉ dùng để rung.

const ZOOM_WALK := 1.0
const ZOOM_DRIVE := 0.78
const ZOOM_SMOOTH := 2.0

var target: Player
var trauma := 0.0
var _bounds := Rect2()


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
	make_current()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount / Tuning.SHAKE_MAX_OFFSET, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var v := target.vehicle
	var goal := target.global_position
	var zoom_goal := ZOOM_WALK
	if v:
		goal = v.global_position + v.velocity * Tuning.LOOK_AHEAD_DRIVING
		zoom_goal = lerpf(ZOOM_WALK, ZOOM_DRIVE, clampf(v.velocity.length() / float(v.spec.max_speed), 0.0, 1.0) + 0.3)
	elif target.alive:
		goal += target.aim_vector() * Tuning.LOOK_AHEAD
	zoom = zoom.lerp(Vector2.ONE * zoom_goal, minf(ZOOM_SMOOTH * delta, 1.0))
	var half := get_viewport_rect().size / zoom * 0.5
	goal = goal.clamp(_bounds.position + half, (_bounds.end - half).max(_bounds.position + half))
	global_position = global_position.lerp(goal, 1.0 - exp(-Tuning.CAMERA_SMOOTH * delta))
	trauma = maxf(trauma - Tuning.SHAKE_DECAY * delta, 0.0)
	var amount := trauma * trauma * Tuning.SHAKE_MAX_OFFSET
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount


## Tâm khung hình thật (để spawn/despawn ngoài màn hình).
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - size * 0.5, size)

class_name DriveInput
extends RefCounted
## Đọc phím lái của người chơi vào throttle/steer/handbrake của xe.
## "screen" (mặc định): xe xoay về hướng bấm trên màn hình, tự phanh khi vào cua; bấm ngược hướng xe
## thì phanh, rồi lùi vòng cho mũi xe quay về hướng đó. "classic": tiến/lùi + xoay trái/phải theo thân xe.

const SCREEN := "screen"
const CLASSIC := "classic"

var _turning_back := false


func read(v: Vehicle) -> void:
	v.handbrake = Input.is_action_pressed("handbrake")
	v.assist = Game.settings.steering != CLASSIC
	if not v.assist:
		v.throttle = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
		v.steer = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	else:
		_steer_toward(v, Input.get_vector("move_left", "move_right", "move_up", "move_down"))


func _steer_toward(v: Vehicle, stick: Vector2) -> void:
	v.throttle = 0.0
	v.steer = 0.0
	if stick.length() < InputSetup.DEADZONE:
		_turning_back = false
		return
	var diff := angle_difference(v.rotation, stick.angle())
	var speed := v.forward_speed()
	var behind := absf(diff) > Tuning.TURN_BACK_ANGLE
	if behind and speed > Tuning.TURN_BACK_SPEED:
		v.throttle = -1.0
	elif behind or (_turning_back and absf(diff) > PI * 0.5):
		_turning_back = true
		v.throttle = -stick.length()
		v.steer = -signf(diff)
	else:
		_turning_back = false
		v.steer = clampf(diff * Tuning.STEER_GAIN, -1.0, 1.0)
		var braking := absf(diff) > Tuning.CORNER_ANGLE and speed > Tuning.CORNER_SPEED
		v.throttle = -0.6 if braking else stick.length()

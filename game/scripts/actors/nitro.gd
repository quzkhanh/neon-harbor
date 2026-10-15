class_name Nitro
extends RefCounted
## Bình nitro của xe: giữ phím thì đốt (tăng tốc, lửa ống xả), nhả thì nạp lại dần.
## Đốt cạn bình thì phải nạp lại một phần mới bật lại được, để không chớp tắt liên tục.

var fuel := 1.0
var active := false
var _dry := false
var _burned := 0.0  # giây đốt nitro chưa ghi vào thống kê
var _flame: CPUParticles2D


func update(v: Vehicle, wanted: bool, delta: float) -> bool:
	if fuel >= Tuning.NITRO_REARM:
		_dry = false
	var was := active
	active = wanted and not _dry and fuel > 0.0
	if active:
		fuel = maxf(fuel - delta / Tuning.NITRO_TIME, 0.0)
		if v.is_player_driven():
			_burned += delta
			if _burned >= 1.0:
				_burned -= 1.0
				Game.bump("nitro_s")
		_dry = fuel <= 0.0
		Fx.shake(Tuning.NITRO_SHAKE * delta)
	else:
		fuel = minf(fuel + delta / Tuning.NITRO_RECHARGE, 1.0)
	if active and not was:
		Sfx.play_at("nitro", v.global_position)
	_show_flame(v)
	return active


func _show_flame(v: Vehicle) -> void:
	if _flame == null:
		if not active:
			return
		_flame = CPUParticles2D.new()
		_flame.texture = Fx.tex("flame")
		_flame.material = Fx.additive()
		_flame.amount = 26
		_flame.lifetime = 0.25
		_flame.direction = Vector2.LEFT
		_flame.spread = 12.0
		_flame.gravity = Vector2.ZERO
		_flame.initial_velocity_min = 120.0
		_flame.initial_velocity_max = 220.0
		_flame.scale_amount_min = 0.5
		_flame.scale_amount_max = 0.95
		_flame.color = Palette.NITRO_FLAME
		_flame.position = Vector2(-v.size.x * 0.5, 0.0)
		_flame.show_behind_parent = true
		v.add_child(_flame)
	_flame.emitting = active

class_name Stunt
extends RefCounted
## Xe bay qua dốc nhảy: bỏ va chạm với người/xe (vẫn đụng tường), sprite phồng lên rồi xẹp xuống;
## tiếp đất thì người chơi được thưởng theo thời gian bay (dốc lần đầu nhảy được báo riêng).

var air := 0.0
var _total := 0.0
var _ramp := -1
var _layer := 0
var _mask := 0
var _scale := Vector2.ONE


func launch(v: Vehicle, ramp: int) -> void:
	if air > 0.0:
		return
	_total = clampf(v.forward_speed() * Tuning.RAMP_AIR_PER_SPEED, Tuning.RAMP_AIR.x, Tuning.RAMP_AIR.y)
	air = _total
	_ramp = ramp
	_layer = v.collision_layer
	_mask = v.collision_mask
	_scale = v.body.scale
	v.collision_layer = 0
	v.collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_WATER
	v.z_index = 25
	Sfx.play_at("swing", v.global_position, 0.0, 0.6)


## Trả về true khi đang bay (xe không lái được).
func update(v: Vehicle, delta: float) -> bool:
	if air <= 0.0:
		return false
	air -= delta
	var t := 1.0 - maxf(air, 0.0) / _total
	v.body.scale = _scale * (1.0 + Tuning.RAMP_LIFT * sin(PI * t))
	if air <= 0.0:
		_land(v)
	return true


func _land(v: Vehicle) -> void:
	v.body.scale = _scale
	v.collision_layer = _layer
	v.collision_mask = _mask
	v.z_index = 0
	Fx.burst(v.global_position, "smoke", 10, 120.0, 0.6, Color(0.6, 0.6, 0.62, 0.7), false)
	Sfx.play_at("crash", v.global_position, -10.0)
	Fx.shake(4.0)
	if v.is_player_driven():
		var first := Game.mark("jump_ids", str(_ramp))
		var pay := int(_total * Tuning.STUNT_PAY_PER_SEC * (1.0 if first else Tuning.STUNT_REPEAT_SCALE))  # nhảy lại: thưởng ít
		Game.add_money(pay)
		Game.bump("jumps")
		Game.notice.emit(I18n.fmt("NOTICE_STUNT_NEW" if first else "NOTICE_STUNT", {"money": I18n.money(pay),
			"got": Game.marked("jump_ids").size(), "total": DataDB.extras().ramps.size()}))

class_name Swim
extends RefCounted
## Jay bơi khi đứng trên ô nước: chậm, không bắn (Player đọc `active`), hết hơi thì mất máu; lên bờ hồi hơi nhanh.

var active := false
var breath := Tuning.SWIM_BREATH
var _warned := false


func update(p: Player, delta: float) -> void:
	var wet := Vehicle.map != null and Vehicle.map.at(MapData.world_to_cell(p.global_position)) == "~"
	if wet != active:
		active = wet
		p.body.self_modulate = Palette.SWIM_TINT if wet else Color.WHITE
		Sfx.play_at("splash", p.global_position)
		Fx.burst(p.global_position, "smoke", 8, 90.0, 0.6, Palette.WAKE, false)
		if wet:
			Game.notice.emit(tr("NOTICE_SWIMMING"))
	if active:
		breath = maxf(breath - delta, 0.0)
		if breath <= 0.0:
			p._apply_damage(Tuning.SWIM_DROWN_DPS * delta, Vector2.ZERO, null)  # không chớp, không máu bắn mỗi frame
		elif breath < Tuning.SWIM_BREATH * 0.3 and not _warned:
			_warned = true
			Game.notice.emit(tr("NOTICE_BREATH"))
	else:
		breath = minf(breath + delta * Tuning.SWIM_RECOVER, Tuning.SWIM_BREATH)
		_warned = false

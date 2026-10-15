class_name DayNight
extends CanvasModulate
## Giờ trong game chạy liên tục (Tuning.DAY_LENGTH giây thật = 24 giờ); màu toàn cảnh đổi theo giờ, đèn đường,
## neon và đèn pha mờ đi ban ngày. Trời mưa (Weather.wet) thì tối thêm. Giờ lưu ở Game.clock.

const KEYS := [[0.0, "night"], [5.0, "night"], [6.5, "dawn"], [8.0, "day"], [17.0, "day"], [18.5, "dusk"], [20.0, "night"], [24.0, "night"]]
const LIGHT_EVERY := 0.25  # giây giữa hai lần cập nhật đèn

var darkness := 1.0  # 1 = đêm (đèn sáng hết), 0 = giữa trưa
var _lights_timer := 0.0
var _city: City


func _init(c: City) -> void:
	_city = c
	name = "DayNight"


func _ready() -> void:
	_apply(true)


func _process(delta: float) -> void:
	Game.clock = fposmod(Game.clock + delta * 24.0 / Tuning.DAY_LENGTH, 24.0)
	_lights_timer -= delta
	_apply(_lights_timer <= 0.0)


func _apply(lights: bool) -> void:
	var tint := tint_at(Game.clock)
	darkness = clampf(inverse_lerp(Palette.SKY["day"].v, Palette.SKY["night"].v, tint.v), 0.0, 1.0)
	color = tint.lerp(tint * Palette.RAIN_DIM, Weather.wet)
	if lights:
		_lights_timer = LIGHT_EVERY
		var a := lerpf(Tuning.LIGHTS_DAY, 1.0, darkness)
		for layer in ["Lamps", "Neon"]:
			var n := _city.map.get_node_or_null(layer)
			if n:
				n.modulate.a = a
		get_tree().call_group("headlights", "set", "self_modulate", Color(1, 1, 1, a))


static func tint_at(hour: float) -> Color:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			return Palette.SKY[a[1]].lerp(Palette.SKY[b[1]], (hour - a[0]) / maxf(b[0] - a[0], 0.001))
	return Palette.SKY["night"]

class_name VehicleLamps
extends Node2D
## Đèn đầu (trắng ấm) và đèn hậu (đỏ, sáng hơn khi phanh) vẽ đè lên thân xe, để phân biệt đầu xe và đuôi xe:
## sprite xe gần như đối xứng nên nhìn từ trên xuống rất khó biết xe quay mặt về đâu.
## Đèn bo tròn và lùi vào trong viền tối của sprite, không lòi ra góc bo của thân xe.

const INSET := 3.5  # px: lùi khỏi mũi/đuôi xe, qua lớp viền tối của sprite Kenney
const SIDE := 0.28  # lệch khỏi trục xe, theo phần chiều ngang
const HEAD := Vector2(2.4, 0.11)  # bán trục: dọc thân (px), ngang thân (phần chiều ngang xe)
const TAIL := Vector2(1.6, 0.1)
const MOTO_INSET := 12.0  # mũi xe máy là bánh xe đen, đèn nằm trên yếm ngay sau bánh
const MOTO_LAMP := 2.3
const SIGNAL_SIDE := 0.4  # xi-nhan (đèn khẩn cấp) ở mép ngoài, cạnh đèn chính
const SIGNAL := 1.6
const BRAKE_GLOW := 2.2  # quầng đèn phanh to gấp mấy lần đèn
const BRAKE_THROTTLE := -0.1
const HAZARD_PERIOD := 0.5

var _vehicle: Vehicle
var _braking := false
var _hazard_on := false


func _init(v: Vehicle) -> void:
	_vehicle = v
	z_index = 1


func _process(_delta: float) -> void:
	var braking := not _vehicle.wrecked and (_vehicle.throttle < BRAKE_THROTTLE or _vehicle.handbrake) and _vehicle.velocity.length_squared() > 1.0
	visible = not _vehicle.wrecked
	var blink := _vehicle.hazard and fmod(Time.get_ticks_msec() / 1000.0, HAZARD_PERIOD * 2.0) < HAZARD_PERIOD
	if braking != _braking or blink != _hazard_on:
		_braking = braking
		_hazard_on = blink
		queue_redraw()


func _draw() -> void:
	var moto := _vehicle.kind == "moto"
	var nose := _vehicle.size.x * 0.5 - (MOTO_INSET if moto else INSET)
	var width := _vehicle.size.y
	var head := Vector2.ONE * MOTO_LAMP if moto else Vector2(HEAD.x, HEAD.y * width)
	var tail := Vector2.ONE * MOTO_LAMP * 0.8 if moto else Vector2(TAIL.x, TAIL.y * width)
	var tail_color := Palette.BRAKE_LAMP if _braking else Palette.TAIL_LAMP
	for side in ([0.0] if moto else [-1.0, 1.0]):
		var y: float = side * width * SIDE
		var front := Vector2(nose - head.x, y)
		var rear := Vector2(-nose + tail.x, y)
		if _braking:
			Shapes.oval(self, rear, tail.x * BRAKE_GLOW, tail.y * BRAKE_GLOW, Color(tail_color, 0.3), 0.0, false)
		Shapes.oval(self, front, head.x, head.y, Palette.HEADLAMP)
		Shapes.oval(self, rear, tail.x, tail.y, tail_color)
	if _hazard_on:
		var signal_y := MOTO_LAMP * 2.0 if moto else width * SIGNAL_SIDE
		for end in [nose - SIGNAL, -nose + SIGNAL]:
			for side in [-1.0, 1.0]:
				Shapes.oval(self, Vector2(end, side * signal_y), SIGNAL, SIGNAL, Palette.HAZARD_LAMP)

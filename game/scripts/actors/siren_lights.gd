class_name SirenLights
extends Node2D
## Đèn nóc xe cảnh sát (đỏ/xanh luân phiên) và còi hú khi đang truy đuổi.

const BAR := Vector2(8, 26)
const PERIOD := 0.5

var active := false
var _sound: AudioStreamPlayer2D
var _glows: Array[Sprite2D] = []


func _ready() -> void:
	z_index = 2
	for color in [Palette.SIREN_RED, Palette.SIREN_BLUE]:
		var g := Sprite2D.new()
		g.texture = Fx.tex("glow")
		g.material = Fx.additive()
		g.modulate = Color(color, 0.0)
		g.scale = Vector2.ONE * 0.8
		add_child(g)
		_glows.append(g)
	_glows[0].position = Vector2(-2, -BAR.y * 0.35)
	_glows[1].position = Vector2(-2, BAR.y * 0.35)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on:
		_sound = Sfx.make_loop("siren", get_parent(), -8.0)
		_sound.play()
	elif _sound:
		_sound.queue_free()
		_sound = null
	queue_redraw()


func _process(_delta: float) -> void:
	var red_on := active and fmod(Time.get_ticks_msec() / 1000.0, PERIOD * 2.0) < PERIOD
	_glows[0].modulate.a = 0.8 if red_on else 0.0
	_glows[1].modulate.a = 0.8 if active and not red_on else 0.0
	queue_redraw()


func _draw() -> void:
	var red_on := active and fmod(Time.get_ticks_msec() / 1000.0, PERIOD * 2.0) < PERIOD
	var half := Rect2(-BAR.x * 0.5 - 2, -BAR.y * 0.5, BAR.x, BAR.y * 0.5)
	draw_rect(half, Palette.SIREN_RED if red_on else Palette.SIREN_RED.darkened(0.6))
	draw_rect(Rect2(half.position + Vector2(0, BAR.y * 0.5), half.size), Palette.SIREN_BLUE if active and not red_on else Palette.SIREN_BLUE.darkened(0.6))

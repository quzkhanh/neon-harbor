class_name Weather
extends CanvasLayer
## Thỉnh thoảng mưa: hạt mưa phủ màn hình, tiếng mưa, trời tối hơn (DayNight), đường trơn (Vehicle đọc `wet`).
## Mỗi giờ trong game tung xúc xắc đổi thời tiết; `wet` chuyển dần 0 <-> 1.

static var wet := 0.0  # 0 = khô ráo, 1 = mưa to

var raining := false
var _hour := -1
var _drops: CPUParticles2D
var _sound: AudioStreamPlayer2D
var _camera: Camera2D


func _init(camera: Camera2D) -> void:
	_camera = camera
	name = "Weather"
	layer = 5


func _ready() -> void:
	wet = 0.0
	_drops = CPUParticles2D.new()
	_drops.texture = _streak()
	_drops.amount = Tuning.RAIN_DROPS
	_drops.lifetime = 0.55
	_drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drops.direction = Vector2(-0.25, 1.0)
	_drops.spread = 4.0
	_drops.gravity = Vector2.ZERO
	_drops.initial_velocity_min = 900.0
	_drops.initial_velocity_max = 1200.0
	_drops.color = Palette.RAIN
	_drops.particle_flag_align_y = true
	_drops.emitting = false
	add_child(_drops)
	_sound = Sfx.make_loop("rain", _camera, -4.0)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _exit_tree() -> void:
	wet = 0.0


## Vệt mưa vẽ bằng code: 2×22 px, mờ dần về đuôi.
func _streak() -> ImageTexture:
	var img := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 2:
			img.set_pixel(x, y, Color(1, 1, 1, float(y) / 22.0))
	return ImageTexture.create_from_image(img)


func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	_drops.position = Vector2(size.x * 0.6, -40.0)
	_drops.emission_rect_extents = Vector2(size.x * 0.75, 10.0)


func set_raining(on: bool) -> void:
	raining = on
	_drops.emitting = on
	if on and not _sound.playing:
		_sound.play()


func _process(delta: float) -> void:
	var hour := int(Game.clock)
	if hour != _hour:
		if _hour >= 0:
			set_raining(randf() < (Tuning.RAIN_STAY if raining else Tuning.RAIN_START))
		_hour = hour
	wet = move_toward(wet, 1.0 if raining else 0.0, delta / Tuning.RAIN_FADE)
	_sound.volume_db = linear_to_db(maxf(wet, 0.001)) - 4.0
	if wet <= 0.0 and _sound.playing:
		_sound.stop()

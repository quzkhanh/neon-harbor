extends Node
## Autoload `Sfx`: bus âm thanh, phát hiệu ứng (toàn cục hoặc theo vị trí) qua pool player.

const BUSES := ["Music", "SFX"]
const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const UI_SOUNDS := {"ui_click": "res://assets/vendor/sounds/click-a.ogg", "ui_move": "res://assets/vendor/sounds/tap-a.ogg"}
const LOOPS := ["flame", "engine", "siren", "skid"]
const POOL := 10
const POOL_2D := 16
const MAX_DISTANCE := 1400.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _loops: Array[Node] = []
var _next := 0
var _next_2d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.max_distance = MAX_DISTANCE
		add_child(p)
		_players_2d.append(p)


func stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path: String = UI_SOUNDS.get(sound, SFX_DIR % sound)
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamWAV and sound in LOOPS:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_streams[sound] = s
	return _streams[sound]


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	_start(p, sound, volume_db, pitch)


func play_at(sound: String, pos: Vector2, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	p.global_position = pos
	_start(p, sound, volume_db, pitch)


## Player lặp riêng (động cơ, còi, lửa) gắn vào `parent`; tự dừng khi parent bị giải phóng.
func make_loop(sound: String, parent: Node, volume_db := 0.0) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.bus = &"SFX"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.max_distance = MAX_DISTANCE
	parent.add_child(p)
	_loops.append(p)
	p.tree_exiting.connect(func() -> void: _loops.erase(p))
	return p


func set_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Dừng mọi player trước khi thoát để tránh cảnh báo leak AudioStreamPlayback.
func stop_all() -> void:
	for p in _players + _players_2d + _loops:
		p.stop()
		p.stream = null


func _start(p: Node, sound: String, volume_db: float, pitch: float) -> void:
	var s := stream(sound)
	if s == null:
		return
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

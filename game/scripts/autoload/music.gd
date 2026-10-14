extends Node
## Autoload `Music`: một vòng nhạc nền lặp trên bus Music.

const THEME := "res://assets/audio/music/theme.ogg"
const VOLUME_DB := -4.0

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)


func play() -> void:
	if _player.playing or not ResourceLoader.exists(THEME):
		return
	var s: AudioStream = load(THEME)
	if s is AudioStreamOggVorbis:
		s.loop = true
	_player.stream = s
	_player.play()


func stop() -> void:
	_player.stop()
	_player.stream = null

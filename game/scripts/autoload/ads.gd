extends Node
## Autoload `Ads`: nơi duy nhất gọi quảng cáo. Chọn provider bằng `-- --ads=<tên>` (mặc định null).
## Trong lúc quảng cáo chạy: tạm dừng game và tắt tiếng bus Master.

signal ad_started(placement: String)
signal ad_finished(placement: String, completed: bool)

const PROVIDERS := {
	"null": "res://scripts/ads/null_ad_provider.gd",
	"debug": "res://scripts/ads/debug_ad_provider.gd",
}
const PLACEMENTS_REWARDED := ["double_reward", "revive_here"]

var provider: Node
var showing := false
var clock_offset_ms := 0  # để test tua thời gian
var _session_start_ms := 0
var _last_interstitial_ms := -1
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_start_ms = Time.get_ticks_msec()
	var choice := "null"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ads="):
			choice = arg.trim_prefix("--ads=")
	use_provider(choice)


func use_provider(provider_name: String) -> void:
	if provider:
		provider.queue_free()
	provider = load(PROVIDERS.get(provider_name, PROVIDERS["null"])).new()
	provider.name = "Provider"
	add_child(provider)


func now_ms() -> int:
	return Time.get_ticks_msec() + clock_offset_ms


func rewarded_available(placement: String) -> bool:
	return not showing and provider.supports_rewarded() and placement in PLACEMENTS_REWARDED


func interstitial_allowed() -> bool:
	if showing or now_ms() - _session_start_ms < Tuning.AD_INTERSTITIAL_GRACE * 1000.0:
		return false
	return _last_interstitial_ms < 0 or now_ms() - _last_interstitial_ms >= Tuning.AD_INTERSTITIAL_GAP * 1000.0


## Coroutine: true chỉ khi người chơi xem hết.
func show_rewarded(placement: String) -> bool:
	if not rewarded_available(placement):
		return false
	_begin(placement)
	var completed: bool = await provider.show_rewarded(placement)
	_end(placement, completed)
	return completed


## Trả về true nếu quảng cáo thật sự được chiếu (đúng giới hạn tần suất).
func show_interstitial(placement: String) -> bool:
	if not interstitial_allowed():
		return false
	_last_interstitial_ms = now_ms()
	_begin(placement)
	await provider.show_interstitial(placement)
	_end(placement, true)
	return true


func _begin(placement: String) -> void:
	showing = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	AudioServer.set_bus_mute(0, true)
	ad_started.emit(placement)


func _end(placement: String, completed: bool) -> void:
	showing = false
	get_tree().paused = _was_paused
	AudioServer.set_bus_mute(0, false)
	ad_finished.emit(placement, completed)

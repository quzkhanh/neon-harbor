class_name AdProvider
extends Node
## Giao diện chung của provider quảng cáo. Provider mới (SDK thật) kế thừa lớp này
## và đăng ký đường dẫn trong Ads.PROVIDERS; code gameplay chỉ gọi autoload Ads.


func supports_rewarded() -> bool:
	return false


## Coroutine: trả về true chỉ khi người chơi xem hết.
func show_rewarded(_placement: String) -> bool:
	return false


func show_interstitial(_placement: String) -> void:
	pass

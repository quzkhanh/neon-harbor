extends "res://tests/harness.gd"
## Quảng cáo: với DebugAdProvider, rewarded chỉ thưởng khi xem hết; game tạm dừng và tắt tiếng khi quảng cáo chạy;
## interstitial đúng giới hạn tần suất. NullAdProvider ẩn mọi nút xem quảng cáo.

const MINUTE_MS := 60000


func _run() -> void:
	var city := await open_city()
	ads.use_provider("debug")
	await frames(2)
	await _check_pause_and_mute()
	await _check_reward_only_when_watched(city)
	await _check_interstitial_caps()
	ads.use_provider("null")
	await frames(2)
	await _check_null_hides_buttons(city)
	finish("ADS")


## Chạy show_rewarded, bấm nút giả lập sau vài frame. Trả về kết quả.
func _watch(placement: String, finish_it: bool) -> bool:
	var result := [null]
	var run := func() -> void: result[0] = await ads.show_rewarded(placement)
	run.call()
	await frames(3)
	var provider: Node = ads.provider
	if provider.overlay:
		(provider.finish_button if finish_it else provider.skip_button).pressed.emit()
	await frames(3)
	return result[0] == true


func _check_pause_and_mute() -> void:
	var run := func() -> void: await ads.show_rewarded("revive_here")
	run.call()
	await frames(3)
	expect(paused, "quảng cáo đang chạy mà game không tạm dừng")
	expect(AudioServer.is_bus_mute(0), "quảng cáo đang chạy mà không tắt tiếng bus Master")
	ads.provider.skip_button.pressed.emit()
	await frames(3)
	expect(not paused, "quảng cáo xong mà game vẫn tạm dừng")
	expect(not AudioServer.is_bus_mute(0), "quảng cáo xong mà vẫn tắt tiếng")


func _check_reward_only_when_watched(city: Node) -> void:
	expect(not await _watch("double_reward", false), "bỏ dở mà show_rewarded vẫn trả về true")
	expect(await _watch("double_reward", true), "xem hết mà show_rewarded trả về false")
	city.overlays.show_mission_complete(1, 500, [])
	await frames(3)
	var button: Button = _ad_buttons(city)[0]
	var money: int = game.money
	button.pressed.emit()
	await frames(3)
	ads.provider.skip_button.pressed.emit()
	await frames(3)
	expect(game.money == money, "bỏ dở quảng cáo mà vẫn được nhân đôi thưởng")
	button.pressed.emit()
	await frames(3)
	ads.provider.finish_button.pressed.emit()
	await frames(3)
	expect(game.money == money + 500, "xem hết mà không nhân đôi thưởng (%d -> %d)" % [money, game.money])
	city.overlays.current.close()
	await frames(3)


func _check_interstitial_caps() -> void:
	ads.clock_offset_ms = 0
	expect(not await _interstitial(), "interstitial chiếu trong 3 phút đầu phiên")
	ads.clock_offset_ms = 3 * MINUTE_MS + 1000
	expect(await _interstitial(), "interstitial không chiếu sau 3 phút")
	ads.clock_offset_ms += MINUTE_MS
	expect(not await _interstitial(), "interstitial chiếu lại khi chưa đủ 3 phút")
	ads.clock_offset_ms += 2 * MINUTE_MS + 1000
	expect(await _interstitial(), "interstitial không chiếu lại sau 3 phút")


func _interstitial() -> bool:
	var result := [null]
	var run := func() -> void: result[0] = await ads.show_interstitial("after_mission")
	run.call()
	await frames(3)
	if ads.provider.overlay:
		ads.provider.finish_button.pressed.emit()
	await frames(3)
	return result[0] == true


func _check_null_hides_buttons(city: Node) -> void:
	expect(not ads.rewarded_available("double_reward"), "NullAdProvider vẫn báo có rewarded")
	city.overlays.show_mission_complete(1, 500, [])
	await frames(3)
	_expect_hidden(city, "màn hoàn thành nhiệm vụ")
	city.overlays.current.close()
	await frames(2)
	city.player.take_hit(999.0, Vector2.RIGHT, null)
	for i in 200:
		if city.overlays.current != null:
			break
		await frames(1)
	_expect_hidden(city, "màn chết")


func _ad_buttons(city: Node) -> Array:
	return city.overlays.current.get_tree().get_nodes_in_group("ad_button")


func _expect_hidden(city: Node, where: String) -> void:
	var buttons := _ad_buttons(city)
	expect(buttons.size() > 0, "%s: không tìm thấy nút quảng cáo" % where)
	for b in buttons:
		expect(not b.visible, "%s: NullAdProvider mà nút quảng cáo vẫn hiện" % where)

extends "res://tests/harness.gd"
## Ngày/đêm và mưa (đợt 8): giờ chạy và được lưu; trưa sáng hơn nửa đêm, đèn đường mờ ban ngày; mưa làm trời tối hơn,
## mưa tạnh thì khô lại. Chạy: godot --headless --path game -s res://tests/atmosphere.gd


func _run() -> void:
	var city := await open_city()
	var day_night: Node = city.get_node("DayNight")
	var weather: Node = city.get_node("Weather")
	var lamps: Node = city.map.get_node("Lamps")
	var t0: float = game.clock
	await physics(120)
	expect(game.clock > t0 + 0.03, "giờ trong game không chạy (%.3f -> %.3f)" % [t0, game.clock])
	game.clock = 0.0
	await physics(30)
	var night: Color = day_night.color
	expect(day_night.darkness > 0.95 and lamps.modulate.a > 0.95, "nửa đêm mà không tối / đèn không sáng (%.2f, %.2f)" % [day_night.darkness, lamps.modulate.a])
	game.clock = 12.0
	await physics(30)
	var noon: Color = day_night.color
	expect(noon.v > night.v + 0.15 and day_night.darkness < 0.05, "trưa không sáng hơn đêm (%s vs %s)" % [noon, night])
	expect(lamps.modulate.a < 0.3, "giữa trưa đèn đường vẫn sáng (%.2f)" % lamps.modulate.a)
	weather.set_raining(true)
	await physics(60 * 7)
	expect(weather.wet > 0.95, "mưa 7 giây mà đường chưa ướt (%.2f)" % weather.wet)
	expect(day_night.color.v < noon.v - 0.05, "trời mưa mà không tối hơn")
	weather.set_raining(false)
	await physics(60 * 7)
	expect(weather.wet < 0.05, "tạnh 7 giây mà đường chưa khô (%.2f)" % weather.wet)
	game.clock = 15.5
	game.save_game()
	game.clock = 3.0
	game.load_game()
	expect(absf(game.clock - 15.5) < 0.01, "giờ trong game không được lưu (%.2f)" % game.clock)
	finish("ATMOSPHERE")

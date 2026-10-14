extends "res://tests/harness.gd"
## Hoàn thành lần lượt 3 nhiệm vụ qua API kiểm thử (dịch chuyển, hạ mục tiêu).
## Assert tiền tăng đúng, súng mở bán đúng, lưu rồi nạp lại save.json giữ nguyên state,
## chết thì về bệnh viện và mất 10% tiền.

const UNLOCKS := {1: ["smg"], 2: ["rifle", "flamethrower"], 3: ["sniper", "bazooka"]}
const MAX_WAIT := 300


func _run() -> void:
	var city := await open_city()
	for n in [1, 2, 3]:
		city = await _play_mission(city, n)
	expect(game.missions_done == [1, 2, 3], "missions_done sai: %s" % [game.missions_done])
	await _wait(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.ENDING_SCENE, "xong NV3 không sang màn kết")
	_check_save_roundtrip()
	city = await open_city()
	await _check_death(city)
	finish("MISSIONS")


func _play_mission(city: Node, n: int) -> Node:
	var p: Node = city.player
	expect(game.next_mission() == n, "nhiệm vụ kế tiếp phải là %d" % n)
	for id in UNLOCKS[n]:
		expect(not game.is_unlocked(id), "NV%d: %s đã mở bán quá sớm" % [n, id])
	p.global_position = city.missions.giver_pos(n)
	await _wait(func() -> bool: return city.overlays.current != null, "NV%d: không mở hội thoại" % n)
	await close_overlays(city)
	await _wait(func() -> bool: return city.missions.current != null, "NV%d: không bắt đầu" % n)
	var mission: Node = city.missions.current
	match n:
		1:
			p.enter_vehicle(mission.bike)
			await frames(5)
			mission.bike.global_position = mission.cell_pos("d")
		2:
			for g in get_nodes_in_group("gang"):
				g.take_hit(999.0, Vector2.RIGHT, p)
			await frames(5)
			expect(game.objective == "M2_OBJ_CASE", "NV2: chưa hiện mục tiêu nhặt vali (%s)" % game.objective)
			p.global_position = mission.cell_pos("r")
			await _wait(func() -> bool: return game.objective == "M2_OBJ_RETURN", "NV2: không nhặt được vali")
			p.global_position = mission.cell_pos("2")
		3:
			p.enter_vehicle(mission.car)
			await frames(5)
			expect(game.stars == 2, "NV3: cướp xe phải lên 2 sao (đang %d)" % game.stars)
			game.clear_wanted()
			await frames(5)
			expect(game.objective == "M3_OBJ_GARAGE", "NV3: cắt đuôi xong chưa hiện mục tiêu gara (%s)" % game.objective)
			mission.car.global_position = mission.cell_pos("G")
	var money_before: int = game.money
	await _wait(func() -> bool: return city.missions.current == null, "NV%d: không hoàn thành" % n)
	await _wait(func() -> bool: return city.overlays.current != null, "NV%d: không có hội thoại kết" % n)
	await close_overlays(city)
	var reward := int(game.mission(n).reward)
	expect(game.money == money_before + reward, "NV%d: tiền %d, mong đợi %d" % [n, game.money, money_before + reward])
	expect(n in game.missions_done, "NV%d chưa được ghi là xong" % n)
	for id in UNLOCKS[n]:
		expect(game.is_unlocked(id), "NV%d: %s chưa mở bán" % [n, id])
	await frames(30)
	return current_scene


func _check_save_roundtrip() -> void:
	game.owned["smg"] = {"mag": 7, "reserve": 33}
	game.settings.lang = "vi"
	game.save_game()
	var snapshot := [game.money, game.owned.duplicate(true), game.missions_done.duplicate(), game.settings.duplicate()]
	game.reset_progress()
	game.settings.lang = "en"
	game.load_game()
	var after := [game.money, game.owned, game.missions_done, game.settings]
	expect(snapshot[0] == after[0], "lưu/nạp: tiền %s != %s" % [snapshot[0], after[0]])
	expect(snapshot[1] == after[1], "lưu/nạp: súng/đạn %s != %s" % [snapshot[1], after[1]])
	expect(snapshot[2] == after[2], "lưu/nạp: nhiệm vụ %s != %s" % [snapshot[2], after[2]])
	expect(snapshot[3] == after[3], "lưu/nạp: cài đặt %s != %s" % [snapshot[3], after[3]])
	game.set_setting("lang", "en")


func _check_death(city: Node) -> void:
	game.add_money(1000 - game.money)
	game.set_stars(2)
	var p: Node = city.player
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current != null, "chết: không hiện màn chết")
	city.overlays.current.close(false)
	await frames(5)
	var hospital: Vector2 = city.missions.cell_pos_of("H")
	expect(p.alive, "chết: không hồi sinh")
	expect(p.global_position.distance_to(hospital) < 10.0, "chết: không về bệnh viện (%s)" % p.global_position)
	expect(game.money == 900, "chết: tiền %d, mong đợi 900 (mất 10%%)" % game.money)
	expect(game.stars == 0, "chết: vẫn còn %d sao" % game.stars)


func _wait(cond: Callable, message: String) -> void:
	for i in MAX_WAIT:
		if cond.call():
			return
		await frames(1)
	expect(false, message)

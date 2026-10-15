class_name Overlays
extends Node
## Mở các lớp phủ trong thành phố (tạm dừng game khi mở): tạm dừng, hội thoại, cửa hàng,
## hoàn thành nhiệm vụ, màn chết. Mỗi lần chỉ một lớp phủ.

const SHOP_SCENE := "res://scenes/shop.tscn"

var city: City
var current: Modal


func _init(c: City) -> void:
	city = c
	name = "Overlays"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if current != null:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		show_pause()
	elif event.is_action_pressed("map") and city.player.alive:
		get_viewport().set_input_as_handled()
		await open(MapScreen.new(city))


## Mở lớp phủ, chờ đóng, trả về kết quả.
func open(modal: Modal) -> Variant:
	if current:
		current.close()
	current = modal
	get_tree().paused = true
	city.add_child(modal)
	var result: Variant = await modal.closed
	if current == modal:
		current = null
		get_tree().paused = false
	return result


func show_pause() -> void:
	var choice: Variant = await open(PauseMenu.new())
	match choice:
		"help":
			await open(HelpPanel.new())
			show_pause()
		"settings":
			await open(SettingsPanel.new())
			show_pause()
		"stats":
			await open(StatsPanel.new())
			show_pause()
		"menu":
			Game.save_game()
			Game.go(Game.MENU_SCENE)


func show_dialog(lines: Array) -> void:
	await open(DialogBox.new(lines))


func show_shop() -> void:
	await open(load(SHOP_SCENE).instantiate())


func show_mission_complete(n: int, reward: int, unlocked: Array) -> void:
	await open(MissionComplete.new(n, reward, unlocked))


func show_death() -> void:
	var choice: DeathScreen.Revive = await open(DeathScreen.new(city.missions.retry_mission > 0, city.properties.has_home()))
	if choice == DeathScreen.Revive.JAIL:
		await open(JailScreen.new())
	city.respawn(choice)

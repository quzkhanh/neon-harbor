class_name StatsPanel
extends Modal
## Thống kê (từ menu tạm dừng): % hoàn thành, các chỉ số chơi, và danh sách thành tựu (đạt / chưa đạt).

const PX_PER_KM := 16000.0  # 1 ô 64 px coi như 4 m


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size = Vector2(860, 0)
	content.add_child(Ui.label("STATS_TITLE", "HeaderLabel"))
	content.add_child(Ui.live_label("STATS_COMPLETION", func() -> Dictionary: return {"pct": Achievements.completion()}, "MoneyLabel"))
	var body := Ui.hbox(28)
	content.add_child(body)
	var left := Ui.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var rows := [
		["STATS_MISSIONS", "%d / %d" % [Game.missions_done.size(), Game.mission_count()]],
		["STATS_KILLS", str(Game.stat("kills"))],
		["STATS_WALKED", I18n.fmt("STATS_KM", {"km": "%.1f" % (Game.stat("walk_px") / PX_PER_KM)})],
		["STATS_DRIVEN", I18n.fmt("STATS_KM", {"km": "%.1f" % (Game.stat("drive_px") / PX_PER_KM)})],
		["STATS_MAX_STARS", str(Game.stat("max_stars"))],
		["STATS_RACES", str(Game.stat("races_won"))],
		["STATS_JOBS", str(Game.stat("deliveries") + Game.stat("fares") + Game.stat("criminals") + Game.stat("sweeps"))],
		["STATS_TOKENS", "%d / %d" % [Achievements.value("tokens"), Achievements.LIST.collector[1]]],
		["STATS_JUMPS", "%d / %d" % [Achievements.value("jump_ids"), Achievements.LIST.stuntman[1]]],
		["STATS_PLAYTIME", "%d:%02d" % [floori(Game.stat("play_s") / 3600.0), floori(Game.stat("play_s") / 60.0) % 60]],
	]
	for r in rows:
		left.add_child(_row(r[0], r[1]))
	var right := Ui.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(Ui.label("STATS_ACHIEVEMENTS", "SubLabel", HORIZONTAL_ALIGNMENT_LEFT))
	for id in Achievements.LIST:
		var got := Game.marked("achievements").has(id)
		var l := Ui.label(Achievements.LIST[id][2], "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
		l.modulate = Palette.GOLD if got else Palette.TEXT_MUTED
		right.add_child(l)
	button_column(["STATS_CLOSE"])[0].pressed.connect(close)


func _row(key: String, value: String) -> Control:
	var row := Ui.hbox(12)
	var label := Ui.label(key, "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var v := Ui.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.text = value
	row.add_child(v)
	return row

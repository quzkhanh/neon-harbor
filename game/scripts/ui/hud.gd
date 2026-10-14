class_name Hud
extends CanvasLayer
## HUD: trên trái máu/giáp/tiền, trên phải sao truy nã, dưới phải súng/đạn, dưới trái minimap,
## giữa trên mục tiêu nhiệm vụ, giữa dưới gợi ý thao tác và thông báo.

const ICON_DIR := "res://assets/sprites/ui/%s.png"
const WEAPON_ICON := "res://assets/sprites/weapons/icon_%s.png"
const STAR := "res://assets/vendor/ui/star.png"
const STAR_EMPTY := "res://assets/vendor/ui/star_outline.png"
const MARGIN := 20
const NOTICE_TIME := 3.5
const MAX_NOTICES := 3

var city: City
var _health: ProgressBar
var _armor: ProgressBar
var _money: Label
var _stars: Array[TextureRect] = []
var _objective: LiveLabel
var _objective_panel: PanelContainer
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ammo: LiveLabel
var _prompt: LiveLabel
var _prompt_panel: PanelContainer
var _notices: VBoxContainer


func _init(c: City) -> void:
	city = c
	name = "Hud"
	layer = 10


func _ready() -> void:
	add_to_group("hud")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(root)
	_build_vitals(root)
	var top_right := _build_stars(root)
	_build_objective(root)
	_build_weapon(top_right if TouchControls.wanted() else root)
	var mini := PanelContainer.new()
	mini.theme_type_variation = "HudPanel"
	mini.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Có joystick ảo ở hai góc dưới thì dời minimap và thẻ súng lên giữa.
	var touch := TouchControls.wanted()
	mini.size_flags_vertical = Control.SIZE_SHRINK_CENTER if touch else Control.SIZE_SHRINK_END
	mini.add_child(Minimap.new(city))
	root.add_child(mini)
	_build_bottom_center(root)
	Game.vitals_changed.connect(_on_vitals)
	Game.money_changed.connect(func(_m: int) -> void: _money.text = I18n.money(Game.money))
	Game.weapons_changed.connect(_on_weapon)
	Game.wanted_changed.connect(_on_wanted)
	Game.objective_changed.connect(_on_objective)
	Game.notice.connect(show_notice)
	I18n.language_changed.connect(func(_l: String) -> void: _refresh_all())
	_refresh_all()


func _refresh_all() -> void:
	_on_vitals()
	_money.text = I18n.money(Game.money)
	_on_weapon()
	_on_wanted(Game.stars)
	_on_objective()


func _corner(parent: Control, h: Control.SizeFlags, v: Control.SizeFlags, variation := "HudPanel") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.size_flags_horizontal = h
	panel.size_flags_vertical = v
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var box := Ui.vbox(6)
	panel.add_child(box)
	return box


func _build_vitals(root: Control) -> void:
	var box := _corner(root, Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_BEGIN)
	_health = _bar_row(box, "icon_health", "HealthBar", Tuning.MAX_HEALTH)
	_armor = _bar_row(box, "icon_armor", "ArmorBar", Tuning.MAX_ARMOR)
	var row := Ui.hbox(8)
	row.add_child(Ui.texture(ICON_DIR % "icon_money", Vector2(26, 26)))
	_money = Ui.label("", "MoneyLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_money.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(_money)
	box.add_child(row)


func _bar_row(box: Control, icon: String, variation: String, max_value: float) -> ProgressBar:
	var row := Ui.hbox(8)
	row.add_child(Ui.texture(ICON_DIR % icon, Vector2(26, 26)))
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.max_value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(190, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	box.add_child(row)
	return bar


## Góc trên phải: hàng sao (và thẻ súng khi có điều khiển cảm ứng).
func _build_stars(root: Control) -> VBoxContainer:
	var col := Ui.vbox(10)
	col.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(col)
	var row := Ui.hbox(4)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	for i in Tuning.MAX_STARS:
		var star := Ui.texture(STAR_EMPTY, Vector2(42, 40))
		row.add_child(star)
		_stars.append(star)
	col.add_child(row)
	return col


func _build_objective(root: Control) -> void:
	var box := _corner(root, Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_BEGIN)
	_objective_panel = box.get_parent()
	_objective = Ui.live_label("", func() -> Dictionary: return Game.objective_params, "HudLabel")
	box.add_child(_objective)


func _build_weapon(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(panel)
	var row := Ui.hbox(14)
	panel.add_child(row)
	var well := PanelContainer.new()
	well.theme_type_variation = "IconWell"
	row.add_child(well)
	_weapon_icon = Ui.texture("", Vector2(112, 56))
	well.add_child(_weapon_icon)
	var col := Ui.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_weapon_name = Ui.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	col.add_child(_weapon_name)
	_ammo = Ui.live_label("HUD_AMMO", _ammo_params, "HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	col.add_child(_ammo)


func _ammo_params() -> Dictionary:
	var a := Game.ammo()
	var reserve: String = tr("AMMO_INFINITE") if int(a.reserve) < 0 else str(int(a.reserve))
	return {"mag": int(a.mag), "reserve": reserve}


func _build_bottom_center(root: Control) -> void:
	var col := Ui.vbox(8)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	_notices = Ui.vbox(6)
	col.add_child(_notices)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.theme_type_variation = "HudPanel"
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_prompt_panel)
	_prompt = Ui.live_label("", _prompt_params, "HintLabel")
	_prompt_panel.add_child(_prompt)


func _prompt_params() -> Dictionary:
	var params := city.interactions.prompt_params.duplicate()
	params["key"] = InputSetup.key_label(&"interact")
	return params


func _process(_delta: float) -> void:
	var key := city.interactions.prompt
	if key != _prompt.key or key != "":
		_prompt.setup(key)
	_prompt_panel.visible = key != ""
	var searching := Game.stars > 0 and city.police.unseen > 0.0
	var blink := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.006))
	for i in _stars.size():
		_stars[i].modulate.a = blink if searching and i < Game.stars else 1.0


func _on_vitals() -> void:
	_health.value = Game.health
	_armor.value = Game.armor


func _on_weapon() -> void:
	var w := Game.weapon_def()
	_weapon_icon.texture = load(WEAPON_ICON % w.id)
	_weapon_name.text = w.name
	_ammo.refresh()


func _on_wanted(stars: int) -> void:
	for i in _stars.size():
		_stars[i].texture = load(STAR if i < stars else STAR_EMPTY)


func _on_objective() -> void:
	_objective.setup(Game.objective)
	_objective_panel.visible = Game.objective != ""


func show_notice(text: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Ui.label("", "HintLabel")
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	panel.add_child(l)
	_notices.add_child(panel)
	while _notices.get_child_count() > MAX_NOTICES:
		_notices.get_child(0).free()
	var t := panel.create_tween()
	t.tween_interval(NOTICE_TIME)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(panel.queue_free)

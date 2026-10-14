class_name AdOverlay
extends Object
## Lớp phủ quảng cáo giả lập của DebugAdProvider.

const LAYER := 110


static func build(placement: String, rewarded: bool) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	var dim := ColorRect.new()
	dim.color = Palette.BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := Ui.vbox(18)
	panel.add_child(box)
	var badge := Ui.label("AD_BADGE", "TitleLabel")
	badge.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(badge)
	box.add_child(Ui.label("AD_REWARDED" if rewarded else "AD_INTERSTITIAL", "SubLabel"))
	box.add_child(Ui.live_label("AD_PLACEMENT", func() -> Dictionary: return {"placement": placement}, "SmallLabel"))
	var bar := ProgressBar.new()
	bar.name = "Progress"
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	box.add_child(bar)
	var row := Ui.hbox(14)
	box.add_child(row)
	var finish := Ui.button("AD_FINISH", "AccentButton")
	finish.name = "Finish"
	row.add_child(finish)
	var skip := Ui.button("AD_SKIP")
	skip.name = "Skip"
	row.add_child(skip)
	finish.grab_focus.call_deferred()
	return layer

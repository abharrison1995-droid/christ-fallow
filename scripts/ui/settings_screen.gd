extends "res://scripts/ui/menu_overlay.gd"

signal closed

var _feedback: Label
var _rows: VBoxContainer


func _ready() -> void:
	setup("Settings", Vector2(750, 603))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 408
	content.add_child(tabs)
	_rows = _tab(tabs, "Display")
	_toggle("Fullscreen", "fullscreen")
	_slider("Interface scale", "ui_scale", 0.9, 1.1, 0.05)
	_slider("World brightness", "brightness", 1.0, 1.5, 0.05)
	_toggle("PSX world filter", "psx")
	_toggle("Reduce interface motion", "reduced_motion")
	_rows = _tab(tabs, "Audio")
	_slider("Master volume", "master", 0.0, 1.0, 0.05)
	_slider("Title ambience", "ambience", 0.0, 1.0, 0.05)
	_rows = _tab(tabs, "Controls")
	for binding in [
		["Move / Sprint / Dodge", "WASD or Arrows / Shift / Space"],
		["Orbit / Zoom", "Right drag / Wheel"],
		["Cleave / Javelin / Blessing / Interact", "LMB / F or RMB / Q / E"],
		["Inspect friendly or wounded unit", "Left-Click on unit"],
		["Build / Colony / Faith / Diplomacy", "B / C / R (outside build) / V"],
		["Place / Continuous / Rotate / Cancel", "LMB / Shift + LMB / T / RMB or Esc"],
		["Command / Pause", "Tab or M / P or Esc"],
		["Select squad / Orders / Warhorn", "1–6 / F1–F6 / H"],
		["Quick Save / Quick Load", "F9 / F10"],
	]:
		_row(binding[0]).add_child(Look.label(binding[1], &"QuietLabel"))
	_feedback = Look.label("", &"QuietLabel")
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_feedback)
	var done := Look.button("Done", _close, &"PrimaryButton")
	footer.add_child(done)
	tabs.get_tab_bar().grab_focus()


func _tab(tabs: TabContainer, caption: String) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.name = caption
	rows.add_theme_constant_override("separation", 12)
	tabs.add_child(rows)
	return rows


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if Preferences.save():
		closed.emit()
	else:
		_feedback.text = "Preferences could not be saved."
		_feedback.modulate = Look.DANGER


func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Look.label(caption)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_rows.add_child(row)
	return row


func _toggle(caption: String, key: String) -> void:
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.custom_minimum_size.x = 78
	toggle.button_pressed = bool(Preferences.get_value(key))
	toggle.text = "On" if toggle.button_pressed else "Off"
	toggle.tooltip_text = caption
	toggle.toggled.connect(func(value: bool):
		toggle.text = "On" if value else "Off"
		Preferences.set_value(key, value)
	)
	_row(caption).add_child(toggle)


func _slider(caption: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var row := _row(caption)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(Preferences.get_value(key))
	slider.custom_minimum_size.x = 220
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = caption
	row.add_child(slider)
	var value_label := Look.label("%d%%" % roundi(slider.value * 100.0), &"QuietLabel")
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float):
		value_label.text = "%d%%" % roundi(value * 100.0)
		Preferences.set_value(key, value)
	)

extends Control

signal cover_requested
signal uncover_requested

const Look = preload("res://scripts/ui/fallow_theme.gd")
const Overlay = preload("res://scripts/ui/menu_overlay.gd")
const Settings = preload("res://scripts/ui/settings_screen.gd")

var _pause_screen: Control
var _settings: Control
var _confirmation: Control
var _pause_status: Label
var _pause_resume: Button
var _conquest_first_choice: Button
var _results_action: Button

var _conquest_panel: Control
var _conquest_label: Label = null
var _conquest_target_fid: int = -1

var _endgame_panel: Control
var _endgame_body: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_pause_screen()
	_build_conquest_modal()
	_build_endgame_modal()
	GameState.conquest_triggered.connect(_on_conquest_triggered)
	GameState.victory_achieved.connect(_on_victory)
	GameState.defeat_triggered.connect(_on_defeat)


func blocks_world_input() -> bool:
	return is_pause_visible() or captures_gameplay_shortcuts()


func captures_gameplay_shortcuts() -> bool:
	return _settings != null or _confirmation != null or _conquest_panel.visible or _endgame_panel.visible


func dismiss_confirmation() -> bool:
	if _confirmation == null:
		return false
	_close_confirmation()
	return true


func is_pause_visible() -> bool:
	return _pause_screen.visible


func reset() -> void:
	_clear_settings()
	_close_confirmation()
	_pause_screen.hide()
	_endgame_panel.hide()
	_conquest_panel.hide()
	_conquest_target_fid = -1


func _build_pause_screen() -> void:
	_pause_screen = Overlay.new()
	add_child(_pause_screen)
	_pause_screen.setup("Campaign Paused", Vector2(530, 495))
	_pause_screen.hide()
	_pause_resume = _pause_action("Resume Campaign", toggle_pause, &"PrimaryButton")
	_pause_action("Save Campaign   F9", save_campaign)
	_pause_action("Load Campaign", _confirm_load)
	_pause_action("Settings", _open_settings)
	_pause_action("Return to Title", _confirm_title)
	_pause_status = Look.label("", &"QuietLabel")
	_pause_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_screen.content.add_child(_pause_status)


func _pause_action(caption: String, action: Callable, style: StringName = &"MenuButtonRow") -> Button:
	var button := Look.button(caption, action, style)
	button.custom_minimum_size.y = 46
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pause_screen.content.add_child(button)
	return button


func save_campaign() -> void:
	if GameState.save_game():
		_pause_status.text = "Campaign saved."
	else:
		_pause_status.text = "The campaign could not be saved."


func set_pause_status(message: String) -> void:
	if _pause_status != null:
		_pause_status.text = message


func quick_load_campaign() -> bool:
	if GameState.load_game():
		return true
	if is_pause_visible():
		var result: Dictionary = GameState.read_campaign_save()
		set_pause_status(str(result.get("error", "The campaign could not be loaded.")))
	return false


func _open_settings() -> void:
	_pause_screen.hide()
	_settings = Settings.new()
	_settings.closed.connect(func():
		_clear_settings()
		_pause_screen.show()
		_pause_resume.grab_focus()
	)
	add_child(_settings)


func _clear_settings() -> void:
	if _settings != null:
		remove_child(_settings)
		_settings.queue_free()
		_settings = null


func _confirm_load() -> void:
	var result := GameState.read_campaign_save()
	if result.has("error"):
		_pause_status.text = result["error"]
		return
	_show_confirmation("Load Campaign", "Load your save and discard progress made since it was written?", "Load Campaign", func():
		if not GameState.load_game():
			_pause_status.text = "The campaign could not be loaded."
	)


func _confirm_title() -> void:
	_show_confirmation("Return to Title", "Progress since your last save will be lost.", "Return to Title", _return_to_title)


func _show_confirmation(title: String, message: String, caption: String, action: Callable) -> void:
	_pause_screen.hide()
	_confirmation = Overlay.new()
	add_child(_confirmation)
	_confirmation.setup(title, Vector2(570, 260))
	var description := Look.label(message, &"QuietLabel")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation.content.add_child(description)
	var cancel := Look.button("Cancel", _close_confirmation)
	_confirmation.footer.add_child(cancel)
	_confirmation.footer.add_child(Look.button(caption, func():
		_close_confirmation()
		action.call()
	))
	cancel.grab_focus()


func _close_confirmation() -> void:
	if _confirmation == null:
		return
	remove_child(_confirmation)
	_confirmation.queue_free()
	_confirmation = null
	_pause_screen.show()
	_pause_resume.grab_focus()


func _return_to_title() -> void:
	if not GameState.title_requested.get_connections().is_empty():
		GameState.title_requested.emit()
	else:
		GameState.end_campaign()
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _build_conquest_modal() -> void:
	_conquest_panel = Overlay.new()
	add_child(_conquest_panel)
	_conquest_panel.setup("The Fallen Tribe", Vector2(700, 455))
	_conquest_panel.hide()
	_conquest_label = Look.label("", &"QuietLabel")
	_conquest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conquest_panel.content.add_child(_conquest_label)
	var choices := [
		["Assimilate Survivors", "Bring their people and buildings into your tribe.", "ASSIMILATE"],
		["Make a Tributary", "Keep the tribe as an ally and receive tribute.", "TRIBUTARY"],
		["Raze and Loot", "Destroy the settlement and seize its stockpiles.", "RAZE"],
	]
	for choice in choices:
		var key: String = choice[2]
		var button := Look.button(choice[0], func(): _finish_conquest(key), &"MenuButtonRow")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_conquest_panel.content.add_child(button)
		_conquest_panel.content.add_child(Look.label(choice[1], &"QuietLabel", 14))
		if _conquest_first_choice == null:
			_conquest_first_choice = button


func _on_conquest_triggered(target_fid: int) -> void:
	if not GameState.factions.has(target_fid):
		return
	_clear_settings()
	_close_confirmation()
	_pause_screen.hide()
	cover_requested.emit()
	_conquest_target_fid = target_fid
	var faction: Dictionary = GameState.factions[target_fid]
	_conquest_label.text = "%s has fallen. Decide the fate of the settlement." % faction["name"]
	_conquest_panel.show()
	_conquest_first_choice.grab_focus()


func _finish_conquest(choice: String) -> void:
	var target_fid := _conquest_target_fid
	_conquest_target_fid = -1
	_conquest_panel.hide()
	if target_fid > 0:
		GameState.resolve_conquest(target_fid, choice)
	if GameState.campaign_finished or _conquest_panel.visible:
		return
	if GameState.is_paused:
		_pause_screen.show()
		_pause_resume.grab_focus()
	else:
		uncover_requested.emit()


func _build_endgame_modal() -> void:
	_endgame_panel = Overlay.new()
	add_child(_endgame_panel)
	_endgame_panel.setup("", Vector2(640, 310))
	_endgame_panel.hide()
	_endgame_body = Look.label("", &"QuietLabel")
	_endgame_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_endgame_panel.content.add_child(_endgame_body)
	_results_action = Look.button("Return to Title", _return_to_title, &"PrimaryButton")
	_endgame_panel.footer.add_child(_results_action)


func _on_victory(reason: String) -> void:
	_show_results("The Valley United", reason, Look.GOLD)


func _on_defeat(reason: String) -> void:
	_show_results("The Tribe Has Fallen", reason, Look.DANGER)


func _show_results(title: String, reason: String, color: Color) -> void:
	_clear_settings()
	_close_confirmation()
	_pause_screen.hide()
	_conquest_panel.hide()
	cover_requested.emit()
	_endgame_panel.title_label.text = title
	_endgame_panel.title_label.modulate = color
	_endgame_body.text = reason
	_endgame_panel.show()
	_results_action.grab_focus()


func toggle_pause() -> void:
	if _conquest_panel.visible or GameState.campaign_finished or _settings != null or _confirmation != null:
		return
	var resume := _pause_screen.visible
	if not GameState.set_manual_pause(not resume):
		return
	if resume:
		_pause_screen.hide()
		uncover_requested.emit()
	else:
		cover_requested.emit()
		_pause_status.text = ""
		_pause_screen.show()
		_pause_resume.grab_focus()

extends Node

const Look = preload("res://scripts/ui/fallow_theme.gd")
const Overlay = preload("res://scripts/ui/menu_overlay.gd")
const Awakening = preload("res://scripts/ui/awakening_screen.gd")
const Settings = preload("res://scripts/ui/settings_screen.gd")
const Embers = preload("res://scripts/ui/title_embers.gd")
const CampaignSession = preload("res://scripts/systems/campaign_session.gd")
const ART := "res://assets/ui/valley_dawn.png"
const AMBIENCE := "res://assets/ui/title_ambience.wav"

var _title: Control
var _stack: VBoxContainer
var _buttons: VBoxContainer
var _start: Button
var _continue: Button
var _new_game: Button
var _save_hint: Label
var _status: Label
var _page: Control
var _page_trigger: Control
var _session: Node
var _ambience: AudioStreamPlayer
var _launching := false
var _menu_open := false
var _quitting := false


func _ready() -> void:
	_session = CampaignSession.new()
	_session.title_restored.connect(_return_to_title)
	add_child(_session)
	get_tree().auto_accept_quit = false
	_build_title()
	_show_start()
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(AMBIENCE):
		_ambience = AudioStreamPlayer.new()
		var loop := load(AMBIENCE).duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_ambience.stream = loop
		add_child(_ambience)
		Preferences.changed.connect(_update_ambience)
		_update_ambience()
		_ambience.play()


func _exit_tree() -> void:
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
		# Give the mixer time to drop the stopped playback before normal shutdown.
		await get_tree().create_timer(maxf(0.05, AudioServer.get_output_latency())).timeout
	get_tree().quit()


func _build_title() -> void:
	_title = Control.new()
	_title.name = "TitleInterface"
	_title.theme = Look.create()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title)
	var backdrop := ColorRect.new()
	backdrop.color = Color("222a24")
	_fill(backdrop)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(ART):
		art.texture = load(ART)
	_fill(art)
	var shading := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.57, 1.0])
	gradient.colors = PackedColorArray([Color(0.035, 0.054, 0.043, 0.97), Color(0.035, 0.054, 0.043, 0.78), Color(0.035, 0.054, 0.043, 0.15), Color(0.035, 0.054, 0.043, 0.03)])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.width = 768
	shade_texture.height = 2
	shading.texture = shade_texture
	shading.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill(shading)
	_fill(Embers.new())

	_stack = VBoxContainer.new()
	_stack.anchor_top = 0.145
	_stack.offset_left = 106.0
	_stack.offset_right = 502.0
	_stack.add_theme_constant_override("separation", 0)
	_title.add_child(_stack)
	var logo := Look.label("CHRIST\nFALLOW", &"DisplayTitle", 100)
	logo.add_theme_constant_override("line_spacing", -30)
	logo.add_theme_color_override("font_shadow_color", Color(0.025, 0.03, 0.025, 0.95))
	logo.add_theme_constant_override("shadow_offset_y", 3)
	_stack.add_child(logo)
	var rule := ColorRect.new()
	rule.color = Look.GOLD
	rule.custom_minimum_size = Vector2(94, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(gap)
	_start = _menu_button("Start", _show_main_menu, _stack, &"PrimaryButton")
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_stack.add_child(_buttons)
	_continue = _menu_button("Continue", func(): _begin_campaign(true), _buttons)
	_new_game = _menu_button("New Game", _show_awakening, _buttons)
	_menu_button("Load Game", _show_load, _buttons)
	_menu_button("Settings", _show_settings, _buttons)
	_menu_button("Quit", _quit_game, _buttons)
	_save_hint = Look.label("", &"QuietLabel", 14)
	_save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buttons.add_child(_save_hint)
	_status = Look.label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_status)


func _fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(control)


func _menu_button(caption: String, action: Callable, parent: VBoxContainer, style: StringName = &"MenuButtonRow") -> Button:
	var result := Look.button(caption, action, style)
	result.custom_minimum_size.y = 49
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(result)
	return result


func _show_start() -> void:
	_menu_open = false
	_buttons.hide()
	_start.show()
	_start.grab_focus()


func _show_main_menu() -> void:
	_menu_open = true
	_start.hide()
	_buttons.show()
	_refresh_save()
	if _continue.disabled:
		_new_game.grab_focus()
	else:
		_continue.grab_focus()
	if not bool(Preferences.get_value("reduced_motion")):
		_buttons.modulate.a = 0.3
		create_tween().tween_property(_buttons, "modulate:a", 1.0, 0.18)


func _refresh_save() -> void:
	var result := GameState.read_campaign_save()
	_continue.disabled = result.has("error")
	_save_hint.text = str(result.get("error", ""))
	_save_hint.visible = _continue.disabled


func _add_page(page: Control) -> void:
	_page_trigger = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_page):
		_title.remove_child(_page)
		_page.queue_free()
	_page = page
	_stack.hide()
	_title.add_child(_page)


func _close_page() -> void:
	_title.remove_child(_page)
	_page.queue_free()
	_page = null
	_stack.show()
	if is_instance_valid(_page_trigger):
		_page_trigger.grab_focus()


func _show_awakening() -> void:
	var page := Awakening.new()
	page.closed.connect(_close_page)
	page.campaign_selected.connect(func(leader: String, tribe: String, lineage: int):
		_begin_campaign(false, leader, tribe, lineage)
	)
	_add_page(page)


func _show_settings() -> void:
	var page := Settings.new()
	page.closed.connect(_close_page)
	_add_page(page)


func _show_load() -> void:
	var page := Overlay.new()
	_add_page(page)
	page.setup("Load Game", Vector2(650, 330))
	var result := GameState.read_campaign_save()
	var back := Look.button("Back", _close_page)
	page.footer.add_child(back)
	if result.has("error"):
		page.content.add_child(Look.label(result["error"], &"QuietLabel"))
		back.grab_focus()
		return
	var data: Dictionary = result["data"]
	page.content.add_child(Look.label(data["factions"][0]["name"], &"SectionTitle"))
	page.content.add_child(Look.label("Day %d  ·  %s" % [data["day_count"], data["factions"][0]["leader_name"]]))
	var saved := Time.get_datetime_string_from_unix_time(int(result["modified"]), true)
	page.content.add_child(Look.label("Saved %s UTC" % saved, &"QuietLabel"))
	var load_button := Look.button("Load Campaign", func(): _begin_campaign(true), &"PrimaryButton")
	page.footer.add_child(load_button)
	load_button.grab_focus()


func _begin_campaign(load_saved: bool, leader: String = "", tribe: String = "", lineage: int = 0) -> void:
	if _launching or _quitting:
		return
	_launching = true
	if is_instance_valid(_page):
		_close_page()
	_buttons.hide()
	_status.text = "Loading campaign…" if load_saved else "Entering the valley…"
	# Present the loading status before constructing the world on the main thread.
	await get_tree().process_frame
	await get_tree().process_frame
	if _quitting:
		return
	if not _session.launch(load_saved, leader, tribe, lineage):
		_launching = false
		_show_main_menu()
		_status.text = "The campaign could not be loaded. Open Load Game for details."
		return
	_title.hide()
	if _ambience != null:
		_ambience.stop()
	_launching = false


func _return_to_title() -> void:
	_status.text = ""
	_title.show()
	_show_main_menu()
	if _ambience != null:
		_ambience.play()


func _update_ambience() -> void:
	var volume := float(Preferences.get_value("ambience"))
	_ambience.volume_db = linear_to_db(maxf(volume, 0.001))
	_ambience.stream_paused = volume <= 0.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not _title.visible or _launching or not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(_page):
		# Settings owns Escape because it needs to persist its changes first.
		if _page.get_script() == Overlay:
			_close_page()
	elif _menu_open:
		_show_start()

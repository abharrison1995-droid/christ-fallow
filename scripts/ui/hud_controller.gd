extends Control

const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const HUDDrawers = preload("res://scripts/ui/hud_drawers.gd")
const Look = preload("res://scripts/ui/fallow_theme.gd")
const CampaignOverlays = preload("res://scripts/ui/campaign_overlays.gd")
const Inspector = preload("res://scripts/ui/unit_inspector.gd")
const WorldMap = preload("res://scripts/ui/world_map_overlay.gd")
const DRAWERS := {
	"BUILD": preload("res://scripts/ui/drawers/build_drawer.gd"),
	"COLONY": preload("res://scripts/ui/drawers/colony_drawer.gd"),
	"RELIGION": preload("res://scripts/ui/drawers/faith_drawer.gd"),
	"DIPLOMACY": preload("res://scripts/ui/drawers/diplomacy_drawer.gd"),
	"MENU": preload("res://scripts/ui/drawers/command_drawer.gd"),
}

const DRAWER_LINKS := [
	["Build", "B", "BUILD"], ["Colony", "C", "COLONY"],
	["Faith", "R", "RELIGION"], ["Diplomacy", "V", "DIPLOMACY"], ["Command", "Tab", "MENU"],
]

var _overlays: Control
var _world_map: WorldMap
var _event_panel: PanelContainer
var _latest_event: Label
var _event_toggle: Button
var _event_expanded := false
var _resource_values: Dictionary = {}
var _drawer_links: Dictionary = {}
var _drawer_scroll: ScrollContainer
var _drawer_close: Button
var _drawer_views: Dictionary = {}
var _raid_panel: PanelContainer
var _leader_hp_label: Label

var _top_bar: PanelContainer = null
var _clock_label: Label = null
var _pop_label: Label = null
var _stock_label: Label = null
var _pause_btn: Button = null
var _objective_panel: PanelContainer = null
var _objective_label: Label = null
var _grace_label: Label = null

var _tutorial_panel: PanelContainer = null
var _tutorial_title: Label = null
var _tutorial_body: Label = null
var _tutorial_progress: Label = null
var _highlighted_hud_tab: String = ""
var _highlight_style: StyleBoxFlat = null

var _build_banner: PanelContainer = null
var _build_banner_label: Label = null

var _minimap_panel: PanelContainer = null
var _raid_banner: Label = null
var _raid_banner_timer: float = 0.0

var _log_box: RichTextLabel = null
var _squad_bar: PanelContainer = null
var _squad_btns: Dictionary = {}
var _order_btns: Dictionary = {}
var _fire_btn: Button = null
var _warhorn_btn: Button = null
var _leader_hp_bar: ProgressBar = null
var _blessing_label: Label = null

var _drawer_panel: PanelContainer = null
var _drawer_title: Label = null
var _drawer_content: VBoxContainer = null
var _active_tab: String = ""

var _ui_refresh_timer: float = 0.0
var _inspector_panel: PanelContainer = null


func _ready() -> void:
	GameState.hud_controller = self
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Look.create()
	_overlays = CampaignOverlays.new()

	_build_top_bar()
	_build_tutorial_panel()
	_build_mode_banner()
	_build_minimap()
	_build_log_panel()
	_build_squad_bar()
	_build_drawer_panel()
	_build_raid_panel()
	_inspector_panel = Inspector.new()
	add_child(_inspector_panel)
	_world_map = WorldMap.new()
	add_child(_world_map)
	_world_map.close_requested.connect(_world_map.close)
	_overlays.cover_requested.connect(func():
		close_drawer()
		_set_hud_visible(false)
	)
	_overlays.uncover_requested.connect(activate_campaign)
	add_child(_overlays)
	resized.connect(_align_upper_hud)
	_top_bar.resized.connect(_align_upper_hud)
	_minimap_panel.resized.connect(_align_upper_hud)
	_squad_bar.resized.connect(_align_upper_hud)
	_build_banner.resized.connect(_align_upper_hud)
	_align_upper_hud.call_deferred()

	GameState.resources_changed.connect(_on_resources_changed)
	GameState.time_changed.connect(_on_time_changed)
	GameState.notification_pushed.connect(_on_notification_pushed)
	GameState.raid_alert.connect(_on_raid_alert)
	GameState.diplomacy_changed.connect(_on_diplomacy_changed)
	GameState.religion_changed.connect(_on_religion_changed)
	GameState.campaign_loaded.connect(_on_campaign_loaded)
	GameState.game_started.connect(_world_map.clear_campaign)
	if GameState.combat_command_system != null:
		GameState.combat_command_system.selection_changed.connect(_on_squad_selection_changed)

	_set_hud_visible(false)


func _align_upper_hud() -> void:
	var vp_size: Vector2 = size if (size.x > 0.0 and size.y > 0.0) else get_viewport_rect().size
	var objective_top := _top_bar.get_rect().end.y + 6.0
	var objective_height := maxf(38.0, _objective_panel.get_combined_minimum_size().y)
	var below_objectives := objective_top + objective_height + 10.0
	_objective_panel.offset_top = objective_top
	_objective_panel.offset_bottom = objective_top + objective_height
	_tutorial_panel.offset_top = below_objectives
	_tutorial_panel.offset_bottom = below_objectives + 132.0
	var build_banner_height := maxf(47.0, _build_banner.get_combined_minimum_size().y)
	_build_banner.offset_top = below_objectives
	_build_banner.offset_bottom = below_objectives + build_banner_height
	var raid_top := below_objectives + build_banner_height + 10.0
	_raid_panel.offset_top = raid_top
	_raid_panel.offset_bottom = raid_top

	var minimap_left: float = minf(_minimap_panel.position.x, vp_size.x - 232.0) if _minimap_panel.size.x > 0.0 else (vp_size.x - 232.0)
	var margin_x := 20.0
	var right_limit: float = minimap_left - 12.0
	var max_width: float = maxf(320.0, right_limit - margin_x)
	var drawer_w: float = minf(1082.0, max_width)
	var drawer_left: float = clampf((vp_size.x - drawer_w) * 0.5, margin_x, maxf(margin_x, right_limit - drawer_w))
	var squad_top: float = minf(_squad_bar.position.y, vp_size.y - 158.0) if _squad_bar.size.y > 0.0 else (vp_size.y - 158.0)
	var drawer_bottom: float = minf(vp_size.y * 0.82, squad_top - 6.0)
	drawer_bottom = maxf(drawer_bottom, below_objectives + 120.0)
	_drawer_panel.offset_left = drawer_left
	_drawer_panel.offset_right = drawer_left + drawer_w
	_drawer_panel.offset_top = below_objectives
	_drawer_panel.offset_bottom = drawer_bottom


func _dismiss_open_popup() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if _hide_button_popup(focused):
		return true
	for container in [_drawer_panel, _inspector_panel]:
		if not is_instance_valid(container) or not container.visible:
			continue
		for ctrl in container.find_children("*", "OptionButton", true, false):
			if _hide_button_popup(ctrl):
				return true
		for ctrl in container.find_children("*", "MenuButton", true, false):
			if _hide_button_popup(ctrl):
				return true
	return false


func _hide_button_popup(control: Node) -> bool:
	if control is OptionButton:
		var popup: PopupMenu = (control as OptionButton).get_popup()
		if popup != null and popup.visible:
			popup.hide()
			return true
	elif control is MenuButton:
		var popup: PopupMenu = (control as MenuButton).get_popup()
		if popup != null and popup.visible:
			popup.hide()
			return true
	return false


func _input(event: InputEvent) -> void:
	if not GameState.game_active or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if _overlays.captures_gameplay_shortcuts():
		if key == KEY_ESCAPE and _overlays.dismiss_confirmation():
			get_viewport().set_input_as_handled()
		return
	if _world_map.visible:
		match key:
			KEY_M, KEY_ESCAPE:
				_world_map.close()
			KEY_P:
				_world_map.close()
				_overlays.toggle_pause()
			KEY_F9:
				_overlays.save_campaign()
			KEY_F10:
				_overlays.quick_load_campaign()
			KEY_TAB:
				if event.shift_pressed:
					return
				_world_map.close()
				toggle_drawer("MENU")
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if key == KEY_P:
		_overlays.toggle_pause()
	elif key == KEY_ESCAPE:
		if _overlays.is_pause_visible():
			_overlays.toggle_pause()
		elif _dismiss_open_popup():
			pass
		elif _drawer_panel.visible:
			close_drawer()
		elif is_instance_valid(GameState.player_controller) and GameState.player_controller.is_build_mode:
			GameState.player_controller.exit_build_mode()
		elif _inspector_panel.visible:
			_close_inspector()
		else:
			_overlays.toggle_pause()
	elif key == KEY_F9:
		_overlays.save_campaign()
	elif key == KEY_F10:
		_overlays.quick_load_campaign()
	elif _overlays.is_pause_visible():
		return
	elif key == KEY_M:
		toggle_world_map()
	elif key == KEY_TAB and not event.shift_pressed:
		toggle_drawer("MENU")
	elif key == KEY_B:
		toggle_drawer("BUILD")
	elif key == KEY_C:
		toggle_drawer("COLONY")
	elif key == KEY_R:
		if is_instance_valid(GameState.player_controller) and GameState.player_controller.is_build_mode:
			return
		toggle_drawer("RELIGION")
	elif key == KEY_V:
		toggle_drawer("DIPLOMACY")
	else:
		return
	get_viewport().set_input_as_handled()


func blocks_world_input() -> bool:
	return _world_map.visible or _drawer_panel.visible or _overlays.blocks_world_input()


func toggle_world_map() -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished or _overlays.blocks_world_input():
		return
	if _world_map.visible:
		_world_map.close()
		return
	_dismiss_open_popup()
	close_drawer()
	_close_inspector()
	_world_map.open()


func get_world_waypoint() -> Variant:
	return _world_map.waypoint if is_instance_valid(_world_map) else null


func open_leader_negotiation(faction_id: int) -> void:
	if GameState.is_settled_rival(faction_id) and not blocks_world_input():
		var drawer := _get_or_create_drawer("DIPLOMACY")
		drawer.select_faction(faction_id)
		toggle_drawer("DIPLOMACY")


func _process(delta: float) -> void:
	if _raid_banner_timer > 0.0:
		_raid_banner_timer -= delta
		if _raid_banner_timer <= 0.0:
			_raid_panel.hide()

	if not GameState.game_active or not _top_bar.visible:
		return

	_sync_build_banner()
	_ui_refresh_timer += delta
	if _ui_refresh_timer >= 0.35:
		_ui_refresh_timer = 0.0
		_update_top_bar()
		_update_squad_bar()
		_update_tutorial_and_banners()
		if _inspector_panel.visible:
			_inspector_panel.update_live_values()
		var view: Control = _drawer_views.get(_active_tab)
		if is_instance_valid(view) and view.has_method("update_live_values"):
			view.update_live_values()


func _make_panel_style(bg: Color = Color(0.08, 0.10, 0.086, 0.96), border: Color = Look.EDGE) -> StyleBoxFlat:
	return Look.panel(bg, border, 14)


func _set_hud_visible(vis: bool) -> void:
	_top_bar.visible = vis
	_objective_panel.visible = vis
	_tutorial_panel.visible = vis and not GameState.tutorial_completed and not GameState.tutorial_skipped
	_minimap_panel.visible = vis
	_event_panel.visible = vis
	_squad_bar.visible = vis
	if not vis:
		_world_map.close()
		_build_banner.hide()
		_inspector_panel.close()
		_raid_panel.hide()
		_clear_hud_highlight()


func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.add_theme_stylebox_override("panel", _make_panel_style())
	_top_bar.anchor_right = 1.0
	_top_bar.offset_left = 20.0
	_top_bar.offset_top = 18.0
	_top_bar.offset_right = -252.0
	add_child(_top_bar)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	_top_bar.add_child(stack)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 18)
	stack.add_child(summary)
	_clock_label = Look.label("", &"SectionTitle", 19)
	summary.add_child(_clock_label)
	_pop_label = Look.label("", &"QuietLabel", 14)
	_pop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(_pop_label)
	_pause_btn = Look.button("Pause  P", _overlays.toggle_pause)
	summary.add_child(_pause_btn)

	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 8)
	stack.add_child(resources)
	for key in ["food", "wood", "stone", "flint", "hide", "bone", "faith"]:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", Look.panel(Look.SURFACE, Look.EDGE, 5, 4))
		resources.add_child(tile)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(row)
		row.add_child(Look.label(key.capitalize(), &"QuietLabel", 13))
		var amount := Look.label("0", &"SectionTitle", 18)
		row.add_child(amount)
		_resource_values[key] = amount

	var navigation := HBoxContainer.new()
	stack.add_child(navigation)
	for item in DRAWER_LINKS:
		var tab: String = item[2]
		var button := Look.button("%s  %s" % [item[0], item[1]], func(): toggle_drawer(tab))
		button.toggle_mode = true
		navigation.add_child(button)
		_drawer_links[tab] = button
	_stock_label = Look.label("", &"QuietLabel", 13)
	_stock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation.add_child(_stock_label)

	_objective_panel = PanelContainer.new()
	_objective_panel.add_theme_stylebox_override("panel", Look.panel(Color(0.09, 0.115, 0.095, 0.93), Look.EDGE, 9))
	_objective_panel.anchor_right = 1.0
	_objective_panel.offset_left = 20
	_objective_panel.offset_top = 157
	_objective_panel.offset_right = -252
	add_child(_objective_panel)
	var objectives := HBoxContainer.new()
	_objective_panel.add_child(objectives)
	_objective_label = Look.label("", &"QuietLabel", 14)
	_objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objectives.add_child(_objective_label)
	_grace_label = Look.label("", &"SectionTitle", 15)
	objectives.add_child(_grace_label)


func _build_tutorial_panel() -> void:
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.115, 0.09, 0.96), Color("687454")))
	_tutorial_panel.anchor_left = 0.0
	_tutorial_panel.anchor_right = 0.0
	_tutorial_panel.anchor_top = 0.0
	_tutorial_panel.anchor_bottom = 0.0
	_tutorial_panel.offset_left = 20.0
	_tutorial_panel.offset_top = 205.0
	_tutorial_panel.offset_right = 371.0
	_tutorial_panel.offset_bottom = 332.0
	add_child(_tutorial_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_tutorial_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	_tutorial_title = Look.label("", &"SectionTitle", 18)
	_tutorial_title.text = "Awakening Guide (Step 1/5)"
	_tutorial_title.add_theme_color_override("font_color", Look.MOSS)
	_tutorial_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_tutorial_title)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.tooltip_text = "Hide guide (your early Peace Buffer before bandit attacks remains active)"
	skip_btn.pressed.connect(func():
		skip_btn.release_focus()
		_on_skip_tutorial_pressed()
	)
	hdr.add_child(skip_btn)

	_tutorial_body = Label.new()
	_tutorial_body.text = "Walk near 3 wandering locals and press [E] to recruit them into your tribe."
	_tutorial_body.add_theme_font_size_override("font_size", 13)
	_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_tutorial_body)

	_tutorial_progress = Label.new()
	_tutorial_progress.text = "[ ] Recruit tribesfolk (0/3)"
	_tutorial_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_progress.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_tutorial_progress.add_theme_font_size_override("font_size", 12)
	vb.add_child(_tutorial_progress)


func _on_skip_tutorial_pressed() -> void:
	GameState.skip_awakening_guide()
	_tutorial_panel.hide()
	_sync_tutorial_highlights()
	if is_instance_valid(GameState.player_controller) and GameState.player_controller.has_method("_sync_tutorial_beacon"):
		GameState.player_controller._sync_tutorial_beacon(0.0)


func _build_mode_banner() -> void:
	_build_banner = PanelContainer.new()
	_build_banner.add_theme_stylebox_override("panel", _make_panel_style(Look.SURFACE, Look.GOLD))
	_build_banner.anchor_left = 0.5
	_build_banner.anchor_right = 0.5
	_build_banner.anchor_top = 0.0
	_build_banner.anchor_bottom = 0.0
	_build_banner.offset_left = -310.0
	_build_banner.offset_right = 310.0
	_build_banner.offset_top = 204.0
	_build_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_banner.visible = false
	add_child(_build_banner)

	_build_banner_label = Label.new()
	_build_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_banner_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	_build_banner_label.add_theme_font_size_override("font_size", 13)
	_build_banner.add_child(_build_banner_label)


func _sync_build_banner() -> void:
	if _build_banner == null:
		return
	var pc := GameState.player_controller
	var active: bool = pc != null and pc.is_build_mode
	_build_banner.visible = active
	if active and _build_banner_label != null:
		var info: Dictionary = GameData.BUILDINGS.get(pc.blueprint_type, {})
		var b_name: String = str(info.get("name", pc.blueprint_type))
		var warning: String = pc.blueprint_placement_message()
		var next_text := "%s   ·   LMB Place   T Rotate   Esc / RMB Cancel" % b_name
		if not warning.is_empty():
			next_text += "\n" + warning
		var changed: bool = _build_banner_label.text != next_text
		_build_banner_label.text = next_text
		_build_banner_label.modulate = Look.BONE if warning.is_empty() else Look.DANGER
		if changed:
			_align_upper_hud()


func _build_minimap() -> void:
	_minimap_panel = PanelContainer.new()
	_minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap_panel.offset_left = -232
	_minimap_panel.offset_right = -20
	_minimap_panel.offset_top = 18
	_minimap_panel.mouse_filter = MOUSE_FILTER_STOP
	_minimap_panel.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_minimap_panel.tooltip_text = "Open World Map [M]"
	_minimap_panel.gui_input.connect(_on_radar_input)
	_minimap_panel.add_theme_stylebox_override("panel", Look.panel(Look.INK, Look.EDGE, 10))
	add_child(_minimap_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	_minimap_panel.add_child(stack)
	stack.add_child(Look.label("Valley Radar  [M]", &"SectionTitle", 19))
	var minimap := Control.new()
	minimap.set_script(preload("res://scripts/ui/minimap_widget.gd"))
	minimap.custom_minimum_size = Vector2(190, 173)
	minimap.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(minimap)


func _on_radar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_world_map()
		_minimap_panel.accept_event()


func _build_log_panel() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_event_panel.offset_left = 20
	_event_panel.offset_right = 308
	_event_panel.offset_top = -111
	_event_panel.offset_bottom = -18
	add_child(_event_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_event_panel.add_child(stack)
	_event_toggle = Look.button("Event Log  +", _toggle_event_log)
	_event_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(_event_toggle)
	_latest_event = Look.label("", &"QuietLabel", 13)
	_latest_event.custom_minimum_size.y = 23
	_latest_event.mouse_filter = Control.MOUSE_FILTER_PASS
	_latest_event.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_latest_event)
	_log_box = RichTextLabel.new()
	_log_box.add_theme_font_size_override("normal_font_size", 14)
	_log_box.scroll_following = true
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_box.hide()
	stack.add_child(_log_box)


func _toggle_event_log() -> void:
	_event_expanded = not _event_expanded
	_event_panel.offset_top = -240 if _event_expanded else -111
	_log_box.visible = _event_expanded
	_latest_event.visible = not _event_expanded
	_event_toggle.text = "Event Log  −" if _event_expanded else "Event Log  +"
	_event_toggle.release_focus()


func _build_squad_bar() -> void:
	_squad_bar = PanelContainer.new()
	_squad_bar.add_theme_stylebox_override("panel", _make_panel_style())
	_squad_bar.anchor_left = 0.5
	_squad_bar.anchor_right = 0.5
	_squad_bar.anchor_top = 1.0
	_squad_bar.anchor_bottom = 1.0
	_squad_bar.offset_left = -350.0
	_squad_bar.offset_top = -158.0
	_squad_bar.offset_right = 350.0
	_squad_bar.offset_bottom = -18.0
	add_child(_squad_bar)

	var vb := VBoxContainer.new()
	_squad_bar.add_child(vb)

	var top_r := HBoxContainer.new()
	top_r.add_theme_constant_override("separation", 12)
	vb.add_child(top_r)

	_leader_hp_label = Look.label("Leader", &"SectionTitle", 19)
	top_r.add_child(_leader_hp_label)

	_leader_hp_bar = ProgressBar.new()
	_leader_hp_bar.custom_minimum_size = Vector2(126, 8)
	_leader_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leader_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leader_hp_bar.show_percentage = false
	_leader_hp_bar.max_value = 100.0
	_leader_hp_bar.value = 100.0
	top_r.add_child(_leader_hp_bar)

	_blessing_label = Label.new()
	_blessing_label.text = "[Q] Blessing Ready"
	_blessing_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	top_r.add_child(_blessing_label)

	var sq_r := HBoxContainer.new()
	sq_r.add_theme_constant_override("separation", 6)
	vb.add_child(sq_r)

	for s in HUDDrawers.SQUAD_CLASS_SPECS:
		var btn := Button.new()
		btn.text = str(s["short"])
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sid: int = int(s["id"])
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.select_squad(sid)
			btn.release_focus()
		)
		sq_r.add_child(btn)
		_squad_btns[sid] = btn

	var ord_r := HBoxContainer.new()
	ord_r.add_theme_constant_override("separation", 6)
	vb.add_child(ord_r)

	for o in HUDDrawers.TACTICAL_ORDER_SPECS:
		var btn := Button.new()
		btn.text = str(o["short"])
		btn.toggle_mode = true
		btn.tooltip_text = str(o["full"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var oid: int = int(o["id"])
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.issue_player_order(oid)
			btn.release_focus()
		)
		ord_r.add_child(btn)
		_order_btns[oid] = btn

	_fire_btn = Button.new()
	_fire_btn.text = "Fire  F5"
	_fire_btn.toggle_mode = true
	_fire_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_fire_at_will()
		_fire_btn.release_focus()
	)
	ord_r.add_child(_fire_btn)

	_warhorn_btn = Button.new()
	_warhorn_btn.text = "Warhorn  H"
	_warhorn_btn.toggle_mode = true
	_warhorn_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_warhorn()
		_warhorn_btn.release_focus()
	)
	ord_r.add_child(_warhorn_btn)


func _build_drawer_panel() -> void:
	_drawer_panel = PanelContainer.new()
	_drawer_panel.hide()
	_drawer_panel.add_theme_stylebox_override("panel", Look.panel(Look.INK, Look.GOLD, 16))
	_drawer_panel.anchor_left = 0.0
	_drawer_panel.anchor_right = 0.0
	_drawer_panel.anchor_top = 0.0
	_drawer_panel.anchor_bottom = 0.0
	_drawer_panel.offset_left = 20.0
	_drawer_panel.offset_top = 215.0
	_drawer_panel.offset_right = 1102.0
	_drawer_panel.offset_bottom = 650.0
	add_child(_drawer_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	_drawer_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	_drawer_title = Look.label("", &"DisplayTitle", 33)
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_drawer_title)
	_drawer_close = Look.button("Close  Esc", close_drawer)
	_drawer_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_drawer_close)
	stack.add_child(HSeparator.new())
	_drawer_scroll = ScrollContainer.new()
	_drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_drawer_scroll.follow_focus = true
	_drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_drawer_scroll)
	_drawer_content = VBoxContainer.new()
	_drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_content.add_theme_constant_override("separation", 12)
	_drawer_scroll.add_child(_drawer_content)


func _build_raid_panel() -> void:
	_raid_panel = PanelContainer.new()
	_raid_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_raid_panel.offset_left = -255
	_raid_panel.offset_right = 255
	_raid_panel.offset_top = 268
	_raid_panel.add_theme_stylebox_override("panel", Look.panel(Color("432721"), Look.DANGER, 12))
	_raid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_panel.hide()
	add_child(_raid_panel)
	var alert := VBoxContainer.new()
	alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_panel.add_child(alert)
	var title := Look.label("Raid incoming", &"SectionTitle", 21)
	title.modulate = Look.DANGER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_child(title)
	_raid_banner = Look.label("")
	_raid_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raid_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_child(_raid_banner)


func inspect_unit(unit: Node) -> void:
	_inspector_panel.inspect_unit(unit)


func activate_campaign() -> void:
	_set_hud_visible(true)
	_update_top_bar()
	_update_squad_bar()
	var command := GameState.combat_command_system
	if is_instance_valid(command):
		_on_squad_selection_changed(command.selected_warrior_class, command.last_issued_order, command.global_fire_at_will, GameState.warhorn_active)
	_update_tutorial_and_banners()
	_align_upper_hud()
	_align_upper_hud.call_deferred()


func _on_campaign_loaded() -> void:
	_overlays.reset()
	_world_map.clear_campaign()
	_raid_panel.hide()
	_raid_banner_timer = 0.0
	_close_inspector()
	close_drawer()
	_log_box.clear()
	_latest_event.text = ""
	activate_campaign()


func toggle_drawer(tab_key: String) -> void:
	if _overlays.blocks_world_input():
		return
	if _drawer_panel.visible and _active_tab == tab_key:
		close_drawer()
		return
	_close_inspector()
	close_drawer()
	_active_tab = tab_key
	_align_upper_hud()
	_drawer_panel.show()
	_refresh_open_drawer()
	_drawer_scroll.set_deferred("scroll_vertical", 0)
	for key in _drawer_links:
		(_drawer_links[key] as Button).set_pressed_no_signal(key == _active_tab)
	_drawer_close.grab_focus()


func close_drawer() -> void:
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and (_drawer_panel.is_ancestor_of(focused) or focused in _drawer_links.values()):
			focused.release_focus()
	_drawer_panel.hide()
	var view: Control = _drawer_views.get(_active_tab)
	if is_instance_valid(view):
		view.hide()
	for button in _drawer_links.values():
		button.set_pressed_no_signal(false)
	_active_tab = ""
	if GameState.game_active:
		AwakeningGuide.advance(GameState)
		_update_tutorial_and_banners()


func _refresh_open_drawer() -> void:
	if not _drawer_panel.visible:
		return
	var view := _get_or_create_drawer(_active_tab)
	_drawer_title.text = view.title
	view.show()
	view.refresh()


func _get_or_create_drawer(tab: String) -> Control:
	var view: Control = _drawer_views.get(tab)
	if view == null:
		view = DRAWERS[tab].new()
		view.scroll_host = _drawer_scroll
		view.focus_lost.connect(_drawer_close.grab_focus)
		view.close_requested.connect(close_drawer)
		view.navigate_requested.connect(toggle_drawer)
		view.pause_requested.connect(_overlays.toggle_pause)
		view.inspect_requested.connect(func(unit: Node):
			close_drawer()
			inspect_unit(unit)
		)
		_drawer_content.add_child(view)
		_drawer_views[tab] = view
	return view


func _close_inspector() -> void:
	_inspector_panel.close()


func _on_resources_changed(_fid: int) -> void:
	_update_top_bar()
	if _active_tab == "BUILD" and _drawer_views.has("BUILD"):
		_drawer_views["BUILD"].update_live_values()


func _on_diplomacy_changed() -> void:
	if _active_tab == "DIPLOMACY":
		_refresh_open_drawer()


func _on_religion_changed(_fid: int) -> void:
	_update_top_bar()
	if _active_tab == "BUILD" and _drawer_views.has("BUILD"):
		_drawer_views["BUILD"].update_live_values()


func _on_time_changed(_t: float, _d: int, _p: int) -> void:
	_update_clock()


func _update_top_bar() -> void:
	if not GameState.factions.has(0):
		return
	var f0: Dictionary = GameState.factions[0]
	var res: Dictionary = f0["resources"]
	var stock: Dictionary = f0["stockpile"]

	_update_clock()
	var units := GameState.get_faction_units(0, true)
	_pop_label.text = "Population %d/%d    ·    Morale %d%%    ·    Captives %d" % [
		units.size(), GameState.get_housing_capacity(0), int(GameState.get_average_morale(0)), int(f0.get("captured_cavemen", 0)),
	]
	for key in _resource_values:
		(_resource_values[key] as Label).text = str(int(res[key]))

	_stock_label.text = "Tier %d | Spears:%d Knives:%d Bows:%d Clubs:%d Javs:%d Armor:%d" % [
		int(f0.get("tech_tier", 1)), int(stock.get("spears", 0)), int(stock.get("knives", 0)), int(stock.get("bows", 0)), int(stock.get("clubs", 0)), int(stock.get("javelins", 0)), int(stock.get("armor", 0))
	]
	_update_objective_banner(f0)


func _update_clock() -> void:
	var hour := int(GameState.time_of_day)
	var minute := int((GameState.time_of_day - float(hour)) * 60.0)
	var phase := "Daylight"
	if GameState.current_phase == GameData.SchedulePhase.DUSK_HEARTH:
		phase = "Dusk"
	elif GameState.current_phase == GameData.SchedulePhase.NIGHT_SLEEP:
		phase = "Night"
	_clock_label.text = "Day %d   ·   %02d:%02d   ·   %s" % [GameState.day_count, hour, minute, phase]


func _update_objective_banner(f0: Dictionary) -> void:
	if _grace_label != null:
		if GameState.is_raid_grace_active():
			var rem: int = ceili(GameState.bandit_grace_remaining)
			var mins: int = rem / 60
			var secs: int = rem % 60
			_grace_label.text = "Peace Buffer: %d:%02d" % [mins, secs]
			_grace_label.add_theme_color_override("font_color", Color(0.49, 0.88, 0.96) if rem > 30 else Color(1.0, 0.72, 0.35))
		else:
			_grace_label.text = "Raiders Active"
			_grace_label.add_theme_color_override("font_color", Color(0.98, 0.48, 0.40))

	if _objective_label == null:
		return
	var wild_left: int = GameState.get_faction_units(-1, true).size()
	if not bool(f0.get("is_founded", false)):
		if wild_left > 0:
			_objective_label.text = "Objective: Recruit wanderers (%d left, [E]) & press [B] Build to light Campfire." % wild_left
		else:
			_objective_label.text = "Objective: Press [B] Build to place your Tribal Campfire."
	elif not GameState.has_building(0, "SACRED_TOTEM", true) or not GameState.has_building(0, "CRAFTING_PIT", true):
		_objective_label.text = "Objective: Press [B] Build for Sacred Totem & Crafting Pit, and assign workers in [C] Colony."
	elif int(f0.get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.NONE:
		_objective_label.text = "Objective: Press [R] Faith & Religion to choose your Patron God & Tenets."
	else:
		var united := 0
		for fid in range(1, 5):
			if GameState.factions.has(fid):
				if GameState.factions[fid]["is_defeated"] or GameState.is_treaty_ally(0, fid):
					united += 1
		_objective_label.text = "Objective: Unite the Valley (%d/4 Rival Tribes Allied or Conquered) — [V] Diplomacy." % united


func refresh_awakening_guide() -> void:
	_update_tutorial_and_banners()


func get_highlighted_hud_tab() -> String:
	return _highlighted_hud_tab


func _clear_hud_highlight() -> void:
	_highlighted_hud_tab = ""
	for btn in _drawer_links.values():
		var button: Button = btn as Button
		if button != null:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_color_override("font_color")


func _sync_tutorial_highlights() -> void:
	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var next_tab: String = str(target.get("highlight_hud", "")) if bool(target.get("active", false)) else ""
	if next_tab == _highlighted_hud_tab:
		return
	_highlighted_hud_tab = next_tab
	if _highlighted_hud_tab.is_empty():
		_clear_hud_highlight()
		return
	for key in _drawer_links.keys():
		var button: Button = _drawer_links[key] as Button
		if button == null:
			continue
		if str(key) == _highlighted_hud_tab:
			if _highlight_style == null:
				_highlight_style = Look.panel(Color("3d3320"), Look.GOLD, 6, 4)
				_highlight_style.set_border_width_all(2)
				_highlight_style.content_margin_left = 11
				_highlight_style.content_margin_right = 11
			button.add_theme_stylebox_override("normal", _highlight_style)
			button.add_theme_color_override("font_color", Look.GOLD)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_color_override("font_color")


func _update_tutorial_and_banners() -> void:
	_sync_build_banner()
	_sync_tutorial_highlights()
	if _tutorial_panel == null or not GameState.factions.has(0):
		return
	if GameState.tutorial_completed or GameState.tutorial_skipped:
		_tutorial_panel.visible = false
		return

	_tutorial_panel.visible = true
	var cur: int = GameState.tutorial_step
	_tutorial_title.text = "Awakening Guide (Step %d/5)" % cur
	if cur == 1:
		var rec: int = mini(AwakeningGuide.recruit_count(GameState), 3)
		_tutorial_body.text = "Follow the golden beacon to wandering locals and press [E] to recruit 3 into your tribe."
		_tutorial_progress.text = "[%s] Recruit tribesfolk (%d/3)" % ["x" if rec >= 3 else " ", rec]
	elif cur == 2:
		var founded: bool = bool(GameState.factions[0].get("is_founded", false))
		_tutorial_body.text = "Open [B] Build, select Tribal Campfire, then [LMB] click clear ground to light it."
		_tutorial_progress.text = "[%s] Open [B] Build & light Tribal Campfire" % ("x" if founded else " ")
	elif cur == 3:
		_tutorial_body.text = "Press [E] near a marked resource node to gather, and assign a villager role in [C] Colony."
		_tutorial_progress.text = "%s Harvest resource ([E])\n%s Assign villager role ([C] Colony)" % [
			"[x]" if GameState.tutorial_harvested else "[ ]",
			"[x]" if GameState.tutorial_assigned_role else "[ ]",
		]
	elif cur == 4:
		var has_hut_bp: bool = not GameState.get_faction_buildings(0, "SLEEPING_HUT", false).is_empty()
		var has_hut_done: bool = not GameState.get_faction_buildings(0, "SLEEPING_HUT", true).is_empty()
		if has_hut_bp and not has_hut_done:
			_tutorial_body.text = "Walk to your Sleeping Hut blueprint and press [E] to help finish building it."
		else:
			_tutorial_body.text = "Open [B] Build to place a Sleeping Hut, then press [E] near it to help build."
		_tutorial_progress.text = "%s Place Sleeping Hut ([B] Build)\n%s Finish Sleeping Hut ([E] to help)" % [
			"[x]" if (has_hut_bp or has_hut_done) else "[ ]",
			"[x]" if has_hut_done else "[ ]",
		]
	else:
		_tutorial_body.text = "Practice your Leader attacks: [LMB] Heavy Cleave and [F] or [RMB] Throw Javelin."
		_tutorial_progress.text = "%s Heavy Cleave ([LMB])\n%s Throw Javelin ([F] / [RMB])" % [
			"[x]" if GameState.tutorial_cleaved else "[ ]",
			"[x]" if GameState.tutorial_thrown else "[ ]",
		]


func _update_squad_bar() -> void:
	var leader := GameState.get_faction_leader(0)
	if leader != null:
		_leader_hp_label.text = "%s   ·   %d / %d HP" % [leader.unit_name, ceili(leader.hp), ceili(leader.max_hp)]
		_leader_hp_bar.max_value = leader.max_hp
		_leader_hp_bar.value = leader.hp

	if GameState.player_controller != null:
		var cd: float = GameState.player_controller._blessing_cd
		if GameState.player_controller.is_mounted():
			_blessing_label.text = "[E] Dismount"
		else:
			_blessing_label.text = "[Q] Blessing Ready" if cd <= 0.0 else "[Q] Blessing (%.0fs)" % cd

	var all_w := 0
	var sp_w := 0
	var kn_w := 0
	var ar_w := 0
	var br_w := 0
	var jv_w := 0
	for u in GameState.get_faction_units(0, true):
		if not u.is_leader and u.role == GameData.Role.WARRIOR:
			all_w += 1
			if u.warrior_class == GameData.WarriorClass.SPEARMAN:
				sp_w += 1
			elif u.warrior_class == GameData.WarriorClass.KNIFE_RAIDER:
				kn_w += 1
			elif u.warrior_class == GameData.WarriorClass.ARCHER:
				ar_w += 1
			elif u.warrior_class == GameData.WarriorClass.BRUTE:
				br_w += 1
			elif u.warrior_class == GameData.WarriorClass.JAVELINEER:
				jv_w += 1

	_squad_btns[-1].text = "[1] All (%d)" % all_w
	_squad_btns[GameData.WarriorClass.SPEARMAN].text = "[2] Spears (%d)" % sp_w
	_squad_btns[GameData.WarriorClass.KNIFE_RAIDER].text = "[3] Knives (%d)" % kn_w
	_squad_btns[GameData.WarriorClass.ARCHER].text = "[4] Archers (%d)" % ar_w
	_squad_btns[GameData.WarriorClass.BRUTE].text = "[5] Brutes (%d)" % br_w
	_squad_btns[GameData.WarriorClass.JAVELINEER].text = "[6] Javelins (%d)" % jv_w


func _on_squad_selection_changed(selected_class: int, last_order: int, fire_at_will: bool, warhorn: bool) -> void:
	for key in _squad_btns:
		(_squad_btns[key] as Button).set_pressed_no_signal(key == selected_class)
	for key in _order_btns:
		(_order_btns[key] as Button).set_pressed_no_signal(key == last_order)
	_fire_btn.set_pressed_no_signal(fire_at_will)
	_fire_btn.tooltip_text = "Fire at will is on" if fire_at_will else "Fire at will is off"
	_warhorn_btn.set_pressed_no_signal(warhorn)
	_warhorn_btn.tooltip_text = "Warhorn is active" if warhorn else "Raise the warhorn"
	if _drawer_panel.visible and _active_tab == "MENU":
		call_deferred("_refresh_open_drawer")


func _on_notification_pushed(message: String, severity: String) -> void:
	var color := Look.BONE
	match severity:
		"success": color = Look.MOSS
		"warning": color = Look.GOLD
		"danger": color = Look.DANGER
	_latest_event.modulate = color
	_latest_event.text = message
	_latest_event.tooltip_text = message
	_log_box.push_color(color)
	_log_box.add_text(message)
	_log_box.pop()
	_log_box.newline()
	if _log_box.get_paragraph_count() > 80:
		_log_box.remove_paragraph(0)


func _on_raid_alert(_attacker: int, target: int, message: String) -> void:
	if target == 0:
		_align_upper_hud()
		_raid_banner.text = message
		_raid_panel.show()
		_raid_banner_timer = 8.5

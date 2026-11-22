extends Control

const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const HUDPanels = preload("res://scripts/ui/hud_panels.gd")
const Look = preload("res://scripts/ui/fallow_theme.gd")
const CampaignOverlays = preload("res://scripts/ui/campaign_overlays.gd")
const Inspector = preload("res://scripts/ui/unit_inspector.gd")
const WorldMap = preload("res://scripts/ui/world_map_overlay.gd")
const DRAWERS := {
	"BUILD": preload("res://scripts/ui/drawers/build_drawer.gd"),
	"COLONY": preload("res://scripts/ui/drawers/colony_drawer.gd"),
	"PERKS": preload("res://scripts/ui/drawers/perks_drawer.gd"),
	"RELIGION": preload("res://scripts/ui/drawers/faith_drawer.gd"),
	"DIPLOMACY": preload("res://scripts/ui/drawers/diplomacy_drawer.gd"),
	"MENU": preload("res://scripts/ui/drawers/command_drawer.gd"),
}

const DRAWER_LINKS := HUDPanels.DRAWER_LINKS

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
var _pov_btn: Button = null
var _fp_reticle: Control = null
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
	HUDPanels.build_fp_reticle(self)
	_inspector_panel = Inspector.new()
	add_child(_inspector_panel)
	_world_map = WorldMap.new()
	add_child(_world_map)
	_world_map.close_requested.connect(_close_world_map_with_sfx)
	_overlays.cover_requested.connect(func():
		_dismiss_open_popup()
		close_drawer()
		_set_hud_visible(false)
	)
	_overlays.uncover_requested.connect(activate_campaign)
	add_child(_overlays)
	_world_map.visibility_changed.connect(sync_pov_state)
	_drawer_panel.visibility_changed.connect(sync_pov_state)
	_inspector_panel.visibility_changed.connect(sync_pov_state)
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
	GameState.progression_changed.connect(_on_progression_changed)
	GameState.arena_state_changed.connect(_on_arena_state_changed)
	GameState.campaign_loaded.connect(_on_campaign_loaded)
	GameState.game_started.connect(clear_campaign)
	if is_instance_valid(GameState.player_controller):
		GameState.player_controller.mount_changed.connect(_sync_leader_action_hint)
	if GameState.combat_command_system != null:
		GameState.combat_command_system.selection_changed.connect(_on_squad_selection_changed)

	_set_hud_visible(false)


func _align_upper_hud() -> void:
	HUDPanels.align_upper_hud(self)


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
				_play_ui_sfx()
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
			KEY_K:
				_world_map.close()
				toggle_drawer("PERKS")
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
			_play_ui_sfx()
			close_drawer()
		elif is_instance_valid(GameState.player_controller) and GameState.player_controller.is_build_mode:
			GameState.player_controller.exit_build_mode()
		elif _inspector_panel.visible:
			_close_inspector()
		elif is_instance_valid(GameState.player_controller) and GameState.player_controller.is_spectating_arena:
			GameState.player_controller.set_arena_spectate(false)
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
	elif key == KEY_K:
		toggle_drawer("PERKS")
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


func _play_ui_sfx(cue: String = "ui_click") -> void:
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_ui_sfx(cue, 0.04)


func _close_world_map_with_sfx() -> void:
	if _world_map.visible:
		_play_ui_sfx()
	_world_map.close()


func toggle_world_map() -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished or _overlays.blocks_world_input():
		return
	if _world_map.visible:
		_play_ui_sfx()
		_world_map.close()
		return
	_play_ui_sfx()
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


func open_arena_drawer() -> void:
	if not GameState.game_active or _overlays.blocks_world_input():
		return
	if _world_map.visible:
		_world_map.close()
	_close_inspector()
	_dismiss_open_popup()
	if not _drawer_panel.visible or _active_tab != "COLONY":
		if _drawer_panel.visible:
			close_drawer()
		_active_tab = "COLONY"
		_align_upper_hud()
		_drawer_panel.show()
		for key in _drawer_links:
			(_drawer_links[key] as Button).set_pressed_no_signal(key == _active_tab)
	var drawer := _get_or_create_drawer("COLONY")
	_drawer_title.text = drawer.title
	drawer.show()
	drawer.select_section("Arena")
	_drawer_scroll.set_deferred("scroll_vertical", 0)
	_drawer_close.grab_focus()
	_play_ui_sfx("ui_click")
	sync_pov_state()
	if GameState.game_active:
		_update_tutorial_and_banners()


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
	return HUDPanels.make_panel_style(bg, border)


func _set_hud_visible(vis: bool) -> void:
	HUDPanels.set_hud_visible(self, vis)
	sync_pov_state()


func _build_top_bar() -> void:
	HUDPanels.build_top_bar(self)


func _build_tutorial_panel() -> void:
	HUDPanels.build_tutorial_panel(self)


func _on_skip_tutorial_pressed() -> void:
	GameState.skip_awakening_guide()
	_tutorial_panel.hide()
	_sync_tutorial_highlights()
	if is_instance_valid(GameState.player_controller) and GameState.player_controller.has_method("_sync_tutorial_beacon"):
		GameState.player_controller._sync_tutorial_beacon(0.0)


func _build_mode_banner() -> void:
	HUDPanels.build_mode_banner(self)


func _sync_build_banner() -> void:
	HUDPanels.sync_build_banner(self)


func _build_minimap() -> void:
	HUDPanels.build_minimap(self)


func _on_radar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_world_map()
		_minimap_panel.accept_event()


func _build_log_panel() -> void:
	HUDPanels.build_log_panel(self)


func _toggle_event_log() -> void:
	_event_expanded = not _event_expanded
	_event_panel.offset_top = -240 if _event_expanded else -111
	_log_box.visible = _event_expanded
	_latest_event.visible = not _event_expanded
	_event_toggle.text = "Event Log  −" if _event_expanded else "Event Log  +"
	_event_toggle.release_focus()


func _build_squad_bar() -> void:
	HUDPanels.build_squad_bar(self)


func _build_drawer_panel() -> void:
	HUDPanels.build_drawer_panel(self)


func _build_raid_panel() -> void:
	HUDPanels.build_raid_panel(self)


func inspect_unit(unit: Node) -> void:
	_inspector_panel.inspect_unit(unit)


func sync_pov_state() -> void:
	var pc := GameState.player_controller
	var can_toggle := false
	if is_instance_valid(pc):
		can_toggle = pc.can_toggle_first_person()
		if not can_toggle:
			pc.cancel_camera_drag()
	HUDPanels.sync_pov_state(self, can_toggle)


func _sync_leader_action_hint() -> void:
	HUDPanels.sync_leader_action_hint(self)


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


func clear_campaign() -> void:
	_world_map.clear_campaign()
	_reset_drawer_views()


func _reset_drawer_views() -> void:
	for view_v: Variant in _drawer_views.values():
		var view := view_v as Control
		if is_instance_valid(view) and view.has_method("reset_campaign_state"):
			view.reset_campaign_state()


func _on_campaign_loaded() -> void:
	_overlays.reset()
	_world_map.clear_campaign()
	_raid_panel.hide()
	_raid_banner_timer = 0.0
	_close_inspector()
	close_drawer()
	_reset_drawer_views()
	_log_box.clear()
	_latest_event.text = ""
	activate_campaign()


func toggle_drawer(tab_key: String) -> void:
	if _overlays.blocks_world_input():
		return
	_play_ui_sfx()
	_dismiss_open_popup()
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
	if GameState.game_active:
		_update_tutorial_and_banners()


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


func _on_progression_changed(fid: int) -> void:
	if fid == 0:
		_update_top_bar()
		if _active_tab == "BUILD" and _drawer_views.has("BUILD"):
			_drawer_views["BUILD"].update_live_values()
		elif _active_tab == "COLONY" and _drawer_views.has("COLONY"):
			_drawer_views["COLONY"].update_live_values()
		elif _active_tab == "PERKS" and _drawer_views.has("PERKS"):
			_drawer_views["PERKS"].update_live_values()
	elif _active_tab == "DIPLOMACY":
		_refresh_open_drawer()


func _on_arena_state_changed() -> void:
	_sync_leader_action_hint()
	if _active_tab == "COLONY" and _drawer_views.has("COLONY"):
		var view: Control = _drawer_views["COLONY"]
		if is_instance_valid(view) and view.has_method("update_live_values"):
			view.update_live_values()
	sync_pov_state()


func _on_time_changed(_t: float, _d: int, _p: int) -> void:
	_update_clock()


func _update_top_bar() -> void:
	HUDPanels.update_top_bar(self)


func _update_clock() -> void:
	HUDPanels.update_clock(self)


func _update_objective_banner(f0: Dictionary) -> void:
	HUDPanels.update_objective_banner(self, f0)


func refresh_awakening_guide() -> void:
	_update_tutorial_and_banners()


func get_highlighted_hud_tab() -> String:
	return _highlighted_hud_tab


func _clear_hud_highlight() -> void:
	HUDPanels.clear_hud_highlight(self)


func _sync_tutorial_highlights() -> void:
	HUDPanels.sync_tutorial_highlights(self)


func _update_tutorial_and_banners() -> void:
	HUDPanels.update_tutorial_and_banners(self)


func _update_squad_bar() -> void:
	HUDPanels.update_squad_bar(self)


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

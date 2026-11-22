extends SceneTree
## Forward+ regression check for the player-facing campaign flow. Use isolated APPDATA.

var _game: Node
var _data: Node
var _shell: Node
var _failed := false
var _screens := false
var _out := ""

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, caption: String) -> void:
	if value:
		print("PASS ", caption)
	else:
		push_error("FAIL " + caption)
		_failed = true

func frames(count: int = 2) -> void:
	for frame in range(count):
		await process_frame

func screenshot(name: String) -> void:
	if not _screens:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.save_png(_out.path_join(name + ".png")) == OK, "screenshot " + name + " " + str(img.get_size()))

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event, true)

func click_at(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)

func button_in(scope: Node, label: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		if node.text == label and node.is_visible_in_tree() and not node.disabled:
			return node
	return null

func press(scope: Node, label: String) -> void:
	var button := button_in(scope, label)
	check(button != null and button.is_visible_in_tree() and not button.disabled, "action " + label)
	if button != null:
		button.grab_focus()
		key(KEY_ENTER)

func run() -> void:
	_game = root.get_node("GameState")
	_data = root.get_node("GameData")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out = argument.trim_prefix("--out-dir=")
	if not _out.is_empty() and (not _out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_out) != OK):
		push_error("Pass a writable absolute --out-dir.")
		quit(1)
		return
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return
	_screens = not _out.is_empty() and DisplayServer.get_name() != "headless"
	print("QA user directory: ", OS.get_user_data_dir())
	var save_path: String = _game.CAMPAIGN_SAVE_PATH
	if FileAccess.file_exists(save_path):
		push_error("The regression check needs an empty campaign slot.")
		quit(1)
		return
	var title: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_shell = title.instantiate()
	root.add_child(_shell)
	await frames()
	check(not _game.game_active and _game.world_node == null, "title starts without a simulated world")
	await screenshot("01-title")
	press(_shell._title, "Start")
	await frames(14)
	check(_shell._continue.disabled, "Continue unavailable with no save")
	await screenshot("02-menu")
	press(_shell._title, "Load Game")
	await frames()
	check(_shell._page.content.get_child(0).text.contains("No saved"), "empty load view explains missing save")
	key(KEY_ESCAPE)
	press(_shell._title, "Settings")
	await frames()
	var preferences := root.get_node("Preferences")
	preferences.set_value("reduced_motion", true)
	var scale := 1.1 if "--large-ui" in OS.get_cmdline_user_args() else 0.9
	preferences.set_value("ui_scale", scale)
	preferences.set_value("psx", false)
	# Re-open so the input controls reflect the directly changed test settings.
	press(_shell._page, "Done")
	await frames()
	press(_shell._title, "Settings")
	await frames()
	await screenshot("03-settings")
	press(_shell._page, "Done")
	await frames()
	var file := ConfigFile.new()
	check(file.load(preferences.PATH) == OK and file.get_value("interface", "ui_scale") == scale, "settings persist to a separate config")
	press(_shell._title, "New Game")
	await frames()
	press(_shell._page, "Goliath")
	await frames()
	check(_shell._page._lineage == _data.Lineage.GOLIATH, "Awakening lineage selection works")
	await screenshot("04-awakening")
	_shell._page._tribe.text = "QA Fallow"
	press(_shell._page, "Awaken in the Valley")
	await frames(12)
	check(_game.game_active and _game.get_faction_leader(0) != null, "Awakening creates a live campaign")
	if not _game.game_active or _game.hud_controller == null:
		quit(1)
		return
	var hud: Control = _game.hud_controller
	var pc: Node = _game.player_controller
	check(not _game.world_node.is_psx_filter_enabled(), "title preferences applied to new world")
	check(_game.factions[0]["name"] == "QA Fallow" and _game.factions[0]["primary_lineage"] == _data.Lineage.GOLIATH, "setup values reach campaign")
	await screenshot("05-opening-hud")
	var start_time: float = _game.bandit_grace_remaining
	var initial: int = _game.get_faction_units(0).size()
	key(KEY_B)
	await frames()
	check(hud._active_tab == "BUILD", "B opens the Build panel")
	key(KEY_E)
	key(KEY_F)
	check(_game.get_faction_units(0).size() == initial and pc._javelin_cd == 0.0, "drawer consumes world interaction and attack keys")
	check(hud._tutorial_panel.size.y <= 160.0, "guide keeps its compact height")
	var place_button := button_in(hud._drawer_content, "Place Campfire")
	check(place_button.get_global_rect().end.y <= hud._drawer_scroll.get_global_rect().end.y, "campfire action fits without scrolling")
	var drawer_rect: Rect2 = hud._drawer_panel.get_global_rect()
	check(not drawer_rect.intersects(hud._minimap_panel.get_global_rect()), "drawer stays clear of Valley Radar")
	check(not drawer_rect.intersects(hud._squad_bar.get_global_rect()), "drawer stays clear of squad bar")
	check(hud._raid_panel.get_index() > hud._drawer_panel.get_index(), "raid panel renders above drawer panel")
	await screenshot("06-build")
	key(KEY_ESCAPE)
	for i in range(3):
		var wanderers: Array = _game.get_faction_units(-1)
		pc.leader_unit.global_position = wanderers[0].global_position
		key(KEY_E)
		await frames()
	await frames(23)
	check(_game.get_faction_units(0).size() >= 4 and _game.tutorial_step >= 2, "E recruitment advances the guide")
	hud._drawer_links["BUILD"].grab_focus()
	key(KEY_ENTER)
	await frames()
	check(hud._active_tab == "BUILD", "Build HUD button opens the same view")
	press(hud._drawer_content, "Place Campfire")
	await frames()
	check(pc.is_build_mode and not hud._drawer_panel.visible, "Campfire action starts placement")
	var resource_label: Label = hud._resource_values["stone"]
	click_at(resource_label.get_global_rect().get_center())
	check(pc.is_build_mode and not _game.has_building(0, "CAMPFIRE"), "Clicking the HUD cannot place the blueprint")
	key(KEY_ESCAPE)
	check(not pc.is_build_mode and not _game.is_paused, "Escape cancels the blueprint before opening Pause")
	key(KEY_B)
	await frames()
	press(hud._drawer_content, "Place Campfire")
	await frames()
	if pc.is_build_mode:
		key(KEY_T)
		check(pc.blueprint_rot_y > 0, "T rotates blueprint")
		click_at(root.get_visible_rect().size * Vector2(0.52, 0.45))
		await frames()
	await frames(23)
	check(_game.has_building(0, "CAMPFIRE", true) and _game.tutorial_step >= 3, "LMB places the first Campfire and advances guide")
	check(_game.is_raid_grace_active() and _game.bandit_grace_remaining <= start_time, "Peace Buffer remains active")
	var colony: Node = _game.faction_controllers[0]
	var child: Node = colony.spawn_colonist(pc.leader_unit.global_position + Vector3(0, 0, 20),
		_data.Lineage.CRAG_BORN, _data.Gender.MALE, _data.Role.FORAGER, false, true)
	key(KEY_C)
	await frames()
	check(hud._active_tab == "COLONY" and button_in(hud._drawer_content, "Inspect") != null, "C opens live colony roster")
	var roster: Control = hud._drawer_views["COLONY"]
	var role_key := "unit-role:%d" % child.unit_id
	check(not _has_role_control(roster, role_key), "A child has no role selector")
	child.growth_progress = 0.9999
	await frames(26)
	check(not child.is_child and _has_role_control(roster, role_key), "Roster refreshes role eligibility when the same unit matures")
	var child_role_opt: OptionButton = _find_role_control(roster, role_key)
	check(child_role_opt != null, "matured unit role selector is accessible")
	if child_role_opt != null:
		child_role_opt.grab_focus()
		child_role_opt.show_popup()
		await frames()
		check(child_role_opt.get_popup().visible, "OptionButton popup opens inside Colony drawer")
		key(KEY_ESCAPE)
		await frames()
		check(not child_role_opt.get_popup().visible and hud._drawer_panel.visible and hud._active_tab == "COLONY", "Escape closes OptionButton popup without closing Colony drawer")
	await screenshot("07-colony")
	if child_role_opt != null:
		child_role_opt.grab_focus()
		child_role_opt.show_popup()
		await frames()
		check(child_role_opt.get_popup().visible, "OptionButton popup reopens before toggle_drawer")
		hud.toggle_drawer("BUILD")
		await frames()
		check(not child_role_opt.get_popup().visible and hud._drawer_panel.visible and hud._active_tab == "BUILD", "toggle_drawer(\"BUILD\") dismisses open Colony OptionButton popup")
		key(KEY_C)
		await frames()
		var child_role_opt_again: OptionButton = _find_role_control(roster, role_key)
		check(child_role_opt_again != null, "matured unit role selector remains accessible after returning to Colony")
		if child_role_opt_again != null:
			child_role_opt_again.grab_focus()
			child_role_opt_again.show_popup()
			await frames()
			check(child_role_opt_again.get_popup().visible, "OptionButton popup opens before Pause")
			hud._pause_btn.pressed.emit()
			await frames()
			check(not child_role_opt_again.get_popup().visible and _game.is_paused and hud._overlays._pause_screen.visible, "Pause action dismisses open Colony OptionButton popup when pausing")
			key(KEY_P)
			await frames()
			key(KEY_C)
			await frames()
	press(hud._drawer_content, "Crafting")
	await frames()
	check(hud._drawer_views["COLONY"]._queue_label != null, "crafting queue renders")
	check(button_in(hud._drawer_content, "Enlighten Captive") == null, "Enlighten Captive starts disabled with zero captives")
	_game.factions[0]["captured_cavemen"] = 1
	await frames(26)
	check(button_in(hud._drawer_content, "Enlighten Captive") != null and _has_label_containing(hud._drawer_content, "Captured Nomadic Cavemen: 1"), "Crafting tab refreshes captured_cavemen while open")
	_game.factions[0]["captured_cavemen"] = 0
	await frames(26)
	check(button_in(hud._drawer_content, "Enlighten Captive") == null, "Crafting tab updates when captives return to zero")
	_game.faction_controllers[0].spawn_building("ARENA_PIT", Vector3(-18.0, 0.0, 52.0), 0.0, true)
	press(hud._drawer_content, "Arena")
	await frames()
	var arena_rect: Rect2 = hud._drawer_panel.get_global_rect()
	check(button_in(hud._drawer_content, "Start Arena Bout") != null and not arena_rect.intersects(hud._minimap_panel.get_global_rect())
		and not arena_rect.intersects(hud._squad_bar.get_global_rect()), "Arena drawer and start control fit between Valley Radar and the squad bar")
	key(KEY_ESCAPE)
	await frames()
	hud.inspect_unit(child)
	await frames()
	check(hud._inspector_panel.visible, "UnitInspector opens for friendly unit")
	key(KEY_ESCAPE)
	await frames()
	check(not hud._inspector_panel.visible and not _game.is_paused, "Escape closes UnitInspector without pausing")
	hud.inspect_unit(_game.get_faction_leader(0))
	await frames()
	var weapon_option: OptionButton = hud._inspector_panel._insp_weapon_opt
	var inspector_rect: Rect2 = hud._inspector_panel.get_global_rect()
	check(weapon_option.is_visible_in_tree() and not inspector_rect.intersects(hud._minimap_panel.get_global_rect())
		and not inspector_rect.intersects(hud._squad_bar.get_global_rect()), "Scrollable inspector fits the leader's loadout between Valley Radar and the squad bar")
	weapon_option.grab_focus()
	weapon_option.get_popup().popup()
	await frames()
	key(KEY_ESCAPE)
	await frames()
	check(not weapon_option.get_popup().visible and root.gui_get_focus_owner() != weapon_option and hud._inspector_panel.visible,
		"Escape dismisses the inspector gear popup and releases gameplay focus")
	key(KEY_ESCAPE)
	await frames()
	key(KEY_R)
	await frames()
	check(hud._active_tab == "RELIGION", "R opens Faith")
	press(hud._drawer_content, "Worship")
	check(_game.factions[0]["patron_god"] != _data.PatronGod.NONE, "Worship changes patron")
	press(hud._drawer_content, "Adopt")
	check(_game.factions[0]["tenets"].size() == 1, "Faith can adopt a tenet through the shared action")
	var tenet_focus := root.gui_get_focus_owner() as Button
	check(tenet_focus != null and tenet_focus.text == "Remove", "Faith refresh retains focus by tenet identity when the caption changes")
	key(KEY_ENTER)
	check(_game.factions[0]["tenets"].is_empty(), "The focused tenet can be removed")
	await screenshot("08-faith")
	key(KEY_V)
	await frames()
	check(hud._active_tab == "DIPLOMACY", "V opens Diplomacy")
	await screenshot("09-diplomacy")
	var dip: Control = hud._drawer_views["DIPLOMACY"]
	var earth_root_btn: Button = _find_tagged_button(dip, "faction:4")
	check(earth_root_btn != null, "Diplomacy lists Earth-Root Tribe")
	if earth_root_btn != null:
		earth_root_btn.grab_focus()
		key(KEY_ENTER)
		await frames()
		var op4: int = _game.get_diplomatic_opinion(0, 4)
		var bd4: Dictionary = _game.get_diplomatic_opinion_breakdown(0, 4)
		var bd4_sum: int = int(bd4.get("god", 0)) + int(bd4.get("tenets", 0)) + int(bd4.get("peaceful_offering", 0)) + int(bd4.get("actions", 0)) + int(bd4.get("state_bound", 0))
		check(int(bd4.get("peaceful_offering", 0)) == 15 and int(bd4.get("total", 0)) == op4 and bd4_sum == op4, "Earth-Root opinion breakdown reconciles with GameState")
		check(_has_label_containing(dip, "Peaceful Offering: +15") and _has_label_containing(dip, "Opinion %+d" % op4), "DiplomacyDrawer displays Peaceful Offering and matching opinion")
	dip._selected_faction = 6
	dip.refresh()
	await frames()
	check(dip._selected_faction == 1 and _has_label_containing(dip, str(_game.factions[1]["name"])), "DiplomacyDrawer recovers from unfunded faction 6 selection")
	key(KEY_M)
	await frames()
	check(hud._world_map.visible and hud._active_tab == "" and hud.blocks_world_input(), "M opens World Map and closes the drawer")
	var warhorn_before_map: bool = _game.warhorn_active
	key(KEY_H)
	check(_game.warhorn_active == warhorn_before_map, "World Map blocks campaign combat shortcuts")
	await screenshot("world-map")
	key(KEY_ESCAPE)
	await frames()
	check(not hud._world_map.visible and not _game.is_paused, "Escape closes World Map within the campaign")
	click_at(hud._minimap_panel.get_global_rect().get_center())
	await frames()
	check(hud._world_map.visible, "Clicking Valley Radar opens World Map")
	key(KEY_TAB)
	await frames()
	check(not hud._world_map.visible and hud._active_tab == "MENU", "Tab opens Tribal Command")
	key(KEY_ESCAPE)
	var player: Node = _game.get_faction_leader(0)
	var guard: Node = _game.faction_controllers[0].spawn_colonist(
		player.global_position + Vector3(5.0, 0.0, 0.0), player.lineage, 0, _data.Role.WARRIOR
	)
	key(KEY_F6)
	check(guard.squad_order == _data.SquadOrder.GUARD_BASE, "F6 orders a live warrior to Guard Base")
	key(KEY_F2)
	await frames()
	check(_game.combat_command_system.last_issued_order == _data.SquadOrder.HOLD, "F2 issues Hold")
	var guard_button: Button = hud._order_btns[_data.SquadOrder.GUARD_BASE]
	click_at(guard_button.get_global_rect().get_center())
	check(guard.squad_order == _data.SquadOrder.GUARD_BASE, "Guard HUD button orders the same warrior")
	var follow: Button = hud._order_btns[_data.SquadOrder.FOLLOW]
	follow.grab_focus()
	key(KEY_ENTER)
	check(_game.combat_command_system.last_issued_order == _data.SquadOrder.FOLLOW, "combat HUD button issues Follow")
	check(root.gui_get_focus_owner() != follow, "combat HUD button releases focus after activation")
	click_at(hud._event_toggle.get_global_rect().get_center())
	await frames()
	check(hud._event_expanded and root.gui_get_focus_owner() != hud._event_toggle, "Event Log button toggles and releases focus")
	key(KEY_SPACE)
	await frames()
	check(hud._event_expanded, "Space does not re-trigger Event Log button")
	click_at(hud._event_toggle.get_global_rect().get_center())
	await frames()
	check(not hud._event_expanded, "Event Log button collapses again")
	var fire_before: bool = _game.combat_command_system.global_fire_at_will
	click_at(hud._fire_btn.get_global_rect().get_center())
	await frames()
	check(_game.combat_command_system.global_fire_at_will != fire_before and root.gui_get_focus_owner() != hud._fire_btn, "Fire HUD button toggles and releases focus")
	key(KEY_SPACE)
	await frames()
	check(_game.combat_command_system.global_fire_at_will != fire_before, "Space does not re-trigger Fire HUD button")
	key(KEY_F5)
	await frames()
	check(_game.combat_command_system.global_fire_at_will == fire_before, "F5 restores Fire at Will")
	_game.raid_alert.emit(5, 0, "Cavemen are approaching the Campfire.")
	await frames()
	check(hud._raid_panel.visible and not hud._raid_panel.get_global_rect().intersects(hud._build_banner.get_global_rect()), "raid panel stays clear of build banner")
	await screenshot("10-raid")
	key(KEY_P)
	await frames()
	check(_game.is_paused and hud._overlays._pause_screen.visible, "P opens pause and pauses simulation")
	await screenshot("11-pause")
	key(KEY_F9)
	await frames()
	check(FileAccess.file_exists(save_path), "F9 saves in isolated Godot directory")
	var valid_save := FileAccess.get_file_as_string(save_path)
	key(KEY_P)
	await frames()
	_game.tutorial_step = 4
	key(KEY_B)
	await frames()
	var build_drawer: Control = hud._drawer_views["BUILD"]
	var wall_btn: Button = _find_tagged_button(build_drawer, "PALISADE_WALL")
	check(wall_btn != null, "BuildDrawer lists PALISADE_WALL")
	if wall_btn != null:
		wall_btn.pressed.emit()
		await frames()
	check(build_drawer._user_picked_step == 4 and build_drawer.get_selected_building() == "PALISADE_WALL", "BuildDrawer records user pick for current step before reload")
	key(KEY_ESCAPE)
	await frames()
	dip._selected_faction = 4
	dip._raid_feedback_fid = 4
	dip._raid_feedback_text = "Stale raid feedback"
	key(KEY_P)
	await frames()
	var bad := FileAccess.open(save_path, FileAccess.WRITE)
	bad.store_string("{ broken")
	bad.close()
	var leader: Node = _game.get_faction_leader(0)
	key(KEY_F10)
	check(_game.get_faction_leader(0) == leader and _game.is_paused, "invalid F10 preserves live campaign")
	check(not hud._overlays._pause_status.text.is_empty(), "invalid F10 surfaces error in pause status")
	var restored := FileAccess.open(save_path, FileAccess.WRITE)
	restored.store_string(valid_save)
	restored.close()
	key(KEY_F10)
	await frames(5)
	check(not _game.is_paused and not hud._overlays._pause_screen.visible and _game.has_building(0, "CAMPFIRE", true), "F10 reloads through the active HUD")
	check(build_drawer._user_picked_step == -1 and build_drawer.get_selected_building() == "CAMPFIRE" and build_drawer.get_recommended_building() == "" and not build_drawer.is_place_action_highlighted(), "F10 resets BuildDrawer cached selection and picked step")
	check(dip._selected_faction == 1 and dip._raid_feedback_fid == -1 and dip._raid_feedback_text.is_empty(), "F10 resets DiplomacyDrawer cached selection and raid feedback")
	_game.tutorial_step = 4
	key(KEY_B)
	await frames()
	check(build_drawer.get_selected_building() == "SLEEPING_HUT" and build_drawer.get_recommended_building() == "SLEEPING_HUT" and build_drawer.is_place_action_highlighted(), "BuildDrawer re-recommends Sleeping Hut cleanly after F10 reset")
	key(KEY_ESCAPE)
	await frames()
	key(KEY_ESCAPE)
	press(hud._overlays._pause_screen, "Return to Title")
	await frames()
	press(hud._overlays._confirmation, "Return to Title")
	await frames(6)
	check(not _game.game_active and _game.world_node == null and not _shell._continue.disabled, "return to title tears down and finds a save")
	press(_shell._title, "Load Game")
	await frames()
	check(_shell._page.content.get_child(0).text == "QA Fallow", "load preview displays save metadata")
	await screenshot("12-load")
	press(_shell._page, "Load Campaign")
	await frames(12)
	check(_game.game_active and _game.has_building(0, "CAMPFIRE", true), "Load Campaign restores from title")
	var loaded_hud: Control = _game.hud_controller
	var victor := 1
	var rival: Node = _game.get_faction_leader(victor)
	rival.is_dead = true
	_game.trigger_conquest_if_eligible(victor, 0)
	await frames()
	check(loaded_hud._overlays._conquest_panel.visible and _game.is_paused, "conquest shows a modal and pauses")
	key(KEY_P)
	key(KEY_ESCAPE)
	check(_game.is_paused and loaded_hud._overlays._conquest_panel.visible, "Pause and Escape cannot resume a pending conquest")
	await screenshot("13-conquest")
	press(loaded_hud._overlays._conquest_panel, "Make a Tributary")
	check(not _game.is_paused and _game.get_diplomatic_state(0, victor) == _data.DiplomaticState.TRIBUTARY, "conquest action creates a tributary through GameState")
	_game.time_of_day = 23.0
	preferences.set_value("psx", true)
	await frames(12)
	check(_game.world_node.is_psx_filter_enabled(), "PSX toggle updates the live world")
	await screenshot("14-night")
	for tribe_id in range(2, 5):
		_game.set_diplomatic_state(0, tribe_id, _data.DiplomaticState.ALLIED)
	_game.check_victory_conditions()
	await frames()
	check(loaded_hud._overlays._endgame_panel.visible and _game.campaign_finished, "victory opens its result screen")
	await screenshot("15-victory")
	press(loaded_hud._overlays._endgame_panel, "Return to Title")
	await frames(7)
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	press(_shell._title, "Load Game")
	await frames()
	check(_shell._page.content.get_child(0).text.contains("invalid"), "title reports a corrupt save")
	key(KEY_ESCAPE)
	press(_shell._title, "New Game")
	await frames()
	press(_shell._page, "Awaken in the Valley")
	await frames(12)
	check(_game.game_active and not _game.factions[0]["is_founded"], "a second new campaign starts cleanly")
	var new_hud: Control = _game.hud_controller
	press(new_hud._tutorial_panel, "Skip")
	check(_game.tutorial_skipped and _game.is_raid_grace_active(), "Guide Skip leaves the Peace Buffer active")
	key(KEY_ESCAPE)
	press(new_hud._overlays._pause_screen, "Return to Title")
	await frames()
	press(new_hud._overlays._confirmation, "Return to Title")
	await frames(6)
	check(not _game.game_active and _game.player_controller == null, "Repeated return releases the active controller")
	if _failed:
		print("CAMPAIGN UI VERIFICATION FAILED")
		quit(1)
		return
	var quit_button := button_in(_shell._title, "Quit")
	if quit_button == null:
		push_error("Title Quit button is unavailable")
		quit(1)
		return
	print("CAMPAIGN UI VERIFICATION PASSED")
	create_timer(1.0).timeout.connect(_fail_quit)
	press(_shell._title, "Quit")


func _has_role_control(roster: Control, key_name: String) -> bool:
	return _find_role_control(roster, key_name) != null


func _find_role_control(roster: Control, key_name: String) -> OptionButton:
	for control in roster.find_children("*", "OptionButton", true, false):
		if control.get_meta("drawer_focus", "") == key_name:
			return control as OptionButton
	return null


func _find_tagged_button(scope: Node, key_name: String) -> Button:
	for control in scope.find_children("*", "Button", true, false):
		if control.get_meta("drawer_focus", "") == key_name and control.is_visible_in_tree():
			return control as Button
	return null


func _has_label_containing(scope: Node, needle: String) -> bool:
	for node in scope.find_children("*", "Label", true, false):
		var lbl := node as Label
		if lbl != null and lbl.is_visible_in_tree() and lbl.text.contains(needle):
			return true
	return false


func _fail_quit() -> void:
	push_error("Title Quit did not terminate the scene tree")
	quit(1)


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
	await screenshot("07-colony")
	press(hud._drawer_content, "Crafting")
	await frames()
	check(hud._drawer_views["COLONY"]._queue_label != null, "crafting queue renders")
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
	key(KEY_TAB)
	await frames()
	check(hud._active_tab == "MENU", "Tab opens Tribal Command")
	key(KEY_ESCAPE)
	key(KEY_F2)
	await frames()
	check(_game.combat_command_system.last_issued_order == _data.SquadOrder.HOLD, "F2 issues Hold")
	var follow: Button = hud._order_btns[_data.SquadOrder.FOLLOW]
	follow.grab_focus()
	key(KEY_ENTER)
	check(_game.combat_command_system.last_issued_order == _data.SquadOrder.FOLLOW, "combat HUD button issues Follow")
	_game.raid_alert.emit(5, 0, "Cavemen are approaching the Campfire.")
	await screenshot("10-raid")
	key(KEY_P)
	await frames()
	check(_game.is_paused and hud._overlays._pause_screen.visible, "P opens pause and pauses simulation")
	await screenshot("11-pause")
	key(KEY_F9)
	await frames()
	check(FileAccess.file_exists(save_path), "F9 saves in isolated Godot directory")
	var valid_save := FileAccess.get_file_as_string(save_path)
	var bad := FileAccess.open(save_path, FileAccess.WRITE)
	bad.store_string("{ broken")
	bad.close()
	var leader: Node = _game.get_faction_leader(0)
	key(KEY_F10)
	check(_game.get_faction_leader(0) == leader and _game.is_paused, "invalid F10 preserves live campaign")
	var restored := FileAccess.open(save_path, FileAccess.WRITE)
	restored.store_string(valid_save)
	restored.close()
	key(KEY_F10)
	await frames(5)
	check(not _game.is_paused and not hud._overlays._pause_screen.visible and _game.has_building(0, "CAMPFIRE", true), "F10 reloads through the active HUD")
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
	check(not _game.is_paused and _game.get_diplomatic_state(0, victor) == _data.DiplomaticState.ALLIED, "conquest action resolves through GameState")
	_game.time_of_day = 23.0
	preferences.set_value("psx", true)
	await frames(12)
	check(_game.world_node.is_psx_filter_enabled(), "PSX toggle updates the live world")
	await screenshot("14-night")
	for tribe_id in range(1, 5):
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
	for control in roster.find_children("*", "OptionButton", true, false):
		if control.get_meta("drawer_focus", "") == key_name:
			return true
	return false


func _fail_quit() -> void:
	push_error("Title Quit did not terminate the scene tree")
	quit(1)


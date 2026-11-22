extends SceneTree
## Forward+ end-to-end probe for Phase 2A: Playable Opening Tutorial.
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.

const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")

var _game: Node
var _data: Node
var _shell: Node
var _failed := false
var _screens := false
var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS ", caption)
	else:
		push_error("FAIL " + caption)
		_failed = true


func frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame


func screenshot(img_name: String) -> void:
	if not _screens:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.save_png(_out.path_join(img_name + ".png")) == OK, "screenshot " + img_name + " " + str(img.get_size()))


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
		var btn := node as Button
		if btn != null and btn.text == label and btn.is_visible_in_tree() and not btn.disabled:
			return btn
	return null


func press(scope: Node, label: String) -> void:
	var button := button_in(scope, label)
	check(button != null and button.is_visible_in_tree() and not button.disabled, "button " + label)
	if button != null:
		button.grab_focus()
		key(KEY_ENTER)


func _find_role_option(scope: Node) -> OptionButton:
	for ctrl in scope.find_children("*", "OptionButton", true, false):
		var meta: String = str(ctrl.get_meta("drawer_focus", ""))
		if meta.begins_with("unit-role:") and ctrl.is_visible_in_tree():
			return ctrl as OptionButton
	return null


func _move_leader(pc: Node, pos: Vector3) -> void:
	pc.leader_unit.global_position = pos
	_game.spatial_index.update_unit(pc.leader_unit)
	if pc.camera_pivot != null:
		pc.camera_pivot.global_position = pos + Vector3(0.0, 1.4, 0.0)


func _run() -> void:
	_game = root.get_node("GameState")
	_data = root.get_node("GameData")

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out = argument.trim_prefix("--out-dir=")
	if not _out.is_empty() and (not _out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_out) != OK):
		push_error("Pass a writable absolute --out-dir.")
		quit(1)
		return
	_screens = not _out.is_empty() and DisplayServer.get_name() != "headless"

	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return

	var probe_path := "user://opening_tutorial_probe_%d.json" % Time.get_ticks_usec()
	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_shell = title_scene.instantiate()
	root.add_child(_shell)
	await frames(2)

	press(_shell._title, "Start")
	await frames(14)
	press(_shell._title, "New Game")
	await frames(2)
	_shell._page._tribe.text = "Tutorial Tribe"
	press(_shell._page, "Awaken in the Valley")
	await frames(12)

	check(_game.game_active and _game.hud_controller != null and _game.player_controller != null, "New campaign starts cleanly")
	if not _game.game_active or _game.hud_controller == null or _game.player_controller == null:
		quit(1)
		return

	var hud: Control = _game.hud_controller
	var pc: Node = _game.player_controller
	var beacon: Node3D = pc.get_tutorial_beacon()
	check(beacon != null and is_instance_valid(beacon), "TutorialBeacon instantiated")
	check(hud._tutorial_panel.visible and hud._tutorial_panel.size.y <= 160.0, "Guide panel visible with compact height")

	# --- STEP 1: Recruit 3 wild wanderers ---
	var target1: Dictionary = AwakeningGuide.get_objective_target(_game)
	check(bool(target1["active"]) and int(target1["step"]) == 1 and bool(target1["has_position"]), "Step 1 targets nearest wild wanderer")
	await frames(2)
	check(beacon.is_beacon_visible(), "Beacon visible on Step 1")
	check(beacon.is_pointer_visible(), "Directional ground pointer visible when far from Step 1 target")

	var start_camp: Vector3 = _game.factions[0]["camp_position"]
	for i in range(3):
		var t_step1: Dictionary = AwakeningGuide.get_objective_target(_game)
		var wpos: Vector3 = t_step1["position"]
		check(beacon.get_beacon_position().distance_to(Vector3(wpos.x, 0.0, wpos.z)) < 0.1, "Beacon tracks targeted wanderer %d" % (i + 1))
		var outward: Vector3 = wpos - start_camp
		outward.y = 0.0
		outward = outward.normalized() if outward.length() > 0.1 else Vector3.BACK
		_move_leader(pc, wpos + outward * 5.4)
		await frames(3)
		if i == 0:
			check(beacon.is_pointer_visible(), "Directional ground pointer shows at 5.4 m from Step 1 target")
			check(beacon.get_prompt_text() == "[E] Recruit", "Proximity prompt shows [E] Recruit near wanderer")
			await screenshot("tutorial_01_step1_recruit_pointer")
		key(KEY_E)
		await frames(3)

	check(_game.tutorial_step == 2 and AwakeningGuide.recruit_count(_game) >= 3, "Recruiting 3 wanderers advances tutorial to Step 2")

	# --- STEP 2: Found village (Build highlight + Campfire auto-select + placement) ---
	await frames(2)
	var target2: Dictionary = AwakeningGuide.get_objective_target(_game)
	check(int(target2["step"]) == 2 and str(target2["highlight_hud"]) == "BUILD" and str(target2["highlight_building"]) == "CAMPFIRE", "Step 2 targets Build -> CAMPFIRE")
	check(hud.get_highlighted_hud_tab() == "BUILD", "HUD highlights Build button on Step 2")
	check(beacon.is_beacon_visible(), "Beacon points to clear founding ground on Step 2")

	key(KEY_B)
	await frames(2)
	check(hud._active_tab == "BUILD", "B opens Build drawer")
	var build_drawer: Control = hud._drawer_views["BUILD"]
	check(build_drawer.get_recommended_building() == "CAMPFIRE" and build_drawer.get_selected_building() == "CAMPFIRE", "BuildDrawer recommends and auto-selects CAMPFIRE on Step 2")
	check(build_drawer.is_place_action_highlighted(), "BuildDrawer highlights Place Campfire action on Step 2")
	check(_has_label_containing(build_drawer, "RECOMMENDED"), "BuildDrawer renders RECOMMENDED badge")
	await screenshot("tutorial_02_step2_build_drawer")
	press(hud._drawer_content, "Place Campfire")
	await frames(2)
	check(pc.is_build_mode and pc.blueprint_type == "CAMPFIRE", "Campfire blueprint mode starts")
	check(hud._tutorial_body.text.contains("Left-click [LMB]"), "Guide body updates to placement instruction in build mode")

	var vp_size: Vector2 = root.get_visible_rect().size
	var ghost_motion := InputEventMouseMotion.new()
	ghost_motion.position = vp_size * Vector2(0.54, 0.45)
	ghost_motion.global_position = vp_size * Vector2(0.54, 0.45)
	root.push_input(ghost_motion, true)
	await frames(2)
	await screenshot("tutorial_03_step2_campfire_ghost")
	click_at(vp_size * Vector2(0.54, 0.45))
	await frames(4)
	check(bool(_game.factions[0]["is_founded"]) and _game.has_building(0, "CAMPFIRE", true), "Campfire placed and village founded")
	check(_game.tutorial_step == 3, "Founding Campfire advances tutorial to Step 3")

	# --- STEP 3: Gather resource [E] & assign villager role [C] ---
	await frames(2)
	var target3: Dictionary = AwakeningGuide.get_objective_target(_game)
	check(int(target3["step"]) == 3 and bool(target3["has_position"]) and str(target3["highlight_hud"]) == "COLONY", "Step 3 targets resource node and highlights Colony")
	check(hud.get_highlighted_hud_tab() == "COLONY", "HUD highlights Colony button on Step 3")
	var res_pos: Vector3 = target3["position"]
	_move_leader(pc, res_pos + Vector3(0.0, 0.0, 1.2))
	await frames(3)
	check(not beacon.is_pointer_visible(), "Directional ground pointer hides when close to Step 3 target")
	check(beacon.get_prompt_text() == "[E] Harvest", "Proximity prompt shows [E] Harvest near resource node")
	await screenshot("tutorial_04_step3_harvest_prompt")
	var harvest_tries := 0
	while not _game.tutorial_harvested and harvest_tries < 4:
		pc._harvest_cd = 0.0
		key(KEY_E)
		await frames(3)
		harvest_tries += 1
	check(_game.tutorial_harvested, "Pressing E harvests resource node")
	check(hud._tutorial_progress.text.contains("[x] Harvest"), "Checklist marks Harvest complete")

	key(KEY_C)
	await frames(2)
	check(hud._active_tab == "COLONY", "C opens Colony drawer")
	var colony_drawer: Control = hud._drawer_views["COLONY"]
	check(colony_drawer.has_tutorial_role_highlight(), "ColonyDrawer highlights villager role assignment on Step 3")
	await screenshot("tutorial_05_step3_colony_role")
	var role_opt: OptionButton = _find_role_option(colony_drawer)
	check(role_opt != null, "Colony roster exposes villager role selector")
	if role_opt != null:
		var builder_idx: int = role_opt.get_item_index(_data.Role.BUILDER_CRAFTER)
		role_opt.select(builder_idx)
		role_opt.item_selected.emit(builder_idx)
	await frames(2)
	check(not colony_drawer.has_tutorial_role_highlight(), "ColonyDrawer clears role highlight after assigning villager role")
	key(KEY_ESCAPE)
	await frames(3)
	check(_game.tutorial_assigned_role and _game.tutorial_step == 4, "Assigning villager role advances tutorial to Step 4")

	# --- STEP 4: Build & Finish Sleeping Hut + Save/Load resumption ---
	var target4_pre: Dictionary = AwakeningGuide.get_objective_target(_game)
	check(int(target4_pre["step"]) == 4 and str(target4_pre["highlight_hud"]) == "BUILD" and str(target4_pre["highlight_building"]) == "SLEEPING_HUT", "Step 4 targets Build -> SLEEPING_HUT")
	check(hud.get_highlighted_hud_tab() == "BUILD", "HUD highlights Build button on Step 4")

	# Move leader to clear open spot away from Campfire before placing Sleeping Hut
	var camp_pos: Vector3 = _game.factions[0]["camp_position"]
	_move_leader(pc, camp_pos + Vector3(14.0, 0.0, 6.0))
	await frames(3)

	key(KEY_B)
	await frames(2)
	check(build_drawer.get_recommended_building() == "SLEEPING_HUT" and build_drawer.get_selected_building() == "SLEEPING_HUT", "BuildDrawer recommends and auto-selects SLEEPING_HUT on Step 4")
	check(build_drawer.is_place_action_highlighted(), "BuildDrawer highlights Place Blueprint action on Step 4")
	await screenshot("tutorial_06_step4_hut_build_drawer")
	press(hud._drawer_content, "Place Blueprint")
	await frames(2)
	check(pc.is_build_mode and pc.blueprint_type == "SLEEPING_HUT", "Sleeping Hut blueprint mode starts")

	click_at(vp_size * Vector2(0.55, 0.45))
	await frames(4)
	var huts_all: Array = _game.get_faction_buildings(0, "SLEEPING_HUT", false)
	check(huts_all.size() >= 1, "Sleeping Hut blueprint placed")
	if huts_all.is_empty():
		quit(1)
		return
	var hut: Node3D = huts_all[0] as Node3D
	check(not bool(hut.get("is_constructed")), "Sleeping Hut starts as unfinished blueprint")
	check(_game.tutorial_step == 4, "Unfinished Sleeping Hut keeps tutorial at Step 4")
	check(hud.get_highlighted_hud_tab() == "", "Build highlight clears once Sleeping Hut blueprint is placed")
	var target4_bp: Dictionary = AwakeningGuide.get_objective_target(_game)
	check(bool(target4_bp["has_position"]) and (target4_bp["position"] as Vector3).distance_to(hut.global_position) < 0.2, "Step 4 target tracks unfinished Sleeping Hut blueprint")
	check(beacon.is_beacon_visible() and beacon.get_beacon_position().distance_to(Vector3(hut.global_position.x, 0.0, hut.global_position.z)) < 0.2, "Beacon moves to unfinished Sleeping Hut blueprint")

	# Mid-tutorial Save/Load check at Step 4
	check(_game.save_game(probe_path), "Save mid-tutorial at Step 4")
	check(_game.load_game(probe_path), "Reload mid-tutorial save at Step 4")
	await frames(3)
	pc = _game.player_controller
	hud = _game.hud_controller
	beacon = pc.get_tutorial_beacon()
	check(_game.tutorial_step == 4 and hud._tutorial_panel.visible, "Reload restores exact Step 4 and guide panel")
	var reloaded_huts: Array = _game.get_faction_buildings(0, "SLEEPING_HUT", false)
	check(reloaded_huts.size() == 1 and not bool(reloaded_huts[0].get("is_constructed")), "Reload restores unfinished Sleeping Hut blueprint")
	hut = reloaded_huts[0] as Node3D
	check(beacon.is_beacon_visible() and beacon.get_beacon_position().distance_to(Vector3(hut.global_position.x, 0.0, hut.global_position.z)) < 0.2, "Reload restores beacon on Sleeping Hut blueprint")

	# Assist construction with [E] until finished
	_move_leader(pc, hut.global_position + Vector3(0.0, 0.0, 1.8))
	await frames(3)
	check(not beacon.is_pointer_visible(), "Directional ground pointer hides when close to Step 4 blueprint")
	check(beacon.get_prompt_text() == "[E] Help Build", "Proximity prompt shows [E] Help Build near Sleeping Hut blueprint")
	await screenshot("tutorial_07_step4_hut_assist")
	var guard_iters := 0
	while not bool(hut.get("is_constructed")) and guard_iters < 12:
		pc._harvest_cd = 0.0
		key(KEY_E)
		await frames(2)
		guard_iters += 1
	check(bool(hut.get("is_constructed")), "Pressing [E] finishes Sleeping Hut construction")
	check(_game.tutorial_step == 5, "Finishing Sleeping Hut advances tutorial to Step 5")

	# --- STEP 5: Combat Readiness & Handover ---
	await frames(2)
	check(not beacon.is_beacon_visible(), "Beacon hides on Step 5")
	check(hud.get_highlighted_hud_tab() == "", "No HUD button highlighted on Step 5")
	await screenshot("tutorial_08_step5_combat")
	var res_before: Dictionary = _game.factions[0]["resources"].duplicate()
	click_at(vp_size * Vector2(0.75, 0.40))
	await frames(3)
	check(_game.tutorial_cleaved, "LMB performs Leader Heavy Cleave")
	key(KEY_F)
	await frames(3)
	check(_game.tutorial_thrown and _game.tutorial_completed, "F throws Javelin and completes Awakening Guide")
	await frames(2)
	check(not hud._tutorial_panel.visible and not beacon.is_beacon_visible(), "Completed tutorial hides guide panel and beacon")
	var res_after: Dictionary = _game.factions[0]["resources"]
	check(is_equal_approx(float(res_after["food"]), float(res_before["food"]) + 10.0), "Completion pays +10 Food")
	check(is_equal_approx(float(res_after["wood"]), float(res_before["wood"]) + 10.0), "Completion pays +10 Wood")
	check(is_equal_approx(float(res_after["flint"]), float(res_before["flint"]) + 5.0), "Completion pays +5 Flint")
	_game._process(0.5)
	check(is_equal_approx(float(_game.factions[0]["resources"]["food"]), float(res_after["food"])), "Completion bonus paid only once")

	# --- FRESH SKIP CHECK ---
	_game.start_new_campaign("Enoch", "Skip Probe", _data.Lineage.CRAG_BORN)
	await frames(4)
	check(hud._tutorial_panel.visible and beacon.is_beacon_visible() and _game.is_raid_grace_active(), "Fresh campaign shows guide, beacon, and Peace Buffer")
	press(hud._tutorial_panel, "Skip")
	await frames(3)
	check(_game.tutorial_skipped and not hud._tutorial_panel.visible and not beacon.is_beacon_visible(), "Skip hides guide panel and beacon")
	check(hud.get_highlighted_hud_tab() == "", "Skip clears HUD highlights")
	check(_game.is_raid_grace_active(), "Skip keeps 210s Peace Buffer active")

	_game.end_campaign()
	root.remove_child(_shell)
	_shell.queue_free()
	if FileAccess.file_exists(probe_path):
		DirAccess.remove_absolute(probe_path)
	await frames(2)

	if _failed:
		print("OPENING TUTORIAL VERIFICATION FAILED")
		quit(1)
	else:
		print("OPENING TUTORIAL VERIFICATION PASSED")
		quit(0)


func _has_label_containing(scope: Node, needle: String) -> bool:
	for node in scope.find_children("*", "Label", true, false):
		var lbl := node as Label
		if lbl != null and lbl.is_visible_in_tree() and lbl.text.contains(needle):
			return true
	return false

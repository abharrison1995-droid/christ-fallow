extends SceneTree
## Forward+ verification probe & optional screenshot capture for First-Person POV Mode.
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.

const Farming = preload("res://scripts/core/farming_rules.gd")

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


func physics_frames(count: int = 2) -> void:
	for _i in range(count):
		await physics_frame


func screenshot(img_name: String) -> void:
	if not _screens:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.save_png(_out.path_join(img_name + ".png")) == OK, "screenshot " + img_name + " " + str(img.get_size()))


func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func key(code: Key) -> void:
	key_event(code, true)
	key_event(code, false)


func move_pointer(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)


func mouse_button(pos: Vector2, button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = button_index
	event.pressed = pressed
	root.push_input(event, true)


func wheel(button_index: MouseButton, pos: Vector2) -> void:
	move_pointer(pos)
	mouse_button(pos, button_index, true)


func click_at(pos: Vector2, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	move_pointer(pos)
	mouse_button(pos, button_index, true)
	mouse_button(pos, button_index, false)


func drag_look(relative: Vector2, pos: Vector2) -> void:
	mouse_button(pos, MOUSE_BUTTON_RIGHT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)
	mouse_button(pos, MOUSE_BUTTON_RIGHT, false)


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


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return
	seed(17394)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out = arg.trim_prefix("--out-dir=")
			_screens = true
	if _screens and (not _out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_out) != OK):
		push_error("Pass a writable absolute --out-dir.")
		quit(1)
		return

	_game = root.get_node("GameState")
	_data = root.get_node("GameData")
	var title_scene := load("res://scenes/ui/title_screen.tscn") as PackedScene
	_shell = title_scene.instantiate()
	root.add_child(_shell)
	await frames(3)

	press(_shell._title, "Start")
	await frames(14)
	press(_shell._title, "New Game")
	await frames(3)
	press(_shell._page, "Awaken in the Valley")
	await frames(12)

	var hud: Control = _game.hud_controller
	var pc: Node = _game.player_controller
	var leader: CharacterBody3D = pc.leader_unit
	check(_game.game_active and is_instance_valid(pc) and is_instance_valid(leader) and is_instance_valid(hud), "Campaign started for First-Person POV checks")

	# 1. Default Third-Person baseline
	check(pc.is_first_person == false, "Starts in Third-Person POV")
	check(hud._pov_btn != null and hud._pov_btn.text == "POV: 3rd  Z", "HUD shows POV: 3rd  Z by default")
	check(hud._fp_reticle != null and not hud._fp_reticle.visible, "Reticle is hidden in Third-Person POV")
	check(pc._fp_viewmodel.get_child_count() == 0 and leader._cached_fp_meshes.is_empty(), "Third-person startup leaves the POV meshes and viewmodel unbuilt")

	# 2. Lineage eye-height scaling check
	var orig_lin: int = int(leader.lineage)
	leader.lineage = _data.Lineage.SWIFT_KIN
	var eye_swift: float = leader.get_eye_height()
	leader.lineage = _data.Lineage.CRAG_BORN
	var eye_crag: float = leader.get_eye_height()
	leader.lineage = _data.Lineage.GOLIATH
	var eye_goliath: float = leader.get_eye_height()
	leader.lineage = orig_lin
	check(eye_swift < eye_crag and eye_crag < eye_goliath, "Eye height scales cleanly by lineage (%.2f < %.2f < %.2f)" % [eye_swift, eye_crag, eye_goliath])

	# 3. Enter First-Person via Z hotkey
	key(KEY_Z)
	await physics_frames(2)
	await frames(2)
	check(pc.is_first_person == true, "Z enters First-Person POV")
	check(is_equal_approx(pc.camera.fov, 72.0) and is_equal_approx(pc.camera.near, 0.08), "First-Person POV uses 72 degree FOV and 0.08 m near clip")
	check(hud._pov_btn.text == "POV: 1st  Z" and hud._pov_btn.button_pressed, "HUD POV button updates to POV: 1st  Z")
	check(hud._fp_reticle.visible, "First-Person center reticle appears in HUD")
	check(leader.is_first_person_hidden(), "Leader third-person meshes switch to shadow-only occlusion mode")
	check(leader._cached_fp_meshes.size() > 0, "Leader caches MeshInstance3D nodes for zero-traversal POV switching (%d)" % leader._cached_fp_meshes.size())
	check(_body_hidden(leader), "Leader body keeps its shadow while accessories leave the camera and shadow pass")
	check(not leader._hp_bg.visible and not leader._hp_fill.visible and not leader._leader_nameplate.visible, "Leader overhead HP and nameplate hide in First-Person POV")
	check(pc._fp_viewmodel != null and pc._fp_viewmodel.visible, "First-Person weapon viewmodel is visible")
	var preferences := root.get_node("Preferences")
	for scale in [0.9, 1.1]:
		preferences.set_value("ui_scale", scale)
		await frames(2)
		var squad_rect: Rect2 = hud._squad_bar.get_global_rect()
		check(root.get_visible_rect().encloses(squad_rect) and squad_rect.encloses(hud._pov_btn.get_global_rect()), "POV button and squad bar fit at %d%% interface scale" % roundi(scale * 100.0))
	preferences.set_value("ui_scale", 1.0)

	# 4. Look rotation, viewmodel look sway, & camera-aligned strafe check
	pc.rotate_first_person_view(30.0, 8.0)
	check(pc._fp_viewmodel._look_sway_rot.length() > 0.2, "First-Person look delta induces angular viewmodel sway")
	await physics_frames(2)
	var yaw_rad_before: float = leader.rotation.y
	var ev_a := InputEventKey.new()
	ev_a.keycode = KEY_A
	ev_a.pressed = true
	Input.parse_input_event(ev_a)
	await physics_frames(4)
	var moved_vel: Vector3 = leader.velocity
	var yaw_rad_after: float = leader.rotation.y
	var ev_a_rel := InputEventKey.new()
	ev_a_rel.keycode = KEY_A
	ev_a_rel.pressed = false
	Input.parse_input_event(ev_a_rel)
	await physics_frames(2)
	check(Vector2(moved_vel.x, moved_vel.z).length() > 1.0 and absf(angle_difference(yaw_rad_before, yaw_rad_after)) < 0.05,
		"First-Person A strafe moves laterally while keeping facing aligned to camera yaw")
	for _decay in range(28):
		await physics_frames(1)
	check(pc._fp_viewmodel._look_sway_rot.length() < 0.2, "First-Person viewmodel look sway decays smoothly back to rest")

	await _verify_hud_blocking(pc, hud)

	# Stage crisp Stone Age camp scene for visual captures
	_game.skip_awakening_guide()
	if is_instance_valid(hud._tutorial_panel):
		hud._tutorial_panel.hide()
	_game.time_of_day = 11.0 # Bright crisp midday lighting
	var fc0: Node = _game.faction_controllers[0]
	var fc5: Node = _game.faction_controllers[5]
	var camp_origin: Vector3 = _game.factions[0]["camp_position"]
	for w_unit in _game.get_faction_units(-1, true):
		w_unit.convert_to_faction(0, false)
	_game.factions[0]["is_founded"] = true
	fc0.spawn_building("CAMPFIRE", camp_origin + Vector3(0.0, 0.0, -4.5), 0.0, true)
	fc0.spawn_building("SLEEPING_HUT", camp_origin + Vector3(-5.8, 0.0, -8.0), 0.45, true)
	fc0.spawn_building("SACRED_TOTEM", camp_origin + Vector3(5.2, 0.0, -7.2), -0.35, true)
	fc0.spawn_colonist(camp_origin + Vector3(-4.2, 0.0, -6.2), _data.Lineage.CRAG_BORN, _data.Gender.FEMALE, _data.Role.FORAGER)
	fc0.spawn_colonist(camp_origin + Vector3(3.6, 0.0, -5.8), _data.Lineage.GOLIATH, _data.Gender.MALE, _data.Role.WARRIOR)

	leader.global_position = camp_origin + Vector3(0.0, 0.0, 4.5)
	_game.spatial_index.update_unit(leader)
	pc.cam_yaw = 0.0 # Facing -Z toward the camp
	pc.fp_pitch = -7.0
	await physics_frames(4)
	await frames(4)
	await screenshot("fp_01_village_spear_pov")

	# 6. First-Person Heavy Cleave (LMB) & mid-swing camera-space pitch check
	if is_instance_valid(hud._inspector_panel):
		hud._inspector_panel.close()
	var foe1: Node = fc5.spawn_colonist(leader.global_position + Vector3(0.0, 0.0, -2.3), _data.Lineage.CAVEMAN, _data.Gender.MALE, _data.Role.WARRIOR, false, false, true)
	foe1.set_role_and_class(_data.Role.WARRIOR, _data.WarriorClass.BRUTE)
	_game.spatial_index.update_unit(foe1)
	foe1.look_at(leader.global_position, Vector3.UP)
	var foe1_hp_before: float = float(foe1.hp)
	pc.cam_yaw = 0.0
	pc.fp_pitch = -5.0
	pc._attack_cd = 0.0
	await physics_frames(1)
	click_at(root.get_visible_rect().size * 0.5, MOUSE_BUTTON_LEFT)
	await physics_frames(7)
	var min_cleave_pitch: float = float(pc._fp_viewmodel._right_pivot.rotation_degrees.x) + float(pc._fp_viewmodel._spear_mount.rotation_degrees.x)
	var cleave_yaw: float = float(pc._fp_viewmodel._right_pivot.rotation_degrees.y)
	check(min_cleave_pitch > -80.0 and cleave_yaw > 10.0,
		"First-Person CLEAVE sweeps across viewport without plunging downward (combined pitch %.1f°, yaw %.1f°)" % [min_cleave_pitch, cleave_yaw])
	await screenshot("fp_02_melee_cleave_pov")
	await physics_frames(1)
	check(float(foe1.hp) < foe1_hp_before, "First-Person Heavy Cleave damages enemy straight ahead")

	# Verify pitched-down (-28°) & pitched-up (+24°) melee cleave + action viewmodel coverage
	pc.fp_pitch = -28.0
	pc._attack_cd = 0.0
	var foe1_hp_mid: float = float(foe1.hp)
	await physics_frames(1)
	click_at(root.get_visible_rect().size * 0.5, MOUSE_BUTTON_LEFT)
	await physics_frames(2)
	check(float(foe1.hp) < foe1_hp_mid, "First-Person pitched-down (-28°) cleave connects with look target")

	pc.fp_pitch = 24.0
	pc._attack_cd = 0.0
	var foe1_hp_hi: float = float(foe1.hp)
	await physics_frames(1)
	click_at(root.get_visible_rect().size * 0.5, MOUSE_BUTTON_LEFT)
	await physics_frames(2)
	check(float(foe1.hp) < foe1_hp_hi, "First-Person pitched-up (+24°) cleave connects with look target")

	if is_instance_valid(foe1):
		foe1.is_dead = true
		foe1._unregister_from_index()
		foe1.hide()
		foe1.queue_free()
	await physics_frames(2)

	# Verify WORK, DASH, BLESSING viewmodel animations update pivot transforms cleanly
	var rest_r: Vector3 = pc._fp_viewmodel._right_pivot.position
	pc._fp_viewmodel.trigger_action("WORK", 0.30)
	await physics_frames(4)
	check(pc._fp_viewmodel._tool_mount.visible and not pc._fp_viewmodel._spear_mount.visible and pc._fp_viewmodel._right_pivot.position != rest_r,
		"First-Person WORK action swaps spear for mallet and animates strike")
	pc._fp_viewmodel.trigger_action("DASH", 0.24)
	await physics_frames(4)
	check(pc._fp_viewmodel._right_pivot.position.z < rest_r.z - 0.04,
		"First-Person DASH action tucks arms forward during dash")
	pc._fp_viewmodel.trigger_action("BLESSING", 0.40)
	await physics_frames(6)
	check(pc._fp_viewmodel._right_pivot.position.y > rest_r.y + 0.04 and pc._fp_viewmodel._left_pivot.position.y > pc._fp_viewmodel._REST_LEFT_POS.y + 0.04,
		"First-Person BLESSING raises both arms skyward")
	for _settle in range(30):
		await physics_frames(1)

	# 7. First-Person 3D Javelin Throw (F)
	if is_instance_valid(hud._inspector_panel):
		hud._inspector_panel.close()
	var foe2: Node = fc5.spawn_colonist(leader.global_position + Vector3(0.0, 0.0, -12.5), _data.Lineage.CAVEMAN, _data.Gender.MALE, _data.Role.WARRIOR, false, false, true)
	foe2.set_role_and_class(_data.Role.WARRIOR, _data.WarriorClass.SPEARMAN)
	_game.spatial_index.update_unit(foe2)
	foe2.look_at(leader.global_position, Vector3.UP)
	pc.cam_yaw = 0.0
	pc.fp_pitch = -1.5
	pc._javelin_cd = 0.0
	await physics_frames(1)
	var proj_before: int = _game.projectiles_container.get_child_count()
	key(KEY_F)
	await physics_frames(3)
	check(_game.projectiles_container.get_child_count() > proj_before or float(foe2.hp) < float(foe2.max_hp),
		"First-Person Javelin throw launches projectile toward crosshair")
	await screenshot("fp_03_javelin_throw_pov")
	for p in _game.projectiles_container.get_children():
		p.queue_free()
	if is_instance_valid(foe2):
		foe2.is_dead = true
		foe2._unregister_from_index()
		foe2.hide()
		foe2.queue_free()
	await physics_frames(2)

	# 8. First-Person Blueprint Building placement mode
	if is_instance_valid(hud._inspector_panel):
		hud._inspector_panel.close()
	pc.cam_yaw = 22.0
	pc.fp_pitch = -16.0
	pc.enter_build_mode("SLEEPING_HUT")
	await physics_frames(3)
	var bp_dist: float = leader.global_position.distance_to(pc._blueprint_ghost.global_position)
	check(pc.is_build_mode and is_instance_valid(pc._blueprint_ghost) and bp_dist >= 2.3 and bp_dist <= 14.5,
		"First-Person blueprint ghost projects in front of leader within 2.4..14m (%.2fm)" % bp_dist)
	await screenshot("fp_04_blueprint_build_pov")
	pc.exit_build_mode()
	await frames(2)

	# 9. Mounted Mammoth First-Person POV
	if is_instance_valid(hud._inspector_panel):
		hud._inspector_panel.close()
	var mammoth: Node3D = _game.world_node._spawn_animal("MAMMOTH", camp_origin + Vector3(1.5, 0.0, 5.5))
	mammoth.owner_faction = 0
	mammoth.training_feeds = Farming.MOUNT_TRAINING
	mammoth.maturity_remaining = 0.0
	mammoth.is_aggro = false
	_game.spatial_index.update_wildlife(mammoth)
	leader.global_position = mammoth.global_position + Vector3(0.0, 0.0, 1.4)
	_game.spatial_index.update_unit(leader)
	pc.cam_yaw = 6.0
	pc.fp_pitch = -22.0
	key(KEY_E)
	await physics_frames(4)
	check(pc.is_mounted() and leader.get_eye_height() > eye_crag + 1.5, "First-Person Mounted Mammoth raises leader eye height above %.2fm (%.2fm)" % [eye_crag + 1.5, leader.get_eye_height()])
	await screenshot("fp_05_mounted_mammoth_pov")
	key(KEY_E)
	await physics_frames(3)

	# 10. Scroll-Wheel exit/re-entry & HUD button toggle check
	wheel(MOUSE_BUTTON_WHEEL_DOWN, root.get_visible_rect().size * 0.5)
	await physics_frames(2)
	await frames(2)
	check(not pc.is_first_person and is_equal_approx(pc.camera.fov, 58.0) and not leader.is_first_person_hidden(),
		"Scroll Down exits First-Person POV back to Third-Person and restores leader meshes")
	wheel(MOUSE_BUTTON_WHEEL_UP, root.get_visible_rect().size * 0.5)
	await physics_frames(2)
	await frames(2)
	check(pc.is_first_person and is_equal_approx(pc.camera.fov, 72.0), "Scroll Up at 5.5m close zoom re-enters First-Person POV")
	var first_pivot: Node3D = pc._fp_viewmodel._right_pivot
	click_at(hud._pov_btn.get_global_rect().get_center())
	await physics_frames(2)
	await frames(2)
	check(not pc.is_first_person and hud._pov_btn.text == "POV: 3rd  Z", "Clicking HUD POV button exits First-Person POV")
	click_at(hud._pov_btn.get_global_rect().get_center())
	await physics_frames(2)
	await frames(2)
	check(pc.is_first_person and hud._pov_btn.text == "POV: 1st  Z", "Clicking HUD POV button re-enters First-Person POV")
	check(first_pivot == pc._fp_viewmodel._right_pivot, "POV toggles reuse the viewmodel for the same leader gear")

	var test_origin := camp_origin + Vector3(45.0, 0.0, 25.0)
	await _verify_steep_aim(pc, hud, fc0, fc5, test_origin)
	await _verify_idle_and_succession(pc, hud, fc0, test_origin)
	await _verify_mount_loads(pc, hud, test_origin)

	if _failed:
		quit(1)
		return
	print("FIRST PERSON POV VERIFICATION PASSED")
	quit(0)


func _body_hidden(leader: Node) -> bool:
	if leader._cached_fp_meshes.is_empty() or leader._cached_fp_small_meshes.is_empty():
		return false
	for mesh in leader._cached_fp_meshes:
		if not is_instance_valid(mesh) or not mesh.is_inside_tree():
			return false
		if mesh in leader._cached_fp_small_meshes:
			if mesh.layers != 0 or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				return false
		elif mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			return false
	return true


func _body_restored(leader: Node) -> bool:
	if leader.is_first_person_hidden() or leader._cached_fp_meshes.is_empty():
		return false
	for i in range(leader._cached_fp_meshes.size()):
		if leader._cached_fp_meshes[i].cast_shadow != leader._cached_fp_shadow_modes[i]:
			return false
	for i in range(leader._cached_fp_small_meshes.size()):
		if leader._cached_fp_small_meshes[i].layers != leader._cached_fp_small_layers[i]:
			return false
	return true


func _verify_hud_blocking(pc: Node, hud: Control) -> void:
	for binding: Array in [[KEY_B, "Build"], [KEY_C, "Colony"], [KEY_K, "Perks"], [KEY_R, "Faith"],
			[KEY_V, "Diplomacy"], [KEY_TAB, "Tribal Command"], [KEY_M, "World Map"], [KEY_P, "Pause"]]:
		key(binding[0])
		_check_blocked_actions(pc, hud, binding[1])
		if binding[0] == KEY_M:
			press(hud._world_map, "Close  [Esc]")
		else:
			key(KEY_ESCAPE)
		check(not hud.blocks_world_input() and hud._fp_reticle.visible and not hud._pov_btn.disabled,
			"Closing %s restores the reticle and POV button immediately" % binding[1])
		await frames(1)
	var center := root.get_visible_rect().size * 0.5
	for binding: Array in [[KEY_B, "Build"], [KEY_M, "World Map"], [KEY_P, "Pause"]]:
		pc._javelin_cd = 0.0
		move_pointer(center)
		mouse_button(center, MOUSE_BUTTON_RIGHT, true)
		var began_in_world: bool = pc._rmb_dragging
		key_event(binding[0], true)
		var cancelled: bool = hud.blocks_world_input() and not pc._rmb_dragging
		key_event(KEY_ESCAPE, true)
		move_pointer(center)
		mouse_button(center, MOUSE_BUTTON_RIGHT, false)
		check(began_in_world and cancelled and not hud.blocks_world_input() and pc._javelin_cd == 0.0,
			"%s cancels an in-progress RMB gesture before the next physics frame" % binding[1])
		key_event(KEY_ESCAPE, false)
		key_event(binding[0], false)


func _check_blocked_actions(pc: Node, hud: Control, panel: String) -> void:
	var point := Vector2(4.0, 285.0)
	var yaw: float = pc.cam_yaw
	var zoom: float = pc.target_cam_distance
	pc._attack_cd = 0.0
	pc._javelin_cd = 0.0
	check(hud.blocks_world_input() and not hud._fp_reticle.visible and hud._pov_btn.disabled,
		"%s hides the reticle and disables the POV button" % panel)
	key(KEY_Z)
	wheel(MOUSE_BUTTON_WHEEL_DOWN, point)
	click_at(point)
	click_at(point, MOUSE_BUTTON_RIGHT)
	drag_look(Vector2(45.0, 55.0), point)
	click_at(hud._pov_btn.get_global_rect().get_center())
	check(pc.is_first_person and pc.cam_yaw == yaw and pc.target_cam_distance == zoom and pc._attack_cd == 0.0 and pc._javelin_cd == 0.0,
		"%s blocks Z, the POV button, wheel zoom, cleave, RMB throw and look" % panel)


func _teleport_unit(unit: Node3D, point: Vector3) -> void:
	unit.global_position = point
	_game.spatial_index.update_unit(unit)


func _verify_steep_aim(pc: Node, hud: Control, fc0: Node, fc5: Node, origin: Vector3) -> void:
	var leader: CharacterBody3D = pc.leader_unit
	var center := root.get_visible_rect().size * 0.5
	_teleport_unit(leader, origin)
	pc.cam_yaw = 0.0
	await physics_frames(2)
	var foe: Node3D = fc5.spawn_colonist(origin + Vector3.FORWARD * 2.0, _data.Lineage.CAVEMAN,
		_data.Gender.MALE, _data.Role.WARRIOR, false, false, true)
	foe.set_physics_process(false)
	var friend: Node3D = fc0.spawn_colonist(origin + Vector3.BACK * 2.5, _data.Lineage.CRAG_BORN, _data.Gender.FEMALE, _data.Role.FORAGER)
	friend.set_physics_process(false)

	drag_look(Vector2(0.0, 400.0), center)
	check(pc.fp_pitch == -65.0 and is_equal_approx(-pc.camera.global_basis.z.y, sin(deg_to_rad(-65.0))), "RMB drag clamps the camera at -65 degrees")
	var hp: float = foe.hp
	pc._attack_cd = 0.0
	click_at(center)
	check(foe.hp < hp and not hud._inspector_panel.visible, "Steep downward cleave hits a foe ahead with a friendly behind")

	drag_look(Vector2(0.0, -800.0), center)
	check(pc.fp_pitch == 70.0 and is_equal_approx(-pc.camera.global_basis.z.y, sin(deg_to_rad(70.0))), "RMB drag clamps the camera at +70 degrees")
	_teleport_unit(friend, origin + Vector3.FORWARD * 4.5)
	hp = foe.hp
	pc._attack_cd = 0.0
	click_at(center)
	check(foe.hp == hp and not hud._inspector_panel.visible, "Aiming high misses the ground foe and the off-reticle villager")
	var look: Vector3 = -pc.camera.global_basis.z
	_teleport_unit(foe, pc.camera.global_position + look * 2.5 - Vector3.UP)
	pc._attack_cd = 0.0
	click_at(center)
	check(foe.hp < hp, "Cleave connects with an elevated target at +70 degrees")

	_teleport_unit(foe, pc.camera.global_position + look * 7.0 - Vector3.UP)
	foe.hp = foe.max_hp
	hp = foe.hp
	pc._javelin_cd = 0.0
	key(KEY_F)
	await physics_frames(12)
	check(foe.hp < hp, "F javelin hits an elevated target at +70 degrees")
	foe.queue_free()
	await frames(2)

	drag_look(Vector2(0.0, 800.0), center)
	var ground_aim: Vector3 = pc._get_first_person_aim_point()
	check(absf(ground_aim.y) < 0.01, "At -65 degrees the unaided aim ray reaches the ground plane")
	pc._javelin_cd = 0.0
	key(KEY_F)
	var projectile: Node3D = _game.projectiles_container.get_child(-1)
	var launch_velocity: Vector3 = projectile.velocity
	check(launch_velocity.normalized().dot(-pc.camera.global_basis.z) > 0.995, "The steep close-range javelin leaves along the ground aim ray")
	await physics_frames(8)

	var prey: Node3D = _game.world_node._spawn_animal("REEDJAW", ground_aim)
	prey.set_physics_process(false)
	hp = prey.hp
	pc._javelin_cd = 0.0
	click_at(center, MOUSE_BUTTON_RIGHT)
	await physics_frames(10)
	check(prey.hp < hp and not pc._fp_viewmodel._javelin_mount.visible, "Quick RMB at -65 degrees hits low wildlife and clears the thrown javelin from the hand")
	for _i in range(75):
		if pc._javelin_cd <= 0.26:
			break
		await physics_frame
	check(pc._fp_viewmodel._javelin_mount.visible and pc._fp_viewmodel._javelin_mount.position.y < pc._fp_viewmodel._jav_base_pos.y,
		"The replacement javelin glides up into the hand near cooldown completion")
	await physics_frames(20)
	check(pc._fp_viewmodel._javelin_mount.position.is_equal_approx(pc._fp_viewmodel._jav_base_pos), "The reload glide settles at the ready pose")

	pc.fp_pitch = -7.0
	_teleport_unit(friend, origin + Vector3.FORWARD * 3.0)
	prey.global_position = origin + Vector3(1.3, 0.0, -2.4)
	_game.spatial_index.update_wildlife(prey)
	await physics_frames(2)
	hp = prey.hp
	pc._attack_cd = 0.0
	click_at(center)
	check(prey.hp < hp and not hud._inspector_panel.visible, "Cleave takes priority over the aimed villager when hostile wildlife is in the swing")
	prey.queue_free()
	await physics_frames(2)
	click_at(center)
	check(hud._inspector_panel._inspected_unit == friend and not hud._fp_reticle.visible, "The reticle selects a friendly unit when the swing is clear")
	press(hud._inspector_panel, "Close")
	check(hud._fp_reticle.visible, "Inspector close restores the reticle immediately")
	friend.queue_free()


func _verify_idle_and_succession(pc: Node, hud: Control, fc0: Node, origin: Vector3) -> void:
	var leader: CharacterBody3D = pc.leader_unit
	var prefs := root.get_node("Preferences")
	var vm: Node3D = pc._fp_viewmodel
	await physics_frames(30)
	prefs.set_value("reduced_motion", true)
	await physics_frames(4)
	var idle_time: float = vm._idle_time
	await physics_frames(4)
	check(vm._idle_settled and vm._idle_time == idle_time, "Reduced Motion skips settled viewmodel pose updates")
	prefs.set_value("reduced_motion", false)
	await physics_frames(10)
	prefs.set_value("reduced_motion", true)
	await physics_frames(2)
	check(vm._right_pivot.position.is_equal_approx(vm._REST_RIGHT_POS), "Re-enabling Reduced Motion clears the previous idle sway")
	prefs.set_value("reduced_motion", false)

	var slope := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.25, 2.0)
	shape.shape = box
	slope.add_child(shape)
	_game.world_node.add_child(slope)
	slope.global_position = origin + Vector3.UP * 0.75
	slope.rotation_degrees.z = 17.0
	_teleport_unit(leader, origin + Vector3.UP * 1.2)
	await physics_frames(25)
	check(leader.is_on_floor() and leader.global_position.y > 0.5, "Idle leader settles on raised sloped ground")
	slope.queue_free()
	await physics_frames(30)
	check(leader.is_on_floor() and leader.global_position.y < 0.1, "Idle leader falls when the sloped support disappears")

	var foe: Node3D = _game.faction_controllers[5].spawn_colonist(origin + Vector3.RIGHT * 2.5, _data.Lineage.CAVEMAN,
		_data.Gender.MALE, _data.Role.WARRIOR, false, false, true)
	foe.set_physics_process(false)
	await physics_frames(20)
	var chest: Node3D = leader._visual_root.find_child("ChestPivot", true, false)
	var idle_chest := chest.rotation
	var before_hit := leader.global_position
	leader.take_damage(2.0, foe, 5)
	await physics_frames(4)
	var hit_pose: bool = leader._skinned_trial._current_clip == &"Hit" if leader._skinned_trial != null else not chest.rotation.is_equal_approx(idle_chest)
	check(hit_pose and leader.global_position.x < before_hit.x - 0.05, "A stationary first-person leader plays the hit pose and takes knockback")
	foe.queue_free()
	await physics_frames(45)
	check(leader._fp_anim_idle_time >= 0.24 and (leader._skinned_trial == null or leader._skinned_trial._current_clip == leader._skinned_trial._idle_clip),
		"The standing shadow settles after the hit and knockback")

	var initial_mesh: int = leader._cached_fp_meshes[0].get_instance_id()
	leader.lineage = _data.Lineage.SWIFT_KIN
	leader._rebuild_visual()
	await physics_frames(2)
	check(initial_mesh != leader._cached_fp_meshes[0].get_instance_id() and _body_hidden(leader) and vm._built_lineage == _data.Lineage.SWIFT_KIN,
		"A live lineage rebuild refreshes the cast-only body and first-person arms")
	key(KEY_H)
	check(_game.warhorn_active and _body_hidden(leader), "Warhorn gear refresh keeps the leader out of the camera")
	key(KEY_H)
	fc0.spawn_building("CRAFTING_PIT", origin + Vector3.BACK * 20.0, 0.0, true)
	for resource in _data.TIER_UPGRADE_COSTS[2]:
		_game.factions[0]["resources"][resource] = 100.0
	check(fc0.upgrade_stone_age_tier(), "Faction upgrades to Tier II")
	await physics_frames(2)
	check(vm.get_built_tier() == 2 and _body_hidden(leader), "Tech tier change refreshes first-person weapons and preserves body occlusion")

	vm.trigger_action("WORK", 0.30)
	leader.take_damage(1000.0, null, 5)
	var successor: CharacterBody3D = pc.leader_unit
	check(is_instance_valid(successor) and successor != leader and successor.is_leader and _body_restored(leader),
		"Tribal Succession releases the fallen leader's original mesh state")
	check(pc.is_first_person and hud._fp_reticle.visible and _body_hidden(successor) and vm._built_lineage == successor.lineage
		and vm.get_built_tier() == successor.weapon_tier and vm._action_timer == 0.0,
		"Successor inherits POV with fresh arms, the right gear tier and no stale action")

	_game.get_faction_leader(1).take_damage(1000.0, successor, 0)
	check(hud._overlays._conquest_panel.visible and _game.is_paused, "Victory over a rival opens the conquest modal in first person")
	_check_blocked_actions(pc, hud, "Conquest")
	press(hud._overlays._conquest_panel, "Make a Tributary")
	check(not _game.is_paused and hud._fp_reticle.visible, "Resolving conquest resumes first-person input and reticle")


func _verify_mount_loads(pc: Node, hud: Control, origin: Vector3) -> void:
	var leader: CharacterBody3D = pc.leader_unit
	var eye_on_foot: float = leader.get_eye_height()
	var species_list := ["DEER", "BOAR", "MAMMOTH"]
	for i in range(species_list.size()):
		var species: String = species_list[i]
		var site := origin + Vector3.RIGHT * (16.0 * float(i))
		var animal: Node3D = _game.world_node._spawn_animal(species, site)
		animal.owner_faction = 0
		animal.training_feeds = Farming.MOUNT_TRAINING
		animal.maturity_remaining = 0.0
		_teleport_unit(leader, site + Vector3.BACK * 1.4)
		pc.cam_yaw = 14.0
		pc.fp_pitch = -12.0
		key(KEY_E)
		var mount_hint := "%s  ·  [E] Dismount" % animal.animal_name
		check(hud._blessing_label.text == mount_hint, "E immediately shows the first-person %s dismount prompt" % species)
		await physics_frames(3)
		check(pc._mounted_animal == animal and leader.get_eye_height() > eye_on_foot + 0.10
			and is_equal_approx(pc.camera.global_position.y, leader.global_position.y + leader.get_eye_height()),
			"E mounts the %s and moves the first-person camera to the rider's eyes" % species)
		var before := leader.global_position
		var forward := Vector3(-sin(deg_to_rad(14.0)), 0.0, -cos(deg_to_rad(14.0)))
		var walk := InputEventKey.new()
		walk.keycode = KEY_W
		walk.pressed = true
		Input.parse_input_event(walk)
		await physics_frames(7)
		walk = InputEventKey.new()
		walk.keycode = KEY_W
		Input.parse_input_event(walk)
		await physics_frames(2)
		check((leader.global_position - before).dot(forward) > 0.30 and animal.global_position.distance_to(leader.global_position) < 0.05,
			"Mounted first-person W movement follows camera yaw on the %s" % species)
		await screenshot("fp_mounted_%s" % species.to_lower())
		animal.take_damage(animal.hp * 0.15, null, 5)
		check(not animal._hp_bg.visible and not animal._hp_fill.visible, "The mounted %s health bar stays out of the first-person camera after damage" % species)
		key(KEY_Z)
		check(not pc.is_first_person and animal._hp_bg.visible and animal._hp_fill.visible, "Third-person POV restores the mounted %s health bar" % species)
		key(KEY_Z)

		var saved_id: int = leader.unit_id
		var old_leader_instance := leader.get_instance_id()
		key(KEY_F9)
		if species == "BOAR":
			key(KEY_P)
			press(hud._overlays._pause_screen, "Load Campaign")
			press(hud._overlays._confirmation, "Load Campaign")
		else:
			key(KEY_F10)
		check(hud._blessing_label.text == mount_hint, "Loading the mounted %s restores its HUD prompt" % species)
		await physics_frames(3)
		leader = pc.leader_unit
		var loaded_animal: Node3D = pc._mounted_animal
		check(leader.get_instance_id() != old_leader_instance and leader.unit_id == saved_id and pc.is_first_person
			and _body_hidden(leader) and hud._fp_reticle.visible and pc.is_mounted() and loaded_animal.animal_type == species
			and loaded_animal.rider_unit_id == saved_id and leader.get_eye_height() > eye_on_foot + 0.10 and not loaded_animal._hp_bg.visible,
			"%s restores the mounted %s and keeps the active POV" % ["Pause Load Campaign" if species == "BOAR" else "F10", species])
		key(KEY_E)
		check(hud._blessing_label.text.begins_with("[Q] Blessing"), "E dismount on the %s immediately restores the blessing hint" % species)
		await physics_frames(3)
		check(not pc.is_mounted() and is_equal_approx(leader.get_eye_height(), eye_on_foot) and pc.is_first_person
			and is_equal_approx(pc.camera.global_position.y, leader.global_position.y + eye_on_foot) and loaded_animal._hp_bg.visible,
			"E dismounts the %s and restores the standing first-person camera" % species)

	var retired_camera: Camera3D = pc.camera
	var retired_viewmodel: Node3D = pc._fp_viewmodel
	await _return_to_title(hud)
	check(not _game.game_active and not is_instance_valid(pc) and not is_instance_valid(retired_camera) and not is_instance_valid(retired_viewmodel),
		"Return to Title frees the first-person controller, camera and viewmodel")
	press(_shell._title, "Continue")
	await frames(12)
	pc = _game.player_controller
	hud = _game.hud_controller
	check(pc.is_mounted() and pc._mounted_animal.animal_type == "MAMMOTH" and not pc.is_first_person
		and not pc.leader_unit.is_first_person_hidden() and not hud._fp_reticle.visible,
		"Continue restores the saved mammoth and starts a fresh third-person camera session")
	key(KEY_Z)
	check(pc.is_first_person and pc._fp_viewmodel._last_pose_mounted and _body_hidden(pc.leader_unit), "Z enters first person on the mount restored by Continue")
	await _return_to_title(hud)
	press(_shell._title, "New Game")
	await frames(3)
	press(_shell._page, "Awaken in the Valley")
	await frames(12)
	pc = _game.player_controller
	check(_game.game_active and not pc.is_first_person and not pc.is_mounted() and not _game.hud_controller._fp_reticle.visible,
		"New Game starts cleanly in third person after leaving a mounted first-person campaign")
	leader = pc.leader_unit
	key(KEY_Z)
	leader.take_damage(1000.0, null, 5)
	check(pc.leader_unit == null and not pc._fp_viewmodel.visible and not _game.hud_controller._fp_reticle.visible and _body_restored(leader),
		"Losing the leader without a successor clears the viewmodel and reticle and restores the corpse meshes")


func _return_to_title(hud: Control) -> void:
	key(KEY_P)
	press(hud._overlays._pause_screen, "Return to Title")
	press(hud._overlays._confirmation, "Return to Title")
	await frames(12)

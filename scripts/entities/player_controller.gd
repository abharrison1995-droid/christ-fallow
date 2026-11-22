extends Node

signal mount_changed

const Layout = preload("res://scripts/core/world_layout.gd")

var _mounted_animal: Node3D

const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const BlessingEffects = preload("res://scripts/systems/blessing_effects.gd")
const Projectile3D = preload("res://scripts/entities/projectile_3d.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const TutorialBeacon = preload("res://scripts/core/tutorial_beacon.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const FirstPersonViewmodel = preload("res://scripts/entities/first_person_viewmodel.gd")
const FIRST_PERSON_JAVELIN_RELEASE := 0.22

var leader_unit: CharacterBody3D = null
var camera_pivot: Node3D = null
var camera: Camera3D = null
var _leader_light: OmniLight3D = null
var _tutorial_beacon: Node3D = null
var _fp_viewmodel: FirstPersonViewmodel = null

var cam_yaw: float = 0.0
var cam_pitch: float = 28.0
var cam_distance: float = 12.0
var target_cam_distance: float = 12.0
var is_first_person: bool = false
var fp_pitch: float = -6.0
var _saved_third_person_dist: float = 12.0
var _fp_bob_time: float = 0.0
var is_spectating_arena: bool = false:
	set(value):
		if is_spectating_arena == value:
			return
		is_spectating_arena = value
		if is_spectating_arena:
			if is_first_person:
				set_first_person(false, false)
			if arena_spectate_center == Vector3.ZERO and GameState.arena_bout.has("arena_pos"):
				arena_spectate_center = GameState.arena_bout["arena_pos"]
			target_cam_distance = maxf(target_cam_distance, 13.5)
		else:
			arena_spectate_center = Vector3.ZERO
var arena_spectate_center: Vector3 = Vector3.ZERO

var is_build_mode: bool = false
var blueprint_type: String = "CAMPFIRE"
var blueprint_rot_y: float = 0.0
var _blueprint_ghost: Node3D = null

var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _attack_cd: float = 0.0
var _javelin_cd: float = 0.0
var _blessing_cd: float = 0.0
var _footstep_sfx_timer: float = 0.0

const HARVEST_YIELD_TABLE := {
	"BERRY_BUSH": {"res": "food", "amount": 5.0, "label": "+5 Food", "verb": "Foraged", "col": Color(0.95, 0.55, 0.65)},
	"TREE": {"res": "wood", "amount": 5.0, "label": "+5 Wood", "verb": "Chopped", "col": Color(0.82, 0.62, 0.36)},
	"STONE": {"res": "stone", "amount": 5.0, "label": "+5 Stone", "verb": "Mined", "col": Color(0.78, 0.78, 0.82)},
	"FLINT": {"res": "flint", "amount": 4.0, "label": "+4 Flint", "verb": "Knapped", "col": Color(0.65, 0.85, 1.0)},
}
var _harvest_cd: float = 0.0

var _rmb_dragging: bool = false
var _rmb_drag_dist: float = 0.0


func _ready() -> void:
	GameState.player_controller = self


func setup(p_leader: CharacterBody3D) -> void:
	if camera_pivot == null:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		get_parent().add_child(camera_pivot)

		camera = Camera3D.new()
		camera.name = "MainCamera"
		camera.fov = 58.0
		camera_pivot.add_child(camera)
		camera.current = true

		# Diablo-style warm Player Light Radius
		_leader_light = OmniLight3D.new()
		_leader_light.name = "PlayerLightRadius"
		_leader_light.light_color = Color(1.0, 0.72, 0.40)
		_leader_light.omni_range = 24.0
		_leader_light.light_energy = 2.20
		_leader_light.position = Vector3(0.0, 1.4, 0.0)
		camera_pivot.add_child(_leader_light)

		_fp_viewmodel = FirstPersonViewmodel.new()
		_fp_viewmodel.name = "FirstPersonViewmodel"
		_fp_viewmodel.visible = false
		camera.add_child(_fp_viewmodel)
	camera.far = GameState.valley_layout.camera_far
	_ensure_tutorial_beacon()
	attach_leader(p_leader)


func attach_leader(p_leader: CharacterBody3D) -> void:
	if is_instance_valid(_mounted_animal):
		dismount_from(_mounted_animal)
	if is_instance_valid(leader_unit) and leader_unit != p_leader:
		leader_unit.is_player_controlled = false
		leader_unit.set_first_person_view(false)
	reset_cooldowns()
	_fp_bob_time = 0.0
	if _fp_viewmodel != null:
		_fp_viewmodel.reset_pose()
		_fp_viewmodel.hide()
	_ensure_tutorial_beacon()
	if not GameState.is_arena_bout_active():
		set_arena_spectate(false)
	leader_unit = p_leader
	if _has_live_leader():
		leader_unit.is_player_controlled = true
		if camera_pivot != null:
			camera_pivot.global_position = leader_unit.global_position + Vector3(0.0, 1.4, 0.0)
			_update_camera(0.0)
		leader_unit.set_first_person_view(is_first_person)
	_sync_tutorial_beacon(0.0)
	if is_instance_valid(GameState.hud_controller):
		GameState.hud_controller.sync_pov_state()


func set_arena_spectate(enabled: bool, center: Vector3 = Vector3.ZERO) -> void:
	if enabled:
		var target_center := center
		if target_center == Vector3.ZERO and GameState.arena_bout.has("arena_pos"):
			target_center = GameState.arena_bout["arena_pos"]
		arena_spectate_center = target_center
		if is_first_person:
			set_first_person(false, false)
		is_spectating_arena = true
		target_cam_distance = maxf(target_cam_distance, 13.5)
	else:
		is_spectating_arena = false
		arena_spectate_center = Vector3.ZERO


func _has_live_leader() -> bool:
	return is_instance_valid(leader_unit) and leader_unit.is_inside_tree() and not leader_unit.is_dead


func can_toggle_first_person() -> bool:
	return (camera != null and _has_live_leader() and GameState.game_active
		and not GameState.campaign_finished and not GameState.is_paused and not _world_input_blocked())


func toggle_first_person() -> void:
	set_first_person(not is_first_person)


func set_first_person(enabled: bool, from_scroll: bool = false) -> void:
	if is_first_person == enabled or not can_toggle_first_person():
		return
	is_first_person = enabled
	_fp_bob_time = 0.0
	cancel_camera_drag()
	_fp_viewmodel.reset_pose()
	leader_unit.set_first_person_view(enabled)
	if is_mounted():
		_mounted_animal.refresh_health_bar()
	if is_first_person:
		_saved_third_person_dist = clampf(target_cam_distance, 5.5, 42.0)
		fp_pitch = -6.0
		camera.fov = 72.0
		camera.near = 0.08
		GameState.push_log("First-Person POV active ([Z] or Scroll Down for 3rd-Person).", "info")
	else:
		_fp_viewmodel.hide()
		camera.fov = 58.0
		camera.near = 0.05
		target_cam_distance = 5.5 if from_scroll else maxf(5.5, _saved_third_person_dist)
		cam_distance = target_cam_distance
		if is_mounted():
			var seat: Vector3 = _mounted_animal.mount_profile["seat"]
			cam_distance = maxf(cam_distance, seat.y * 3.7)
		camera_pivot.global_position = _get_third_person_pivot()
		GameState.push_log("Third-Person POV restored.", "info")
	_update_camera(0.0)
	if is_instance_valid(GameState.hud_controller):
		GameState.hud_controller.sync_pov_state()


func rotate_first_person_view(yaw_delta_deg: float, pitch_delta_deg: float) -> void:
	if not is_first_person or not _has_live_leader():
		return
	var old_pitch := fp_pitch
	cam_yaw += yaw_delta_deg
	fp_pitch = clampf(fp_pitch + pitch_delta_deg, -65.0, 70.0)
	if yaw_delta_deg == 0.0 and fp_pitch == old_pitch:
		return
	var reduced_motion: bool = Preferences.get_value("reduced_motion") == true
	_fp_viewmodel.notify_look_delta(yaw_delta_deg, fp_pitch - old_pitch, reduced_motion)
	_update_camera(0.0)


func get_tutorial_beacon() -> Node3D:
	return _tutorial_beacon


func _ensure_tutorial_beacon() -> void:
	if is_instance_valid(_tutorial_beacon):
		return
	var host: Node = GameState.world_node if is_instance_valid(GameState.world_node) else get_parent()
	if host == null:
		return
	_tutorial_beacon = TutorialBeacon.new()
	host.add_child(_tutorial_beacon)


func _sync_tutorial_beacon(delta: float) -> void:
	if is_instance_valid(_tutorial_beacon) and _tutorial_beacon.has_method("sync_with_state"):
		_tutorial_beacon.sync_with_state(leader_unit, delta)


func _notify_tutorial_progress() -> void:
	AwakeningGuide.advance(GameState)
	_sync_tutorial_beacon(0.0)
	if is_instance_valid(GameState.hud_controller) and GameState.hud_controller.has_method("refresh_awakening_guide"):
		GameState.hud_controller.refresh_awakening_guide()


func _exit_tree() -> void:
	if is_instance_valid(_tutorial_beacon):
		if _tutorial_beacon.get_parent() != null:
			_tutorial_beacon.get_parent().remove_child(_tutorial_beacon)
		_tutorial_beacon.queue_free()
	_tutorial_beacon = null


func _play_sfx_3d(cue: String, pos: Vector3, pitch_jitter: float = 0.08, volume_db: float = 0.0) -> void:
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_sfx_3d(cue, pos, pitch_jitter, volume_db)


func _play_ui_sfx(cue: String, pitch_jitter: float = 0.05) -> void:
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_ui_sfx(cue, pitch_jitter)


func reset_cooldowns() -> void:
	_dash_timer = 0.0
	_dash_cd = 0.0
	_dash_dir = Vector3.ZERO
	_attack_cd = 0.0
	_javelin_cd = 0.0
	_blessing_cd = 0.0
	_harvest_cd = 0.0
	_footstep_sfx_timer = 0.0
	cancel_camera_drag()


func cancel_camera_drag() -> void:
	_rmb_dragging = false
	_rmb_drag_dist = 0.0


func serialize() -> Dictionary:
	return {
		"blessing_cooldown": maxf(0.0, _blessing_cd),
	}


func restore_from_save(snapshot: Dictionary) -> void:
	_blessing_cd = maxf(0.0, float(snapshot.get("blessing_cooldown", 0.0)))
	_sync_tutorial_beacon(0.0)


func enter_build_mode(b_type: String) -> void:
	blueprint_type = b_type
	is_build_mode = true
	blueprint_rot_y = 0.0
	_rebuild_blueprint_ghost()
	GameState.push_log("Blueprint ready: %s. Left-Click ground to place, [T] rotate, Right-Click/Esc cancel." % GameData.BUILDINGS[b_type]["name"], "info")
	if GameState.game_active:
		_notify_tutorial_progress()


func exit_build_mode() -> void:
	var was_build_mode := is_build_mode
	is_build_mode = false
	if _blueprint_ghost != null:
		_blueprint_ghost.queue_free()
		_blueprint_ghost = null
	if was_build_mode and GameState.game_active:
		_notify_tutorial_progress()


func _rebuild_blueprint_ghost() -> void:
	if _blueprint_ghost != null:
		_blueprint_ghost.queue_free()
		_blueprint_ghost = null
	if not is_build_mode:
		return
	var col: Color = GameData.FACTION_COLORS[0]
	_blueprint_ghost = MeshFactory.build_building_mesh(blueprint_type, col, true)
	if GameState.world_node != null:
		GameState.world_node.add_child(_blueprint_ghost)


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.game_active or GameState.campaign_finished or GameState.is_paused or _world_input_blocked():
		cancel_camera_drag()
		return
	if not _has_live_leader():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if not _is_pointer_over_ui():
				if not is_first_person and target_cam_distance <= 5.55:
					set_first_person(true, true)
				elif not is_first_person:
					target_cam_distance = clampf(target_cam_distance - 2.2, 5.5, 42.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if not _is_pointer_over_ui():
				if is_first_person:
					set_first_person(false, true)
				else:
					target_cam_distance = clampf(target_cam_distance + 2.2, 5.5, 42.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if _is_pointer_over_ui():
					return
				_rmb_dragging = true
				_rmb_drag_dist = 0.0
			else:
				var started_in_world := _rmb_dragging
				_rmb_dragging = false
				if started_in_world and _rmb_drag_dist < 6.0 and not _is_pointer_over_ui():
					if is_build_mode:
						exit_build_mode()
					elif not GameState.is_paused:
						_try_throw_javelin()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _is_pointer_over_ui():
				return
			if is_build_mode:
				_try_place_blueprint()
			elif is_first_person or not _try_inspect_clicked_unit():
				_try_melee_cleave(is_first_person)

	elif event is InputEventMouseMotion and _rmb_dragging:
		var mm := event as InputEventMouseMotion
		_rmb_drag_dist += mm.relative.length()
		if is_first_person:
			rotate_first_person_view(-mm.relative.x * 0.24, -mm.relative.y * 0.20)
		else:
			cam_yaw -= mm.relative.x * 0.28
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.22, 12.0, 68.0)

	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_ESCAPE and is_build_mode:
			exit_build_mode()
		elif kc == KEY_ESCAPE and is_spectating_arena:
			set_arena_spectate(false)
		elif kc == KEY_T and is_build_mode:
			blueprint_rot_y += deg_to_rad(45.0)
		elif kc == KEY_Z and not GameState.is_paused:
			if is_spectating_arena:
				set_arena_spectate(false)
			toggle_first_person()
		elif kc == KEY_SPACE and not GameState.is_paused:
			_try_dash()
		elif kc == KEY_E and not GameState.is_paused:
			_try_interact_or_harvest()
		elif kc == KEY_Q and not GameState.is_paused:
			_try_god_blessing()
		elif kc == KEY_F and not GameState.is_paused:
			_try_throw_javelin()
		elif kc == KEY_H and not GameState.is_paused:
			if GameState.combat_command_system != null:
				GameState.combat_command_system.toggle_warhorn()
		elif kc == KEY_1:
			_select_squad(-1)
		elif kc == KEY_2:
			_select_squad(GameData.WarriorClass.SPEARMAN)
		elif kc == KEY_3:
			_select_squad(GameData.WarriorClass.KNIFE_RAIDER)
		elif kc == KEY_4:
			_select_squad(GameData.WarriorClass.ARCHER)
		elif kc == KEY_5:
			_select_squad(GameData.WarriorClass.BRUTE)
		elif kc == KEY_6:
			_select_squad(GameData.WarriorClass.JAVELINEER)
		elif kc == KEY_F1:
			_issue_order(GameData.SquadOrder.FOLLOW)
		elif kc == KEY_F2:
			_issue_order(GameData.SquadOrder.HOLD)
		elif kc == KEY_F3:
			_issue_order(GameData.SquadOrder.CHARGE)
		elif kc == KEY_F4:
			_issue_order(GameData.SquadOrder.RETREAT)
		elif kc == KEY_F5:
			if GameState.combat_command_system != null:
				GameState.combat_command_system.toggle_fire_at_will()
		elif kc == KEY_F6:
			_issue_order(GameData.SquadOrder.GUARD_BASE)


func _select_squad(w_class: int) -> void:
	if GameState.combat_command_system != null:
		GameState.combat_command_system.select_squad(w_class)


func _issue_order(order: int) -> void:
	if GameState.combat_command_system != null and leader_unit != null:
		GameState.combat_command_system.issue_player_order(order)


func _is_pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _world_input_blocked() -> bool:
	var hud := GameState.hud_controller
	return is_instance_valid(hud) and hud.blocks_world_input()


func _physics_process(delta: float) -> void:
	if not GameState.game_active or camera_pivot == null or camera == null:
		return

	_sync_tutorial_beacon(delta)
	var sim_running := not GameState.is_paused and not GameState.campaign_finished
	if sim_running:
		_dash_cd = maxf(0.0, _dash_cd - delta)
		_attack_cd = maxf(0.0, _attack_cd - delta)
		_javelin_cd = maxf(0.0, _javelin_cd - delta)
		_blessing_cd = maxf(0.0, _blessing_cd - delta)
		_harvest_cd = maxf(0.0, _harvest_cd - delta)

	if is_spectating_arena and not GameState.is_arena_bout_active():
		set_arena_spectate(false)

	var has_world_input := sim_running and not _world_input_blocked()
	if _rmb_dragging and (not has_world_input or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		cancel_camera_drag()
	if _has_live_leader():
		if has_world_input:
			_move_leader(delta)
		if sim_running and is_mounted():
			var gait := leader_unit.get_real_velocity() if has_world_input else Vector3.ZERO
			_mounted_animal.sync_ridden_transform(leader_unit, gait, delta)
		_update_camera(delta if sim_running else 0.0)
		if _leader_light != null:
			var t_sec := float(Time.get_ticks_msec()) * 0.001
			_leader_light.light_energy = 2.20 + sin(t_sec * 11.0) * 0.14 + cos(t_sec * 17.3) * 0.08
		if has_world_input and is_build_mode and _blueprint_ghost != null:
			_update_blueprint_ghost()


func _move_leader(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	var move_dir := Vector3.ZERO
	if input_vec.length() > 0.01:
		if is_spectating_arena:
			set_arena_spectate(false)
		var yaw_rad := deg_to_rad(cam_yaw)
		var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
		var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
		move_dir = (forward * -input_vec.y + right * input_vec.x).normalized()

	var spd: float = leader_unit.move_speed
	if is_mounted():
		spd *= float(_mounted_animal.mount_profile["speed_mult"])
	elif Input.is_key_pressed(KEY_SHIFT):
		spd *= 1.38

	if _dash_timer > 0.0:
		_dash_timer -= delta
		leader_unit.velocity.x = _dash_dir.x * spd * 2.6
		leader_unit.velocity.z = _dash_dir.z * spd * 2.6
	elif move_dir.length() > 0.05:
		leader_unit.velocity.x = move_dir.x * spd
		leader_unit.velocity.z = move_dir.z * spd
		if not is_first_person:
			var look_target := leader_unit.global_position + move_dir
			leader_unit.look_at(look_target, Vector3.UP)
	else:
		leader_unit.velocity.x = lerpf(leader_unit.velocity.x, 0.0, 14.0 * delta)
		leader_unit.velocity.z = lerpf(leader_unit.velocity.z, 0.0, 14.0 * delta)

	if is_first_person:
		leader_unit.rotation.y = deg_to_rad(cam_yaw)

	if not leader_unit.is_on_floor():
		leader_unit.velocity.y -= 24.0 * delta
	else:
		leader_unit.velocity.y = 0.0

	if leader_unit.is_on_floor() and _dash_timer <= 0.0 and Vector2(leader_unit.velocity.x, leader_unit.velocity.z).length_squared() < 0.0004:
		leader_unit.velocity = Vector3.ZERO

	leader_unit.move_and_slide()
	leader_unit.global_position.x = clampf(leader_unit.global_position.x, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)
	leader_unit.global_position.z = clampf(leader_unit.global_position.z, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)

	var horiz_spd := Vector2(leader_unit.velocity.x, leader_unit.velocity.z).length()
	if not is_mounted() and leader_unit.is_on_floor() and (horiz_spd > 0.8 or _dash_timer > 0.0):
		_footstep_sfx_timer -= delta
		if _footstep_sfx_timer <= 0.0:
			var step_interval := 0.16 if _dash_timer > 0.0 else (0.26 if Input.is_key_pressed(KEY_SHIFT) else 0.38)
			_footstep_sfx_timer = step_interval
			_play_sfx_3d("footstep_grass", leader_unit.global_position, 0.10, -10.0)
	else:
		_footstep_sfx_timer = minf(_footstep_sfx_timer, 0.05)


func _update_camera(delta: float) -> void:
	if is_first_person:
		var yaw_r := deg_to_rad(cam_yaw)
		var horiz_fwd := Vector3(-sin(yaw_r), 0.0, -cos(yaw_r))
		leader_unit.rotation.y = yaw_r
		var reduced_motion: bool = (Preferences.get_value("reduced_motion") == true)
		var horiz_speed := Vector2(leader_unit.velocity.x, leader_unit.velocity.z).length()
		var speed_ratio := horiz_speed / maxf(leader_unit.move_speed, 1.0)
		var mounted := is_mounted()
		var bob_y := 0.0
		if not reduced_motion and not mounted and speed_ratio > 0.05:
			_fp_bob_time += delta * lerpf(6.5, 11.0, clampf(speed_ratio, 0.0, 1.5))
			bob_y = sin(_fp_bob_time) * 0.045 * minf(speed_ratio, 1.3)
		var eye_h: float = leader_unit.get_eye_height()
		var fwd_offset := -0.24 if mounted else 0.14
		var eye_pos := leader_unit.global_position + Vector3(0.0, eye_h + bob_y, 0.0) + horiz_fwd * fwd_offset
		camera_pivot.global_position = eye_pos
		camera.position = Vector3.ZERO
		var pitch_r := deg_to_rad(clampf(fp_pitch, -65.0, 70.0))
		var cp := cos(pitch_r)
		var look_dir := Vector3(-sin(yaw_r) * cp, sin(pitch_r), -cos(yaw_r) * cp).normalized()
		camera.look_at(eye_pos + look_dir, Vector3.UP)
		if _fp_viewmodel.has_stale_gear(leader_unit):
			_fp_viewmodel.setup_for_leader(leader_unit)
		_fp_viewmodel.show()
		_fp_viewmodel.update_viewmodel(delta, speed_ratio, mounted, _javelin_cd, reduced_motion)
		return

	var distance := target_cam_distance
	if is_spectating_arena:
		distance = maxf(distance, 13.5)
	elif is_mounted():
		var seat: Vector3 = _mounted_animal.mount_profile["seat"]
		# Keep the taller mount and its rider in frame at close zoom.
		distance = maxf(distance, seat.y * 3.7)
	cam_distance = lerpf(cam_distance, distance, 10.0 * delta)
	camera_pivot.global_position = camera_pivot.global_position.lerp(_get_third_person_pivot(), 14.0 * delta)

	var zoom_t := clampf((cam_distance - 5.5) / (42.0 - 5.5), 0.0, 1.0)
	var eff_pitch := lerpf(cam_pitch, 64.0, zoom_t * 0.72)
	var yaw_r := deg_to_rad(cam_yaw)
	var pitch_r := deg_to_rad(eff_pitch)
	var offset := Vector3(
		sin(yaw_r) * cos(pitch_r) * cam_distance,
		sin(pitch_r) * cam_distance,
		cos(yaw_r) * cos(pitch_r) * cam_distance
	)
	camera.position = offset
	camera.look_at(camera_pivot.global_position, Vector3.UP)


func _get_third_person_pivot() -> Vector3:
	if is_spectating_arena:
		var center := arena_spectate_center
		if center == Vector3.ZERO and GameState.arena_bout.has("arena_pos"):
			center = GameState.arena_bout["arena_pos"]
		return center + Vector3.UP * 1.4
	var pivot := leader_unit.global_position + Vector3.UP * 1.4
	if is_mounted():
		var seat: Vector3 = _mounted_animal.mount_profile["seat"]
		pivot.y += seat.y * 0.55
	return pivot


func _get_ground_mouse_pos() -> Vector3:
	if camera == null or leader_unit == null:
		return Vector3.ZERO
	if is_first_person:
		var center := get_viewport().get_visible_rect().size * 0.5
		var c_orig := camera.project_ray_origin(center)
		var c_dir := camera.project_ray_normal(center)
		var yaw_r := deg_to_rad(cam_yaw)
		var horiz_fwd := Vector3(-sin(yaw_r), 0.0, -cos(yaw_r))
		var raw := leader_unit.global_position + horiz_fwd * 4.5
		if c_dir.y < -0.02:
			var tc := -c_orig.y / c_dir.y
			if tc > 0.0 and tc < GameState.valley_layout.camera_ray_length:
				raw = c_orig + c_dir * tc
		raw.y = 0.0
		var offset_xz := Vector3(raw.x - leader_unit.global_position.x, 0.0, raw.z - leader_unit.global_position.z)
		var d_xz := offset_xz.length()
		if d_xz < 2.4:
			raw = leader_unit.global_position + horiz_fwd * 2.4
			raw.y = 0.0
		elif d_xz > 14.0:
			raw = leader_unit.global_position + offset_xz.normalized() * 14.0
			raw.y = 0.0
		return raw
	var m_pos := get_viewport().get_mouse_position()
	var ray_orig := camera.project_ray_origin(m_pos)
	var ray_dir := camera.project_ray_normal(m_pos)
	if absf(ray_dir.y) > 0.001:
		var t := -ray_orig.y / ray_dir.y
		if t > 0.0 and t < GameState.valley_layout.camera_ray_length:
			var hit := ray_orig + ray_dir * t
			hit.y = 0.0
			return hit
	return leader_unit.global_position + (-leader_unit.global_transform.basis.z * 4.0)


func _update_blueprint_ghost() -> void:
	var pos := _get_ground_mouse_pos()
	pos.x = clampf(pos.x, -GameState.valley_layout.blueprint_half_extent, GameState.valley_layout.blueprint_half_extent)
	pos.z = clampf(pos.z, -GameState.valley_layout.blueprint_half_extent, GameState.valley_layout.blueprint_half_extent)
	_blueprint_ghost.global_position = pos
	_blueprint_ghost.rotation.y = blueprint_rot_y


func _try_place_blueprint() -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished or _blueprint_ghost == null:
		return
	var b_info: Dictionary = GameData.BUILDINGS.get(blueprint_type, {})
	if b_info.is_empty():
		return
	var warning := blueprint_placement_message()
	if not warning.is_empty():
		GameState.push_log(warning, "warning")
		return
	var pos := _blueprint_ghost.global_position
	GameState.spend_resources(0, b_info["costs"], true)

	var b_script := load("res://scripts/entities/building_entity.gd")
	var b := StaticBody3D.new()
	b.set_script(b_script)
	GameState.buildings_container.add_child(b)
	# Campfire finishes quickly if player is founding their tribe
	var instant: bool = (blueprint_type == "CAMPFIRE" and not bool(GameState.factions[0]["is_founded"]))
	b.setup(blueprint_type, 0, pos, blueprint_rot_y, instant)
	if instant:
		GameState.factions[0]["is_founded"] = true
		GameState.factions[0]["camp_position"] = pos
		GameState.push_log("Campfire lit! Your colony is founded. Assign jobs in [C] Colony!", "success")
		_play_sfx_3d("building_complete", pos, 0.04, 0.0)
	else:
		_play_ui_sfx("ui_click", 0.04)
		if blueprint_type == "CAMPFIRE" and not GameState.has_building(0, "CAMPFIRE", true):
			GameState.factions[0]["camp_position"] = pos
		GameState.push_log("Placed %s blueprint. Builders will construct it." % b_info["name"], "info")
		if not GameState.builder_tip_shown:
			var has_builder := false
			for u in GameState.get_faction_units(0, true):
				if int(u.get("role")) == GameData.Role.BUILDER_CRAFTER:
					has_builder = true
					break
			if not has_builder:
				GameState.builder_tip_shown = true
				GameState.push_log("Tip: Assign a Builder/Crafter in [C] Colony, or press [E] near the blueprint to help build it!", "info")

	if not Input.is_key_pressed(KEY_SHIFT):
		exit_build_mode()
	_notify_tutorial_progress()


func blueprint_placement_message() -> String:
	if not is_instance_valid(_blueprint_ghost) or not GameData.BUILDINGS.has(blueprint_type):
		return ""
	var info: Dictionary = GameData.BUILDINGS[blueprint_type]
	if not GameState.can_afford(0, info["costs"], true):
		return "Not enough resources for %s." % info["name"]
	for building in GameState.get_faction_buildings(0):
		if _blueprint_ghost.global_position.distance_to(building.global_position) < 2.6:
			return "Too close to an existing building. Move to open ground."
	return ""

func _try_dash() -> void:
	if _dash_cd > 0.0 or leader_unit == null or is_mounted():
		return
	_dash_cd = 2.0 * PerkSystem.get_leader_dash_cd_mult(GameState.factions.get(0, {}))
	_dash_timer = 0.20
	var fwd := -leader_unit.global_transform.basis.z
	fwd.y = 0.0
	_dash_dir = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	if is_first_person and _fp_viewmodel != null:
		_fp_viewmodel.trigger_action("DASH", 0.24)


func _try_melee_cleave(inspect_if_clear: bool = false) -> void:
	if not _has_live_leader():
		return
	if is_mounted():
		if inspect_if_clear:
			_try_inspect_aimed_unit()
		return
	if _attack_cd > 0.0 and not inspect_if_clear:
		return

	var wid: String = leader_unit.get_equipped_weapon_id() if leader_unit.has_method("get_equipped_weapon_id") else str(leader_unit.get("equipped_weapon_id"))
	var wdef: Dictionary = GameData.resolve_weapon_def(wid, int(leader_unit.role), int(leader_unit.warrior_class), true, false)
	var eff_wid: String = str(wdef.get("id", "GREAT_SPEAR"))
	var cd_mult: float = float(wdef.get("cooldown_mult", 1.0))

	if eff_wid == "HUNTING_BOW":
		if inspect_if_clear and _try_inspect_aimed_unit():
			return
		if _attack_cd > 0.0:
			return
		_attack_cd = 0.48 * cd_mult * PerkSystem.get_leader_attack_cd_mult(GameState.factions.get(0, {}))
		GameState.tutorial_cleaved = true
		_notify_tutorial_progress()
		leader_unit.play_attack_animation("BOW_SHOT", 0.36)
		if is_first_person and _fp_viewmodel != null:
			_fp_viewmodel.trigger_action("BOW_SHOT", 0.36)
		var origin := leader_unit.global_position + Vector3(0.0, 1.45, 0.0)
		var target_pos: Vector3
		if is_first_person and camera != null:
			origin = camera.global_position - camera.global_basis.z * FIRST_PERSON_JAVELIN_RELEASE
			target_pos = _get_first_person_aim_point()
		else:
			var aim := _get_ground_mouse_pos()
			var dir := aim - leader_unit.global_position
			dir.y = 0.0
			if dir.length() > 0.2:
				leader_unit.look_at(leader_unit.global_position + dir.normalized(), Vector3.UP)
			target_pos = aim + Vector3(0.0, 0.8, 0.0)
		var tier: int = int(GameState.factions[0].get("tech_tier", 1))
		var bow_dmg: float = float(leader_unit.attack_damage) * 1.25
		if GameState.factions[0].get("patron_god") == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
			bow_dmg *= 1.20
		if GameState.projectiles_container != null:
			Projectile3D.spawn(leader_unit, 0, origin, target_pos, bow_dmg, 34.0, "ARROW", tier, false)
		_play_sfx_3d("bow_release", leader_unit.global_position, 0.08, 0.0)
		return

	if not is_first_person:
		var aim := _get_ground_mouse_pos()
		var dir := aim - leader_unit.global_position
		dir.y = 0.0
		if dir.length() > 0.2:
			leader_unit.look_at(leader_unit.global_position + dir.normalized(), Vector3.UP)
	var r_over: float = float(wdef.get("range_override", 2.95))
	var reach_scale: float = clampf(r_over / 2.95, 0.72, 1.25) if r_over > 0.0 else 1.0
	var targets := _get_cleave_targets(reach_scale)
	if inspect_if_clear and targets.is_empty() and _try_inspect_aimed_unit():
		return
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.48 * cd_mult * PerkSystem.get_leader_attack_cd_mult(GameState.factions.get(0, {}))
	GameState.tutorial_cleaved = true
	_notify_tutorial_progress()
	var anim_name: String = str(wdef.get("attack_anim", "LEADER_CLEAVE"))
	leader_unit.play_attack_animation(anim_name, 0.40)
	var swing_cue: String = "club_smash" if (eff_wid == "WAR_CLUB" or eff_wid == "OBSIDIAN_CLEAVER" or anim_name == "HEAVY_SMASH") else "melee_swing"
	_play_sfx_3d(swing_cue, leader_unit.global_position, 0.08, 0.0)
	if is_first_person and _fp_viewmodel != null:
		var vm_action := "HEAVY_SMASH" if anim_name == "HEAVY_SMASH" else ("DUAL_SLASH" if anim_name == "DUAL_SLASH" else "CLEAVE")
		_fp_viewmodel.trigger_action(vm_action, 0.40)

	var vfx_host: Node = GameState.world_node if GameState.world_node != null else leader_unit.get_parent()
	if is_first_person and camera != null:
		CombatVFX.spawn_first_person_slash_arc(vfx_host, camera, Color(1.0, 0.90, 0.45, 0.92))
	else:
		CombatVFX.spawn_slash_arc(
			vfx_host,
			leader_unit.global_position,
			-leader_unit.global_transform.basis.z,
			Color(1.0, 0.90, 0.45, 0.92),
			1.25 * reach_scale
		)

	var dmg: float = float(leader_unit.attack_damage) * 1.25
	if GameState.factions[0].get("patron_god") == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
		dmg *= 1.20
	for target in targets:
		if target is StaticBody3D:
			target.take_damage(dmg, 0)
			GameState.notify_combat_audio(14.0)
		else:
			if target.get("is_child") != true and (target.get("faction_id") != null or target.get("is_aggro") == true or target.get("is_boss") == true):
				GameState.notify_combat_audio(14.0)
			target.take_damage(dmg, leader_unit, 0)


func _get_cleave_targets(reach_scale: float = 1.0) -> Array[Node3D]:
	var center := leader_unit.global_position - leader_unit.global_basis.z * (1.6 * reach_scale)
	if is_first_person:
		center = camera.global_position - camera.global_basis.z * (1.85 * reach_scale)
	var unit_reach := 3.2 * reach_scale
	var wild_reach := 3.6 * reach_scale
	var targets: Array[Node3D] = []
	var leader_in_arena: bool = (leader_unit.get("is_arena_combatant") == true or leader_unit.get_meta("is_arena_combatant", false) == true)
	for u in GameState.spatial_index.query_units_in_radius(center, unit_reach):
		if u == leader_unit or u.is_wounded or not GameState.is_hostile(0, u.faction_id):
			continue
		var u_opp: bool = (u.get("is_arena_opponent") == true or u.get_meta("is_arena_opponent", false) == true)
		var u_comb: bool = (u.get("is_arena_combatant") == true or u.get_meta("is_arena_combatant", false) == true)
		if leader_in_arena:
			if not u_opp:
				continue
		elif u_opp or u_comb:
			continue
		var point: Vector3 = u.global_position + (Vector3.UP if is_first_person else Vector3.ZERO)
		if _cleave_reaches(center, point, unit_reach):
			targets.append(u)

	for w in GameState.spatial_index.query_wildlife_in_radius(center, wild_reach):
		var w_opp: bool = (w.get("is_arena_opponent") == true or w.get_meta("is_arena_opponent", false) == true)
		if leader_in_arena:
			if not w_opp:
				continue
		else:
			if w_opp or w.is_protected_from(0):
				continue
		var point: Vector3 = w.projectile_hit_center() if is_first_person else w.global_position
		if _cleave_reaches(center, point, (3.6 if w.is_boss else 2.8) * reach_scale):
			targets.append(w)
	if not targets.is_empty() or leader_in_arena:
		return targets

	for b in GameState.spatial_index.query_buildings_in_radius(center, wild_reach):
		if b.hp <= 0.0 or not GameState.is_hostile(0, b.faction_id):
			continue
		var point: Vector3 = b.global_position + (Vector3.UP * 1.2 if is_first_person else Vector3.ZERO)
		if _cleave_reaches(center, point, wild_reach):
			targets.append(b)
	return targets


func _cleave_reaches(center: Vector3, point: Vector3, radius: float) -> bool:
	if center.distance_squared_to(point) > radius * radius:
		return false
	if not is_first_person:
		return true
	var from_eye := point - camera.global_position
	# Limit the swing to 60 degrees on either side of the 3D look direction.
	return from_eye.dot(-camera.global_basis.z) >= from_eye.length() * 0.5


func _get_first_person_aim_point() -> Vector3:
	var ray_orig := camera.global_position
	var ray_dir := -camera.global_basis.z
	var aim_limit := 32.0
	if ray_dir.y < -0.001 and ray_orig.y > 0.0:
		aim_limit = minf(aim_limit, ray_orig.y / -ray_dir.y)
	var best_t := aim_limit
	var best_point := ray_orig + ray_dir * minf(24.0, aim_limit)
	var leader_in_arena: bool = (leader_unit.get("is_arena_combatant") == true or leader_unit.get_meta("is_arena_combatant", false) == true)
	for u in GameState.spatial_index.query_units_in_radius(ray_orig, aim_limit + Projectile3D.UNIT_HIT_RADIUS):
		if u == leader_unit or u.is_wounded or not GameState.is_hostile(0, u.faction_id):
			continue
		var u_opp: bool = (u.get("is_arena_opponent") == true or u.get_meta("is_arena_opponent", false) == true)
		var u_comb: bool = (u.get("is_arena_combatant") == true or u.get_meta("is_arena_combatant", false) == true)
		if leader_in_arena:
			if not u_opp:
				continue
		elif u_opp or u_comb:
			continue
		var tgt: Vector3 = u.global_position + Vector3.UP
		var proj := (tgt - ray_orig).dot(ray_dir)
		if proj > FIRST_PERSON_JAVELIN_RELEASE and proj < best_t:
			if tgt.distance_squared_to(ray_orig + ray_dir * proj) <= Projectile3D.UNIT_HIT_RADIUS * Projectile3D.UNIT_HIT_RADIUS:
				best_t = proj
				best_point = tgt
	for w in GameState.spatial_index.query_wildlife_in_radius(ray_orig, aim_limit + 2.0):
		var w_opp: bool = (w.get("is_arena_opponent") == true or w.get_meta("is_arena_opponent", false) == true)
		if leader_in_arena:
			if not w_opp:
				continue
		else:
			if w_opp or w.is_protected_from(0):
				continue
		var tgt_w: Vector3 = w.projectile_hit_center()
		var proj_w := (tgt_w - ray_orig).dot(ray_dir)
		if proj_w > FIRST_PERSON_JAVELIN_RELEASE and proj_w < best_t:
			var radius: float = w.projectile_hit_radius
			if tgt_w.distance_squared_to(ray_orig + ray_dir * proj_w) <= radius * radius:
				best_t = proj_w
				best_point = tgt_w
	return best_point


func _try_throw_javelin() -> void:
	if _javelin_cd > 0.0 or leader_unit == null or leader_unit.is_dead or GameState.projectiles_container == null or is_mounted():
		return
	_javelin_cd = 1.15 * PerkSystem.get_leader_attack_cd_mult(GameState.factions.get(0, {}))
	GameState.tutorial_thrown = true
	_notify_tutorial_progress()
	leader_unit.play_attack_animation("JAVELIN_THROW", 0.36)
	if is_first_person and _fp_viewmodel != null:
		_fp_viewmodel.trigger_action("JAVELIN", 0.36)

	var origin := leader_unit.global_position + Vector3(0.0, 1.5, 0.0)
	var target_pos: Vector3
	if is_first_person and camera != null:
		origin = camera.global_position - camera.global_basis.z * FIRST_PERSON_JAVELIN_RELEASE
		target_pos = _get_first_person_aim_point()
	else:
		var aim := _get_ground_mouse_pos()
		var dir := aim - leader_unit.global_position
		dir.y = 0.0
		if dir.length() > 0.2:
			leader_unit.look_at(leader_unit.global_position + dir.normalized(), Vector3.UP)
		target_pos = aim + Vector3(0.0, 0.8, 0.0)

	var tier := int(GameState.factions[0].get("tech_tier", 1))
	var jav_dmg: float = float(leader_unit.ranged_attack_damage) * 1.25
	var patron: int = int(GameState.factions[0].get("patron_god", GameData.PatronGod.NONE))
	if patron == GameData.PatronGod.VALK_TOR:
		jav_dmg *= 1.25
	elif patron == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
		jav_dmg *= 1.20
	Projectile3D.spawn(leader_unit, 0, origin, target_pos, jav_dmg, 32.0, "JAVELIN", tier, false)
	_play_sfx_3d("javelin_throw", leader_unit.global_position, 0.08, 0.0)


func _try_inspect_aimed_unit() -> bool:
	if not is_instance_valid(GameState.hud_controller) or GameState.units_container == null:
		return false
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 6.0, leader_unit.collision_mask, [leader_unit.get_rid()])
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var unit: Node = hit.get("collider")
	if unit == null or not GameState.units_container.is_ancestor_of(unit) or unit.is_dead:
		return false
	if unit.faction_id != 0 and not (unit.is_wounded and unit.original_faction_id == 0):
		return false
	GameState.hud_controller.inspect_unit(unit)
	return true


func _try_inspect_clicked_unit() -> bool:
	if GameState.units_container == null or GameState.hud_controller == null:
		return false
	var click_pos: Vector3 = _get_ground_mouse_pos()
	# Do not hijack click if enemy hostile or nearby wildlife is right next to cursor
	for u in GameState.spatial_index.query_units_in_radius(click_pos, Layout.SCAN_RANGE_INSPECT_ENEMY + 0.5):
		if u.get("is_dead") != true and u.get("is_wounded") != true:
			var u_fid: int = int(u.get("faction_id"))
			if GameState.is_hostile(0, u_fid) and click_pos.distance_to((u as Node3D).global_position) <= Layout.SCAN_RANGE_INSPECT_ENEMY:
				return false
	for w in GameState.spatial_index.query_wildlife_in_radius(click_pos, Layout.SCAN_RANGE_INSPECT_BOSS + 0.5):
		if w.get("is_dead") != true:
			var check_r := Layout.SCAN_RANGE_INSPECT_BOSS if w.get("is_boss") == true else Layout.SCAN_RANGE_INSPECT_WILDLIFE
			if click_pos.distance_to((w as Node3D).global_position) <= check_r:
				return false
	var best_u: Node = null
	var best_d := Layout.SCAN_RANGE_INSPECT
	for u in GameState.spatial_index.query_units_in_radius(click_pos, Layout.SCAN_RANGE_INSPECT + 0.5):
		if u.get("is_dead") != true:
			var u_fid: int = int(u.get("faction_id"))
			if u_fid == 0 or (u.get("is_wounded") and int(u.get("original_faction_id")) == 0):
				var d := click_pos.distance_to((u as Node3D).global_position)
				if d < best_d:
					best_d = d
					best_u = u
	if best_u != null and GameState.hud_controller.has_method("inspect_unit"):
		GameState.hud_controller.inspect_unit(best_u)
		return true
	return false


func _try_interact_or_harvest() -> void:
	if leader_unit == null or leader_unit.is_dead:
		return
	if is_mounted():
		_try_dismount()
		return
	var representative := GameState.nearby_rival_leader(leader_unit.global_position)
	if representative != null and is_instance_valid(GameState.hud_controller):
		GameState.hud_controller.open_leader_negotiation(representative.faction_id)
		return
	# 0. Rescue nearby wounded rebel tribe member to Shaman Shack
	var shacks: Array = GameState.get_faction_buildings(0, "SHAMAN_SHACK", true)
	for u in GameState.spatial_index.query_units_in_radius(leader_unit.global_position, Layout.SCAN_RANGE_FIELD_AID + 0.5):
		if u.get("is_dead") != true and u.get("is_wounded") == true and u.get("is_healing_in_shack") != true:
			if leader_unit.global_position.distance_to((u as Node3D).global_position) <= Layout.SCAN_RANGE_FIELD_AID:
				if not shacks.is_empty():
					var best_shack: Node3D = shacks[0] as Node3D
					var best_sd: float = (u as Node3D).global_position.distance_squared_to(best_shack.global_position)
					for s in shacks:
						var s3d := s as Node3D
						if s3d != null:
							var sd: float = (u as Node3D).global_position.distance_squared_to(s3d.global_position)
							if sd < best_sd:
								best_sd = sd
								best_shack = s3d
					u.send_to_shaman_shack(best_shack.global_position)
					_play_ui_sfx("ui_click", 0.04)
					GameState.push_log("Sent wounded %s to the Shaman Shack for healing!" % str(u.get("unit_name")), "success")
				else:
					if u.has_method("apply_field_aid") and u.apply_field_aid():
						_play_ui_sfx("ui_click", 0.04)
						GameState.push_log("Applied field aid to %s (+20s). Build a Shaman's Healing Shack ([B]) so they can recover!" % str(u.get("unit_name")), "warning")
					else:
						GameState.push_log("%s needs a constructed Shaman's Healing Shack ([B]) to recover!" % str(u.get("unit_name")), "warning")
				return

	# 1. Recruit nearby wild wanderers
	var recruited := 0
	for u in GameState.spatial_index.query_units_in_radius(leader_unit.global_position, Layout.SCAN_RANGE_RECRUIT + 0.5):
		if u.get("is_dead") != true and int(u.get("faction_id")) == -1:
			if leader_unit.global_position.distance_to((u as Node3D).global_position) <= Layout.SCAN_RANGE_RECRUIT:
				u.convert_to_faction(0, false)
				recruited += 1
	if recruited > 0:
		_play_ui_sfx("ui_click", 0.04)
		GameState.award_xp(0, 20.0 * float(recruited), "Recruited wanderer")
		GameState.push_log("Recruited %d wandering tribesfolk!" % recruited, "success")
		_notify_tutorial_progress()
		return

	if _try_livestock_interaction():
		return

	# 1.5 Direct assist on unfinished blueprint nearby
	for b in GameState.spatial_index.query_buildings_in_radius(leader_unit.global_position, Layout.SCAN_RANGE_CONSTRUCTION_ASSIST + 0.5):
		if int(b.get("faction_id")) == 0 and b.get("is_constructed") != true:
			if leader_unit.global_position.distance_to((b as Node3D).global_position) <= Layout.SCAN_RANGE_CONSTRUCTION_ASSIST:
				if _harvest_cd > 0.0:
					return
				_harvest_cd = 0.45
				var bdir := (b as Node3D).global_position - leader_unit.global_position
				bdir.y = 0.0
				if bdir.length() > 0.1:
					leader_unit.look_at(leader_unit.global_position + bdir.normalized(), Vector3.UP)
				leader_unit.play_attack_animation("TOOL_SWING", 0.30)
				if is_first_person and _fp_viewmodel != null:
					_fp_viewmodel.trigger_action("WORK", 0.30)
				b.advance_construction(1.6 * PerkSystem.get_build_speed_mult(GameState.factions.get(0, {})))
				_play_sfx_3d("build_hammer", (b as Node3D).global_position, 0.08, -2.0)
				CombatVFX.spawn_damage_popup(b as Node3D, "+Build", Color(0.55, 0.90, 1.0), 0.95, 2.2)
				_notify_tutorial_progress()
				return

	# 1.8 Open Blood-Pit Arena drawer when interacting near a constructed Arena Pit
	for arena_b in GameState.get_faction_buildings(0, "ARENA_PIT", true):
		if is_instance_valid(arena_b) and not arena_b.get("is_destroyed"):
			if leader_unit.global_position.distance_to((arena_b as Node3D).global_position) <= 7.2:
				if is_instance_valid(GameState.hud_controller) and GameState.hud_controller.has_method("open_arena_drawer"):
					GameState.hud_controller.open_arena_drawer()
					return

	# 2. Direct harvest nearby resource node
	if _harvest_cd > 0.0:
		return
	if GameState.resources_container != null:
		var best_node: Node = null
		var best_d := Layout.SCAN_RANGE_HARVEST
		for n in GameState.resources_container.get_children():
			if not is_instance_valid(n):
				continue
			var nt_chk: String = n.get_meta("node_type", "")
			if nt_chk == "CAVEMAN_CAVE":
				continue
			var d := leader_unit.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best_node = n
		if best_node != null:
			_harvest_cd = 0.45
			GameState.tutorial_harvested = true
			var ndir := (best_node as Node3D).global_position - leader_unit.global_position
			ndir.y = 0.0
			if ndir.length() > 0.1:
				leader_unit.look_at(leader_unit.global_position + ndir.normalized(), Vector3.UP)
			leader_unit.play_attack_animation("TOOL_SWING", 0.30)
			if is_first_person and _fp_viewmodel != null:
				_fp_viewmodel.trigger_action("WORK", 0.30)
			var nt: String = best_node.get_meta("node_type", "BERRY_BUSH")
			if HARVEST_YIELD_TABLE.has(nt):
				var hy: Dictionary = HARVEST_YIELD_TABLE[nt]
				GameState.add_resource(0, str(hy["res"]), float(hy["amount"]))
				var harvest_cue: String = "stone_mine" if (nt == "STONE" or nt == "FLINT") else "wood_chop"
				_play_sfx_3d(harvest_cue, (best_node as Node3D).global_position, 0.08, -2.0)
				CombatVFX.spawn_damage_popup(leader_unit, str(hy["label"]), hy["col"], 0.95)
				GameState.push_log("%s %s." % [hy["verb"], hy["label"]], "info")
			_notify_tutorial_progress()


func _try_livestock_interaction() -> bool:
	var nearest: Node = null
	var best := Layout.SCAN_RANGE_LIVESTOCK
	for animal in GameState.spatial_index.query_wildlife_in_radius(leader_unit.global_position, best):
		if animal.can_interact(0):
			var d: float = leader_unit.global_position.distance_to(animal.global_position)
			if d < best:
				nearest = animal
				best = d
	if nearest == null:
		return false
	if nearest.can_mount(0):
		_mount_livestock(nearest)
	elif nearest.attempt_tame(leader_unit):
		var tame_cue: String = "animal_roar" if nearest.animal_type in ["MAMMOTH", "BOAR", "SLATEBACK_BOAR"] else "blessing_cast"
		_play_sfx_3d(tame_cue, nearest.global_position, 0.06, -1.0)
	return true


func is_mounted() -> bool:
	return is_instance_valid(_mounted_animal) and not _mounted_animal.is_dead


func get_mount_name() -> String:
	return _mounted_animal.animal_name if is_mounted() else ""


func _mount_livestock(animal: Node3D, silent: bool = false) -> void:
	_mounted_animal = animal
	_dash_timer = 0.0
	leader_unit.add_collision_exception_with(animal)
	leader_unit.global_position = animal.global_position
	leader_unit.rotation.y = deg_to_rad(cam_yaw) if is_first_person else animal.rotation.y
	leader_unit.velocity = Vector3.ZERO
	GameState.spatial_index.update_unit(leader_unit)
	animal.set_rider(leader_unit.unit_id)
	leader_unit.set_mounted(animal.get_mount_shape(), animal.mount_profile["leg_spread"])
	animal.sync_ridden_transform(leader_unit, Vector3.ZERO, 0.0)
	if is_first_person:
		_update_camera(0.0)
	mount_changed.emit()
	if not silent:
		var mount_cue: String = "animal_roar" if animal.animal_type in ["MAMMOTH", "BOAR", "SLATEBACK_BOAR"] else "blessing_cast"
		_play_sfx_3d(mount_cue, animal.global_position, 0.06, -1.0)
	GameState.push_log("Mounted %s." % animal.animal_name, "info")


func _try_dismount() -> void:
	var animal := _mounted_animal
	var side := leader_unit.global_basis.x
	var back := leader_unit.global_basis.z
	var stride := maxf(1.4, animal.get_mount_shape().radius + 0.5)
	var extent := GameState.valley_layout.unit_half_extent
	for direction in [side, -side, back, -back]:
		var point: Vector3 = animal.global_position + direction * stride
		if absf(point.x) > extent or absf(point.z) > extent or not leader_unit.can_stand_at(point, animal.get_rid()):
			continue
		leader_unit.global_position = point
		leader_unit.velocity = Vector3.ZERO
		GameState.spatial_index.update_unit(leader_unit)
		dismount_from(animal)
		return
	GameState.push_log("Move to a clear spot to dismount.", "info")


func dismount_from(animal: Node3D) -> void:
	if animal != _mounted_animal:
		return
	_mounted_animal = null
	animal.set_rider(0)
	if is_instance_valid(leader_unit):
		leader_unit.remove_collision_exception_with(animal)
		leader_unit.set_mounted(null)
		if is_first_person and _has_live_leader():
			_update_camera(0.0)
	mount_changed.emit()


func restore_mount_from_save() -> void:
	if leader_unit == null or GameState.wildlife_container == null:
		return
	for animal in GameState.wildlife_container.get_children():
		if animal.rider_unit_id == leader_unit.unit_id:
			animal.set_rider(0)
			if animal.can_mount(0):
				_mount_livestock(animal, true)
			return


func _try_god_blessing() -> void:
	if is_mounted():
		return
	if _blessing_cd > 0.0 or leader_unit == null:
		if _blessing_cd > 0.0:
			GameState.push_log("Divine Blessing recharging (%.0fs left)." % _blessing_cd, "warning")
		return
	_blessing_cd = 16.0 * PerkSystem.get_blessing_cd_mult(GameState.factions.get(0, {}))
	if is_first_person and _fp_viewmodel != null:
		_fp_viewmodel.trigger_action("BLESSING", 0.45)
	BlessingEffects.trigger_leader_blessing(leader_unit, 0, true)

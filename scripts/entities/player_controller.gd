extends Node

const Layout = preload("res://scripts/core/world_layout.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")

var _mounted_animal: Node3D

const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const BlessingEffects = preload("res://scripts/systems/blessing_effects.gd")
const Projectile3D = preload("res://scripts/entities/projectile_3d.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const TutorialBeacon = preload("res://scripts/core/tutorial_beacon.gd")

var leader_unit: CharacterBody3D = null
var camera_pivot: Node3D = null
var camera: Camera3D = null
var _leader_light: OmniLight3D = null
var _tutorial_beacon: Node3D = null

var cam_yaw: float = 0.0
var cam_pitch: float = 28.0
var cam_distance: float = 12.0
var target_cam_distance: float = 12.0

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
	camera.far = GameState.valley_layout.camera_far
	_ensure_tutorial_beacon()
	attach_leader(p_leader)


func attach_leader(p_leader: CharacterBody3D) -> void:
	if is_instance_valid(_mounted_animal):
		dismount_from(_mounted_animal)
	reset_cooldowns()
	_ensure_tutorial_beacon()
	leader_unit = p_leader
	if leader_unit != null:
		leader_unit.is_player_controlled = true
		if camera_pivot != null:
			camera_pivot.global_position = leader_unit.global_position + Vector3(0.0, 1.4, 0.0)
	_sync_tutorial_beacon(0.0)


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


func reset_cooldowns() -> void:
	_dash_timer = 0.0
	_dash_cd = 0.0
	_dash_dir = Vector3.ZERO
	_attack_cd = 0.0
	_javelin_cd = 0.0
	_blessing_cd = 0.0
	_harvest_cd = 0.0
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


func exit_build_mode() -> void:
	is_build_mode = false
	if _blueprint_ghost != null:
		_blueprint_ghost.queue_free()
		_blueprint_ghost = null


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
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if not _is_pointer_over_ui():
				target_cam_distance = clampf(target_cam_distance - 2.2, 5.5, 42.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if not _is_pointer_over_ui():
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
			elif not GameState.is_paused:
				if _try_inspect_clicked_unit():
					return
				_try_melee_cleave()

	elif event is InputEventMouseMotion and _rmb_dragging:
		var mm := event as InputEventMouseMotion
		_rmb_drag_dist += mm.relative.length()
		cam_yaw -= mm.relative.x * 0.28
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.22, 12.0, 68.0)

	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_ESCAPE and is_build_mode:
			exit_build_mode()
		elif kc == KEY_T and is_build_mode:
			blueprint_rot_y += deg_to_rad(45.0)
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

	var has_world_input := sim_running and not _world_input_blocked()
	if not has_world_input or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rmb_dragging = false
	if leader_unit != null and is_instance_valid(leader_unit) and not leader_unit.is_dead:
		if has_world_input:
			_move_leader(delta)
		if sim_running and is_instance_valid(_mounted_animal):
			var gait := leader_unit.velocity if has_world_input else Vector3.ZERO
			_mounted_animal.sync_ridden_transform(leader_unit, gait, delta)
		_update_camera(delta)
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
		var yaw_rad := deg_to_rad(cam_yaw)
		var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
		var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
		move_dir = (forward * -input_vec.y + right * input_vec.x).normalized()

	var spd: float = leader_unit.move_speed
	if is_mounted():
		spd *= Farming.MOUNT_SPEED_MULT
	elif Input.is_key_pressed(KEY_SHIFT):
		spd *= 1.38

	if _dash_timer > 0.0:
		_dash_timer -= delta
		leader_unit.velocity.x = _dash_dir.x * spd * 2.6
		leader_unit.velocity.z = _dash_dir.z * spd * 2.6
	elif move_dir.length() > 0.05:
		leader_unit.velocity.x = move_dir.x * spd
		leader_unit.velocity.z = move_dir.z * spd
		var look_target := leader_unit.global_position + move_dir
		leader_unit.look_at(look_target, Vector3.UP)
	else:
		leader_unit.velocity.x = lerpf(leader_unit.velocity.x, 0.0, 14.0 * delta)
		leader_unit.velocity.z = lerpf(leader_unit.velocity.z, 0.0, 14.0 * delta)

	if not leader_unit.is_on_floor():
		leader_unit.velocity.y -= 24.0 * delta
	else:
		leader_unit.velocity.y = 0.0

	leader_unit.move_and_slide()
	leader_unit.global_position.x = clampf(leader_unit.global_position.x, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)
	leader_unit.global_position.z = clampf(leader_unit.global_position.z, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)


func _update_camera(delta: float) -> void:
	cam_distance = lerpf(cam_distance, target_cam_distance, 10.0 * delta)
	var zoom_t := clampf((cam_distance - 5.5) / (42.0 - 5.5), 0.0, 1.0)
	var eff_pitch := lerpf(cam_pitch, 64.0, zoom_t * 0.72)

	var target_pivot := leader_unit.global_position + Vector3(0.0, 1.4, 0.0)
	if is_mounted():
		target_pivot.y += 0.65
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_pivot, 14.0 * delta)

	var yaw_r := deg_to_rad(cam_yaw)
	var pitch_r := deg_to_rad(eff_pitch)
	var offset := Vector3(
		sin(yaw_r) * cos(pitch_r) * cam_distance,
		sin(pitch_r) * cam_distance,
		cos(yaw_r) * cos(pitch_r) * cam_distance
	)
	camera.position = offset
	camera.look_at(camera_pivot.global_position, Vector3.UP)


func _get_ground_mouse_pos() -> Vector3:
	if camera == null or leader_unit == null:
		return Vector3.ZERO
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
	else:
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
	_dash_cd = 2.0
	_dash_timer = 0.20
	var fwd := -leader_unit.global_transform.basis.z
	fwd.y = 0.0
	_dash_dir = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD


func _try_melee_cleave() -> void:
	if _attack_cd > 0.0 or leader_unit == null or leader_unit.is_dead or is_mounted():
		return
	_attack_cd = 0.48
	GameState.tutorial_cleaved = true
	_notify_tutorial_progress()
	leader_unit.play_attack_animation("LEADER_CLEAVE", 0.40)

	# Face mouse ground cursor
	var aim := _get_ground_mouse_pos()
	var dir := aim - leader_unit.global_position
	dir.y = 0.0
	if dir.length() > 0.2:
		leader_unit.look_at(leader_unit.global_position + dir.normalized(), Vector3.UP)

	var vfx_host: Node = GameState.world_node if GameState.world_node != null else leader_unit.get_parent()
	CombatVFX.spawn_slash_arc(
		vfx_host,
		leader_unit.global_position,
		-leader_unit.global_transform.basis.z,
		Color(1.0, 0.90, 0.45, 0.92),
		1.25
	)

	var dmg: float = float(leader_unit.attack_damage) * 1.25
	if GameState.factions[0].get("patron_god") == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
		dmg *= 1.20

	var hit_any := false
	var cleave_center := leader_unit.global_position + (-leader_unit.global_transform.basis.z * 1.6)
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if not is_instance_valid(u) or u.get("is_dead") or u == leader_unit:
				continue
			if GameState.is_hostile(0, u.get("faction_id")) and cleave_center.distance_to(u.global_position) <= 3.2:
				u.take_damage(dmg, leader_unit, 0)
				hit_any = true

	if GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if not is_instance_valid(w) or w.get("is_dead") or w.is_protected_from(0):
				continue
			var r := 3.6 if w.get("is_boss") else 2.8
			if cleave_center.distance_to(w.global_position) <= r:
				w.take_damage(dmg, leader_unit, 0)
				hit_any = true

	if not hit_any and GameState.buildings_container != null:
		for b in GameState.buildings_container.get_children():
			if not is_instance_valid(b) or b.get("hp") <= 0.0:
				continue
			if GameState.is_hostile(0, b.get("faction_id")) and cleave_center.distance_to(b.global_position) <= 3.6:
				b.take_damage(dmg, 0)


func _try_throw_javelin() -> void:
	if _javelin_cd > 0.0 or leader_unit == null or leader_unit.is_dead or GameState.projectiles_container == null or is_mounted():
		return
	_javelin_cd = 1.15
	GameState.tutorial_thrown = true
	_notify_tutorial_progress()
	leader_unit.play_attack_animation("JAVELIN_THROW", 0.36)
	var aim := _get_ground_mouse_pos()
	var dir := aim - leader_unit.global_position
	dir.y = 0.0
	if dir.length() > 0.2:
		leader_unit.look_at(leader_unit.global_position + dir.normalized(), Vector3.UP)

	var origin := leader_unit.global_position + Vector3(0.0, 1.5, 0.0)
	var tier := int(GameState.factions[0].get("tech_tier", 1))
	var jav_dmg: float = float(leader_unit.ranged_attack_damage) * 1.25
	var patron: int = int(GameState.factions[0].get("patron_god", GameData.PatronGod.NONE))
	if patron == GameData.PatronGod.VALK_TOR:
		jav_dmg *= 1.25
	elif patron == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
		jav_dmg *= 1.20
	Projectile3D.spawn(leader_unit, 0, origin, aim + Vector3(0.0, 0.8, 0.0), jav_dmg, 32.0, "JAVELIN", tier, false)


func _try_inspect_clicked_unit() -> bool:
	if GameState.units_container == null or GameState.hud_controller == null:
		return false
	var click_pos: Vector3 = _get_ground_mouse_pos()
	# Do not hijack click if enemy hostile or nearby wildlife is right next to cursor
	for u in GameState.units_container.get_children():
		if is_instance_valid(u) and not u.get("is_dead") and not u.get("is_wounded"):
			var u_fid: int = int(u.get("faction_id"))
			if GameState.is_hostile(0, u_fid):
				if click_pos.distance_to((u as Node3D).global_position) <= Layout.SCAN_RANGE_INSPECT_ENEMY:
					return false
	if GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if is_instance_valid(w) and not w.get("is_dead"):
				var check_r := Layout.SCAN_RANGE_INSPECT_BOSS if w.get("is_boss") == true else Layout.SCAN_RANGE_INSPECT_WILDLIFE
				if click_pos.distance_to((w as Node3D).global_position) <= check_r:
					return false
	var best_u: Node = null
	var best_d := Layout.SCAN_RANGE_INSPECT
	for u in GameState.units_container.get_children():
		if is_instance_valid(u) and not u.get("is_dead"):
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
		dismount_from(_mounted_animal)
		return
	var representative := GameState.nearby_rival_leader(leader_unit.global_position)
	if representative != null and is_instance_valid(GameState.hud_controller):
		GameState.hud_controller.open_leader_negotiation(representative.faction_id)
		return
	# 0. Rescue nearby wounded rebel tribe member to Shaman Shack
	if GameState.units_container != null:
		var shacks: Array = GameState.get_faction_buildings(0, "SHAMAN_SHACK", true)
		for u in GameState.units_container.get_children():
			if is_instance_valid(u) and not u.get("is_dead") and u.get("is_wounded") and not u.get("is_healing_in_shack"):
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
						GameState.push_log("Sent wounded %s to the Shaman Shack for healing!" % str(u.get("unit_name")), "success")
					else:
						if u.has_method("apply_field_aid") and u.apply_field_aid():
							GameState.push_log("Applied field aid to %s (+20s). Build a Shaman's Healing Shack ([B]) so they can recover!" % str(u.get("unit_name")), "warning")
						else:
							GameState.push_log("%s needs a constructed Shaman's Healing Shack ([B]) to recover!" % str(u.get("unit_name")), "warning")
					return

	# 1. Recruit nearby wild wanderers
	var recruited := 0
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if is_instance_valid(u) and not u.get("is_dead") and u.get("faction_id") == -1:
				if leader_unit.global_position.distance_to(u.global_position) <= Layout.SCAN_RANGE_RECRUIT:
					u.convert_to_faction(0, false)
					recruited += 1
	if recruited > 0:
		GameState.push_log("Recruited %d wandering tribesfolk!" % recruited, "success")
		_notify_tutorial_progress()
		return

	if _try_livestock_interaction():
		return

	# 1.5 Direct assist on unfinished blueprint nearby
	for b in GameState.get_faction_buildings(0, "", false):
		if is_instance_valid(b) and not b.get("is_constructed"):
			if leader_unit.global_position.distance_to((b as Node3D).global_position) <= Layout.SCAN_RANGE_CONSTRUCTION_ASSIST:
				if _harvest_cd > 0.0:
					return
				_harvest_cd = 0.45
				var bdir := (b as Node3D).global_position - leader_unit.global_position
				bdir.y = 0.0
				if bdir.length() > 0.1:
					leader_unit.look_at(leader_unit.global_position + bdir.normalized(), Vector3.UP)
				leader_unit.play_attack_animation("TOOL_SWING", 0.30)
				b.advance_construction(1.6)
				CombatVFX.spawn_damage_popup(b as Node3D, "+Build", Color(0.55, 0.90, 1.0), 0.95, 2.2)
				_notify_tutorial_progress()
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
			var nt: String = best_node.get_meta("node_type", "BERRY_BUSH")
			if HARVEST_YIELD_TABLE.has(nt):
				var hy: Dictionary = HARVEST_YIELD_TABLE[nt]
				GameState.add_resource(0, str(hy["res"]), float(hy["amount"]))
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
	else:
		nearest.attempt_tame(leader_unit)
	return true


func is_mounted() -> bool:
	return is_instance_valid(_mounted_animal) and not _mounted_animal.is_dead


func _mount_livestock(animal: Node3D) -> void:
	_mounted_animal = animal
	_dash_timer = 0.0
	animal.set_rider(leader_unit.unit_id)
	leader_unit.set_mounted(true)
	animal.sync_ridden_transform(leader_unit, Vector3.ZERO, 0.0)
	GameState.push_log("Mounted %s. Press E to dismount." % animal.animal_name, "info")


func dismount_from(animal: Node3D) -> void:
	if animal != _mounted_animal:
		return
	_mounted_animal = null
	animal.set_rider(0)
	if is_instance_valid(leader_unit):
		leader_unit.set_mounted(false)
		var side := leader_unit.global_transform.basis.x * 1.4
		for direction in [side, -side]:
			var point: Vector3 = leader_unit.global_position + direction
			var extent := GameState.valley_layout.unit_half_extent
			if absf(point.x) > extent or absf(point.z) > extent:
				continue
			var nav: RefCounted = GameState.valley_nav
			if not nav.is_ready() or not nav.is_cell_blocked(nav.world_to_cell(point)):
				animal.global_position = point
				break
		GameState.spatial_index.update_wildlife(animal)


func restore_mount_from_save() -> void:
	if leader_unit == null or GameState.wildlife_container == null:
		return
	for animal in GameState.wildlife_container.get_children():
		if animal.rider_unit_id == leader_unit.unit_id:
			animal.set_rider(0)
			if animal.can_mount(0):
				_mount_livestock(animal)
			return


func _try_god_blessing() -> void:
	if is_mounted():
		return
	if _blessing_cd > 0.0 or leader_unit == null:
		if _blessing_cd > 0.0:
			GameState.push_log("Divine Blessing recharging (%.0fs left)." % _blessing_cd, "warning")
		return
	_blessing_cd = 16.0
	BlessingEffects.trigger_leader_blessing(leader_unit, 0, true)

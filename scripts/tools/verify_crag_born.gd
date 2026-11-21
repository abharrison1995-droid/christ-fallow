extends SceneTree
## Run after a clean import, with -- --crag-born-trial --out-dir=<absolute directory>.

const Trial = preload("res://scripts/entities/crag_born_trial.gd")
const POST_SHADER = preload("res://scripts/shaders/psx_diablo_post.gdshader")
const FRAME := Rect2i(0, 0, 1180, 824)
const SNAPSHOT := Vector2i(288, 188)
const VARIANTS := ["broad", "braided", "child"]
const SIX_VARIANTS := ["broad", "cropped", "boy", "braided", "twin_knots", "child"]
const KITS := ["SPEARMAN", "FORAGER"]

var _issues: Array[String] = []
var _stage: Node3D
var _camera: Camera3D
var _data: Node
var _state: Node
var _factory: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_data = root.get_node("GameData")
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	if "--check-default-roster" in OS.get_cmdline_user_args():
		var expect_enabled := not (Trial.PROCEDURAL_ROSTER_FLAG in OS.get_cmdline_user_args())
		if not _check(Trial.enabled() == expect_enabled,
				"Default roster check expects Crag-Born skinned rig enabled unless --procedural-roster is passed"):
			quit(1)
			return
		await _verify_gameplay()
		if _issues.is_empty():
			print("DEFAULT ROSTER CHECK PASSED")
		quit(0 if _issues.is_empty() else 1)
		return
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if not _check(Trial.enabled(), "Crag-Born skinned rig must be enabled (do not pass --procedural-roster)"):
		quit(1)
		return
	if not _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Pass a writable absolute --out-dir for the comparison sheet"):
		quit(1)
		return
	await _verify_gameplay()
	await _review_models(out_dir)
	if _issues.is_empty():
		print("CRAG-BORN PILOT PASSED")
	else:
		push_error("Crag-Born pilot failed %d checks." % _issues.size())
	quit(0 if _issues.is_empty() else 1)


func _verify_gameplay() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Node = main.get_node("UILayer/GameHUD")
	_state.start_new_campaign("Enoch", "Fallow Chosen", _data.Lineage.CRAG_BORN)
	var world: Node = _state.world_node
	var faction: Node = _state.faction_controllers[0]
	var leader: Node = _state.get_faction_leader(0)
	var base_pos: Vector3 = leader.global_position
	var unit: Node = faction.spawn_colonist(base_pos + Vector3(6, 0, 0), _data.Lineage.CRAG_BORN,
		_data.Gender.MALE, _data.Role.FORAGER, false, false, false, "Pilot")
	var child: Node = faction.spawn_colonist(base_pos + Vector3(7, 0, 2), _data.Lineage.CRAG_BORN,
		_data.Gender.FEMALE, _data.Role.FORAGER, false, true, false, "Child fit")
	unit.set_physics_process(false)
	child.set_physics_process(false)
	var forager := unit.get_node_or_null("CragBornTrial") as Trial
	var child_model := child.get_node_or_null("CragBornTrial") as Trial
	var stalker: Node = faction.spawn_colonist(base_pos + Vector3(8, 0, 0), _data.Lineage.STALKER,
		_data.Gender.MALE, _data.Role.FORAGER, false, false, false, "Stalker Check")
	stalker.set_physics_process(false)
	_check(stalker._skinned_trial == null and stalker._visual_root.visible,
		"Unpromoted lineages continue to use procedural rigs")
	var leader_trial_enabled := Trial.LAUNCH_FLAG in OS.get_cmdline_user_args()
	_check((leader.get_node_or_null("SkinnedTribesmanTrial") != null) == leader_trial_enabled,
		"The leader still respects the --skinned-tribesman-trial flag")
	if not Trial.enabled():
		_check(forager == null and child_model == null and unit._visual_root.visible and child._visual_root.visible,
			"--procedural-roster opts out to the procedural Crag-Born roster")
		_verify_body_variants(faction, base_pos + Vector3(12, 0, 6))
		main.free()
		return
	if _check(forager != null and child_model != null, "Default Crag-Born adults and children spawn the promoted skinned rig"):
		var initial_body := _body_file(unit)
		_check(child_model.scale.is_equal_approx(Vector3.ONE * Trial.CHILD_SCALE), "Child scale is applied")
		_check(leader.get_node_or_null("CragBornTrial") == null, "Crag-Born promotion does not replace the leader slot")
		_check(world.is_psx_filter_enabled(), "Campaign PSX filter is enabled")
		world.toggle_psx_filter()
		unit._update_procedural_animation(0.017)
		_check(forager._body_materials[0].get_shader_parameter("enable_jitter") == false,
			"Disabling PSX also disables skinned vertex jitter")
		world.toggle_psx_filter()
		# Drive the real gather routine with a nearby berry bush, then deliver its yield to camp.
		var camp: Node3D = faction.spawn_building("CAMPFIRE", unit.global_position + Vector3(-2, 0, 0))
		var bush := Node3D.new()
		bush.set_meta("node_type", "BERRY_BUSH")
		_state.resources_container.add_child(bush)
		bush.global_position = unit.global_position + Vector3(0, 0, -4)
		unit._target_node = bush
		unit._day_work_routine(0.1)
		unit._update_procedural_animation(0.1)
		_check(forager.visible and not unit._visual_root.visible and forager._animation.current_animation == &"Walk",
			"Forager approaching berries uses the imported Walk")
		bush.global_position = unit.global_position + Vector3(0, 0, -1.5)
		unit._day_work_routine(3.2)
		unit._update_procedural_animation(0.1)
		_check(unit._is_working_this_frame and forager.visible and not unit._visual_root.visible
			and forager._animation.current_animation == &"Work",
			"Berry harvesting stays on the skinned rig with the Work clip")
		forager.update_action("WORK_GATHER", 0.0, 0.05, true, 0.0)
		_check(forager.visible and not unit._visual_root.visible and forager._animation.current_animation == &"Work",
			"WORK_GATHER maps to the skinned Work clip without swapping")
		_check(unit._carry_type == "food" and unit._carry_amount > 0.0, "Berry work yields food")
		var stock: Dictionary = _state.factions[0]["resources"]
		var before_food := float(stock["food"])
		unit.global_position = camp.global_position + Vector3(1.5, 0, 0)
		_state.spatial_index.update_unit(unit)
		unit._day_work_routine(0.1)
		_check(float(stock["food"]) > before_food, "Gatherer deposits food at camp")
		unit._is_working_this_frame = false

		# The inspector uses the same signal as a player's role selection.
		hud.inspect_unit(unit)
		var role_option: OptionButton = hud._inspector_panel._insp_role_opt
		var warrior_index := role_option.get_item_index(_data.Role.WARRIOR)
		_check(warrior_index >= 0, "Inspector exposes the Warrior role")
		role_option.select(warrior_index)
		role_option.item_selected.emit(warrior_index)
		var guard := unit.get_node_or_null("CragBornTrial") as Trial
		if _check(unit.role == _data.Role.WARRIOR and guard != null and guard != forager,
				"Inspector switches the same colonist from Forager to Spearman"):
			_check(forager.get_parent() == null, "Role change detaches the previous kit immediately")
			_check(guard.find_child("Back", true, false) == null
				and guard.find_child("Offhand", true, false) != null, "Role change replaces basket with buckler")
			_check(_state.tutorial_assigned_role, "Role change still updates the Awakening guide")
			_check(unit.serialize()["unit_id"] == unit.unit_id, "Role change preserves the serialized unit ID")
			_check(_body_file(unit) == initial_body, "Inspector role change keeps the same adult body")
			_check(unit.has_equipped_weapon and unit.has_armor and unit.weapon_tier == 1
				and is_equal_approx(unit.max_hp, unit.base_hp_stat * 1.15 * 1.25)
				and is_equal_approx(unit.attack_range, 2.75) and is_equal_approx(unit.armor, 17.0),
				"Crag-Born Spearman equips starter stock and keeps existing HP, reach and armor formulas")
			unit.velocity = Vector3(4.3, 0, 0)
			unit._update_procedural_animation(0.10)
			_check(guard.visible and not unit._visual_root.visible and guard._animation.current_animation == &"GuardWalk",
				"The same colonist walks in the guard stance after the role change")

			var enemy: Node = _state.faction_controllers[1].spawn_colonist(
				unit.global_position + Vector3(0, 0, -2), _data.Lineage.CRAG_BORN,
				_data.Gender.FEMALE, _data.Role.FORAGER)
			enemy.set_physics_process(false)
			var prior_hp: float = enemy.hp
			unit._engage_target(enemy)
			unit._update_procedural_animation(0.12)
			_check(unit._animator.is_attacking() and guard.visible and not unit._visual_root.visible
				and guard._animation.current_animation == &"Attack",
				"SPEAR_THRUST stays on the skinned rig with the Attack clip")
			_check(is_equal_approx(prior_hp - enemy.hp, maxf(2.0, unit.attack_damage - enemy.armor * 0.45)),
				"Thrust applies normal human armor mitigation")
			enemy._update_procedural_animation(0.05)
			var enemy_trial := enemy.get_node_or_null("CragBornTrial") as Trial
			var hit_energy_v: Variant = enemy_trial._body_materials[0].get_shader_parameter("emission_energy") if enemy_trial != null else 0.0
			var hit_color_v: Variant = enemy_trial._body_materials[0].get_shader_parameter("emission_color") if enemy_trial != null else Color.BLACK
			_check(enemy_trial != null and enemy_trial.visible and not enemy._visual_root.visible
				and enemy._animator.is_taking_damage() and enemy._hit_flash_timer > 0.0
				and enemy_trial._animation.current_animation == &"Hit"
				and float(hit_energy_v) > 0.0 and hit_color_v == Color(1.0, 0.25, 0.2),
				"Hit reaction and shader flash stay on the skinned rig without procedural swap")
			enemy_trial.update_action("DAMAGE_FRONT", 0.0, 0.05, true, 0.8)
			var explicit_flash_v: Variant = enemy_trial._body_materials[0].get_shader_parameter("emission_energy")
			_check(enemy_trial.visible and not enemy._visual_root.visible
				and enemy_trial._animation.current_animation == &"Hit" and float(explicit_flash_v) > 0.0,
				"DAMAGE_FRONT with hit_flash > 0 uses skinned Hit clip and shader emission")
			for i in range(60):
				unit._update_hit_flash(1.0 / 60.0)
				unit._update_procedural_animation(1.0 / 60.0)
				enemy._update_hit_flash(1.0 / 60.0)
				enemy._update_procedural_animation(1.0 / 60.0)
			var cleared_flash_v: Variant = enemy_trial._body_materials[0].get_shader_parameter("emission_energy")
			_check(guard.visible and not unit._visual_root.visible and guard._animation.current_animation == &"GuardIdle",
				"Imported guard resumes GuardIdle after thrust")
			_check(enemy_trial != null and enemy_trial.visible and not enemy._visual_root.visible
				and is_zero_approx(float(cleared_flash_v)),
				"Skinned Forager clears shader emission when hit flash and reaction end")

			# Verify Wounded state stays on the skinned rig with the Wounded clip.
			var wounded_unit: Node = _state.faction_controllers[0].spawn_colonist(
				unit.global_position + Vector3(2, 0, 0), _data.Lineage.CRAG_BORN,
				_data.Gender.MALE, _data.Role.FORAGER)
			wounded_unit.set_physics_process(false)
			wounded_unit.is_revolting = true
			wounded_unit.original_faction_id = 0
			wounded_unit.enter_wounded_state()
			wounded_unit._update_wounded_animation(0.1)
			var wounded_trial := wounded_unit.get_node_or_null("CragBornTrial") as Trial
			_check(wounded_trial != null and wounded_trial.visible and not wounded_unit._visual_root.visible
				and wounded_trial._animation.current_animation == &"Wounded",
				"WOUNDED state stays on the skinned rig with the Wounded clip")

			# Verify Death state stays on the skinned rig and clamps cleanly at fallen pose.
			enemy._die(unit, 0, Vector3(0.0, 0.0, 1.0))
			for i in range(10):
				enemy._process_dead_corpse(0.1)
			var enemy_skel := enemy_trial.find_child("Skeleton3D", true, false) as Skeleton3D
			var enemy_hips := enemy_skel.get_bone_global_pose(enemy_skel.find_bone("Hips")).origin.y
			_check(enemy_trial.visible and not enemy._visual_root.visible
				and enemy_trial._animation.current_animation == &"Death" and enemy_hips < 0.45,
				"DEATH_BACK plays skinned Death clip, clamps fallen pose, and never swaps to procedural")

			# Exercise the Colony hotkey and its roster dropdown on the return to Forager.
			hud._inspector_panel.hide()
			var key := InputEventKey.new()
			key.keycode = KEY_C
			key.pressed = true
			root.push_input(key, true)
			var entry: Dictionary = hud._drawer_views["COLONY"]._roster_rows.get(unit.unit_id, {})
			if _check(not entry.is_empty(), "Colony drawer opened via C and populated the roster"):
				var row: Node = entry["label"].get_parent()
				var expected_tag := "unit-role:%d" % unit.unit_id
				var colony_role: OptionButton = null
				for candidate in row.find_children("*", "OptionButton", true, false):
					if str(candidate.get_meta("drawer_focus", "")) == expected_tag:
						colony_role = candidate as OptionButton
						break
				if _check(colony_role != null, "Colony roster exposes the role dropdown for unit %d" % unit.unit_id):
					var forage_index := colony_role.get_item_index(_data.Role.FORAGER)
					colony_role.select(forage_index)
					colony_role.item_selected.emit(forage_index)
					var restored := unit.get_node_or_null("CragBornTrial") as Trial
					_check(unit.role == _data.Role.FORAGER and restored != null and restored != guard
						and restored.find_child("Back", true, false) != null
						and restored.find_child("Offhand", true, false) == null,
						"Colony roster returns to Forager and clears the old offhand")
					_check(_body_file(unit) == initial_body, "Colony role change keeps the same adult body")
	_verify_body_variants(faction, base_pos + Vector3(12, 0, 6))
	main.free()
	await process_frame
	print("Campaign path checked from Awakening through role selection, harvest, thrust and hit.")


func _verify_body_variants(faction: Node, origin: Vector3) -> void:
	var saved_bodies := {}
	var body_files := {}
	var lineage: int = _data.Lineage.CRAG_BORN
	for i in range(10):
		var gender: int = _data.Gender.MALE if i % 2 == 0 else _data.Gender.FEMALE
		var unit: Node = faction.spawn_colonist(origin + Vector3((i % 5) * 2.0, 0, floorf(i / 5.0) * 2.0),
			lineage, gender, _data.Role.FORAGER, false, i >= 8)
		unit.set_physics_process(false)
		var body_file := _body_file(unit)
		if Trial.enabled():
			var variant := Trial.select_body_variant(lineage, gender, unit.is_child, unit.unit_id)
			_check(body_file == "crag_born_%s.glb" % variant, "The live roster loads %s" % variant)
			saved_bodies[unit.unit_id] = body_file
			body_files[body_file] = true
		else:
			_check(body_file.is_empty() and unit._visual_root.visible, "Roster opt-out uses a procedural body")
	if not Trial.enabled():
		return
	for variant in SIX_VARIANTS:
		_check(body_files.has("crag_born_%s.glb" % variant), "Campaign spawns %s in the six-body lineup" % variant)
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if not _check(not scratch.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"),
			"Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory"):
		return
	var path := OS.get_user_data_dir().path_join("crag-born-variants.json")
	if _check(_state.save_game(path) and _state.load_game(path), "The six-body roster saves and reloads"):
		var grown := 0
		for unit in _state.get_faction_units(0):
			if not saved_bodies.has(unit.unit_id):
				continue
			_check(_body_file(unit) == saved_bodies[unit.unit_id], "Reload keeps the body for unit %d" % unit.unit_id)
			saved_bodies.erase(unit.unit_id)
			if unit.is_child:
				var adult := Trial.select_body_variant(lineage, unit.gender, false, unit.unit_id)
				unit.growth_progress = 0.999
				unit._physics_process(0.1)
				_check(not unit.is_child and _body_file(unit) == "crag_born_%s.glb" % adult,
					"Growing up selects the stable %s adult body" % adult)
				grown += 1
		_check(saved_bodies.is_empty() and grown == 2, "All roster variants return and both children grow up")
	DirAccess.remove_absolute(path)


func _body_file(unit: Node) -> String:
	var rig: Trial = unit._skinned_trial as Trial
	return rig.get_child(0).scene_file_path.get_file() if rig != null else ""


func _review_models(out_dir: String) -> void:
	_setup_stage()
	var reference: Node3D = load(Trial.MODEL_PATH).instantiate()
	var shared_rig := reference.find_child("Skeleton3D", true, false) as Skeleton3D
	var portraits: Array[Image] = []
	var back_views: Array[Image] = []
	portraits.resize(VARIANTS.size() * KITS.size())
	back_views.resize(VARIANTS.size())
	var gallery := Image.create(SNAPSHOT.x * 3, SNAPSHOT.y * 2, false, Image.FORMAT_RGB8)
	for variant in SIX_VARIANTS:
		for kit in KITS:
			var tint: Color = _data.FACTION_COLORS[0 if kit == "SPEARMAN" else 4]
			var model := Trial.new()
			if not _check(model.setup_kit(_factory, tint, variant, kit), "%s %s imported" % [variant, kit]):
				model.free()
				continue
			_stage.add_child(model)
			await process_frame
			_verify_rig(model, tint, shared_rig)
			await _verify_motion(model, kit)
			var walking: bool = variant != "broad"
			var phase := 0.15 if walking else 0.0
			var portrait := await _capture_model(model, walking, phase, -30.0)
			if variant in VARIANTS:
				# Keep the original sheet's row order for the existing side-by-side review.
				var row: int = VARIANTS.find(variant)
				portraits[row * 2 + KITS.find(kit)] = portrait
			if kit == "FORAGER":
				portrait.convert(Image.FORMAT_RGB8)
				var i: int = SIX_VARIANTS.find(variant)
				gallery.blit_rect(portrait, Rect2i(Vector2i.ZERO, SNAPSHOT),
					Vector2i((i % 3) * SNAPSHOT.x, (1 if i >= 3 else 0) * SNAPSHOT.y))
				if variant in VARIANTS:
					back_views[VARIANTS.find(variant)] = await _capture_model(model, walking, phase, -142.0)
			model.free()
	reference.free()
	_check(gallery.save_png(out_dir.path_join("crag-born-six-variants.png")) == OK, "Save the six-body comparison PNG")
	if not portraits.has(null) and not back_views.has(null):
		await _write_sheet(portraits, back_views, out_dir.path_join("crag-born-comparison.png"))


func _verify_rig(model: Trial, tint: Color, shared_rig: Skeleton3D) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton.get_bone_count() == 17, "Body uses the shared 17-bone skeleton")
	for bone in range(shared_rig.get_bone_count()):
		var bone_name := shared_rig.get_bone_name(bone)
		_check(skeleton.find_bone(bone_name) == bone and skeleton.get_bone_parent(bone) == shared_rig.get_bone_parent(bone)
			and skeleton.get_bone_rest(bone).is_equal_approx(shared_rig.get_bone_rest(bone)),
			"%s matches the shared rig hierarchy and rest pose" % bone_name)
	var skinned_meshes := model.find_children("*", "MeshInstance3D", true, false).filter(
		func(node: MeshInstance3D) -> bool: return node.skin != null)
	if _check(skinned_meshes.size() == 1, "Body mesh has skin bind data"):
		var body_mesh := skinned_meshes[0] as MeshInstance3D
		_check(body_mesh.skin.get_bind_count() == 17 and body_mesh.get_node_or_null(body_mesh.skeleton) == skeleton,
			"All 17 skin binds resolve to the imported skeleton")
		for slot in range(body_mesh.mesh.get_surface_count()):
			var arrays := body_mesh.mesh.surface_get_arrays(slot)
			_check(not arrays[Mesh.ARRAY_BONES].is_empty() and not arrays[Mesh.ARRAY_WEIGHTS].is_empty(),
				"Each body surface has weighted vertices")
	var trim_count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for slot in range(mesh_node.mesh.get_surface_count()):
			var arrays := mesh_node.mesh.surface_get_arrays(slot)
			_check(not arrays[Mesh.ARRAY_TEX_UV].is_empty(), "%s has UVs" % mesh_node.name)
			var imported := mesh_node.mesh.surface_get_material(slot)
			if imported.resource_name == "FactionTrim":
				trim_count += 1
				var shader := mesh_node.get_surface_override_material(slot) as ShaderMaterial
				_check(shader != null and shader.get_shader_parameter("base_color") == tint
					and shader.get_shader_parameter("enable_jitter") == true, "PSX shader tints body and kit trim")
	_check(trim_count >= 3, "Body and both trim-bearing gear pieces have faction surfaces")

	for clip_name in [&"Idle", &"Walk", &"GuardIdle", &"GuardWalk", &"Work", &"Wounded"]:
		var clip := model._animation.get_animation(clip_name)
		if not _check(clip != null and clip.loop_mode == Animation.LOOP_LINEAR and clip.get_track_count() > 0,
				"%s imports as a looping, nonempty clip" % clip_name):
			continue
		model._animation.play(clip_name)
		model._animation.seek(0.0, true)
		var rest := skeleton.get_bone_pose(skeleton.find_bone("Hips"))
		model._animation.seek(clip.length * 0.25, true)
		_check(not rest.is_equal_approx(skeleton.get_bone_pose(skeleton.find_bone("Hips"))),
			"%s animates the bound skeleton" % clip_name)
		model._animation.seek(clip.length, true)
		_check(rest.is_equal_approx(skeleton.get_bone_pose(skeleton.find_bone("Hips"))),
			"%s returns to its opening pose at the loop seam" % clip_name)
	for clip_name in [&"Attack", &"Hit", &"Death"]:
		var clip := model._animation.get_animation(clip_name)
		if not _check(clip != null and clip.loop_mode == Animation.LOOP_NONE and clip.get_track_count() > 0,
				"%s imports as a one-shot, nonempty clip" % clip_name):
			continue
		model._animation.play(clip_name)
		model._animation.seek(0.0, true)
		var initial_pose: Array[Transform3D] = []
		for bone in range(skeleton.get_bone_count()):
			initial_pose.append(skeleton.get_bone_pose(bone))
		var animated := false
		for sample in [0.25, 0.50, 0.85]:
			model._animation.seek(clip.length * sample, true)
			for bone in range(skeleton.get_bone_count()):
				animated = animated or not initial_pose[bone].is_equal_approx(skeleton.get_bone_pose(bone))
		_check(animated, "%s animates the bound skeleton" % clip_name)
		if clip_name == &"Death":
			model._animation.seek(clip.length, true)
			_check(skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin.y < 0.45,
				"Death ends in a collapsed ground pose")
	model._animation.stop()


func _verify_motion(model: Trial, kit: String) -> void:
	var slots := {"Weapon": "Hand.R"}
	if kit == "SPEARMAN":
		slots["Offhand"] = "Hand.L"
	else:
		slots["Back"] = "Chest"
	var bones := model.find_child("Skeleton3D", true, false) as Skeleton3D
	model.update_locomotion(4.3, 0.0, true)
	await process_frame
	var start: Dictionary = {}
	for slot_name in slots:
		var attachment := bones.get_node(slot_name) as BoneAttachment3D
		start[slot_name] = attachment.get_child(0).global_transform
		_check(attachment.bone_name == slots[slot_name], "%s binds to %s" % [slot_name, slots[slot_name]])
	for sample in range(1, 9):
		model.update_locomotion(4.3, 0.10, true)
		await process_frame
		for slot_name in slots:
			var attachment := bones.get_node(slot_name) as BoneAttachment3D
			var bone_pose := bones.get_bone_global_pose(attachment.bone_idx)
			_check(attachment.transform.is_equal_approx(bone_pose), "%s follows its bone during Walk" % slot_name)
			if sample == 3:
				var initial: Transform3D = start[slot_name]
				_check(not initial.is_equal_approx(attachment.get_child(0).global_transform),
					"%s visibly moves through the gait" % slot_name)
		_check(_clears_ground(bones.get_node("Weapon")), "%s weapon clears the ground during Walk" % kit)


func _clears_ground(attachment: Node3D) -> bool:
	for node in attachment.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var verts: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in verts:
				if (mesh_node.global_transform * vertex).y < -0.015:
					return false
	return true


func _setup_stage() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#596052")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ded6be")
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	_stage.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, 25, 0)
	sun.light_color = Color("#fff0ce")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	_stage.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	ground.mesh = plane
	var loam := StandardMaterial3D.new()
	loam.albedo_color = Color("#414947")
	loam.roughness = 1.0
	ground.material_override = loam
	_stage.add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	_stage.add_child(_camera)
	_camera.make_current()
	var psx := CanvasLayer.new()
	_stage.add_child(psx)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var filter := ShaderMaterial.new()
	filter.shader = POST_SHADER
	rect.material = filter
	psx.add_child(rect)


func _capture_model(model: Trial, walking: bool, phase: float, yaw: float, size := SNAPSHOT) -> Image:
	model._animation.stop()
	model.update_locomotion(4.3 if walking else 0.0, 0.0, true)
	model._animation.seek(phase, true)
	var focus := Vector3(0, 1.4, 0)
	var pitch := deg_to_rad(lerpf(28.0, 64.0, ((12.0 - 5.5) / (42.0 - 5.5)) * 0.72))
	var azimuth := deg_to_rad(yaw)
	_camera.position = focus + 12.0 * Vector3(sin(azimuth) * cos(pitch), sin(pitch), -cos(azimuth) * cos(pitch))
	_camera.look_at(focus)
	await process_frame
	await RenderingServer.frame_post_draw
	var center := Vector2i(_camera.unproject_position(Vector3(0, 1.07, 0)))
	return root.get_texture().get_image().get_region(Rect2i(center - size / 2, size))


func _write_sheet(portraits: Array[Image], back_views: Array[Image], path: String) -> void:
	_stage.free()
	var layout := Control.new()
	root.add_child(layout)
	_block(layout, Vector2.ZERO, Vector2(FRAME.size), Color("#171e20"))
	_block(layout, Vector2(32, 31), Vector2(42, 3), Color("#d4a859"))
	_caption(layout, "CHRIST FALLOW  /  ASSET OVERHAUL", Vector2(87, 20), 16, Color("#d4a859"))
	_caption(layout, "Crag-Born role kits", Vector2(31, 47), 42, Color("#f4e9d6"))
	_caption(layout, "58° FOV   /   12 m   /   30° front three-quarter   /   PSX on", Vector2(35, 109), 17, Color("#b8bfb5"))
	_caption(layout, "SPEARMAN", Vector2(35, 154), 20, Color("#e6b958"))
	_caption(layout, "FORAGER", Vector2(493, 154), 20, Color("#9ad08d"))
	_caption(layout, "BACK FIT", Vector2(905, 154), 20, Color("#b8bfb5"))
	var headings := ["Broad adult", "Braided adult", "Child fit"]
	var guard_notes := ["Forked beard\nRaised buckler", "Auburn braids\nGuard walk", "Rig fit study\nGuard walk"]
	var worker_notes := ["Idle carry\nFlint sickle", "Walk pose\nFlint sickle", "Walk pose\nLight workwear"]
	for i in range(3):
		var y := 194 + 196 * i
		_block(layout, Vector2(32, y), Vector2(442, 187), Color("#242d2c"))
		_block(layout, Vector2(490, y), Vector2(398, 187), Color("#242d2c"))
		_block(layout, Vector2(904, y), Vector2(244, 187), Color("#242d2c"))
		_picture(layout, portraits[i * 2], Rect2i(16, 0, 256, 187), Vector2(32, y))
		_picture(layout, portraits[i * 2 + 1], Rect2i(16, 0, 256, 187), Vector2(490, y))
		_picture(layout, back_views[i], Rect2i(22, 0, 244, 187), Vector2(904, y))
		_caption(layout, headings[i], Vector2(298, y + 58), 24, Color("#f4e9d6"))
		_caption(layout, guard_notes[i], Vector2(299, y + 93), 17, Color("#b8bfb5"))
		_caption(layout, worker_notes[i], Vector2(755, y + 77), 17, Color("#b8bfb5"))
	_caption(layout, "Sun Gold trim  /  Moss Green trim", Vector2(35, 791), 15, Color("#b8bfb5"))
	_caption(layout, "142° rear three-quarter", Vector2(905, 791), 15, Color("#b8bfb5"))
	await process_frame
	await RenderingServer.frame_post_draw
	var sheet := root.get_texture().get_image().get_region(FRAME)
	if _check(sheet.save_png(path) == OK, "Could not write the comparison sheet"):
		print("Comparison sheet written to %s" % path)


func _block(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = size
	parent.add_child(rect)


func _caption(parent: Control, value: String, pos: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _picture(parent: Control, source: Image, crop: Rect2i, pos: Vector2) -> void:
	var picture := TextureRect.new()
	picture.texture = ImageTexture.create_from_image(source.get_region(crop))
	picture.position = pos
	parent.add_child(picture)


func _has_flash(model: Node) -> bool:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if node.material_overlay != null:
			return true
	return false


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_issues.append(message)
		push_error(message)
	return condition

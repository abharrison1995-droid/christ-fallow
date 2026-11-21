extends "res://scripts/tools/verify_crag_born.gd"
## Run in Forward+ with --out-dir=<absolute directory> or --procedural-roster.

const LINEAGE_SNAPSHOT := Vector2i(288, 224)


func _run() -> void:
	_data = root.get_node("GameData")
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if Trial.enabled():
		var qa_appdata := OS.get_environment("CHRIST_FALLOW_QA_APPDATA")
		if not _check(qa_appdata.is_absolute_path() and OS.get_environment("APPDATA") == qa_appdata,
				"Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory"):
			quit(1)
			return
	var lineages: Array[int] = [
		_data.Lineage.GOLIATH, _data.Lineage.CRAG_BORN, _data.Lineage.SWIFT_KIN,
		_data.Lineage.STALKER, _data.Lineage.ASH_WALKER, _data.Lineage.FEN_TIDAL, _data.Lineage.CAVEMAN,
	]
	await _verify_lineage_gameplay(lineages)
	if Trial.enabled() and _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Pass a writable absolute --out-dir for the lineage review"):
		await _review_lineages(lineages, out_dir)
	if _issues.is_empty():
		print("SKINNED LINEAGES VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _verify_lineage_gameplay(lineages: Array[int]) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_state.start_new_campaign("Enoch", "Fallow Chosen", _data.Lineage.GOLIATH)
	var faction: Node = _state.faction_controllers[0]
	var leader: Node3D = _state.get_faction_leader(0)
	var use_lineage_leader := Trial.enabled() and Trial.LAUNCH_FLAG not in OS.get_cmdline_user_args()
	_check((leader._skinned_trial is Trial) == use_lineage_leader, "The leader follows the requested roster mode")
	var spawn_pos := leader.global_position + Vector3(6, 0, 8)
	var saved_bodies := {}
	for lineage in lineages:
		saved_bodies.merge(_spawn_body_variants(faction, spawn_pos + Vector3(8, 0, 0), lineage))
		var guard: Node = faction.spawn_colonist(spawn_pos, lineage, _data.Gender.MALE, _data.Role.WARRIOR)
		var forager: Node = faction.spawn_colonist(spawn_pos + Vector3(2, 0, 0), lineage,
			_data.Gender.FEMALE, _data.Role.FORAGER)
		var child: Node = faction.spawn_colonist(spawn_pos + Vector3(4, 0, 0), lineage,
			_data.Gender.FEMALE, _data.Role.FORAGER, false, true)
		spawn_pos.z += 5.0
		for unit in [guard, forager, child]:
			unit.set_physics_process(false)
			_check((unit._skinned_trial is Trial) == Trial.enabled() and unit._visual_root.visible != Trial.enabled(),
				"Lineage %d chooses the expected roster at spawn" % lineage)
		if not Trial.enabled() or guard._skinned_trial == null or forager._skinned_trial == null or child._skinned_trial == null:
			continue
		var guard_rig: Trial = guard._skinned_trial
		var worker_rig: Trial = forager._skinned_trial
		var child_rig: Trial = child._skinned_trial
		_check(child_rig.scale.is_equal_approx(worker_rig.scale * Trial.CHILD_SCALE),
			"Lineage %d child has its own body and age scale" % lineage)
		guard.velocity = Vector3(4.3, 0, 0)
		guard._update_procedural_animation(0.1)
		_check_action(guard, guard_rig, &"GuardWalk")
		guard.play_attack_animation("SPEAR_THRUST", 0.5)
		guard._update_procedural_animation(0.15)
		_check_action(guard, guard_rig, &"Attack")
		forager._is_working_this_frame = true
		forager._update_procedural_animation(0.1)
		_check_action(forager, worker_rig, &"Work")
		forager.take_damage(15.0, null, 5)
		forager._update_procedural_animation(0.1)
		_check_action(forager, worker_rig, &"Hit")
		_check(float(worker_rig._body_materials[0].get_shader_parameter("emission_energy")) > 0.0,
			"Taking damage flashes the imported rig")
		forager.take_damage(forager.max_hp * 10.0, null, 5)
		forager._process_dead_corpse(1.0)
		_check_action(forager, worker_rig, &"Death")
		var alive_scale := worker_rig.scale
		forager._death_timer = 1.0
		forager._process_dead_corpse(0.25)
		_check(worker_rig.scale.is_equal_approx(alive_scale * Vector3(1.0, 0.75, 1.0)),
			"Corpse squash retains the original lineage proportions")
		child.enter_wounded_state()
		child._update_wounded_animation(0.1)
		_check(child._skinned_trial != null, "Wounding keeps the child on a skinned rig")
		if child._skinned_trial != null:
			_check_action(child, child._skinned_trial, &"Wounded")
		saved_bodies[guard.unit_id] = _body_file(guard)
	var saved_raiders := _verify_cave_captives(faction, leader, saved_bodies)
	if Trial.enabled():
		_verify_body_reload(saved_bodies, lineages.size() * 2)
		for raider in _state.get_faction_units(5):
			if saved_raiders.has(raider.unit_id):
				_check(_body_file(raider) == saved_raiders[raider.unit_id] and _wears_cave_kit(raider),
					"Reload restores the nomad's body and kit")
				saved_raiders.erase(raider.unit_id)
		_check(saved_raiders.is_empty(), "All surviving nomads were restored")
	main.free()
	await process_frame


func _check_action(unit: Node, rig: Trial, clip: StringName) -> void:
	_check(unit._skinned_trial == rig and rig.visible and not unit._visual_root.visible
		and rig._animation.current_animation == clip, "Lineage %d plays %s on the skinned body" % [unit.lineage, clip])


func _wears_cave_kit(unit: Node) -> bool:
	var rig := unit._skinned_trial as Trial
	if rig == null:
		return false
	var weapon := rig.find_child("Weapon", true, false)
	var pelt := rig.find_child("Chestwear", true, false)
	return weapon != null and weapon.get_child(0).scene_file_path.ends_with("/caveman/bone_club.glb") \
		and pelt != null and pelt.get_child(0).scene_file_path.ends_with("/caveman/trophy_pelt.glb")


func _verify_cave_captives(faction: Node, leader: Node3D, saved_bodies: Dictionary) -> Dictionary:
	_state.bandit_grace_remaining = 0.0
	_state.faction_controllers[5]._process_caveman_faction(60.0)
	var pack: Array = _state.get_faction_units(5)
	var raiders := {}
	var genders := {}
	for raider in pack:
		genders[raider.gender] = true
		_check(_wears_cave_kit(raider) == Trial.enabled(), "Nomadic spawn uses the selected roster mode")
		if Trial.enabled():
			raiders[raider.unit_id] = _body_file(raider)
	if not _check(pack.size() >= 2 and genders.size() == 2, "Both adults spawn in the nomadic pack"):
		return raiders
	var captive: Node = pack[0]
	if Trial.enabled() and captive._skinned_trial is Trial:
		captive.play_attack_animation("HEAVY_SMASH", 0.5)
		captive._update_procedural_animation(0.15)
		_check_action(captive, captive._skinned_trial, &"Attack")
	raiders.erase(captive.unit_id)
	captive._die(leader, 0)
	var player: Dictionary = _state.factions[0]
	_check(int(player["captured_cavemen"]) == 1, "Defeating a nomad records a captive")
	faction.spawn_building("CAMPFIRE", leader.global_position + Vector3(5, 0, 0))
	_state.add_resource(0, "food", 8.0)
	_state.add_resource(0, "faith", 5.0)
	var count: int = _state.get_faction_units(0).size()
	if _check(_state.combat_command_system.enlighten_captured_caveman(), "Enlighten the captive through the campaign command"):
		var units: Array = _state.get_faction_units(0)
		if _check(units.size() == count + 1, "The captive joins the settlement"):
			var recruit: Node = units.back()
			_check(not recruit.is_caveman and recruit.lineage == _data.Lineage.CAVEMAN and recruit.role == _data.Role.FORAGER,
				"The converted Forager retains Cave-Kin ancestry")
			if Trial.enabled():
				var body := _body_file(recruit)
				_check(body.begins_with("caveman_") and not _wears_cave_kit(recruit), "Converted Cave-Kin uses Forager gear")
				saved_bodies[recruit.unit_id] = body
	return raiders


func _review_lineages(lineages: Array[int], out_dir: String) -> void:
	_setup_stage()
	var reference: Node3D = load(Trial.MODEL_PATH).instantiate()
	var shared_rig := reference.find_child("Skeleton3D", true, false) as Skeleton3D
	var sheet := Image.create(LINEAGE_SNAPSHOT.x * lineages.size(), LINEAGE_SNAPSHOT.y * VARIANTS.size(),
		false, Image.FORMAT_RGB8)
	var body_sizes := {}
	for i in range(lineages.size()):
		var gallery := Image.create(LINEAGE_SNAPSHOT.x * 3, LINEAGE_SNAPSHOT.y * 2, false, Image.FORMAT_RGB8)
		for j in range(SIX_VARIANTS.size()):
			var variant: String = SIX_VARIANTS[j]
			for kit in KITS:
				var model := Trial.new()
				var tint: Color = _data.FACTION_COLORS[0 if kit == "SPEARMAN" else 4]
				if not _check(model.setup_kit(_factory, tint, variant, kit, lineages[i]),
						"Lineage %d imports %s %s" % [lineages[i], variant, kit]):
					model.free()
					continue
				_stage.add_child(model)
				await process_frame
				_verify_rig(model, tint, shared_rig)
				if lineages[i] == _data.Lineage.ASH_WALKER:
					_verify_ember_material(model)
				await _verify_motion(model, kit)
				if kit == "FORAGER" or variant == "broad":
					var portrait := await _capture_model(model, true, 0.15, -30.0, LINEAGE_SNAPSHOT)
					portrait.convert(Image.FORMAT_RGB8)
					if kit == "FORAGER":
						gallery.blit_rect(portrait, Rect2i(Vector2i.ZERO, LINEAGE_SNAPSHOT),
							Vector2i((j % 3) * LINEAGE_SNAPSHOT.x, (1 if j >= 3 else 0) * LINEAGE_SNAPSHOT.y))
					var comparison_kit := "SPEARMAN" if variant == "broad" else "FORAGER"
					if kit == comparison_kit and variant in VARIANTS:
						sheet.blit_rect(portrait, Rect2i(Vector2i.ZERO, LINEAGE_SNAPSHOT),
							Vector2i(i * LINEAGE_SNAPSHOT.x, VARIANTS.find(variant) * LINEAGE_SNAPSHOT.y))
				if variant == "broad" and kit == "SPEARMAN":
					for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
						if mesh_node.skin != null:
							body_sizes[lineages[i]] = mesh_node.get_aabb().size * model.scale
				model.free()
		var lineage_key: String = Trial.LINEAGE_KEYS[lineages[i]]
		var path := out_dir.path_join("%s-six-variants.png" % lineage_key.replace("_", "-"))
		_check(gallery.save_png(path) == OK, "Save the %s six-body comparison PNG" % lineage_key)
	var goliath: Vector3 = body_sizes.get(_data.Lineage.GOLIATH, Vector3.ZERO)
	var crag: Vector3 = body_sizes.get(_data.Lineage.CRAG_BORN, Vector3.ZERO)
	var swift: Vector3 = body_sizes.get(_data.Lineage.SWIFT_KIN, Vector3.ZERO)
	var stalker: Vector3 = body_sizes.get(_data.Lineage.STALKER, Vector3.ZERO)
	_check(goliath.y > crag.y * 1.3 and swift.y > 0.0 and swift.y < crag.y * 0.85
		and goliath.x > crag.x and swift.x < crag.x,
		"Goliath and Swift-Kin bracket Crag-Born in rendered height and width")
	_check(stalker.y > crag.y and stalker.x < crag.x, "Stalkers retain a tall, narrow silhouette")
	_check(sheet.save_png(out_dir.path_join("skinned-lineages.png")) == OK, "Save the lineage comparison PNG")
	var nomad := Trial.new()
	if _check(nomad.setup_kit(_factory, _data.FACTION_COLORS[5], "broad", "CAVEMAN", _data.Lineage.CAVEMAN),
			"Cave-Kin club and pelt fit the shared skeleton"):
		_stage.add_child(nomad)
		var portrait := await _capture_model(nomad, true, 0.15, -30.0, LINEAGE_SNAPSHOT)
		_check(portrait.save_png(out_dir.path_join("cave-kin-kit.png")) == OK, "Save a nomad kit preview")
	nomad.free()
	reference.free()


func _verify_ember_material(model: Trial) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for slot in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.mesh.surface_get_material(slot)
			if source.resource_name == "Mat_EmberSkinPaint":
				var shader := mesh_node.get_surface_override_material(slot) as ShaderMaterial
				_check(shader != null and float(shader.get_shader_parameter("emission_energy")) > 0.0,
					"Ash-Walker ember marks glow through the gameplay shader")
				return
	_check(false, "Ash-Walker body has its imported ember marks")

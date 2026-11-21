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
	var lineages: Array[int] = [_data.Lineage.GOLIATH, _data.Lineage.CRAG_BORN, _data.Lineage.SWIFT_KIN]
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
	_check(not (leader._skinned_trial is Trial), "The roster leaves the player leader on its own visual path")
	var spawn_pos := leader.global_position + Vector3(6, 0, 8)
	var saved_ids: Array[int] = []
	for lineage in lineages:
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
		saved_ids.append(guard.unit_id)
	if Trial.enabled():
		var path := OS.get_user_data_dir().path_join("skinned-lineage-check.json")
		if _check(_state.save_game(path) and _state.load_game(path), "Save and reload preserves the lineage roster"):
			for unit in _state.get_faction_units(0):
				if saved_ids.has(unit.unit_id):
					_check(unit._skinned_trial is Trial and not unit._visual_root.visible,
						"Reload reconstructs the skinned Spearman %d" % unit.unit_id)
					saved_ids.erase(unit.unit_id)
			_check(saved_ids.is_empty(), "Every saved Spearman still exists after reload")
		DirAccess.remove_absolute(path)
	main.free()
	await process_frame


func _check_action(unit: Node, rig: Trial, clip: StringName) -> void:
	_check(unit._skinned_trial == rig and rig.visible and not unit._visual_root.visible
		and rig._animation.current_animation == clip, "Lineage %d plays %s on the skinned body" % [unit.lineage, clip])


func _review_lineages(lineages: Array[int], out_dir: String) -> void:
	_setup_stage()
	var reference: Node3D = load(Trial.MODEL_PATH).instantiate()
	var shared_rig := reference.find_child("Skeleton3D", true, false) as Skeleton3D
	var sheet := Image.create(LINEAGE_SNAPSHOT.x * lineages.size(), LINEAGE_SNAPSHOT.y * VARIANTS.size(),
		false, Image.FORMAT_RGB8)
	var body_sizes: Array[Vector3] = []
	for i in range(lineages.size()):
		for j in range(VARIANTS.size()):
			var variant: String = VARIANTS[j]
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
				await _verify_motion(model, kit)
				if (kit == "SPEARMAN" and variant == "broad") or (kit == "FORAGER" and variant != "broad"):
					var portrait := await _capture_model(model, true, 0.15, -30.0, LINEAGE_SNAPSHOT)
					portrait.convert(Image.FORMAT_RGB8)
					sheet.blit_rect(portrait, Rect2i(Vector2i.ZERO, LINEAGE_SNAPSHOT),
						Vector2i(i * LINEAGE_SNAPSHOT.x, j * LINEAGE_SNAPSHOT.y))
				if variant == "broad" and kit == "SPEARMAN":
					for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
						if mesh_node.skin != null:
							body_sizes.append(mesh_node.get_aabb().size * model.scale)
				model.free()
	_check(body_sizes.size() == 3 and body_sizes[0].y > body_sizes[1].y * 1.3
		and body_sizes[2].y < body_sizes[1].y * 0.85
		and body_sizes[0].x > body_sizes[1].x and body_sizes[2].x < body_sizes[1].x,
		"Goliath and Swift-Kin bracket Crag-Born in rendered height and width")
	_check(sheet.save_png(out_dir.path_join("skinned-lineages.png")) == OK, "Save the lineage comparison PNG")
	reference.free()

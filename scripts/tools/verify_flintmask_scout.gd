extends "res://scripts/tools/verify_crag_born.gd"

const Save = preload("res://scripts/core/campaign_save.gd")


func _run() -> void:
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if not _check(not scratch.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"),
			"Set isolated APPDATA and CHRIST_FALLOW_QA_APPDATA"):
		quit(1)
		return
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_state.start_new_campaign("Ena", "Scout Review", GameData.Lineage.CRAG_BORN)
	_state.bandit_grace_remaining = 0.0
	_state.faction_controllers[5]._process_caveman_faction(60.0)
	var scouts := _scouts()
	if _check(scouts.size() == 1, "Nomadic cave pack contains one Flintmask Scout"):
		_verify_scout(scouts.front())
	main.free()
	await process_frame
	if Trial.enabled() and _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Set the Scout capture output"):
		await _capture_scout(out_dir)
	if _issues.is_empty():
		print("FLINTMASK SCOUT VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _scouts() -> Array:
	return _state.get_faction_units(5).filter(func(unit: Node) -> bool: return unit.archetype == GameData.FLINTMASK_SCOUT)


func _verify_scout(scout: Node) -> void:
	var leader: Node = _state.get_faction_leader(0)
	var rig := scout._skinned_trial as Trial
	_check((rig != null) == Trial.enabled(), "Scout follows the roster mode")
	_check(is_equal_approx(scout.max_hp, 100.0) and is_equal_approx(scout.move_speed, 7.4)
		and is_equal_approx(scout.attack_cooldown_max, 0.85), "Scout uses its authored skirmisher stats")
	if rig != null:
		_check(_body_file(scout) == "flintmask_scout.glb" and rig.find_child("Weapon", true, false) != null,
			"Scout mounts the hooked club on its dedicated body")
	var before: float = leader.hp
	scout.global_position = leader.global_position + Vector3(0, 0, 1.5)
	_state.spatial_index.update_unit(scout)
	scout._process_feral_caveman(0.1)
	_check(is_equal_approx(before - leader.hp, maxf(2.0, 13.0 - leader.armor * 0.45)), "Scout attack applies normal contact damage")
	if rig != null:
		scout._update_procedural_animation(0.17)
		_check(rig._animation.current_animation == &"Attack", "Scout plays the skinned club attack")
		scout._swing_timer = 0.0
		scout.take_damage(3.0, leader, 0)
		scout._update_procedural_animation(0.06)
		_check(rig._animation.current_animation == &"Hit", "Scout plays the skinned hit reaction")
	var id: int = scout.unit_id
	var path := OS.get_user_data_dir().path_join("flintmask-scout.json")
	if _check(_state.save_game(path), "Save the live Scout"):
		var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for data in invalid["units"]:
			if int(data["unit_id"]) == id:
				data["archetype"] = "UNKNOWN_ARCHETYPE"
		_check(Save.unpack(invalid).is_empty(), "Reject unknown archetype data")
		if _check(_state.load_game(path) and _scouts().size() == 1, "Restore Scout from the campaign save"):
			var restored: Node = _scouts().front()
			_check(restored.unit_id == id and is_equal_approx(restored.move_speed, 7.4), "Reload preserves Scout identity and stats")
			restored._die(_state.get_faction_leader(0), 0)
			restored._process_dead_corpse(0.3)
			if Trial.enabled():
				var dead_rig := restored._skinned_trial as Trial
				_check(dead_rig != null and dead_rig._animation.current_animation == &"Death", "Scout plays the skinned death clip")
	DirAccess.remove_absolute(path)


func _capture_scout(out_dir: String) -> void:
	_setup_stage()
	var model := Trial.new()
	if _check(model.setup_kit(_factory, GameData.FACTION_COLORS[5], "broad", GameData.FLINTMASK_SCOUT, GameData.Lineage.CAVEMAN),
			"Import the Scout for preview"):
		_stage.add_child(model)
		var shot := await _capture_model(model, false, 0.0, -25.0)
		_check(shot.save_png(out_dir.path_join("flintmask-scout.png")) == OK, "Capture the Scout preview")
	model.free()

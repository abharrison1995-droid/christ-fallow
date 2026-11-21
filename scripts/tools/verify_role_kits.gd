extends "res://scripts/tools/verify_crag_born.gd"
## Review mounted gear and the clips used by live role actions.


func _run() -> void:
	_data = root.get_node("GameData")
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	await _verify_live_kits()
	if Trial.enabled() and _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Pass a writable absolute directory for gear captures"):
		await _capture_kits(out_dir, Trial.COMBAT_CLIPS.keys(), "combat-kits.png")
	if _issues.is_empty():
		print("ROLE KIT VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _verify_live_kits() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_state.start_new_campaign("Ena", "Kit Review", _data.Lineage.CRAG_BORN)
	var faction: Node = _state.faction_controllers[0]
	var leader: Node3D = _state.get_faction_leader(0)
	var origin := leader.global_position + Vector3(9, 0, 8)
	for warrior_class in [_data.WarriorClass.KNIFE_RAIDER, _data.WarriorClass.ARCHER,
			_data.WarriorClass.BRUTE, _data.WarriorClass.JAVELINEER]:
		var unit: Node = faction.spawn_colonist(origin, _data.Lineage.CRAG_BORN, _data.Gender.FEMALE, _data.Role.FORAGER)
		unit.set_physics_process(false)
		var body := _body_file(unit)
		_check(_state.assign_player_role(unit, _data.Role.WARRIOR, warrior_class), "Select Warrior class through GameState")
		var class_key: String = unit._get_class_key()
		var rig := unit._skinned_trial as Trial
		if not Trial.enabled():
			_check(rig == null and unit._visual_root.visible, "%s respects procedural roster" % class_key)
			continue
		if not _check(rig != null and _body_file(unit) == body, "%s keeps the assigned lineage body" % class_key):
			continue
		_verify_mounts(rig, class_key)
		unit.weapon_tier = 3
		unit.has_armor = true
		unit._refresh_gear_visual()
		_check(rig._armor.visible and not rig._tier_surfaces.is_empty(), "%s shows equipped armor and edged surfaces" % class_key)
		for surface in rig._tier_surfaces:
			_check(surface.get_shader_parameter("base_color") != surface.get_meta("base_tint"), "%s updates its tier finish" % class_key)
		var ranged := class_key in ["ARCHER", "JAVELINEER"]
		var reach := 7.0 if ranged else 1.4
		var target: Node = _state.faction_controllers[1].spawn_colonist(origin + Vector3(0, 0, -reach),
			_data.Lineage.CRAG_BORN, _data.Gender.MALE, _data.Role.FORAGER)
		target.set_physics_process(false)
		var hp: float = target.hp
		var projectiles: int = _state.projectiles_container.get_child_count()
		unit._engage_target(target)
		unit._update_procedural_animation(0.1)
		var clip := StringName("combat/" + String(Trial.COMBAT_CLIPS[class_key]))
		_check(rig._animation.current_animation == clip, "%s plays its own live attack" % class_key)
		_check(_state.projectiles_container.get_child_count() > projectiles if ranged else target.hp < hp,
			"%s launches or hits at action start" % class_key)
		var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
		var index := skeleton.find_bone("UpperArm.R")
		var pose := skeleton.get_bone_pose_rotation(index)
		rig._animation.seek(0.32, true)
		_check(not skeleton.get_bone_pose_rotation(index).is_equal_approx(pose), "%s clip binds and moves the arm" % class_key)
		origin.x += 4.0
	main.free()
	await process_frame


func _verify_mounts(rig: Trial, class_key: String) -> void:
	var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for item in Trial.KIT_ITEMS[class_key]:
		var attachment := skeleton.get_node_or_null(item[1]) as BoneAttachment3D
		_check(attachment != null and attachment.bone_name == item[0]
			and attachment.get_child(0).scene_file_path.ends_with(String(item[2]) + ".glb"),
			"%s mounts %s on %s" % [class_key, item[2], item[0]])


func _capture_kits(out_dir: String, class_keys: Array, filename: String) -> void:
	_setup_stage()
	var sheet := Image.create(SNAPSHOT.x * mini(class_keys.size(), 4), SNAPSHOT.y * ceili(class_keys.size() / 4.0), false, Image.FORMAT_RGB8)
	for i in range(class_keys.size()):
		var model := Trial.new()
		var tint: Color = _data.FACTION_COLORS[0]
		if _check(model.setup_kit(_factory, tint, "broad", class_keys[i]), "Preview %s" % class_keys[i]):
			_stage.add_child(model)
			model.sync_equipment(2, true)
			var portrait := await _capture_model(model, false, 0.0, -37.0)
			portrait.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(portrait, Rect2i(Vector2i.ZERO, SNAPSHOT), Vector2i((i % 4) * SNAPSHOT.x, floori(i / 4.0) * SNAPSHOT.y))
		model.free()
	_check(sheet.save_png(out_dir.path_join(filename)) == OK, "Write the kit comparison sheet")
	_stage.free()

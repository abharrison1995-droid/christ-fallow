extends "res://scripts/tools/verify_crag_born.gd"

const Gate = preload("res://scripts/core/standing_stone_gate.gd")
const OPEN_SITE := Vector3(95.3, 0.0, 42.7)


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
	_state.start_new_campaign("Ena", "Gate Review", GameData.Lineage.CRAG_BORN)
	_state.add_resource(0, "stone", 30.0)
	_state.add_resource(0, "wood", 30.0)
	var player: Node = _state.player_controller
	player.enter_build_mode(Gate.TYPE)
	var ghost: Node3D = player._blueprint_ghost
	_check(ghost.get_node_or_null("Stage_Intact") != null, "Gate placement uses the imported intact stage")
	ghost.global_position = OPEN_SITE
	player._try_place_blueprint()
	var gates: Array = _state.get_faction_buildings(0, Gate.TYPE)
	if _check(gates.size() == 1, "Gate is available in normal blueprint placement"):
		var gate: Node = gates.front()
		_check(not gate.is_constructed, "Gate begins as a blueprint")
		gate.advance_construction(gate.build_time + 0.01)
		await _check_rotations(gate)
		await _walk_unit_through_gate(gate)
		await _check_damage_and_restore(gate)
	main.free()
	await process_frame
	if _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK, "Set the gate review output"):
		await _capture_gate(out_dir)
	if _issues.is_empty():
		print("STANDING STONE GATE VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _check_rotations(gate: Node) -> void:
	var leader: CharacterBody3D = _state.get_faction_leader(0)
	for turn in range(8):
		gate.rotation.y = deg_to_rad(45.0 * turn)
		await physics_frame
		await physics_frame
		var start: Vector3 = gate.to_global(Vector3(0, 0, -4))
		var end: Vector3 = gate.to_global(Vector3(0, 0, 4))
		var probe := Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.04)
		_check(not leader.test_move(probe, end - start), "Leader capsule passes the opening at %d degrees" % (turn * 45))
		_check(_state.valley_nav.find_path(start, end).size() == 1, "AI can route directly through the rotated opening")
		for side in [-1.0, 1.0]:
			var lateral: Vector3 = gate.global_basis.x * (side * Gate.PIER_OFFSET)
			probe.origin = start + lateral + Vector3.UP * 0.04
			_check(leader.test_move(probe, end - start), "The pier blocks actual movement")
			var path: PackedVector3Array = _state.valley_nav.find_path(start + lateral, end + lateral)
			var previous := start + lateral
			_check(path.size() > 1, "AI detours around the pier")
			for waypoint in path:
				_check(_state.valley_nav.has_gate_clearance(previous, waypoint), "Detour segment clears both piers")
				previous = waypoint


func _walk_unit_through_gate(gate: Node) -> void:
	var start: Vector3 = gate.to_global(Vector3(0, 0.04, -4))
	var end: Vector3 = gate.to_global(Vector3(0, 0.04, 4))
	var unit: CharacterBody3D = _state.faction_controllers[0].spawn_colonist(start, GameData.Lineage.CRAG_BORN,
		GameData.Gender.MALE, GameData.Role.FORAGER)
	unit.set_physics_process(false)
	await physics_frame
	for step in range(35):
		unit._steer_toward(end, 3.5)
		unit.move_and_collide(unit.velocity * 0.1)
	_check(unit.global_position.distance_to(end) < 0.4, "A live colonist walks all the way through")
	_state.spatial_index.update_unit(unit)


func _check_damage_and_restore(gate: Node) -> void:
	gate.take_damage(gate.max_hp * 0.39, 5)
	_check(gate.damage_stage == 1, "Damage changes to the fractured lintel")
	gate.take_damage(gate.max_hp * 0.36, 5)
	_check(gate.damage_stage == 2, "Critical damage removes the lintel")
	var save_path := OS.get_user_data_dir().path_join("gate-review.json")
	if not _check(_state.save_game(save_path) and _state.load_game(save_path), "Save and reload the critical gate"):
		return
	DirAccess.remove_absolute(save_path)
	var restored: Node = _state.get_faction_buildings(0, Gate.TYPE).front()
	_check(restored.damage_stage == 2 and is_equal_approx(wrapf(restored.rotation.y, -PI, PI), deg_to_rad(-45.0)),
		"Reload restores damage and orientation")
	var a: Vector3 = restored.to_global(Vector3(Gate.PIER_OFFSET, 0, -4))
	var b: Vector3 = restored.to_global(Vector3(Gate.PIER_OFFSET, 0, 4))
	_check(not _state.valley_nav.has_gate_clearance(a, b), "Reload registers both pier obstacles")
	restored.take_damage(restored.max_hp, 5)
	await physics_frame
	await physics_frame
	_check(restored.damage_stage == 3 and restored._col_shape.disabled and restored._other_pier.disabled,
		"Rubble disables both physical piers")
	_check(_state.valley_nav.has_gate_clearance(a, b), "Rubble opens the AI route")


func _capture_gate(out_dir: String) -> void:
	_setup_stage()
	var sheet := Image.create(1200, 210, false, Image.FORMAT_RGB8)
	for i in range(4):
		var visual: Node3D = _factory.build_building_mesh(Gate.TYPE, Color(0.84, 0.61, 0.28), false, i)
		_stage.add_child(visual)
		_camera.position = Vector3(7.0, 7.5, 12.4)
		_camera.look_at(Vector3(0, 1.1, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		var center := Vector2i(_camera.unproject_position(Vector3(0, 1.1, 0)))
		var shot := root.get_texture().get_image().get_region(Rect2i(center - Vector2i(150, 105), Vector2i(300, 210)))
		shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot, Rect2i(0, 0, 300, 210), Vector2i(i * 300, 0))
		visual.free()
	_check(sheet.save_png(out_dir.path_join("standing-stone-gate.png")) == OK, "Capture all four gate stages")

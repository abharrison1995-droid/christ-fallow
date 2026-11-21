extends "res://scripts/tools/verify_crag_born.gd"

const Layout = preload("res://scripts/core/world_layout.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")
const GROUPS := {"woodland": ["DEER", "WOLF"], "megafauna": ["MAMMOTH", "CAVE_BEAR"]}
const SITE := Vector3(93, 0, 92)
const CELL := Vector2i(324, 252)


func _run() -> void:
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	var group := ""
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--batch="):
			group = arg.trim_prefix("--batch=")
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if not _check(GROUPS.has(group) and out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK
			and not scratch.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"),
			"Set a valid --batch, writable --out-dir, and isolated saves"):
		quit(1)
		return
	var kinds: Array = GROUPS[group]
	for layout in [Layout.CLASSIC_ID, Layout.EXPANDED_ID]:
		await _verify_layout(layout, kinds, group)
	await _capture_species(kinds, out_dir.path_join("%s-wildlife.png" % group))
	if _issues.is_empty():
		print("WILDLIFE LINEUP VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _verify_layout(layout: String, kinds: Array, group: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_state.start_new_campaign("Ena", "Wildlife Review", GameData.Lineage.CRAG_BORN, layout)
	for kind in kinds:
		var entity := _find_animal(kind)
		_check(entity != null and entity._bite_player != null, "%s uses its imported rig in %s" % [kind, layout])
	if group == "woodland":
		await _verify_deer()
		_verify_predator("WOLF", SITE + Vector3(24, 0, 0))
	else:
		_verify_predator("MAMMOTH", SITE)
		_verify_predator("CAVE_BEAR", SITE + Vector3(24, 0, 0))
	var path := OS.get_user_data_dir().path_join("wildlife-%s.json" % layout)
	if _check(_state.save_game(path) and _state.load_game(path), "Reload wildlife in %s" % layout):
		for kind in kinds:
			var restored := _find_animal(kind)
			_check(restored != null and restored._bite_player != null, "%s restores the imported rig" % kind)
		if group == "woodland":
			var owned_deer := _find_animal("DEER", true)
			_check(owned_deer != null and owned_deer.pen_position != null, "Deer restores ownership and pen assignment")
	DirAccess.remove_absolute(path)
	main.free()
	await process_frame


func _find_animal(kind: String, owned: bool = false) -> Node:
	for animal in _state.wildlife_container.get_children():
		if animal.animal_type == kind and not animal.is_dead and (not owned or animal.owner_faction == 0):
			return animal
	return null


func _verify_deer() -> void:
	var leader: Node = _state.get_faction_leader(0)
	var pen: Node = _state.faction_controllers[0].spawn_building("ANIMAL_PEN", SITE)
	var start := SITE + Vector3(5, 0, 0)
	leader.global_position = start + Vector3(1.5, 0, 0)
	_state.spatial_index.update_unit(leader)
	var deer: Node = _state.world_node._spawn_animal("DEER", start)
	deer.take_damage(1.0, leader, 0)
	_check(deer._flee_timer > 0.0, "Wild deer flees when hit")
	deer._physics_process(0.05)
	deer._update_wildlife_animation(0.05)
	_check(deer._bite_player.current_animation == &"Run", "Deer uses its run clip when fleeing")
	_state.add_resource(0, "food", 20.0)
	for sample in range(100):
		seed(sample)
		if randf() < float(Farming.TAME_CHANCES["DEER"]):
			seed(sample)
			break
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.pressed = true
	root.push_input(interact, true)
	_check(deer.owner_faction == 0 and deer.pen_position == pen.global_position, "E tames the imported deer")
	for frame in range(180):
		if deer.global_position.distance_to(pen.global_position) < Farming.PEN_RADIUS:
			break
		await physics_frame
	_check(deer.global_position.distance_to(pen.global_position) < Farming.PEN_RADIUS, "Tamed deer walks into its pen")
	var fawn: Node = _state.world_node._spawn_animal("DEER", SITE + Vector3(0, 0, 1.0))
	fawn.domesticate(0, SITE, 45.0)
	_check(fawn._visual_root.scale.x < deer._visual_root.scale.x, "Fawn scales down the same rig")


func _verify_predator(kind: String, position: Vector3) -> void:
	var leader: Node = _state.get_faction_leader(0)
	var animal: Node = _state.world_node._spawn_animal(kind, position)
	var boss: bool = animal.is_boss
	if kind == "MAMMOTH":
		_check(not animal.is_aggro and animal._target_unit == null, "Mammoth starts neutral")
	else:
		leader.global_position = position + Vector3(0, 0, 6.0)
		_state.spatial_index.update_unit(leader)
		animal._physics_process(0.016)
		_check(animal._target_unit == leader and animal.velocity.z > 0.0, "%s pursues nearby prey" % kind)
	leader.global_position = position + Vector3(0, 0, 1.65)
	_state.spatial_index.update_unit(leader)
	var after_hit: float = animal.hp
	var center: Vector3 = animal.projectile_hit_center()
	var projectile := load("res://scripts/entities/projectile_3d.gd")
	var shot: Node3D = projectile.spawn(leader, 0, center - Vector3.RIGHT * 1.6, center + Vector3.RIGHT * 1.6, 7.0)
	shot.gravity = 0.0
	shot.velocity = Vector3.RIGHT * 32.0
	shot._physics_process(0.1)
	_check(animal.hp < after_hit and animal._target_unit == leader, "%s takes a torso hit and retaliates" % kind)
	var outside: Node = _state.faction_controllers[0].spawn_colonist(position + Vector3(4.7, 0, 0),
		GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER)
	var outside_hp: float = outside.hp
	var player_hp: float = leader.hp
	animal._physics_process(0.016)
	_check(leader.hp < player_hp and animal._attack_cd > 0.0, "%s attack lands and starts its cooldown" % kind)
	_check(animal._bite_player.current_animation == animal._attack_clip, "%s plays its authored attack" % kind)
	_check(outside.hp == outside_hp, "Attack leaves the distant unit outside its range")
	_check(not boss or animal._hp_bg.visible, "%s retains its boss HUD state" % kind)
	var stock: Dictionary = _state.factions[0]["resources"]
	var food: float = stock["food"]
	animal.take_damage(animal.hp + 1.0, null, 0)
	var expected: float = GameData.WILDLIFE_DATA[kind]["yield"]["food"]
	_check(is_equal_approx(float(stock["food"]) - food, expected), "%s grants its existing hunting yield" % kind)


func _capture_species(kinds: Array, path: String) -> void:
	_setup_stage()
	var sheet := Image.create(CELL.x * 2, CELL.y * kinds.size(), false, Image.FORMAT_RGB8)
	_camera.position = Vector3(6.3, 6.4, -11.9)
	_camera.look_at(Vector3(0, 1.2, 0))
	for row in range(kinds.size()):
		var kind: String = kinds[row]
		var model: Node3D = _factory.build_wildlife_mesh(kind)
		_stage.add_child(model)
		var player := model.find_child("BiteAnimation", true, false) as AnimationPlayer
		if _check(player != null and player.has_animation(&"Idle") and player.has_animation(&"Walk"), "%s has authored locomotion" % kind):
			var action: StringName = GameData.WILDLIFE_DATA[kind].get("attack_clip", &"Bite")
			for column in range(2):
				var clip := &"Idle" if column == 0 else action if player.has_animation(action) else &"Run"
				player.play(clip)
				player.seek(0.10, true)
				player.pause()
				await process_frame
				await RenderingServer.frame_post_draw
				var center := Vector2i(_camera.unproject_position(Vector3(0, 1.2, 0)))
				var shot := root.get_texture().get_image().get_region(Rect2i(center - CELL / 2, CELL))
				shot.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
		model.free()
	_check(sheet.save_png(path) == OK, "Save wildlife review sheet")

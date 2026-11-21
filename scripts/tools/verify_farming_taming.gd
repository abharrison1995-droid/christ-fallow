extends SceneTree
## Verifies building entry points, crop work, wildlife ownership, husbandry, riding and persistence.

const Farming = preload("res://scripts/core/farming_rules.gd")

var _state: Node
var _failures := 0
var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return
	_state = root.get_node("GameState")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out_dir = argument.trim_prefix("--out-dir=")
	if not _out_dir.is_empty() and not _check(_out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(_out_dir) == OK,
			"Pass a writable capture directory"):
		quit(1)
		return
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(17394)
	_state.start_new_campaign("Enoch", "Farm Probe", GameData.Lineage.CRAG_BORN)
	var origin := Vector3(82, 0, 72)
	var stock: Dictionary = _state.factions[0]["resources"]
	for resource in ["food", "wood", "stone"]:
		stock[resource] = 180.0
	var faction: Node = _state.faction_controllers[0]
	var camp: Node = faction.spawn_building("CAMPFIRE", origin - Vector3(14, 0, 0))
	_state.factions[0]["is_founded"] = true
	_state.factions[0]["camp_position"] = camp.global_position
	var field := _build("CROP_FIELD", origin)
	var pen := _build("ANIMAL_PEN", origin + Vector3(14, 0, 0))
	if field != null and pen != null:
		var worker: Node = faction.spawn_colonist(origin + Vector3(1, 0, 0), GameData.Lineage.CRAG_BORN,
			GameData.Gender.FEMALE, GameData.Role.FORAGER)
		_check(_state.assign_player_role(worker, GameData.Role.FARMER), "Colony role assignment makes a Farmer")
		worker.set_physics_process(false)
		_sow_and_tend(field, worker)
		await _verify_taming_and_breeding(pen)
		await _verify_mount_and_reload(field, pen, worker.unit_id, "user://farm-probe-%d.json" % Time.get_ticks_usec())
	_state.end_campaign()
	root.remove_child(main)
	main.queue_free()
	await process_frame
	if _failures == 0:
		print("FARMING AND TAMING VERIFICATION PASSED")
	quit(0 if _failures == 0 else 1)


func _build(kind: String, point: Vector3) -> Node:
	var player: Node = _state.player_controller
	var stat: Dictionary = GameData.BUILDINGS[kind]
	var stock: Dictionary = _state.factions[0]["resources"]
	var wood: float = stock["wood"]
	player.enter_build_mode(kind)
	player._blueprint_ghost.global_position = point
	player._try_place_blueprint()
	var buildings: Array = _state.get_faction_buildings(0, kind)
	if not _check(buildings.size() == 1, "%s is available to place through Build" % kind):
		return null
	var building: Node = buildings[0]
	_check(not building.is_constructed and is_equal_approx(float(stock["wood"]), wood - float(stat["costs"]["wood"])),
		"%s placement consumes its advertised cost and creates a blueprint" % kind)
	building.advance_construction(building.build_time + 0.1)
	var nav: RefCounted = _state.valley_nav
	_check(building.is_constructed and building._col_shape.disabled and not nav.is_cell_blocked(nav.world_to_cell(point)),
		"%s completes and remains walkable" % kind)
	return building


func _sow_and_tend(field: Node, worker: Node) -> void:
	worker._day_work_routine(2.1)
	_check(field.crop_stage == Farming.CropStage.GROWING and worker._carry_amount == 0.0, "Farmer sows an empty field")
	field._physics_process(18.0)
	worker._day_work_routine(1.6)
	_check(field.crop_tended and field.crop_progress > 18.0, "Tending speeds crop growth")
	_check(field._get_active_stage_node().get_node("Crops").visible, "A growing field shows its crop rows")
	var growth: float = field.crop_progress
	_state.set_manual_pause(true)
	field._physics_process(Farming.CROP_GROW_TIME)
	_check(is_equal_approx(float(field.crop_progress), growth), "Crop timers freeze while the campaign is paused")
	_state.set_manual_pause(false)


func _verify_taming_and_breeding(pen: Node) -> void:
	var leader: Node = _state.get_faction_leader(0)
	var center: Vector3 = pen.global_position
	var first: Node = _state.world_node._spawn_animal("BOAR", center + Vector3(-8.0, 0, 0))
	var second: Node = _state.world_node._spawn_animal("BOAR", center + Vector3(1.4, 0, 0))
	for animal in [first, second]:
		_teleport(leader, animal.global_position + Vector3(0, 0, 1.4))
		_choose_taming_roll(true)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_check(animal.owner_faction == 0 and animal.pen_position == center, "E tames a wild boar and assigns a pen")
	var rejected: Node = _state.world_node._spawn_animal("BOAR", center + Vector3(10, 0, 0))
	_teleport(leader, rejected.global_position + Vector3(0, 0, 2.4))
	_choose_taming_roll(false)
	_key(KEY_E, true)
	_key(KEY_E, false)
	_check(rejected.owner_faction == -1 and rejected._target_unit == leader and rejected._tame_cooldown > 0.0,
		"A failed attempt provokes a wild boar")
	_teleport(leader, center + Vector3(8, 0, 6))
	for frame in range(180):
		if first.global_position.distance_to(center) <= Farming.PEN_RADIUS:
			break
		await physics_frame
	_check(first.global_position.distance_to(center) <= Farming.PEN_RADIUS, "Tamed livestock walks into its pen")
	var stock: Dictionary = _state.factions[0]["resources"]
	var food: float = stock["food"]
	stock["food"] = 0.0
	pen._physics_process(Farming.PEN_INTERVAL)
	_check(pen.get_herd().size() == 2 and first.training_feeds == 0, "An unfed herd neither breeds nor trains")
	stock["food"] = food
	pen._physics_process(Farming.PEN_INTERVAL)
	_check(pen.get_herd().size() == 3 and pen.get_herd()[2].maturity_remaining > 0.0,
		"Two fed adults produce a juvenile")
	pen._physics_process(Farming.PEN_INTERVAL)
	_check(pen.get_herd().size() == 4 and first.training_feeds == Farming.MOUNT_TRAINING and second.can_mount(0),
		"Feeding trains adult boars as mounts and preserves the herd")
	var hp: float = first.hp
	first.take_damage(20.0, leader, 0)
	_check(is_equal_approx(first.hp, hp), "Owned livestock is protected from friendly attacks")


func _verify_mount_and_reload(field: Node, pen: Node, worker_id: int, path: String) -> void:
	var leader: Node = _state.get_faction_leader(0)
	var player: Node = _state.player_controller
	var herd: Array = pen.get_herd()
	if not _check(not herd.is_empty(), "A herd is available for mount verification"):
		return
	_teleport(leader, herd[0].global_position + Vector3(0, 0, 3))
	_key(KEY_E, true)
	_key(KEY_E, false)
	if not _check(player.is_mounted() and leader._mounted and leader._rider_lift > 0.0,
		"E mounts a trained adult with an elevated rider pose"):
		return
	var mounted: Node = player._mounted_animal
	var begin: Vector3 = leader.global_position
	_key(KEY_W, true)
	for frame in range(8):
		await physics_frame
	_key(KEY_W, false)
	_check(leader.global_position.distance_to(begin) > 0.1 and leader.global_position.distance_to(mounted.global_position) < 0.1,
		"Mounted movement drives the leader and boar together")
	_check(player.camera_pivot.global_position.y > leader.global_position.y + 1.45, "The camera frames the mounted rider")
	if not _out_dir.is_empty():
		player.cam_yaw += 68.0
		for frame in range(22):
			await physics_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out_dir.path_join("mounted-leader.png")) == OK, "Write the mounted review")
	var saved_growth: float = field.crop_progress
	var growth_tended: bool = field.crop_tended
	var pen_pos: Vector3 = pen.global_position
	var lead_id: int = leader.unit_id
	_check(_state.save_game(path), "Write a growing field, herd and rider to a real save")
	var original := FileAccess.get_file_as_string(path)
	var invalid: Dictionary = JSON.parse_string(original)
	for animal in invalid["wildlife"]:
		if int(animal.get("rider_unit_id", 0)) > 0:
			animal["rider_unit_id"] = lead_id + 9999
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	_check(not _state.load_game(path) and player.is_mounted(), "An invalid rider reference leaves the live campaign intact")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	_check(_state.load_game(path), "Reload a mounted campaign")
	field = _state.get_faction_buildings(0, "CROP_FIELD", true)[0]
	pen = _state.get_faction_buildings(0, "ANIMAL_PEN", true)[0]
	leader = _state.get_faction_leader(0)
	_check(field.crop_stage == Farming.CropStage.GROWING and is_equal_approx(field.crop_progress, saved_growth)
		and field.crop_tended == growth_tended, "Growth stage and tending survive reload")
	_check(pen.global_position.is_equal_approx(pen_pos) and pen.get_herd().size() == herd.size(),
		"The pen and its herd survive reload")
	_check(player.is_mounted() and player._mounted_animal.owner_faction == 0
		and player._mounted_animal.rider_unit_id == lead_id and leader._mounted,
		"Reload restores the trained mount and its rider")
	var restored_mount: Node = player._mounted_animal
	_key(KEY_E, true)
	_key(KEY_E, false)
	_check(not player.is_mounted() and restored_mount.rider_unit_id == 0 and not leader._mounted,
		"E dismounts and clears the rider reference")
	_harvest_and_haul(field, worker_id)
	for animal in pen.get_herd():
		animal._physics_process(Farming.MATURITY_TIME)
	var herd_before: int = pen.get_herd().size()
	var food_before: float = _state.factions[0]["resources"]["food"]
	_check(pen.harvest_surplus_livestock() and pen.get_herd().size() == herd_before - 1
		and _state.factions[0]["resources"]["food"] > food_before,
		"A pen can harvest surplus adults while retaining a breeding pair")
	DirAccess.remove_absolute(path)


func _harvest_and_haul(field: Node, worker_id: int) -> void:
	var farmer: Node = null
	for unit in _state.get_faction_units(0):
		if unit.unit_id == worker_id:
			farmer = unit
			break
	if not _check(farmer != null and farmer.role == GameData.Role.FARMER, "The assigned Farmer survives reload"):
		return
	field._physics_process(Farming.CROP_GROW_TIME)
	_check(field.crop_stage == Farming.CropStage.RIPE, "An established field reaches harvest")
	_teleport(farmer, field.global_position + Vector3(1, 0, 0))
	farmer._day_work_routine(2.6)
	_check(field.crop_stage == Farming.CropStage.EMPTY and farmer._carry_type == "food" and farmer._carry_amount == 24.0,
		"Farmer harvests the tended crop into a load")
	var stock: Dictionary = _state.factions[0]["resources"]
	var food: float = stock["food"]
	var camp: Vector3 = _state.factions[0]["camp_position"]
	_teleport(farmer, camp + Vector3(2, 0, 0))
	farmer._day_work_routine(0.1)
	_check(is_equal_approx(float(stock["food"]), food + 24.0) and farmer._carry_amount == 0.0,
		"The Farmer hauls the crop to camp and credits the food once")


func _choose_taming_roll(success: bool) -> void:
	for value in range(100):
		seed(value)
		if (randf() < Farming.TAME_CHANCES["BOAR"]) == success:
			seed(value)
			return


func _teleport(unit: Node, point: Vector3) -> void:
	unit.global_position = point
	_state.spatial_index.update_unit(unit)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, caption: String) -> bool:
	if not condition:
		_failures += 1
		push_error(caption)
	return condition

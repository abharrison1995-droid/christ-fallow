extends SceneTree
## Verifies building entry points, crop work, wildlife ownership, husbandry, riding and persistence.

const Farming = preload("res://scripts/core/farming_rules.gd")
const MOUNT_SPEEDS := {"MAMMOTH": 1.15, "BOAR": 1.32, "DEER": 1.58}

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
		await _verify_mount_roster()
	_state.end_campaign()
	root.remove_child(main)
	main.queue_free()
	await process_frame
	if _failures == 0:
		await _verify_title_continue()
	DirAccess.remove_absolute(_state.CAMPAIGN_SAVE_PATH)
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
		_choose_taming_roll("BOAR", true)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_check(animal.owner_faction == 0 and animal.pen_position == center, "E tames a wild boar and assigns a pen")
	var rejected: Node = _state.world_node._spawn_animal("BOAR", center + Vector3(10, 0, 0))
	_teleport(leader, rejected.global_position + Vector3(0, 0, 2.4))
	_choose_taming_roll("BOAR", false)
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


func _verify_mount_roster() -> void:
	var plot := Vector3(99, 0, 100)
	var previous_speed := 0.0
	var valley_species := {}
	for wildlife in _state.wildlife_container.get_children():
		valley_species[wildlife.animal_type] = true
	for species: String in MOUNT_SPEEDS:
		_check(valley_species.has(species), "%s is available in the campaign valley" % species)
		var leader: Node = _state.get_faction_leader(0)
		var player: Node = _state.player_controller
		var faction: Node = _state.faction_controllers[0]
		var pen: Node = faction.spawn_building("ANIMAL_PEN", plot)
		var animal: Node = _state.world_node._spawn_animal(species, plot + Vector3(2.2, 0, 0))
		plot.z += 16.0
		_teleport(leader, animal.global_position + Vector3(0, 0, 2.0))
		_choose_taming_roll(species, true)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_check(animal.owner_faction == 0 and animal.pen_position == pen.global_position, "%s can be tamed through E" % species)
		pen._physics_process(Farming.PEN_INTERVAL)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_check(animal.training_feeds == 1 and not player.is_mounted(), "%s needs both feedings" % species)
		pen._physics_process(Farming.PEN_INTERVAL)
		if not _check(animal.can_mount(0), "%s trains through normal pen feeding" % species):
			continue

		_key(KEY_C, true)
		_key(KEY_C, false)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_check(not player.is_mounted(), "The Colony drawer blocks mounting")
		_key(KEY_C, true)
		_key(KEY_C, false)
		_key(KEY_E, true)
		_key(KEY_E, false)
		if not _check(player.is_mounted() and player._mounted_animal == animal, "E mounts the trained %s" % species):
			continue
		var hud: Node = _state.hud_controller
		_check(hud._blessing_label.text == "%s  ·  [E] Dismount" % animal.animal_name,
			"The HUD immediately names the active mount and shows its dismount control")

		player.cam_yaw = -90.0
		var start: Vector3 = leader.global_position
		_key(KEY_W, true)
		for frame in range(12):
			await physics_frame
		_key(KEY_W, false)
		var speed: Vector3 = leader.get_real_velocity()
		var ground_speed := Vector2(speed.x, speed.z).length()
		var ratio: float = ground_speed / leader.move_speed
		_check(absf(ratio - float(MOUNT_SPEEDS[species])) < 0.002 and ground_speed > previous_speed
			and leader.global_position.distance_to(start) > 0.75, "%s moves at its unique mounted speed (%.3fx)" % [species, ratio])
		previous_speed = ground_speed
		_check(leader.global_position.is_equal_approx(animal.global_position) and leader._rider_lift > 0.0
			and leader._collider.shape == animal.get_mount_shape() and animal._collider.disabled,
			"%s carries the rider with its own collision capsule" % species)
		print("MOUNT %s: %.2f m/s (%.0f%% of walking speed)" % [species, ground_speed, ratio * 100.0])

		if not _out_dir.is_empty():
			await _capture_mount(player, hud, species)
		if not _check(_state.save_game() and _state.load_game(), "%s round-trips through a campaign save" % species):
			continue
		leader = _state.get_faction_leader(0)
		animal = player._mounted_animal
		if not _check(player.is_mounted() and animal.animal_type == species and animal.rider_unit_id == leader.unit_id,
			"Campaign load restores the %s and its rider" % species):
			continue
		_key(KEY_E, true)
		_key(KEY_E, false)
		await physics_frame
		_check(not player.is_mounted() and animal.rider_unit_id == 0 and not animal._collider.disabled
			and leader._collider.shape == leader._foot_shape and leader.global_position.distance_to(animal.global_position) > 1.0,
			"E dismounts the %s into clear space and restores both collision shapes" % species)
		if species == "MAMMOTH":
			_key(KEY_E, true)
			_key(KEY_E, false)
			if _check(player._mounted_animal == animal, "The leader can mount again after dismounting"):
				animal.take_damage(animal.hp + 1.0, null, 5)
				_check(not player.is_mounted() and not leader._mounted and animal.rider_unit_id == 0,
					"Losing a mount immediately releases the rider")
				_check(hud._blessing_label.text.begins_with("[Q] Blessing"),
					"Losing a mount immediately restores the blessing hint")


func _verify_title_continue() -> void:
	var title: Node = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	title._show_main_menu()
	if _check(not title._continue.disabled, "Continue finds the save with a mounted leader"):
		title._continue.pressed.emit()
		for frame in range(6):
			await process_frame
		var player: Node = _state.player_controller
		_check(_state.game_active and player != null and player.is_mounted() and player._mounted_animal.animal_type == "DEER",
			"Continue mounts a fresh campaign with the saved deer and rider")
	root.remove_child(title)
	title.queue_free()
	await process_frame


func _capture_mount(player: Node, hud: Node, species: String) -> void:
	var preferences := root.get_node("Preferences")
	player.cam_yaw -= 72.0
	player.target_cam_distance = 8.5
	preferences.set_value("ui_scale", 1.1)
	for frame in range(22):
		await physics_frame
	await RenderingServer.frame_post_draw
	var hud_rect: Rect2 = hud._squad_bar.get_global_rect()
	_check(root.get_visible_rect().encloses(hud_rect), "The mounted HUD fits at maximum interface scale")
	_check(root.get_texture().get_image().save_png(_out_dir.path_join("mount-%s.png" % species.to_lower())) == OK,
		"Write the %s mount review" % species)
	preferences.set_value("ui_scale", 0.9)
	await process_frame
	_check(root.get_visible_rect().encloses(hud._squad_bar.get_global_rect()), "The mounted HUD fits at minimum interface scale")
	preferences.set_value("ui_scale", 1.0)
	player.target_cam_distance = 12.0


func _choose_taming_roll(species: String, success: bool) -> void:
	for value in range(100):
		seed(value)
		if (randf() < Farming.TAME_CHANCES[species]) == success:
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

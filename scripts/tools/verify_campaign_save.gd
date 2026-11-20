extends SceneTree
## Builds temporary v1, v2, and v3 fixtures through the real campaign save path.

var _state: Node
var _main: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, caption: String) -> void:
	if not condition:
		_failures += 1
		push_error(caption)


func _mount() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _unmount() -> void:
	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()


func _run() -> void:
	_state = root.get_node("GameState")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return
	var path := "user://probe-%d.json" % Time.get_ticks_usec()
	_mount()
	_state.start_new_campaign("Enoch", "Restoration Probe", GameData.Lineage.CRAG_BORN)
	var player: Node = _state.get_faction_leader(0)
	var leader_id: int = player.unit_id
	var colony: Node = _state.faction_controllers[0]
	colony.spawn_colonist(Vector3(66, 0, 52), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	var damaged: Node = colony.spawn_building("SLEEPING_HUT", Vector3(62, 0, 52), 0.5, true)
	damaged.hp = damaged.max_hp * 0.28
	damaged.sync_visual_from_state()
	colony.spawn_building("CAMPFIRE", Vector3(56, 0, 52), 0.0, false)
	_state.tutorial_step = 3
	_state.tutorial_harvested = true
	_state.warhorn_active = true
	_state.combat_command_system.issue_order(GameData.SquadOrder.HOLD, player.global_position)
	var fallen: Node = _state.get_faction_leader(1)
	fallen.is_dead = true
	_state.trigger_conquest_if_eligible(1, 0)
	if not _state.save_game(path):
		push_error("Could not write the v3 fixture.")
		quit(1)
		return
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(current["version"]) == 3, "The writer emits schema v3")
	_unmount()
	await process_frame
	_mount()
	var events: Array[String] = []
	_state.game_started.connect(func(): events.append("started"))
	_state.campaign_loaded.connect(func():
		_check(_state.get_faction_leader(0).unit_id == leader_id, "The leader is attached with its original ID before campaign_loaded")
		_check(_state.combat_command_system.last_issued_order == GameData.SquadOrder.HOLD, "Commands restore before campaign_loaded")
		events.append("loaded")
	, CONNECT_ONE_SHOT)
	_state.conquest_triggered.connect(func(_faction: int): events.append("conquest"), CONNECT_ONE_SHOT)
	_check(_state.load_game(path), "Cold load v3")
	_check(events == ["started", "loaded", "conquest"], "Cold-load signals retain their order")
	var buildings: Array = _state.get_faction_buildings(0, "SLEEPING_HUT")
	_check(buildings.size() == 1 and buildings[0].damage_stage == 2, "Critical stage derives from saved HP")
	_check(not _state.get_faction_buildings(0, "CAMPFIRE")[0].is_constructed, "Blueprint remains unfinished")
	_check(_state.tutorial_step == 3 and _state.tutorial_harvested and _state.warhorn_active, "Guide and warhorn restore")
	var live_world: Node = _state.world_node
	var live_leader: Node = _state.get_faction_leader(0)
	_write(path, "{ malformed")
	_check(not _state.load_game(path) and _state.get_faction_leader(0) == live_leader, "Malformed input preserves live entities")
	var future := current.duplicate(true)
	future["version"] = 99
	_write(path, JSON.stringify(future))
	_check(not _state.load_game(path) and _state.world_node == live_world, "Unsupported input preserves the world")
	var units: Array = current["units"]
	var missing_leader := current.duplicate(true)
	missing_leader["units"] = units.filter(func(unit: Dictionary): return int(unit["faction_id"]) != 0 or not unit["is_leader"])
	_write(path, JSON.stringify(missing_leader))
	_check(not _state.load_game(path) and _state.get_faction_leader(0) == live_leader, "A v3 save missing its recorded leader is rejected before restore")
	missing_leader["units"] = units.filter(func(unit: Dictionary): return int(unit["faction_id"]) != 0)
	missing_leader.erase("player_leader_id")
	_write(path, JSON.stringify(missing_leader))
	_check(_state.read_campaign_save(path).has("data"), "A v3 save with no surviving player units remains readable")
	var legacy := current.duplicate(true)
	legacy.erase("wildlife")
	legacy.erase("combat_commands")
	legacy.erase("pending_conquests")
	legacy.erase("player_leader_id")
	legacy["version"] = 2
	var old_wildlife: Node = _state.wildlife_container.get_child(0)
	_write(path, JSON.stringify(legacy))
	_check(_state.load_game(path), "In-session reload accepts v2")
	_check(_state.wildlife_container.get_child(0) == old_wildlife, "Missing wildlife preserves existing wildlife during reload")
	legacy.erase("version")
	for unit in legacy["units"]:
		unit.erase("unit_id")
	_write(path, JSON.stringify(legacy))
	_unmount()
	await process_frame
	_mount()
	_check(_state.load_game(path), "Cold load accepts an unversioned v1 fixture")
	_check(_state.wildlife_container.get_child_count() == 25, "Missing wildlife repopulates on cold load")
	var ids := {}
	for unit in _state.units_container.get_children():
		_check(unit.unit_id > 0 and not ids.has(unit.unit_id), "Legacy unit IDs become positive and unique")
		ids[unit.unit_id] = true
	_check_guide_reward()
	_check_combat()
	_unmount()
	DirAccess.remove_absolute(path)
	await process_frame
	if _failures == 0:
		print("CAMPAIGN SAVE VERIFICATION PASSED")
	quit(0 if _failures == 0 else 1)


func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not rewrite the temporary fixture")
		return
	file.store_string(contents)
	file.close()


func _check_guide_reward() -> void:
	_state.hud_controller.hide()
	_state.tutorial_step = 5
	_state.tutorial_cleaved = true
	_state.tutorial_thrown = true
	var resources: Dictionary = _state.factions[0]["resources"]
	var before := resources.duplicate()
	_state._process(0.36)
	_check(_state.tutorial_completed, "Guide completes while the HUD is hidden")
	for key in ["food", "wood", "flint"]:
		var reward := 5.0 if key == "flint" else 10.0
		_check(is_equal_approx(float(resources[key]), float(before[key]) + reward), "Guide pays the expected " + key + " reward")
	var after := resources.duplicate()
	_state._process(0.36)
	_check(resources == after, "Guide reward is paid once")


func _check_combat() -> void:
	if _state.warhorn_active:
		_state.combat_command_system.toggle_warhorn()
	var ally: Node = _state.faction_controllers[0]
	var rival: Node = _state.faction_controllers[2]
	var center := Vector3(152, 0, 150)
	var civilian: Node = ally.spawn_colonist(center, GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	civilian.base_melee_stat = 10.0
	civilian.recalculate_stats(true)
	var opponent: Node = rival.spawn_colonist(center + Vector3.RIGHT, GameData.Lineage.SWIFT_KIN, GameData.Gender.MALE, GameData.Role.FORAGER)
	opponent.armor = 0.0
	_state.set_diplomatic_state(0, 2, GameData.DiplomaticState.AT_WAR)
	var before: float = opponent.hp
	civilian._process_tribal_ai(0.0)
	_check(is_equal_approx(before - float(opponent.hp), 3.78), "Cornered adult civilian delivers the baseline unarmed strike")
	_check(is_equal_approx(float(civilian._attack_cd), 1.15), "Unarmed strike uses the baseline cooldown")

	var brute: Node = ally.spawn_colonist(center + Vector3(0, 0, 8), GameData.Lineage.GOLIATH, GameData.Gender.MALE, GameData.Role.WARRIOR)
	brute.base_hp_stat = 100.0
	brute.base_melee_stat = 10.0
	brute.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.BRUTE)
	_check(is_equal_approx(float(brute.max_hp), 207.0), "Fixed Goliath Brute derives baseline maximum HP")
	var wall: Node = rival.spawn_building("PALISADE_WALL", brute.global_position + Vector3.RIGHT, 0.0, true)
	before = wall.hp
	brute._engage_building(wall)
	_check(is_equal_approx(before - float(wall.hp), 31.438125), "Brute retains the baseline multiplier against buildings")

	var impact: Vector3 = opponent.global_position + Vector3.UP
	var projectile: Node = load("res://scripts/entities/projectile_3d.gd").spawn(brute, 0, impact - Vector3.RIGHT, impact, 12.0)
	_state.units_container.remove_child(brute)
	brute.free()
	opponent.armor = 10.0
	before = opponent.hp
	projectile.global_position = impact
	projectile.velocity = Vector3.ZERO
	projectile.gravity = 0.0
	projectile._physics_process(0.016)
	_check(is_equal_approx(before - float(opponent.hp), 7.5), "Projectile retains faction attribution and armor mitigation after its shooter is freed")

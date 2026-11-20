extends SceneTree
## Deterministic seed 17394 simulation benchmark for Phase 1 performance tracking.

var _unit_ai: GDScript
var _state: Node
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _physics_frames(count: int) -> Array[float]:
	var samples: Array[float] = []
	for i in range(count):
		await physics_frame
		var ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		samples.append(ms)
	return samples


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[(n / 2) - 1] + sorted[n / 2]) * 0.5


func _percentile_95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)
	return sorted[idx]


func _measure_target_search_median(probe_unit: Node) -> float:
	if probe_unit == null or not is_instance_valid(probe_unit):
		return 0.0
	var origin: Vector3 = (probe_unit as Node3D).global_position
	var batches: Array[float] = []
	for b in range(11):
		var t0: int = Time.get_ticks_usec()
		for i in range(100):
			var _found: Node = _unit_ai.find_enemy_near_point(probe_unit, origin, 85.0)
		var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		batches.append(elapsed_ms)
	return _median(batches)


func _measure_scenario(label: String, probe_unit: Node) -> Dictionary:
	var _warmup: Array[float] = await _physics_frames(15)
	var samples: Array[float] = await _physics_frames(30)
	var search_ms: float = _measure_target_search_median(probe_unit)
	var unit_count: int = _state.units_container.get_child_count() if _state.units_container != null else 0
	var building_count: int = _state.buildings_container.get_child_count() if _state.buildings_container != null else 0
	return {
		"label": label,
		"units": unit_count,
		"buildings": building_count,
		"physics_median": _median(samples),
		"physics_p95": _percentile_95(samples),
		"search_median": search_ms,
	}


func _setup_developed_settlement() -> void:
	var player_fc: Node = _state.faction_controllers[0]
	var player_camp: Vector3 = _state.factions[0]["camp_position"]
	var player_buildings: Array[String] = [
		"CAMPFIRE", "SLEEPING_HUT", "SLEEPING_HUT", "STORAGE_PIT",
		"FORAGER_LODGE", "BARRACKS", "SHAMAN_SHACK", "WATCHTOWER",
		"CRAFTING_PIT", "PALISADE_WALL", "PALISADE_WALL"
	]
	for i in range(player_buildings.size()):
		var angle: float = float(i) * (TAU / float(player_buildings.size()))
		var pos: Vector3 = player_camp + Vector3(cos(angle) * 14.0, 0.0, sin(angle) * 14.0)
		player_fc.spawn_building(player_buildings[i], pos, angle, true)

	# Add player colonists & warriors
	for i in range(16):
		var angle: float = float(i) * (TAU / 16.0)
		var pos: Vector3 = player_camp + Vector3(cos(angle) * 8.0, 0.0, sin(angle) * 8.0)
		var role: int = GameData.Role.WARRIOR if (i % 2 == 0) else GameData.Role.FORAGER
		player_fc.spawn_colonist(pos, GameData.Lineage.CRAG_BORN, i % 2, role)

	# Expand rival tribes (factions 1..4) with extra units & buildings to ~91 units / ~50 buildings
	var rival_idx: int = 0
	for fid in [1, 2, 3, 4]:
		if not _state.faction_controllers.has(fid):
			continue
		var fc: Node = _state.faction_controllers[fid]
		var camp: Vector3 = _state.factions[fid]["camp_position"]
		var r_lineage: int = int(_state.factions[fid].get("lineage", GameData.Lineage.STALKER))
		fc.spawn_building("SLEEPING_HUT", camp + Vector3(8.0, 0.0, 0.0), 0.0, true)
		if rival_idx < 2:
			fc.spawn_building("WATCHTOWER", camp + Vector3(-8.0, 0.0, 4.0), 0.5, true)
		for j in range(8):
			var a: float = float(j) * (TAU / 8.0)
			var u_pos: Vector3 = camp + Vector3(cos(a) * 7.0, 0.0, sin(a) * 7.0)
			var u_role: int = GameData.Role.WARRIOR if (j % 2 == 0) else GameData.Role.FORAGER
			fc.spawn_colonist(u_pos, r_lineage, j % 2, u_role)
		rival_idx += 1


func _setup_raid() -> void:
	var player_camp: Vector3 = _state.factions[0]["camp_position"]
	# Disable opening peace buffer and sound Tribal Warhorn
	_state.bandit_grace_remaining = 0.0
	if not _state.warhorn_active and _state.combat_command_system != null:
		_state.combat_command_system.toggle_warhorn()

	# Set rivals 1 & 2 AT_WAR and launch raids toward player camp
	for fid in [1, 2]:
		_state.set_diplomatic_state(0, fid, GameData.DiplomaticState.AT_WAR)
		if _state.faction_controllers.has(fid):
			var fc: Node = _state.faction_controllers[fid]
			fc.launch_raid_against(0)

	# Spawn active caveman raid wave near player perimeter + 1 extra watchtower
	if _state.faction_controllers.has(5):
		var caveman_fc: Node = _state.faction_controllers[5]
		for i in range(16):
			var a: float = float(i) * (TAU / 16.0)
			var spawn_pos: Vector3 = player_camp + Vector3(cos(a) * 28.0, 0.0, sin(a) * 28.0)
			var raider: Node = caveman_fc.spawn_colonist(
				spawn_pos, GameData.Lineage.CAVEMAN, i % 2, GameData.Role.WARRIOR, false, false, true
			)
			if raider != null:
				raider.is_raiding = true
				raider.raid_target_pos = player_camp

	if _state.faction_controllers.has(0):
		var player_fc: Node = _state.faction_controllers[0]
		player_fc.spawn_building("WATCHTOWER", player_camp + Vector3(0.0, 0.0, -16.0), 0.0, true)

	# Issue aggressive player squad order to engage
	if _state.combat_command_system != null:
		_state.combat_command_system.issue_order(GameData.SquadOrder.CHARGE, player_camp)


func _run() -> void:
	_unit_ai = load("res://scripts/entities/unit_ai_routines.gd")
	_state = root.get_node("GameState")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame

	seed(17394)
	if not _state.start_new_campaign("Bench Leader", "Bench Tribe", GameData.Lineage.CRAG_BORN):
		push_error("Failed to start benchmark campaign.")
		quit(1)
		return

	var leader: Node = _state.get_faction_leader(0)
	if leader == null:
		push_error("Player leader missing after start_new_campaign.")
		quit(1)
		return

	var results: Array[Dictionary] = []

	# 1. Opening
	results.append(await _measure_scenario("Opening", leader))

	# 2. Developed settlement
	_setup_developed_settlement()
	results.append(await _measure_scenario("Developed settlement", leader))

	# 3. Raid
	_setup_raid()
	results.append(await _measure_scenario("Raid", leader))

	print("")
	print("| Scenario | Unit nodes | Building nodes | Physics median (ms) | Physics p95 (ms) | 100 target searches (ms) |")
	print("| --- | ---: | ---: | ---: | ---: | ---: |")
	for row in results:
		print("| %s | %d | %d | %.3f ms | %.3f ms | %.3f ms |" % [
			str(row["label"]),
			int(row["units"]),
			int(row["buildings"]),
			float(row["physics_median"]),
			float(row["physics_p95"]),
			float(row["search_median"]),
		])
	print("")
	print("SIMULATION BENCHMARK COMPLETE")

	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()
	quit(0)

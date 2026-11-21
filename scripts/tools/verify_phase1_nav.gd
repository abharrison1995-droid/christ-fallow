extends SceneTree
## Phase 1 verification: SpatialIndex accuracy and ValleyNavigation routing (walls, rubble, river fords, save/load).
## Run (isolated save dir required):
##   $env:APPDATA=<scratch>; $env:CHRIST_FALLOW_QA_APPDATA=<scratch>
##   godot --path . --quit-after 900 -s res://scripts/tools/verify_phase1_nav.gd

const Layout = preload("res://scripts/core/world_layout.gd")

var _state: Node
var _main: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, caption: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAILED: " + caption)
	else:
		print("ok: ", caption)


func _mount() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _unmount() -> void:
	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()


func _ids(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		out.append(n.get_instance_id())
	out.sort()
	return out


## Index results must equal a brute-force container scan for every faction.
func _index_matches_world(tag: String) -> void:
	var ok := true
	for fid in range(-3, 7):
		var live_units: Array = []
		for u in _state.units_container.get_children():
			if is_instance_valid(u) and not u.is_queued_for_deletion() and int(u.faction_id) == fid and not u.is_dead and u.hp > 0.0:
				live_units.append(u)
		if _ids(live_units) != _ids(_state.get_faction_units(fid, true)):
			ok = false
			push_error("%s: unit mismatch in faction %d (%d vs %d)" % [tag, fid, live_units.size(), _state.get_faction_units(fid, true).size()])
		var live_buildings: Array = []
		for b in _state.buildings_container.get_children():
			if is_instance_valid(b) and not b.is_queued_for_deletion() and int(b.faction_id) == fid and b.hp > 0.0:
				live_buildings.append(b)
		if _ids(live_buildings) != _ids(_state.get_faction_buildings(fid, "", false)):
			ok = false
			push_error("%s: building mismatch in faction %d" % [tag, fid])
	_check(ok, tag + ": index equals container scan for all factions")


func _path_is_walkable(path: PackedVector3Array, from: Vector3) -> bool:
	var nav = _state.valley_nav
	var prev: Vector3 = from
	for i in range(path.size()):
		var wp: Vector3 = path[i]
		var last: bool = i == path.size() - 1
		if not last and nav.is_cell_blocked(nav.world_to_cell(wp)):
			return false
		if i > 0 and not nav.has_line_of_sight(nav.world_to_cell(prev), nav.world_to_cell(wp)):
			return false
		prev = wp
	return true


func _min_dist_to_fords(path: PackedVector3Array) -> float:
	var best := 99999.0
	for ford in _state.valley_layout.river_crossings():
		var fp: Vector3 = ford["pos"]
		for wp in path:
			best = minf(best, Vector2(wp.x - fp.x, wp.z - fp.z).length())
	return best


func _run() -> void:
	_state = root.get_node("GameState")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return
	var path := "user://phase1-nav-%d.json" % Time.get_ticks_usec()
	seed(17394)
	_mount()
	_state.start_new_campaign("Enoch", "Nav Probe", GameData.Lineage.CRAG_BORN, Layout.CLASSIC_ID)
	var index = _state.spatial_index
	var nav = _state.valley_nav
	_check(index.is_populated() and nav.is_ready(), "Index and navigation exist after a new campaign")
	_check(_state.get_faction_leader(0) != null and _state.get_faction_leader(0).is_leader, "Player leader is cached in the index")
	_index_matches_world("new campaign")

	# Movement across cells (physics frames run update_unit on every living unit)
	for i in range(45):
		await physics_frame
	var moved_ok := true
	for u in _state.units_container.get_children():
		if not u.is_dead and not index.query_units_in_radius((u as Node3D).global_position, 0.5).has(u):
			moved_ok = false
	_check(moved_ok, "Every living unit is findable at its current position after simulation")

	# Spawn, cross a cell boundary, convert, die
	var fc0: Node = _state.faction_controllers[0]
	var probe: Node3D = fc0.spawn_colonist(Vector3(100, 0, 100), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	_check(index.query_units_in_radius(Vector3(100, 0, 100), 2.0).has(probe), "Spawned unit is indexed")
	probe.global_position = Vector3(131, 0, 100)
	index.update_unit(probe)
	_check(index.query_units_in_radius(Vector3(100, 0, 100), 2.0).is_empty() and index.query_units_in_radius(Vector3(131, 0, 100), 2.0).has(probe), "Unit moves between cells")
	probe.convert_to_faction(6, false)
	_check(_state.get_faction_units(6, true).has(probe) and not _state.get_faction_units(0, true).has(probe), "Faction conversion moves the cached roster")
	probe.is_leader = true
	_check(_state.get_faction_leader(6) == probe, "Leader promotion updates the cached leader")
	probe.is_leader = false
	_check(_state.get_faction_leader(6) == null, "Leader demotion clears the cached leader")
	probe._die(null, -1)
	_check(not index.query_units_in_radius(Vector3(131, 0, 100), 2.0).has(probe) and not _state.get_faction_units(6, true).has(probe), "Dead unit leaves the index")
	probe.queue_free()
	_index_matches_world("after spawn/convert/death")

	# Buildings: blueprint -> constructed -> rubble
	var site := Vector3(100, 0, -100)
	var hut: Node = fc0.spawn_building("SLEEPING_HUT", site, 0.0, false)
	_check(_state.get_faction_buildings(0, "SLEEPING_HUT", false).has(hut) and not _state.get_faction_buildings(0, "SLEEPING_HUT", true).has(hut), "Blueprint is indexed but not constructed")
	_check(not nav.is_cell_blocked(nav.world_to_cell(site)), "Blueprints do not block navigation")
	hut.advance_construction(9999.0)
	_check(_state.get_faction_buildings(0, "SLEEPING_HUT", true).has(hut) and nav.is_cell_blocked(nav.world_to_cell(site)), "Completed building is queryable and blocks its cell")
	hut.take_damage(99999.0, -1)
	_check(hut.is_destroyed and not _state.get_faction_buildings(0, "SLEEPING_HUT", false).has(hut) and not index.query_buildings_in_radius(site, 4.0).has(hut), "Rubble leaves the building index")
	_check(not nav.is_cell_blocked(nav.world_to_cell(site)), "Rubble clears the navigation obstacle")
	_index_matches_world("after building lifecycle")

	# Wall routing
	var wall_x := 40.0
	var walls: Array = []
	for k in range(-4, 5):
		walls.append(fc0.spawn_building("PALISADE_WALL", Vector3(wall_x, 0, float(k) * 4.0), 0.0, true))
	var start := Vector3(28, 0, 0)
	var goal := Vector3(54, 0, 0)
	var detour: PackedVector3Array = nav.find_path(start, goal)
	_check(detour.size() > 1 and _path_is_walkable(detour, start), "Path routes around the palisade barrier (%d waypoints)" % detour.size())
	_check(detour[detour.size() - 1].is_equal_approx(Vector3(goal.x, 0, goal.z)), "Path ends exactly at the requested goal")
	var detour_len := 0.0
	var prev_p := start
	for wp in detour:
		detour_len += prev_p.distance_to(wp)
		prev_p = wp
	_check(detour_len > start.distance_to(goal) + 6.0, "Detour is longer than the blocked straight line")
	for w in walls:
		w.take_damage(99999.0, -1)
	var open: PackedVector3Array = nav.find_path(start, goal)
	_check(open.size() == 1 and open[0].is_equal_approx(Vector3(goal.x, 0, goal.z)), "Direct path reopens once the wall is rubble")

	# River ford routing: west bank to east bank at a point far from every ford
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(_state.valley_layout.river_rotation_y_deg))
	var axis_pt: Vector3 = _state.valley_layout.river_point(40.0)
	var west: Vector3 = axis_pt + yaw_basis * Vector3(-30.0, 0.0, 0.0)
	var east: Vector3 = axis_pt + yaw_basis * Vector3(30.0, 0.0, 0.0)
	_check(not nav.has_line_of_sight(nav.world_to_cell(west), nav.world_to_cell(east)), "Straight line across deep water is blocked")
	var crossing: PackedVector3Array = nav.find_path(west, east)
	_check(crossing.size() > 1 and _path_is_walkable(crossing, west), "Crossing path never enters deep water (%d waypoints)" % crossing.size())
	_check(_min_dist_to_fords(crossing) <= _state.valley_layout.river_ford_half_width + 4.0, "Crossing path uses a ford")
	var edge_path: PackedVector3Array = nav.find_path(axis_pt + yaw_basis * Vector3(-5.5, 0.0, 0.0), east)
	_check(edge_path.size() >= 1, "A unit standing on the river edge still receives a path")

	# Save / load round trip
	_index_matches_world("before save")
	var leader_id: int = _state.get_faction_leader(0).unit_id
	var unit_total: int = _state.get_faction_units(0, true).size()
	var bld_total: int = _state.get_faction_buildings(0, "", false).size()
	var standing: Node = fc0.spawn_building("PALISADE_WALL", Vector3(60, 0, 20), 0.0, true)
	var standing_cell: Vector2i = nav.world_to_cell(standing.global_position)
	_check(_state.save_game(path), "Save the campaign")
	_unmount()
	await process_frame
	_check(not _state.spatial_index.is_populated() and not _state.valley_nav.is_ready(), "End of campaign clears the index and navigation grid")
	_mount()
	_check(_state.load_game(path), "Cold load the campaign")
	index = _state.spatial_index
	nav = _state.valley_nav
	_check(_state.get_faction_leader(0).unit_id == leader_id, "Leader is cached after load")
	_check(_state.get_faction_units(0, true).size() == unit_total, "Player roster restores through the index")
	_check(_state.get_faction_buildings(0, "", false).size() == bld_total + 1, "Building roster restores through the index")
	_check(nav.is_ready() and nav.is_cell_blocked(standing_cell), "Standing wall blocks navigation after load")
	_index_matches_world("after load")
	for i in range(30):
		await physics_frame
	_index_matches_world("after load + simulation")

	# Warm load over a live campaign must not leak freed instances
	_check(_state.load_game(path), "Warm load over a live campaign")
	_index_matches_world("after warm load")

	_unmount()
	await process_frame
	if _failures == 0:
		print("PHASE 1 NAV & SPATIAL VERIFICATION PASSED")
		quit(0)
	else:
		push_error("PHASE 1 NAV & SPATIAL VERIFICATION FAILED (%d)" % _failures)
		quit(1)

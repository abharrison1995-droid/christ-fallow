extends SceneTree
## Verifies both terrain layouts, long-distance routes, layout-versioned saves and World Map input.

const Layout = preload("res://scripts/core/world_layout.gd")

var _state: Node
var _main: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return
	_state = root.get_node("GameState")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	seed(17394)
	_check(_state.start_new_campaign("Enoch", "Expanded Valley", GameData.Lineage.CRAG_BORN), "New Game starts")
	_verify_geography()
	_verify_routes()
	_verify_distant_colony()
	await _verify_map()
	_verify_layout_saves("user://expanded-valley-%d.json" % Time.get_ticks_usec())
	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()
	await process_frame
	if _failures == 0:
		print("EXPANDED VALLEY VERIFICATION PASSED")
	quit(0 if _failures == 0 else 1)


func _verify_geography() -> void:
	var layout: Layout = _state.valley_layout
	_check(layout.id == Layout.EXPANDED_ID and layout.ground_size == Vector2(760, 760), "New Game selects the 760 m valley")
	_check(_state.valley_nav._size == Vector2i(190, 190), "Expanded navigation has 190 by 190 cells")
	_check(_terrain_width() == 760.0, "Expanded ground collision is 760 m wide")
	var fords: Node = _state.world_node.get_node("Terrain/RiverFords")
	_check(fords.get_child_count() == layout.river_crossings().size(), "The terrain displays every reachable ford")
	var nearest := INF
	for fid in range(5):
		var camp: Vector3 = _state.factions[fid]["camp_position"]
		for other in range(fid + 1, 5):
			var distance := camp.distance_to(layout.camp_position(other))
			_check(distance >= 170.0, "Starting camps %d and %d are at least 170 m apart" % [fid, other])
			if fid == 0:
				nearest = minf(nearest, distance)
		for step in range(12):
			var angle := TAU * float(step) / 12.0
			var point := camp + Vector3(cos(angle), 0.0, sin(angle)) * layout.settlement_radius
			_check(absf(point.x) <= layout.blueprint_half_extent and absf(point.z) <= layout.blueprint_half_extent
				and not _state.valley_nav._in_river(point), "Camp %d has a dry %d m growth radius" % [fid, layout.settlement_radius])
		var available := {}
		for resource in _state.resources_container.get_children():
			if camp.distance_to(resource.global_position) <= 32.0:
				available[resource.get_meta("node_type")] = true
		_check(available.has_all(["TREE", "STONE", "FLINT", "BERRY_BUSH"]), "Camp %d has nearby gathering resources" % fid)
	_check(nearest >= 170.0 and nearest <= 240.0, "The nearest rival is within the intended travel band")
	_check(_state.bandit_grace_remaining == _state.BANDIT_GRACE_DURATION, "The opening Peace Buffer is unchanged")


func _verify_routes() -> void:
	var nav: RefCounted = _state.valley_nav
	var layout: Layout = _state.valley_layout
	var across := Basis(Vector3.UP, deg_to_rad(layout.river_rotation_y_deg)).x
	for ford in layout.river_crossings():
		var center: Vector3 = ford["pos"]
		var start := center - across * 28.0
		var target := center + across * 28.0
		var path: PackedVector3Array = nav.find_path(start, target)
		_check(not path.is_empty() and path[-1].distance_to(target) < 4.0 and _crosses_open_water(start, path),
			"Every ford carries a route between both banks")

	_state.set_diplomatic_state(3, 0, GameData.DiplomaticState.AT_WAR)
	_state.faction_controllers[3].launch_raid_against(0)
	var raiders := 0
	for unit in _state.get_faction_units(3):
		if unit.is_raiding:
			var path: PackedVector3Array = nav.find_path(unit.global_position, unit.raid_target_pos)
			_check(not path.is_empty() and path[-1].distance_to(layout.camp_position(0)) < 8.0
				and _crosses_open_water(unit.global_position, path), "A distant raider routes through a ford to the player camp")
			raiders += 1
	_check(raiders > 0, "The western rival can dispatch a raid across the valley")
	var work_pos := layout.river_point(18.0) - across * 38.0
	var delivery := layout.river_point(18.0) + across * 23.0
	var faction: Node = _state.faction_controllers[0]
	faction.spawn_building("STORAGE_PIT", delivery)
	var gatherer: Node = faction.spawn_colonist(work_pos, GameData.Lineage.CRAG_BORN,
		GameData.Gender.MALE, GameData.Role.FORAGER)
	gatherer._carry_type = "food"
	gatherer._carry_amount = 3.0
	gatherer._day_work_routine(0.0)
	var haul_path: PackedVector3Array = gatherer._nav_path
	_check(haul_path.size() > 1 and haul_path[-1].distance_to(delivery) < 4.0 and _crosses_open_water(work_pos, haul_path),
		"A loaded hauler finds a route through a ford to the nearer Storage Mound")


func _crosses_open_water(start: Vector3, path: PackedVector3Array) -> bool:
	var nav: RefCounted = _state.valley_nav
	var crossed := false
	var previous := start
	for waypoint in path:
		var samples := maxi(1, ceili(previous.distance_to(waypoint) / 2.0))
		for i in range(1, samples + 1):
			var point := previous.lerp(waypoint, float(i) / float(samples))
			if nav._in_river(point):
				if nav.is_cell_blocked(nav.world_to_cell(point)):
					return false
				crossed = true
		previous = waypoint
	return crossed


func _verify_distant_colony() -> void:
	var faction: Node = _state.faction_controllers[3]
	var count: int = _state.get_faction_buildings(3, "SLEEPING_HUT").size()
	faction._run_rival_leader_ai()
	var huts: Array = _state.get_faction_buildings(3, "SLEEPING_HUT")
	_check(huts.size() > count, "The distant western colony queues a new hut during the Peace Buffer")
	for hut in huts:
		if not hut.is_constructed:
			var camp: Vector3 = _state.factions[3]["camp_position"]
			_check(camp.distance_to(hut.global_position) < _state.valley_layout.settlement_radius,
				"Distant construction stays within the settlement")
			hut.advance_construction(hut.build_time + 0.1)
			_check(hut.is_constructed, "The distant colony's hut can finish construction")


func _verify_map() -> void:
	var hud: Node = _state.hud_controller
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	await process_frame
	var map: Control = hud._world_map
	if not _check(map.visible and hud.blocks_world_input(), "M opens the full-screen map and blocks world input"):
		return
	var location := Vector3(64, 0, -54)
	var rect: Rect2 = map._map_area.get_global_rect()
	var initial: Vector2 = map.world_to_map(location)
	_check(map.map_to_world(initial).is_equal_approx(location), "Default map projection round-trips world coordinates")
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	zoom.position = rect.position + initial
	root.push_input(zoom, true)
	_check(map._zoom > 1.0 and map.world_to_map(location).is_equal_approx(initial), "Wheel zoom keeps the world point under the cursor")
	var grab := InputEventMouseButton.new()
	grab.button_index = MOUSE_BUTTON_RIGHT
	grab.position = rect.position + initial
	grab.pressed = true
	root.push_input(grab, true)
	var drag := InputEventMouseMotion.new()
	drag.position = grab.position + Vector2(24, 18)
	drag.relative = Vector2(24, 18)
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(drag, true)
	grab = grab.duplicate()
	grab.pressed = false
	grab.position = drag.position
	root.push_input(grab, true)
	var projected: Vector2 = map.world_to_map(location)
	_check(not projected.is_equal_approx(initial) and map.map_to_world(projected).is_equal_approx(location),
		"Dragging changes projection and preserves world coordinate parity")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.position + projected
	root.push_input(click, true)
	var marker: Variant = hud.get_world_waypoint()
	_check(marker is Vector3 and marker.is_equal_approx(location), "Click places a waypoint at the projected world point")



func _verify_layout_saves(path: String) -> void:
	var layout: Layout = _state.valley_layout
	var expanded_camp := layout.camp_position(3)
	_check(_state.save_game(path), "Write a v4 expanded save")
	var expanded := FileAccess.get_file_as_string(path)
	var broken: Dictionary = JSON.parse_string(expanded)
	var current_leader: Node = _state.get_faction_leader(0)
	broken["valley_layout_id"] = "missing_layout"
	_write(path, JSON.stringify(broken))
	_check(not _state.load_game(path) and _state.get_faction_leader(0) == current_leader
		and _state.valley_layout.id == Layout.EXPANDED_ID, "An unknown layout cannot replace the live valley")
	_state.start_new_campaign("Enoch", "Classic Valley", GameData.Lineage.CRAG_BORN, Layout.CLASSIC_ID)
	_check(_state.save_game(path), "Write a classic fixture before removing its v4 layout field")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy["version"] = 3
	legacy.erase("valley_layout_id")
	var classic_camp: Vector3 = _state.factions[3]["camp_position"]
	_write(path, expanded)
	_check(_state.load_game(path) and _state.valley_layout.id == Layout.EXPANDED_ID
		and _state.factions[3]["camp_position"] == expanded_camp and _terrain_width() == 760.0,
		"In-session v4 load restores the larger terrain and the saved camp position")
	_verify_caves()
	_write(path, JSON.stringify(legacy))
	_check(_state.load_game(path) and _state.valley_layout.id == Layout.CLASSIC_ID
		and _state.factions[3]["camp_position"] == classic_camp and _terrain_width() == 380.0,
		"A v3 save restores the classic terrain without moving its camps")
	_check(is_equal_approx(_state.player_controller.camera.far, _state.valley_layout.camera_far), "The camera adopts the loaded layout bounds")
	_verify_caves()
	_check(_state.hud_controller.get_world_waypoint() == null, "Loading clears the previous campaign's waypoint")
	DirAccess.remove_absolute(path)


func _terrain_width() -> float:
	var terrain: Node = _state.world_node.get_node("Terrain")
	var collider := terrain.get_child(0).get_child(0) as CollisionShape3D
	return (collider.shape as BoxShape3D).size.x


func _verify_caves() -> void:
	var caves: Array[Vector3] = []
	for resource in _state.resources_container.get_children():
		if resource.get_meta("node_type") == "CAVEMAN_CAVE":
			caves.append(resource.global_position)
	_check(caves == _state.valley_layout.cave_positions, "Loading rebuilds the caves for the selected layout")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "Write the layout fixture"):
		file.store_string(text)


func _check(condition: bool, label: String) -> bool:
	if not condition:
		_failures += 1
		push_error(label)
	return condition

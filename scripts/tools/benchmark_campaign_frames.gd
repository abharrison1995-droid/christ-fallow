extends SceneTree
## Rendered frame intervals and fixed-step simulation timings for seed 17394.

const Layout = preload("res://scripts/core/world_layout.gd")
const SEED := 17394
const SCENARIOS := ["opening", "settlement", "battle-on", "battle-off"]
const WORK_ROLES := [
	GameData.Role.FORAGER, GameData.Role.LUMBERJACK, GameData.Role.STONEKNAPPER,
	GameData.Role.BUILDER_CRAFTER, GameData.Role.FARMER, GameData.Role.HUNTER,
	GameData.Role.TRAINEE,
]

class TickSampler extends Node:
	var began: int
	var samples: Array[float] = []

	func begin() -> void:
		began = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		samples.append((Time.get_ticks_usec() - began) / 1000.0)

var _state: Node


func _initialize() -> void:
	_run.call_deferred()


func _option(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.get_slice("=", 1)
	return fallback


func _setup_settlement(camp: Vector3) -> void:
	var faction: Node = _state.faction_controllers[0]
	var buildings := [
		"CAMPFIRE", "STORAGE_PIT", "FORAGER_LODGE", "BARRACKS", "CRAFTING_PIT",
		"CROP_FIELD", "CROP_FIELD", "CROP_FIELD", "CROP_FIELD", "CROP_FIELD",
		"SLEEPING_HUT", "SLEEPING_HUT", "SLEEPING_HUT", "SLEEPING_HUT",
	]
	for i in range(buildings.size()):
		var angle := TAU * i / buildings.size()
		faction.spawn_building(buildings[i], camp + Vector3(cos(angle), 0, sin(angle)) * 15.0, angle, true)
	for i in range(4):
		faction.spawn_building("PALISADE_WALL", camp + Vector3(25.0, 0, (i - 1.5) * 6.0), 0.0, false)
	_state.factions[0]["is_founded"] = true
	for i in range(105):
		var role: int = WORK_ROLES[i % WORK_ROLES.size()]
		var pos := camp + Vector3((i % 11 - 5) * 2.0, 0.1, (i / 11 - 4) * 2.0)
		faction.spawn_colonist(pos, i % 6, i % 2, role)


func _setup_battle(camp: Vector3) -> void:
	_state.factions[0]["is_founded"] = true
	# Keep the passive player leader clear so defeat cannot end the fight mid-sample.
	var leader: Node = _state.get_faction_leader(0)
	leader.global_position = camp + Vector3(0.0, 0.0, -90.0)
	_state.spatial_index.update_unit(leader)
	for fid in range(4):
		var faction: Node = _state.faction_controllers[fid]
		var lineage: int = _state.get_faction_leader(fid).lineage
		var basis := Basis(Vector3.UP, TAU * fid / 4)
		for i in range(32):
			var grid := Vector3((i % 8 - 3.5) * 2.2, 0.1, 9.0 + (i / 8) * 2.2)
			var warrior: Node = faction.spawn_colonist(camp + basis * grid, lineage, i % 2, GameData.Role.WARRIOR)
			warrior.set_role_and_class(GameData.Role.WARRIOR, i % 5)
			if fid != 0:
				warrior.is_raiding = true
				warrior.raid_target_pos = camp
		for other in range(fid):
			_state.set_diplomatic_state(fid, other, GameData.DiplomaticState.AT_WAR)
	_state.combat_command_system.issue_player_order(GameData.SquadOrder.GUARD_BASE)


func _counts() -> Array:
	return [
		_state.units_container.get_child_count(), _state.buildings_container.get_child_count(),
		_state.wildlife_container.get_child_count(), _state.resources_container.get_child_count(),
	]


func _report_settlement(start_stock: Dictionary) -> void:
	var targets := {}
	var hauling := 0
	var largest_group := 0
	for worker in _state.get_faction_units(0, true):
		hauling += int(worker._carry_amount > 0.0)
		var target: Node = worker._target_node
		if is_instance_valid(target):
			targets[target] = int(targets.get(target, 0)) + 1
			largest_group = maxi(largest_group, targets[target])
	var stock: Dictionary = _state.factions[0]["resources"]
	print("SETTLEMENT hauling=%d largest shared gather target=%d stock delta food/wood/flint/stone=%s" % [
		hauling, largest_group, [stock["food"] - start_stock["food"], stock["wood"] - start_stock["wood"],
			stock["flint"] - start_stock["flint"], stock["stone"] - start_stock["stone"]],
	])


func _percentile(sorted: Array, fraction: float) -> float:
	return sorted[ceili(sorted.size() * fraction) - 1]


func _summarize(label: String, values: Array) -> void:
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	var median: float = sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) / 2.0
	print("%s median=%.3f p95=%.3f p99=%.3f max=%.3f" % [
		label, median, _percentile(sorted, 0.95), _percentile(sorted, 0.99), sorted[-1],
	])


func _measure(scenario: String, frames: int, fixed: bool, sampler: TickSampler) -> bool:
	var viewport := root.get_viewport_rid()
	var elapsed: Array[float] = []
	var physics: Array[float] = []
	var process: Array[float] = []
	var gpu: Array[float] = []
	var render_cpu: Array[float] = []
	var draw_calls: Array[int] = []
	var visible_draws: Array[int] = []
	var shadow_draws: Array[int] = []
	var visible_primitives: Array[int] = []
	var shadow_primitives: Array[int] = []
	var ticks: Array[int] = []
	var start_counts := _counts()
	var start_stock: Dictionary = _state.factions[0]["resources"].duplicate() if scenario == "settlement" else {}
	sampler.samples.clear()
	var last_tick := Engine.get_physics_frames()
	var last_time := Time.get_ticks_usec()
	for i in range(frames):
		if fixed:
			await physics_frame
		else:
			await RenderingServer.frame_post_draw
		if not _state.game_active or _state.is_paused or _state.campaign_finished:
			push_error("Campaign paused or ended while sampling %s." % scenario)
			return false
		var now := Time.get_ticks_usec()
		var tick := Engine.get_physics_frames()
		elapsed.append((now - last_time) / 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		ticks.append(tick - last_tick)
		last_tick = tick
		last_time = now
		if not fixed:
			process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu())
			draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			visible_draws.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			shadow_draws.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			visible_primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
			shadow_primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	print("SCENARIO %s seed=%d layout=%s fixed=%s frames=%d window=%s viewport=%s counts(units/buildings/wildlife/resources)=%s -> %s" % [
		scenario, SEED, _state.valley_layout.id, fixed, frames, root.size, root.get_visible_rect().size, start_counts, _counts(),
	])
	_summarize("physics monitor ms", physics)
	if not sampler.samples.is_empty():
		_summarize("scene physics tick ms", sampler.samples)
	if scenario == "settlement":
		_report_settlement(start_stock)
	if fixed:
		return true
	_summarize("wall frame ms", elapsed)
	_summarize("process monitor ms", process)
	_summarize("viewport GPU ms", gpu)
	_summarize("render CPU ms", render_cpu)
	_summarize("draw calls", draw_calls)
	_summarize("visible draw calls", visible_draws)
	_summarize("shadow draw calls", shadow_draws)
	_summarize("visible primitives", visible_primitives)
	_summarize("shadow primitives", shadow_primitives)
	var over_budget := 0
	for sample in elapsed:
		if sample > 16.7:
			over_budget += 1
	print("budget over 16.7 ms: %d/%d" % [over_budget, frames])
	var sorted := elapsed.duplicate()
	sorted.sort()
	var threshold := _percentile(sorted, 0.95)
	var spikes: Array[String] = []
	for i in range(frames):
		if elapsed[i] >= threshold:
			spikes.append("%d:%.1f/%.1f/%.1f/%.1f/%d" % [i + 1, elapsed[i], gpu[i], render_cpu[i], physics[i], ticks[i]])
	print("p95+ frames (index:wall/GPU/render CPU/physics/ticks) %s" % " ".join(spikes))
	return true


func _run() -> void:
	var selection := _option("--scenario", "opening")
	var frames := int(_option("--samples", "180"))
	var warmup := int(_option("--warmup", "45"))
	var fixed := "--fixed-step" in OS.get_cmdline_user_args()
	var diagnostic := _option("--diagnostic", "")
	var scenarios := [selection]
	if selection == "all":
		scenarios = SCENARIOS
	elif selection == "battle":
		scenarios = ["battle-on", "battle-off"]
	if (selection not in ["all", "battle"] and selection not in SCENARIOS) or frames < 1 or warmup < 1 or (not fixed and DisplayServer.get_name() == "headless"):
		push_error("Use a valid scenario and sample counts. Wall-frame mode requires a display.")
		quit(1)
		return
	_state = root.get_node("GameState")
	for scenario in scenarios:
		if not await _run_scenario(scenario, frames, warmup, fixed, diagnostic):
			quit(1)
			return
	print("CAMPAIGN FRAME BENCHMARK COMPLETE")
	quit()


func _run_scenario(scenario: String, frames: int, warmup: int, fixed: bool, diagnostic: String) -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var sampler := TickSampler.new()
	sampler.process_physics_priority = 1000
	physics_frame.connect(sampler.begin)
	root.add_child(sampler)
	await process_frame
	seed(SEED)
	if not _state.start_new_campaign("Bench Leader", "Bench Tribe", GameData.Lineage.CRAG_BORN, Layout.EXPANDED_ID):
		return false
	var camp: Vector3 = _state.factions[0]["camp_position"]
	if scenario == "settlement":
		_setup_settlement(camp)
	elif scenario.begins_with("battle"):
		_setup_battle(camp)
		if int(_counts()[0]) != 171:
			push_error("The four-faction benchmark requires the full 171-unit setup.")
			return false
	if diagnostic == "freeze-sky":
		_state.world_node.set_process(false)
		print("DIAGNOSTIC frozen world lighting")
	elif diagnostic == "half-resolution":
		root.scaling_3d_scale = 0.5
		print("DIAGNOSTIC half 3D render scale")
	elif diagnostic == "no-sun-shadows":
		_state.world_node._sun_light.shadow_enabled = false
		print("DIAGNOSTIC disabled directional shadows")
	if scenario != "opening":
		var camera := Camera3D.new()
		main.add_child(camera)
		camera.far = _state.valley_layout.camera_far
		var view_center := camp + Vector3(130, 0, 55) if scenario == "battle-off" else camp
		camera.position = view_center + Vector3(0, 50, 20)
		camera.look_at(view_center)
		camera.make_current()
	if fixed:
		RenderingServer.set_render_loop_enabled(false)
	else:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		var camera := root.get_camera_3d()
		print("RENDER %s warmup=%d scale=%s msaa=%d sun_shadows=%s camera=%s forward=%s fov=%s" % [
			scenario, warmup, root.scaling_3d_scale, root.msaa_3d, _state.world_node._sun_light.shadow_enabled,
			camera.global_position, -camera.global_basis.z, camera.fov,
		])
	for i in range(warmup):
		if fixed:
			await physics_frame
		else:
			await RenderingServer.frame_post_draw
	if not await _measure(scenario, frames, fixed, sampler):
		return false
	await process_frame
	_state.end_campaign()
	root.remove_child(sampler)
	sampler.queue_free()
	root.remove_child(main)
	main.queue_free()
	await process_frame
	return true

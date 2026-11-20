extends RefCounted

const Layout = preload("res://scripts/core/world_layout.gd")

const STEP_LOGS := {
	1: "Guide 1/5 complete! Press [B] Build to light your Tribal Campfire.",
	2: "Guide 2/5 complete! Harvest a resource ([E]) & assign a villager role in [C] Colony.",
	3: "Guide 3/5 complete! Build a Sleeping Hut ([B]) and press [E] near it to help finish.",
	4: "Guide 4/5 complete! Test Cleave ([LMB]) and Javelin ([RMB / F]).",
}


static func advance(state) -> void:
	while not state.tutorial_completed and not state.tutorial_skipped and state.factions.has(0):
		var step: int = state.tutorial_step
		if not _reached(state, step):
			return
		if step == 5:
			state.tutorial_completed = true
			state.add_resource(0, "food", 10.0)
			state.add_resource(0, "wood", 10.0)
			state.add_resource(0, "flint", 5.0)
			state.push_log("Awakening Guide complete! Readiness Bonus: +10 Food, +10 Wood, +5 Flint.", "success")
			return
		state.tutorial_step += 1
		state.push_log(STEP_LOGS[step], "success")


static func _reached(state, step: int) -> bool:
	match step:
		1: return recruit_count(state) >= 3
		2: return bool(state.factions[0].get("is_founded", false))
		3: return bool(state.tutorial_harvested) and bool(state.tutorial_assigned_role)
		4: return not state.get_faction_buildings(0, "SLEEPING_HUT", true).is_empty()
		5: return bool(state.tutorial_cleaved) and bool(state.tutorial_thrown)
	return false


static func recruit_count(state) -> int:
	return maxi(state.get_faction_units(0).size() - 1, 0)


static func guard_count(state) -> int:
	var count := 0
	for unit in state.get_faction_units(0):
		if not unit.is_leader and unit.role in [GameData.Role.WARRIOR, GameData.Role.TRAINEE]:
			count += 1
	return count


static func find_pending_building(state, building_type: String, from_pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d2 := INF
	for b in state.get_faction_buildings(0, building_type, false):
		if not is_instance_valid(b) or b.get("is_constructed") == true:
			continue
		var b3d := b as Node3D
		if b3d == null:
			continue
		var d2 := from_pos.distance_squared_to(b3d.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = b3d
	return best


static func get_objective_target(state) -> Dictionary:
	var empty_result := {
		"active": false,
		"step": 0,
		"position": Vector3.ZERO,
		"has_position": false,
		"highlight_hud": "",
		"highlight_building": "",
		"hint": "",
	}
	if state == null or not state.game_active or state.tutorial_completed or state.tutorial_skipped:
		return empty_result
	if not state.factions.has(0):
		return empty_result

	var step: int = int(state.tutorial_step)
	var leader: Node = state.get_faction_leader(0)
	var camp_pos: Vector3 = state.factions[0].get("camp_position", Vector3(0.0, 0.0, 52.0))
	var ref_pos: Vector3 = (leader as Node3D).global_position if is_instance_valid(leader) else camp_pos

	var result := {
		"active": true,
		"step": step,
		"position": Vector3.ZERO,
		"has_position": false,
		"highlight_hud": "",
		"highlight_building": "",
		"hint": "",
	}

	match step:
		1:
			var wanderer: Node3D = _find_nearest_wanderer(state, ref_pos)
			if wanderer != null:
				result["position"] = wanderer.global_position
				result["has_position"] = true
			result["hint"] = "Approach wanderer and press [E] to Recruit (%d/3)" % mini(recruit_count(state), 3)
		2:
			result["position"] = _find_clear_build_spot(state, camp_pos)
			result["has_position"] = true
			result["highlight_hud"] = "BUILD"
			result["highlight_building"] = "CAMPFIRE"
			result["hint"] = "Open [B] Build -> Tribal Campfire -> [LMB] Place"
		3:
			if not bool(state.tutorial_harvested):
				var res_node: Node3D = _find_nearest_resource(state, ref_pos)
				if res_node != null:
					result["position"] = res_node.global_position
					result["has_position"] = true
				result["hint"] = "Approach resource node and press [E] to Harvest"
			else:
				result["hint"] = "Open [C] Colony and assign a villager role"
			if not bool(state.tutorial_assigned_role):
				result["highlight_hud"] = "COLONY"
		4:
			var pending_hut: Node3D = find_pending_building(state, "SLEEPING_HUT", ref_pos)
			if pending_hut != null:
				result["position"] = pending_hut.global_position
				result["has_position"] = true
				result["hint"] = "Approach Sleeping Hut blueprint and press [E] to Help Build"
			elif state.get_faction_buildings(0, "SLEEPING_HUT", true).is_empty():
				result["position"] = _find_clear_build_spot(state, camp_pos)
				result["has_position"] = true
				result["highlight_hud"] = "BUILD"
				result["highlight_building"] = "SLEEPING_HUT"
				result["hint"] = "Open [B] Build -> Sleeping Hut -> [LMB] Place near camp"
		5:
			result["hint"] = "Test [LMB] Heavy Cleave and [F] or [RMB] Throw Javelin"
		_:
			result["active"] = false

	return result


static func _find_nearest_wanderer(state, from_pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d2 := INF
	for u in state.get_faction_units(-1, true):
		if not is_instance_valid(u):
			continue
		var u3d := u as Node3D
		if u3d == null:
			continue
		var d2 := from_pos.distance_squared_to(u3d.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = u3d
	return best


static func _find_nearest_resource(state, from_pos: Vector3) -> Node3D:
	if state.resources_container == null:
		return null
	var best: Node3D = null
	var best_d2 := INF
	for n in state.resources_container.get_children():
		if not is_instance_valid(n):
			continue
		if str(n.get_meta("node_type", "")) == "CAVEMAN_CAVE":
			continue
		var n3d := n as Node3D
		if n3d == null:
			continue
		var d2 := from_pos.distance_squared_to(n3d.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n3d
	return best


static func _find_clear_build_spot(state, center: Vector3) -> Vector3:
	var existing: Array = state.get_faction_buildings(0)
	var candidate_offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, -4.0),
		Vector3(5.0, 0.0, 3.5),
		Vector3(-5.0, 0.0, 3.5),
		Vector3(6.5, 0.0, -2.5),
		Vector3(-6.5, 0.0, -2.5),
		Vector3(0.0, 0.0, 6.5),
		Vector3(9.5, 0.0, 0.0),
		Vector3(-9.5, 0.0, 0.0),
		Vector3(0.0, 0.0, -9.5),
		Vector3(0.0, 0.0, 9.5),
	]
	for offset in candidate_offsets:
		var cand := Vector3(
			clampf(center.x + offset.x, -Layout.BLUEPRINT_HALF_EXTENT, Layout.BLUEPRINT_HALF_EXTENT),
			0.0,
			clampf(center.z + offset.z, -Layout.BLUEPRINT_HALF_EXTENT, Layout.BLUEPRINT_HALF_EXTENT)
		)
		var clear := true
		for b in existing:
			if is_instance_valid(b) and cand.distance_to((b as Node3D).global_position) < 3.4:
				clear = false
				break
		if clear:
			return cand
	return Vector3(
		clampf(center.x + 12.0, -Layout.BLUEPRINT_HALF_EXTENT, Layout.BLUEPRINT_HALF_EXTENT),
		0.0,
		clampf(center.z, -Layout.BLUEPRINT_HALF_EXTENT, Layout.BLUEPRINT_HALF_EXTENT)
	)

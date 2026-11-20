extends RefCounted

const STEP_LOGS := {
	1: "Guide 1/5 complete! Press [B] Build to light your Tribal Campfire.",
	2: "Guide 2/5 complete! Harvest a resource ([E]) & assign a villager role in [C] Colony.",
	3: "Guide 3/5 complete! Assign a Warrior/Trainee & place a 2nd building ([B]).",
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
		2: return state.factions[0].get("is_founded", false)
		3: return state.tutorial_harvested and state.tutorial_assigned_role
		4: return state.get_faction_buildings(0).size() >= 2 and guard_count(state) >= 1
		5: return state.tutorial_cleaved and state.tutorial_thrown
	return false


static func recruit_count(state) -> int:
	return maxi(state.get_faction_units(0).size() - 1, 0)


static func guard_count(state) -> int:
	var count := 0
	for unit in state.get_faction_units(0):
		if not unit.is_leader and unit.role in [GameData.Role.WARRIOR, GameData.Role.TRAINEE]:
			count += 1
	return count

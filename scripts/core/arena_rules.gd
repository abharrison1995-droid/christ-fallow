extends RefCounted
## Blood-Pit Arena rules, bout tiers, eligibility checks, spawning, leashing, and rewards.

const MODE_CHIEFTAIN := "CHIEFTAIN"
const MODE_EXHIBITION := "EXHIBITION"

const PIT_LEASH_RADIUS := 5.0
const BOUT_COOLDOWN := 12.0
const RECOVERY_DURATION := 25.0

const BOUT_TIERS := {
	1: {
		"id": 1,
		"name": "Beasts of the Scrub",
		"summary": "2x Tusked Boar, 1x Dire Wolf",
		"min_fighters": 1,
		"max_fighters": 3,
		"opponents": [
			{"kind": "wildlife", "animal_type": "BOAR", "count": 2},
			{"kind": "wildlife", "animal_type": "WOLF", "count": 1},
		],
		"rewards": {
			"resources": {"food": 25, "hide": 12, "bone": 8},
			"xp": 45,
			"train_xp": 20,
			"gear": [],
			"champion": false,
		},
	},
	2: {
		"id": 2,
		"name": "Bone-Cave Raiders",
		"summary": "2x Cave Brute (T1), 2x Flintmask Scout",
		"min_fighters": 1,
		"max_fighters": 4,
		"opponents": [
			{
				"kind": "human",
				"count": 2,
				"lineage": GameData.Lineage.CAVEMAN,
				"is_caveman": true,
				"warrior_class": GameData.WarriorClass.BRUTE,
				"weapon_tier": 1,
				"archetype": "",
				"weapon_id": "",
				"armor_id": "",
				"melee_rank": 0,
				"ranged_rank": 0,
				"is_arena_champion": false,
				"unit_name": "Bone-Cave Brute",
			},
			{
				"kind": "human",
				"count": 2,
				"lineage": GameData.Lineage.CAVEMAN,
				"is_caveman": true,
				"warrior_class": GameData.WarriorClass.JAVELINEER,
				"weapon_tier": 1,
				"archetype": GameData.FLINTMASK_SCOUT,
				"weapon_id": "",
				"armor_id": "",
				"melee_rank": 0,
				"ranged_rank": 0,
				"is_arena_champion": false,
				"unit_name": "Flintmask Scout",
			},
		],
		"rewards": {
			"resources": {"flint": 18, "stone": 15},
			"xp": 55,
			"train_xp": 30,
			"gear": ["armor", "knives"],
			"champion": false,
		},
	},
	3: {
		"id": 3,
		"name": "Apex Megafauna",
		"summary": "1x Sabertooth Tiger, 1x Slateback Boar, 1x Reedjaw",
		"min_fighters": 1,
		"max_fighters": 4,
		"opponents": [
			{"kind": "wildlife", "animal_type": "SABERTOOTH", "count": 1},
			{"kind": "wildlife", "animal_type": "SLATEBACK_BOAR", "count": 1},
			{"kind": "wildlife", "animal_type": "REEDJAW", "count": 1},
		],
		"rewards": {
			"resources": {"food": 40, "hide": 24, "bone": 20},
			"xp": 80,
			"train_xp": 45,
			"gear": ["pelt_mantle"],
			"champion": true,
		},
	},
	4: {
		"id": 4,
		"name": "Rival Grand Champions",
		"summary": "1x Goliath Champion (T3), 2x Stalker & Ash-Walker Elites (T2)",
		"min_fighters": 1,
		"max_fighters": 4,
		"opponents": [
			{
				"kind": "human",
				"count": 1,
				"lineage": GameData.Lineage.GOLIATH,
				"is_caveman": false,
				"warrior_class": GameData.WarriorClass.BRUTE,
				"weapon_tier": 3,
				"archetype": "",
				"weapon_id": "WAR_CLUB",
				"armor_id": "BONE_GUARD",
				"melee_rank": 3,
				"ranged_rank": 0,
				"is_arena_champion": true,
				"unit_name": "Goliath Grand Champion",
			},
			{
				"kind": "human",
				"count": 1,
				"lineage": GameData.Lineage.STALKER,
				"is_caveman": false,
				"warrior_class": GameData.WarriorClass.ARCHER,
				"weapon_tier": 2,
				"archetype": "",
				"weapon_id": "HUNTING_BOW",
				"armor_id": "HIDE_TUNIC",
				"melee_rank": 1,
				"ranged_rank": 2,
				"is_arena_champion": false,
				"unit_name": "Sun-Stalker Elite",
			},
			{
				"kind": "human",
				"count": 1,
				"lineage": GameData.Lineage.ASH_WALKER,
				"is_caveman": false,
				"warrior_class": GameData.WarriorClass.KNIFE_RAIDER,
				"weapon_tier": 2,
				"archetype": "",
				"weapon_id": "FLINT_DIRK",
				"armor_id": "PELT_MANTLE",
				"melee_rank": 2,
				"ranged_rank": 1,
				"is_arena_champion": false,
				"unit_name": "Ash-Walker Elite",
			},
		],
		"rewards": {
			"resources": {"faith": 25},
			"xp": 110,
			"train_xp": 60,
			"gear": ["obsidian_cleavers"],
			"champion": true,
		},
	},
	5: {
		"id": 5,
		"name": "Titan of the Valley",
		"summary": "1x Giant Cave Bear, 1x Woolly Mammoth",
		"min_fighters": 1,
		"max_fighters": 4,
		"opponents": [
			{"kind": "wildlife", "animal_type": "CAVE_BEAR", "count": 1},
			{"kind": "wildlife", "animal_type": "MAMMOTH", "count": 1},
		],
		"rewards": {
			"resources": {"food": 90, "hide": 30, "bone": 35},
			"xp": 150,
			"train_xp": 85,
			"gear": ["obsidian_plate", "great_spears"],
			"champion": true,
		},
	},
}


static func get_arena_building(game_state) -> Node3D:
	if game_state == null:
		return null
	if game_state.is_arena_bout_active():
		var host: Variant = game_state.arena_bout.get("arena")
		return host as Node3D if _is_available_arena(host) else null
	var leader: Node3D = game_state.get_faction_leader(0)
	var closest: Node3D = null
	var best_dist := INF
	for arena in game_state.get_faction_buildings(0, "ARENA_PIT", true):
		if not _is_available_arena(arena):
			continue
		if leader == null:
			return arena
		var dist: float = leader.global_position.distance_squared_to(arena.global_position)
		if dist < best_dist:
			closest = arena
			best_dist = dist
	return closest


static func _is_available_arena(arena: Variant) -> bool:
	return is_instance_valid(arena) and arena.is_inside_tree() and not arena.is_queued_for_deletion() and not arena.is_destroyed and arena.faction_id == 0


static func is_combatant(entity: Node) -> bool:
	return is_instance_valid(entity) and entity.get("is_arena_combatant") == true


static func is_opponent(entity: Node) -> bool:
	return is_instance_valid(entity) and entity.get("is_arena_opponent") == true


static func is_in_bout(entity: Node) -> bool:
	return is_combatant(entity) or is_opponent(entity)


static func allows_attack(attacker: Node, target: Node) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return false
	if is_combatant(attacker):
		return is_opponent(target)
	if is_opponent(attacker):
		return is_combatant(target)
	return not is_in_bout(target)


static func _get_unit_recovery(unit: Node) -> float:
	if unit == null or not is_instance_valid(unit):
		return 0.0
	var rec: Variant = unit.get("arena_recovery_remaining")
	return maxf(0.0, float(rec)) if rec != null else 0.0


static func _check_fighter_eligibility(unit: Node) -> Dictionary:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return {"ok": false, "reason": "Selected fighter is unavailable."}
	var uname: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else "Fighter"
	if int(unit.get("faction_id")) != 0:
		return {"ok": false, "reason": "%s does not belong to your tribe." % uname}
	if unit.get("is_dead") == true or float(unit.get("hp")) <= 0.0:
		return {"ok": false, "reason": "%s has fallen." % uname}
	if unit.get("is_wounded") == true:
		return {"ok": false, "reason": "%s is wounded." % uname}
	if unit.get("is_child") == true:
		return {"ok": false, "reason": "%s is too young for the Blood-Pit." % uname}
	if unit.get("is_revolting") == true:
		return {"ok": false, "reason": "%s is revolting." % uname}
	var role_id: int = int(unit.get("role"))
	if unit.get("is_leader") != true and role_id not in [GameData.Role.WARRIOR, GameData.Role.TRAINEE]:
		return {"ok": false, "reason": "%s must be a Warrior or Barracks Trainee." % uname}
	var rec := _get_unit_recovery(unit)
	if rec > 0.0:
		return {"ok": false, "reason": "%s is recovering from a knockout (%.0fs)." % [uname, ceilf(rec)]}
	return {"ok": true, "reason": ""}


static func _resolve_fighters(game_state, mode: String, tier_id: int, fighter_ids: Array) -> Dictionary:
	if game_state == null or not game_state.game_active or game_state.campaign_finished:
		return {"ok": false, "reason": "No active campaign.", "fighters": []}
	if game_state.is_paused:
		return {"ok": false, "reason": "Resume the campaign to start an arena bout.", "fighters": []}
	if game_state.is_arena_bout_active():
		return {"ok": false, "reason": "An arena bout is already active.", "fighters": []}
	if float(game_state.arena_cooldown) > 0.0:
		return {"ok": false, "reason": "Blood-Pit Arena is cooling down (%.0fs)." % ceilf(float(game_state.arena_cooldown)), "fighters": []}
	if get_arena_building(game_state) == null:
		return {"ok": false, "reason": "Build a Blood-Pit Arena first.", "fighters": []}
	if not BOUT_TIERS.has(tier_id):
		return {"ok": false, "reason": "Unknown arena bout tier.", "fighters": []}
	if mode != MODE_CHIEFTAIN and mode != MODE_EXHIBITION:
		return {"ok": false, "reason": "Unknown arena bout mode.", "fighters": []}

	var tier_data: Dictionary = BOUT_TIERS[tier_id]
	var max_tier_fighters: int = int(tier_data.get("max_fighters", 4))
	var min_tier_fighters: int = int(tier_data.get("min_fighters", 1))

	var unit_by_id := {}
	for u in game_state.get_faction_units(0, true):
		if is_instance_valid(u) and not u.is_queued_for_deletion():
			unit_by_id[int(u.get("unit_id"))] = u

	var fighters: Array = []
	var seen_ids := {}

	if mode == MODE_CHIEFTAIN:
		var leader: Node = game_state.get_faction_leader(0)
		if leader == null or not is_instance_valid(leader):
			return {"ok": false, "reason": "No living Chieftain available.", "fighters": []}
		var l_check := _check_fighter_eligibility(leader)
		if not bool(l_check["ok"]):
			return {"ok": false, "reason": str(l_check["reason"]), "fighters": []}
		var leader_id: int = int(leader.get("unit_id"))
		seen_ids[leader_id] = true
		fighters.append(leader)

		var guard_limit: int = mini(2, max_tier_fighters - 1)
		var guard_count := 0
		for raw_id in fighter_ids:
			var uid: int = int(raw_id)
			if seen_ids.has(uid):
				continue
			if not unit_by_id.has(uid):
				return {"ok": false, "reason": "Selected guard is unavailable.", "fighters": []}
			var guard: Node = unit_by_id[uid]
			var g_check := _check_fighter_eligibility(guard)
			if not bool(g_check["ok"]):
				return {"ok": false, "reason": str(g_check["reason"]), "fighters": []}
			guard_count += 1
			if guard_count > guard_limit:
				return {"ok": false, "reason": "Chieftain bout allows at most %d guards." % guard_limit, "fighters": []}
			seen_ids[uid] = true
			fighters.append(guard)
		return {"ok": true, "reason": "", "fighters": fighters}

	# MODE_EXHIBITION: 1..4 adult warriors/trainees
	var max_exh: int = mini(4, max_tier_fighters)
	for raw_id in fighter_ids:
		var uid: int = int(raw_id)
		if seen_ids.has(uid):
			continue
		if not unit_by_id.has(uid):
			return {"ok": false, "reason": "Selected fighter is unavailable.", "fighters": []}
		var fighter: Node = unit_by_id[uid]
		var f_check := _check_fighter_eligibility(fighter)
		if not bool(f_check["ok"]):
			return {"ok": false, "reason": str(f_check["reason"]), "fighters": []}
		if fighter.get("is_leader") == true:
			return {"ok": false, "reason": "Use Chieftain Trial to fight with your Chieftain.", "fighters": []}
		seen_ids[uid] = true
		fighters.append(fighter)

	if fighters.size() < min_tier_fighters:
		return {"ok": false, "reason": "Select at least %d Warrior or Trainee." % min_tier_fighters, "fighters": []}
	if fighters.size() > max_exh:
		return {"ok": false, "reason": "Exhibition bout allows at most %d fighters." % max_exh, "fighters": []}
	return {"ok": true, "reason": "", "fighters": fighters}


static func can_start_bout(game_state, mode: String, tier_id: int, fighter_ids: Array) -> Dictionary:
	var res := _resolve_fighters(game_state, mode, tier_id, fighter_ids)
	return {"ok": bool(res["ok"]), "reason": str(res["reason"])}


static func start_bout(game_state, mode: String, tier_id: int, fighter_ids: Array) -> bool:
	var res := _resolve_fighters(game_state, mode, tier_id, fighter_ids)
	if not bool(res["ok"]):
		if game_state != null:
			game_state.push_log(str(res["reason"]), "warning")
		return false

	var fighters: Array = res["fighters"]
	var arena: Node3D = get_arena_building(game_state)
	var arena_pos: Vector3 = arena.global_position

	var pc: Variant = game_state.player_controller
	if is_instance_valid(pc) and mode == MODE_CHIEFTAIN and pc.is_mounted():
		pc.dismount_from(pc.get("_mounted_animal"))

	var combatant_ids: Array = []
	var f_count := fighters.size()
	for idx in range(f_count):
		var fighter: Node = fighters[idx]
		var z_off := _spread_offset(idx, f_count, 1.35)
		var spawn_pos := arena_pos + Vector3(-2.6, 0.0, z_off)
		var fighter_3d := fighter as Node3D
		fighter_3d.global_position = spawn_pos
		if fighter is CharacterBody3D:
			(fighter as CharacterBody3D).velocity = Vector3.ZERO
		fighter.set("is_raiding", false)
		fighter.set("_knockback_vel", Vector3.ZERO)
		fighter.clear_combat_target()
		fighter.set("is_arena_combatant", true)
		fighter_3d.look_at(arena_pos + Vector3(2.6, 0.0, z_off), Vector3.UP)
		game_state.spatial_index.update_unit(fighter_3d)
		combatant_ids.append(int(fighter.get("unit_id")))

	var opponent_specs := _expand_opponents(BOUT_TIERS[tier_id]["opponents"])
	var opponent_nodes: Array = []
	var o_count := opponent_specs.size()
	for idx in range(o_count):
		var spec: Dictionary = opponent_specs[idx]
		var z_off := _spread_offset(idx, o_count, 1.35)
		var spawn_pos := arena_pos + Vector3(2.6, 0.0, z_off)
		var opp: Node3D = _spawn_opponent(game_state, spec, spawn_pos, arena_pos)
		if opp != null:
			opp.look_at(arena_pos + Vector3(-2.6, 0.0, z_off), Vector3.UP)
			opponent_nodes.append(opp)

	game_state.arena_bout = {
		"active": true,
		"arena": arena,
		"mode": mode,
		"tier_id": tier_id,
		"arena_pos": arena_pos,
		"combatant_ids": combatant_ids,
		"opponent_nodes": opponent_nodes,
		"elapsed": 0.0,
	}
	if is_instance_valid(pc):
		pc.set_arena_spectate(mode == MODE_EXHIBITION, arena_pos)

	var sm: Node = game_state.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_ui_sfx("warhorn")
		sm.set_music_state("ARENA", 0.6)

	var tier_name: String = str(BOUT_TIERS[tier_id]["name"])
	game_state.push_log("Blood-Pit Arena bout begun: %s!" % tier_name, "info")
	game_state.arena_state_changed.emit()
	return true


static func _spread_offset(index: int, total: int, spacing: float) -> float:
	if total <= 1:
		return 0.0
	var span := spacing * float(total - 1)
	var max_span := 6.0
	var actual_spacing := spacing if span <= max_span else max_span / float(total - 1)
	return (float(index) - float(total - 1) * 0.5) * actual_spacing


static func _expand_opponents(raw_specs: Array) -> Array:
	var out: Array = []
	for spec in raw_specs:
		var count: int = maxi(1, int(spec.get("count", 1)))
		for _i in range(count):
			out.append(spec)
	return out


static func _spawn_opponent(game_state, spec: Dictionary, pos: Vector3, arena_pos: Vector3) -> Node3D:
	var kind: String = str(spec.get("kind", "wildlife"))
	if kind == "wildlife":
		if game_state.wildlife_container == null:
			return null
		var w_script: Script = load("res://scripts/entities/wildlife_entity.gd")
		var animal := CharacterBody3D.new()
		animal.set_script(w_script)
		game_state.wildlife_container.add_child(animal)
		animal.setup(str(spec.get("animal_type", "BOAR")), pos)
		animal.is_aggro = true
		animal.flees_when_hit = false
		animal.home_pos = arena_pos
		animal.set("is_arena_opponent", true)
		game_state.spatial_index.update_wildlife(animal)
		return animal

	if game_state.units_container == null:
		return null
	var u_script: Script = load("res://scripts/entities/human_unit.gd")
	var unit := CharacterBody3D.new()
	unit.set_script(u_script)
	game_state.units_container.add_child(unit)
	var armor_id: String = str(spec.get("armor_id", ""))
	var is_champ: bool = bool(spec.get("is_arena_champion", false))
	unit.setup({
		"faction_id": 5,
		"original_faction_id": 5,
		"pos": pos,
		"lineage": int(spec.get("lineage", GameData.Lineage.CAVEMAN)),
		"gender": GameData.Gender.MALE,
		"role": GameData.Role.WARRIOR,
		"warrior_class": int(spec.get("warrior_class", GameData.WarriorClass.BRUTE)),
		"is_leader": false,
		"is_player_controlled": false,
		"is_caveman": bool(spec.get("is_caveman", false)),
		"archetype": str(spec.get("archetype", "")),
		"weapon_tier": int(spec.get("weapon_tier", 1)),
		"has_equipped_weapon": true,
		"has_armor": (armor_id != "" and armor_id != "NONE"),
		"equipped_weapon_id": str(spec.get("weapon_id", "")),
		"equipped_armor_id": armor_id,
		"melee_rank": int(spec.get("melee_rank", 0)),
		"ranged_rank": int(spec.get("ranged_rank", 0)),
		"is_arena_champion": is_champ,
		"unit_name": str(spec.get("unit_name", "")),
	})
	unit.set("is_arena_champion", is_champ)
	unit.set("is_arena_opponent", true)
	if unit.has_method("recalculate_stats"):
		unit.recalculate_stats(true)
	game_state.spatial_index.update_unit(unit)
	return unit


static func _find_unit_by_id(game_state, uid: int) -> Node:
	if game_state == null or game_state.units_container == null:
		return null
	for u in game_state.units_container.get_children():
		if is_instance_valid(u) and not u.is_queued_for_deletion() and int(u.get("unit_id")) == uid:
			return u
	return null


static func _is_combatant_ko(fighter: Node) -> bool:
	if fighter == null or not is_instance_valid(fighter) or fighter.is_queued_for_deletion():
		return true
	if fighter.get("is_dead") == true or float(fighter.get("hp")) <= 0.0 or fighter.get("is_wounded") == true:
		return true
	if "is_arena_combatant" in fighter and fighter.get("is_arena_combatant") != true:
		return true
	if _get_unit_recovery(fighter) > 0.0:
		return true
	return false


static func _leash_to_pit(node: Node3D, arena_pos: Vector3, max_radius: float = PIT_LEASH_RADIUS) -> void:
	if node == null or not is_instance_valid(node):
		return
	var offset := node.global_position - arena_pos
	offset.y = 0.0
	var dist_sq := offset.length_squared()
	if dist_sq > max_radius * max_radius:
		var dir := offset.normalized()
		node.global_position = Vector3(arena_pos.x + dir.x * max_radius, node.global_position.y, arena_pos.z + dir.z * max_radius)
		if node is CharacterBody3D:
			var body := node as CharacterBody3D
			var v_xz := Vector3(body.velocity.x, 0.0, body.velocity.z)
			if v_xz.dot(dir) > 0.0:
				body.velocity.x = 0.0
				body.velocity.z = 0.0


static func count_living_opponents(bout: Dictionary) -> int:
	var count := 0
	var opp_nodes: Array = bout.get("opponent_nodes", [])
	for opp in opp_nodes:
		if is_instance_valid(opp) and not opp.is_queued_for_deletion() and opp.get("is_dead") != true and float(opp.get("hp")) > 0.0:
			count += 1
	return count


static func tick_bout(game_state, delta: float) -> void:
	if game_state == null:
		return
	if float(game_state.arena_cooldown) > 0.0:
		game_state.arena_cooldown = maxf(0.0, float(game_state.arena_cooldown) - delta)

	if not game_state.is_arena_bout_active():
		return

	if get_arena_building(game_state) == null:
		forfeit_bout(game_state)
		return

	var bout: Dictionary = game_state.arena_bout
	bout["elapsed"] = float(bout.get("elapsed", 0.0)) + delta
	var arena_pos: Vector3 = bout.get("arena_pos", Vector3.ZERO)

	var living_opponents := 0
	var opp_nodes: Array = bout.get("opponent_nodes", [])
	for opp in opp_nodes:
		if is_instance_valid(opp) and not opp.is_queued_for_deletion() and opp.get("is_dead") != true and float(opp.get("hp")) > 0.0:
			living_opponents += 1
			_leash_to_pit(opp as Node3D, arena_pos)
			if opp.get("animal_type") != null:
				game_state.spatial_index.update_wildlife(opp as Node3D)
			else:
				game_state.spatial_index.update_unit(opp as Node3D)

	var active_combatants := 0
	var c_ids: Array = bout.get("combatant_ids", [])
	for raw_id in c_ids:
		var fighter: Node = _find_unit_by_id(game_state, int(raw_id))
		if fighter == null:
			continue
		if _is_combatant_ko(fighter):
			if is_combatant(fighter):
				fighter.set("is_arena_combatant", false)
				fighter.clear_combat_target()
			continue
		active_combatants += 1
		_leash_to_pit(fighter as Node3D, arena_pos)
		game_state.spatial_index.update_unit(fighter as Node3D)

	if living_opponents <= 0:
		resolve_bout(game_state, true)
	elif active_combatants <= 0:
		resolve_bout(game_state, false)


static func _clear_references_to_opponents(game_state, opp_nodes: Array) -> void:
	if game_state == null or game_state.units_container == null or opp_nodes.is_empty():
		return
	for u in game_state.units_container.get_children():
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		for prop in ["_target_node", "_self_defense_target", "_scan_enemy", "_scan_wild"]:
			var ref_val: Variant = u.get(prop)
			if typeof(ref_val) != TYPE_NIL and (not is_instance_valid(ref_val) or opp_nodes.has(ref_val)):
				u.set(prop, null)


static func forfeit_bout(game_state) -> void:
	if game_state == null or not game_state.is_arena_bout_active():
		return
	resolve_bout(game_state, false, true)


static func resolve_bout(game_state, player_won: bool, forfeited: bool = false) -> void:
	if game_state == null or not game_state.is_arena_bout_active():
		return

	var bout: Dictionary = game_state.arena_bout
	game_state.arena_bout = {}

	var opp_nodes: Array = bout.get("opponent_nodes", [])
	var c_ids: Array = bout.get("combatant_ids", [])
	_clear_references_to_opponents(game_state, opp_nodes)
	var projectiles: Node = game_state.projectiles_container
	if is_instance_valid(projectiles):
		for shot in projectiles.get_children():
			if shot.get("is_arena_shot") == true:
				projectiles.remove_child(shot)
				shot.queue_free()

	for opp in opp_nodes:
		if not is_instance_valid(opp) or opp.is_queued_for_deletion():
			continue
		if opp.get("is_dead") != true:
			if opp.has_method("_unregister_from_index"):
				opp._unregister_from_index()
			if opp is Node3D:
				(opp as Node3D).hide()
			if opp.get_parent() != null:
				opp.get_parent().remove_child(opp)
			opp.queue_free()

	var tier_id: int = int(bout.get("tier_id", 1))
	var tier_data: Dictionary = BOUT_TIERS.get(tier_id, {})
	var rewards: Dictionary = tier_data.get("rewards", {})
	var train_xp: float = float(rewards.get("train_xp", 0.0))
	var grants_champion: bool = bool(rewards.get("champion", false))

	for raw_id in c_ids:
		var fighter: Node = _find_unit_by_id(game_state, int(raw_id))
		if fighter == null:
			continue
		fighter.set("is_arena_combatant", false)
		fighter.clear_combat_target()
		if player_won and fighter.get("is_dead") != true:
			if train_xp > 0.0:
				var unit_ai: Script = load("res://scripts/entities/unit_ai_routines.gd")
				if unit_ai != null:
					unit_ai.gain_training_xp(fighter, train_xp)
			if grants_champion and fighter.get("is_child") != true and fighter.get("is_caveman") != true:
				fighter.set("is_arena_champion", true)
			if fighter.has_method("recalculate_stats"):
				fighter.recalculate_stats(false)

	var pc: Variant = game_state.player_controller
	if is_instance_valid(pc):
		pc.set_arena_spectate(false)

	if player_won:
		var res_rewards: Dictionary = rewards.get("resources", {})
		for res_key in res_rewards.keys():
			game_state.add_resource(0, str(res_key), float(res_rewards[res_key]))
		var xp_amt: float = float(rewards.get("xp", 0.0))
		if xp_amt > 0.0:
			game_state.award_xp(0, xp_amt, "Arena Victory")
		var gear_list: Array = rewards.get("gear", [])
		if not gear_list.is_empty() and game_state.factions.has(0):
			var stock: Dictionary = game_state.factions[0].get("stockpile", {})
			for gear_key in gear_list:
				var gk := str(gear_key)
				stock[gk] = int(stock.get(gk, 0)) + 1
			game_state.resources_changed.emit(0)
		var tier_name: String = str(tier_data.get("name", "Arena Bout"))
		game_state.push_log("Victory in Blood-Pit Arena (%s)! +%d Tribal XP." % [tier_name, int(xp_amt)], "success")
	else:
		if forfeited:
			game_state.push_log("Blood-Pit Arena bout forfeited.", "warning")
		else:
			game_state.push_log("Your fighters were knocked out in the Blood-Pit Arena!", "warning")

	game_state.arena_cooldown = BOUT_COOLDOWN
	game_state._combat_music_timer = 0.0
	game_state._sync_campaign_music(0.8)

	var sm: Node = game_state.get_node_or_null("/root/SoundManager")
	if sm != null:
		if player_won:
			sm.play_ui_sfx("level_up")
		else:
			sm.play_ui_sfx("ui_click")

	game_state.arena_state_changed.emit()

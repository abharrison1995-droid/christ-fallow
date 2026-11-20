extends Node

var faction_id: int = 0
var _ai_timer: float = 0.0
var _raid_cooldown: float = 45.0
var _caveman_spawn_timer: float = 28.0
var _diplomacy_event_cd: float = 35.0


func setup(p_faction_id: int) -> void:
	faction_id = p_faction_id
	_ai_timer = randf_range(1.5, 4.0)
	_raid_cooldown = randf_range(50.0, 85.0)
	_diplomacy_event_cd = randf_range(35.0, 65.0)
	if faction_id == 5:
		_caveman_spawn_timer = 32.0


func spawn_colonist(pos: Vector3, lineage: int, gender: int, role: int, is_leader: bool = false, is_child: bool = false, is_caveman: bool = false, custom_name: String = "") -> Node:
	if GameState.units_container == null:
		return null
	var u_script := load("res://scripts/entities/human_unit.gd")
	var unit := CharacterBody3D.new()
	unit.set_script(u_script)
	GameState.units_container.add_child(unit)

	var specialty := GameData.WarriorClass.SPEARMAN
	var tier := 1
	if GameState.factions.has(faction_id):
		specialty = int(GameState.factions[faction_id].get("weapon_specialty", GameData.WarriorClass.SPEARMAN))
		tier = int(GameState.factions[faction_id].get("tech_tier", 1))

	unit.setup({
		"faction_id": faction_id,
		"pos": pos,
		"lineage": lineage,
		"gender": gender,
		"role": role,
		"warrior_class": specialty,
		"is_leader": is_leader,
		"is_player_controlled": (faction_id == 0 and is_leader),
		"is_child": is_child,
		"is_caveman": is_caveman,
		"weapon_tier": tier,
		"has_equipped_weapon": (role == GameData.Role.WARRIOR or is_leader or is_caveman),
		"has_armor": is_leader,
		"unit_name": custom_name,
	})
	return unit


func spawn_building(b_type: String, pos: Vector3, rot_y: float = 0.0, constructed: bool = true) -> Node:
	if GameState.buildings_container == null:
		return null
	var b_script := load("res://scripts/entities/building_entity.gd")
	var b := StaticBody3D.new()
	b.set_script(b_script)
	GameState.buildings_container.add_child(b)
	b.setup(b_type, faction_id, pos, rot_y, constructed)
	return b


func handle_player_leader_death(dead_leader: Node) -> void:
	if faction_id != 0 or GameState.campaign_finished:
		return
	var candidates := []
	for u in GameState.get_faction_units(0, true):
		if u == dead_leader or u.get("is_dead"):
			continue
		candidates.append(u)

	if candidates.is_empty():
		GameState.check_victory_conditions()
		return

	# Prefer adult warriors, then any adult colonist
	var successor: Node = candidates[0]
	for c in candidates:
		if not c.get("is_child") and c.get("role") == GameData.Role.WARRIOR:
			successor = c
			break
		elif not c.get("is_child") and successor.get("is_child"):
			successor = c

	successor.promote_to_player_leader()
	if GameState.player_controller != null:
		GameState.player_controller.attach_leader(successor)
	GameState.leader_succeeded.emit(successor.unit_name)
	GameState.push_log("Your Leader fell! %s rises by Tribal Succession to lead the colony." % successor.unit_name, "warning")


func queue_craft(item_key: String) -> bool:
	if not GameState.factions.has(faction_id):
		return false
	if not GameState.has_building(faction_id, "CRAFTING_PIT", true):
		if faction_id == 0:
			GameState.push_log("Build a Flint-Knapping & Crafting Pit first!", "warning")
		return false
	var recipe: Dictionary = GameData.CRAFT_RECIPES.get(item_key, {})
	if recipe.is_empty():
		return false
	if not GameState.spend_resources(faction_id, recipe["costs"]):
		if faction_id == 0:
			GameState.push_log("Insufficient materials to craft %s." % recipe["name"], "warning")
		return false
	GameState.factions[faction_id]["craft_queue"].append(item_key)
	if faction_id == 0:
		GameState.push_log("Queued %s at the Crafting Pit." % recipe["name"], "info")
	return true


func upgrade_stone_age_tier() -> bool:
	if not GameState.factions.has(faction_id):
		return false
	var fdata: Dictionary = GameState.factions[faction_id]
	var cur_tier := int(fdata.get("tech_tier", 1))
	if cur_tier >= 3:
		return false
	if not GameState.has_building(faction_id, "CRAFTING_PIT", true):
		if faction_id == 0:
			GameState.push_log("Build a Crafting Pit to advance Stone Age Gear!", "warning")
		return false
	var next_tier := cur_tier + 1
	var costs: Dictionary = GameData.TIER_UPGRADE_COSTS[next_tier]
	if not GameState.spend_resources(faction_id, costs):
		if faction_id == 0:
			GameState.push_log("Not enough resources for %s!" % GameData.TECH_TIER_NAMES[next_tier], "warning")
		return false

	fdata["tech_tier"] = next_tier
	for u in GameState.get_faction_units(faction_id, true):
		u.weapon_tier = next_tier
		u.recalculate_stats(false)
	if faction_id == 0:
		GameState.resources_changed.emit(0)
		GameState.push_log("Unlocked %s!" % GameData.TECH_TIER_NAMES[next_tier], "success")
	return true


func _process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return
	if faction_id == 0:
		return
	if not GameState.factions.has(faction_id) or GameState.factions[faction_id]["is_defeated"]:
		return

	if faction_id == 5:
		_process_caveman_faction(delta)
		return

	_ai_timer -= delta
	_raid_cooldown = maxf(0.0, _raid_cooldown - delta)
	_diplomacy_event_cd = maxf(0.0, _diplomacy_event_cd - delta)
	if _ai_timer <= 0.0:
		_ai_timer = 5.0
		_run_rival_leader_ai()


func _process_caveman_faction(delta: float) -> void:
	if GameState.is_raid_grace_active():
		_caveman_spawn_timer = 12.0
		return
	_caveman_spawn_timer -= delta
	if _caveman_spawn_timer > 0.0:
		return
	_caveman_spawn_timer = 46.0

	var current_cavemen := GameState.get_faction_units(5, true)
	if current_cavemen.size() >= 10:
		return

	# Spawn a feral raid pack from one of the caveman caves
	var caves := []
	if GameState.resources_container != null:
		for n in GameState.resources_container.get_children():
			if is_instance_valid(n) and n.get_meta("node_type", "") == "CAVEMAN_CAVE":
				caves.append(n)
	if caves.is_empty():
		return

	var cave: Node = caves[randi() % caves.size()]
	var pack_size := randi_range(2, 3)
	for i in range(pack_size):
		var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		spawn_colonist(cave.global_position + offset, GameData.Lineage.CAVEMAN, GameData.Gender.MALE, GameData.Role.WARRIOR, false, false, true)

	if GameState.factions.has(0) and GameState.factions[0]["is_founded"]:
		var msg := "Nomadic Cavemen emerged from a bone-cave and are prowling for a raid!"
		GameState.raid_alert.emit(5, 0, msg)


func _run_rival_leader_ai() -> void:
	var fdata: Dictionary = GameState.factions[faction_id]
	if not bool(fdata.get("is_founded", false)):
		return
	var units: Array = GameState.get_faction_units(faction_id, true)
	if units.is_empty():
		return

	var camp: Vector3 = fdata["camp_position"]

	# 0. Home-Defense Recall if hostile units threaten camp
	var home_under_attack := false
	if GameState.units_container != null:
		for other_u in GameState.units_container.get_children():
			if is_instance_valid(other_u) and not other_u.get("is_dead"):
				var o_fid: int = int(other_u.get("faction_id"))
				if o_fid >= 0 and GameState.is_hostile(faction_id, o_fid):
					if (other_u as Node3D).global_position.distance_to(camp) <= 28.0:
						home_under_attack = true
						break
	if home_under_attack:
		for u in units:
			if u.get("is_raiding"):
				u.is_raiding = false

	# 1. Dynamic Economy, Combined-Arms & Auto-Equip
	var adults := []
	for u in units:
		if not u.get("is_leader") and not u.get("is_child"):
			adults.append(u)

	var desired_warriors: int = maxi(3, int(float(adults.size()) * 0.45))
	var sig_class: int = int(fdata["weapon_specialty"])
	var comp_class: int = GameData.WarriorClass.JAVELINEER if sig_class == GameData.WarriorClass.ARCHER else GameData.WarriorClass.ARCHER
	var heavy_class: int = GameData.WarriorClass.BRUTE if (sig_class == GameData.WarriorClass.SPEARMAN or sig_class == GameData.WarriorClass.KNIFE_RAIDER) else GameData.WarriorClass.SPEARMAN

	var warriors := []
	var civilians := []
	for u in adults:
		if u.get("role") == GameData.Role.WARRIOR:
			warriors.append(u)
		else:
			civilians.append(u)

	while warriors.size() < desired_warriors and not civilians.is_empty():
		var recruit: Node = civilians.pop_back()
		var target_cls: int = sig_class
		if warriors.size() % 4 == 2:
			target_cls = comp_class
		elif warriors.size() % 4 == 3:
			target_cls = heavy_class
		recruit.set_role_and_class(GameData.Role.WARRIOR, target_cls)
		warriors.append(recruit)

	# Re-equip all AI warriors from stockpile when new weapons/armor are forged
	for w in warriors:
		w.try_equip_from_stockpile()

	# Allocate civilians dynamically based on colony needs
	var food_amt: float = float(fdata["resources"].get("food", 0.0))
	var has_totem: bool = GameState.has_building(faction_id, "SACRED_TOTEM", true)
	var has_bp := false
	for b in GameState.get_faction_buildings(faction_id, "", false):
		if not b.get("is_constructed"):
			has_bp = true
			break
	var need_builders: int = 2 if (has_bp or not fdata["craft_queue"].is_empty()) else 1
	var need_food_workers: int = maxi(2, int(ceilf(float(civilians.size()) * (0.50 if food_amt < 30.0 else 0.34))))
	var need_shaman: int = 1 if (has_totem and civilians.size() >= 3) else 0

	var assigned_food := 0
	var assigned_builder := 0
	var assigned_shaman := 0
	var wood_stone_toggle := 0

	for civ in civilians:
		if assigned_food < need_food_workers:
			var f_role: int = GameData.Role.HUNTER if (assigned_food % 2 == 1) else GameData.Role.FORAGER
			if civ.get("role") != f_role:
				civ.set_role_and_class(f_role)
			assigned_food += 1
		elif assigned_shaman < need_shaman:
			if civ.get("role") != GameData.Role.SHAMAN:
				civ.set_role_and_class(GameData.Role.SHAMAN)
			assigned_shaman += 1
		elif assigned_builder < need_builders:
			if civ.get("role") != GameData.Role.BUILDER_CRAFTER:
				civ.set_role_and_class(GameData.Role.BUILDER_CRAFTER)
			assigned_builder += 1
		else:
			var ws_role: int = GameData.Role.LUMBERJACK if (wood_stone_toggle % 2 == 0) else GameData.Role.STONEKNAPPER
			if civ.get("role") != ws_role:
				civ.set_role_and_class(ws_role)
			wood_stone_toggle += 1

	# 2. Construct new buildings around AI camp
	var huts := GameState.get_faction_buildings(faction_id, "SLEEPING_HUT", false)
	if huts.size() < 4 and GameState.can_afford(faction_id, GameData.BUILDINGS["SLEEPING_HUT"]["costs"]):
		GameState.spend_resources(faction_id, GameData.BUILDINGS["SLEEPING_HUT"]["costs"])
		var ang := randf_range(0.0, TAU)
		spawn_building("SLEEPING_HUT", camp + Vector3(cos(ang) * 11.0, 0.0, sin(ang) * 11.0), ang, false)
	elif GameState.get_faction_buildings(faction_id, "WATCHTOWER", false).size() < 2 and GameState.can_afford(faction_id, GameData.BUILDINGS["WATCHTOWER"]["costs"]):
		GameState.spend_resources(faction_id, GameData.BUILDINGS["WATCHTOWER"]["costs"])
		var ang := randf_range(0.0, TAU)
		spawn_building("WATCHTOWER", camp + Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 15.0), ang, false)

	# 3. Craft & tech upgrade (Weapons + Armor)
	if int(fdata["tech_tier"]) < 3 and GameState.day_count >= (int(fdata["tech_tier"]) * 2):
		upgrade_stone_age_tier()
	var spec_key := "spears"
	if sig_class == GameData.WarriorClass.KNIFE_RAIDER:
		spec_key = "knives"
	elif sig_class == GameData.WarriorClass.ARCHER:
		spec_key = "bows"
	elif sig_class == GameData.WarriorClass.BRUTE:
		spec_key = "clubs"
	elif sig_class == GameData.WarriorClass.JAVELINEER:
		spec_key = "javelins"
	if fdata["craft_queue"].size() < 2:
		if int(fdata["stockpile"].get("armor", 0)) < desired_warriors and GameState.can_afford(faction_id, GameData.CRAFT_RECIPES["armor"]["costs"]):
			queue_craft("armor")
		elif GameState.can_afford(faction_id, GameData.CRAFT_RECIPES[spec_key]["costs"]):
			queue_craft(spec_key)

	# 4. Proactive AI Envoy Events toward Player
	if _diplomacy_event_cd <= 0.0 and GameState.factions.has(0) and bool(GameState.factions[0]["is_founded"]):
		_diplomacy_event_cd = randf_range(50.0, 80.0)
		var p_op: int = GameState.get_diplomatic_opinion(faction_id, 0)
		var p_state: int = GameState.get_diplomatic_state(faction_id, 0)
		var personality_val: int = int(fdata["ai_personality"])
		if p_state == GameData.DiplomaticState.NEUTRAL and p_op >= 40:
			GameState.add_resource(0, "food", 10.0)
			GameState.modify_opinion(0, faction_id, 5)
			GameState.push_log("%s (%s) sent a friendly envoy with +10 Food!" % [fdata["leader_name"], fdata["name"]], "success")
		elif p_state == GameData.DiplomaticState.NEUTRAL and p_op <= -30 and (personality_val == GameData.AIPersonality.WARLORD or personality_val == GameData.AIPersonality.ZEALOT):
			GameState.push_log("%s warns your tribe: 'Guard your palisades — war approaches!'" % fdata["leader_name"], "warning")

	# 5. AI-vs-AI & Player Diplomacy + Distinct Personality Raids
	if _raid_cooldown > 0.0 or home_under_attack or GameState.is_raid_grace_active():
		return

	var personality: int = int(fdata["ai_personality"])
	var target_fid := _pick_ai_target(personality)
	if target_fid >= 0:
		if GameState.get_diplomatic_state(faction_id, target_fid) != GameData.DiplomaticState.AT_WAR:
			GameState.set_diplomatic_state(faction_id, target_fid, GameData.DiplomaticState.AT_WAR)
		launch_raid_against(target_fid)
		_raid_cooldown = 75.0 if personality != GameData.AIPersonality.OPPORTUNIST else 55.0


func _pick_ai_target(personality: int) -> int:
	var best_target := -1
	var best_score := -9999.0

	for other_id in range(7):
		if other_id == faction_id or other_id == 5:
			continue
		if not GameState.factions.has(other_id):
			continue
		var other: Dictionary = GameState.factions[other_id]
		if other["is_defeated"] or not other["is_founded"]:
			continue
		if GameState.get_diplomatic_state(faction_id, other_id) == GameData.DiplomaticState.ALLIED:
			continue

		var op := GameState.get_diplomatic_opinion(faction_id, other_id)
		var other_pow := GameState.get_faction_military_power(other_id)
		var score := float(-op)
		if faction_id == 6 and other_id == 0:
			score += 120.0

		match personality:
			GameData.AIPersonality.WARLORD:
				score += (200.0 - other_pow) * 0.6
			GameData.AIPersonality.ZEALOT:
				# Strongly targets opposing religious tenets or negative opinion
				if op < 10:
					score += 45.0
				else:
					score -= 80.0
			GameData.AIPersonality.OPPORTUNIST:
				# Strikes when enemy's leader & army are far from their camp!
				var other_leader := GameState.get_faction_leader(other_id)
				if other_leader != null:
					var dist_from_camp: float = other_leader.global_position.distance_to(other["camp_position"])
					if dist_from_camp > 28.0:
						score += 95.0
			GameData.AIPersonality.GUARDIAN:
				# Only attacks if actively at war or deeply provoked
				if GameState.get_diplomatic_state(faction_id, other_id) != GameData.DiplomaticState.AT_WAR and op > -45:
					score -= 150.0

		if score > 25.0 and score > best_score:
			best_score = score
			best_target = other_id

	return best_target


func launch_raid_against(target_fid: int) -> void:
	if not GameState.factions.has(target_fid):
		return
	var target_camp: Vector3 = GameState.factions[target_fid]["camp_position"]
	var raiders_sent := 0
	for u in GameState.get_faction_units(faction_id, true):
		if u.get("role") == GameData.Role.WARRIOR and not u.get("is_leader"):
			if raiders_sent < 5:
				u.is_raiding = true
				u.raid_target_pos = target_camp
				raiders_sent += 1

	if raiders_sent > 0:
		var attacker_name: String = GameState.factions[faction_id]["name"]
		var leader_name: String = GameState.factions[faction_id]["leader_name"]
		var target_name: String = GameState.factions[target_fid]["name"]
		var msg := "RAID ALERT: %s (%s) sent %d warriors against %s!" % [leader_name, attacker_name, raiders_sent, target_name]
		GameState.raid_alert.emit(faction_id, target_fid, msg)
		if target_fid == 0:
			GameState.push_log(msg, "danger")
		else:
			GameState.push_log("%s is marching on %s!" % [attacker_name, target_name], "info")

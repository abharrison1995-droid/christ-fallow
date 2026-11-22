extends RefCounted
## Diplomacy, opinion scoring, tribute delivery, rebel founding, leader succession,
## conquest resolution, and valley victory/defeat evaluation for GameState.

const Layout = preload("res://scripts/core/world_layout.gd")


static func initialize_diplomacy(state: Node) -> void:
	# Initialize diplomacy pairs (0..4)
	for a in range(5):
		for b in range(a + 1, 5):
			var key := get_diplomatic_key(a, b)
			var base_mod := 0
			if a == 0 or b == 0:
				var other := b if a == 0 else a
				if other == 1:
					base_mod = -10
				elif other == 4:
					base_mod = 12
			state.diplomacy[key] = {
				"state": GameData.DiplomaticState.NEUTRAL,
				"opinion_mod": base_mod,
				"truce_timer": 0.0,
			}

	# Faction 5 (Nomadic Cavemen) is permanently at war with everyone
	for a in range(5):
		var fkey := get_diplomatic_key(a, 5)
		state.diplomacy[fkey] = {
			"state": GameData.DiplomaticState.AT_WAR,
			"opinion_mod": -100,
			"truce_timer": 0.0,
		}

	# Faction 6 (Outcast Rebels) starts at war with Player (0) and neutral to rivals
	for a in range(5):
		var rkey := get_diplomatic_key(a, 6)
		state.diplomacy[rkey] = {
			"state": GameData.DiplomaticState.AT_WAR if a == 0 else GameData.DiplomaticState.NEUTRAL,
			"opinion_mod": -100 if a == 0 else 0,
			"truce_timer": 0.0,
		}
	state.diplomacy[get_diplomatic_key(5, 6)] = {
		"state": GameData.DiplomaticState.AT_WAR,
		"opinion_mod": -100,
		"truce_timer": 0.0,
	}


static func on_new_day(state: Node) -> void:
	var treaty_changed := false
	for key in state.diplomacy.keys():
		var rel: Dictionary = state.diplomacy[key]
		if float(rel["truce_timer"]) > 0.0:
			rel["truce_timer"] = maxf(0.0, float(rel["truce_timer"]) - 1.0)
			treaty_changed = true
	for faction_id in [1, 2, 3, 4, 6]:
		if is_settled_rival(state, faction_id):
			state.award_xp(faction_id, 55.0, "Daily development")
			if get_diplomatic_state(state, 0, faction_id) == GameData.DiplomaticState.TRIBUTARY:
				deliver_tribute(state, faction_id)
	if treaty_changed:
		state.diplomacy_changed.emit()


static func deliver_tribute(state: Node, faction_id: int) -> void:
	var stock: Dictionary = state.factions[faction_id]["resources"]
	var food := clampf(float(stock["food"]), 0.0, 8.0)
	var flint := clampf(float(stock["flint"]), 0.0, 3.0)
	if food <= 0.0 and flint <= 0.0:
		return
	state.spend_resources(faction_id, {"food": food, "flint": flint})
	state.add_resource(0, "food", food)
	state.add_resource(0, "flint", flint)
	state.push_log("%s delivered %.0f Food and %.0f Flint in tribute." % [state.factions[faction_id]["name"], food, flint], "success")


static func get_diplomatic_key(a: int, b: int) -> String:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return "%d_%d" % [lo, hi]


static func get_diplomatic_state(state: Node, a: int, b: int) -> int:
	if a == b:
		return GameData.DiplomaticState.ALLIED
	if a == 5 or b == 5:
		return GameData.DiplomaticState.AT_WAR
	var key := get_diplomatic_key(a, b)
	if state.diplomacy.has(key):
		return int(state.diplomacy[key]["state"])
	return GameData.DiplomaticState.NEUTRAL


static func get_truce_days(state: Node, a: int, b: int) -> float:
	var relation: Dictionary = state.diplomacy.get(get_diplomatic_key(a, b), {})
	return float(relation.get("truce_timer", 0.0))


static func has_truce(state: Node, a: int, b: int) -> bool:
	return get_truce_days(state, a, b) > 0.0


static func begin_truce(state: Node, a: int, b: int) -> void:
	if not set_diplomatic_state(state, a, b, GameData.DiplomaticState.NEUTRAL):
		return
	state.diplomacy[get_diplomatic_key(a, b)]["truce_timer"] = 2.0
	for pair in [[a, b], [b, a]]:
		var camp: Vector3 = state.factions[int(pair[1])]["camp_position"]
		for unit in state.get_faction_units(int(pair[0]), true):
			if unit.is_raiding and unit.raid_target_pos.is_equal_approx(camp):
				unit.is_raiding = false
	state.diplomacy_changed.emit()


static func is_treaty_ally(state: Node, a: int, b: int) -> bool:
	return get_diplomatic_state(state, a, b) in [GameData.DiplomaticState.ALLIED, GameData.DiplomaticState.TRIBUTARY]


static func is_settled_rival(state: Node, faction_id: int) -> bool:
	var faction: Dictionary = state.factions.get(faction_id, {})
	return faction_id in [1, 2, 3, 4, 6] and faction.get("is_founded") == true and faction.get("is_defeated") != true


static func nearby_rival_leader(state: Node, origin: Vector3) -> Node:
	var nearest: Node = null
	var best_d := Layout.SCAN_RANGE_NEGOTIATE * Layout.SCAN_RANGE_NEGOTIATE
	for fid in [1, 2, 3, 4, 6]:
		if not is_settled_rival(state, fid):
			continue
		var representative: Node = state.get_faction_leader(fid)
		if representative != null:
			var distance_sq := origin.distance_squared_to((representative as Node3D).global_position)
			if distance_sq < best_d:
				best_d = distance_sq
				nearest = representative
	return nearest


static func set_diplomatic_state(state: Node, a: int, b: int, d_state: int) -> bool:
	if a == b or a == 5 or b == 5 or not state.factions.has(a) or not state.factions.has(b):
		return false
	if d_state == GameData.DiplomaticState.AT_WAR and has_truce(state, a, b):
		return false
	var key := get_diplomatic_key(a, b)
	if not state.diplomacy.has(key):
		state.diplomacy[key] = {"state": d_state, "opinion_mod": 0, "truce_timer": 0.0}
	else:
		state.diplomacy[key]["state"] = d_state
	state.diplomacy_changed.emit()
	return true


static func modify_opinion(state: Node, a: int, b: int, delta: int) -> void:
	if a == b or a == 5 or b == 5:
		return
	var key := get_diplomatic_key(a, b)
	if state.diplomacy.has(key):
		state.diplomacy[key]["opinion_mod"] = clampi(int(state.diplomacy[key]["opinion_mod"]) + delta, -100, 100)
	state.diplomacy_changed.emit()


static func get_diplomatic_opinion_breakdown(state: Node, fid_a: int, fid_b: int) -> Dictionary:
	if fid_a == fid_b:
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": 100, "state_bound": 0, "total": 100}
	if fid_a == 5 or fid_b == 5:
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": -100, "state_bound": 0, "total": -100}
	if not state.factions.has(fid_a) or not state.factions.has(fid_b):
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": 0, "state_bound": 0, "total": 0}

	var fa: Dictionary = state.factions[fid_a]
	var fb: Dictionary = state.factions[fid_b]
	var key := get_diplomatic_key(fid_a, fid_b)
	var actions: int = int(state.diplomacy[key]["opinion_mod"]) if state.diplomacy.has(key) else 0

	# Religious alignment scoring
	var god: int = 0
	var god_a: int = int(fa.get("patron_god", GameData.PatronGod.NONE))
	var god_b: int = int(fb.get("patron_god", GameData.PatronGod.NONE))
	if god_a != GameData.PatronGod.NONE and god_b != GameData.PatronGod.NONE and god_a == god_b:
		god = 30

	var tenets: int = 0
	var tenets_a: Array = fa.get("tenets", [])
	var tenets_b: Array = fb.get("tenets", [])
	for t in tenets_a:
		if tenets_b.has(t):
			tenets += 20
		var t_data: Dictionary = GameData.TENET_DATA.get(t, {})
		var opp: String = str(t_data.get("opposing", ""))
		if opp != "" and tenets_b.has(opp):
			tenets -= 20

	# Peaceful Offering tenet passive bonus
	var peaceful_offering: int = 15 if (tenets_a.has("PEACEFUL_OFFERING") or tenets_b.has("PEACEFUL_OFFERING")) else 0

	var raw_total: int = actions + god + tenets + peaceful_offering
	var bounded: int = raw_total
	var d_state := get_diplomatic_state(state, fid_a, fid_b)
	if d_state == GameData.DiplomaticState.AT_WAR:
		bounded = mini(bounded, -35)
	elif d_state in [GameData.DiplomaticState.ALLIED, GameData.DiplomaticState.TRIBUTARY]:
		bounded = maxi(bounded, 50)

	var total: int = clampi(bounded, -100, 100)
	var state_bound: int = total - raw_total
	return {
		"god": god,
		"tenets": tenets,
		"peaceful_offering": peaceful_offering,
		"actions": actions,
		"state_bound": state_bound,
		"total": total,
	}


static func get_diplomatic_opinion(state: Node, a: int, b: int) -> int:
	return int(get_diplomatic_opinion_breakdown(state, a, b)["total"])


static func is_hostile(state: Node, a: int, b: int) -> bool:
	if a == b:
		return false
	if a == -3 or b == -3 or a == -1 or b == -1:
		return false
	if (a == 0 and b == -2) or (a == -2 and b == 0):
		return true
	if a == -2 or b == -2:
		return false
	if a == 5 or b == 5:
		return true
	return get_diplomatic_state(state, a, b) == GameData.DiplomaticState.AT_WAR and not has_truce(state, a, b)


static func found_rebel_faction(state: Node, defector: Node) -> void:
	if not state.factions.has(6) or defector == null:
		return
	var f6: Dictionary = state.factions[6]
	var fc6: Node = state.faction_controllers.get(6)
	if f6.get("is_founded") != true or f6.get("is_defeated") == true:
		var p_camp: Vector3 = state.factions[0].get("camp_position", Vector3.ZERO)
		var best_site := p_camp + Vector3(-58.0, 0.0, 12.0)
		var best_min_d := -1.0
		for i in range(12):
			var ang := float(i) * TAU / 12.0
			var cand := p_camp + Vector3(cos(ang) * 60.0, 0.0, sin(ang) * 60.0)
			cand.x = clampf(cand.x, -state.valley_layout.rebel_camp_clamp, state.valley_layout.rebel_camp_clamp)
			cand.z = clampf(cand.z, -state.valley_layout.rebel_camp_clamp, state.valley_layout.rebel_camp_clamp)
			var min_d := 99999.0
			for rid in range(1, 5):
				if state.factions.has(rid):
					var camp_pos: Vector3 = state.factions[rid]["camp_position"]
					var rd := cand.distance_to(camp_pos)
					min_d = minf(min_d, rd)
			if min_d > best_min_d:
				best_min_d = min_d
				best_site = cand

		f6["is_founded"] = true
		f6["is_defeated"] = false
		f6["camp_position"] = best_site
		f6["leader_name"] = defector.get("unit_name")
		f6["primary_lineage"] = int(defector.get("lineage"))
		set_diplomatic_state(state, 0, 6, GameData.DiplomaticState.AT_WAR)
		modify_opinion(state, 0, 6, -100)

		if fc6 != null:
			fc6.spawn_building("CAMPFIRE", best_site, 0.0, true)
			fc6.spawn_building("SLEEPING_HUT", best_site + Vector3(-5.0, 0.0, -3.5), 0.3, true)
			fc6.spawn_building("PALISADE_WALL", best_site + Vector3(-3.0, 0.0, 5.0), 0.2, true)
			fc6.spawn_building("PALISADE_WALL", best_site + Vector3(3.0, 0.0, 5.0), -0.2, true)
			var lin: int = int(defector.get("lineage"))
			for k in range(2):
				var rw: Node = fc6.spawn_colonist(best_site + Vector3(-2.5 + float(k) * 5.0, 0.0, 2.5), lin, GameData.Gender.MALE if k == 0 else GameData.Gender.FEMALE, GameData.Role.WARRIOR, false)
				if rw != null:
					rw.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN if k == 0 else GameData.WarriorClass.ARCHER)

		defector.convert_to_faction(6, false)
		(defector as Node3D).global_position = best_site + Vector3(0.0, 0.0, 2.0)
		state.spatial_index.update_unit(defector)
		defector.promote_to_rival_leader()
		var alert_msg := "REBEL FACTION FORMED! %s founded The Outcast Rebels nearby and targets your colony!" % str(f6["leader_name"])
		state.raid_alert.emit(6, 0, alert_msg)
		state.push_log(alert_msg, "danger")
	else:
		defector.convert_to_faction(6, false)
		defector.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.KNIFE_RAIDER)
		defector.is_raiding = true
		defector.raid_target_pos = state.factions[0]["camp_position"]
		state.push_log("%s defected and joined The Outcast Rebels!" % str(defector.get("unit_name")), "danger")
	state.diplomacy_changed.emit()


static func trigger_conquest_if_eligible(state: Node, target_faction_id: int, attacker_faction_id: int) -> void:
	if not state.game_active or state.campaign_finished:
		return
	if not is_settled_rival(state, target_faction_id):
		return
	if state._conquest_pending_factions.has(target_faction_id):
		return

	var has_camp: bool = state.has_building(target_faction_id, "CAMPFIRE", true)
	var has_totem: bool = state.has_building(target_faction_id, "SACRED_TOTEM", true)
	var leader: Node = state.get_faction_leader(target_faction_id)
	var wiped_out: bool = state.get_faction_units(target_faction_id, true).is_empty() and state.get_faction_buildings(target_faction_id, "", false).is_empty()
	if not ((not has_camp and not has_totem) or leader == null or wiped_out):
		return

	var player_or_ally_conquest := false
	if attacker_faction_id == 0:
		player_or_ally_conquest = true
	elif attacker_faction_id > 0 and attacker_faction_id != target_faction_id:
		var is_player_ally := is_treaty_ally(state, 0, attacker_faction_id)
		var player_at_war := is_hostile(state, 0, target_faction_id)
		var ally_at_war := is_hostile(state, attacker_faction_id, target_faction_id)
		if is_player_ally and player_at_war and ally_at_war:
			player_or_ally_conquest = true

	if player_or_ally_conquest:
		var first_conquest: bool = state._conquest_pending_factions.is_empty()
		state._conquest_pending_factions[target_faction_id] = true
		if first_conquest:
			state._paused_before_conquest = state.is_paused
			state.is_paused = true
			state.conquest_triggered.emit(target_faction_id)
	elif leader == null and (has_camp or has_totem) and ensure_rival_leader(state, target_faction_id) != null:
		state.diplomacy_changed.emit()
	else:
		mark_faction_eliminated_by_third_party(state, target_faction_id, attacker_faction_id)


static func ensure_rival_leader(state: Node, faction_id: int) -> Node:
	var current: Node = state.get_faction_leader(faction_id)
	if current != null or not is_settled_rival(state, faction_id):
		return current
	var candidate: Node = null
	var best := -INF
	for unit in state.get_faction_units(faction_id, true):
		if unit.is_child:
			continue
		var score: float = float(unit.max_hp) * 0.4 + float(unit.attack_damage) * 3.0
		if score > best:
			best = score
			candidate = unit
	if candidate != null:
		candidate.promote_to_rival_leader()
		state.push_log("%s now leads %s." % [candidate.unit_name, state.factions[faction_id]["name"]], "info")
	return candidate


static func restore_rival_leadership(state: Node) -> void:
	for fid in [1, 2, 3, 4, 6]:
		if not state._conquest_pending_factions.has(fid):
			ensure_rival_leader(state, fid)


static func mark_faction_eliminated_by_third_party(state: Node, target_faction_id: int, attacker_faction_id: int) -> void:
	var target: Dictionary = state.factions[target_faction_id]
	target["is_defeated"] = true
	var target_name: String = str(target.get("name", "Rival Tribe"))
	var killer_name := "the wilderness"
	if attacker_faction_id == -1:
		killer_name = "wild beasts"
	elif state.factions.has(attacker_faction_id):
		killer_name = str(state.factions[attacker_faction_id].get("name", "a rival tribe"))
	state.push_log("%s was wiped out by %s!" % [target_name, killer_name], "warning")
	state.diplomacy_changed.emit()
	check_victory_conditions(state)


static func resolve_conquest(state: Node, target_faction_id: int, choice: String) -> void:
	if not state._conquest_pending_factions.has(target_faction_id):
		return
	var target: Dictionary = state.factions[target_faction_id]
	var survivor_units: Array = state.get_faction_units(target_faction_id, true)
	var target_name: String = str(target["name"])

	if choice == "ASSIMILATE":
		target["is_defeated"] = true
		for u in survivor_units:
			u.convert_to_faction(0, true)
		for b in state.get_faction_buildings(target_faction_id, "", false):
			b.faction_id = 0
			if b.has_method("recalculate_max_hp"):
				b.recalculate_max_hp(true)
			b.refresh_faction_color()
		state.add_resource(0, "food", float(target["resources"]["food"]) * 0.5)
		state.add_resource(0, "wood", float(target["resources"]["wood"]) * 0.5)
		state.add_resource(0, "flint", float(target["resources"]["flint"]) * 0.5)
		state.push_log("Assimilated %s! %d survivors and their bloodline joined your tribe." % [target_name, survivor_units.size()], "success")
	elif choice == "TRIBUTARY":
		if ensure_rival_leader(state, target_faction_id) != null:
			set_diplomatic_state(state, 0, target_faction_id, GameData.DiplomaticState.TRIBUTARY)
			modify_opinion(state, 0, target_faction_id, 60)
			state.push_log("%s became a tributary and will deliver supplies each day." % target_name, "success")
		else:
			target["is_defeated"] = true
			state.push_log("%s has no surviving adult to represent the tribe." % target_name, "info")
	else: # RAZE
		target["is_defeated"] = true
		state.add_resource(0, "food", float(target["resources"]["food"]) + 30.0)
		state.add_resource(0, "wood", float(target["resources"]["wood"]) + 30.0)
		state.add_resource(0, "stone", float(target["resources"]["stone"]) + 20.0)
		state.add_resource(0, "flint", float(target["resources"]["flint"]) + 20.0)
		state.add_resource(0, "bone", float(target["resources"]["bone"]) + 12.0)
		state.factions[0]["stockpile"]["spears"] = int(state.factions[0]["stockpile"]["spears"]) + int(target["stockpile"]["spears"])
		state.factions[0]["stockpile"]["bows"] = int(state.factions[0]["stockpile"]["bows"]) + int(target["stockpile"]["bows"])
		for u in survivor_units:
			if state.units_container != null and u.get_parent() == state.units_container:
				state.units_container.remove_child(u)
			u.queue_free()
		for b in state.get_faction_buildings(target_faction_id, "", false):
			if state.buildings_container != null and b.get_parent() == state.buildings_container:
				state.buildings_container.remove_child(b)
			b.queue_free()
		state.push_log("Razed %s and looted all tribal stockpiles!" % target_name, "warning")

	state._conquest_pending_factions.erase(target_faction_id)
	if state._conquest_pending_factions.is_empty():
		state.is_paused = state._paused_before_conquest
		state._paused_before_conquest = false
	check_victory_conditions(state)
	if not state.campaign_finished and not state._conquest_pending_factions.is_empty():
		state.conquest_triggered.emit(int(state._conquest_pending_factions.keys()[0]))


static func check_victory_conditions(state: Node) -> void:
	if not state.game_active or state.campaign_finished:
		return

	# Check defeat: player has no living units (including wounded waiting recovery)
	var player_units: Array = state.get_faction_units(0, true)
	var wounded_player_units := 0
	if state.units_container != null:
		for u in state.units_container.get_children():
			if is_instance_valid(u) and u.get("is_dead") != true and u.get("is_wounded") == true and u.get("original_faction_id") == 0:
				wounded_player_units += 1
	if player_units.is_empty() and wounded_player_units == 0:
		state.campaign_finished = true
		state.defeat_triggered.emit("Your entire tribe and lineage perished in the Stone Age wilderness.")
		return

	# Mark any completely wiped rival/rebel faction (no living units or buildings) as defeated
	var marked_any_defeated := false
	for fid in range(1, 5):
		if state.factions.has(fid) and state.factions[fid].get("is_defeated") != true and not state._conquest_pending_factions.has(fid):
			if state.get_faction_units(fid, true).is_empty() and state.get_faction_buildings(fid, "", false).is_empty():
				state.factions[fid]["is_defeated"] = true
				marked_any_defeated = true
	if state.factions.has(6) and state.factions[6].get("is_founded") == true and state.factions[6].get("is_defeated") != true and not state._conquest_pending_factions.has(6):
		if state.get_faction_units(6, true).is_empty() and state.get_faction_buildings(6, "", false).is_empty():
			state.factions[6]["is_defeated"] = true
			marked_any_defeated = true
	if marked_any_defeated:
		state.diplomacy_changed.emit()

	# Check victory: every rival tribe (1..4) and any founded rebel faction (6) is defeated or allied
	var all_united := true
	var allied_count := 0
	var defeated_count := 0
	for fid in range(1, 5):
		if state.factions[fid].get("is_defeated") == true:
			defeated_count += 1
		elif is_treaty_ally(state, 0, fid):
			allied_count += 1
		else:
			all_united = false
			break
	if all_united and state.factions.has(6) and state.factions[6].get("is_founded") == true and state.factions[6].get("is_defeated") != true:
		if not is_treaty_ally(state, 0, 6):
			all_united = false

	if all_united:
		state.campaign_finished = true
		var summary := "You united the Valley! (%d assimilated/conquered, %d allied tribes)" % [defeated_count, allied_count]
		state.victory_achieved.emit(summary)

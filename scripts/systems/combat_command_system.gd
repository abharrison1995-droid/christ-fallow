extends Node

signal selection_changed(selected_class: int, last_order: int, fire_at_will: bool, warhorn: bool)

var selected_warrior_class: int = -1 # -1 = All Warriors
var last_issued_order: int = GameData.SquadOrder.FOLLOW
var global_fire_at_will: bool = true


func _ready() -> void:
	GameState.combat_command_system = self


func _play_ui_sfx(cue: String, pitch_jitter: float = 0.04) -> void:
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_ui_sfx(cue, pitch_jitter)


func serialize() -> Dictionary:
	return {
		"selected_warrior_class": selected_warrior_class,
		"last_issued_order": last_issued_order,
		"global_fire_at_will": global_fire_at_will,
	}


func restore_from_save(saved: Dictionary) -> void:
	selected_warrior_class = int(saved.get("selected_warrior_class", -1))
	last_issued_order = int(saved.get("last_issued_order", GameData.SquadOrder.FOLLOW))
	global_fire_at_will = bool(saved.get("global_fire_at_will", true))
	selection_changed.emit(selected_warrior_class, last_issued_order, global_fire_at_will, GameState.warhorn_active)


func select_squad(w_class: int) -> void:
	selected_warrior_class = w_class
	_play_ui_sfx("ui_click", 0.04)
	var label := "All Warriors"
	if w_class >= 0:
		label = GameData.WARRIOR_CLASS_NAMES.get(w_class, "Warriors") + "s"
	GameState.push_log("Selected Squad: %s" % label, "info")
	selection_changed.emit(selected_warrior_class, last_issued_order, global_fire_at_will, GameState.warhorn_active)


func issue_player_order(order: int) -> void:
	_play_ui_sfx("ui_click", 0.04)
	var leader := GameState.get_faction_leader(0)
	var origin: Vector3 = leader.global_position if leader != null else Vector3.ZERO
	issue_order(order, origin)


func issue_order(order: int, leader_pos: Vector3) -> void:
	last_issued_order = order
	var count := 0
	for u in GameState.get_faction_units(0, true):
		if u.is_leader or u.is_child or u.is_arena_combatant or u.is_out_of_commission():
			continue
		if u.get("role") != GameData.Role.WARRIOR and not GameState.warhorn_active:
			continue
		var eff_cls: int = GameData.WarriorClass.SPEARMAN if (u.get("role") != GameData.Role.WARRIOR and GameState.warhorn_active) else int(u.get("warrior_class"))
		if selected_warrior_class >= 0 and eff_cls != selected_warrior_class:
			continue
		u.squad_order = order
		if order == GameData.SquadOrder.HOLD:
			u.hold_position = leader_pos + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		count += 1

	var order_name: String = GameData.SQUAD_ORDER_NAMES.get(order, "Order")
	GameState.push_log("Order [%s] issued to %d warriors." % [order_name, count], "info")
	selection_changed.emit(selected_warrior_class, last_issued_order, global_fire_at_will, GameState.warhorn_active)


func toggle_fire_at_will() -> void:
	global_fire_at_will = not global_fire_at_will
	_play_ui_sfx("ui_click", 0.04)
	for u in GameState.get_faction_units(0, true):
		if u.get("is_leader") != true:
			u.fire_at_will = global_fire_at_will
	GameState.push_log("Archers: %s" % ("Fire at Will" if global_fire_at_will else "Hold Fire"), "info")
	selection_changed.emit(selected_warrior_class, last_issued_order, global_fire_at_will, GameState.warhorn_active)


func toggle_warhorn() -> void:
	GameState.warhorn_active = not GameState.warhorn_active
	for u in GameState.get_faction_units(0, true):
		u._refresh_gear_visual()
		if GameState.warhorn_active and not u.is_arena_combatant and not u.is_out_of_commission() and u._is_warhorn_militia():
			u.squad_order = GameData.SquadOrder.GUARD_BASE
	if GameState.warhorn_active:
		_play_ui_sfx("warhorn", 0.03)
		GameState.push_log("WARHORN SOUNDED! All civilians armed to defend the colony!", "warning")
	else:
		_play_ui_sfx("ui_click", 0.04)
		GameState.push_log("Warhorn stood down. Civilians return to their tasks.", "info")
	selection_changed.emit(selected_warrior_class, last_issued_order, global_fire_at_will, GameState.warhorn_active)


func enlighten_captured_caveman() -> bool:
	if not GameState.factions.has(0):
		return false
	var f0: Dictionary = GameState.factions[0]
	if int(f0.get("captured_cavemen", 0)) <= 0:
		GameState.push_log("No captured cavemen waiting for enlightenment.", "warning")
		return false
	if not GameState.has_building(0, "CAMPFIRE", true) and not GameState.has_building(0, "SACRED_TOTEM", true):
		GameState.push_log("Build a Campfire or Sacred Totem first to enlighten captives!", "warning")
		return false
	var cost := {"food": 8, "faith": 5}
	if not GameState.spend_resources(0, cost):
		GameState.push_log("Need 8 Food and 5 Faith to enlighten a captured caveman.", "warning")
		return false

	f0["captured_cavemen"] = int(f0["captured_cavemen"]) - 1
	var fc = GameState.faction_controllers.get(0)
	if fc != null and fc.has_method("spawn_colonist"):
		var pos: Vector3 = f0["camp_position"] + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
		var gender := GameData.Gender.MALE if randf() < 0.5 else GameData.Gender.FEMALE
		var unit = fc.spawn_colonist(pos, GameData.Lineage.CAVEMAN, gender, GameData.Role.FORAGER, false, false)
		if unit != null:
			if GameState.has_tenet(0, "KINSHIP"):
				unit.weapon_tier = maxi(unit.weapon_tier, 2)
			GameState.apply_recruit_perks(0, unit)
			GameState.award_xp(0, 35.0, "Enlightened captive")
		GameState.push_log("Enlightened a captured Caveman! %s joined your tribe." % (unit.unit_name if unit else "A convert"), "success")
	GameState.resources_changed.emit(0)
	return true


func send_gift(target_fid: int) -> void:
	if not GameState.spend_resources(0, {"food": 20, "wood": 15}):
		GameState.push_log("Need 20 Food & 15 Wood to send a tribal gift.", "warning")
		return
	GameState.add_resource(target_fid, "food", 20.0)
	GameState.add_resource(target_fid, "wood", 15.0)
	GameState.modify_opinion(0, target_fid, 25)
	GameState.push_log("Sent gifts to %s (+25 Opinion)." % GameState.factions[target_fid]["name"], "success")


func preach_religion(target_fid: int) -> void:
	if GameState.factions[0]["patron_god"] == GameData.PatronGod.NONE:
		GameState.push_log("Choose a Patron God in [R] Religion before preaching to rivals!", "warning")
		return
	if not GameState.spend_resources(0, {"faith": 15}):
		GameState.push_log("Need 15 Faith to send a Shaman Envoy.", "warning")
		return
	GameState.modify_opinion(0, target_fid, 18)
	# Chance to shift one tenet or convert small opinion
	if GameState.get_diplomatic_opinion(0, target_fid) >= 35 and randf() < 0.45:
		GameState.factions[target_fid]["patron_god"] = GameState.factions[0]["patron_god"]
		for u in GameState.get_faction_units(target_fid, true):
			u.recalculate_stats(false)
		GameState.religion_changed.emit(target_fid)
		GameState.push_log("Envoy converted %s to your Patron God!" % GameState.factions[target_fid]["name"], "success")
	else:
		GameState.push_log("Shaman preached to %s (+18 Opinion)." % GameState.factions[target_fid]["name"], "info")
	GameState.diplomacy_changed.emit()


func propose_alliance(target_fid: int) -> void:
	var op := GameState.get_diplomatic_opinion(0, target_fid)
	if op >= 35:
		GameState.set_diplomatic_state(0, target_fid, GameData.DiplomaticState.ALLIED)
		GameState.award_xp(0, 100.0, "Forged alliance")
		GameState.push_log("%s agreed to a Tribal Alliance!" % GameState.factions[target_fid]["name"], "success")
		GameState.check_victory_conditions()
	else:
		GameState.push_log("%s refused Alliance (Need +35 Opinion; currently %d)." % [GameState.factions[target_fid]["name"], op], "warning")


func declare_war(target_fid: int) -> void:
	if GameState.has_truce(0, target_fid):
		GameState.push_log("The truce still bars a declaration of war.", "warning")
		return
	if not GameState.set_diplomatic_state(0, target_fid, GameData.DiplomaticState.AT_WAR):
		return
	GameState.modify_opinion(0, target_fid, -40)
	GameState.push_log("Declared War on %s!" % GameState.factions[target_fid]["name"], "danger")


func offer_peace_tribute(target_fid: int) -> void:
	if GameState.get_diplomatic_state(0, target_fid) != GameData.DiplomaticState.AT_WAR:
		return
	if not GameState.spend_resources(0, {"food": 25, "flint": 15}):
		GameState.push_log("Need 25 Food & 15 Flint to offer a Peace Tribute.", "warning")
		return
	GameState.add_resource(target_fid, "food", 25.0)
	GameState.add_resource(target_fid, "flint", 15.0)
	GameState.begin_truce(0, target_fid)
	GameState.modify_opinion(0, target_fid, 20)
	GameState.push_log("%s accepted a two-day truce (+20 Opinion)." % GameState.factions[target_fid]["name"], "success")


func adjust_role_count(role_id: int, warrior_class_id: int, delta: int) -> bool:
	var units: Array = GameState.get_faction_units(0, true)
	if delta > 0:
		var candidate: Node = null
		# First look for a non-warrior civilian (not already the target role)
		for u in units:
			if not GameState.can_assign_player_role(u):
				continue
			if u.get("role") != GameData.Role.WARRIOR and u.get("role") != role_id:
				candidate = u
				break
		# Fallback: pull from another warrior class or any eligible adult not matching target
		if candidate == null:
			for u in units:
				if not GameState.can_assign_player_role(u):
					continue
				if role_id == GameData.Role.WARRIOR:
					if u.get("role") != GameData.Role.WARRIOR or int(u.get("warrior_class")) != warrior_class_id:
						candidate = u
						break
				elif u.get("role") != role_id:
					candidate = u
					break
		if GameState.assign_player_role(candidate, role_id, warrior_class_id):
			GameState.resources_changed.emit(0)
			return true
	elif delta < 0:
		for u in units:
			if not GameState.can_assign_player_role(u):
				continue
			if u.get("role") == role_id:
				if role_id == GameData.Role.WARRIOR and int(u.get("warrior_class")) != warrior_class_id:
					continue
				var fallback_role: int = GameData.Role.LUMBERJACK if role_id == GameData.Role.FORAGER else GameData.Role.FORAGER
				GameState.assign_player_role(u, fallback_role)
				GameState.resources_changed.emit(0)
				return true
	return false


func call_ally_to_war(ally_fid: int, enemy_fid: int) -> void:
	if not GameState.is_treaty_ally(0, ally_fid):
		return
	if not GameState.set_diplomatic_state(ally_fid, enemy_fid, GameData.DiplomaticState.AT_WAR):
		GameState.push_log("Your ally has a truce with that tribe.", "warning")
		return
	var fc = GameState.faction_controllers.get(ally_fid)
	if fc != null and fc.has_method("launch_raid_against"):
		fc.launch_raid_against(enemy_fid)
	GameState.push_log("%s marches to war against %s!" % [GameState.factions[ally_fid]["name"], GameState.factions[enemy_fid]["name"]], "success")

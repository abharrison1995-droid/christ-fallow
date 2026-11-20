extends Node

signal resources_changed(faction_id: int)
signal time_changed(time_of_day: float, day_count: int, phase: int)
signal diplomacy_changed()
signal religion_changed(faction_id: int)
signal notification_pushed(message: String, severity: String)
signal raid_alert(attacker_faction_id: int, target_faction_id: int, message: String)
signal conquest_triggered(target_faction_id: int)
signal victory_achieved(reason: String)
signal defeat_triggered(reason: String)
signal leader_succeeded(new_leader_name: String)
signal game_started()
signal campaign_loaded()
signal title_requested()

const BANDIT_GRACE_DURATION := 210.0
const CampaignSave = preload("res://scripts/core/campaign_save.gd")
const CampaignStorage = preload("res://scripts/core/campaign_storage.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const CAMPAIGN_SAVE_PATH := "user://christ_fallow_save.json"

var game_active: bool = false
var is_paused: bool = false
var campaign_finished: bool = false

var time_of_day: float = 7.5
var day_count: int = 1
var day_length_seconds: float = 180.0
var current_phase: int = GameData.SchedulePhase.DAY_WORK
var bandit_grace_remaining: float = 0.0
var _grace_30s_warned: bool = false
var _grace_ended_announced: bool = false

var tutorial_step: int = 1
var tutorial_completed: bool = false
var tutorial_skipped: bool = false
var tutorial_harvested: bool = false
var tutorial_assigned_role: bool = false
var tutorial_cleaved: bool = false
var tutorial_thrown: bool = false
var builder_tip_shown: bool = false

var factions: Dictionary = {}
var diplomacy: Dictionary = {}
var warhorn_active: bool = false

var world_node: Node3D = null
var units_container: Node3D = null
var buildings_container: Node3D = null
var resources_container: Node3D = null
var wildlife_container: Node3D = null
var projectiles_container: Node3D = null

var faction_controllers: Dictionary = {}
var player_controller: Node = null
var combat_command_system: Node = null
var hud_controller: Control = null

var _next_unit_id: int = 1
var _conquest_pending_factions: Dictionary = {}
var _revolt_stagger_cd: float = 0.0
var _guide_refresh_remaining := 0.0
var _paused_before_conquest := false


func _ready() -> void:
	randomize()


func _process(delta: float) -> void:
	if not game_active or is_paused or campaign_finished:
		return

	_revolt_stagger_cd = maxf(0.0, _revolt_stagger_cd - delta)
	_guide_refresh_remaining -= delta
	if _guide_refresh_remaining <= 0.0:
		_guide_refresh_remaining = 0.35
		AwakeningGuide.advance(self)

	if bandit_grace_remaining > 0.0:
		bandit_grace_remaining = maxf(0.0, bandit_grace_remaining - delta)
		if bandit_grace_remaining <= 30.0 and not _grace_30s_warned:
			_grace_30s_warned = true
			push_log("30s left in Peace Buffer — arm at least one Warrior ([C] Colony) before bandits emerge!", "warning")
		if bandit_grace_remaining <= 0.0 and not _grace_ended_announced:
			_grace_ended_announced = true
			push_log("Peace Buffer ended! Feral Cavemen and rival raiders now prowl the valley.", "danger")

	var hours_per_sec := 24.0 / maxf(day_length_seconds, 30.0)
	time_of_day += delta * hours_per_sec
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day_count += 1
		_on_new_day()

	var new_phase := get_schedule_phase(time_of_day)
	if new_phase != current_phase:
		current_phase = new_phase
		if current_phase == GameData.SchedulePhase.DUSK_HEARTH:
			push_log("Dusk falls. Tribesfolk gather at the Campfire for food and worship.", "info")
		elif current_phase == GameData.SchedulePhase.NIGHT_SLEEP:
			push_log("Night has arrived. Families rest in huts; watchtowers guard the dark.", "info")
		elif current_phase == GameData.SchedulePhase.DAY_WORK:
			push_log("Dawn breaks on Day %d. Workers return to their duties." % day_count, "info")

	time_changed.emit(time_of_day, day_count, current_phase)


func get_schedule_phase(hour: float) -> int:
	if hour >= 6.0 and hour < 18.0:
		return GameData.SchedulePhase.DAY_WORK
	elif hour >= 18.0 and hour < 21.0:
		return GameData.SchedulePhase.DUSK_HEARTH
	else:
		return GameData.SchedulePhase.NIGHT_SLEEP


func is_daytime() -> bool:
	return time_of_day >= 6.0 and time_of_day < 18.5


func is_raid_grace_active() -> bool:
	return bandit_grace_remaining > 0.0


func allocate_unit_id() -> int:
	var id := _next_unit_id
	_next_unit_id += 1
	return id


func start_new_campaign(leader_name: String, tribe_name: String, lineage: int) -> bool:
	if not is_instance_valid(world_node) or not world_node.has_method("populate_new_world"):
		push_log("The campaign world is unavailable.", "danger")
		return false
	initialize_new_campaign(leader_name, tribe_name, lineage)
	world_node.populate_new_world()
	AwakeningGuide.advance(self)
	if is_instance_valid(hud_controller):
		hud_controller.activate_campaign()
	push_log("Approach wanderers and press E to recruit them.", "info")
	return true


func initialize_new_campaign(leader_name: String, tribe_name: String, lineage: int) -> void:
	game_active = true
	is_paused = false
	campaign_finished = false
	warhorn_active = false
	_paused_before_conquest = false
	_guide_refresh_remaining = 0.0
	_next_unit_id = 1
	time_of_day = 7.5
	day_count = 1
	current_phase = GameData.SchedulePhase.DAY_WORK
	bandit_grace_remaining = BANDIT_GRACE_DURATION
	_grace_30s_warned = false
	_grace_ended_announced = false
	tutorial_step = 1
	tutorial_completed = false
	tutorial_skipped = false
	tutorial_harvested = false
	tutorial_assigned_role = false
	tutorial_cleaved = false
	tutorial_thrown = false
	builder_tip_shown = false
	_revolt_stagger_cd = 0.0
	factions.clear()
	diplomacy.clear()
	_conquest_pending_factions.clear()

	# Faction 0: Player Tribe (starts un-founded in the wild until Campfire is placed)
	factions[0] = {
		"id": 0,
		"name": tribe_name if not tribe_name.strip_edges().is_empty() else "Fallow Chosen",
		"leader_name": leader_name if not leader_name.strip_edges().is_empty() else "Enoch",
		"ai_personality": GameData.AIPersonality.PLAYER,
		"personality_name": "Enlightened Leader",
		"primary_lineage": lineage,
		"weapon_specialty": GameData.WarriorClass.SPEARMAN,
		"patron_god": GameData.PatronGod.NONE,
		"tenets": [],
		"tech_tier": 1,
		"is_founded": false,
		"is_defeated": false,
		"camp_position": Vector3(0.0, 0.0, 52.0),
		"captured_cavemen": 0,
		"blessing_cooldown": 0.0,
		"resources": {
			"food": 35.0,
			"wood": 28.0,
			"stone": 18.0,
			"flint": 10.0,
			"hide": 8.0,
			"bone": 4.0,
			"faith": 5.0,
		},
		"stockpile": {
			"spears": 2,
			"knives": 2,
			"bows": 1,
			"clubs": 1,
			"javelins": 1,
			"armor": 1,
		},
		"craft_queue": [],
	}

	# Factions 1..4: Rival Tribes, Faction 5: Nomadic Cavemen, Faction 6: Outcast Rebels
	for fid in GameData.RIVAL_PRESETS.keys():
		var preset: Dictionary = GameData.RIVAL_PRESETS[fid]
		var is_feral := int(fid) == 5
		var is_rebel := int(fid) == 6
		factions[fid] = {
			"id": fid,
			"name": preset["name"],
			"leader_name": preset["leader_name"],
			"ai_personality": preset["personality"],
			"personality_name": preset["personality_name"],
			"primary_lineage": preset["lineage"],
			"weapon_specialty": preset["specialty"],
			"patron_god": preset["god"],
			"tenets": preset["tenets"].duplicate(),
			"tech_tier": 1,
			"is_founded": (not is_feral and not is_rebel),
			"is_defeated": false,
			"camp_position": preset["camp_pos"],
			"captured_cavemen": 0,
			"blessing_cooldown": 0.0,
			"resources": {
				"food": 75.0,
				"wood": 65.0,
				"stone": 50.0,
				"flint": 30.0,
				"hide": 25.0,
				"bone": 15.0,
				"faith": 20.0,
			},
			"stockpile": {
				"spears": 4,
				"knives": 4,
				"bows": 4,
				"clubs": 3,
				"javelins": 3,
				"armor": 3,
			},
			"craft_queue": [],
		}

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
			diplomacy[key] = {
				"state": GameData.DiplomaticState.NEUTRAL,
				"opinion_mod": base_mod,
				"truce_timer": 0.0,
			}

	# Faction 5 (Nomadic Cavemen) is permanently at war with everyone
	for a in range(5):
		var fkey := get_diplomatic_key(a, 5)
		diplomacy[fkey] = {
			"state": GameData.DiplomaticState.AT_WAR,
			"opinion_mod": -100,
			"truce_timer": 0.0,
		}

	# Faction 6 (Outcast Rebels) starts at war with Player (0) and neutral to rivals
	for a in range(5):
		var rkey := get_diplomatic_key(a, 6)
		diplomacy[rkey] = {
			"state": GameData.DiplomaticState.AT_WAR if a == 0 else GameData.DiplomaticState.NEUTRAL,
			"opinion_mod": -100 if a == 0 else 0,
			"truce_timer": 0.0,
		}
	diplomacy[get_diplomatic_key(5, 6)] = {
		"state": GameData.DiplomaticState.AT_WAR,
		"opinion_mod": -100,
		"truce_timer": 0.0,
	}

	if is_instance_valid(combat_command_system):
		combat_command_system.restore_from_save({})
	game_started.emit()
	resources_changed.emit(0)
	diplomacy_changed.emit()


func _on_new_day() -> void:
	for key in diplomacy.keys():
		var rel: Dictionary = diplomacy[key]
		if rel["truce_timer"] > 0.0:
			rel["truce_timer"] = maxf(0.0, rel["truce_timer"] - 1.0)


func get_diplomatic_key(a: int, b: int) -> String:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return "%d_%d" % [lo, hi]


func get_diplomatic_state(a: int, b: int) -> int:
	if a == b:
		return GameData.DiplomaticState.ALLIED
	if a == 5 or b == 5:
		return GameData.DiplomaticState.AT_WAR
	var key := get_diplomatic_key(a, b)
	if diplomacy.has(key):
		return int(diplomacy[key]["state"])
	return GameData.DiplomaticState.NEUTRAL


func set_diplomatic_state(a: int, b: int, state: int) -> void:
	if a == b or a == 5 or b == 5:
		return
	var key := get_diplomatic_key(a, b)
	if not diplomacy.has(key):
		diplomacy[key] = {"state": state, "opinion_mod": 0, "truce_timer": 0.0}
	else:
		diplomacy[key]["state"] = state
	diplomacy_changed.emit()


func modify_opinion(a: int, b: int, delta: int) -> void:
	if a == b or a == 5 or b == 5:
		return
	var key := get_diplomatic_key(a, b)
	if diplomacy.has(key):
		diplomacy[key]["opinion_mod"] = clampi(int(diplomacy[key]["opinion_mod"]) + delta, -100, 100)
	diplomacy_changed.emit()


func get_diplomatic_opinion_breakdown(fid_a: int, fid_b: int) -> Dictionary:
	if fid_a == fid_b:
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": 100, "state_bound": 0, "total": 100}
	if fid_a == 5 or fid_b == 5:
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": -100, "state_bound": 0, "total": -100}
	if not factions.has(fid_a) or not factions.has(fid_b):
		return {"god": 0, "tenets": 0, "peaceful_offering": 0, "actions": 0, "state_bound": 0, "total": 0}

	var fa: Dictionary = factions[fid_a]
	var fb: Dictionary = factions[fid_b]
	var key := get_diplomatic_key(fid_a, fid_b)
	var actions: int = int(diplomacy[key]["opinion_mod"]) if diplomacy.has(key) else 0

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
	var state := get_diplomatic_state(fid_a, fid_b)
	if state == GameData.DiplomaticState.AT_WAR:
		bounded = mini(bounded, -35)
	elif state == GameData.DiplomaticState.ALLIED:
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


func get_diplomatic_opinion(a: int, b: int) -> int:
	return int(get_diplomatic_opinion_breakdown(a, b)["total"])


func is_hostile(a: int, b: int) -> bool:
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
	return get_diplomatic_state(a, b) == GameData.DiplomaticState.AT_WAR


func can_trigger_revolt() -> bool:
	if _revolt_stagger_cd <= 0.0:
		_revolt_stagger_cd = 20.0
		return true
	return false


func get_average_morale(faction_id: int = 0) -> float:
	var units := get_faction_units(faction_id, true)
	if units.is_empty():
		return 100.0
	var total := 0.0
	for u in units:
		total += float(u.get("morale"))
	return total / float(units.size())


func found_rebel_faction(defector: Node) -> void:
	if not factions.has(6) or defector == null:
		return
	var f6: Dictionary = factions[6]
	var fc6 = faction_controllers.get(6)
	if not bool(f6["is_founded"]) or bool(f6["is_defeated"]):
		var p_camp: Vector3 = factions[0].get("camp_position", Vector3.ZERO)
		var best_site := p_camp + Vector3(-58.0, 0.0, 12.0)
		var best_min_d := -1.0
		for i in range(12):
			var ang := float(i) * TAU / 12.0
			var cand := p_camp + Vector3(cos(ang) * 60.0, 0.0, sin(ang) * 60.0)
			cand.x = clampf(cand.x, -140.0, 140.0)
			cand.z = clampf(cand.z, -140.0, 140.0)
			var min_d := 99999.0
			for rid in range(1, 5):
				if factions.has(rid):
					var rd := cand.distance_to(factions[rid]["camp_position"])
					min_d = minf(min_d, rd)
			if min_d > best_min_d:
				best_min_d = min_d
				best_site = cand

		f6["is_founded"] = true
		f6["is_defeated"] = false
		f6["camp_position"] = best_site
		f6["leader_name"] = defector.get("unit_name")
		f6["primary_lineage"] = int(defector.get("lineage"))
		set_diplomatic_state(0, 6, GameData.DiplomaticState.AT_WAR)
		modify_opinion(0, 6, -100)

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
		defector.is_leader = true
		defector.role = GameData.Role.WARRIOR
		(defector as Node3D).global_position = best_site + Vector3(0.0, 0.0, 2.0)
		defector._rebuild_visual()
		defector.recalculate_stats(true)
		var alert_msg := "REBEL FACTION FORMED! %s founded The Outcast Rebels nearby and targets your colony!" % str(f6["leader_name"])
		raid_alert.emit(6, 0, alert_msg)
		push_log(alert_msg, "danger")
	else:
		defector.convert_to_faction(6, false)
		defector.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.KNIFE_RAIDER)
		defector.is_raiding = true
		defector.raid_target_pos = factions[0]["camp_position"]
		push_log("%s defected and joined The Outcast Rebels!" % str(defector.get("unit_name")), "danger")
	diplomacy_changed.emit()


func has_tenet(faction_id: int, tenet_id: String) -> bool:
	if not factions.has(faction_id):
		return false
	return factions[faction_id]["tenets"].has(tenet_id)


func skip_awakening_guide() -> void:
	if not game_active or tutorial_skipped or tutorial_completed:
		return
	tutorial_skipped = true
	push_log("Tutorial skipped. Peace Buffer remains active until bandits arrive.", "info")


func set_manual_pause(paused: bool) -> bool:
	if not game_active or campaign_finished or not _conquest_pending_factions.is_empty():
		return false
	is_paused = paused
	return true


func can_assign_player_role(unit: Node) -> bool:
	return (
		is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.faction_id == 0
		and not (unit.is_leader or unit.is_child or unit.is_dead or unit.is_wounded or unit.is_revolting)
	)


func assign_player_role(unit: Node, role: int, warrior_class: int = -1) -> bool:
	if not can_assign_player_role(unit) or not GameData.ROLE_NAMES.has(role):
		return false
	if warrior_class != -1 and not GameData.WARRIOR_CLASS_NAMES.has(warrior_class):
		return false
	unit.set_role_and_class(role, warrior_class)
	return true


func select_player_patron(patron: int) -> void:
	if not factions.has(0) or not GameData.GOD_DATA.has(patron) or patron == GameData.PatronGod.NONE:
		return
	factions[0]["patron_god"] = patron
	for unit in get_faction_units(0):
		unit.recalculate_stats(false)
	religion_changed.emit(0)
	push_log("Your tribe now worships %s." % GameData.GOD_DATA[patron]["name"], "success")


func set_player_tenet(tenet: String, adopted: bool) -> void:
	if not factions.has(0) or not GameData.TENET_DATA.has(tenet):
		return
	var tenets: Array = factions[0]["tenets"]
	if adopted and not tenets.has(tenet):
		if tenets.size() >= 2 or tenets.has(GameData.TENET_DATA[tenet]["opposing"]):
			return
		tenets.append(tenet)
	elif not adopted and tenets.has(tenet):
		tenets.erase(tenet)
	else:
		return
	religion_changed.emit(0)


func add_resource(faction_id: int, res_key: String, amount: float) -> void:
	if not factions.has(faction_id):
		return
	var res: Dictionary = factions[faction_id]["resources"]
	res[res_key] = maxf(0.0, float(res.get(res_key, 0.0)) + amount)
	if faction_id == 0:
		resources_changed.emit(faction_id)


func can_afford(faction_id: int, costs: Dictionary, is_building: bool = false) -> bool:
	if not factions.has(faction_id):
		return false
	var res: Dictionary = factions[faction_id]["resources"]
	var discount := 0.8 if (is_building and has_tenet(faction_id, "ANCESTRAL_STONE")) else 1.0
	for k in costs.keys():
		var req := float(costs[k])
		if k == "wood" or k == "stone":
			req = ceilf(req * discount)
		if float(res.get(k, 0.0)) < req:
			return false
	return true


func spend_resources(faction_id: int, costs: Dictionary, is_building: bool = false) -> bool:
	if not can_afford(faction_id, costs, is_building):
		return false
	var res: Dictionary = factions[faction_id]["resources"]
	var discount := 0.8 if (is_building and has_tenet(faction_id, "ANCESTRAL_STONE")) else 1.0
	for k in costs.keys():
		var req := float(costs[k])
		if k == "wood" or k == "stone":
			req = ceilf(req * discount)
		res[k] = maxf(0.0, float(res.get(k, 0.0)) - req)
	if faction_id == 0:
		resources_changed.emit(faction_id)
	return true


func get_faction_buildings(faction_id: int, building_type: String = "", constructed_only: bool = false) -> Array:
	var result := []
	if buildings_container == null:
		return result
	for b in buildings_container.get_children():
		if not is_instance_valid(b):
			continue
		if b.get("faction_id") != faction_id:
			continue
		if b.get("hp") <= 0.0:
			continue
		if building_type != "" and b.get("building_type") != building_type:
			continue
		if constructed_only and not b.get("is_constructed"):
			continue
		result.append(b)
	return result


func has_building(faction_id: int, building_type: String, constructed_only: bool = true) -> bool:
	return get_faction_buildings(faction_id, building_type, constructed_only).size() > 0


func get_faction_units(faction_id: int, alive_only: bool = true) -> Array:
	var result := []
	if units_container == null:
		return result
	for u in units_container.get_children():
		if not is_instance_valid(u):
			continue
		if u.get("faction_id") != faction_id:
			continue
		if alive_only and (u.get("is_dead") or u.get("hp") <= 0.0):
			continue
		result.append(u)
	return result


func get_faction_leader(faction_id: int) -> Node:
	for u in get_faction_units(faction_id, true):
		if u.get("is_leader"):
			return u
	return null


func get_housing_capacity(faction_id: int) -> int:
	var cap := 2
	for b in get_faction_buildings(faction_id, "", true):
		var b_type: String = b.get("building_type")
		if GameData.BUILDINGS.has(b_type):
			cap += int(GameData.BUILDINGS[b_type]["housing"])
	return cap


func get_faction_military_power(faction_id: int) -> float:
	var power := 0.0
	for u in get_faction_units(faction_id, true):
		if u.get("role") == GameData.Role.WARRIOR or u.get("is_leader"):
			power += float(u.get("max_hp")) * 0.4 + float(u.get("attack_damage")) * 3.0
	return power


func trigger_conquest_if_eligible(target_faction_id: int, attacker_faction_id: int) -> void:
	if not game_active or campaign_finished:
		return
	if target_faction_id <= 0 or target_faction_id == 5:
		return
	if not factions.has(target_faction_id):
		return
	if target_faction_id == 6 and not bool(factions[6].get("is_founded", false)):
		return
	if factions[target_faction_id]["is_defeated"]:
		return
	if _conquest_pending_factions.has(target_faction_id):
		return

	var has_camp := has_building(target_faction_id, "CAMPFIRE", true)
	var has_totem := has_building(target_faction_id, "SACRED_TOTEM", true)
	var leader := get_faction_leader(target_faction_id)
	var wiped_out := get_faction_units(target_faction_id, true).is_empty() and get_faction_buildings(target_faction_id, "", false).is_empty()
	if not ((not has_camp and not has_totem) or leader == null or wiped_out):
		return

	var player_or_ally_conquest := false
	if attacker_faction_id == 0:
		player_or_ally_conquest = true
	elif attacker_faction_id > 0 and attacker_faction_id != target_faction_id:
		var is_player_ally := get_diplomatic_state(0, attacker_faction_id) == GameData.DiplomaticState.ALLIED
		var player_at_war := get_diplomatic_state(0, target_faction_id) == GameData.DiplomaticState.AT_WAR
		var ally_at_war := get_diplomatic_state(attacker_faction_id, target_faction_id) == GameData.DiplomaticState.AT_WAR
		if is_player_ally and player_at_war and ally_at_war:
			player_or_ally_conquest = true

	if player_or_ally_conquest:
		var first_conquest := _conquest_pending_factions.is_empty()
		_conquest_pending_factions[target_faction_id] = true
		if first_conquest:
			_paused_before_conquest = is_paused
			is_paused = true
			conquest_triggered.emit(target_faction_id)
	else:
		_mark_faction_eliminated_by_third_party(target_faction_id, attacker_faction_id)


func _mark_faction_eliminated_by_third_party(target_faction_id: int, attacker_faction_id: int) -> void:
	var target: Dictionary = factions[target_faction_id]
	target["is_defeated"] = true
	var target_name: String = str(target.get("name", "Rival Tribe"))
	var killer_name := "the wilderness"
	if attacker_faction_id == -1:
		killer_name = "wild beasts"
	elif factions.has(attacker_faction_id):
		killer_name = str(factions[attacker_faction_id].get("name", "a rival tribe"))
	push_log("%s was wiped out by %s!" % [target_name, killer_name], "warning")
	diplomacy_changed.emit()
	check_victory_conditions()


func resolve_conquest(target_faction_id: int, choice: String) -> void:
	if not _conquest_pending_factions.has(target_faction_id):
		return
	var target: Dictionary = factions[target_faction_id]
	var survivor_units := get_faction_units(target_faction_id, true)
	var target_name: String = target["name"]

	if choice == "ASSIMILATE":
		target["is_defeated"] = true
		for u in survivor_units:
			u.convert_to_faction(0, true)
		for b in get_faction_buildings(target_faction_id, "", false):
			b.faction_id = 0
			b.refresh_faction_color()
		add_resource(0, "food", float(target["resources"]["food"]) * 0.5)
		add_resource(0, "wood", float(target["resources"]["wood"]) * 0.5)
		add_resource(0, "flint", float(target["resources"]["flint"]) * 0.5)
		push_log("Assimilated %s! %d survivors and their bloodline joined your tribe." % [target_name, survivor_units.size()], "success")
	elif choice == "TRIBUTARY":
		target["is_defeated"] = false
		set_diplomatic_state(0, target_faction_id, GameData.DiplomaticState.ALLIED)
		modify_opinion(0, target_faction_id, 60)
		add_resource(0, "food", 30.0)
		add_resource(0, "flint", 20.0)
		push_log("%s bent the knee as a Tributary Ally!" % target_name, "success")
	else: # RAZE
		target["is_defeated"] = true
		add_resource(0, "food", float(target["resources"]["food"]) + 30.0)
		add_resource(0, "wood", float(target["resources"]["wood"]) + 30.0)
		add_resource(0, "stone", float(target["resources"]["stone"]) + 20.0)
		add_resource(0, "flint", float(target["resources"]["flint"]) + 20.0)
		add_resource(0, "bone", float(target["resources"]["bone"]) + 12.0)
		factions[0]["stockpile"]["spears"] += int(target["stockpile"]["spears"])
		factions[0]["stockpile"]["bows"] += int(target["stockpile"]["bows"])
		for u in survivor_units:
			if units_container != null and u.get_parent() == units_container:
				units_container.remove_child(u)
			u.queue_free()
		for b in get_faction_buildings(target_faction_id, "", false):
			if buildings_container != null and b.get_parent() == buildings_container:
				buildings_container.remove_child(b)
			b.queue_free()
		push_log("Razed %s and looted all tribal stockpiles!" % target_name, "warning")

	_conquest_pending_factions.erase(target_faction_id)
	if _conquest_pending_factions.is_empty():
		is_paused = _paused_before_conquest
		_paused_before_conquest = false
	check_victory_conditions()
	if not campaign_finished and not _conquest_pending_factions.is_empty():
		conquest_triggered.emit(_conquest_pending_factions.keys()[0])


func check_victory_conditions() -> void:
	if not game_active or campaign_finished:
		return

	# Check defeat: player has no living units (including wounded waiting recovery)
	var player_units := get_faction_units(0, true)
	var wounded_player_units := 0
	if units_container != null:
		for u in units_container.get_children():
			if is_instance_valid(u) and not u.get("is_dead") and u.get("is_wounded") and int(u.get("original_faction_id")) == 0:
				wounded_player_units += 1
	if player_units.is_empty() and wounded_player_units == 0:
		campaign_finished = true
		defeat_triggered.emit("Your entire tribe and lineage perished in the Stone Age wilderness.")
		return

	# Mark any completely wiped rival/rebel faction (no living units or buildings) as defeated
	var marked_any_defeated := false
	for fid in range(1, 5):
		if factions.has(fid) and not bool(factions[fid]["is_defeated"]) and not _conquest_pending_factions.has(fid):
			if get_faction_units(fid, true).is_empty() and get_faction_buildings(fid, "", false).is_empty():
				factions[fid]["is_defeated"] = true
				marked_any_defeated = true
	if factions.has(6) and bool(factions[6].get("is_founded", false)) and not bool(factions[6].get("is_defeated", false)) and not _conquest_pending_factions.has(6):
		if get_faction_units(6, true).is_empty() and get_faction_buildings(6, "", false).is_empty():
			factions[6]["is_defeated"] = true
			marked_any_defeated = true
	if marked_any_defeated:
		diplomacy_changed.emit()

	# Check victory: every rival tribe (1..4) and any founded rebel faction (6) is defeated or allied
	var all_united := true
	var allied_count := 0
	var defeated_count := 0
	for fid in range(1, 5):
		if factions[fid]["is_defeated"]:
			defeated_count += 1
		elif get_diplomatic_state(0, fid) == GameData.DiplomaticState.ALLIED:
			allied_count += 1
		else:
			all_united = false
			break
	if all_united and factions.has(6) and bool(factions[6].get("is_founded", false)) and not bool(factions[6].get("is_defeated", false)):
		if get_diplomatic_state(0, 6) != GameData.DiplomaticState.ALLIED:
			all_united = false

	if all_united:
		campaign_finished = true
		var summary := "You united the Valley! (%d assimilated/conquered, %d allied tribes)" % [defeated_count, allied_count]
		victory_achieved.emit(summary)


func push_log(msg: String, severity: String = "info") -> void:
	notification_pushed.emit(msg, severity)


func save_game(path: String = CAMPAIGN_SAVE_PATH) -> bool:
	if not game_active or not is_instance_valid(world_node):
		push_log("There is no active campaign to save.", "warning")
		return false
	var units_data := []
	var player_leader_id := 0
	if units_container != null:
		for u in units_container.get_children():
			if is_instance_valid(u) and not u.is_queued_for_deletion() and not u.get("is_dead"):
				units_data.append(u.serialize())
				if u.faction_id == 0 and u.is_leader:
					player_leader_id = u.unit_id

	var buildings_data := []
	if buildings_container != null:
		for b in buildings_container.get_children():
			if is_instance_valid(b) and not b.is_queued_for_deletion() and b.get("hp") > 0.0:
				buildings_data.append(b.serialize())

	var wildlife_data := []
	if wildlife_container != null:
		for animal in wildlife_container.get_children():
			if is_instance_valid(animal) and not animal.is_queued_for_deletion() and not animal.get("is_dead"):
				wildlife_data.append(animal.serialize())

	var saved_factions := factions.duplicate(true)
	for faction in saved_factions.values():
		faction["camp_position"] = CampaignSave.pack_position(faction["camp_position"])

	var save_payload := {
		"version": CampaignSave.VERSION,
		"time_of_day": time_of_day,
		"day_count": day_count,
		"warhorn_active": warhorn_active,
		"pending_conquests": _conquest_pending_factions.keys(),
		"bandit_grace_remaining": bandit_grace_remaining,
		"tutorial_step": tutorial_step,
		"tutorial_completed": tutorial_completed,
		"tutorial_skipped": tutorial_skipped,
		"tutorial_harvested": tutorial_harvested,
		"tutorial_assigned_role": tutorial_assigned_role,
		"tutorial_cleaved": tutorial_cleaved,
		"tutorial_thrown": tutorial_thrown,
		"builder_tip_shown": builder_tip_shown,
		"combat_commands": combat_command_system.serialize() if is_instance_valid(combat_command_system) else {
			"selected_warrior_class": -1, "last_issued_order": GameData.SquadOrder.FOLLOW, "global_fire_at_will": true,
		},
		"factions": saved_factions,
		"diplomacy": diplomacy,
		"units": units_data,
		"buildings": buildings_data,
		"wildlife": wildlife_data,
	}
	if player_leader_id > 0:
		save_payload["player_leader_id"] = player_leader_id

	if not CampaignStorage.write_snapshot(path, save_payload):
		push_log("Failed to save game to %s" % path, "danger")
		return false
	push_log("Campaign saved (Day %d)." % day_count, "success")
	return true


func read_campaign_save(path: String = CAMPAIGN_SAVE_PATH) -> Dictionary:
	return CampaignStorage.read_snapshot(path)


func load_game(path: String = CAMPAIGN_SAVE_PATH) -> bool:
	var result := read_campaign_save(path)
	if result.has("error"):
		push_log(result["error"], "warning" if result.get("missing", false) else "danger")
		return false
	var parsed: Dictionary = result["data"]
	if not is_instance_valid(world_node) or not world_node.has_method("restore_from_save"):
		push_log("The campaign world is unavailable.", "danger")
		return false

	var starting_campaign := not game_active or campaign_finished
	_apply_campaign_snapshot(parsed)

	world_node.restore_from_save(parsed, starting_campaign)
	if is_instance_valid(combat_command_system):
		combat_command_system.restore_from_save(parsed.get("combat_commands", {}))

	if starting_campaign:
		game_started.emit()
	campaign_loaded.emit()
	if not _conquest_pending_factions.is_empty():
		is_paused = true
		conquest_triggered.emit(_conquest_pending_factions.keys()[0])
	time_changed.emit(time_of_day, day_count, current_phase)
	resources_changed.emit(0)
	diplomacy_changed.emit()
	religion_changed.emit(0)
	push_log("Campaign loaded (Day %d)." % day_count, "success")
	return true


func _apply_campaign_snapshot(parsed: Dictionary) -> void:
	game_active = true
	is_paused = false
	_paused_before_conquest = false
	_guide_refresh_remaining = 0.0
	campaign_finished = false
	_conquest_pending_factions.clear()
	for target_id in parsed.get("pending_conquests", []):
		_conquest_pending_factions[int(target_id)] = true
	_revolt_stagger_cd = 0.0
	time_of_day = float(parsed.get("time_of_day", 7.5))
	day_count = int(parsed.get("day_count", 1))
	current_phase = get_schedule_phase(time_of_day)
	warhorn_active = bool(parsed.get("warhorn_active", false))
	bandit_grace_remaining = float(parsed.get("bandit_grace_remaining", 0.0))
	_grace_30s_warned = bandit_grace_remaining <= 30.0
	_grace_ended_announced = bandit_grace_remaining <= 0.0
	tutorial_step = int(parsed.get("tutorial_step", 1))
	tutorial_completed = bool(parsed.get("tutorial_completed", false))
	tutorial_skipped = bool(parsed.get("tutorial_skipped", false))
	tutorial_harvested = bool(parsed.get("tutorial_harvested", false))
	tutorial_assigned_role = bool(parsed.get("tutorial_assigned_role", false))
	tutorial_cleaved = bool(parsed.get("tutorial_cleaved", false))
	tutorial_thrown = bool(parsed.get("tutorial_thrown", false))
	builder_tip_shown = bool(parsed.get("builder_tip_shown", false))
	factions = parsed["factions"]
	diplomacy = parsed["diplomacy"]

	_next_unit_id = 1
	for unit in parsed["units"]:
		_next_unit_id = maxi(_next_unit_id, int(unit.get("unit_id", 0)) + 1)
	var restored_ids := {}
	for unit in parsed["units"]:
		var id := int(unit.get("unit_id", 0))
		if id <= 0 or restored_ids.has(id):
			id = allocate_unit_id()
		unit["unit_id"] = id
		restored_ids[id] = true


func end_campaign() -> void:
	game_active = false
	is_paused = false
	campaign_finished = false
	warhorn_active = false
	factions.clear()
	diplomacy.clear()
	faction_controllers.clear()
	_conquest_pending_factions.clear()
	world_node = null
	units_container = null
	buildings_container = null
	resources_container = null
	wildlife_container = null
	projectiles_container = null
	combat_command_system = null
	player_controller = null
	hud_controller = null

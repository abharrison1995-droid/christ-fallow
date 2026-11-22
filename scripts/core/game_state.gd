extends Node

signal resources_changed(faction_id: int)
signal time_changed(time_of_day: float, day_count: int, phase: int)
signal diplomacy_changed()
signal religion_changed(faction_id: int)
signal progression_changed(faction_id: int)
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
const DiplomacyConquestRules = preload("res://scripts/core/diplomacy_conquest_rules.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const SpatialIndex = preload("res://scripts/core/spatial_index.gd")
const ValleyNavigation = preload("res://scripts/core/valley_navigation.gd")
const Layout = preload("res://scripts/core/world_layout.gd")
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

var spatial_index = SpatialIndex.new()
var valley_nav = ValleyNavigation.new()
var valley_layout := Layout.new()

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


func start_new_campaign(leader_name: String, tribe_name: String, lineage: int, layout_id: String = Layout.DEFAULT_ID) -> bool:
	if not is_instance_valid(world_node) or not world_node.has_method("populate_new_world"):
		push_log("The campaign world is unavailable.", "danger")
		return false
	if not Layout.has_layout(layout_id):
		push_log("Unknown valley layout.", "danger")
		return false
	initialize_new_campaign(leader_name, tribe_name, lineage, layout_id)
	world_node.populate_new_world()
	AwakeningGuide.advance(self)
	if is_instance_valid(hud_controller):
		hud_controller.activate_campaign()
	push_log("Approach wanderers and press E to recruit them.", "info")
	return true


func initialize_new_campaign(leader_name: String, tribe_name: String, lineage: int, layout_id: String = Layout.DEFAULT_ID) -> void:
	valley_layout = Layout.new(layout_id)
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
		"level": 1,
		"xp": 0.0,
		"skill_points": 0,
		"perks": {},
		"is_founded": false,
		"is_defeated": false,
		"camp_position": valley_layout.camp_position(0),
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
			"great_spears": 0,
			"obsidian_cleavers": 0,
			"hide_tunic": 0,
			"pelt_mantle": 0,
			"obsidian_plate": 0,
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
			"level": 1,
			"xp": 0.0,
			"skill_points": 0,
			"perks": {},
			"is_founded": (not is_feral and not is_rebel),
			"is_defeated": false,
			"camp_position": valley_layout.camp_position(fid),
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
				"great_spears": 0,
				"obsidian_cleavers": 0,
				"hide_tunic": 0,
				"pelt_mantle": 0,
				"obsidian_plate": 0,
			},
			"craft_queue": [],
		}

	DiplomacyConquestRules.initialize_diplomacy(self)

	if is_instance_valid(combat_command_system):
		combat_command_system.restore_from_save({})
	game_started.emit()
	resources_changed.emit(0)
	diplomacy_changed.emit()


func _on_new_day() -> void:
	DiplomacyConquestRules.on_new_day(self)


func _deliver_tribute(faction_id: int) -> void:
	DiplomacyConquestRules.deliver_tribute(self, faction_id)


func get_diplomatic_key(a: int, b: int) -> String:
	return DiplomacyConquestRules.get_diplomatic_key(a, b)


func get_diplomatic_state(a: int, b: int) -> int:
	return DiplomacyConquestRules.get_diplomatic_state(self, a, b)


func get_truce_days(a: int, b: int) -> float:
	return DiplomacyConquestRules.get_truce_days(self, a, b)


func has_truce(a: int, b: int) -> bool:
	return DiplomacyConquestRules.has_truce(self, a, b)


func begin_truce(a: int, b: int) -> void:
	DiplomacyConquestRules.begin_truce(self, a, b)


func is_treaty_ally(a: int, b: int) -> bool:
	return DiplomacyConquestRules.is_treaty_ally(self, a, b)


func is_settled_rival(faction_id: int) -> bool:
	return DiplomacyConquestRules.is_settled_rival(self, faction_id)


func nearby_rival_leader(origin: Vector3) -> Node:
	return DiplomacyConquestRules.nearby_rival_leader(self, origin)


func set_diplomatic_state(a: int, b: int, state: int) -> bool:
	return DiplomacyConquestRules.set_diplomatic_state(self, a, b, state)


func modify_opinion(a: int, b: int, delta: int) -> void:
	DiplomacyConquestRules.modify_opinion(self, a, b, delta)


func get_diplomatic_opinion_breakdown(fid_a: int, fid_b: int) -> Dictionary:
	return DiplomacyConquestRules.get_diplomatic_opinion_breakdown(self, fid_a, fid_b)


func get_diplomatic_opinion(a: int, b: int) -> int:
	return DiplomacyConquestRules.get_diplomatic_opinion(self, a, b)


func is_hostile(a: int, b: int) -> bool:
	return DiplomacyConquestRules.is_hostile(self, a, b)


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
	DiplomacyConquestRules.found_rebel_faction(self, defector)


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
	AwakeningGuide.advance(self)
	if is_instance_valid(hud_controller) and hud_controller.has_method("refresh_awakening_guide"):
		hud_controller.refresh_awakening_guide()
	return true


func select_player_patron(patron: int) -> void:
	if not factions.has(0) or not GameData.GOD_DATA.has(patron) or patron == GameData.PatronGod.NONE:
		return
	var prev_patron: int = int(factions[0].get("patron_god", GameData.PatronGod.NONE))
	factions[0]["patron_god"] = patron
	for unit in get_faction_units(0):
		unit.recalculate_stats(false)
	if prev_patron == GameData.PatronGod.KRAG_UL or patron == GameData.PatronGod.KRAG_UL:
		for b in get_faction_buildings(0):
			if b.has_method("recalculate_max_hp"):
				b.recalculate_max_hp(true)
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


func get_perk_rank(faction_id: int, perk_id: String) -> int:
	if not factions.has(faction_id):
		return 0
	return PerkSystem.get_perk_rank(factions[faction_id], perk_id)


func is_building_unlocked(faction_id: int, building_type: String) -> bool:
	if not factions.has(faction_id):
		return false
	return PerkSystem.is_building_unlocked(factions[faction_id], building_type)


func get_building_lock_reason(faction_id: int, building_type: String) -> String:
	if not factions.has(faction_id):
		return ""
	return PerkSystem.get_building_lock_reason(factions[faction_id], building_type)


func get_max_population_cap(faction_id: int) -> int:
	if not factions.has(faction_id):
		return 32
	return PerkSystem.get_max_population_cap(factions[faction_id])


func award_xp(faction_id: int, amount: float, _reason: String = "") -> void:
	if amount <= 0.0 or faction_id == 5 or not factions.has(faction_id):
		return
	var fdata: Dictionary = factions[faction_id]
	var lvl: int = PerkSystem.get_level(fdata)
	if lvl >= PerkSystem.MAX_LEVEL:
		fdata["level"] = PerkSystem.MAX_LEVEL
		fdata["xp"] = 0.0
		return
	var xp: float = PerkSystem.get_xp(fdata) + amount
	var leveled_up := false
	while lvl < PerkSystem.MAX_LEVEL:
		var req: float = PerkSystem.xp_for_next_level(lvl)
		if xp < req:
			break
		xp -= req
		lvl += 1
		fdata["skill_points"] = PerkSystem.get_skill_points(fdata) + 1
		leveled_up = true
		var leader: Node = get_faction_leader(faction_id)
		if leader != null and is_instance_valid(leader):
			leader.heal(30.0)
			if faction_id == 0 and leader is Node3D:
				CombatVFX.spawn_damage_popup(leader as Node3D, "LEVEL UP! Lv.%d" % lvl, Color(1.0, 0.90, 0.32), 1.35, 2.6)
		if faction_id == 0:
			push_log("LEVEL UP! Your tribe reached Level %d (+1 Skill Point — open [K] Perks)!" % lvl, "success")
	if lvl >= PerkSystem.MAX_LEVEL:
		xp = 0.0
	fdata["level"] = lvl
	fdata["xp"] = xp
	if leveled_up and faction_id in [1, 2, 3, 4, 6]:
		_auto_spend_rival_perks(faction_id)
	progression_changed.emit(faction_id)


func _auto_spend_rival_perks(faction_id: int) -> void:
	if not factions.has(faction_id) or faction_id == 0 or faction_id == 5:
		return
	var guard := 0
	while PerkSystem.get_skill_points(factions[faction_id]) > 0 and guard < 16:
		guard += 1
		var next_perk: String = PerkSystem.pick_rival_perk(factions[faction_id])
		if next_perk.is_empty() or not unlock_perk(faction_id, next_perk, true):
			break


func unlock_perk(faction_id: int, perk_id: String, silent: bool = false) -> bool:
	if not factions.has(faction_id):
		return false
	var fdata: Dictionary = factions[faction_id]
	if not PerkSystem.can_unlock_perk(fdata, perk_id):
		return false
	if typeof(fdata.get("perks")) != TYPE_DICTIONARY:
		fdata["perks"] = {}
	var perks: Dictionary = fdata["perks"]
	var new_rank: int = PerkSystem.get_perk_rank(fdata, perk_id) + 1
	perks[perk_id] = new_rank
	fdata["skill_points"] = PerkSystem.get_skill_points(fdata) - 1
	for unit in get_faction_units(faction_id, true):
		unit.recalculate_stats(false)
	for b in get_faction_buildings(faction_id, "", false):
		if b.has_method("recalculate_max_hp"):
			b.recalculate_max_hp(true)
	if faction_id == 0 and not silent:
		var perk_name: String = str(PerkSystem.PERK_DEFINITIONS[perk_id]["name"])
		push_log("Unlocked %s (Rank %d)!" % [perk_name, new_rank], "success")
	progression_changed.emit(faction_id)
	if faction_id == 0:
		resources_changed.emit(0)
	return true


func apply_recruit_perks(faction_id: int, unit: Node) -> void:
	if not is_instance_valid(unit) or not factions.has(faction_id) or faction_id == 5:
		return
	var fdata: Dictionary = factions[faction_id]
	var target_mult: float = PerkSystem.get_recruit_stat_mult(fdata)
	var prev_val: Variant = unit.get("_recruit_perks_mult")
	var prev_mult: float = float(prev_val) if prev_val != null else 1.0
	if target_mult > prev_mult + 0.001:
		var ratio: float = target_mult / maxf(prev_mult, 1.0)
		unit.base_hp_stat = clampf(float(unit.base_hp_stat) * ratio, 60.0, 220.0)
		unit.base_melee_stat = clampf(float(unit.base_melee_stat) * ratio, 6.0, 35.0)
		unit.base_ranged_stat = clampf(float(unit.base_ranged_stat) * ratio, 6.0, 35.0)
		unit.set("_recruit_perks_mult", target_mult)
		var morale_bonus: float = PerkSystem.get_recruit_morale_bonus(fdata)
		if morale_bonus > 0.0 and float(unit.morale) < 100.0:
			unit.morale = clampf(float(unit.morale) + morale_bonus, 0.0, 100.0)
	var start_rank: int = PerkSystem.get_recruit_starting_rank(fdata)
	if start_rank > 0 and not bool(unit.get("is_child")):
		unit.melee_rank = maxi(int(unit.melee_rank), start_rank)
		unit.ranged_rank = maxi(int(unit.ranged_rank), start_rank)
	unit.recalculate_stats(true)
	if PerkSystem.has_battle_veterans(fdata) and int(unit.role) == GameData.Role.WARRIOR:
		unit.try_equip_from_stockpile()


func hire_nomad_villager(faction_id: int = 0) -> Node:
	if not factions.has(faction_id):
		return null
	var fdata: Dictionary = factions[faction_id]
	if PerkSystem.get_perk_rank(fdata, "CALL_OF_THE_HEARTH") <= 0:
		if faction_id == 0:
			push_log("Unlock 'Call of the Hearth' in [K] Perks to hire Nomad Villagers.", "warning")
		return null
	if not has_building(faction_id, "CAMPFIRE", true):
		if faction_id == 0:
			push_log("Light a Tribal Campfire first to hire Nomad Villagers!", "warning")
		return null
	var cur_pop: int = get_faction_units(faction_id, true).size()
	var cap: int = mini(get_housing_capacity(faction_id), get_max_population_cap(faction_id))
	if cur_pop >= cap:
		if faction_id == 0:
			push_log("Build more Sleeping Huts or upgrade Hearth capacity before hiring!", "warning")
		return null
	var cost: int = PerkSystem.get_hire_nomad_cost(fdata)
	if not spend_resources(faction_id, {"food": cost}):
		if faction_id == 0:
			push_log("Need %d Food to hire a Nomad Villager." % cost, "warning")
		return null
	var fc: Node = faction_controllers.get(faction_id)
	if fc == null or not fc.has_method("spawn_colonist"):
		return null
	var camp_pos: Vector3 = fdata["camp_position"]
	var pos := camp_pos + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	var lin: int = int(fdata.get("primary_lineage", GameData.Lineage.CRAG_BORN))
	var gender := GameData.Gender.MALE if randf() < 0.5 else GameData.Gender.FEMALE
	var unit: Node = fc.spawn_colonist(pos, lin, gender, GameData.Role.FORAGER, false, false)
	if unit != null:
		apply_recruit_perks(faction_id, unit)
		award_xp(faction_id, 20.0, "Hired nomad")
		if faction_id == 0:
			push_log("Hired nomad villager %s (%s)!" % [str(unit.get("unit_name")), GameData.LINEAGE_DATA[lin]["short_name"]], "success")
	return unit


func equip_unit_weapon(unit: Node, weapon_id: String, consume_stockpile: bool = true) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.get("is_dead") == true:
		return false
	if int(unit.get("faction_id")) != 0 or not factions.has(0):
		return false
	if not GameData.WEAPON_DEFS.has(weapon_id):
		return false
	var current_weapon: String = unit.get_equipped_weapon_id() if unit.has_method("get_equipped_weapon_id") else str(unit.get("equipped_weapon_id"))
	if weapon_id == current_weapon:
		return true
	var raw_old_weapon: String = str(unit.get("equipped_weapon_id"))
	var wdef: Dictionary = GameData.WEAPON_DEFS[weapon_id]
	var fdata: Dictionary = factions[0]
	var stock: Dictionary = fdata["stockpile"]
	var min_tier: int = int(wdef.get("min_tier", 1))
	var stock_key: String = str(wdef.get("stock_key", ""))
	if consume_stockpile:
		if int(fdata.get("tech_tier", 1)) < min_tier:
			push_log("Requires %s to equip %s." % [GameData.TECH_TIER_NAMES.get(min_tier, "Tier %d" % min_tier), str(wdef["name"])], "warning")
			return false
		if stock_key != "" and int(stock.get(stock_key, 0)) <= 0:
			push_log("No %s in stockpile. Craft one at the Crafting Pit." % str(wdef["name"]), "warning")
			return false
		if stock_key != "":
			stock[stock_key] = int(stock.get(stock_key, 0)) - 1
		if raw_old_weapon != "" and GameData.WEAPON_DEFS.has(raw_old_weapon):
			var old_key: String = str(GameData.WEAPON_DEFS[raw_old_weapon].get("stock_key", ""))
			if old_key != "":
				stock[old_key] = int(stock.get(old_key, 0)) + 1
	unit.equip_loadout(weapon_id)
	resources_changed.emit(0)
	push_log("Equipped %s with %s." % [str(unit.get("unit_name")), str(wdef["name"])], "info")
	return true


func equip_unit_armor(unit: Node, armor_id: String, consume_stockpile: bool = true) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.get("is_dead") == true:
		return false
	if int(unit.get("faction_id")) != 0 or not factions.has(0):
		return false
	if not GameData.ARMOR_DEFS.has(armor_id):
		return false
	var current_armor: String = unit.get_equipped_armor_id() if unit.has_method("get_equipped_armor_id") else str(unit.get("equipped_armor_id"))
	if armor_id == current_armor:
		return true
	var raw_old_armor: String = str(unit.get("equipped_armor_id"))
	var adef: Dictionary = GameData.ARMOR_DEFS[armor_id]
	var fdata: Dictionary = factions[0]
	var stock: Dictionary = fdata["stockpile"]
	var min_tier: int = int(adef.get("min_tier", 1))
	var stock_key: String = str(adef.get("stock_key", ""))
	if consume_stockpile:
		if int(fdata.get("tech_tier", 1)) < min_tier:
			push_log("Requires %s to equip %s." % [GameData.TECH_TIER_NAMES.get(min_tier, "Tier %d" % min_tier), str(adef["name"])], "warning")
			return false
		if stock_key != "" and int(stock.get(stock_key, 0)) <= 0:
			push_log("No %s in stockpile. Craft one at the Crafting Pit." % str(adef["name"]), "warning")
			return false
		if stock_key != "":
			stock[stock_key] = int(stock.get(stock_key, 0)) - 1
		if raw_old_armor != "" and raw_old_armor != "NONE" and GameData.ARMOR_DEFS.has(raw_old_armor):
			var old_key: String = str(GameData.ARMOR_DEFS[raw_old_armor].get("stock_key", ""))
			if old_key != "":
				stock[old_key] = int(stock.get(old_key, 0)) + 1
	unit.equip_loadout("__KEEP__", armor_id)
	resources_changed.emit(0)
	if armor_id == "NONE":
		push_log("Unequipped armor from %s." % str(unit.get("unit_name")), "info")
	else:
		push_log("Equipped %s with %s." % [str(unit.get("unit_name")), str(adef["name"])], "info")
	return true


func can_afford(faction_id: int, costs: Dictionary, is_building: bool = false) -> bool:
	if not factions.has(faction_id):
		return false
	var res: Dictionary = factions[faction_id]["resources"]
	var discount := 1.0
	if is_building:
		if has_tenet(faction_id, "ANCESTRAL_STONE"):
			discount *= 0.8
		discount *= PerkSystem.get_building_cost_mult(factions[faction_id])
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
	var discount := 1.0
	if is_building:
		if has_tenet(faction_id, "ANCESTRAL_STONE"):
			discount *= 0.8
		discount *= PerkSystem.get_building_cost_mult(factions[faction_id])
	for k in costs.keys():
		var req := float(costs[k])
		if k == "wood" or k == "stone":
			req = ceilf(req * discount)
		res[k] = maxf(0.0, float(res.get(k, 0.0)) - req)
	if faction_id == 0:
		resources_changed.emit(faction_id)
	return true


func get_faction_buildings(faction_id: int, building_type: String = "", constructed_only: bool = false) -> Array:
	if spatial_index.is_populated():
		return spatial_index.get_faction_buildings(faction_id, building_type, constructed_only)
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
	if alive_only and spatial_index.is_populated():
		return spatial_index.get_faction_units(faction_id)
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
	if spatial_index.is_populated():
		return spatial_index.get_faction_leader(faction_id)
	for u in get_faction_units(faction_id, true):
		if u.get("is_leader"):
			return u
	return null


## Rebuilds the spatial index and navigation grid from the live world containers.
func rebuild_spatial_systems() -> void:
	if world_node == null or not is_instance_valid(world_node):
		spatial_index.clear()
		valley_nav.clear()
		return
	spatial_index.rebuild_from_world(world_node)
	valley_nav.configure_from_layout(valley_layout)
	valley_nav.rebuild_from_world(world_node)


func clear_spatial_systems() -> void:
	spatial_index.clear()
	valley_nav.clear()


func get_housing_capacity(faction_id: int) -> int:
	var cap := 2
	var faction: Dictionary = factions.get(faction_id, {})
	for b in get_faction_buildings(faction_id, "", true):
		var b_type: String = b.get("building_type")
		if GameData.BUILDINGS.has(b_type):
			cap += int(GameData.BUILDINGS[b_type]["housing"]) + PerkSystem.get_extra_housing(faction, b_type)
	return cap


func get_faction_military_power(faction_id: int) -> float:
	var power := 0.0
	for u in get_faction_units(faction_id, true):
		if u.get("role") == GameData.Role.WARRIOR or u.get("is_leader"):
			power += float(u.get("max_hp")) * 0.4 + float(u.get("attack_damage")) * 3.0
	return power


func trigger_conquest_if_eligible(target_faction_id: int, attacker_faction_id: int) -> void:
	DiplomacyConquestRules.trigger_conquest_if_eligible(self, target_faction_id, attacker_faction_id)


func ensure_rival_leader(faction_id: int) -> Node:
	return DiplomacyConquestRules.ensure_rival_leader(self, faction_id)


func restore_rival_leadership() -> void:
	DiplomacyConquestRules.restore_rival_leadership(self)


func _mark_faction_eliminated_by_third_party(target_faction_id: int, attacker_faction_id: int) -> void:
	DiplomacyConquestRules.mark_faction_eliminated_by_third_party(self, target_faction_id, attacker_faction_id)


func resolve_conquest(target_faction_id: int, choice: String) -> void:
	DiplomacyConquestRules.resolve_conquest(self, target_faction_id, choice)


func check_victory_conditions() -> void:
	DiplomacyConquestRules.check_victory_conditions(self)


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
	for fid in saved_factions.keys():
		var faction: Dictionary = saved_factions[fid]
		faction["camp_position"] = CampaignSave.pack_position(faction["camp_position"])
		var fc: Node = faction_controllers.get(int(fid))
		if is_instance_valid(fc) and fc.has_method("serialize"):
			var fc_state: Dictionary = fc.serialize()
			for k in fc_state.keys():
				faction[k] = fc_state[k]

	var player_ctrl_data: Dictionary = {}
	if is_instance_valid(player_controller) and player_controller.has_method("serialize"):
		player_ctrl_data = player_controller.serialize()
		if saved_factions.has(0):
			saved_factions[0]["blessing_cooldown"] = float(player_ctrl_data.get("blessing_cooldown", 0.0))

	var save_payload := {
		"version": CampaignSave.VERSION,
		"valley_layout_id": valley_layout.id,
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
		"player_controller": player_ctrl_data,
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
	progression_changed.emit(0)
	push_log("Campaign loaded (Day %d)." % day_count, "success")
	return true


func _apply_campaign_snapshot(parsed: Dictionary) -> void:
	valley_layout = Layout.new(parsed["valley_layout_id"])
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
	for fid in factions.keys():
		var fstock: Dictionary = factions[fid].get("stockpile", {})
		for opt_key in CampaignSave.OPTIONAL_STOCKPILE_FIELDS:
			if not fstock.has(opt_key):
				fstock[opt_key] = 0
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
	clear_spatial_systems()
	valley_layout = Layout.new()
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

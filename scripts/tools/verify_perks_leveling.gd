extends SceneTree
## Forward+ verification for Tribal Level, Perks & Skills System.
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.

const PerkSystem = preload("res://scripts/core/perk_system.gd")

var _state: Node
var _data: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, caption: String) -> bool:
	if condition:
		print("PASS ", caption)
	else:
		push_error("FAIL " + caption)
		_failures += 1
	return condition


func _frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event, true)


func _find_tagged_button(scope: Node, key_name: String) -> Button:
	for control in scope.find_children("*", "Button", true, false):
		if control.get_meta("drawer_focus", "") == key_name and control.is_visible_in_tree():
			return control as Button
	return null


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return

	_state = root.get_node("GameState")
	_data = root.get_node("GameData")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	seed(17394)
	_state.start_new_campaign("Enoch", "Perk Tribe", GameData.Lineage.CRAG_BORN)
	await _frames(3)

	var hud: Control = _state.hud_controller
	var pc: Node = _state.player_controller
	var fc0: Node = _state.faction_controllers[0]
	var probe_path := "user://perks_probe_%d.json" % Time.get_ticks_usec()

	# 1. Initial level, XP, skill points, perks across player & rivals
	for fid in [0, 1, 2, 3, 4, 6]:
		var fdata: Dictionary = _state.factions[fid]
		_check(PerkSystem.get_level(fdata) == 1 and is_zero_approx(PerkSystem.get_xp(fdata)) \
			and PerkSystem.get_skill_points(fdata) == 0 and fdata["perks"].is_empty(),
			"Faction %d starts at Lv.1 with 0 XP, 0 Skill Points, and empty perks" % fid)

	# 2. BuildDrawer building unlock gating at Level 1
	var camp: Node = fc0.spawn_building("CAMPFIRE", Vector3(0.0, 0.0, 52.0), 0.0, true)
	_state.factions[0]["is_founded"] = true
	_state.factions[0]["camp_position"] = camp.global_position
	var res0: Dictionary = _state.factions[0]["resources"]
	for rk in ["food", "wood", "stone", "flint", "hide", "bone", "faith"]:
		res0[rk] = 300.0

	_key(KEY_B)
	await _frames(2)
	_check(hud._active_tab == "BUILD", "B opens Build drawer")
	var build_drawer: Control = hud._drawer_views["BUILD"]
	var place_btn: Button = _find_tagged_button(build_drawer, "place")
	for starter in ["CAMPFIRE", "SLEEPING_HUT", "PALISADE_WALL"]:
		var s_btn: Button = _find_tagged_button(build_drawer, starter)
		if _check(s_btn != null, "BuildDrawer lists %s" % starter):
			s_btn.pressed.emit()
			await _frames(1)
			_check(place_btn != null and not place_btn.disabled, "%s is unlocked at Level 1" % starter)
	for gated in ["CROP_FIELD", "BARRACKS", "WATCHTOWER", "ANIMAL_PEN", "STANDING_STONE_GATE"]:
		var g_btn: Button = _find_tagged_button(build_drawer, gated)
		if _check(g_btn != null, "BuildDrawer lists gated %s" % gated):
			g_btn.pressed.emit()
			await _frames(1)
			_check(place_btn != null and place_btn.disabled and place_btn.text.begins_with("Requires"),
				"%s is gated at Level 1 (%s)" % [gated, place_btn.text])
	_key(KEY_ESCAPE)
	await _frames(2)

	# 3. XP award, Level-ups, HUD top bar & PerksDrawer via K
	_state.award_xp(0, 80.0 + 135.0 + 190.0 + 245.0, "Test milestones") # Lv.1 -> Lv.5 (4 skill points)
	await _frames(2)
	_check(PerkSystem.get_level(_state.factions[0]) == 5 and PerkSystem.get_skill_points(_state.factions[0]) == 4,
		"Awarding XP advances player to Lv.5 with 4 Skill Points")
	_check(hud._pop_label.text.contains("Lv.5") and hud._drawer_links["PERKS"].text == "Perks (+4)  K",
		"HUD top bar displays Lv.5 and Perks (+4)  K indicator")

	_key(KEY_K)
	await _frames(2)
	_check(hud._active_tab == "PERKS", "K opens PerksDrawer")
	var perks_drawer: Control = hud._drawer_views["PERKS"]
	var mb_btn: Button = _find_tagged_button(perks_drawer, "perk:MASTER_BUILDERS")
	_check(mb_btn != null and not mb_btn.disabled and mb_btn.text == "Learn (1 Pt)",
		"PerksDrawer enables learning Master Builders")
	if mb_btn != null:
		mb_btn.pressed.emit()
	await _frames(2)
	_check(_state.get_perk_rank(0, "MASTER_BUILDERS") == 1 and PerkSystem.get_skill_points(_state.factions[0]) == 3,
		"Clicking Learn unlocks Master Builders Rank 1 and spends 1 Skill Point")
	_key(KEY_ESCAPE)
	await _frames(2)

	# 4. Masonry perks: unlock buildings, cost discount, Max HP scaling, passive repair & housing capacity
	var hut: Node = fc0.spawn_building("SLEEPING_HUT", Vector3(8.0, 0.0, 52.0), 0.0, true)
	var base_hut_hp: float = float(_data.BUILDINGS["SLEEPING_HUT"]["max_hp"])
	var base_housing: int = _state.get_housing_capacity(0) # 2 (base) + 2 (Campfire) + 4 (Hut) = 8
	_state.award_xp(0, 2000.0, "Extra levels for testing all branches") # Advance up to higher level/points
	var lvl_now: int = PerkSystem.get_level(_state.factions[0])
	_check(lvl_now >= 8, "XP advances tribe to Lv.%d for tier-2/3 perks" % lvl_now)

	_check(_state.unlock_perk(0, "STONE_FOUNDATIONS") and _state.unlock_perk(0, "GREAT_LODGES") and _state.unlock_perk(0, "MASTERWORK_DEFENCES"),
		"Unlock Stone-Bound Foundations, Great Lodges, and Masterwork Defences")
	_check(is_equal_approx(float(hut.max_hp), base_hut_hp * 1.2),
		"Stone-Bound Foundations scales existing Sleeping Hut max_hp by 1.2x")
	_check(_state.get_housing_capacity(0) == base_housing + 2,
		"Great Lodges increases Campfire + Sleeping Hut housing capacity (+2 total)")
	hut.hp = hut.max_hp * 0.5
	hut._combat_timer = 0.0
	hut._physics_process(2.0)
	_check(float(hut.hp) > hut.max_hp * 0.5,
		"Stone-Bound Foundations passively repairs damaged out-of-combat building")

	# Cost reduction check: MASTER_BUILDERS Rank 1 gives -10% wood/stone
	res0["wood"] = 18.0
	res0["stone"] = 9.0
	_check(_state.can_afford(0, {"wood": 20, "stone": 10}, true) and not _state.can_afford(0, {"wood": 20, "stone": 10}, false),
		"Master Builders discounts building Wood/Stone cost (-10%) without discounting non-buildings")
	for rk2 in ["food", "wood", "stone", "flint", "hide", "bone", "faith"]:
		res0[rk2] = 300.0

	_key(KEY_B)
	await _frames(2)
	place_btn = _find_tagged_button(build_drawer, "place")
	for unlocked_b in ["CROP_FIELD", "STORAGE_PIT", "STANDING_STONE_GATE", "SHAMAN_SHACK", "ANIMAL_PEN", "WATCHTOWER"]:
		var ub_btn: Button = _find_tagged_button(build_drawer, unlocked_b)
		if _check(ub_btn != null, "BuildDrawer lists %s" % unlocked_b):
			ub_btn.pressed.emit()
			await _frames(1)
			_check(place_btn != null and not place_btn.disabled, "%s unlocks in BuildDrawer after Masonry perks" % unlocked_b)
	_key(KEY_ESCAPE)
	await _frames(2)

	# 5. Might perks: Leader & Warrior HP, armor, damage, speed & cooldown reduction
	var leader: Node = _state.get_faction_leader(0)
	var warrior: Node = fc0.spawn_colonist(Vector3(-4.0, 0.0, 52.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR)
	var l_hp_before: float = float(leader.max_hp)
	var l_dmg_before: float = float(leader.attack_damage)
	var l_spd_before: float = float(leader.move_speed)
	var w_hp_before: float = float(warrior.max_hp)
	var w_dmg_before: float = float(warrior.attack_damage)
	var w_arm_before: float = float(warrior.armor)

	_state.factions[0]["skill_points"] = int(_state.factions[0]["skill_points"]) + 4
	_check(_state.unlock_perk(0, "PRIMAL_VIGOR") and _state.unlock_perk(0, "WARLORDS_EDGE") \
		and _state.unlock_perk(0, "SWIFT_STRIDE") and _state.unlock_perk(0, "DIVINE_CONDUIT"),
		"Unlock all Might branch perks (Primal Vigor, Warlord's Edge, Swift Stride, Divine Conduit)")
	_check(leader.max_hp > l_hp_before * 1.19 and warrior.max_hp > w_hp_before * 1.09,
		"Primal Vigor scales Leader (+20%) and Warrior (+10%) Max HP")
	_check(leader.attack_damage > l_dmg_before * 1.19 and warrior.attack_damage > w_dmg_before * 1.09 \
		and warrior.armor >= w_arm_before + 2.0,
		"Warlord's Edge scales Leader/Warrior damage and armor")
	_check(leader.move_speed > l_spd_before * 1.09,
		"Swift Stride boosts tribe movement speed (+10%)")

	pc._try_dash()
	var dash_cd_after: float = float(pc._dash_cd)
	pc._try_melee_cleave()
	var atk_cd_after: float = float(pc._attack_cd)
	pc._try_god_blessing()
	var bless_cd_after: float = float(pc._blessing_cd)
	_check(dash_cd_after < 1.5 and atk_cd_after < 0.43 and bless_cd_after < 11.0,
		"Might perks reduce Leader Dash, Cleave, and Blessing cooldowns")

	# 6. Kinship perks: Hire Nomad Villager, boosted base stats & rank, Barracks Rank VIII, Combat XP & Auto-equip
	_state.factions[0]["skill_points"] = int(_state.factions[0]["skill_points"]) + 6
	_check(_state.unlock_perk(0, "CALL_OF_THE_HEARTH") \
		and _state.unlock_perk(0, "SEASONED_BLOODLINES") \
		and _state.unlock_perk(0, "SEASONED_BLOODLINES") \
		and _state.unlock_perk(0, "BARRACKS_DRILLMASTERS") \
		and _state.unlock_perk(0, "BARRACKS_DRILLMASTERS") \
		and _state.unlock_perk(0, "BATTLE_VETERANS"),
		"Unlock Kinship perks (Call of the Hearth R1, Seasoned Bloodlines R2, Barracks Drillmasters R2, Battle-Hardened Veterans)")

	_key(KEY_C)
	await _frames(2)
	var colony_drawer: Control = hud._drawer_views["COLONY"]
	var hire_btn: Button = _find_tagged_button(colony_drawer, "hire-nomad")
	_check(hire_btn != null and not hire_btn.disabled, "Hire Nomad Villager button is enabled in ColonyDrawer")
	var pop_before: int = _state.get_faction_units(0, true).size()
	if hire_btn != null:
		hire_btn.pressed.emit()
	await _frames(2)
	var pop_after: int = _state.get_faction_units(0, true).size()
	_check(pop_after == pop_before + 1, "Hiring nomad villager spawns a new colonist")
	var hired: Node = null
	for u in _state.get_faction_units(0, true):
		if u != leader and u != warrior and int(u.melee_rank) >= 1 and float(u._recruit_perks_mult) >= 1.29:
			hired = u
			break
	_check(hired != null, "Hired nomad arrives with Seasoned Bloodlines stat boost (1.30x) and starting Rank I")
	_key(KEY_ESCAPE)
	await _frames(2)

	_key(KEY_B)
	await _frames(2)
	place_btn = _find_tagged_button(build_drawer, "place")
	var barracks_btn: Button = _find_tagged_button(build_drawer, "BARRACKS")
	if _check(barracks_btn != null, "BuildDrawer lists BARRACKS"):
		barracks_btn.pressed.emit()
		await _frames(1)
		_check(place_btn != null and not place_btn.disabled, "BARRACKS unlocks in BuildDrawer after Barracks Drillmasters")
	_key(KEY_ESCAPE)
	await _frames(2)

	# Barracks Drillmasters R2 raises max training rank to 7 (5 + 2)
	warrior.melee_rank = 5
	warrior.ranged_rank = 5
	warrior.training_xp = 0.0
	warrior._gain_training_xp(12.0) # 12.0 * 2.0 (Drillmasters R2) = 24.0 -> Rank 6!
	_check(int(warrior.melee_rank) == 6, "Barracks Drillmasters trains warrior past Rank V to Rank VI")

	# Battle-Hardened Veterans grants live combat training XP and auto-equips stockpile
	_state.factions[0]["stockpile"]["spears"] = 2
	_state.factions[0]["stockpile"]["armor"] = 2
	_state.factions[0]["tech_tier"] = 2
	hired.has_armor = false
	hired.weapon_tier = 1
	_state.assign_player_role(hired, GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN)
	_check(int(hired.weapon_tier) == 2 and bool(hired.has_armor),
		"Battle-Hardened Veterans auto-equips stockpile tier-2 spear and armor on assignment")
	var dummy_enemy: Node = _state.faction_controllers[1].spawn_colonist(warrior.global_position + Vector3(1.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	var txp_before: float = float(warrior.training_xp)
	warrior._execute_attack_on(dummy_enemy)
	_check(float(warrior.training_xp) > txp_before, "Battle-Hardened Veterans awards Training XP on live combat strike")

	# 7. Rival tribes scale up in level and perks automatically
	_state.award_xp(1, 250.0, "Rival XP check")
	_check(PerkSystem.get_level(_state.factions[1]) >= 3 and PerkSystem.get_total_perk_ranks(_state.factions[1]) >= 2,
		"Rival tribe levels up and automatically unlocks personality perks")

	# 8. Save / Load persistence across reload
	var saved_lvl: int = PerkSystem.get_level(_state.factions[0])
	var saved_sp: int = PerkSystem.get_skill_points(_state.factions[0])
	var saved_hut_max: float = float(hut.max_hp)
	_check(_state.save_game(probe_path) and _state.load_game(probe_path), "Save and reload campaign with perks and levels")
	await _frames(3)
	_check(PerkSystem.get_level(_state.factions[0]) == saved_lvl \
		and PerkSystem.get_skill_points(_state.factions[0]) == saved_sp \
		and _state.get_perk_rank(0, "BARRACKS_DRILLMASTERS") == 2 \
		and _state.get_perk_rank(1, "PRIMAL_VIGOR") >= 1,
		"Reload restores player & rival levels, skill points, and perks")
	var reloaded_huts: Array = _state.get_faction_buildings(0, "SLEEPING_HUT", true)
	_check(reloaded_huts.size() == 1 and is_equal_approx(float(reloaded_huts[0].max_hp), saved_hut_max),
		"Reload preserves Stone-Bound Foundations scaled building max_hp")
	var found_rank6 := false
	for u in _state.get_faction_units(0, true):
		if int(u.melee_rank) == 6:
			found_rank6 = true
			break
	_check(found_rank6, "Reload preserves warrior Rank VI above legacy cap")

	# 9. Regression checks: Watchtower vs unarmed civilian, and RETREAT + Barracks Drillmasters
	_state.current_phase = GameData.SchedulePhase.DAY_WORK
	_state.set_diplomatic_state(0, 1, GameData.DiplomaticState.AT_WAR)
	var fc1: Node = _state.faction_controllers[1]
	var tower_pos := Vector3(-42.0, 0.0, 52.0)
	var enemy_tower: Node = fc1.spawn_building("WATCHTOWER", tower_pos, 0.0, true)
	enemy_tower._watchtower_cd = 0.0
	enemy_tower._scan_cd = 0.0
	var civ: Node = _state.faction_controllers[0].spawn_colonist(
		tower_pos + Vector3(2.8, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER
	)
	var civ_hp_before: float = float(civ.hp)
	for _tick in range(45):
		await physics_frame
		if float(civ.hp) < civ_hp_before:
			break
	for _tick in range(10):
		await physics_frame
	_check(float(civ.hp) < civ_hp_before, "Hostile Watchtower shoots unarmed civilian within 4 m")
	_check(civ._self_defense_target == null and is_instance_valid(enemy_tower) and not enemy_tower.is_destroyed,
		"Unarmed civilian shot by Watchtower does not target building for self-defense")
	civ.queue_free()
	enemy_tower.queue_free()
	await _frames(2)

	var camp_pos: Vector3 = _state.factions[0].get("camp_position", Vector3(0.0, 0.0, 52.0))
	var test_barracks: Node = _state.faction_controllers[0].spawn_building("BARRACKS", camp_pos + Vector3(0.0, 0.0, 10.0), 0.0, true)
	var retreat_warrior: Node = _state.faction_controllers[0].spawn_colonist(
		camp_pos + Vector3(0.0, 0.0, 2.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR
	)
	retreat_warrior.squad_order = GameData.SquadOrder.RETREAT
	var reached_barracks := false
	for _tick in range(180):
		await physics_frame
		if (retreat_warrior as Node3D).global_position.distance_to((test_barracks as Node3D).global_position) <= 3.6:
			reached_barracks = true
			break
	for _tick in range(30):
		await physics_frame
	var dist_to_barracks: float = (retreat_warrior as Node3D).global_position.distance_to((test_barracks as Node3D).global_position)
	var dist_to_camp: float = (retreat_warrior as Node3D).global_position.distance_to(camp_pos)
	_check(reached_barracks and dist_to_barracks <= 3.8 and dist_to_camp > 5.0,
		"RETREAT warrior reaches and stays at Barracks 10 m from camp without oscillating")
	retreat_warrior.queue_free()
	test_barracks.queue_free()
	await _frames(2)

	_state.end_campaign()
	root.remove_child(main)
	main.queue_free()
	if FileAccess.file_exists(probe_path):
		DirAccess.remove_absolute(probe_path)
	await _frames(2)

	if _failures == 0:
		print("PERKS AND LEVELING VERIFICATION PASSED")
		quit(0)
	else:
		print("PERKS AND LEVELING VERIFICATION FAILED (%d)" % _failures)
		quit(1)

extends SceneTree
## Builds temporary v1, v2, and v3 fixtures through the real campaign save path.

const Layout = preload("res://scripts/core/world_layout.gd")

var _state: Node
var _main: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, caption: String) -> void:
	if not condition:
		_failures += 1
		push_error(caption)


func _mount() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _unmount() -> void:
	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()


func _run() -> void:
	_state = root.get_node("GameState")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return
	var path := "user://probe-%d.json" % Time.get_ticks_usec()
	_mount()
	_state.start_new_campaign("Enoch", "Restoration Probe", GameData.Lineage.CRAG_BORN)
	var player: Node = _state.get_faction_leader(0)
	var leader_id: int = player.unit_id
	var colony: Node = _state.faction_controllers[0]
	colony.spawn_colonist(Vector3(66, 0, 52), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	var damaged: Node = colony.spawn_building("SLEEPING_HUT", Vector3(62, 0, 52), 0.5, true)
	damaged.hp = damaged.max_hp * 0.28
	damaged.sync_visual_from_state()
	colony.spawn_building("CAMPFIRE", Vector3(56, 0, 52), 0.0, false)
	_state.tutorial_step = 3
	_state.tutorial_harvested = true
	_state.warhorn_active = true
	_state.combat_command_system.issue_order(GameData.SquadOrder.HOLD, player.global_position)
	var fallen: Node = _state.get_faction_leader(1)
	fallen.is_dead = true
	_state.trigger_conquest_if_eligible(1, 0)
	if not _state.save_game(path):
		push_error("Could not write the v3 fixture.")
		quit(1)
		return
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(current["version"]) == 3, "The writer emits schema v3")
	_unmount()
	await process_frame
	_mount()
	var events: Array[String] = []
	_state.game_started.connect(func(): events.append("started"))
	_state.campaign_loaded.connect(func():
		_check(_state.get_faction_leader(0).unit_id == leader_id, "The leader is attached with its original ID before campaign_loaded")
		_check(_state.combat_command_system.last_issued_order == GameData.SquadOrder.HOLD, "Commands restore before campaign_loaded")
		events.append("loaded")
	, CONNECT_ONE_SHOT)
	_state.conquest_triggered.connect(func(_faction: int): events.append("conquest"), CONNECT_ONE_SHOT)
	_check(_state.load_game(path), "Cold load v3")
	_check(events == ["started", "loaded", "conquest"], "Cold-load signals retain their order")
	var buildings: Array = _state.get_faction_buildings(0, "SLEEPING_HUT")
	_check(buildings.size() == 1 and buildings[0].damage_stage == 2, "Critical stage derives from saved HP")
	_check(not _state.get_faction_buildings(0, "CAMPFIRE")[0].is_constructed, "Blueprint remains unfinished")
	_check(_state.tutorial_step == 3 and _state.tutorial_harvested and _state.warhorn_active, "Guide and warhorn restore")
	var live_world: Node = _state.world_node
	var live_leader: Node = _state.get_faction_leader(0)
	_write(path, "{ malformed")
	_check(not _state.load_game(path) and _state.get_faction_leader(0) == live_leader, "Malformed input preserves live entities")
	var future := current.duplicate(true)
	future["version"] = 99
	_write(path, JSON.stringify(future))
	_check(not _state.load_game(path) and _state.world_node == live_world, "Unsupported input preserves the world")
	var units: Array = current["units"]
	var missing_leader := current.duplicate(true)
	missing_leader["units"] = units.filter(func(unit: Dictionary): return int(unit["faction_id"]) != 0 or not unit["is_leader"])
	_write(path, JSON.stringify(missing_leader))
	_check(not _state.load_game(path) and _state.get_faction_leader(0) == live_leader, "A v3 save missing its recorded leader is rejected before restore")
	missing_leader["units"] = units.filter(func(unit: Dictionary): return int(unit["faction_id"]) != 0)
	missing_leader.erase("player_leader_id")
	_write(path, JSON.stringify(missing_leader))
	_check(_state.read_campaign_save(path).has("data"), "A v3 save with no surviving player units remains readable")
	var legacy := current.duplicate(true)
	legacy.erase("wildlife")
	legacy.erase("combat_commands")
	legacy.erase("pending_conquests")
	legacy.erase("player_leader_id")
	legacy.erase("player_controller")
	for fkey in legacy["factions"].keys():
		legacy["factions"][fkey].erase("raid_cooldown")
		legacy["factions"][fkey].erase("caveman_spawn_timer")
		legacy["factions"][fkey].erase("diplomacy_event_cd")
	legacy["version"] = 2
	var old_wildlife: Node = _state.wildlife_container.get_child(0)
	old_wildlife.is_dead = true
	_state.player_controller._blessing_cd = 9.0
	_write(path, JSON.stringify(legacy))
	_check(_state.load_game(path), "In-session reload accepts v2")
	_check(old_wildlife.is_queued_for_deletion() and old_wildlife.get_parent() == null, "Legacy in-session reload clears previous-session wildlife without leaking")
	_check(_state.wildlife_container.get_child_count() == 25, "Legacy in-session reload respawns clean baseline wildlife")
	var all_wildlife_alive := true
	for animal in _state.wildlife_container.get_children():
		if animal.get("is_dead") == true:
			all_wildlife_alive = false
			break
	_check(all_wildlife_alive, "Respawned baseline wildlife on legacy in-session reload are all alive")
	_check(is_equal_approx(float(_state.player_controller._blessing_cd), 0.0), "Legacy v2 reload resets PlayerController blessing cooldown cleanly")
	legacy.erase("version")
	for unit in legacy["units"]:
		unit.erase("unit_id")
	_write(path, JSON.stringify(legacy))
	_unmount()
	await process_frame
	_mount()
	_check(_state.load_game(path), "Cold load accepts an unversioned v1 fixture")
	_check(_state.wildlife_container.get_child_count() == 25, "Missing wildlife repopulates on cold load")
	var ids := {}
	for unit in _state.units_container.get_children():
		_check(unit.unit_id > 0 and not ids.has(unit.unit_id), "Legacy unit IDs become positive and unique")
		ids[unit.unit_id] = true
	_check_guide_reward()
	_check_combat()
	_check_slice_0a()
	_check_slice_0b()
	await _check_slice_0c(path)
	_unmount()
	DirAccess.remove_absolute(path)
	await process_frame
	if _failures == 0:
		print("CAMPAIGN SAVE VERIFICATION PASSED")
	quit(0 if _failures == 0 else 1)


func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not rewrite the temporary fixture")
		return
	file.store_string(contents)
	file.close()


func _check_guide_reward() -> void:
	_state.hud_controller.hide()
	_state.tutorial_step = 5
	_state.tutorial_cleaved = true
	_state.tutorial_thrown = true
	var resources: Dictionary = _state.factions[0]["resources"]
	var before := resources.duplicate()
	_state._process(0.36)
	_check(_state.tutorial_completed, "Guide completes while the HUD is hidden")
	for key in ["food", "wood", "flint"]:
		var reward := 5.0 if key == "flint" else 10.0
		_check(is_equal_approx(float(resources[key]), float(before[key]) + reward), "Guide pays the expected " + key + " reward")
	var after := resources.duplicate()
	_state._process(0.36)
	_check(resources == after, "Guide reward is paid once")


func _check_combat() -> void:
	if _state.warhorn_active:
		_state.combat_command_system.toggle_warhorn()
	var ally: Node = _state.faction_controllers[0]
	var rival: Node = _state.faction_controllers[2]
	var center := Vector3(152, 0, 150)
	var civilian: Node = ally.spawn_colonist(center, GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	civilian.base_melee_stat = 10.0
	civilian.recalculate_stats(true)
	var opponent: Node = rival.spawn_colonist(center + Vector3.RIGHT, GameData.Lineage.SWIFT_KIN, GameData.Gender.MALE, GameData.Role.FORAGER)
	opponent.armor = 0.0
	_state.set_diplomatic_state(0, 2, GameData.DiplomaticState.AT_WAR)
	var before: float = opponent.hp
	civilian._process_tribal_ai(0.0)
	_check(is_equal_approx(before - float(opponent.hp), 3.78), "Cornered adult civilian delivers the baseline unarmed strike")
	_check(is_equal_approx(float(civilian._attack_cd), 1.15), "Unarmed strike uses the baseline cooldown")

	var brute: Node = ally.spawn_colonist(center + Vector3(0, 0, 8), GameData.Lineage.GOLIATH, GameData.Gender.MALE, GameData.Role.WARRIOR)
	brute.base_hp_stat = 100.0
	brute.base_melee_stat = 10.0
	brute.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.BRUTE)
	_check(is_equal_approx(float(brute.max_hp), 207.0), "Fixed Goliath Brute derives baseline maximum HP")
	var wall: Node = rival.spawn_building("PALISADE_WALL", brute.global_position + Vector3.RIGHT, 0.0, true)
	before = wall.hp
	brute._engage_building(wall)
	_check(is_equal_approx(before - float(wall.hp), 31.438125), "Brute retains the baseline multiplier against buildings")

	var impact: Vector3 = opponent.global_position + Vector3.UP
	var projectile: Node = load("res://scripts/entities/projectile_3d.gd").spawn(brute, 0, impact - Vector3.RIGHT, impact, 12.0)
	_state.units_container.remove_child(brute)
	brute.free()
	opponent.armor = 10.0
	before = opponent.hp
	projectile.global_position = impact
	projectile.velocity = Vector3.ZERO
	projectile.gravity = 0.0
	projectile._physics_process(0.016)
	_check(is_equal_approx(before - float(opponent.hp), 7.5), "Projectile retains faction attribution and armor mitigation after its shooter is freed")


func _check_slice_0a() -> void:
	_state.start_new_campaign("Enoch", "Slice0A Probe", GameData.Lineage.CRAG_BORN)

	# (g) Diplomatic opinion breakdown matches get_diplomatic_opinion() across states & tenets
	_state.factions[0]["patron_god"] = int(_state.factions[4]["patron_god"])
	_state.factions[0]["tenets"] = ["PEACEFUL_OFFERING"]
	for fid in range(1, 5):
		var bd: Dictionary = _state.get_diplomatic_opinion_breakdown(0, fid)
		var expected_sum: int = int(bd["god"]) + int(bd["tenets"]) + int(bd["peaceful_offering"]) + int(bd["actions"]) + int(bd["state_bound"])
		_check(expected_sum == int(bd["total"]), "Opinion breakdown sums cleanly to total for faction %d" % fid)
		_check(int(bd["total"]) == _state.get_diplomatic_opinion(0, fid), "Opinion breakdown total matches get_diplomatic_opinion for faction %d" % fid)
	var neutral_bd: Dictionary = _state.get_diplomatic_opinion_breakdown(0, 4)
	_check(int(neutral_bd["god"]) == 30 and int(neutral_bd["peaceful_offering"]) == 15, "Breakdown exposes god and peaceful_offering bonuses")
	_state.set_diplomatic_state(0, 4, GameData.DiplomaticState.AT_WAR)
	var war_bd: Dictionary = _state.get_diplomatic_opinion_breakdown(0, 4)
	_check(int(war_bd["total"]) == -35 and int(war_bd["state_bound"]) < 0, "AT_WAR opinion cap is captured in state_bound")
	_check(
		int(war_bd["god"]) + int(war_bd["tenets"]) + int(war_bd["peaceful_offering"]) + int(war_bd["actions"]) + int(war_bd["state_bound"]) == int(war_bd["total"]),
		"AT_WAR opinion breakdown sums to total"
	)

	# (e) promote_to_player_leader() creates _selection_ring, grants armor/weapon, clears raid & retreat flags
	var colony: Node = _state.faction_controllers[0]
	var heir: Node = colony.spawn_colonist(Vector3(12, 0, 52), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER)
	heir.is_raiding = true
	heir._retreating_to_heal = true
	heir.has_armor = false
	heir.has_equipped_weapon = false
	_check(heir._selection_ring == null, "Non-leader starts without _selection_ring")
	heir.promote_to_player_leader()
	_check(heir._selection_ring != null and is_instance_valid(heir._selection_ring), "promote_to_player_leader creates _selection_ring")
	_check(heir.has_armor and heir.has_equipped_weapon, "promote_to_player_leader grants armor and equipped weapon")
	_check(not heir.is_raiding and not heir._retreating_to_heal, "promote_to_player_leader clears raiding and retreat state")

	# (f) Replacement Campfire updates camp_position after original Campfire is destroyed
	var orig_camp_pos := Vector3(16.0, 0.0, 52.0)
	var camp_a: Node = colony.spawn_building("CAMPFIRE", orig_camp_pos, 0.0, true)
	_state.factions[0]["is_founded"] = true
	_state.factions[0]["camp_position"] = orig_camp_pos
	camp_a.take_damage(camp_a.max_hp + 50.0, 5)
	_check(camp_a.is_destroyed, "Original Campfire enters destroyed state")
	var new_camp_pos := Vector3(30.0, 0.0, 48.0)
	var camp_b: Node = colony.spawn_building("CAMPFIRE", new_camp_pos, 0.0, false)
	camp_b.advance_construction(camp_b.build_time + 1.0)
	var updated_camp: Vector3 = _state.factions[0]["camp_position"]
	_check(updated_camp.distance_to(new_camp_pos) < 0.05, "Completed replacement Campfire updates camp_position")

	# (d) Pause and campaign_finished freeze entity ticks, rubble sinking, and PlayerController cooldowns
	var pc: Node = _state.player_controller
	pc._dash_cd = 1.5
	pc._attack_cd = 0.4
	pc._javelin_cd = 1.0
	pc._blessing_cd = 10.0
	pc._harvest_cd = 0.4
	var sink_before: float = float(camp_a._sink_timer)
	heir._attack_cd = 2.0
	var wild: Node = _state.wildlife_container.get_child(0)
	wild._attack_cd = 1.2
	_state.is_paused = true
	camp_a._physics_process(0.5)
	heir._physics_process(0.5)
	wild._physics_process(0.5)
	pc._physics_process(0.5)
	_check(is_equal_approx(float(camp_a._sink_timer), sink_before), "Paused rubble does not tick _sink_timer")
	_check(is_equal_approx(float(heir._attack_cd), 2.0), "Paused HumanUnit does not tick cooldowns")
	_check(is_equal_approx(float(wild._attack_cd), 1.2), "Paused WildlifeEntity does not tick cooldowns")
	_check(
		is_equal_approx(float(pc._dash_cd), 1.5) and is_equal_approx(float(pc._attack_cd), 0.4)
		and is_equal_approx(float(pc._javelin_cd), 1.0) and is_equal_approx(float(pc._blessing_cd), 10.0)
		and is_equal_approx(float(pc._harvest_cd), 0.4),
		"Paused PlayerController does not tick cooldowns"
	)
	_state.is_paused = false
	_state.campaign_finished = true
	camp_a._physics_process(0.5)
	heir._physics_process(0.5)
	wild._physics_process(0.5)
	pc._physics_process(0.5)
	_check(is_equal_approx(float(camp_a._sink_timer), sink_before), "campaign_finished freezes rubble _sink_timer")
	_check(is_equal_approx(float(heir._attack_cd), 2.0), "campaign_finished freezes HumanUnit ticks")
	_check(is_equal_approx(float(wild._attack_cd), 1.2), "campaign_finished freezes WildlifeEntity ticks")
	_check(
		is_equal_approx(float(pc._dash_cd), 1.5) and is_equal_approx(float(pc._attack_cd), 0.4)
		and is_equal_approx(float(pc._javelin_cd), 1.0) and is_equal_approx(float(pc._blessing_cd), 10.0)
		and is_equal_approx(float(pc._harvest_cd), 0.4),
		"campaign_finished freezes PlayerController cooldowns"
	)
	_state.campaign_finished = false

	# (a) RAZE conquest frees living enemy leader
	var rival1_leader: Node = _state.get_faction_leader(1)
	_check(rival1_leader != null and not rival1_leader.is_dead, "Rival 1 has a living leader before RAZE")
	for b in _state.get_faction_buildings(1, "CAMPFIRE", true):
		b.take_damage(b.max_hp + 50.0, 0)
	for b in _state.get_faction_buildings(1, "SACRED_TOTEM", true):
		b.take_damage(b.max_hp + 50.0, 0)
	_check(_state._conquest_pending_factions.has(1), "Destroying rival 1 Campfire+Totem triggers conquest while leader lives")
	_state.resolve_conquest(1, "RAZE")
	_check(_state.factions[1]["is_defeated"] == true, "RAZE marks rival 1 defeated")
	_check(rival1_leader.is_queued_for_deletion(), "RAZE queues living enemy leader for deletion")
	_check(_state.get_faction_units(1, true).is_empty(), "RAZE leaves no living units in faction 1")

	# (b) Third-party rival wipe marks is_defeated = true and allows victory
	var victory_events: Array[String] = []
	var on_victory := func(reason: String): victory_events.append(reason)
	_state.victory_achieved.connect(on_victory)
	var rival2_leader: Node = _state.get_faction_leader(2)
	rival2_leader.is_dead = true
	_state.trigger_conquest_if_eligible(2, 5)
	_check(_state.factions[2]["is_defeated"] == true and not _state._conquest_pending_factions.has(2), "Cavemen eliminating rival 2 marks it defeated without conquest modal")

	var rival3_leader: Node = _state.get_faction_leader(3)
	rival3_leader.is_dead = true
	_state.trigger_conquest_if_eligible(3, -1)
	_check(_state.factions[3]["is_defeated"] == true and not _state._conquest_pending_factions.has(3), "Wildlife eliminating rival 3 marks it defeated without conquest modal")

	var rival4_leader: Node = _state.get_faction_leader(4)
	rival4_leader.is_dead = true
	_state.trigger_conquest_if_eligible(4, 2)
	_check(_state.factions[4]["is_defeated"] == true, "Non-allied rival eliminating rival 4 marks it defeated")
	_check(_state.campaign_finished and victory_events.size() == 1, "Victory triggers cleanly once all rivals are defeated including third-party wipes")
	_state.victory_achieved.disconnect(on_victory)

	# (c) Field aid without Shaman Shack does not freeze being_rescued, Shaman claim clears on interruption,
	#     and wounded defection triggers defeat when no healthy player units remain
	_state.start_new_campaign("Enoch", "Wounded Probe", GameData.Lineage.CRAG_BORN)
	var p_leader: Node = _state.get_faction_leader(0)
	var p_colony: Node = _state.faction_controllers[0]
	var rebel_unit: Node = p_colony.spawn_colonist(p_leader.global_position + Vector3(1.5, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	rebel_unit.enter_wounded_state()
	var timer_before_aid: float = float(rebel_unit.wounded_timer)
	_state.player_controller._try_interact_or_harvest()
	_check(not rebel_unit.being_rescued, "Field aid without Shaman Shack does not freeze being_rescued")
	_check(float(rebel_unit.wounded_timer) > timer_before_aid, "First field aid applies one-time stabilization")
	var timer_after_first: float = float(rebel_unit.wounded_timer)
	_state.player_controller._try_interact_or_harvest()
	_check(is_equal_approx(float(rebel_unit.wounded_timer), timer_after_first), "Repeated field aid cannot extend wounded_timer indefinitely")
	rebel_unit._physics_process(1.0)
	_check(float(rebel_unit.wounded_timer) < timer_after_first, "Wounded timer keeps ticking after field aid without a shack")

	var shaman: Node = p_colony.spawn_colonist(p_leader.global_position + Vector3(8.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.SHAMAN)
	rebel_unit.claim_rescue(shaman, 1.5)
	_check(rebel_unit.being_rescued, "Shaman claim marks wounded unit as being_rescued")
	shaman.set_role_and_class(GameData.Role.FORAGER)
	rebel_unit._physics_process(0.1)
	_check(not rebel_unit.being_rescued, "Shaman role change clears being_rescued automatically")

	var defeat_events: Array[String] = []
	var on_defeat := func(reason: String): defeat_events.append(reason)
	_state.defeat_triggered.connect(on_defeat)
	for u in _state.get_faction_units(0, true):
		u.is_dead = true
	rebel_unit.wounded_timer = 0.05
	rebel_unit._physics_process(0.1)
	_check(_state.campaign_finished and defeat_events.size() == 1, "Wounded defection triggers defeat when no healthy player units remain")
	_state.defeat_triggered.disconnect(on_defeat)


func _check_slice_0b() -> void:
	_state.start_new_campaign("Enoch", "Slice0B Probe", GameData.Lineage.CRAG_BORN)
	var colony: Node = _state.faction_controllers[0]
	var leader: Node = _state.get_faction_leader(0)
	var base := Vector3(130.0, 0.0, 120.0)
	_state.factions[0]["is_founded"] = true
	_state.factions[0]["camp_position"] = base

	# 1. Warrior & Watchtower engage hostile Wildlife (WOLF) without errors
	var wolf_script: Script = load("res://scripts/entities/wildlife_entity.gd") as Script
	var wolf := CharacterBody3D.new()
	wolf.set_script(wolf_script)
	_state.wildlife_container.add_child(wolf)
	wolf.setup("WOLF", base + Vector3(2.0, 0.0, 0.0))

	var guard: Node = colony.spawn_colonist(base, GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR)
	guard.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN)
	guard.squad_order = GameData.SquadOrder.GUARD_BASE
	var wolf_hp_before: float = float(wolf.hp)
	guard._process_tribal_ai(0.016)
	_check(float(wolf.hp) < wolf_hp_before, "Guard warrior engages and damages hostile Wolf")

	var tower: Node = colony.spawn_building("WATCHTOWER", base + Vector3(0.0, 0.0, 8.0), 0.0, true)
	var wt_target: Node3D = tower._find_nearest_hostile(22.0)
	_check(wt_target == wolf, "Watchtower acquires hostile Wolf as target")
	var proj_count_before: int = _state.projectiles_container.get_child_count()
	tower._watchtower_cd = 0.0
	tower._physics_process(0.016)
	_check(_state.projectiles_container.get_child_count() > proj_count_before, "Watchtower fires arrow at hostile Wolf")
	# Ensure Watchtower damaging Wolf does not set BuildingEntity as _target_unit
	wolf.take_damage(5.0, tower, 0)
	_check(wolf._target_unit != tower, "Watchtower hit does not assign BuildingEntity as wildlife _target_unit")
	wolf._physics_process(0.016)

	# 2. Stoneknapper balances STONE and FLINT instead of locking onto one forever
	for n in _state.resources_container.get_children():
		if is_instance_valid(n) and (n.get_meta("node_type", "") == "STONE" or n.get_meta("node_type", "") == "FLINT"):
			_state.resources_container.remove_child(n)
			n.queue_free()
	var knap_camp := Vector3(-120.0, 0.0, 120.0)
	_state.factions[0]["camp_position"] = knap_camp
	var stone_node := Node3D.new()
	stone_node.set_meta("node_type", "STONE")
	_state.resources_container.add_child(stone_node)
	stone_node.global_position = knap_camp + Vector3(2.0, 0.0, 0.0)
	var flint_node := Node3D.new()
	flint_node.set_meta("node_type", "FLINT")
	_state.resources_container.add_child(flint_node)
	flint_node.global_position = knap_camp + Vector3(-2.0, 0.0, 0.0)
	_state.factions[0]["resources"]["stone"] = 20.0
	_state.factions[0]["resources"]["flint"] = 5.0
	var knapper: Node = colony.spawn_colonist(knap_camp, GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.STONEKNAPPER)
	knapper._day_work_routine(0.1)
	_check(knapper._target_node == flint_node, "Stoneknapper picks FLINT when flint stockpile is lower than stone")
	knapper.global_position = flint_node.global_position
	knapper._day_work_routine(3.5)
	_check(knapper._carry_type == "flint" and float(knapper._carry_amount) > 0.0, "Stoneknapper gathers flint")
	_state.factions[0]["resources"]["flint"] = 30.0
	knapper.global_position = knap_camp
	knapper._day_work_routine(0.1)
	_check(knapper._target_node == null, "Stoneknapper clears _target_node on drop-off")
	knapper._day_work_routine(0.1)
	_check(knapper._target_node == stone_node, "Stoneknapper switches to STONE when stone stockpile is lower than flint")

	# 3. Warhorn does NOT arm children, and keeps civilian militia consistently SPEARMAN
	var child: Node = colony.spawn_colonist(base + Vector3(4.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER, false, true)
	var archer_civ: Node = colony.spawn_colonist(base + Vector3(5.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER, false, false)
	archer_civ.warrior_class = GameData.WarriorClass.ARCHER
	archer_civ.recalculate_stats(false)
	_state.combat_command_system.toggle_warhorn()
	_check(_state.warhorn_active, "Warhorn activated")
	_check(child._get_class_key() == "FORAGER" and not child._is_warhorn_militia(), "Warhorn does NOT arm children")
	_check(archer_civ._get_class_key() == "SPEARMAN" and archer_civ._get_effective_warrior_class() == GameData.WarriorClass.SPEARMAN, "Warhorn civilian militia resolves consistently as SPEARMAN")
	_state.combat_command_system.toggle_warhorn()

	# 4. Tech Tier upgrade advances tech_tier & Leader weapon_tier without upgrading ordinary living warriors until crafted
	colony.spawn_building("CRAFTING_PIT", base + Vector3(8.0, 0.0, 0.0), 0.0, true)
	for rk in ["wood", "stone", "flint", "hide", "bone"]:
		_state.factions[0]["resources"][rk] = 100.0
	_state.factions[0]["stockpile"]["spears"] = 0
	var spear_before_tier: int = int(guard.weapon_tier)
	var upgraded: bool = colony.upgrade_stone_age_tier()
	_check(upgraded and int(_state.factions[0]["tech_tier"]) == 2, "upgrade_stone_age_tier advances faction tech_tier to 2")
	_check(int(leader.weapon_tier) == 2, "Leader auto-scales to new weapon_tier")
	_check(int(guard.weapon_tier) == spear_before_tier, "Living ordinary warrior keeps old weapon_tier until crafted gear is equipped")
	_state.factions[0]["stockpile"]["spears"] = 1
	guard.try_equip_from_stockpile()
	_check(int(guard.weapon_tier) == 2 and int(_state.factions[0]["stockpile"]["spears"]) == 0, "Living warrior upgrades weapon_tier by consuming crafted stockpile")

	# 5. HumanUnit & WildlifeEntity stay clamped inside WorldLayout.UNIT_HALF_EXTENT
	guard.global_position = Vector3(220.0, 0.0, -230.0)
	guard.velocity = Vector3(10.0, 0.0, -10.0)
	guard._physics_process(0.1)
	_check(absf(guard.global_position.x) <= Layout.UNIT_HALF_EXTENT + 0.01 and absf(guard.global_position.z) <= Layout.UNIT_HALF_EXTENT + 0.01, "HumanUnit XZ stays clamped inside world bounds")
	wolf.global_position = Vector3(-240.0, 0.0, 210.0)
	wolf.velocity = Vector3(-10.0, 0.0, 10.0)
	wolf._physics_process(0.1)
	_check(absf(wolf.global_position.x) <= Layout.UNIT_HALF_EXTENT + 0.01 and absf(wolf.global_position.z) <= Layout.UNIT_HALF_EXTENT + 0.01, "WildlifeEntity XZ stays clamped inside world bounds")

	# 6. ANCESTRAL_STONE discounts buildings (is_building=true) ONLY, not crafting/tier/gifts (is_building=false)
	_state.factions[0]["tenets"] = ["ANCESTRAL_STONE"]
	_state.factions[0]["resources"]["wood"] = 10.0
	_state.factions[0]["resources"]["stone"] = 10.0
	_check(_state.can_afford(0, {"wood": 12, "stone": 12}, true), "ANCESTRAL_STONE discounts building wood/stone cost (-20%)")
	_check(not _state.can_afford(0, {"wood": 12, "stone": 12}, false), "ANCESTRAL_STONE does NOT discount non-building wood/stone costs")
	_check(not _state.can_afford(0, {"wood": 12, "stone": 12}), "Default can_afford does NOT apply building discount")

	# 7. Vertical projectile (horiz == 0) spawns/flies cleanly, and swept segment catches fast low-FPS hits
	var proj_script: Script = load("res://scripts/entities/projectile_3d.gd") as Script
	var vert_proj: Node3D = proj_script.spawn(leader, 0, Vector3(0.0, 2.0, 0.0), Vector3(0.0, 8.0, 0.0), 10.0, 20.0, "ARROW", 1, false)
	_check(vert_proj != null, "Vertical projectile spawns cleanly without look_at error")
	vert_proj._physics_process(0.05)
	if is_instance_valid(vert_proj) and not vert_proj.is_queued_for_deletion():
		vert_proj.queue_free()

	var rival_fc: Node = _state.faction_controllers[1]
	_state.set_diplomatic_state(0, 1, GameData.DiplomaticState.AT_WAR)
	var target_u: Node = rival_fc.spawn_colonist(Vector3(40.0, 0.0, 40.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	target_u.armor = 0.0
	var t_hp_before: float = float(target_u.hp)
	var fast_proj: Node3D = proj_script.spawn(leader, 0, Vector3(36.0, 1.0, 40.0), Vector3(44.0, 1.0, 40.0), 15.0, 32.0, "JAVELIN", 1, false)
	fast_proj.gravity = 0.0
	fast_proj.velocity = Vector3(32.0, 0.0, 0.0)
	# Single 0.25s step moves 8m from x=36 to x=44 right through target at x=40
	fast_proj._physics_process(0.25)
	_check(float(target_u.hp) < t_hp_before, "Swept projectile segment detects hit at low FPS without tunneling")

	# 8. Post-truce civilian _self_defense_target clears, Campfire heals only at Dusk & doesn't stack,
	#    and toggle_fire_at_will propagates to newly assigned warriors
	var civ: Node = colony.spawn_colonist(Vector3(41.5, 0.0, 40.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER)
	civ._self_defense_target = target_u
	civ._self_defense_timer = 5.0
	_state.set_diplomatic_state(0, 1, GameData.DiplomaticState.NEUTRAL)
	var truce_hp_before: float = float(target_u.hp)
	civ._process_tribal_ai(0.016)
	_check(civ._self_defense_target == null and is_equal_approx(float(target_u.hp), truce_hp_before), "Civilian clears _self_defense_target and stops attacking after truce")

	_state.combat_command_system.toggle_fire_at_will()
	_check(not _state.combat_command_system.global_fire_at_will, "Fire-at-will toggled off")
	civ.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.ARCHER)
	_check(not civ.fire_at_will, "Newly assigned warrior inherits faction fire_at_will state")
	_state.combat_command_system.toggle_fire_at_will()

	var camp1: Node = colony.spawn_building("CAMPFIRE", Vector3(-60.0, 0.0, -60.0), 0.0, true)
	var camp2: Node = colony.spawn_building("CAMPFIRE", Vector3(-58.0, 0.0, -60.0), 0.0, true)
	var hurt_u: Node = colony.spawn_colonist(Vector3(-59.0, 0.0, -60.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	hurt_u.hp = hurt_u.max_hp * 0.5
	var hp_day_before: float = float(hurt_u.hp)
	_state.current_phase = GameData.SchedulePhase.DAY_WORK
	camp1._dusk_heal_timer = 2.0
	camp1._physics_process(0.1)
	_check(is_equal_approx(float(hurt_u.hp), hp_day_before), "Campfire does not heal during DAY_WORK")
	_state.current_phase = GameData.SchedulePhase.DUSK_HEARTH
	camp1._dusk_heal_timer = 2.0
	camp2._dusk_heal_timer = 2.0
	camp1._physics_process(0.1)
	camp2._physics_process(0.1)
	_check(is_equal_approx(float(hurt_u.hp), hp_day_before + 5.0), "Campfire heals at Dusk and does not stack linearly across overlapping Campfires")


func _find_unit_by_id(uid: int) -> Node:
	if _state.units_container == null:
		return null
	for u in _state.units_container.get_children():
		if is_instance_valid(u) and int(u.get("unit_id")) == uid:
			return u
	return null


func _check_slice_0c(path: String) -> void:
	_state.start_new_campaign("Enoch", "Slice0C Probe", GameData.Lineage.CRAG_BORN)
	var colony: Node = _state.faction_controllers[0]
	var pc: Node = _state.player_controller

	# A. Destroyed/rubble buildings (damage_stage == 3) excluded from get_faction_buildings() & save/load, and hp clamp on load
	var rubble_hut: Node = colony.spawn_building("SLEEPING_HUT", Vector3(20.0, 0.0, 52.0), 0.0, true)
	colony.spawn_building("PALISADE_WALL", Vector3(26.0, 0.0, 52.0), 0.2, true)
	rubble_hut.take_damage(rubble_hut.max_hp + 100.0, 5)
	_check(rubble_hut.is_destroyed and int(rubble_hut.damage_stage) == 3, "Destroyed building enters rubble stage 3")
	_check(_state.get_faction_buildings(0, "SLEEPING_HUT", false).is_empty(), "Rubble building excluded from get_faction_buildings()")
	_check(_state.save_game(path), "Save succeeds with rubble building present")
	var snap_a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved_player_huts := 0
	for bd in snap_a["buildings"]:
		if int(bd["faction_id"]) == 0 and str(bd["building_type"]) == "SLEEPING_HUT":
			saved_player_huts += 1
		if int(bd["faction_id"]) == 0 and str(bd["building_type"]) == "PALISADE_WALL":
			bd["hp"] = 9999.0
	_check(saved_player_huts == 0, "Rubble building is not written to save payload")
	_write(path, JSON.stringify(snap_a))
	_check(_state.load_game(path), "Reload succeeds with over-max building HP fixture")
	var reloaded_walls: Array = _state.get_faction_buildings(0, "PALISADE_WALL", true)
	_check(reloaded_walls.size() == 1 and is_equal_approx(float(reloaded_walls[0].hp), float(reloaded_walls[0].max_hp)), "Building restore_snapshot clamps hp to max_hp")
	_check(_state.get_faction_buildings(0, "SLEEPING_HUT", false).is_empty(), "No rubble building remains after load")

	# B. Live KRAG_UL building max_hp scaling & clamp + PatronGod / Tenet persistence
	var base_wall_hp: float = float(GameData.BUILDINGS["PALISADE_WALL"]["max_hp"])
	var wall_full: Node = reloaded_walls[0]
	colony = _state.faction_controllers[0]
	var wall_half: Node = colony.spawn_building("PALISADE_WALL", Vector3(32.0, 0.0, 52.0), 0.0, true)
	wall_half.hp = wall_half.max_hp * 0.5
	wall_half.sync_visual_from_state()
	_state.select_player_patron(GameData.PatronGod.KRAG_UL)
	_check(is_equal_approx(float(wall_full.max_hp), base_wall_hp * 1.25) and is_equal_approx(float(wall_full.hp), base_wall_hp * 1.25), "KRAG_UL scales existing full-HP building max_hp and hp by 1.25x")
	_check(is_equal_approx(float(wall_half.max_hp), base_wall_hp * 1.25) and is_equal_approx(float(wall_half.hp), base_wall_hp * 1.25 * 0.5), "KRAG_UL preserves damaged building HP ratio")
	_state.select_player_patron(GameData.PatronGod.VALK_TOR)
	_check(is_equal_approx(float(wall_full.max_hp), base_wall_hp) and float(wall_full.hp) <= float(wall_full.max_hp) + 0.001, "Switching away from KRAG_UL reverts building max_hp and clamps hp")
	_check(is_equal_approx(float(wall_half.max_hp), base_wall_hp) and is_equal_approx(float(wall_half.hp), base_wall_hp * 0.5), "Switching away from KRAG_UL preserves damaged building ratio")
	_state.select_player_patron(GameData.PatronGod.KRAG_UL)
	_state.set_player_tenet("ANCESTRAL_STONE", true)
	_state.set_player_tenet("KINSHIP", true)
	_check(_state.save_game(path) and _state.load_game(path), "Save/load PatronGod and Tenets")
	_check(int(_state.factions[0]["patron_god"]) == GameData.PatronGod.KRAG_UL, "KRAG_UL patron persists across save/load")
	var loaded_tenets: Array = _state.factions[0]["tenets"]
	_check(loaded_tenets.has("ANCESTRAL_STONE") and loaded_tenets.has("KINSHIP") and loaded_tenets.size() == 2, "Adopted tenets persist across save/load")
	for wb in _state.get_faction_buildings(0, "PALISADE_WALL", true):
		_check(is_equal_approx(float(wb.max_hp), base_wall_hp * 1.25) and float(wb.hp) <= float(wb.max_hp) + 0.001, "KRAG_UL building max_hp and hp clamp hold after reload")

	# C. captured_cavemen, craft_queue, blessing_cooldown, transient cooldown resets, unit buffs/carry/daily flags, and faction AI timers
	colony = _state.faction_controllers[0]
	pc = _state.player_controller
	_state.factions[0]["captured_cavemen"] = 3
	_state.factions[0]["craft_queue"] = ["spears", "armor"]
	pc._blessing_cd = 11.5
	pc._dash_cd = 1.6
	pc._dash_timer = 0.15
	pc._attack_cd = 0.35
	pc._javelin_cd = 0.85
	pc._harvest_cd = 0.30
	var worker: Node = colony.spawn_colonist(Vector3(14.0, 0.0, 52.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.STONEKNAPPER)
	var worker_id: int = int(worker.unit_id)
	worker._dusk_eaten_today = 2
	worker._night_morale_today = 2
	worker._buff_timer = 7.5
	worker._buff_speed_mult = 1.35
	worker._buff_armor_bonus = 6.0
	worker._carry_type = "flint"
	worker._carry_amount = 4.0
	var rival1_leader: Node = _state.get_faction_leader(1)
	var rival1_leader_id: int = int(rival1_leader.unit_id)
	rival1_leader._leader_blessing_cd = 12.25
	var fc1: Node = _state.faction_controllers[1]
	var fc5: Node = _state.faction_controllers[5]
	fc1._raid_cooldown = 33.5
	fc1._diplomacy_event_cd = 19.0
	fc5._caveman_spawn_timer = 17.5
	_check(_state.save_game(path), "Save succeeds with full Slice 0C runtime state")
	var snap_c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))

	# Mutate live values to prove load restores from snapshot rather than leaking live state
	pc._blessing_cd = 1.0
	pc._dash_cd = 1.9
	pc._attack_cd = 0.4
	pc._javelin_cd = 0.9
	pc._harvest_cd = 0.4
	fc1._raid_cooldown = 1.0
	fc5._caveman_spawn_timer = 1.0
	_check(_state.load_game(path), "Reload restores Slice 0C runtime state")
	_check(int(_state.factions[0]["captured_cavemen"]) == 3, "captured_cavemen persists across save/load")
	_check(_state.factions[0]["craft_queue"] == ["spears", "armor"], "craft_queue persists across save/load")
	_check(is_equal_approx(float(pc._blessing_cd), 11.5), "PlayerController _blessing_cd persists across save/load")
	_check(
		is_equal_approx(float(pc._dash_cd), 0.0) and is_equal_approx(float(pc._dash_timer), 0.0)
		and is_equal_approx(float(pc._attack_cd), 0.0) and is_equal_approx(float(pc._javelin_cd), 0.0)
		and is_equal_approx(float(pc._harvest_cd), 0.0),
		"Transient PlayerController cooldowns reset cleanly on load"
	)
	var r_worker: Node = _find_unit_by_id(worker_id)
	_check(r_worker != null, "Saved worker restored by unit_id")
	if r_worker != null:
		_check(int(r_worker._dusk_eaten_today) == 2 and int(r_worker._night_morale_today) == 2, "Unit daily eat & morale flags persist")
		_check(
			is_equal_approx(float(r_worker._buff_timer), 7.5)
			and is_equal_approx(float(r_worker._buff_speed_mult), 1.35)
			and is_equal_approx(float(r_worker._buff_armor_bonus), 6.0),
			"Unit buff timer, speed multiplier, and armor bonus persist"
		)
		_check(str(r_worker._carry_type) == "flint" and is_equal_approx(float(r_worker._carry_amount), 4.0), "Unit carried resource persists")
	var r_rival1_leader: Node = _find_unit_by_id(rival1_leader_id)
	_check(r_rival1_leader != null and is_equal_approx(float(r_rival1_leader._leader_blessing_cd), 12.25), "Rival leader _leader_blessing_cd persists")
	_check(
		is_equal_approx(float(_state.faction_controllers[1]._raid_cooldown), 33.5)
		and is_equal_approx(float(_state.faction_controllers[1]._diplomacy_event_cd), 19.0)
		and is_equal_approx(float(_state.faction_controllers[5]._caveman_spawn_timer), 17.5),
		"FactionController AI raid/diplomacy/caveman timers persist"
	)

	# D. Mismatched non-zero player_leader_id rejected without mutating live campaign
	var bad_leader_snap: Dictionary = snap_c.duplicate(true)
	bad_leader_snap["player_leader_id"] = 999999
	var live_leader_before: Node = _state.get_faction_leader(0)
	var live_captured_before: int = int(_state.factions[0]["captured_cavemen"])
	_write(path, JSON.stringify(bad_leader_snap))
	_check(not _state.load_game(path), "Mismatched non-zero player_leader_id is rejected")
	_check(
		_state.get_faction_leader(0) == live_leader_before and int(_state.factions[0]["captured_cavemen"]) == live_captured_before,
		"Rejected mismatched player_leader_id leaves live campaign untouched"
	)

	# E. Wounded / healing / revolting unit states persist across save/load
	colony = _state.faction_controllers[0]
	var u_wounded: Node = colony.spawn_colonist(Vector3(10.0, 0.0, 56.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	var u_wounded_id: int = int(u_wounded.unit_id)
	u_wounded.enter_wounded_state()
	u_wounded.apply_field_aid()
	var wounded_t_saved: float = float(u_wounded.wounded_timer)
	var u_healing: Node = colony.spawn_colonist(Vector3(12.0, 0.0, 56.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.FORAGER)
	var u_healing_id: int = int(u_healing.unit_id)
	u_healing.enter_wounded_state()
	u_healing.send_to_shaman_shack(Vector3(12.0, 0.0, 58.0))
	var u_revolt: Node = colony.spawn_colonist(Vector3(14.0, 0.0, 56.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	var u_revolt_id: int = int(u_revolt.unit_id)
	u_revolt.is_revolting = true
	u_revolt.faction_id = -2
	u_revolt.original_faction_id = 0
	u_revolt.morale = 12.0
	_check(_state.save_game(path) and _state.load_game(path), "Save/load succeeds with wounded, healing, and revolting units")
	var rw: Node = _find_unit_by_id(u_wounded_id)
	var rh: Node = _find_unit_by_id(u_healing_id)
	var rr: Node = _find_unit_by_id(u_revolt_id)
	_check(
		rw != null and rw.is_wounded and not rw.is_healing_in_shack and int(rw.faction_id) == -3
		and int(rw.original_faction_id) == 0 and rw._field_aid_applied and is_equal_approx(float(rw.wounded_timer), wounded_t_saved),
		"Wounded unit state, timer, and field-aid flag persist"
	)
	_check(
		rh != null and rh.is_wounded and rh.is_healing_in_shack and rh.being_rescued
		and int(rh.faction_id) == -3 and int(rh.original_faction_id) == 0,
		"Healing-in-shack unit state persists"
	)
	_check(
		rr != null and rr.is_revolting and int(rr.faction_id) == -2
		and int(rr.original_faction_id) == 0 and is_equal_approx(float(rr.morale), 12.0),
		"Revolting unit state persists"
	)

	# F. Multi-tribe + faction-6 pending_conquests persistence across cold load
	var defector: Node = _state.faction_controllers[0].spawn_colonist(Vector3(8.0, 0.0, 56.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.FORAGER)
	_state.found_rebel_faction(defector)
	_check(bool(_state.factions[6]["is_founded"]), "Outcast Rebels (faction 6) founded for conquest persistence test")
	for cid in [1, 2, 6]:
		var cl: Node = _state.get_faction_leader(cid)
		_check(cl != null, "Faction %d has a leader before triggering conquest" % cid)
		if cl != null:
			cl.is_dead = true
		_state.trigger_conquest_if_eligible(cid, 0)
	_check(
		_state._conquest_pending_factions.has(1) and _state._conquest_pending_factions.has(2) and _state._conquest_pending_factions.has(6),
		"Multi-tribe + faction-6 conquests queued"
	)
	_check(_state.save_game(path), "Save succeeds with multi-tribe + faction-6 pending_conquests")
	_unmount()
	await process_frame
	_mount()
	_check(_state.load_game(path), "Cold load restores multi-tribe + faction-6 pending_conquests")
	_check(
		_state._conquest_pending_factions.has(1) and _state._conquest_pending_factions.has(2) and _state._conquest_pending_factions.has(6)
		and _state.is_paused,
		"All three pending conquests (1, 2, 6) and conquest pause restore on cold load"
	)
	_state.resolve_conquest(1, "RAZE")
	_state.resolve_conquest(2, "TRIBUTARY")
	_state.resolve_conquest(6, "RAZE")
	_check(_state._conquest_pending_factions.is_empty() and not _state.is_paused, "Resolving all restored conquests clears queue and pause")

	# G. AwakeningGuide steps 1, 2, 4, and skip persist across save/load
	_state.start_new_campaign("Enoch", "Guide Persistence", GameData.Lineage.CRAG_BORN)
	_check(is_equal_approx(float(_state.player_controller._blessing_cd), 0.0), "start_new_campaign resets PlayerController _blessing_cd")
	_check(_state.save_game(path) and _state.load_game(path), "Save/load guide step 1")
	_check(_state.tutorial_step == 1 and not _state.tutorial_skipped and not _state.tutorial_completed, "AwakeningGuide step 1 persists")
	_state.tutorial_step = 2
	_check(_state.save_game(path) and _state.load_game(path), "Save/load guide step 2")
	_check(_state.tutorial_step == 2 and not _state.tutorial_skipped, "AwakeningGuide step 2 persists")
	_state.tutorial_step = 4
	_state.tutorial_harvested = true
	_state.tutorial_assigned_role = true
	_check(_state.save_game(path) and _state.load_game(path), "Save/load guide step 4")
	_check(_state.tutorial_step == 4 and _state.tutorial_harvested and _state.tutorial_assigned_role, "AwakeningGuide step 4 persists")
	var step4_hut: Node = _state.faction_controllers[0].spawn_building("SLEEPING_HUT", Vector3(6.0, 0.0, 56.0), 0.0, false)
	_state._process(0.36)
	_check(_state.tutorial_step == 4 and not step4_hut.is_constructed, "Unfinished Sleeping Hut blueprint keeps AwakeningGuide at step 4")
	step4_hut.advance_construction(step4_hut.build_time + 1.0)
	_state._process(0.36)
	_check(step4_hut.is_constructed and _state.tutorial_step == 5, "Constructed Sleeping Hut advances AwakeningGuide from step 4 to step 5")
	_state.skip_awakening_guide()
	_check(_state.save_game(path) and _state.load_game(path), "Save/load guide skip")
	_check(_state.tutorial_skipped and not _state.tutorial_completed and _state.bandit_grace_remaining > 0.0, "AwakeningGuide skip and Peace Buffer persist")

	# H. Synchronous player leader succession prevents 1-frame leaderless save window
	_state.start_new_campaign("Enoch", "Succession Sync", GameData.Lineage.CRAG_BORN)
	var old_leader: Node = _state.get_faction_leader(0)
	var heir: Node = _state.faction_controllers[0].spawn_colonist(Vector3(6.0, 0.0, 52.0), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.WARRIOR)
	var heir_id: int = int(heir.unit_id)
	old_leader.take_damage(9999.0, null, 5)
	_check(old_leader.is_dead, "Old player leader dies on lethal hit")
	_check(_state.get_faction_leader(0) == heir and heir.is_leader and heir.is_player_controlled, "Successor is promoted synchronously with zero leaderless frame")
	_check(_state.player_controller.leader_unit == heir, "PlayerController attaches promoted successor synchronously")
	_check(_state.save_game(path), "Immediate same-frame save after leader death succeeds")
	var succ_snap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(succ_snap.get("player_leader_id", 0)) == heir_id, "Same-frame save records successor as player_leader_id")
	_check(_state.load_game(path) and int(_state.get_faction_leader(0).unit_id) == heir_id, "Reloading same-frame succession save restores promoted leader")

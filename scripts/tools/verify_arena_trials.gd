extends SceneTree
## Forward+ verification suite for Phase 9 (Blood-Pit Trial Arena).
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.

const Layout = preload("res://scripts/core/world_layout.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const ArenaRules = preload("res://scripts/core/arena_rules.gd")

var _state: Node
var _main: Node
var _sound: Node
var _failed := false
var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, caption: String) -> bool:
	if condition:
		_pass_count += 1
		print("PASS ", caption)
		return true
	_fail_count += 1
	_failed = true
	push_error("FAIL " + caption)
	return false


func frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame


func physics_frames(count: int = 2) -> void:
	for _i in range(count):
		await physics_frame


func key_press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev, true)
	ev = InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	root.push_input(ev, true)


func click_at(pos: Vector2, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button_index
	ev.pressed = true
	root.push_input(ev, true)
	ev = InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button_index
	ev.pressed = false
	root.push_input(ev, true)


func _mount() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _unmount() -> void:
	if _state != null:
		_state.end_campaign()
	if is_instance_valid(_main):
		root.remove_child(_main)
		_main.queue_free()
		_main = null


func _find_tagged_button(scope: Node, key: String) -> BaseButton:
	for node in scope.find_children("*", "BaseButton", true, false):
		var btn := node as BaseButton
		if btn != null and btn.get_meta("drawer_focus", "") == key and btn.is_visible_in_tree():
			return btn
	return null


func _select_option_by_id(opt: OptionButton, target_id: int) -> bool:
	var idx: int = opt.get_item_index(target_id)
	if idx < 0:
		return false
	opt.grab_focus()
	opt.select(idx)
	opt.item_selected.emit(idx)
	return true


func _find_unit_by_id(uid: int) -> Node:
	for u in _state.get_faction_units(0):
		if is_instance_valid(u) and int(u.unit_id) == uid:
			return u
	return null


func _total_tribal_xp(f_dict: Dictionary) -> float:
	var lvl: int = PerkSystem.get_level(f_dict)
	var total: float = PerkSystem.get_xp(f_dict)
	for lv in range(1, lvl):
		total += float(PerkSystem.xp_for_next_level(lv))
	return total


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return

	_state = root.get_node("GameState")
	_sound = root.get_node_or_null("/root/SoundManager")
	_mount()
	await frames(3)
	seed(48219)
	_state.start_new_campaign("Kaelen", "Blood-Pit Tribe", GameData.Lineage.CRAG_BORN, Layout.CLASSIC_ID)
	await frames(4)

	var leader: Node = _state.get_faction_leader(0)
	var fc0: Node = _state.faction_controllers[0]
	var hud: Control = _state.hud_controller
	var pc: Node = _state.player_controller
	check(leader != null and fc0 != null and hud != null and pc != null, "Campaign bootstrapped for Arena Trials suite")

	# Baseline daytime peace state & resources
	_state.skip_awakening_guide()
	_state.time_of_day = 12.0
	_state.bandit_grace_remaining = 300.0
	var camp_pos := Vector3(0.0, 0.0, 52.0)
	var camp: Node = fc0.spawn_building("CAMPFIRE", camp_pos, 0.0, true)
	_state.factions[0]["is_founded"] = true
	_state.factions[0]["camp_position"] = camp_pos
	var f0: Dictionary = _state.factions[0]
	var res0: Dictionary = f0["resources"]
	for rk in ["food", "wood", "stone", "flint", "hide", "bone", "faith"]:
		res0[rk] = 600.0
	check(camp != null, "Founded camp for Arena Trials")
	await frames(2)

	# ------------------------------------------------------------------
	# (a) Lv.1 BuildDrawer gating -> Lv.3 + BARRACKS_DRILLMASTERS -> ARENA_PIT
	# ------------------------------------------------------------------
	key_press(KEY_B)
	await frames(3)
	check(hud._active_tab == "BUILD", "B opens BuildDrawer")
	var build_drawer: Control = hud._drawer_views["BUILD"]
	var arena_build_btn: BaseButton = _find_tagged_button(build_drawer, "ARENA_PIT")
	var place_btn: BaseButton = _find_tagged_button(build_drawer, "place")
	if check(arena_build_btn != null, "BuildDrawer lists ARENA_PIT in Defences"):
		arena_build_btn.pressed.emit()
		await frames(1)
		check(place_btn != null and place_btn.disabled and place_btn.text.begins_with("Requires"),
			"ARENA_PIT is locked at Lv.1 in BuildDrawer (%s)" % (place_btn.text if place_btn != null else "null"))
	key_press(KEY_ESCAPE)
	await frames(2)

	# Check Colony -> Arena tab before building Arena Pit
	key_press(KEY_C)
	await frames(2)
	var colony_drawer: Control = hud._drawer_views["COLONY"]
	var arena_tab_btn: BaseButton = _find_tagged_button(colony_drawer, "section:Arena")
	if check(arena_tab_btn != null, "ColonyDrawer has Arena section tab"):
		arena_tab_btn.pressed.emit()
		await frames(2)
		check(_find_tagged_button(colony_drawer, "arena-open-perks") != null and _find_tagged_button(colony_drawer, "arena-open-build") != null,
			"Arena tab guides player to Perks/Build before ARENA_PIT exists")
		check(_find_tagged_button(colony_drawer, "arena-start") == null, "Start button hidden before ARENA_PIT is built")
	key_press(KEY_ESCAPE)
	await frames(2)

	# Unlock Lv.3 + CALL_OF_THE_HEARTH + BARRACKS_DRILLMASTERS
	_state.award_xp(0, 80.0 + 135.0 + 190.0, "Arena Tier Unlock")
	check(PerkSystem.get_level(f0) >= 3, "Tribe reached Lv.3+")
	check(_state.unlock_perk(0, "CALL_OF_THE_HEARTH") and _state.unlock_perk(0, "BARRACKS_DRILLMASTERS"),
		"Unlocked Call of the Hearth & Barracks Drillmasters Rank 1")

	key_press(KEY_B)
	await frames(2)
	arena_build_btn = _find_tagged_button(build_drawer, "ARENA_PIT")
	place_btn = _find_tagged_button(build_drawer, "place")
	if check(arena_build_btn != null, "BuildDrawer still lists ARENA_PIT after unlock"):
		arena_build_btn.pressed.emit()
		await frames(1)
		check(place_btn != null and not place_btn.disabled, "ARENA_PIT unlocks in BuildDrawer at Lv.3 + Barracks Drillmasters")
		if place_btn != null:
			place_btn.pressed.emit()
			await frames(2)
			check(pc.is_build_mode and pc.blueprint_type == "ARENA_PIT", "Clicking Place enters ARENA_PIT build mode")
			pc.exit_build_mode()
			await frames(1)

	# Place & complete ARENA_PIT and inspect 4 stages + walkable interior
	var arena_pos := Vector3(14.0, 0.0, 52.0)
	var arena_bld: Node = fc0.spawn_building("ARENA_PIT", arena_pos, 0.0, false)
	check(arena_bld != null and not arena_bld.is_constructed, "Spawned unconstructed ARENA_PIT blueprint")
	check(not bool(_state.get_arena_status().get("has_arena", false)), "Blueprint ARENA_PIT does not activate Arena bouts yet")
	if arena_bld != null:
		var vr: Node = arena_bld.get("_visual_root")
		check(vr != null and vr.get_node_or_null("Stage_Intact") != null and vr.get_node_or_null("Stage_Damaged") != null \
			and vr.get_node_or_null("Stage_Critical") != null and vr.get_node_or_null("Stage_Rubble") != null,
			"ARENA_PIT builds all 4 visual damage stages")
		arena_bld.advance_construction(9999.0)
		await frames(2)
		check(arena_bld.is_constructed, "ARENA_PIT construction completes")
		var vr_built: Node = arena_bld.get("_visual_root")
		var intact_stage: Node = vr_built.get_node_or_null("Stage_Intact") if vr_built != null else null
		check(intact_stage != null and intact_stage.get_node_or_null("ArenaBrazierFlame0") != null \
			and intact_stage.get_node_or_null("ArenaBrazierLight0") != null,
			"ARENA_PIT Intact stage includes pulsing braziers and lights")
		var col_shape: CollisionShape3D = arena_bld.get("_col_shape")
		check(arena_bld._is_walkable_interior() and (col_shape == null or col_shape.disabled),
			"ARENA_PIT keeps fighting interior walkable with non-blocking collider")
		check(not bool(arena_bld.get("_obstacle_registered")), "ARENA_PIT does not register solid nav obstacle over pit floor")
	check(bool(_state.get_arena_status().get("has_arena", false)), "Constructed ARENA_PIT enables Arena status")

	# ------------------------------------------------------------------
	# (b) Approaching ARENA_PIT with [E] opens Arena tab
	# ------------------------------------------------------------------
	leader.global_position = arena_pos + Vector3(0.0, 0.0, 6.2)
	await frames(2)
	key_press(KEY_E)
	await frames(3)
	check(hud._drawer_panel.visible and hud._active_tab == "COLONY" and colony_drawer._section == "Arena",
		"[E] near constructed ARENA_PIT opens ColonyDrawer -> Arena tab")
	check(_find_tagged_button(colony_drawer, "arena-start") != null \
		and _find_tagged_button(colony_drawer, "arena-mode:CHIEFTAIN") != null \
		and _find_tagged_button(colony_drawer, "arena-mode:EXHIBITION") != null \
		and _find_tagged_button(colony_drawer, "arena-tier") != null,
		"Arena tab shows mode, tier, and Start Arena Bout controls")
	key_press(KEY_ESCAPE)
	await frames(2)

	# ------------------------------------------------------------------
	# (c) Chieftain's Trial (Tier I) in First-Person POV (Z) + Watchtower isolation + music
	# ------------------------------------------------------------------
	var tower: Node = fc0.spawn_building("WATCHTOWER", arena_pos + Vector3(-11.0, 0.0, 0.0), 0.0, true)
	check(tower != null and tower.is_constructed, "Spawned external Watchtower within 20m of Arena Pit")

	# Upgrade Stone Age tier -> Tier 3 (requires CRAFTING_PIT) and equip leader weapon for deterministic cleave
	var craft_pit: Node = fc0.spawn_building("CRAFTING_PIT", camp_pos + Vector3(-5.0, 0.0, 4.0), 0.0, true)
	check(craft_pit != null and fc0.upgrade_stone_age_tier() and fc0.upgrade_stone_age_tier(),
		"Upgraded Stone Age tech tier to Tier 3")
	f0["stockpile"]["obsidian_cleavers"] = int(f0["stockpile"].get("obsidian_cleavers", 0)) + 2
	check(_state.equip_unit_weapon(leader, "OBSIDIAN_CLEAVER"), "Equipped Leader with OBSIDIAN_CLEAVER")

	# Enter First-Person POV
	key_press(KEY_Z)
	await frames(3)
	check(pc.is_first_person, "Z enters First-Person POV before Chieftain's Trial")

	if _sound != null:
		_sound.reset_telemetry()
	var food_before: float = float(res0.get("food", 0.0))
	var hide_before: float = float(res0.get("hide", 0.0))
	var bone_before: float = float(res0.get("bone", 0.0))
	var xp_before: float = _total_tribal_xp(f0)

	# Start Tier 1 Chieftain's Trial through the Arena UI
	hud.open_arena_drawer()
	await frames(2)
	var start_btn: BaseButton = _find_tagged_button(colony_drawer, "arena-start")
	if check(start_btn != null and not start_btn.disabled, "Start Arena Bout enabled for Chieftain's Trial Tier I"):
		start_btn.pressed.emit()
		await frames(3)

	check(_state.is_arena_bout_active(), "Chieftain's Trial Tier I bout started")
	check(leader.is_arena_combatant and pc.is_first_person and not pc.is_spectating_arena,
		"Chieftain enters bout in First-Person POV without spectator override")
	check(not hud._drawer_panel.visible, "Starting Chieftain's Trial auto-closes Arena drawer")
	if _sound != null:
		check(_sound.get_last_music_state() == "ARENA", "Arena bout switches music to ARENA (got %s)" % _sound.get_last_music_state())
		check(_sound.get_cue_play_count("warhorn") >= 1, "Arena bout start plays warhorn cue")

	# Verify Watchtower isolation & mid-bout save isolation
	await frames(10)
	check(tower._find_nearest_hostile(20.0) == null, "External Watchtower ignores arena beasts and combatants")
	var mid_save_path := "user://arena_mid_%d.json" % Time.get_ticks_usec()
	check(_state.save_game(mid_save_path), "Mid-bout save_game() succeeds")
	var mid_json_str: String = FileAccess.get_file_as_string(mid_save_path)
	var mid_parsed: Variant = JSON.parse_string(mid_json_str)
	if check(mid_parsed is Dictionary, "Mid-bout save file parses as JSON Dictionary"):
		var mid_dict := mid_parsed as Dictionary
		var saved_wild: Array = mid_dict.get("wildlife", [])
		check(saved_wild.size() == 0 or not _contains_arena_wildlife(saved_wild),
			"Mid-bout save excludes temporary Arena beast opponents")
	DirAccess.remove_absolute(mid_save_path)

	# Fight Tier I opponents in First-Person POV using LMB cleave
	var opp_list: Array = _state.arena_bout.get("opponent_nodes", []).duplicate()
	check(opp_list.size() == 3, "Tier I spawned 3 beasts (%d)" % opp_list.size())
	var projectile_script: Script = load("res://scripts/entities/projectile_3d.gd")
	var beast: Node3D = opp_list[0]
	var beast_hp: float = beast.hp
	beast.take_damage(9999.0, null, 0)
	var beast_center: Vector3 = beast.projectile_hit_center()
	var tower_shot: Node3D = projectile_script.spawn(tower, 0, beast_center + Vector3(0.0, 0.0, 2.0), beast_center, 9999.0)
	tower_shot._physics_process(0.08)
	check(is_equal_approx(beast.hp, beast_hp) and not tower_shot.is_queued_for_deletion(),
		"Outside and source-less attacks leave arena beasts untouched and do not intercept arrows")
	tower_shot.queue_free()
	var wild_predator: Node3D = _state.world_node._spawn_animal("WOLF", arena_pos + Vector3(0.0, 0.0, 8.0))
	var leader_hp: float = leader.hp
	wild_predator._perform_attack(leader)
	check(is_equal_approx(leader.hp, leader_hp), "Outside predators cannot attack the trial leader")
	var predator_center: Vector3 = wild_predator.projectile_hit_center()
	var ring_shot: Node3D = projectile_script.spawn(leader, 0, predator_center + Vector3(0.0, 0.0, 2.0), predator_center, 9999.0)
	ring_shot._physics_process(0.08)
	check(not wild_predator.is_dead and not ring_shot.is_queued_for_deletion(), "Arena shots pass through wildlife outside the bout")
	ring_shot.queue_free()
	_state.wildlife_container.remove_child(wild_predator)
	wild_predator.queue_free()
	var first_cleave_verified := false
	for opp in opp_list:
		var safety := 0
		while is_instance_valid(opp) and not opp.get("is_dead") and _state.is_arena_bout_active() and safety < 24:
			safety += 1
			var opp_3d := opp as Node3D
			var to_opp: Vector3 = opp_3d.global_position - leader.global_position
			to_opp.y = 0.0
			if to_opp.length() > 2.2:
				leader.global_position = opp_3d.global_position - to_opp.normalized() * 1.6
				_state.spatial_index.update_unit(leader)
			var look_dir: Vector3 = opp_3d.global_position - leader.global_position
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.001:
				pc.cam_yaw = rad_to_deg(atan2(-look_dir.x, -look_dir.z))
				pc.fp_pitch = -10.0
			await frames(1)
			var hp_pre: float = float(opp.get("hp"))
			pc._attack_cd = 0.0
			click_at(Vector2(800.0, 450.0))
			await frames(2)
			if not first_cleave_verified and is_instance_valid(opp):
				first_cleave_verified = float(opp.get("hp")) < hp_pre or bool(opp.get("is_dead"))
				check(first_cleave_verified, "First-Person LMB cleave damages Arena opponent")

	await frames(4)
	check(not _state.is_arena_bout_active(), "Chieftain's Trial Tier I ends cleanly on victory")
	check(not leader.is_arena_combatant and pc.is_first_person, "Leader clears is_arena_combatant and stays in FP POV after victory")
	check(float(res0.get("food", 0.0)) >= food_before + 25.0 and float(res0.get("hide", 0.0)) >= hide_before + 12.0 \
		and float(res0.get("bone", 0.0)) >= bone_before + 8.0, "Tier I victory awards Food/Hide/Bone rewards")
	check(_total_tribal_xp(f0) >= xp_before + 45.0, "Tier I victory awards +45 Tribal XP")
	if _sound != null:
		check(_sound.get_last_music_state() == "PEACE_DAY",
			"Victory restores PEACE_DAY music cleanly (got %s)" % _sound.get_last_music_state())
		check(_sound.get_cue_play_count("level_up") >= 1, "Arena victory plays level_up cue")

	# Exit FP POV back to 3rd person
	key_press(KEY_Z)
	await frames(2)
	check(not pc.is_first_person, "Z returns to 3rd-Person POV")

	# ------------------------------------------------------------------
	# (d) Non-Lethal Knockout & Convalescence (Leader & Warrior)
	# ------------------------------------------------------------------
	_state.arena_cooldown = 0.0
	var shack_pos := Vector3(-16.0, 0.0, 52.0)
	var shack: Node = fc0.spawn_building("SHAMAN_SHACK", shack_pos, 0.0, true)
	check(shack != null and shack.is_constructed, "Spawned SHAMAN_SHACK for convalescence tests")

	# 1) Leader non-lethal KO
	check(_state.start_arena_bout(ArenaRules.MODE_CHIEFTAIN, 1, []), "Started Chieftain's Trial for non-lethal Leader KO check")
	await frames(2)
	var ko_opp: Node = _state.arena_bout.get("opponent_nodes", [null])[0]
	leader.take_damage(9999.0, ko_opp, -1)
	var knockout_hp: float = leader.hp
	leader.take_damage(9999.0, ko_opp, -1)
	check(is_equal_approx(leader.hp, knockout_hp), "A second hit in the knockout frame cannot kill the leader")
	await frames(3)
	check(not leader.is_dead and not leader.is_wounded and float(leader.hp) >= 1.0,
		"Lethal Arena hit keeps Leader alive (hp=%.1f)" % float(leader.hp))
	check(_state.get_faction_leader(0) == leader, "Non-lethal Arena KO skips leader succession")
	check(not leader.is_arena_combatant and leader.arena_recovery_remaining > 20.0 and leader.is_out_of_commission(),
		"Knocked-out Leader enters Out of Commission convalescence (%.1fs)" % leader.arena_recovery_remaining)
	check(leader.global_position.distance_to(arena_pos + Vector3(0.0, 0.0, 6.2)) <= 0.6,
		"Knocked-out Leader is moved outside the Arena gate")
	check(not _state.is_arena_bout_active(), "Bout ends when all combatants are knocked out")
	pc._javelin_cd = 0.0
	pc._attack_cd = 0.0
	pc._blessing_cd = 0.0
	key_press(KEY_F)
	key_press(KEY_Q)
	click_at(Vector2(800.0, 450.0))
	check(pc._javelin_cd == 0.0 and pc._attack_cd == 0.0 and pc._blessing_cd == 0.0,
		"A recovering Chieftain cannot attack or cast a blessing")
	check(hud._blessing_label.text.contains("Out of Commission"), "HUD shows convalescence on the Chieftain action bar")

	# Restore leader & reset cooldown for Warrior KO + convalescence test
	leader.arena_recovery_remaining = 0.0
	leader.hp = leader.max_hp
	_state.arena_cooldown = 0.0

	var w1: Node = fc0.spawn_colonist(arena_pos + Vector3(-8.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR)
	w1.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN)
	var w1_id: int = int(w1.unit_id)
	check(w1 != null and _state.start_arena_bout(ArenaRules.MODE_EXHIBITION, 1, [w1_id]),
		"Started Exhibition Tier I with Warrior w1 for KO test")
	await frames(2)
	var w_opp: Node = _state.arena_bout.get("opponent_nodes", [null])[0]
	w1.start_revolt()
	check(not w1.is_revolting and w1.faction_id == 0, "A warrior cannot revolt out of a bout")
	w1.take_damage(9999.0, w_opp, -1)
	await frames(3)
	check(not w1.is_dead and not w1.is_wounded and float(w1.hp) >= 1.0, "Warrior survives lethal Arena KO (hp=%.1f)" % float(w1.hp))
	check(w1.arena_recovery_remaining > 50.0 and w1.is_out_of_commission(),
		"Knocked-out Warrior enters Out of Commission convalescence (%.1fs)" % w1.arena_recovery_remaining)
	var recovery_order: int = w1.squad_order
	key_press(KEY_F4)
	check(w1.squad_order == recovery_order and not _state.assign_player_role(w1, GameData.Role.FORAGER),
		"Squad orders and workforce assignment skip a recovering warrior")

	# UI check: [Out of Commission] disabled fighter button
	hud.open_arena_drawer()
	await frames(2)
	var w1_btn: BaseButton = _find_tagged_button(colony_drawer, "arena-fighter:%d" % w1_id)
	check(w1_btn != null and w1_btn.disabled and w1_btn.text.contains("Out of Commission"),
		"Arena UI disables knocked-out Warrior button as Out of Commission (%s)" % (w1_btn.text if w1_btn != null else "null"))
	key_press(KEY_ESCAPE)
	await frames(2)

	# Combat exclusion + SHAMAN_SHACK steering + 1.75x recovery rate
	var u_script: Script = load("res://scripts/entities/human_unit.gd")
	var cave_raider := CharacterBody3D.new()
	cave_raider.set_script(u_script)
	_state.units_container.add_child(cave_raider)
	cave_raider.setup({
		"faction_id": 5, "pos": w1.global_position + Vector3(3.0, 0.0, 0.0),
		"lineage": GameData.Lineage.CAVEMAN, "role": GameData.Role.WARRIOR,
		"warrior_class": GameData.WarriorClass.BRUTE, "is_caveman": true,
	})
	_state.spatial_index.update_unit(cave_raider)
	w1.squad_order = GameData.SquadOrder.CHARGE
	w1.global_position = arena_pos + Vector3(0.0, 0.0, 6.2)
	var start_shack_d: float = w1.global_position.distance_to(shack_pos)
	await physics_frames(20)
	check(w1._target_node == null, "Recovering Warrior ignores nearby hostile caveman")
	check(w1.global_position.distance_to(shack_pos) < start_shack_d - 0.5,
		"Recovering Warrior steers toward constructed SHAMAN_SHACK")
	if is_instance_valid(cave_raider):
		cave_raider._unregister_from_index()
		cave_raider.get_parent().remove_child(cave_raider)
		cave_raider.queue_free()

	# Compare recovery drop far from healers vs within 6.5m of SHAMAN_SHACK
	w1.global_position = Vector3(52.0, 0.0, 52.0)
	await physics_frames(2)
	var rec_far_start: float = float(w1.arena_recovery_remaining)
	await physics_frames(15)
	var far_drop: float = rec_far_start - float(w1.arena_recovery_remaining)

	w1.global_position = shack_pos + Vector3(2.0, 0.0, 0.0)
	await physics_frames(2)
	var rec_near_start: float = float(w1.arena_recovery_remaining)
	await physics_frames(15)
	var near_drop: float = rec_near_start - float(w1.arena_recovery_remaining)
	check(far_drop > 0.0 and near_drop > far_drop * 1.55,
		"SHAMAN_SHACK accelerates convalescence ~1.75x (far drop %.3f, near drop %.3f)" % [far_drop, near_drop])

	# ------------------------------------------------------------------
	# (e) Warband Exhibition (Tier III) + Spectate Ring + Champion + Plan 1 Gear
	# ------------------------------------------------------------------
	w1.arena_recovery_remaining = 0.0
	w1.hp = w1.max_hp
	_state.arena_cooldown = 0.0

	var w2: Node = fc0.spawn_colonist(arena_pos + Vector3(-9.0, 0.0, 2.0), GameData.Lineage.GOLIATH, GameData.Gender.MALE, GameData.Role.WARRIOR)
	w2.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.BRUTE)
	var w3: Node = fc0.spawn_colonist(arena_pos + Vector3(-9.0, 0.0, -2.0), GameData.Lineage.SWIFT_KIN, GameData.Gender.FEMALE, GameData.Role.WARRIOR)
	w3.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.KNIFE_RAIDER)
	for w in [w1, w2, w3]:
		f0["stockpile"]["obsidian_cleavers"] = int(f0["stockpile"].get("obsidian_cleavers", 0)) + 1
		f0["stockpile"]["obsidian_plate"] = int(f0["stockpile"].get("obsidian_plate", 0)) + 1
		_state.equip_unit_weapon(w, "OBSIDIAN_CLEAVER")
		_state.equip_unit_armor(w, "OBSIDIAN_PLATE")

	var w1_pre_hp: float = float(w1.max_hp)
	var w1_pre_rank: int = int(w1.melee_rank)
	var w1_pre_dmg: float = float(w1.close_quarters_damage)
	var pelt_before: int = int(f0["stockpile"].get("pelt_mantle", 0))

	key_press(KEY_Z)
	check(pc.is_first_person, "Opened Exhibition setup from first person")
	hud.open_arena_drawer()
	await frames(2)
	var exh_btn: BaseButton = _find_tagged_button(colony_drawer, "arena-mode:EXHIBITION")
	if check(exh_btn != null, "Arena tab exposes Exhibition mode button"):
		exh_btn.pressed.emit()
		await frames(2)
	var tier_opt: OptionButton = _find_tagged_button(colony_drawer, "arena-tier") as OptionButton
	if check(tier_opt != null, "Arena tab exposes Tier OptionButton"):
		check(_select_option_by_id(tier_opt, 3), "Selected Tier III (Apex Megafauna)")
		await frames(2)
	for wid in [int(w1.unit_id), int(w2.unit_id), int(w3.unit_id)]:
		var fbtn: BaseButton = _find_tagged_button(colony_drawer, "arena-fighter:%d" % wid)
		if check(fbtn != null and not fbtn.disabled, "Fighter %d selectable for Exhibition Tier III" % wid):
			fbtn.pressed.emit()
			await frames(1)

	var exh_start: BaseButton = _find_tagged_button(colony_drawer, "arena-start")
	if check(exh_start != null and not exh_start.disabled, "Start Arena Bout enabled for Warband Exhibition Tier III"):
		exh_start.pressed.emit()
		await frames(3)

	check(_state.is_arena_bout_active() and str(_state.arena_bout.get("mode", "")) == ArenaRules.MODE_EXHIBITION,
		"Warband Exhibition Tier III started")
	check(pc.is_spectating_arena and not pc.is_first_person and not leader.is_first_person_hidden() and not pc._fp_viewmodel.visible,
		"Exhibition started through the blocking drawer switches from first person to the ring camera")

	# Toggle Spectate Ring button off and back on
	var spec_btn: BaseButton = _find_tagged_button(colony_drawer, "arena-spectate")
	if check(spec_btn != null, "Live Exhibition bout shows Spectate Ring toggle"):
		spec_btn.pressed.emit()
		await frames(2)
		check(not pc.is_spectating_arena, "Spectate Ring toggle disables spectate")
		spec_btn = _find_tagged_button(colony_drawer, "arena-spectate")
		if spec_btn != null:
			spec_btn.pressed.emit()
			await frames(2)
			check(pc.is_spectating_arena, "Spectate Ring toggle re-enables spectate")
	key_press(KEY_ESCAPE)
	await frames(2)
	key_press(KEY_ESCAPE)
	check(not pc.is_spectating_arena and not _state.is_paused, "Escape from ring view restores the leader camera without pausing")

	# Let warriors fight briefly and verify they damage Arena beasts, then finish Tier III
	var t3_opps: Array = _state.arena_bout.get("opponent_nodes", []).duplicate()
	var t3_hp_before: Array[float] = []
	for opp in t3_opps:
		t3_hp_before.append(float(opp.get("hp")) if is_instance_valid(opp) else 0.0)
	await physics_frames(45)
	var damaged_by_warriors := false
	for i in range(t3_opps.size()):
		var opp: Node = t3_opps[i]
		if not is_instance_valid(opp) or opp.get("is_dead") == true or float(opp.get("hp")) < t3_hp_before[i]:
			damaged_by_warriors = true
			break
	check(damaged_by_warriors, "Exhibition warriors engage and damage Arena beast opponents")
	for opp in t3_opps:
		if is_instance_valid(opp) and not opp.get("is_dead"):
			opp.take_damage(9999.0, w1, 0)
	await frames(4)

	check(not _state.is_arena_bout_active() and not pc.is_spectating_arena,
		"Tier III Exhibition resolves cleanly and exits Spectate Ring")
	var w1_champ_hp: float = float(w1.max_hp)
	var expected_w1_hp: float = w1_pre_hp + float(int(w1.melee_rank) - w1_pre_rank) * 10.0 + 15.0
	check(w1.is_arena_champion and is_equal_approx(w1_champ_hp, expected_w1_hp),
		"Tier III victory grants is_arena_champion (+15 Max HP + rank ups: %.1f -> %.1f)" % [w1_pre_hp, w1_champ_hp])
	check(float(w1.close_quarters_damage) >= w1_pre_dmg * 1.10 - 0.01 and int(w1.melee_rank) > 0,
		"Tier III victory grants training XP rank-up (%d) and 1.10x Champion damage (%.2f -> %.2f)" % [int(w1.melee_rank), w1_pre_dmg, float(w1.close_quarters_damage)])
	var champ_dmg: float = float(w1.close_quarters_damage)
	w1.is_arena_champion = false
	w1.recalculate_stats(false)
	var base_rank_dmg: float = float(w1.close_quarters_damage)
	w1.is_arena_champion = true
	w1.recalculate_stats(false)
	check(is_equal_approx(champ_dmg, base_rank_dmg * 1.10),
		"is_arena_champion applies exact 1.10x damage multiplier (%.2f -> %.2f)" % [base_rank_dmg, champ_dmg])
	check(int(f0["stockpile"].get("pelt_mantle", 0)) == pelt_before + 1,
		"Tier III victory adds Plan 1 pelt_mantle reward to stockpile")

	var insp: Control = hud._inspector_panel
	insp.inspect_unit(w1)
	await frames(2)
	var insp_status_lbl: Label = insp.get("_insp_status")
	check(insp.visible and insp_status_lbl != null and insp_status_lbl.text.contains("Arena Champion"),
		"UnitInspector displays [Arena Champion] badge")
	insp.close()
	await frames(2)

	# ------------------------------------------------------------------
	# (f) Forfeit live bout (zero freed-object errors) & Save/Load persistence
	# ------------------------------------------------------------------
	_state.arena_cooldown = 0.0
	var w2_id: int = int(w2.unit_id)
	hud.open_arena_drawer()
	await frames(2)
	tier_opt = _find_tagged_button(colony_drawer, "arena-tier") as OptionButton
	if tier_opt != null:
		_select_option_by_id(tier_opt, 2) # Bone-Cave Raiders (human opponents)
		await frames(2)
	for prev_sel in [int(w1.unit_id), int(w3.unit_id)]:
		var pbtn: BaseButton = _find_tagged_button(colony_drawer, "arena-fighter:%d" % prev_sel)
		if pbtn != null and pbtn.button_pressed:
			pbtn.pressed.emit()
			await frames(1)
	var f_start: BaseButton = _find_tagged_button(colony_drawer, "arena-start")
	if f_start != null and not f_start.disabled:
		f_start.pressed.emit()
		await frames(3)
	check(_state.is_arena_bout_active(), "Started Tier II Bone-Cave Raiders bout for forfeit test")

	await physics_frames(15)
	var forfeit_opp: Node3D = _state.arena_bout["opponent_nodes"][0]
	var stale_target := Node3D.new()
	w3._target_node = stale_target
	w3._self_defense_target = forfeit_opp
	w3._scan_enemy = forfeit_opp
	w3._scan_wild = forfeit_opp
	stale_target.free()
	var forfeit_shot: Node3D = projectile_script.spawn(w2, 0, w2.global_position + Vector3.UP, arena_pos + Vector3(10.0, 1.0, 0.0), 30.0)
	var forfeit_btn: BaseButton = _find_tagged_button(colony_drawer, "arena-forfeit")
	if check(forfeit_btn != null and not forfeit_btn.disabled, "Forfeit Bout button visible during active bout"):
		forfeit_btn.pressed.emit()
	else:
		_state.forfeit_arena_bout()
	check(w3._target_node == null and w3._self_defense_target == null and w3._scan_enemy == null and w3._scan_wild == null,
		"Forfeit clears live and previously freed targets on an outside guard")
	check(forfeit_shot.is_queued_for_deletion() and not forfeit_shot.is_inside_tree(), "Forfeit removes in-flight arena arrows immediately")
	await physics_frames(15)
	await frames(3)
	check(not _state.is_arena_bout_active() and ArenaRules.count_living_opponents(_state.arena_bout) == 0,
		"Forfeit Bout cleans up live opponents and ends bout with zero errors")
	check(w2._target_node == null and not w2.is_arena_combatant,
		"Forfeit clears fighter combatant flag and target references")
	key_press(KEY_ESCAPE)
	await frames(2)

	# Save / Load persistence (in-session + cold reload)
	w2.arena_recovery_remaining = 33.0
	var save_path := "user://arena_verify_%d.json" % Time.get_ticks_usec()
	check(_state.save_game(save_path), "Saved campaign with Arena Champion & recovering fighter")

	check(_state.load_game(save_path), "In-session reload succeeded")
	await frames(2)
	var r_w1: Node = _find_unit_by_id(w1_id)
	var r_w2: Node = _find_unit_by_id(w2_id)
	check(r_w1 != null and bool(r_w1.get("is_arena_champion")) and is_equal_approx(float(r_w1.max_hp), w1_champ_hp),
		"In-session reload preserves is_arena_champion and +15 Max HP")
	check(r_w2 != null and float(r_w2.get("arena_recovery_remaining")) > 30.0 and r_w2.is_out_of_commission(),
		"In-session reload preserves arena_recovery_remaining")

	_unmount()
	await frames(2)
	_mount()
	await frames(2)
	check(_state.load_game(save_path), "Cold reload succeeded")
	await frames(2)
	var c_w1: Node = _find_unit_by_id(w1_id)
	var c_w2: Node = _find_unit_by_id(w2_id)
	check(c_w1 != null and bool(c_w1.get("is_arena_champion")) and is_equal_approx(float(c_w1.max_hp), w1_champ_hp),
		"Cold reload preserves is_arena_champion and +15 Max HP")
	check(c_w2 != null and float(c_w2.get("arena_recovery_remaining")) > 30.0 and c_w2.is_out_of_commission(),
		"Cold reload preserves arena_recovery_remaining")
	check(not _state.is_arena_bout_active() and bool(_state.get_arena_status().get("has_arena", false)),
		"Cold reload preserves constructed Arena Pit without stale active bout")
	await _verify_spectating_quickload(w1_id, w2_id)

	DirAccess.remove_absolute(save_path)
	if _sound != null:
		_sound.shutdown()
	_unmount()
	await frames(2)

	if _failed or _fail_count > 0:
		push_error("ARENA TRIALS VERIFICATION FAILED (%d passed, %d failed)" % [_pass_count, _fail_count])
		quit(1)
		return
	print("ARENA TRIALS VERIFICATION PASSED (%d checks)" % _pass_count)
	quit(0)


func _verify_spectating_quickload(fighter_id: int, recovering_id: int) -> void:
	var pc: Node = _state.player_controller
	var fc: Node = _state.faction_controllers[0]
	var leader: Node3D = _state.get_faction_leader(0)
	var second_pit: Node3D = fc.spawn_building("ARENA_PIT", leader.global_position + Vector3(18.0, 0.0, 0.0), 0.0, true)
	leader.global_position = second_pit.global_position
	_state.spatial_index.update_unit(leader)
	_state.time_of_day = 23.0
	check(_state.start_arena_bout(ArenaRules.MODE_EXHIBITION, 4, [fighter_id]), "Started Tier IV with human opponents for quicksave")
	check(pc.is_spectating_arena and ArenaRules.get_arena_building(_state) == second_pit, "Exhibition spectates the pit closest to the leader")
	var old_opponents: Array = _state.arena_bout.get("opponent_nodes", []).duplicate()
	var unit_count: int = _state.units_container.get_child_count() - old_opponents.size()
	var recovery: float = _find_unit_by_id(recovering_id).arena_recovery_remaining
	key_press(KEY_F9)
	check(FileAccess.file_exists(_state.CAMPAIGN_SAVE_PATH), "F9 writes the campaign while spectating an exhibition")
	key_press(KEY_F10)
	await frames(3)
	check(not _state.is_arena_bout_active() and not pc.is_spectating_arena and not _find_unit_by_id(fighter_id).is_arena_combatant,
		"F10 clears bout flags and spectator mode")
	check(_state.units_container.get_child_count() == unit_count and old_opponents.all(func(node): return not is_instance_valid(node)),
		"F10 discards temporary human opponents")
	check(absf(_find_unit_by_id(recovering_id).arena_recovery_remaining - recovery) < 0.2,
		"F10 preserves the recovery timer from the mid-bout save")
	check(_sound == null or _sound.get_active_music_state() == "NIGHT", "F10 restores night music from the saved time")
	var host: Node3D = ArenaRules.get_arena_building(_state)
	check(_state.start_arena_bout(ArenaRules.MODE_EXHIBITION, 1, [fighter_id]), "Started a bout with two constructed pits")
	host.take_damage(9999.0, 5)
	await frames(3)
	check(not _state.is_arena_bout_active() and not pc.is_spectating_arena and ArenaRules.get_arena_building(_state) != null,
		"Destroying the host pit forfeits the bout even with a second pit standing")


func _contains_arena_wildlife(wildlife_arr: Array) -> bool:
	for w in wildlife_arr:
		if w is Dictionary:
			var t: String = str((w as Dictionary).get("animal_type", ""))
			if t == "BOAR" or t == "WOLF":
				var pos_v: Variant = (w as Dictionary).get("pos", [0, 0, 0])
				if pos_v is Array and (pos_v as Array).size() >= 3:
					var p := Vector3(float(pos_v[0]), float(pos_v[1]), float(pos_v[2]))
					if p.distance_to(Vector3(14.0, 0.0, 52.0)) < 7.0:
						return true
	return false

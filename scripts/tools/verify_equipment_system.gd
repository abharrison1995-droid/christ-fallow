extends SceneTree
## Forward+ verification suite for Phase 7 (Weapons & Armor Equipment System).
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.
## Also supports `-- --procedural-roster` to verify HumanMeshBuilder procedural gear paths.

const Layout = preload("res://scripts/core/world_layout.gd")
const CragBornTrial = preload("res://scripts/entities/crag_born_trial.gd")

var _state: Node
var _main: Node
var _unit_ai_routines: Script
var _unit_combat_ai: Script
var _failed := false
var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, caption: String) -> void:
	if condition:
		_pass_count += 1
		print("PASS ", caption)
	else:
		_fail_count += 1
		_failed = true
		push_error("FAIL " + caption)


func frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame


func key_press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev, true)
	ev = InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	root.push_input(ev, true)


func _mount() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _unmount() -> void:
	_state.end_campaign()
	root.remove_child(_main)
	_main.queue_free()


func _find_tagged_button(scope: Node, key: String) -> BaseButton:
	for node in scope.find_children("*", "BaseButton", true, false):
		var btn := node as BaseButton
		if btn != null and btn.get_meta("drawer_focus", "") == key and btn.is_visible_in_tree():
			return btn
	return null


func _select_option_by_meta(opt: OptionButton, target_meta: String) -> bool:
	for i in range(opt.item_count):
		if str(opt.get_item_metadata(i)) == target_meta:
			opt.grab_focus()
			opt.select(i)
			opt.item_selected.emit(i)
			return true
	return false


func _verify_fp_meshes_hidden(leader: Node, label: String) -> void:
	var meshes: Array = leader.get("_cached_fp_meshes")
	var smalls: Array = leader.get("_cached_fp_small_meshes")
	check(not meshes.is_empty(), "%s: FP mesh cache populated (%d)" % [label, meshes.size()])
	var all_hidden := true
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var m := mi as MeshInstance3D
		if m == null:
			continue
		if m in smalls:
			if m.layers != 0 or m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				all_hidden = false
				break
		else:
			if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				all_hidden = false
				break
	check(all_hidden, "%s: all 3rd-person meshes hidden in FP POV" % label)


func _verify_tp_meshes_restored(leader: Node, label: String) -> void:
	var meshes: Array = leader.get("_cached_fp_meshes")
	var smalls: Array = leader.get("_cached_fp_small_meshes")
	var all_visible := true
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var m := mi as MeshInstance3D
		if m == null:
			continue
		if m in smalls:
			if m.layers == 0:
				all_visible = false
				break
		else:
			if m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				all_visible = false
				break
	check(all_visible, "%s: 3rd-person meshes restored on POV exit" % label)


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return

	_state = root.get_node("GameState")
	_unit_ai_routines = load("res://scripts/entities/unit_ai_routines.gd")
	_unit_combat_ai = load("res://scripts/entities/unit_combat_ai.gd")
	_mount()
	await frames(3)
	_state.start_new_campaign("Kaelen", "Iron Flints", GameData.Lineage.CRAG_BORN, Layout.CLASSIC_ID)
	await frames(4)

	var leader: Node = _state.get_faction_leader(0)
	var fc: Node = _state.faction_controllers[0]
	var hud: Node = _state.hud_controller
	var pc: Node = _state.player_controller
	check(leader != null and fc != null and hud != null and pc != null, "Campaign bootstrapped for equipment suite")

	# ------------------------------------------------------------------
	# (a) Crafting Pit recipes, tier gating, and crafting completion
	# ------------------------------------------------------------------
	var f0: Dictionary = _state.factions[0]
	for res_k in ["food", "wood", "stone", "flint", "hide", "bone"]:
		f0["resources"][res_k] = 300.0
	var pit: Node = fc.spawn_building("CRAFTING_PIT", leader.global_position + Vector3(4.0, 0.0, 0.0), 1.0, true)
	var crafter: Node = fc.spawn_colonist(pit.global_position + Vector3(0.5, 0.0, 0.5), GameData.Lineage.CRAG_BORN, GameData.Gender.FEMALE, GameData.Role.BUILDER_CRAFTER)
	check(pit != null and crafter != null, "Spawned Crafting Pit and Crafter")

	check(not fc.queue_craft("obsidian_cleavers"), "Tier 3 weapon blocked at Tier 1")
	check(not fc.queue_craft("pelt_mantle"), "Tier 2 armor blocked at Tier 1")
	check(not fc.queue_craft("obsidian_plate"), "Tier 3 armor blocked at Tier 1")

	check(fc.queue_craft("hide_tunic"), "Tier 1 hide_tunic queues")
	check(fc.queue_craft("great_spears"), "Tier 1 great_spears queues")
	check(fc.queue_craft("clubs"), "Tier 1 clubs queues")
	check(fc.queue_craft("knives"), "Tier 1 knives queues")
	check(fc.queue_craft("bows"), "Tier 1 bows queues")

	var stock: Dictionary = f0["stockpile"]
	var before_t1 := {
		"hide_tunic": int(stock.get("hide_tunic", 0)),
		"great_spears": int(stock.get("great_spears", 0)),
		"clubs": int(stock.get("clubs", 0)),
		"knives": int(stock.get("knives", 0)),
		"bows": int(stock.get("bows", 0)),
	}
	for _step in range(30):
		if f0["craft_queue"].is_empty():
			break
		_unit_ai_routines.run_day_work_routine(crafter, 1.5)
	check(f0["craft_queue"].is_empty(), "Tier 1 craft queue completes")
	for k in before_t1.keys():
		check(int(stock.get(k, 0)) == int(before_t1[k]) + 1, "Crafted 1x %s into stockpile" % k)

	check(fc.upgrade_stone_age_tier() and int(f0["tech_tier"]) == 2, "Upgraded to Tier 2")
	check(fc.queue_craft("pelt_mantle"), "Tier 2 pelt_mantle queues at Tier 2")
	check(not fc.queue_craft("obsidian_cleavers"), "Tier 3 weapon still blocked at Tier 2")
	for _step in range(10):
		if f0["craft_queue"].is_empty():
			break
		_unit_ai_routines.run_day_work_routine(crafter, 1.5)
	check(int(stock.get("pelt_mantle", 0)) >= 1, "Crafted pelt_mantle at Tier 2")

	check(fc.upgrade_stone_age_tier() and int(f0["tech_tier"]) == 3, "Upgraded to Tier 3")
	check(fc.queue_craft("obsidian_cleavers"), "Tier 3 obsidian_cleavers queues at Tier 3")
	check(fc.queue_craft("obsidian_plate"), "Tier 3 obsidian_plate queues at Tier 3")
	for _step in range(20):
		if f0["craft_queue"].is_empty():
			break
		_unit_ai_routines.run_day_work_routine(crafter, 1.5)
	check(int(stock.get("obsidian_cleavers", 0)) >= 1 and int(stock.get("obsidian_plate", 0)) >= 1, "Crafted Tier 3 weapon & armor")

	# ------------------------------------------------------------------
	# (b) Stockpile math: no dupes on defaults, refund on swap, no negative stock, NONE unequip
	# ------------------------------------------------------------------
	var warrior: Node = fc.spawn_colonist(leader.global_position + Vector3(-3.0, 0.0, 2.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR)
	warrior.set_role_and_class(GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN)
	check(warrior != null, "Spawned player Spearman warrior")
	# Reset warrior raw gear & stockpile counts deterministically AFTER set_role_and_class auto-equip
	warrior.equip_loadout("", "NONE")
	for sk in ["spears", "great_spears", "clubs", "knives", "bows", "javelins", "obsidian_cleavers", "armor", "hide_tunic", "pelt_mantle", "obsidian_plate"]:
		stock[sk] = 1

	check(leader.equipped_weapon_id == "" and leader.get_equipped_weapon_id() == "GREAT_SPEAR", "Leader starts with default GREAT_SPEAR (raw empty)")
	check(_state.equip_unit_weapon(leader, "WAR_CLUB"), "Equip WAR_CLUB onto fresh Leader")
	check(int(stock["clubs"]) == 0 and int(stock["great_spears"]) == 1, "Swapping off default GREAT_SPEAR consumes clubs without duping great_spears")

	check(_state.equip_unit_weapon(leader, "FLINT_DIRK"), "Equip FLINT_DIRK onto Leader")
	check(int(stock["knives"]) == 0 and int(stock["clubs"]) == 1, "Swapping WAR_CLUB -> FLINT_DIRK consumes knives and refunds clubs")

	check(_state.equip_unit_weapon(warrior, "WAR_CLUB"), "Warrior equips WAR_CLUB from stockpile")
	check(int(stock["clubs"]) == 0, "clubs decremented to 0")
	check(not _state.equip_unit_weapon(leader, "WAR_CLUB"), "Cannot equip WAR_CLUB when clubs == 0")
	check(int(stock["clubs"]) == 0, "Stockpile never goes negative on failed equip")

	# Armor stockpile math & NONE unequip
	check(leader.equipped_armor_id == "" and leader.get_equipped_armor_id() == "BONE_GUARD", "Leader starts with default BONE_GUARD (raw empty)")
	check(_state.equip_unit_armor(leader, "HIDE_TUNIC"), "Equip HIDE_TUNIC onto fresh Leader")
	check(int(stock["hide_tunic"]) == 0 and int(stock["armor"]) == 1, "Swapping off default armor consumes hide_tunic without duping armor")
	check(_state.equip_unit_armor(leader, "NONE"), "Unequip Leader armor to NONE")
	check(int(stock["hide_tunic"]) == 1 and not leader.has_armor and leader.get_equipped_armor_id() == "NONE", "Unequipping HIDE_TUNIC refunds hide_tunic and sets NONE")
	check(_state.equip_unit_armor(leader, "NONE") and int(stock["hide_tunic"]) == 1, "Re-applying NONE is a no-op with no dupe")

	# Replenish stockpile for stat, projectile, visual, and UI tests
	for sk in ["spears", "great_spears", "clubs", "knives", "bows", "javelins", "obsidian_cleavers", "armor", "hide_tunic", "pelt_mantle", "obsidian_plate"]:
		stock[sk] = 5

	# ------------------------------------------------------------------
	# (c) UnitStats stat changes & Bow shooting Arrow projectiles
	# ------------------------------------------------------------------
	_state.equip_unit_armor(leader, "NONE")
	var base_none_hp: float = float(leader.max_hp)
	var base_none_arm: float = float(leader.armor)
	var base_none_spd: float = float(leader.move_speed)

	check(_state.equip_unit_armor(leader, "HIDE_TUNIC"), "Leader equips HIDE_TUNIC")
	check(is_equal_approx(float(leader.max_hp), base_none_hp + 10.0), "HIDE_TUNIC grants +10 HP")
	check(is_equal_approx(float(leader.armor), base_none_arm + 5.0), "HIDE_TUNIC grants +5 armor")

	check(_state.equip_unit_armor(leader, "PELT_MANTLE"), "Leader equips PELT_MANTLE")
	check(is_equal_approx(float(leader.max_hp), base_none_hp + 25.0), "PELT_MANTLE grants +25 HP")
	check(is_equal_approx(float(leader.armor), base_none_arm + 10.0), "PELT_MANTLE grants +10 armor")
	check(leader.move_speed < base_none_spd, "PELT_MANTLE applies 0.98 move multiplier")

	check(_state.equip_unit_armor(leader, "OBSIDIAN_PLATE"), "Leader equips OBSIDIAN_PLATE")
	check(is_equal_approx(float(leader.max_hp), base_none_hp + 40.0), "OBSIDIAN_PLATE grants +40 HP")
	check(is_equal_approx(float(leader.armor), base_none_arm + 18.0), "OBSIDIAN_PLATE grants +18 armor")
	check(leader.move_speed < base_none_spd * 0.98, "OBSIDIAN_PLATE applies 0.95 move multiplier")

	check(_state.equip_unit_armor(leader, "BONE_GUARD"), "Leader equips BONE_GUARD")
	# At Tier 3, BONE_GUARD grants +8 + 4*(3-1) = +16 armor, +0 HP
	check(is_equal_approx(float(leader.max_hp), base_none_hp), "BONE_GUARD grants +0 HP")
	check(is_equal_approx(float(leader.armor), base_none_arm + 16.0), "BONE_GUARD grants Tier-scaled +16 armor at T3")

	# Weapons stat verification
	check(_state.equip_unit_weapon(leader, "GREAT_SPEAR"), "Leader equips GREAT_SPEAR")
	var gs_dmg: float = float(leader.attack_damage)
	var gs_cd: float = float(leader.attack_cooldown_max)
	var gs_arm: float = float(leader.armor)

	# Return clubs from warrior so Leader can test WAR_CLUB
	_state.equip_unit_weapon(warrior, "STONE_SPEAR")
	check(_state.equip_unit_weapon(leader, "WAR_CLUB"), "Leader equips WAR_CLUB")
	check(float(leader.attack_damage) > gs_dmg and is_equal_approx(float(leader.attack_range), 2.45) and float(leader.attack_cooldown_max) > gs_cd,
		"WAR_CLUB increases damage, sets 2.45m reach, and slows cooldown")

	check(_state.equip_unit_weapon(leader, "FLINT_DIRK"), "Leader equips FLINT_DIRK")
	check(float(leader.attack_damage) < gs_dmg and is_equal_approx(float(leader.attack_range), 1.9) and float(leader.attack_cooldown_max) < gs_cd,
		"FLINT_DIRK sets 1.9m reach and faster cooldown")

	check(_state.equip_unit_weapon(leader, "OBSIDIAN_CLEAVER"), "Leader equips OBSIDIAN_CLEAVER")
	check(float(leader.attack_damage) > gs_dmg and is_equal_approx(float(leader.armor), gs_arm + 1.0),
		"OBSIDIAN_CLEAVER grants high damage and +1 armor")

	check(_state.equip_unit_weapon(leader, "HUNTING_BOW"), "Leader equips HUNTING_BOW")
	check(leader.is_ranged_weapon and leader.projectile_type == "ARROW" and float(leader.attack_range) >= 17.5,
		"HUNTING_BOW sets ranged ARROW mode with >=17.5m range")

	# Leader fires BOW in 3rd-person
	pc._attack_cd = 0.0
	var proj_before: int = _state.projectiles_container.get_child_count()
	pc._try_melee_cleave(false)
	var proj_after: int = _state.projectiles_container.get_child_count()
	check(proj_after == proj_before + 1, "Leader HUNTING_BOW 3rd-person attack spawns projectile")
	if proj_after > proj_before:
		var arrow: Node = _state.projectiles_container.get_child(proj_after - 1)
		check(str(arrow.get("proj_type")) == "ARROW" and arrow.get("shooter") == leader, "Spawned projectile is Leader's ARROW")

	# Warrior fires BOW via UnitCombatAI
	_state.equip_unit_weapon(leader, "GREAT_SPEAR")
	check(_state.equip_unit_weapon(warrior, "HUNTING_BOW"), "Warrior equips HUNTING_BOW")
	check(warrior.is_ranged_weapon and warrior.projectile_type == "ARROW", "Warrior switches to ranged ARROW mode")
	var dummy_enemy: Node = _state.faction_controllers[1].spawn_colonist(warrior.global_position + Vector3(8.0, 0.0, 0.0), GameData.Lineage.CRAG_BORN, GameData.Gender.MALE, GameData.Role.WARRIOR)
	check(_unit_combat_ai.can_shoot_or_reach(warrior, dummy_enemy), "Warrior with HUNTING_BOW can shoot enemy at 8m")
	var w_proj_before: int = _state.projectiles_container.get_child_count()
	_unit_combat_ai.execute_attack_on(warrior, dummy_enemy)
	var w_proj_after: int = _state.projectiles_container.get_child_count()
	check(w_proj_after == w_proj_before + 1 and str(_state.projectiles_container.get_child(w_proj_after - 1).get("proj_type")) == "ARROW",
		"Warrior with HUNTING_BOW fires ARROW projectile via UnitCombatAI")
	if is_instance_valid(dummy_enemy):
		dummy_enemy.queue_free()

	# ------------------------------------------------------------------
	# (d) 3rd-person (CragBornTrial / HumanMeshBuilder) & 1st-person (FirstPersonViewmodel)
	# ------------------------------------------------------------------
	var use_trial: bool = CragBornTrial.enabled()
	if use_trial:
		var trial: Node = leader.get("_skinned_trial")
		check(trial is CragBornTrial, "Leader uses CragBornTrial in default mode")
		for wid in ["WAR_CLUB", "FLINT_DIRK", "HUNTING_BOW", "OBSIDIAN_CLEAVER", "GREAT_SPEAR"]:
			_state.equip_unit_weapon(leader, wid)
			var skel: Skeleton3D = trial.get("_skeleton")
			var has_w: bool = skel != null and skel.get_node_or_null("Weapon") != null
			var has_o: bool = skel != null and skel.get_node_or_null("Offhand") != null
			var expect_o: bool = str(GameData.WEAPON_DEFS[wid].get("offhand_glb", "")) != ""
			check(trial.get("_equipped_weapon_id") == wid and has_w and (has_o == expect_o),
				"CragBornTrial mounts 3rd-person weapon/offhand for %s" % wid)
		for aid in ["NONE", "HIDE_TUNIC", "PELT_MANTLE", "OBSIDIAN_PLATE", "BONE_GUARD"]:
			_state.equip_unit_armor(leader, aid)
			var armor_node: Node3D = trial.get("_armor")
			var armor_ok: bool = (armor_node == null or not armor_node.visible) if aid == "NONE" else (armor_node != null and armor_node.visible)
			check(trial.get("_equipped_armor_id") == aid and armor_ok, "CragBornTrial updates 3rd-person armor for %s" % aid)
	else:
		var vroot: Node3D = leader.get("_visual_root")
		check(vroot != null, "Leader uses procedural HumanMeshBuilder visual_root under --procedural-roster")
		_state.equip_unit_weapon(leader, "HUNTING_BOW")
		_state.equip_unit_armor(leader, "NONE")
		var chest: Node = vroot.find_child("ChestPivot", true, false)
		var armor_mount: Node3D = chest.get_node_or_null("ArmorMount") as Node3D if chest != null else null
		var o_mount: Node = vroot.find_child("OffhandMount", true, false)
		var bow_mesh: Node3D = o_mount.get_node_or_null("BOW") as Node3D if o_mount != null else null
		check(armor_mount != null and not armor_mount.visible, "Procedural ArmorMount hides on NONE")
		check(bow_mesh != null and bow_mesh.visible, "Procedural OffhandMount activates BOW on HUNTING_BOW")
		_state.equip_unit_armor(leader, "OBSIDIAN_PLATE")
		_state.equip_unit_weapon(leader, "OBSIDIAN_CLEAVER")
		var club_mount: Node = vroot.find_child("WeaponMount", true, false)
		var club_mesh: Node3D = club_mount.get_node_or_null("WAR_CLUB") as Node3D if club_mount != null else null
		check(armor_mount != null and armor_mount.visible, "Procedural ArmorMount visible on OBSIDIAN_PLATE")
		check(club_mesh != null and club_mesh.visible, "Procedural WeaponMount activates WAR_CLUB on OBSIDIAN_CLEAVER")

	# First-Person POV mid-POV gear swaps & body occlusion check
	_state.equip_unit_weapon(leader, "GREAT_SPEAR")
	_state.equip_unit_armor(leader, "BONE_GUARD")
	key_press(KEY_Z)
	await frames(4)
	check(pc.is_first_person, "Z enters First-Person POV")
	var vm: Node = pc.get("_fp_viewmodel")
	check(vm != null and vm.get("_built_weapon_id") == "GREAT_SPEAR" and vm.get("_built_armor_id") == "BONE_GUARD",
		"FirstPersonViewmodel builds initial GREAT_SPEAR + BONE_GUARD")
	_verify_fp_meshes_hidden(leader, "Initial FP")

	# Swap mid-POV to HUNTING_BOW + OBSIDIAN_PLATE and fire an arrow
	_state.equip_unit_weapon(leader, "HUNTING_BOW")
	_state.equip_unit_armor(leader, "OBSIDIAN_PLATE")
	await frames(4)
	check(vm.get("_built_weapon_id") == "HUNTING_BOW" and vm.get("_built_armor_id") == "OBSIDIAN_PLATE",
		"FirstPersonViewmodel updates mid-POV to HUNTING_BOW + OBSIDIAN_PLATE")
	_verify_fp_meshes_hidden(leader, "Mid-POV Bow + Obsidian Plate")
	pc._attack_cd = 0.0
	var fp_proj_before: int = _state.projectiles_container.get_child_count()
	pc._try_melee_cleave(false)
	var fp_proj_after: int = _state.projectiles_container.get_child_count()
	check(fp_proj_after == fp_proj_before + 1 and str(_state.projectiles_container.get_child(fp_proj_after - 1).get("proj_type")) == "ARROW",
		"First-Person HUNTING_BOW fires ARROW projectile")

	# Swap mid-POV to WAR_CLUB + NONE, then FLINT_DIRK + PELT_MANTLE, then OBSIDIAN_CLEAVER + HIDE_TUNIC
	for pair in [["WAR_CLUB", "NONE"], ["FLINT_DIRK", "PELT_MANTLE"], ["OBSIDIAN_CLEAVER", "HIDE_TUNIC"]]:
		_state.equip_unit_weapon(leader, pair[0])
		_state.equip_unit_armor(leader, pair[1])
		await frames(4)
		check(vm.get("_built_weapon_id") == pair[0] and vm.get("_built_armor_id") == pair[1],
			"FirstPersonViewmodel swaps mid-POV to %s + %s" % [pair[0], pair[1]])
		_verify_fp_meshes_hidden(leader, "Mid-POV %s + %s" % [pair[0], pair[1]])

	# Exit First-Person POV -> verify 3rd-person meshes restore cleanly
	key_press(KEY_Z)
	await frames(4)
	check(not pc.is_first_person, "Z exits First-Person POV back to Third-Person")
	_verify_tp_meshes_restored(leader, "Post-swap exit FP")

	# ------------------------------------------------------------------
	# (e) UI controls: ColonyDrawer Crafting tab & UnitInspector
	# ------------------------------------------------------------------
	# Ensure stockpile has items to select in UI
	stock["great_spears"] = maxi(1, int(stock.get("great_spears", 0)))
	stock["clubs"] = maxi(1, int(stock.get("clubs", 0)))
	stock["obsidian_plate"] = maxi(1, int(stock.get("obsidian_plate", 0)))

	key_press(KEY_C)
	await frames(4)
	var colony_drawer: Control = hud._drawer_views["COLONY"]
	var craft_tab_btn := _find_tagged_button(colony_drawer, "section:Crafting")
	check(craft_tab_btn != null, "ColonyDrawer has Crafting tab")
	if craft_tab_btn != null:
		craft_tab_btn.pressed.emit()
		await frames(3)

	var lw_opt := _find_tagged_button(colony_drawer, "leader-weapon") as OptionButton
	var la_opt := _find_tagged_button(colony_drawer, "leader-armor") as OptionButton
	check(lw_opt != null and la_opt != null, "ColonyDrawer Crafting tab exposes leader-weapon and leader-armor OptionButtons")
	if lw_opt != null:
		check(_select_option_by_meta(lw_opt, "GREAT_SPEAR"), "ColonyDrawer equips GREAT_SPEAR onto Leader")
		await frames(2)
		check(leader.get_equipped_weapon_id() == "GREAT_SPEAR", "Leader equipped GREAT_SPEAR via ColonyDrawer")
		check(root.gui_get_focus_owner() == null, "ColonyDrawer leader-weapon releases focus")
	if la_opt != null:
		check(_select_option_by_meta(la_opt, "OBSIDIAN_PLATE"), "ColonyDrawer equips OBSIDIAN_PLATE onto Leader")
		await frames(2)
		check(leader.get_equipped_armor_id() == "OBSIDIAN_PLATE", "Leader equipped OBSIDIAN_PLATE via ColonyDrawer")
		check(root.gui_get_focus_owner() == null, "ColonyDrawer leader-armor releases focus")

	var craft_btn := _find_tagged_button(colony_drawer, "craft:hide_tunic")
	check(craft_btn != null and not craft_btn.disabled, "ColonyDrawer craft:hide_tunic button available")
	if craft_btn != null:
		var q_before: int = f0["craft_queue"].size()
		craft_btn.grab_focus()
		craft_btn.pressed.emit()
		await frames(2)
		check(f0["craft_queue"].size() == q_before + 1, "ColonyDrawer craft button queues recipe")
		check(root.gui_get_focus_owner() == null, "ColonyDrawer craft button releases focus")

	hud.close_drawer()
	await frames(2)

	# UnitInspector on Warrior
	var insp: Control = hud._inspector_panel
	insp.inspect_unit(warrior)
	await frames(3)
	check(insp.visible, "UnitInspector opens on Warrior")
	var vp_h: float = root.get_visible_rect().size.y
	check(insp.offset_bottom <= vp_h - 166.0 + 1.5, "UnitInspector fits cleanly above squad bar (bottom %.1f <= %.1f)" % [insp.offset_bottom, vp_h - 166.0])

	var iw_opt: OptionButton = insp.get("_insp_weapon_opt")
	var ia_opt: OptionButton = insp.get("_insp_armor_opt")
	check(iw_opt != null and ia_opt != null and iw_opt.visible and ia_opt.visible, "UnitInspector shows Weapon and Armor selectors")
	if iw_opt != null:
		check(_select_option_by_meta(iw_opt, "WAR_CLUB"), "UnitInspector equips WAR_CLUB onto Warrior")
		await frames(2)
		check(warrior.get_equipped_weapon_id() == "WAR_CLUB", "Warrior equipped WAR_CLUB via UnitInspector")
		check(root.gui_get_focus_owner() == null, "UnitInspector weapon OptionButton releases focus")
	if ia_opt != null:
		check(_select_option_by_meta(ia_opt, "NONE"), "UnitInspector unequips Warrior armor to NONE")
		await frames(2)
		check(warrior.get_equipped_armor_id() == "NONE", "Warrior unarmored via UnitInspector")
		check(root.gui_get_focus_owner() == null, "UnitInspector armor OptionButton releases focus")
	insp.close()
	await frames(2)

	# ------------------------------------------------------------------
	# (f) Save & Load persistence (in-session + cold reload)
	# ------------------------------------------------------------------
	_state.equip_unit_weapon(leader, "OBSIDIAN_CLEAVER")
	_state.equip_unit_armor(leader, "OBSIDIAN_PLATE")
	_state.equip_unit_weapon(warrior, "HUNTING_BOW")
	_state.equip_unit_armor(warrior, "PELT_MANTLE")
	var saved_leader_id: int = int(leader.unit_id)
	var saved_warrior_id: int = int(warrior.unit_id)
	var saved_stock: Dictionary = f0["stockpile"].duplicate(true)
	var save_path := "user://equip_verify_%d.json" % Time.get_ticks_usec()
	check(_state.save_game(save_path), "Saved campaign with custom equipment")

	# In-session reload (check immediately before AI auto-upgrade ticks)
	check(_state.load_game(save_path), "In-session load succeeded")
	var r_leader: Node = _state.get_faction_leader(0)
	var r_warrior: Node = null
	for u in _state.get_faction_units(0):
		if int(u.unit_id) == saved_warrior_id:
			r_warrior = u
			break
	check(r_leader != null and int(r_leader.unit_id) == saved_leader_id, "In-session reload restores Leader")
	check(r_leader.get_equipped_weapon_id() == "OBSIDIAN_CLEAVER" and r_leader.get_equipped_armor_id() == "OBSIDIAN_PLATE",
		"In-session reload preserves Leader OBSIDIAN_CLEAVER + OBSIDIAN_PLATE")
	check(r_warrior != null and r_warrior.get_equipped_weapon_id() == "HUNTING_BOW" and r_warrior.get_equipped_armor_id() == "PELT_MANTLE",
		"In-session reload preserves Warrior HUNTING_BOW + PELT_MANTLE")
	check(r_warrior.is_ranged_weapon and r_warrior.projectile_type == "ARROW",
		"In-session reload restores Warrior ranged ARROW stats")

	# Cold reload
	_unmount()
	await frames(2)
	_mount()
	await frames(2)
	check(_state.load_game(save_path), "Cold load succeeded")
	var c_leader: Node = _state.get_faction_leader(0)
	var c_warrior: Node = null
	for u in _state.get_faction_units(0):
		if int(u.unit_id) == saved_warrior_id:
			c_warrior = u
			break
	check(c_leader != null and c_leader.get_equipped_weapon_id() == "OBSIDIAN_CLEAVER" and c_leader.get_equipped_armor_id() == "OBSIDIAN_PLATE",
		"Cold reload preserves Leader OBSIDIAN_CLEAVER + OBSIDIAN_PLATE")
	check(c_warrior != null and c_warrior.get_equipped_weapon_id() == "HUNTING_BOW" and c_warrior.get_equipped_armor_id() == "PELT_MANTLE",
		"Cold reload preserves Warrior HUNTING_BOW + PELT_MANTLE")
	var c_stock: Dictionary = _state.factions[0]["stockpile"]
	for opt_k in ["great_spears", "obsidian_cleavers", "hide_tunic", "pelt_mantle", "obsidian_plate"]:
		check(int(c_stock.get(opt_k, -1)) == int(saved_stock.get(opt_k, -2)),
			"Cold reload preserves stockpile key %s (%d)" % [opt_k, int(c_stock.get(opt_k, -1))])

	DirAccess.remove_absolute(save_path)
	if _failed:
		push_error("EQUIPMENT SYSTEM VERIFICATION FAILED (%d passed, %d failed)" % [_pass_count, _fail_count])
		quit(1)
		return
	print("EQUIPMENT SYSTEM VERIFICATION PASSED (%d checks)" % _pass_count)
	quit(0)

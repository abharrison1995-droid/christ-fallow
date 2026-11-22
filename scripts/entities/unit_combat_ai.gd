extends RefCounted
## Combat and AI decision routines for tribesfolk, raiders, cavemen, rebels, and wanderers.

const Layout = preload("res://scripts/core/world_layout.gd")
const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const BlessingEffects = preload("res://scripts/systems/blessing_effects.gd")
const Projectile3D = preload("res://scripts/entities/projectile_3d.gd")


static func process_wild_wanderer(u: Node, _delta: float) -> void:
	# Gently face player leader and recruit on proximity
	var p_leader: Node = GameState.get_faction_leader(0)
	if p_leader != null:
		var leader_pos: Vector3 = (p_leader as Node3D).global_position
		var dist: float = (u as Node3D).global_position.distance_to(leader_pos)
		if dist < 4.5:
			u.convert_to_faction(0, false)
			var lin_short: String = str(GameData.LINEAGE_DATA[int(u.lineage)]["short_name"])
			GameState.push_log("Recruited %s (%s) into your tribe!" % [str(u.unit_name), lin_short], "success")
			return
		elif dist < 14.0:
			u._face_point(leader_pos)
	(u as CharacterBody3D).velocity.x = 0.0
	(u as CharacterBody3D).velocity.z = 0.0


static func process_feral_caveman(u: Node, _delta: float) -> void:
	var u3d := u as Node3D
	var u_body := u as CharacterBody3D
	var u_pos: Vector3 = u3d.global_position
	var spd: float = float(u.move_speed)
	var target: Node = u._find_nearest_enemy_unit(32.0)
	if target == null:
		# March toward nearest founded non-caveman colony (or player leader if none founded)
		var march_pos := Vector3.ZERO
		var best_d := 999999999.0
		var found_goal := false
		for fid in GameState.factions.keys():
			var fid_int: int = int(fid)
			if fid_int == 5:
				continue
			var fdata: Dictionary = GameState.factions[fid_int]
			if fdata.get("is_defeated") == true or fdata.get("is_founded") != true:
				continue
			var c_pos: Vector3 = fdata.get("camp_position", Vector3.ZERO)
			var d: float = u_pos.distance_squared_to(c_pos)
			if d < best_d:
				best_d = d
				march_pos = c_pos
				found_goal = true
		if not found_goal:
			var p_leader: Node = GameState.get_faction_leader(0)
			if p_leader != null:
				march_pos = (p_leader as Node3D).global_position
		u._steer_toward(march_pos, spd * 0.85)
		return

	var t_pos: Vector3 = (target as Node3D).global_position
	var dist: float = u_pos.distance_to(t_pos)
	if dist > float(u.attack_range):
		u._steer_toward(t_pos, spd)
	else:
		u_body.velocity.x = 0.0
		u_body.velocity.z = 0.0
		if float(u._attack_cd) <= 0.0:
			execute_attack_on(u, target)


static func process_rebel_ai(u: Node, delta: float) -> void:
	var target: Node = u._find_nearest_enemy_unit(32.0)
	if target != null:
		engage_target(u, target)
		return
	var b_target: Node = u._find_nearest_enemy_building(Layout.SCAN_RANGE_CAMP)
	if b_target != null:
		engage_building(u, b_target)
		return
	var camp: Vector3 = u._get_home_camp_pos()
	u._patrol_around(camp, 8.0, delta)


static func _unit_weapon_def(u: Node) -> Dictionary:
	var wid: String = u.get_equipped_weapon_id() if u.has_method("get_equipped_weapon_id") else str(u.get("equipped_weapon_id"))
	var eff_role: int = GameData.Role.WARRIOR if (u.has_method("_is_warhorn_militia") and u._is_warhorn_militia()) else int(u.role)
	return GameData.resolve_weapon_def(wid, eff_role, int(u._get_effective_warrior_class()), u.is_leader == true, u.is_caveman == true)


static func process_player_warrior(u: Node, delta: float, enemy: Node) -> void:
	var p_leader: Node = GameState.get_faction_leader(0)
	var camp: Vector3 = u._get_home_camp_pos()
	var wdef: Dictionary = _unit_weapon_def(u)
	var is_ranged_unit: bool = bool(wdef.get("is_ranged", false))

	# If unequipped or below faction tech tier and Rack/stockpile exists, equip periodically
	var fid: int = int(u.faction_id)
	var fdata: Dictionary = GameState.factions.get(fid, {})
	var cur_tier: int = int(fdata.get("tech_tier", 1))
	var fstock: Dictionary = fdata.get("stockpile", {})
	var has_tier_upgrade: bool = (cur_tier >= 2 and int(fstock.get("pelt_mantle", 0)) > 0) or (cur_tier >= 3 and (int(fstock.get("obsidian_plate", 0)) > 0 or int(fstock.get("obsidian_cleavers", 0)) > 0))
	if int(u.role) == GameData.Role.WARRIOR and (u.has_equipped_weapon != true or int(u.weapon_tier) < cur_tier or u.has_armor != true or has_tier_upgrade) and float(u._ai_think_cd) <= 0.0:
		u._ai_think_cd = 3.0
		u.try_equip_from_stockpile()

	var u_pos: Vector3 = (u as Node3D).global_position
	var u_body := u as CharacterBody3D
	var eff_speed: float = float(u.move_speed) * float(u._buff_speed_mult)
	var fire_will: bool = (u.fire_at_will == true)
	var order: int = int(u.squad_order)

	match order:
		GameData.SquadOrder.RETREAT:
			var can_train_idle: bool = GameState.current_phase == GameData.SchedulePhase.DAY_WORK and PerkSystem.can_idle_warriors_train(fdata)
			var nearest_barracks: Node3D = null
			var home_radius: float = 4.0
			if can_train_idle:
				var barracks_list: Array = GameState.get_faction_buildings(fid, "BARRACKS", true)
				var best_b_dist: float = INF
				for b_item in barracks_list:
					if is_instance_valid(b_item) and b_item is Node3D:
						var b_node: Node3D = b_item as Node3D
						var d_u: float = u_pos.distance_to(b_node.global_position)
						if d_u < best_b_dist:
							best_b_dist = d_u
							nearest_barracks = b_node
				if nearest_barracks != null:
					var camp_b_dist: float = camp.distance_to(nearest_barracks.global_position)
					if camp_b_dist <= 28.0:
						home_radius = clampf(camp_b_dist + 4.0, 4.0, 32.0)
					else:
						nearest_barracks = null
			if u_pos.distance_to(camp) > home_radius:
				u._steer_toward(camp, eff_speed * 1.15)
			elif nearest_barracks != null:
				u._train_at_barracks(delta)
			else:
				u_body.velocity.x = 0.0
				u_body.velocity.z = 0.0
		GameData.SquadOrder.HOLD:
			var hold_pos: Vector3 = u.hold_position
			if enemy != null and can_shoot_or_reach(u, enemy):
				engage_target(u, enemy)
			elif u_pos.distance_to(hold_pos) > 2.5:
				u._steer_toward(hold_pos, eff_speed)
			else:
				u_body.velocity.x = 0.0
				u_body.velocity.z = 0.0
		GameData.SquadOrder.GUARD_BASE:
			var base_enemy: Node = u._find_cached_enemy_near_point(camp, 28.0)
			if base_enemy == null:
				base_enemy = u._find_cached_wildlife_near_point(camp, 28.0)
			if base_enemy != null and (not is_ranged_unit or fire_will or u_pos.distance_to((base_enemy as Node3D).global_position) < 8.0):
				engage_target(u, base_enemy)
			elif GameState.current_phase == GameData.SchedulePhase.DAY_WORK and GameState.has_building(fid, "BARRACKS", true):
				u._train_at_barracks(delta)
			else:
				u._patrol_around(camp, 9.0, delta)
		GameData.SquadOrder.CHARGE:
			var charge_target: Node = enemy
			if charge_target == null:
				charge_target = u._find_nearest_enemy_unit(Layout.SCAN_RANGE_CHARGE)
			if charge_target != null and (not is_ranged_unit or fire_will or u_pos.distance_to((charge_target as Node3D).global_position) < 8.0):
				engage_target(u, charge_target)
			else:
				var b_target: Node = u._find_nearest_enemy_building(Layout.SCAN_RANGE_CHARGE)
				if b_target != null and (not is_ranged_unit or fire_will):
					engage_building(u, b_target)
				elif p_leader != null:
					u._follow_point((p_leader as Node3D).global_position, 4.5)
		_: # FOLLOW
			if enemy != null and (fire_will or u_pos.distance_to((enemy as Node3D).global_position) < 8.0):
				engage_target(u, enemy)
			elif p_leader != null:
				u._follow_point((p_leader as Node3D).global_position, 4.5)
			else:
				u._patrol_around(camp, 7.0, delta)


static func process_ai_warrior(u: Node, delta: float, enemy: Node) -> void:
	var camp: Vector3 = u._get_home_camp_pos()
	var u_pos: Vector3 = (u as Node3D).global_position
	var fid: int = int(u.faction_id)
	var eff_speed: float = float(u.move_speed) * float(u._buff_speed_mult)
	var leader: bool = (u.is_leader == true)

	# Tactical Low-HP retreat toward Campfire healing aura
	if not leader:
		var u_hp: float = float(u.hp)
		var u_max_hp: float = float(u.max_hp)
		if u_hp < u_max_hp * 0.22:
			u._retreating_to_heal = true
		elif u_hp >= u_max_hp * 0.45:
			u._retreating_to_heal = false
		if u._retreating_to_heal == true and u_pos.distance_to(camp) > 6.0:
			u.is_raiding = false
			u._steer_toward(camp, eff_speed * 1.15)
			return

	# Rival Leader Patron God Blessings in combat
	if leader and fid >= 1 and fid <= 4 and enemy != null and float(u._leader_blessing_cd) <= 0.0:
		if u_pos.distance_to((enemy as Node3D).global_position) <= 10.0:
			cast_rival_leader_blessing(u)

	if enemy != null:
		engage_target(u, enemy)
		return

	if u.is_raiding == true:
		var raid_pos: Vector3 = u.raid_target_pos
		if u_pos.distance_to(raid_pos) > 5.0:
			u._steer_toward(raid_pos, eff_speed)
		else:
			var b_target: Node = u._find_nearest_enemy_building(25.0)
			if b_target != null:
				engage_building(u, b_target)
			else:
				u.is_raiding = false
		return

	if not leader and GameState.current_phase == GameData.SchedulePhase.DAY_WORK and GameState.has_building(fid, "BARRACKS", true) and PerkSystem.can_idle_warriors_train(GameState.factions.get(fid, {})):
		u._train_at_barracks(delta)
		return

	u._patrol_around(camp, 9.5, delta)


static func cast_rival_leader_blessing(u: Node) -> void:
	u._leader_blessing_cd = 18.0
	BlessingEffects.trigger_leader_blessing(u, int(u.faction_id), false)


static func can_shoot_or_reach(u: Node, enemy: Node) -> bool:
	var d: float = (u as Node3D).global_position.distance_to((enemy as Node3D).global_position)
	var wdef: Dictionary = _unit_weapon_def(u)
	if bool(wdef.get("is_ranged", false)):
		return u.fire_at_will == true and d <= float(u.attack_range)
	return d <= 5.5


static func engage_target(u: Node, target: Node) -> void:
	var u_body := u as CharacterBody3D
	var u_pos: Vector3 = u_body.global_position
	var t_pos: Vector3 = (target as Node3D).global_position
	var d: float = u_pos.distance_to(t_pos)
	var eff_class: int = int(u._get_effective_warrior_class())
	var wdef: Dictionary = _unit_weapon_def(u)
	var proj_type: String = str(wdef.get("projectile_type", ""))
	var eff_speed: float = float(u.move_speed) * float(u._buff_speed_mult)
	var is_ranged_kiter: bool = bool(wdef.get("is_ranged", false)) and ((proj_type == "ARROW" and d < 6.0) or (proj_type == "JAVELIN" and d < 4.2))
	if is_ranged_kiter and float(u._attack_cd) > 0.15:
		# Ranged skirmisher/archer kites away from closing melee threats while keeping aim
		var away: Vector3 = u_pos - t_pos
		away.y = 0.0
		if away.length() > 0.1:
			var k_dir: Vector3 = away.normalized()
			u_body.velocity.x = k_dir.x * eff_speed * 0.80
			u_body.velocity.z = k_dir.z * eff_speed * 0.80
			u._kiting_this_frame = true
		u._face_point(t_pos)
		return

	var effective_range: float = float(u.attack_range) + (0.8 if target.get("is_boss") == true else 0.0)
	if d > effective_range:
		if eff_class == GameData.WarriorClass.KNIFE_RAIDER and d > effective_range * 1.4:
			var diff: Vector3 = t_pos - u_pos
			diff.y = 0.0
			if diff.length() > 0.2:
				var fwd: Vector3 = diff.normalized()
				var side: Vector3 = Vector3(-fwd.z, 0.0, fwd.x) * (0.45 if (int(u.unit_id) % 2 == 0) else -0.45)
				var flank_dir: Vector3 = (fwd + side).normalized()
				u_body.velocity.x = flank_dir.x * eff_speed
				u_body.velocity.z = flank_dir.z * eff_speed
		else:
			u._steer_toward(t_pos, eff_speed)
	else:
		u_body.velocity.x = 0.0
		u_body.velocity.z = 0.0
		u._face_point(t_pos)
		if float(u._attack_cd) <= 0.0:
			execute_attack_on(u, target)


static func engage_building(u: Node, b: Node) -> void:
	var u_body := u as CharacterBody3D
	var b_pos: Vector3 = (b as Node3D).global_position
	var d: float = u_body.global_position.distance_to(b_pos)
	var reach: float = maxf(float(u.attack_range), 3.0)
	var eff_class: int = int(u._get_effective_warrior_class())
	var wdef: Dictionary = _unit_weapon_def(u)
	var w_anim: String = str(wdef.get("attack_anim", ""))
	var is_ranged_atk: bool = bool(wdef.get("is_ranged", false))
	var proj_type: String = str(wdef.get("projectile_type", ""))
	if d > reach:
		u._steer_toward(b_pos, float(u.move_speed) * float(u._buff_speed_mult))
	else:
		u_body.velocity.x = 0.0
		u_body.velocity.z = 0.0
		u._face_point(b_pos)
		if float(u._attack_cd) <= 0.0:
			u._attack_cd = float(u.attack_cooldown_max)
			var anim_dur: float = 0.44 if (w_anim == "HEAVY_SMASH" or eff_class == GameData.WarriorClass.BRUTE) else 0.38
			u.play_attack_animation("", anim_dur)
			var dmg: float = float(u.attack_damage)
			var fid: int = int(u.faction_id)
			if eff_class == GameData.WarriorClass.BRUTE or w_anim == "HEAVY_SMASH":
				dmg *= 1.35
			if GameState.has_tenet(fid, "SACRED_CONQUEST"):
				dmg *= 1.18
			if is_ranged_atk and proj_type == "ARROW" and GameState.projectiles_container != null:
				fire_arrow_at(u, b_pos + Vector3(0.0, 1.2, 0.0), dmg)
			elif is_ranged_atk and proj_type == "JAVELIN" and GameState.projectiles_container != null:
				fire_javelin_at(u, b_pos + Vector3(0.0, 1.2, 0.0), dmg)
			else:
				b.take_damage(dmg, fid)


static func execute_attack_on(u: Node, target: Node) -> void:
	u._attack_cd = float(u.attack_cooldown_max)
	var eff_class: int = int(u._get_effective_warrior_class())
	var wdef: Dictionary = _unit_weapon_def(u)
	var w_anim: String = str(wdef.get("attack_anim", ""))
	var is_ranged_atk: bool = bool(wdef.get("is_ranged", false))
	var proj_type: String = str(wdef.get("projectile_type", ""))
	var anim_dur: float = 0.44 if (w_anim == "HEAVY_SMASH" or eff_class == GameData.WarriorClass.BRUTE) else (0.34 if (w_anim == "DUAL_SLASH" or eff_class == GameData.WarriorClass.KNIFE_RAIDER) else 0.40)
	u.play_attack_animation("", anim_dur)
	var dmg: float = float(u.attack_damage)
	var fid: int = int(u.faction_id)

	# Patron God & Tenet modifiers
	if GameState.factions.has(fid):
		var god: int = int(GameState.factions[fid].get("patron_god", GameData.PatronGod.NONE))
		if god == GameData.PatronGod.SOL_KAR and GameState.is_daytime():
			dmg *= 1.20
		if god == GameData.PatronGod.FEN_ROR and (eff_class == GameData.WarriorClass.KNIFE_RAIDER or eff_class == GameData.WarriorClass.ARCHER or proj_type == "ARROW" or str(wdef.get("id", "")) == "FLINT_DIRK"):
			if randf() < 0.22:
				dmg *= 1.65
		if GameState.has_tenet(fid, "SACRED_CONQUEST") and target.get("faction_id") != null:
			dmg *= 1.18

	var u3d := u as Node3D
	var t_pos: Vector3 = (target as Node3D).global_position
	if is_ranged_atk and proj_type == "ARROW" and GameState.projectiles_container != null:
		fire_arrow_at(u, t_pos + Vector3(0.0, 1.0, 0.0), dmg)
	elif is_ranged_atk and proj_type == "JAVELIN" and GameState.projectiles_container != null and u3d.global_position.distance_to(t_pos) > 3.2:
		fire_javelin_at(u, t_pos + Vector3(0.0, 1.0, 0.0), dmg)
	else:
		var arc_scale: float = 1.25 if (w_anim == "HEAVY_SMASH" or eff_class == GameData.WarriorClass.BRUTE or u.is_leader == true) else 0.95
		CombatVFX.spawn_slash_arc(
			GameState.world_node if GameState.world_node != null else u,
			u3d.global_position,
			-u3d.global_transform.basis.z,
			Color(1.0, 0.52, 0.25, 0.85) if fid != 0 else Color(0.95, 0.90, 0.55, 0.85),
			arc_scale
		)
		target.take_damage(dmg, u, fid)
	if GameState.factions.has(fid) and PerkSystem.has_battle_veterans(GameState.factions[fid]):
		u._gain_training_xp(2.5)


static func fire_arrow_at(u: Node, aim_pos: Vector3, dmg: float) -> void:
	Projectile3D.spawn(u, int(u.faction_id), (u as Node3D).global_position + Vector3(0.0, 1.35, 0.0), aim_pos, dmg, 26.0, "ARROW", int(u.weapon_tier), false)


static func fire_javelin_at(u: Node, aim_pos: Vector3, dmg: float) -> void:
	Projectile3D.spawn(u, int(u.faction_id), (u as Node3D).global_position + Vector3(0.0, 1.45, 0.0), aim_pos, dmg, 29.0, "JAVELIN", int(u.weapon_tier), false)


static func engage_unarmed_self_defense(u: Node, target: Node) -> void:
	if not is_instance_valid(target) or not (target is CharacterBody3D) or target.get("is_dead") == true or target.get("is_wounded") == true:
		return
	var u_body := u as CharacterBody3D
	var t_pos: Vector3 = (target as Node3D).global_position
	var d: float = u_body.global_position.distance_to(t_pos)
	var reach := 1.65
	if d > reach:
		u._steer_toward(t_pos, float(u.move_speed) * 0.95)
	else:
		u_body.velocity.x = 0.0
		u_body.velocity.z = 0.0
		u._face_point(t_pos)
		if float(u._attack_cd) <= 0.0:
			var eff_lin: int = GameData.resolve_effective_lineage(int(u.lineage), u.is_caveman == true)
			var lin_data: Dictionary = GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN])
			var atk_spd: float = float(lin_data.get("attack_speed_mult", 1.0))
			u._attack_cd = 1.15 / atk_spd
			u._unarmed_punch_vis_timer = 0.36
			u._set_hand_mounts_visible(false)
			u.play_attack_animation("UNARMED_PUNCH", 0.36)
			target.take_damage(float(u.unarmed_attack_damage), u, int(u.faction_id))

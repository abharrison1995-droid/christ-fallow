extends RefCounted
## Stateless calculations for an explicitly supplied unit and patron.

const PerkSystem = preload("res://scripts/core/perk_system.gd")


static func derive(input: Dictionary, patron: int, faction: Dictionary = {}) -> Dictionary:
	var lineage: int = input["lineage"]
	var is_caveman: bool = input["is_caveman"]
	var role: int = input["role"]
	var warrior_class: int = input["warrior_class"]
	var is_leader: bool = input["is_leader"]
	var is_child: bool = input["is_child"]
	var base_hp_stat: float = input["base_hp_stat"]
	var base_melee_stat: float = input["base_melee_stat"]
	var base_ranged_stat: float = input["base_ranged_stat"]
	var melee_rank: int = input["melee_rank"]
	var ranged_rank: int = input["ranged_rank"]
	var weapon_tier: int = input["weapon_tier"]
	var has_equipped_weapon: bool = input["has_equipped_weapon"]
	var has_armor: bool = input["has_armor"]
	var equipped_weapon_id: String = str(input.get("equipped_weapon_id", ""))
	var equipped_armor_id: String = str(input.get("equipped_armor_id", ""))
	var has_weapon_def: bool = equipped_weapon_id != "" and GameData.WEAPON_DEFS.has(equipped_weapon_id)
	var wdef: Dictionary = GameData.WEAPON_DEFS[equipped_weapon_id] if has_weapon_def else {}
	var has_armor_def: bool = equipped_armor_id != "" and GameData.ARMOR_DEFS.has(equipped_armor_id)
	var adef: Dictionary = GameData.ARMOR_DEFS[equipped_armor_id] if has_armor_def else {}
	var default_weapon_id: String = GameData.resolve_default_weapon_id(role, warrior_class, is_leader, is_caveman)
	var is_custom_weapon: bool = has_weapon_def and equipped_weapon_id != default_weapon_id
	var effective_has_weapon: bool = has_equipped_weapon or has_weapon_def

	var eff_lin := GameData.resolve_effective_lineage(lineage, is_caveman)
	var l_data: Dictionary = GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN])
	var role_hp_mult := 1.0
	if is_leader:
		role_hp_mult = 2.15
	elif role == GameData.Role.WARRIOR:
		role_hp_mult = 1.38 if warrior_class == GameData.WarriorClass.BRUTE else 1.25
	elif is_caveman:
		role_hp_mult = 1.15

	var armor_hp_bonus: float = float(adef.get("hp_bonus", 0.0)) if has_armor_def else 0.0
	var max_hp := base_hp_stat * role_hp_mult * float(l_data["hp_mult"]) + float(melee_rank) * 10.0
	if is_child:
		max_hp *= 0.60
	max_hp *= PerkSystem.get_unit_hp_mult(faction, is_leader)
	max_hp += armor_hp_bonus

	var move_speed := 5.8 * float(l_data["speed_mult"])
	if role == GameData.Role.WARRIOR:
		if warrior_class == GameData.WarriorClass.KNIFE_RAIDER:
			move_speed *= 1.15
		elif warrior_class == GameData.WarriorClass.JAVELINEER:
			move_speed *= 1.08
		elif warrior_class == GameData.WarriorClass.BRUTE:
			move_speed *= 0.94
	if is_leader:
		move_speed *= 1.12
	move_speed *= PerkSystem.get_move_speed_mult(faction)
	if has_armor_def:
		move_speed *= float(adef.get("move_mult", 1.0))

	var tier_bonus := 1.0 + float(weapon_tier - 1) * 0.28
	var role_dmg_mult := 1.0
	if is_leader:
		role_dmg_mult = 1.65
	elif role == GameData.Role.WARRIOR or is_caveman:
		role_dmg_mult = 1.25 if effective_has_weapon else 1.0

	var perk_dmg_mult: float = PerkSystem.get_unit_damage_mult(faction, is_leader, role == GameData.Role.WARRIOR)
	var close_quarters_damage := base_melee_stat * role_dmg_mult * tier_bonus * float(l_data["melee_mult"]) * (1.0 + float(melee_rank) * 0.10) * perk_dmg_mult
	var ranged_attack_damage := base_ranged_stat * role_dmg_mult * tier_bonus * float(l_data["ranged_mult"]) * (1.0 + float(ranged_rank) * 0.10) * perk_dmg_mult
	var unarmed_attack_damage := clampf(base_melee_stat * 0.36 * float(l_data["melee_mult"]), 3.0, 7.5)
	if is_child:
		unarmed_attack_damage *= 0.50

	var attack_damage: float
	var attack_range: float
	var attack_cooldown_max: float
	var is_ranged: bool = false
	var projectile_type: String = ""
	if warrior_class == GameData.WarriorClass.ARCHER and (role == GameData.Role.WARRIOR or is_leader):
		attack_damage = ranged_attack_damage
		attack_range = 17.5 * (1.28 if lineage == GameData.Lineage.STALKER else 1.0)
		attack_cooldown_max = 1.25 / float(l_data["attack_speed_mult"])
		is_ranged = true
		projectile_type = "ARROW"
	elif warrior_class == GameData.WarriorClass.JAVELINEER and (role == GameData.Role.WARRIOR or is_leader):
		attack_damage = ranged_attack_damage * 0.72 + close_quarters_damage * 0.42
		attack_range = 11.5 * (1.15 if lineage == GameData.Lineage.STALKER else 1.0)
		attack_cooldown_max = 1.30 / float(l_data["attack_speed_mult"])
		is_ranged = true
		projectile_type = "JAVELIN"
	elif warrior_class == GameData.WarriorClass.BRUTE and (role == GameData.Role.WARRIOR or is_caveman):
		attack_damage = close_quarters_damage * 1.38
		attack_range = 2.45
		attack_cooldown_max = 1.32 / float(l_data["attack_speed_mult"])
	elif warrior_class == GameData.WarriorClass.KNIFE_RAIDER and (role == GameData.Role.WARRIOR or is_leader):
		attack_damage = close_quarters_damage * 0.92
		attack_range = 1.9
		attack_cooldown_max = 0.65 / float(l_data["attack_speed_mult"])
	else:
		# Spearman or default
		attack_damage = close_quarters_damage * 1.12
		attack_range = 2.75
		attack_cooldown_max = 1.02 / float(l_data["attack_speed_mult"])

	var armor := float(l_data["armor_bonus"])
	if has_armor_def:
		if equipped_armor_id == "BONE_GUARD":
			armor += float(adef.get("armor_bonus", 8.0)) + float(maxi(0, weapon_tier - 1)) * 4.0
		else:
			armor += float(adef.get("armor_bonus", 0.0))
	elif has_armor:
		armor += 8.0 + float(weapon_tier - 1) * 4.0
	if warrior_class == GameData.WarriorClass.SPEARMAN and role == GameData.Role.WARRIOR:
		armor += 3.0
	armor += PerkSystem.get_unit_armor_bonus(faction, is_leader, role == GameData.Role.WARRIOR)

	if is_custom_weapon:
		var w_is_ranged: bool = bool(wdef.get("is_ranged", false))
		var w_proj: String = str(wdef.get("projectile_type", ""))
		var w_dmg_mult: float = float(wdef.get("dmg_mult", 1.0))
		var class_was_ranged: bool = (warrior_class == GameData.WarriorClass.ARCHER or warrior_class == GameData.WarriorClass.JAVELINEER) and (role == GameData.Role.WARRIOR or is_leader)
		if w_is_ranged and not class_was_ranged:
			if w_proj == "JAVELIN":
				attack_damage = (ranged_attack_damage * 0.72 + close_quarters_damage * 0.42) * w_dmg_mult
			else:
				attack_damage = ranged_attack_damage * w_dmg_mult
		elif not w_is_ranged and class_was_ranged:
			attack_damage = close_quarters_damage * 1.12 * w_dmg_mult
		else:
			attack_damage *= w_dmg_mult
		var w_range: float = float(wdef.get("range_override", 0.0))
		if w_range > 0.0:
			attack_range = w_range
			if w_proj == "ARROW" and lineage == GameData.Lineage.STALKER:
				attack_range *= 1.28
			elif w_proj == "JAVELIN" and lineage == GameData.Lineage.STALKER:
				attack_range *= 1.15
		attack_cooldown_max *= float(wdef.get("cooldown_mult", 1.0))
		move_speed *= float(wdef.get("move_mult", 1.0))
		armor += float(wdef.get("armor_bonus", 0.0))
		is_ranged = w_is_ranged
		projectile_type = w_proj

	if input.get("archetype", "") == GameData.FLINTMASK_SCOUT:
		max_hp = GameData.FLINTMASK_STATS["hp"]
		move_speed = GameData.FLINTMASK_STATS["speed"]
		attack_damage = GameData.FLINTMASK_STATS["damage"]
		attack_range = GameData.FLINTMASK_STATS["reach"]
		attack_cooldown_max = GameData.FLINTMASK_STATS["cooldown"]
		armor = GameData.FLINTMASK_STATS["armor"]
		is_ranged = false
		projectile_type = ""

	if patron == GameData.PatronGod.FEN_ROR:
		move_speed *= 1.20
	elif patron == GameData.PatronGod.VALK_TOR and (warrior_class == GameData.WarriorClass.SPEARMAN or warrior_class == GameData.WarriorClass.JAVELINEER):
		attack_damage *= 1.25
	elif patron == GameData.PatronGod.KRAG_UL:
		armor += 6.0

	var is_arena_champion: bool = bool(input.get("is_arena_champion", false))
	if is_arena_champion and not is_child and not is_caveman:
		max_hp += 15.0
		close_quarters_damage *= 1.10
		ranged_attack_damage *= 1.10
		attack_damage *= 1.10

	return {
		"max_hp": max_hp,
		"move_speed": move_speed,
		"close_quarters_damage": close_quarters_damage,
		"ranged_attack_damage": ranged_attack_damage,
		"unarmed_attack_damage": unarmed_attack_damage,
		"attack_damage": attack_damage,
		"attack_range": attack_range,
		"attack_cooldown_max": attack_cooldown_max,
		"armor": armor,
		"is_ranged": is_ranged,
		"projectile_type": projectile_type,
	}


static func mitigated_damage(raw: float, armor: float) -> float:
	return maxf(2.0, raw - armor * 0.45)

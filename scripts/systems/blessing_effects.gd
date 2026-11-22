extends RefCounted
## Shared Patron God blessing and area-of-effect combat helpers for leaders.

const PerkSystem = preload("res://scripts/core/perk_system.gd")


static func trigger_leader_blessing(caster: Node, faction_id: int, hit_wildlife: bool = false) -> void:
	if caster == null or not is_instance_valid(caster) or not GameState.factions.has(faction_id):
		return
	var faction_dict: Dictionary = GameState.factions[faction_id]
	var power_mult: float = PerkSystem.get_blessing_power_mult(faction_dict)
	var god: int = int(faction_dict.get("patron_god", GameData.PatronGod.NONE))
	var god_info: Dictionary = GameData.GOD_DATA.get(god, GameData.GOD_DATA[GameData.PatronGod.NONE])
	var is_player: bool = (faction_id == 0)
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null and caster is Node3D:
		sm.play_sfx_3d("blessing_cast", (caster as Node3D).global_position, 0.05, 0.0)

	match god:
		GameData.PatronGod.SOL_KAR:
			aoe_damage(caster, faction_id, 10.0, (35.0 if is_player else 28.0) * power_mult, 99, hit_wildlife)
			aoe_heal(caster, faction_id, 10.0, 25.0 * power_mult)
		GameData.PatronGod.GAIA_MAR:
			aoe_heal(caster, faction_id, 12.0, (45.0 if is_player else 40.0) * power_mult)
			if is_player:
				GameState.add_resource(faction_id, "food", 15.0)
		GameData.PatronGod.FEN_ROR:
			_apply_allied_buff(caster, faction_id, 14.0, 10.0, 1.40 if is_player else 1.35, 0.0, 0.0)
		GameData.PatronGod.VALK_TOR:
			aoe_damage(caster, faction_id, 14.0 if is_player else 12.0, (42.0 if is_player else 34.0) * power_mult, 5 if is_player else 4, hit_wildlife)
		GameData.PatronGod.KRAG_UL:
			_apply_allied_buff(caster, faction_id, 14.0, 10.0, 1.0, 18.0, 15.0 * power_mult)
		_:
			if is_player:
				_apply_allied_buff(caster, faction_id, 12.0, 8.0, 1.20, 0.0, 15.0 * power_mult)
			else:
				caster.heal(20.0 * power_mult)

	if is_player:
		GameState.push_log("Invoked %s (%s)!" % [god_info["blessing_name"], god_info["name"]], "success")
	else:
		var p_leader: Node = GameState.get_faction_leader(0)
		if p_leader != null and (caster as Node3D).global_position.distance_to((p_leader as Node3D).global_position) <= 45.0:
			GameState.push_log("%s invoked %s (%s)!" % [str(caster.get("unit_name")), god_info["blessing_name"], god_info["name"]], "warning")


static func _apply_allied_buff(caster: Node, faction_id: int, radius: float, duration: float, speed_mult: float, armor_bonus: float, heal_amount: float) -> void:
	var c_pos: Vector3 = (caster as Node3D).global_position
	for u in GameState.get_faction_units(faction_id, true):
		if c_pos.distance_to((u as Node3D).global_position) <= radius:
			u.apply_temporary_buff(duration, speed_mult, armor_bonus)
			if heal_amount > 0.0:
				u.heal(heal_amount)


static func aoe_damage(caster: Node, faction_id: int, radius: float, dmg: float, max_targets: int = 99, include_wildlife: bool = false) -> void:
	var c_pos: Vector3 = (caster as Node3D).global_position
	var radius_sq := radius * radius
	var candidates: Array[Dictionary] = []
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if is_instance_valid(u) and u.get("is_dead") != true and u.get("is_wounded") != true and GameState.is_hostile(faction_id, int(u.get("faction_id"))):
				var d_sq: float = c_pos.distance_squared_to((u as Node3D).global_position)
				if d_sq <= radius_sq:
					candidates.append({"node": u, "dist_sq": d_sq})
	if include_wildlife and GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if is_instance_valid(w) and w.get("is_dead") != true and not w.is_protected_from(faction_id):
				var d_sq: float = c_pos.distance_squared_to((w as Node3D).global_position)
				if d_sq <= radius_sq:
					candidates.append({"node": w, "dist_sq": d_sq})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist_sq"]) < float(b["dist_sq"])
	)
	var limit: int = mini(candidates.size(), max_targets)
	for i in range(limit):
		var target: Node = candidates[i]["node"]
		if is_instance_valid(target) and target.get("is_dead") != true:
			target.take_damage(dmg, caster, faction_id)


static func aoe_heal(caster: Node, faction_id: int, radius: float, amount: float) -> void:
	var c_pos: Vector3 = (caster as Node3D).global_position
	for u in GameState.get_faction_units(faction_id, true):
		if c_pos.distance_to((u as Node3D).global_position) <= radius:
			u.heal(amount)

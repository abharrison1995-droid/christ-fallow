extends RefCounted
## Shared Patron God blessing and area-of-effect combat helpers for leaders.


static func trigger_leader_blessing(caster: Node, faction_id: int, hit_wildlife: bool = false) -> void:
	if caster == null or not is_instance_valid(caster) or not GameState.factions.has(faction_id):
		return
	var god: int = int(GameState.factions[faction_id].get("patron_god", GameData.PatronGod.NONE))
	var god_info: Dictionary = GameData.GOD_DATA.get(god, GameData.GOD_DATA[GameData.PatronGod.NONE])
	var is_player: bool = (faction_id == 0)

	match god:
		GameData.PatronGod.SOL_KAR:
			aoe_damage(caster, faction_id, 10.0, 35.0 if is_player else 28.0, 99, hit_wildlife)
			aoe_heal(caster, faction_id, 10.0, 25.0)
		GameData.PatronGod.GAIA_MAR:
			aoe_heal(caster, faction_id, 12.0, 45.0 if is_player else 40.0)
			if is_player:
				GameState.add_resource(faction_id, "food", 15.0)
		GameData.PatronGod.FEN_ROR:
			_apply_allied_buff(caster, faction_id, 14.0, 10.0, 1.40 if is_player else 1.35, 0.0, 0.0)
		GameData.PatronGod.VALK_TOR:
			aoe_damage(caster, faction_id, 14.0 if is_player else 12.0, 42.0 if is_player else 34.0, 5 if is_player else 4, hit_wildlife)
		GameData.PatronGod.KRAG_UL:
			_apply_allied_buff(caster, faction_id, 14.0, 10.0, 1.0, 18.0, 15.0)
		_:
			if is_player:
				_apply_allied_buff(caster, faction_id, 12.0, 8.0, 1.20, 0.0, 15.0)
			else:
				caster.heal(20.0)

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
	var hits: int = 0
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if hits >= max_targets:
				break
			if is_instance_valid(u) and not u.get("is_dead") and GameState.is_hostile(faction_id, int(u.get("faction_id"))):
				if c_pos.distance_to((u as Node3D).global_position) <= radius:
					u.take_damage(dmg, caster, faction_id)
					hits += 1
	if include_wildlife and GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if hits >= max_targets:
				break
			if is_instance_valid(w) and not w.get("is_dead") and c_pos.distance_to((w as Node3D).global_position) <= radius:
				w.take_damage(dmg, caster, faction_id)
				hits += 1


static func aoe_heal(caster: Node, faction_id: int, radius: float, amount: float) -> void:
	var c_pos: Vector3 = (caster as Node3D).global_position
	for u in GameState.get_faction_units(faction_id, true):
		if c_pos.distance_to((u as Node3D).global_position) <= radius:
			u.heal(amount)

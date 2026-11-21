extends RefCounted
## Civilian work routines, Barracks training, and spatial target queries for tribesfolk.
## Target queries read GameState.spatial_index and fall back to container scans while it is empty.

const Layout = preload("res://scripts/core/world_layout.gd")


static func _units_near(point: Vector3, radius: float) -> Array:
	if GameState.spatial_index.is_populated():
		return GameState.spatial_index.query_units_in_radius(point, radius)
	if GameState.units_container == null:
		return []
	return GameState.units_container.get_children()


static func _wildlife_near(point: Vector3, radius: float) -> Array:
	if GameState.spatial_index.is_populated():
		return GameState.spatial_index.query_wildlife_in_radius(point, radius)
	if GameState.wildlife_container == null:
		return []
	return GameState.wildlife_container.get_children()


static func _buildings_near(point: Vector3, radius: float) -> Array:
	if GameState.spatial_index.is_populated():
		return GameState.spatial_index.query_buildings_in_radius(point, radius)
	if GameState.buildings_container == null:
		return []
	return GameState.buildings_container.get_children()


static func run_dusk_routine(u, _delta: float) -> void:
	var camp: Vector3 = u._get_home_camp_pos()
	if u.global_position.distance_to(camp) > 5.5:
		u._steer_toward(camp, u.move_speed)
		return
	u.velocity.x = 0.0
	u.velocity.z = 0.0
	if u._dusk_eaten_today != GameState.day_count:
		u._dusk_eaten_today = GameState.day_count
		if GameState.spend_resources(u.faction_id, {"food": 1}):
			u.heal(15.0)
			u.modify_morale(12.0)
		else:
			u.modify_morale(-22.0)
			if u.faction_id == 0:
				GameState.push_log("STARVATION: %s had no food at Dusk (-22 Morale)!" % u.unit_name, "warning")


static func run_night_routine(u, _delta: float) -> void:
	var huts: Array = GameState.get_faction_buildings(u.faction_id, "SLEEPING_HUT", true)
	var rest_pos: Vector3 = u._get_home_camp_pos()
	if not huts.is_empty():
		rest_pos = (huts[u.unit_id % huts.size()] as Node3D).global_position
	if u.global_position.distance_to(rest_pos) > 2.8:
		u._steer_toward(rest_pos, u.move_speed * 0.9)
		return
	u.velocity.x = 0.0
	u.velocity.z = 0.0
	if u._night_morale_today != GameState.day_count:
		u._night_morale_today = GameState.day_count
		if GameState.get_faction_units(u.faction_id, true).size() <= GameState.get_housing_capacity(u.faction_id):
			u.modify_morale(8.0)
		else:
			u.modify_morale(-12.0)
			if u.faction_id == 0:
				GameState.push_log("OVERCROWDING: %s had no Sleeping Hut bed (-12 Morale)." % u.unit_name, "warning")


static func run_day_work_routine(u, delta: float) -> void:
	var camp: Vector3 = u._get_home_camp_pos()

	if u._carry_amount > 0.0:
		var drop_pos: Vector3 = get_nearest_dropoff_pos(u)
		if u.global_position.distance_to(drop_pos) > 3.2:
			u._steer_toward(drop_pos, u.move_speed)
		else:
			GameState.add_resource(u.faction_id, u._carry_type, u._carry_amount)
			u._carry_amount = 0.0
			u._carry_type = ""
			if u.role == GameData.Role.STONEKNAPPER:
				u._target_node = null
		return

	if u.role == GameData.Role.BUILDER_CRAFTER and _try_builder_crafter_work(u, delta):
		return
	if u.role == GameData.Role.TRAINEE:
		run_train_at_barracks(u, delta)
		return
	if u.role == GameData.Role.SHAMAN:
		_run_shaman_work(u, camp, delta)
		return
	if u.role == GameData.Role.HUNTER and _try_hunter_work(u):
		return
	if u.role == GameData.Role.FARMER and _try_crop_work(u, delta):
		return

	_run_gatherer_work(u, camp, delta)


static func _nearest_building(origin: Vector3, buildings: Array) -> Node3D:
	var best: Node3D = null
	var best_d := 999999999.0
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var b3d := b as Node3D
		if b3d == null:
			continue
		var d := origin.distance_squared_to(b3d.global_position)
		if d < best_d:
			best_d = d
			best = b3d
	return best


static func _try_crop_work(u, delta: float) -> bool:
	var field: Node = null
	var nearest := Layout.SCAN_RANGE_BLUEPRINT
	for building in GameState.get_faction_buildings(u.faction_id, "CROP_FIELD", true):
		var d: float = u.global_position.distance_to(building.global_position)
		if d < nearest and building.crop_needs_work():
			field = building
			nearest = d
	if field == null:
		return false
	if nearest > 2.7:
		u._steer_toward(field.global_position, u.move_speed)
	else:
		u.velocity.x = 0.0
		u.velocity.z = 0.0
		u._is_working_this_frame = true
		u._face_point(field.global_position)
		var harvest: float = field.work_crop(delta)
		if harvest > 0.0:
			u._carry_type = "food"
			u._carry_amount = harvest
	return true


static func _try_builder_crafter_work(u, delta: float) -> bool:
	var bp: Node = find_nearest_blueprint(u)
	if bp != null:
		u._active_craft_item = ""
		var bp_pos: Vector3 = (bp as Node3D).global_position
		if u.global_position.distance_to(bp_pos) > 3.2:
			u._steer_toward(bp_pos, u.move_speed)
		else:
			u.velocity.x = 0.0
			u.velocity.z = 0.0
			u._face_point(bp_pos)
			u._is_working_this_frame = true
			var build_spd := float(GameData.LINEAGE_DATA[u.lineage]["gather_mult"])
			bp.advance_construction(delta * build_spd)
		return true

	var pits: Array = GameState.get_faction_buildings(u.faction_id, "CRAFTING_PIT", true)
	if not pits.is_empty() and GameState.factions.has(u.faction_id) and not GameState.factions[u.faction_id]["craft_queue"].is_empty():
		var pit := _nearest_building((u as Node3D).global_position, pits)
		if pit == null:
			return false
		var pit_pos: Vector3 = pit.global_position
		if u.global_position.distance_to(pit_pos) > 3.0:
			u._steer_toward(pit_pos, u.move_speed)
		else:
			u.velocity.x = 0.0
			u.velocity.z = 0.0
			u._face_point(pit_pos)
			u._is_working_this_frame = true
			var queue: Array = GameState.factions[u.faction_id]["craft_queue"]
			var current_item: String = str(queue[0])
			if u._active_craft_item != current_item:
				u._active_craft_item = current_item
				u._work_timer = 0.0
			var recipe: Dictionary = GameData.CRAFT_RECIPES.get(current_item, {})
			var craft_time: float = float(recipe.get("craft_time", 3.2))
			u._work_timer += delta
			if u._work_timer >= craft_time:
				u._work_timer = 0.0
				u._active_craft_item = ""
				var item_key: String = str(queue.pop_front())
				GameState.factions[u.faction_id]["stockpile"][item_key] = int(GameState.factions[u.faction_id]["stockpile"].get(item_key, 0)) + 1
				if u.faction_id == 0:
					GameState.resources_changed.emit(0)
					GameState.push_log("Crafted 1x %s into Weapon Rack stockpile!" % item_key.capitalize(), "success")
		return true
	if u._active_craft_item != "":
		u._active_craft_item = ""
		u._work_timer = 0.0
	return false


static func _run_shaman_work(u, camp: Vector3, delta: float) -> void:
	var shacks: Array = GameState.get_faction_buildings(u.faction_id, "SHAMAN_SHACK", true)
	if not shacks.is_empty():
		var wounded: Node = find_wounded_ally(u)
		if wounded != null:
			wounded.claim_rescue(u, 1.5)
			var w_pos: Vector3 = (wounded as Node3D).global_position
			if u.global_position.distance_to(w_pos) > 2.6:
				u._steer_toward(w_pos, u.move_speed * 1.1)
			else:
				var shack := _nearest_building(w_pos, shacks)
				if shack != null:
					wounded.send_to_shaman_shack(shack.global_position)
					GameState.push_log("Shaman %s brought wounded %s to the Shaman Shack!" % [u.unit_name, wounded.unit_name], "success")
			return

	var totems: Array = GameState.get_faction_buildings(u.faction_id, "SACRED_TOTEM", true)
	var nearest_totem := _nearest_building((u as Node3D).global_position, totems)
	var pray_pos: Vector3 = nearest_totem.global_position if nearest_totem != null else camp
	if u.global_position.distance_to(pray_pos) > 3.5:
		u._steer_toward(pray_pos, u.move_speed)
		return
	u.velocity.x = 0.0
	u.velocity.z = 0.0
	u._face_point(pray_pos)
	u._is_working_this_frame = true
	u._work_timer += delta
	if u._work_timer >= 4.0:
		u._work_timer = 0.0
		var faith_gain := 2.5 if not totems.is_empty() else 1.0
		if GameState.has_tenet(u.faction_id, "PEACEFUL_OFFERING"):
			faith_gain *= 1.30
		GameState.add_resource(u.faction_id, "faith", faith_gain)
		u.modify_morale(3.0)


static func _try_hunter_work(u) -> bool:
	var prey: Node = find_nearest_prey(u, 48.0)
	if prey == null:
		return false
	var prey_pos: Vector3 = (prey as Node3D).global_position
	if u.global_position.distance_to(prey_pos) > 11.0:
		u._steer_toward(prey_pos, u.move_speed)
		return true
	u.velocity.x = 0.0
	u.velocity.z = 0.0
	u._face_point(prey_pos)
	if u._attack_cd <= 0.0:
		u._attack_cd = 1.1
		u.play_attack_animation("BOW_SHOT", 0.42)
		u._fire_arrow_at(prey_pos + Vector3(0.0, 0.7, 0.0), float(u.ranged_attack_damage))
	return true


static func _run_gatherer_work(u, camp: Vector3, delta: float) -> void:
	var desired_node_types := ["BERRY_BUSH"]
	var res_out := "food"
	if u.role == GameData.Role.LUMBERJACK:
		desired_node_types = ["TREE"]
		res_out = "wood"
	elif u.role == GameData.Role.STONEKNAPPER:
		desired_node_types = ["FLINT", "STONE"]
		res_out = "stone"

	if u._target_node == null or not is_instance_valid(u._target_node):
		if u.role == GameData.Role.STONEKNAPPER:
			var prefer_flint := false
			if GameState.factions.has(u.faction_id):
				var res: Dictionary = GameState.factions[u.faction_id]["resources"]
				var stone_amt := float(res.get("stone", 0.0))
				var flint_amt := float(res.get("flint", 0.0))
				if is_equal_approx(flint_amt, stone_amt):
					prefer_flint = (int(u.unit_id) % 2 == 0)
				else:
					prefer_flint = flint_amt < stone_amt
			var primary_type: String = "FLINT" if prefer_flint else "STONE"
			var fallback_type: String = "STONE" if prefer_flint else "FLINT"
			u._target_node = find_nearest_resource_node([primary_type], camp, Layout.SCAN_RANGE_GATHER)
			if u._target_node == null:
				u._target_node = find_nearest_resource_node([fallback_type], camp, Layout.SCAN_RANGE_GATHER)
		else:
			u._target_node = find_nearest_resource_node(desired_node_types, camp, Layout.SCAN_RANGE_GATHER)

	if u._target_node == null:
		u._patrol_around(camp, 7.5, delta)
		return

	var n_pos: Vector3 = (u._target_node as Node3D).global_position
	if u.global_position.distance_to(n_pos) > 2.6:
		u._steer_toward(n_pos, u.move_speed)
		return

	u.velocity.x = 0.0
	u.velocity.z = 0.0
	u._face_point(n_pos)
	u._is_working_this_frame = true
	var gather_spd := float(GameData.LINEAGE_DATA[u.lineage]["gather_mult"])
	u._work_timer += delta * gather_spd
	if u._work_timer >= 3.2:
		u._work_timer = 0.0
		var ntype: String = u._target_node.get_meta("node_type", "BERRY_BUSH")
		if ntype == "FLINT":
			res_out = "flint"
		elif ntype == "STONE":
			res_out = "stone"
		var base_yield := 5.0
		if res_out == "food" and GameState.has_building(u.faction_id, "FORAGER_LODGE", true):
			base_yield *= 1.25
		if res_out == "food" and GameState.factions[u.faction_id].get("patron_god") == GameData.PatronGod.GAIA_MAR:
			base_yield *= 1.25
		if (res_out == "stone" or res_out == "flint") and GameState.factions[u.faction_id].get("patron_god") == GameData.PatronGod.KRAG_UL:
			base_yield *= 1.20
		u._carry_type = res_out
		u._carry_amount = base_yield


static func run_train_at_barracks(u, delta: float) -> void:
	var barracks: Array = GameState.get_faction_buildings(u.faction_id, "BARRACKS", true)
	var nearest_b := _nearest_building((u as Node3D).global_position, barracks)
	if nearest_b == null:
		u._patrol_around(u._get_home_camp_pos(), 7.0, delta)
		return
	var b_pos: Vector3 = nearest_b.global_position
	if u.global_position.distance_to(b_pos) > 3.4:
		u._steer_toward(b_pos, u.move_speed)
		return
	u.velocity.x = 0.0
	u.velocity.z = 0.0
	u._face_point(b_pos)
	u._is_working_this_frame = true
	u._work_timer += delta
	if u._work_timer >= 3.5:
		u._work_timer = 0.0
		gain_training_xp(u, 4.0)


static func gain_training_xp(u, xp_gain: float) -> void:
	if u.melee_rank >= 5 and u.ranged_rank >= 5:
		return
	u.training_xp += xp_gain
	if u.training_xp >= 20.0:
		u.training_xp -= 20.0
		var ranked_up := false
		if u.warrior_class == GameData.WarriorClass.ARCHER and u.ranged_rank < 5:
			u.ranged_rank += 1
			ranked_up = true
		elif u.melee_rank < 5:
			u.melee_rank += 1
			ranked_up = true
		elif u.ranged_rank < 5:
			u.ranged_rank += 1
			ranked_up = true
		if ranked_up:
			u.recalculate_stats(false)
			if u.faction_id == 0:
				GameState.push_log("%s trained at the Barracks! (CQ Rank %d, Ranged Rank %d)" % [u.unit_name, u.melee_rank, u.ranged_rank], "success")


static func find_wounded_ally(u) -> Node:
	var best: Node = null
	var best_d := Layout.SCAN_RANGE_WOUNDED
	for other in _units_near((u as Node3D).global_position, Layout.SCAN_RANGE_WOUNDED):
		if is_instance_valid(other) and not other.get("is_dead") and other.get("is_wounded") and not other.get("is_healing_in_shack"):
			if int(other.get("original_faction_id")) == u.faction_id:
				var claimer: Variant = other.get("_rescue_shaman")
				if other.get("being_rescued") == true and claimer != null and claimer != u and is_instance_valid(claimer):
					continue
				var d: float = (u as Node3D).global_position.distance_to((other as Node3D).global_position)
				if d < best_d:
					best_d = d
					best = other
	return best


static func get_nearest_dropoff_pos(u) -> Vector3:
	var best_pos: Vector3 = u._get_home_camp_pos()
	var best_d: float = (u as Node3D).global_position.distance_to(best_pos)
	for b in GameState.get_faction_buildings(u.faction_id, "", true):
		var bt: String = str(b.get("building_type"))
		if bt == "CAMPFIRE" or bt == "STORAGE_PIT" or bt == "FORAGER_LODGE":
			var bp: Vector3 = (b as Node3D).global_position
			var d: float = (u as Node3D).global_position.distance_to(bp)
			if d < best_d:
				best_d = d
				best_pos = bp
	return best_pos


static func find_nearest_blueprint(u) -> Node:
	var best: Node = null
	var best_d := Layout.SCAN_RANGE_BLUEPRINT
	for b in GameState.get_faction_buildings(u.faction_id, "", false):
		if not b.get("is_constructed"):
			var d: float = (u as Node3D).global_position.distance_to((b as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = b
	return best


static func find_nearest_resource_node(types: Array, around: Vector3, max_dist: float) -> Node:
	if GameState.resources_container == null:
		return null
	var best: Node = null
	var best_d := max_dist
	for n in GameState.resources_container.get_children():
		if not is_instance_valid(n):
			continue
		var nt: String = n.get_meta("node_type", "")
		if types.has(nt):
			var d: float = around.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


static func find_nearest_prey(u, max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for w in _wildlife_near((u as Node3D).global_position, max_dist):
		if not is_instance_valid(w) or w.get("is_dead"):
			continue
		var at: String = str(w.get("animal_type"))
		if w.owner_faction < 0 and (at == "DEER" or at == "BOAR"):
			var d: float = (u as Node3D).global_position.distance_to((w as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = w
	return best


static func is_wildlife_hostile_to_faction(w: Node, faction_id: int, unit_ref: Node = null) -> bool:
	if not is_instance_valid(w) or w.get("is_dead") == true:
		return false
	if w.get("is_aggro") == true:
		return true
	var wt: Variant = w.get("_target_unit")
	if wt != null and is_instance_valid(wt):
		if unit_ref != null and wt == unit_ref:
			return true
		var wt_fid: Variant = wt.get("faction_id")
		if wt_fid != null and int(wt_fid) == faction_id:
			return true
	return false


static func find_hostile_wildlife_near_point(u, point: Vector3, radius: float) -> Node:
	var best: Node = null
	var best_d := radius
	var u_fid: int = int(u.faction_id)
	for w in _wildlife_near(point, radius):
		if not is_wildlife_hostile_to_faction(w, u_fid, u):
			continue
		var d: float = point.distance_to((w as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = w
	return best


static func find_nearest_hostile_wildlife(u, radius: float) -> Node:
	return find_hostile_wildlife_near_point(u, (u as Node3D).global_position, radius)


static func find_enemy_near_point(u, point: Vector3, radius: float) -> Node:
	var best: Node = null
	var best_score := 999999.0
	for other in _units_near(point, radius):
		if not is_instance_valid(other) or other.get("is_dead") or other.get("is_wounded"):
			continue
		var u_fid: int = int(other.get("faction_id"))
		if u_fid == -1 or u_fid == -3:
			continue
		if not GameState.is_hostile(u.faction_id, u_fid):
			continue
		var o_pos: Vector3 = (other as Node3D).global_position
		var d: float = point.distance_to(o_pos)
		if d > radius:
			continue
		var score := d
		if u.role == GameData.Role.WARRIOR:
			if u.warrior_class == GameData.WarriorClass.KNIFE_RAIDER:
				if other.get("role") == GameData.Role.WARRIOR and int(other.get("warrior_class")) == GameData.WarriorClass.ARCHER:
					score -= 7.0
				var u_hp := float(other.get("hp"))
				var u_max := maxf(float(other.get("max_hp")), 1.0)
				if (u_hp / u_max) < 0.45:
					score -= 4.0
			elif u.warrior_class == GameData.WarriorClass.SPEARMAN:
				var camp: Vector3 = u._get_home_camp_pos()
				if o_pos.distance_to(camp) < 16.0:
					score -= 4.0
		if score < best_score:
			best_score = score
			best = other
	return best


static func find_nearest_enemy_building(u, radius: float) -> Node:
	var best: Node = null
	var best_d := radius
	for b in _buildings_near((u as Node3D).global_position, radius):
		if not is_instance_valid(b) or float(b.get("hp")) <= 0.0:
			continue
		if not GameState.is_hostile(u.faction_id, int(b.get("faction_id"))):
			continue
		var d: float = (u as Node3D).global_position.distance_to((b as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


static func respond_to_civilian_threat(u, enemy: Node) -> bool:
	# Civilian self-defense (weak unarmed hand attacks) or fleeing to camp
	var threat: Node = enemy
	if u._self_defense_target != null:
		if not is_instance_valid(u._self_defense_target) or u._self_defense_target.get("is_dead") == true or u._self_defense_target.get("is_wounded") == true:
			u._self_defense_target = null
		else:
			var sd_fid: Variant = u._self_defense_target.get("faction_id")
			if sd_fid != null and not GameState.is_hostile(u.faction_id, int(sd_fid)):
				u._self_defense_target = null
	if threat == null and u._self_defense_target != null:
		if u.global_position.distance_to((u._self_defense_target as Node3D).global_position) <= 6.5:
			threat = u._self_defense_target
	if threat == null:
		threat = find_nearest_hostile_wildlife(u, 7.5)

	if threat != null and is_instance_valid(threat):
		var t_pos := (threat as Node3D).global_position
		var dist_t: float = u.global_position.distance_to(t_pos)
		var camp: Vector3 = u._get_home_camp_pos()
		var at_camp: bool = u.global_position.distance_to(camp) <= 6.0
		var was_hit_by_threat: bool = (u._self_defense_timer > 0.0 and u._self_defense_target == threat)
		if dist_t <= 2.35 or (was_hit_by_threat and dist_t <= 4.2) or (at_camp and dist_t <= 4.5):
			u._engage_unarmed_self_defense(threat)
			return true
		elif dist_t < 8.5:
			u._steer_toward(camp, u.move_speed * 1.1)
			return true
	return false

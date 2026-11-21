extends CharacterBody3D

const CampaignSave = preload("res://scripts/core/campaign_save.gd")
const UnitStats = preload("res://scripts/entities/unit_stats.gd")

var animal_type: String = "DEER"
var animal_name: String = "Deer"
var hp: float = 55.0
var max_hp: float = 55.0
var move_speed: float = 7.0
var damage: float = 8.0
var armor: float = 0.0
var projectile_hit_radius: float = 1.05
var is_aggro: bool = false
var flees_when_hit: bool = true
var is_boss: bool = false
var is_dead: bool = false
var home_pos: Vector3 = Vector3.ZERO

const CombatVFX = preload("res://scripts/core/combat_vfx.gd")

var _visual_root: Node3D = null
var _animal_pivot: Node3D = null
var _bite_player: AnimationPlayer = null
var _hp_bg: MeshInstance3D = null
var _anim_walk: float = 0.0
var _attack_anim_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _death_timer: float = 0.0
var _death_fall_blend: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _last_anim_pos: Vector3 = Vector3.ZERO
var _hp_fill: MeshInstance3D = null
var _roam_target: Vector3 = Vector3.ZERO
var _roam_wait: float = 1.5
var _target_unit: Node = null
var _attack_cd: float = 0.0
var _attack_cooldown: float = 1.25
var _attack_reach: float = 1.9
var _attack_windup: float = 0.0
var _bite_remaining: float = 0.0
var _bite_target: Node3D = null
var _projectile_hit_height: float = 0.9
var _flee_timer: float = 0.0
var _flee_dir: Vector3 = Vector3.ZERO
var _index_registered: bool = false
var _prey_scan_cd: float = 0.0
var _last_move_idle: bool = false


func _exit_tree() -> void:
	_unregister_from_index()


func _unregister_from_index() -> void:
	if not _index_registered:
		return
	_index_registered = false
	GameState.spatial_index.unregister_wildlife(self)


func setup(p_type: String, p_pos: Vector3) -> void:
	animal_type = p_type
	global_position = p_pos
	home_pos = p_pos
	_roam_target = p_pos

	var data: Dictionary = GameData.WILDLIFE_DATA.get(animal_type, GameData.WILDLIFE_DATA["DEER"])
	animal_name = data["name"]
	max_hp = float(data["hp"])
	hp = max_hp
	move_speed = float(data["speed"])
	damage = float(data["damage"])
	armor = float(data.get("armor", 0.0))
	is_aggro = bool(data["aggro"])
	flees_when_hit = bool(data["flee"])
	is_boss = bool(data["is_boss"])
	_attack_cooldown = float(data.get("attack_cooldown", 1.6 if is_boss else 1.25))
	_attack_reach = float(data.get("attack_reach", 3.1 if is_boss else 1.9))
	_attack_windup = float(data.get("attack_windup", 0.0))
	_projectile_hit_height = float(data.get("projectile_hit_height", 0.9))
	projectile_hit_radius = float(data.get("projectile_hit_radius", 1.8 if is_boss else 1.05))
	_prey_scan_cd = 0.0
	if is_inside_tree() and not _index_registered:
		_index_registered = true
		GameState.spatial_index.register_wildlife(self)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(data.get("capsule_radius", 1.15 if is_boss else 0.55))
	cap.height = float(data.get("capsule_height", 2.4 if is_boss else 1.4))
	col.shape = cap
	col.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(col)

	_visual_root = MeshFactory.build_wildlife_mesh(animal_type)
	add_child(_visual_root)
	_animal_pivot = _visual_root.get_node_or_null("AnimalPivot")
	_bite_player = _visual_root.find_child("BiteAnimation", true, false) as AnimationPlayer
	if _bite_player != null:
		_bite_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_create_hp_bar()


func _create_hp_bar() -> void:
	var h_offset := 3.6 if is_boss else 2.0
	var w := 2.4 if is_boss else 1.2
	var bg := MeshInstance3D.new()
	var bg_m := BoxMesh.new()
	bg_m.size = Vector3(w, 0.14, 0.06)
	bg.mesh = bg_m
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	bg.position = Vector3(0.0, h_offset, 0.0)
	add_child(bg)
	_hp_bg = bg

	var fill := MeshInstance3D.new()
	var fill_m := BoxMesh.new()
	fill_m.size = Vector3(w - 0.06, 0.10, 0.08)
	fill.mesh = fill_m
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.95, 0.52, 0.15) if is_boss else Color(0.88, 0.28, 0.25)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = fill_mat
	fill.position = Vector3(0.0, h_offset, 0.0)
	add_child(fill)
	_hp_fill = fill
	_update_hp_bar()


func _update_hp_bar() -> void:
	if _hp_bg == null or _hp_fill == null:
		return
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.02, 1.0)
	_hp_fill.scale.x = ratio
	var show := is_boss or hp < max_hp * 0.99
	_hp_bg.visible = show
	_hp_fill.visible = show


func restore_snapshot(snapshot: Dictionary) -> void:
	home_pos = snapshot["home_pos"]
	hp = float(snapshot["hp"])
	rotation.y = float(snapshot["rot_y"])
	_update_hp_bar()


func serialize() -> Dictionary:
	return {
		"animal_type": animal_type,
		"hp": hp,
		"pos": CampaignSave.pack_position(global_position),
		"home_pos": CampaignSave.pack_position(home_pos),
		"rot_y": rotation.y,
	}


func projectile_hit_center() -> Vector3:
	return global_position + Vector3.UP * _projectile_hit_height


func take_damage(amount: float, attacker: Node, attacker_faction: int) -> void:
	if is_dead:
		return
	var applied := UnitStats.mitigated_damage(amount, armor) if armor > 0.0 else amount
	hp -= applied
	_update_hp_bar()
	_hit_flash_timer = 0.14
	CombatVFX.apply_overlay_recursive(_visual_root, CombatVFX.get_hit_flash_material())
	if attacker != null and attacker is Node3D:
		var kb := global_position - (attacker as Node3D).global_position
		kb.y = 0.0
		if kb.length_squared() > 0.001:
			var kb_str := 2.4 if is_boss else 5.5
			if GameState.factions.has(attacker_faction) and int(GameState.factions[attacker_faction].get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.VALK_TOR:
				var atk_is_spear := false
				if attacker.get("is_leader") == true:
					atk_is_spear = true
				elif attacker.has_method("_get_effective_warrior_class"):
					var eff_cls: int = int(attacker._get_effective_warrior_class())
					var atk_role: int = int(attacker.get("role"))
					if (atk_role == GameData.Role.WARRIOR or attacker._is_warhorn_militia()) and (eff_cls == GameData.WarriorClass.SPEARMAN or eff_cls == GameData.WarriorClass.JAVELINEER):
						atk_is_spear = true
				if atk_is_spear:
					kb_str *= 1.25
			_knockback_vel = kb.normalized() * kb_str
	CombatVFX.spawn_damage_popup(self, "-%d" % roundi(applied), Color(1.0, 0.88, 0.28), 1.25 if is_boss else 1.0, 2.9 if is_boss else 1.85)

	if flees_when_hit and attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		_flee_timer = 5.0
		var away: Vector3 = global_position - (attacker as Node3D).global_position
		away.y = 0.0
		_flee_dir = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	elif attacker != null and is_instance_valid(attacker) and attacker is CharacterBody3D and attacker.get("unit_id") != null:
		_target_unit = attacker

	if hp <= 0.0:
		_die(attacker, attacker_faction)


func _die(killer: Node, killer_faction: int) -> void:
	is_dead = true
	var data: Dictionary = GameData.WILDLIFE_DATA.get(animal_type, {})
	var yields: Dictionary = data.get("yield", {"food": 12, "hide": 4, "bone": 2})

	if GameState.factions.has(killer_faction):
		var mult := 1.0
		if GameState.has_building(killer_faction, "FORAGER_LODGE", true):
			mult += 0.25
		if GameState.factions[killer_faction].get("patron_god") == GameData.PatronGod.FEN_ROR:
			mult += 0.25
		if GameState.has_tenet(killer_faction, "WILD_HARMONY"):
			mult += 0.25
		for res_k in yields.keys():
			GameState.add_resource(killer_faction, res_k, float(yields[res_k]) * mult)

		if GameState.has_tenet(killer_faction, "BLOOD_SACRIFICE"):
			GameState.add_resource(killer_faction, "faith", 8.0)
			if killer != null and is_instance_valid(killer) and killer.has_method("heal"):
				killer.heal(10.0)

		if killer_faction == 0:
			var msg := "Slain %s! Gained +%d Food, +%d Hide, +%d Bone." % [animal_name, int(yields.get("food", 0) * mult), int(yields.get("hide", 0) * mult), int(yields.get("bone", 0) * mult)]
			GameState.push_log(msg, "success" if is_boss else "info")

	_unregister_from_index()
	collision_layer = 0
	collision_mask = 0
	if _hp_bg != null:
		_hp_bg.visible = false
	var hp_fill_node: Variant = get("_hp_fill")
	if hp_fill_node != null and hp_fill_node is Node3D:
		(hp_fill_node as Node3D).visible = false
	velocity = Vector3.ZERO
	_knockback_vel = Vector3.ZERO
	if _bite_player != null:
		_bite_player.stop()
	_death_timer = 6.0
	_death_fall_blend = 0.0
	CombatVFX.spawn_damage_popup(self, "SLAIN!", Color(1.0, 0.25, 0.18), 1.45 if is_boss else 1.25, 2.9 if is_boss else 1.85)
	CombatVFX.spawn_blood_pool(self, 1.35 if is_boss else 0.78)


func _process_dead_wildlife(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			CombatVFX.apply_overlay_recursive(_visual_root, null)
	_death_fall_blend = minf(1.0, _death_fall_blend + delta * 3.2)
	var fall_t := 1.0 - pow(1.0 - _death_fall_blend, 2.0)
	if _animal_pivot != null:
		_animal_pivot.rotation_degrees.z = lerpf(0.0, 88.0, fall_t)
		_animal_pivot.rotation_degrees.x = 0.0
		_animal_pivot.rotation_degrees.y = 180.0
		_animal_pivot.position.y = lerpf(0.0, 0.72 if is_boss else 0.34, fall_t)
		_animal_pivot.position.z = 0.0
	_death_timer -= delta
	if _death_timer <= 0.85 and _visual_root != null:
		var s := clampf(_death_timer / 0.85, 0.05, 1.0)
		_visual_root.scale = Vector3(1.0, s, 1.0)
	if _death_timer <= 0.0:
		queue_free()


func _update_wildlife_animation(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			CombatVFX.apply_overlay_recursive(_visual_root, null)
	if _knockback_vel.length_squared() > 0.04:
		move_and_collide(_knockback_vel * delta)
		_clamp_to_world_bounds()
		_knockback_vel = _knockback_vel.lerp(Vector3.ZERO, minf(1.0, 10.0 * delta))
	else:
		_knockback_vel = Vector3.ZERO

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if _last_anim_pos != Vector3.ZERO and delta > 0.0001:
		var dp := Vector2(global_position.x - _last_anim_pos.x, global_position.z - _last_anim_pos.z).length() / delta
		horiz_speed = maxf(horiz_speed, dp * 0.85)
	_last_anim_pos = global_position

	if _animal_pivot == null:
		return
	if _bite_player != null and _bite_player.is_playing():
		_bite_player.advance(delta)
		return

	if _attack_anim_timer > 0.0:
		_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
		var t := 1.0 - clampf(_attack_anim_timer / 0.36, 0.0, 1.0)
		var lunge := sin(t * PI)
		_animal_pivot.rotation_degrees.x = -22.0 * sin(t * PI * 2.0)
		_animal_pivot.position.z = 0.48 * lunge
		_animal_pivot.position.y = 0.16 * maxf(0.0, -sin(t * PI * 2.0))
	elif horiz_speed > 0.30:
		var rate := 1.65 if is_boss else 2.25
		_anim_walk += delta * clampf(horiz_speed, 1.5, 9.0) * rate
		_animal_pivot.position.y = absf(sin(_anim_walk)) * (0.12 if is_boss else 0.08)
		_animal_pivot.position.z = lerpf(_animal_pivot.position.z, 0.0, 10.0 * delta)
		_animal_pivot.rotation_degrees.x = cos(_anim_walk) * 3.5
		_animal_pivot.rotation_degrees.z = sin(_anim_walk) * (3.2 if is_boss else 2.2)
	else:
		_animal_pivot.position.y = lerpf(_animal_pivot.position.y, 0.0, 8.0 * delta)
		_animal_pivot.position.z = lerpf(_animal_pivot.position.z, 0.0, 8.0 * delta)
		_animal_pivot.rotation_degrees.x = lerpf(_animal_pivot.rotation_degrees.x, 0.0, 8.0 * delta)
		_animal_pivot.rotation_degrees.z = lerpf(_animal_pivot.rotation_degrees.z, 0.0, 8.0 * delta)


func _physics_process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return
	if is_dead:
		_process_dead_wildlife(delta)
		return
	GameState.spatial_index.update_wildlife(self)
	_update_wildlife_animation(delta)
	if _bite_remaining > 0.0:
		_bite_remaining = maxf(0.0, _bite_remaining - delta)
		if _bite_remaining <= 0.0:
			_land_bite()

	_attack_cd = maxf(0.0, _attack_cd - delta)
	_prey_scan_cd -= delta
	if _hp_bg != null and _hp_bg.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_hp_bg.look_at(cam.global_position, Vector3.UP)
			_hp_fill.look_at(cam.global_position, Vector3.UP)

	var desired_vel := Vector3.ZERO

	if _bite_remaining > 0.0:
		desired_vel = Vector3.ZERO
	elif _flee_timer > 0.0:
		_flee_timer -= delta
		desired_vel = _flee_dir * move_speed * 1.25
	else:
		if _target_unit != null and (not is_instance_valid(_target_unit) or _target_unit.get("is_dead") or global_position.distance_to(_target_unit.global_position) > 28.0):
			_target_unit = null

		if _target_unit == null and is_aggro and _prey_scan_cd <= 0.0:
			_prey_scan_cd = randf_range(0.18, 0.28)
			_target_unit = _scan_for_prey(16.0 if is_boss else 14.0)

		if _target_unit != null:
			var diff: Vector3 = _target_unit.global_position - global_position
			diff.y = 0.0
			var dist := diff.length()
			if dist > _attack_reach:
				desired_vel = diff.normalized() * move_speed
			elif _attack_cd <= 0.0:
				_perform_attack(_target_unit)
				_attack_cd = _attack_cooldown
		else:
			# Roam gently around home_pos
			var to_roam := _roam_target - global_position
			to_roam.y = 0.0
			if to_roam.length() > 1.2:
				desired_vel = to_roam.normalized() * (move_speed * 0.42)
			else:
				_roam_wait -= delta
				if _roam_wait <= 0.0:
					_roam_wait = randf_range(2.0, 5.5)
					_roam_target = home_pos + Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-14.0, 14.0))
					_roam_target.x = clampf(_roam_target.x, -GameState.valley_layout.wildlife_roam_half_extent, GameState.valley_layout.wildlife_roam_half_extent)
					_roam_target.z = clampf(_roam_target.z, -GameState.valley_layout.wildlife_roam_half_extent, GameState.valley_layout.wildlife_roam_half_extent)

	velocity.x = desired_vel.x
	velocity.z = desired_vel.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

	var idle_now: bool = velocity.x == 0.0 and velocity.z == 0.0 and is_on_floor()
	if not (idle_now and _last_move_idle and _knockback_vel == Vector3.ZERO):
		move_and_slide()
		_clamp_to_world_bounds()
	_last_move_idle = idle_now
	if Vector2(velocity.x, velocity.z).length() > 0.25:
		var look_t := global_position + Vector3(velocity.x, 0.0, velocity.z)
		look_at(look_t, Vector3.UP)


func _clamp_to_world_bounds() -> void:
	global_position.x = clampf(global_position.x, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)
	global_position.z = clampf(global_position.z, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)


func _scan_for_prey(radius: float) -> Node:
	var best: Node = null
	var best_d := radius
	var candidates: Array = []
	if GameState.spatial_index.is_populated():
		candidates = GameState.spatial_index.query_units_in_radius(global_position, radius)
	elif GameState.units_container != null:
		candidates = GameState.units_container.get_children()
	for u in candidates:
		if not is_instance_valid(u) or u.get("is_dead") or u.get("is_wounded"):
			continue
		var u_fid: int = int(u.get("faction_id"))
		if u_fid == -3:
			continue
		if GameState.has_tenet(u_fid, "WILD_HARMONY") and u.get("role") != GameData.Role.WARRIOR and not u.get("is_leader"):
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func _perform_attack(target: Node) -> void:
	if _bite_player != null:
		var aim: Vector3 = target.global_position
		aim.y = global_position.y
		if global_position.distance_squared_to(aim) > 0.001:
			look_at(aim, Vector3.UP)
		_animal_pivot.position = Vector3.ZERO
		_animal_pivot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		_bite_player.play(&"Bite")
		_bite_player.advance(0.0)
	else:
		_attack_anim_timer = 0.36
	if _attack_windup > 0.0:
		_bite_target = target as Node3D
		_bite_remaining = _attack_windup
		return
	if is_boss:
		# Megafauna AoE stomp/swipe
		var stomp_targets: Array = []
		if GameState.spatial_index.is_populated():
			stomp_targets = GameState.spatial_index.query_units_in_radius(global_position, 4.0)
		elif GameState.units_container != null:
			stomp_targets = GameState.units_container.get_children()
		if true:
			for u in stomp_targets:
				if is_instance_valid(u) and not u.get("is_dead") and not u.get("is_wounded"):
					if global_position.distance_to(u.global_position) <= 4.0:
						u.take_damage(damage, self, -1)
	else:
		target.take_damage(damage, self, -1)


func _land_bite() -> void:
	var target := _bite_target
	_bite_target = null
	if not is_instance_valid(target) or target.get("is_dead") == true or target.get("is_wounded") == true:
		return
	var delta := target.global_position - global_position
	delta.y = 0.0
	if delta.length_squared() <= _attack_reach * _attack_reach:
		target.take_damage(damage, self, -1)

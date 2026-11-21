extends Node3D

var shooter: Node = null
var faction_id: int = 0
var damage: float = 14.0
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 16.0
var lifetime: float = 4.0
var proj_type: String = "ARROW"
var tier: int = 1
var is_crit: bool = false


static func spawn(p_shooter: Node, p_faction_id: int, p_origin: Vector3, p_target_pos: Vector3, p_damage: float, p_speed: float = 28.0, p_type: String = "ARROW", p_tier: int = 1, p_crit: bool = false) -> Node3D:
	if GameState.projectiles_container == null:
		return null
	var proj_res: Script = load("res://scripts/entities/projectile_3d.gd") as Script
	var proj := proj_res.new() as Node3D
	GameState.projectiles_container.add_child(proj)
	proj.setup(p_shooter, p_faction_id, p_origin, p_target_pos, p_damage, p_speed, p_type, p_tier, p_crit)
	return proj


func setup(p_shooter: Node, p_faction_id: int, p_origin: Vector3, p_target_pos: Vector3, p_damage: float, p_speed: float = 28.0, p_type: String = "ARROW", p_tier: int = 1, p_crit: bool = false) -> void:
	shooter = p_shooter
	faction_id = p_faction_id
	damage = p_damage
	proj_type = p_type
	tier = p_tier
	is_crit = p_crit
	global_position = p_origin

	var visual := MeshFactory.build_projectile_mesh(proj_type, tier)
	add_child(visual)

	var diff := p_target_pos - p_origin
	var horiz := Vector3(diff.x, 0.0, diff.z)
	var dist := maxf(horiz.length(), 0.5)
	var flight_t := dist / maxf(p_speed, 5.0)
	var dir_h := horiz.normalized() if horiz.length_squared() > 0.0001 else Vector3.ZERO
	var vy := (diff.y + 0.5 * gravity * flight_t * flight_t) / maxf(flight_t, 0.05)
	velocity = dir_h * p_speed + Vector3.UP * vy

	_orient_along_velocity()


func _orient_along_velocity() -> void:
	if velocity.length_squared() <= 0.01:
		return
	var up_vec := Vector3.UP
	if Vector2(velocity.x, velocity.z).length_squared() < 0.0001:
		up_vec = Vector3.FORWARD
	look_at(global_position + velocity.normalized(), up_vec)


static func _segment_distance_to_point(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq <= 0.000001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _physics_process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished or is_queued_for_deletion():
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var prev_pos := global_position
	velocity.y -= gravity * delta
	var next_pos := prev_pos + velocity * delta
	global_position = next_pos
	_orient_along_velocity()

	var attacker: Node = shooter if is_instance_valid(shooter) else null

	# Candidates come from the spatial index around the swept segment (container scan while the index is empty).
	var indexed: bool = GameState.spatial_index.is_populated()
	var seg_mid: Vector3 = (prev_pos + next_pos) * 0.5
	var seg_r: float = prev_pos.distance_to(next_pos) * 0.5 + 3.5
	var unit_candidates: Array = []
	var wild_candidates: Array = []
	var bld_candidates: Array = []
	if indexed:
		unit_candidates = GameState.spatial_index.query_units_in_radius(seg_mid, seg_r)
		wild_candidates = GameState.spatial_index.query_wildlife_in_radius(seg_mid, seg_r)
		bld_candidates = GameState.spatial_index.query_buildings_in_radius(seg_mid, seg_r)
	else:
		if GameState.units_container != null:
			unit_candidates = GameState.units_container.get_children()
		if GameState.wildlife_container != null:
			wild_candidates = GameState.wildlife_container.get_children()
		if GameState.buildings_container != null:
			bld_candidates = GameState.buildings_container.get_children()

	# Hit detection against units (swept segment from prev_pos to next_pos)
	if true:
		for u in unit_candidates:
			if not is_instance_valid(u) or u.get("is_dead") == true:
				continue
			if not GameState.is_hostile(faction_id, int(u.get("faction_id"))):
				continue
			var hit_center: Vector3 = (u as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
			if _segment_distance_to_point(prev_pos, next_pos, hit_center) < 1.15:
				u.take_damage(damage, attacker, faction_id)
				queue_free()
				return

	# Hit detection against wildlife
	if true:
		for w in wild_candidates:
			if not is_instance_valid(w) or w.get("is_dead") == true:
				continue
			if _segment_distance_to_point(prev_pos, next_pos, w.projectile_hit_center()) < w.projectile_hit_radius:
				w.take_damage(damage, attacker, faction_id)
				queue_free()
				return

	# Hit detection against hostile buildings
	if true:
		for b in bld_candidates:
			if not is_instance_valid(b) or float(b.get("hp")) <= 0.0:
				continue
			if not GameState.is_hostile(faction_id, int(b.get("faction_id"))):
				continue
			var b_pos: Vector3 = (b as Node3D).global_position + Vector3(0.0, 1.2, 0.0)
			if _segment_distance_to_point(prev_pos, next_pos, b_pos) < 1.9:
				b.take_damage(damage, faction_id)
				queue_free()
				return

	if global_position.y <= 0.1:
		queue_free()
		return

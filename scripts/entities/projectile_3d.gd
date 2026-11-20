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
	var dir_h := horiz.normalized()
	var vy := (diff.y + 0.5 * gravity * flight_t * flight_t) / maxf(flight_t, 0.05)
	velocity = dir_h * p_speed + Vector3.UP * vy

	if velocity.length() > 0.1:
		look_at(global_position + velocity.normalized(), Vector3.UP)


func _physics_process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished or is_queued_for_deletion():
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	velocity.y -= gravity * delta
	var next_pos := global_position + velocity * delta
	if velocity.length() > 0.2:
		look_at(next_pos, Vector3.UP)
	global_position = next_pos

	if global_position.y <= 0.1:
		queue_free()
		return

	var attacker: Node = shooter if is_instance_valid(shooter) else null

	# Hit detection against units
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if not is_instance_valid(u) or u.get("is_dead"):
				continue
			if not GameState.is_hostile(faction_id, u.get("faction_id")):
				continue
			var hit_center: Vector3 = u.global_position + Vector3(0.0, 1.0, 0.0)
			if global_position.distance_to(hit_center) < 1.15:
				u.take_damage(damage, attacker, faction_id)
				queue_free()
				return

	# Hit detection against wildlife
	if GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if not is_instance_valid(w) or w.get("is_dead"):
				continue
			var w_radius := 1.8 if w.get("is_boss") else 1.05
			var w_center: Vector3 = w.global_position + Vector3(0.0, 0.9, 0.0)
			if global_position.distance_to(w_center) < w_radius:
				w.take_damage(damage, attacker, faction_id)
				queue_free()
				return

	# Hit detection against hostile buildings
	if GameState.buildings_container != null:
		for b in GameState.buildings_container.get_children():
			if not is_instance_valid(b) or b.get("hp") <= 0.0:
				continue
			if not GameState.is_hostile(faction_id, b.get("faction_id")):
				continue
			var b_pos: Vector3 = b.global_position + Vector3(0.0, 1.2, 0.0)
			if global_position.distance_to(b_pos) < 1.9:
				b.take_damage(damage, faction_id)
				queue_free()
				return

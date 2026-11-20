extends RefCounted
## Articulated procedural joint animator for Tribesman models:
## Drives Idle Stances, Walk/Run/Kite, Class Attacks, Directional Damage Flinches,
## Multi-Stage Deaths, Work Cycles, and Wounded states.

enum DeathVariant {
	BACKWARD_STAGGER,
	KNEE_CRUMPLE,
	SIDE_COLLAPSE,
}

var _visual_root: Node3D = null
var _hips: Node3D = null
var _spine: Node3D = null
var _chest: Node3D = null
var _head: Node3D = null
var _sh_l: Node3D = null
var _el_l: Node3D = null
var _sh_r: Node3D = null
var _el_r: Node3D = null
var _hip_l: Node3D = null
var _knee_l: Node3D = null
var _hip_r: Node3D = null
var _knee_r: Node3D = null
var _cape: Node3D = null
var _weapon_mount: Node3D = null

var _hips_base_pos: Vector3 = Vector3(0.0, 0.64, 0.0)
var _weapon_base_pos: Vector3 = Vector3.ZERO
var _spine_hunch: float = 0.0

var _walk_phase: float = 0.0
var _idle_phase: float = 0.0

# Attack state
var _attack_anim: String = ""
var _attack_timer: float = 0.0
var _attack_duration: float = 0.38

# Damage flinch state
var _damage_timer: float = 0.0
var _damage_duration: float = 0.30
var _damage_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
var _damage_heavy: bool = false
var _damage_shielded: bool = false

# Death state
var _death_variant: int = DeathVariant.BACKWARD_STAGGER
var _death_progress: float = 0.0
var _death_side: float = 1.0


func bind(visual_root: Node3D, spine_hunch: float = 0.0) -> void:
	_visual_root = visual_root
	_spine_hunch = spine_hunch
	_hips = null
	_spine = null
	_chest = null
	_head = null
	_sh_l = null
	_el_l = null
	_sh_r = null
	_el_r = null
	_hip_l = null
	_knee_l = null
	_hip_r = null
	_knee_r = null
	_cape = null
	_weapon_mount = null

	if visual_root == null:
		return
	var bp := visual_root.get_node_or_null("BodyPivot")
	if bp == null:
		return
	_hips = bp.get_node_or_null("HipsPivot")
	if _hips == null:
		return
	_hips_base_pos = _hips.position
	_hip_l = _hips.get_node_or_null("HipL")
	_knee_l = _hip_l.get_node_or_null("KneeL") if _hip_l != null else null
	_hip_r = _hips.get_node_or_null("HipR")
	_knee_r = _hip_r.get_node_or_null("KneeR") if _hip_r != null else null

	_spine = _hips.get_node_or_null("SpinePivot")
	if _spine != null:
		_chest = _spine.get_node_or_null("ChestPivot")
	if _chest != null:
		var neck := _chest.get_node_or_null("NeckPivot")
		_head = neck.get_node_or_null("HeadPivot") if neck != null else null
		_sh_l = _chest.get_node_or_null("ShoulderL")
		_el_l = _sh_l.get_node_or_null("ElbowL") if _sh_l != null else null
		_sh_r = _chest.get_node_or_null("ShoulderR")
		_el_r = _sh_r.get_node_or_null("ElbowR") if _sh_r != null else null
		_cape = _chest.get_node_or_null("CapePivot")
		if _el_r != null:
			_weapon_mount = _el_r.get_node_or_null("WeaponMount")
			if _weapon_mount != null:
				_weapon_base_pos = _weapon_mount.position


func is_attacking() -> bool:
	return _attack_timer > 0.0


func is_taking_damage() -> bool:
	return _damage_timer > 0.0


func trigger_attack(attack_anim: String, duration: float = 0.40) -> void:
	_attack_anim = attack_anim
	_attack_duration = maxf(duration, 0.16)
	_attack_timer = _attack_duration


func trigger_damage(hit_dir_local: Vector3, is_heavy: bool = false, has_shield: bool = false) -> void:
	_damage_dir = hit_dir_local.normalized() if hit_dir_local.length_squared() > 0.01 else Vector3(0.0, 0.0, 1.0)
	_damage_heavy = is_heavy
	_damage_shielded = has_shield
	_damage_duration = 0.42 if is_heavy else 0.28
	_damage_timer = _damage_duration


func trigger_death(variant: int = -1, hit_dir_local: Vector3 = Vector3(0.0, 0.0, 1.0)) -> void:
	_attack_timer = 0.0
	_damage_timer = 0.0
	_death_progress = 0.0
	if variant >= 0:
		_death_variant = variant
	else:
		if hit_dir_local.z < -0.35:
			_death_variant = DeathVariant.KNEE_CRUMPLE
		elif absf(hit_dir_local.x) > 0.55:
			_death_variant = DeathVariant.SIDE_COLLAPSE
		else:
			_death_variant = DeathVariant.BACKWARD_STAGGER
	_death_side = 1.0 if hit_dir_local.x >= 0.0 else -1.0


func update(delta: float, params: Dictionary) -> void:
	if _hips == null:
		return

	if bool(params.get("is_dead", false)):
		_death_progress = minf(1.0, _death_progress + delta * 1.35)
		var pose := _compute_death_pose(_death_variant, _death_progress, _death_side)
		_apply_pose(pose, 18.0 * delta, true)
		return

	if bool(params.get("is_wounded", false)):
		_idle_phase += delta * 3.5
		var w_pose := _compute_wounded_pose(_idle_phase)
		_apply_pose(w_pose, 10.0 * delta, false)
		return

	var horiz_speed: float = float(params.get("horiz_speed", 0.0))
	var is_working: bool = bool(params.get("is_working", false))
	var idle_stance: String = str(params.get("idle_stance", "RELAXED"))
	var work_anim: String = str(params.get("work_anim", "WORK_BUILD"))

	_idle_phase += delta * 2.4
	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
	if _damage_timer > 0.0:
		_damage_timer = maxf(0.0, _damage_timer - delta)

	var pose := _make_empty_pose()
	if horiz_speed > 0.35:
		_walk_phase += delta * clampf(horiz_speed, 2.0, 11.0) * 2.15
		_apply_walk_layer(pose, _walk_phase, horiz_speed, idle_stance)
	elif is_working:
		_apply_work_layer(pose, work_anim, _idle_phase * 2.2)
	else:
		_apply_idle_layer(pose, idle_stance, _idle_phase)

	if _attack_timer > 0.0:
		var att_t: float = 1.0 - clampf(_attack_timer / maxf(_attack_duration, 0.05), 0.0, 1.0)
		_overlay_attack_layer(pose, _attack_anim, att_t)

	if _damage_timer > 0.0:
		var dmg_t: float = 1.0 - clampf(_damage_timer / maxf(_damage_duration, 0.05), 0.0, 1.0)
		_overlay_damage_layer(pose, dmg_t, _damage_dir, _damage_heavy, _damage_shielded)

	var blend_spd: float = 24.0 if (_attack_timer > 0.0 or _damage_timer > 0.0) else 14.0
	_apply_pose(pose, minf(1.0, blend_spd * delta), false)


## Sets an exact deterministic pose at normalized time t in [0..1] (for showcase & inspection).
func set_preview_pose(anim_name: String, t: float, idle_stance: String = "RELAXED", hit_dir: Vector3 = Vector3(0, 0, 1)) -> void:
	if _hips == null:
		return
	var pose := _make_empty_pose()
	var nt := clampf(t, 0.0, 1.0)
	if anim_name.begins_with("DEATH_"):
		var dv := DeathVariant.BACKWARD_STAGGER
		if anim_name == "DEATH_KNEE_CRUMPLE":
			dv = DeathVariant.KNEE_CRUMPLE
		elif anim_name == "DEATH_SIDE_COLLAPSE":
			dv = DeathVariant.SIDE_COLLAPSE
		pose = _compute_death_pose(dv, nt, 1.0)
	elif anim_name == "DAMAGE_LIGHT" or anim_name == "DAMAGE_HEAVY" or anim_name == "DAMAGE_SHIELD":
		_apply_idle_layer(pose, idle_stance, 0.0)
		_overlay_damage_layer(pose, nt, hit_dir.normalized(), anim_name == "DAMAGE_HEAVY", anim_name == "DAMAGE_SHIELD")
	elif anim_name == "WALK":
		_apply_walk_layer(pose, nt * TAU, 6.0, idle_stance)
	elif anim_name.begins_with("WORK_"):
		_apply_work_layer(pose, anim_name, nt * TAU)
	elif anim_name == "IDLE":
		_apply_idle_layer(pose, idle_stance, nt * TAU)
	else:
		_apply_idle_layer(pose, idle_stance, 0.0)
		_overlay_attack_layer(pose, anim_name, nt)
	_apply_pose(pose, 1.0, true)


func _make_empty_pose() -> Dictionary:
	return {
		"hips_pos": _hips_base_pos,
		"hips_rot": Vector3.ZERO,
		"spine_rot": Vector3(_spine_hunch, 0.0, 0.0),
		"chest_rot": Vector3.ZERO,
		"head_rot": Vector3.ZERO,
		"sh_l_rot": Vector3(0.0, 0.0, 8.0),
		"el_l_rot": Vector3(-12.0, 0.0, 0.0),
		"sh_r_rot": Vector3(0.0, 0.0, -8.0),
		"el_r_rot": Vector3(-12.0, 0.0, 0.0),
		"hip_l_rot": Vector3.ZERO,
		"knee_l_rot": Vector3.ZERO,
		"hip_r_rot": Vector3.ZERO,
		"knee_r_rot": Vector3.ZERO,
		"cape_rot": Vector3(6.0, 0.0, 0.0),
		"weapon_offset": Vector3.ZERO,
	}


func _apply_idle_layer(pose: Dictionary, stance: String, phase: float) -> void:
	var breath: float = sin(phase)
	pose["hips_pos"] = _hips_base_pos + Vector3(0.0, breath * 0.012, 0.0)
	pose["chest_rot"] = Vector3(breath * 1.8, 0.0, 0.0)
	pose["head_rot"] = Vector3(-breath * 1.5, sin(phase * 0.45) * 4.5, 0.0)
	pose["cape_rot"] = Vector3(6.0 + breath * 2.5, 0.0, 0.0)

	match stance:
		"SHIELD_GUARD":
			pose["sh_l_rot"] = Vector3(-42.0, -36.0, 12.0)
			pose["el_l_rot"] = Vector3(-56.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-22.0, 0.0, -10.0)
			pose["el_r_rot"] = Vector3(-54.0, 0.0, 0.0)
			pose["hip_l_rot"] = Vector3(-6.0, 0.0, -3.0)
			pose["hip_r_rot"] = Vector3(8.0, 0.0, 3.0)
			pose["knee_l_rot"] = Vector3(8.0, 0.0, 0.0)
		"CROUCH_DUAL":
			pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.055 + breath * 0.01, 0.0)
			pose["spine_rot"] = Vector3(_spine_hunch + 14.0, 0.0, 0.0)
			pose["hip_l_rot"] = Vector3(-20.0, 0.0, -5.0)
			pose["knee_l_rot"] = Vector3(32.0, 0.0, 0.0)
			pose["hip_r_rot"] = Vector3(14.0, 0.0, 5.0)
			pose["knee_r_rot"] = Vector3(22.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-30.0, -12.0, 16.0)
			pose["el_l_rot"] = Vector3(-62.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-34.0, 12.0, -16.0)
			pose["el_r_rot"] = Vector3(-58.0, 0.0, 0.0)
		"BOW_READY":
			pose["chest_rot"] = Vector3(breath * 1.5, 18.0, 0.0)
			pose["head_rot"] = Vector3(0.0, -16.0, 0.0)
			pose["sh_l_rot"] = Vector3(-38.0, 10.0, 10.0)
			pose["el_l_rot"] = Vector3(-18.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(10.0, 0.0, -12.0)
			pose["el_r_rot"] = Vector3(-32.0, 0.0, 0.0)
		"HEAVY_STANCE":
			pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.03 + breath * 0.01, 0.0)
			pose["hip_l_rot"] = Vector3(-5.0, 0.0, -7.0)
			pose["hip_r_rot"] = Vector3(5.0, 0.0, 7.0)
			pose["knee_l_rot"] = Vector3(14.0, 0.0, 0.0)
			pose["knee_r_rot"] = Vector3(14.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-20.0, 0.0, -14.0)
			pose["el_r_rot"] = Vector3(-58.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-10.0, 0.0, 16.0)
			pose["el_l_rot"] = Vector3(-28.0, 0.0, 0.0)
		"SKIRMISHER":
			pose["sh_l_rot"] = Vector3(-38.0, -32.0, 12.0)
			pose["el_l_rot"] = Vector3(-48.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-38.0, 0.0, -14.0)
			pose["el_r_rot"] = Vector3(-44.0, 0.0, 0.0)
		"MYSTIC":
			pose["chest_rot"] = Vector3(breath * 2.2, sin(phase * 0.5) * 4.0, 0.0)
			pose["sh_r_rot"] = Vector3(-24.0, 0.0, -12.0)
			pose["el_r_rot"] = Vector3(-56.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-22.0, 0.0, 14.0)
			pose["el_l_rot"] = Vector3(-46.0, 0.0, 0.0)
		"COMMAND":
			pose["spine_rot"] = Vector3(maxf(_spine_hunch - 3.0, -3.0), 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-36.0, -28.0, 14.0)
			pose["el_l_rot"] = Vector3(-50.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-22.0, 0.0, -12.0)
			pose["el_r_rot"] = Vector3(-54.0, 0.0, 0.0)
		_:
			pose["sh_r_rot"] = Vector3(-12.0, 0.0, -10.0)
			pose["el_r_rot"] = Vector3(-36.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-8.0, 0.0, 10.0)
			pose["el_l_rot"] = Vector3(-22.0, 0.0, 0.0)


func _apply_walk_layer(pose: Dictionary, phase: float, speed: float, stance: String) -> void:
	var stride: float = sin(phase)
	var cos_s: float = cos(phase)
	var bob: float = absf(cos_s) * 0.055
	var run_lean: float = clampf(speed * 1.4, 4.0, 14.0)

	pose["hips_pos"] = _hips_base_pos + Vector3(0.0, bob - 0.02, 0.0)
	pose["hips_rot"] = Vector3(0.0, stride * 6.0, cos_s * 3.0)
	pose["spine_rot"] = Vector3(_spine_hunch + run_lean, -stride * 6.0, 0.0)
	pose["chest_rot"] = Vector3(0.0, -stride * 8.0, 0.0)
	pose["head_rot"] = Vector3(-run_lean * 0.5, stride * 4.0, 0.0)

	pose["hip_l_rot"] = Vector3(stride * 36.0, 0.0, -2.0)
	pose["knee_l_rot"] = Vector3(maxf(0.0, -stride * 48.0 + 12.0), 0.0, 0.0)
	pose["hip_r_rot"] = Vector3(-stride * 36.0, 0.0, 2.0)
	pose["knee_r_rot"] = Vector3(maxf(0.0, stride * 48.0 + 12.0), 0.0, 0.0)

	pose["sh_l_rot"] = Vector3(-stride * 28.0 - 10.0, 0.0, 10.0)
	pose["el_l_rot"] = Vector3(-26.0 - maxf(0.0, stride) * 18.0, 0.0, 0.0)
	pose["sh_r_rot"] = Vector3(stride * 26.0 - 16.0, 0.0, -10.0)
	pose["el_r_rot"] = Vector3(-42.0, 0.0, 0.0)

	if stance == "SHIELD_GUARD":
		pose["sh_l_rot"] = Vector3(-38.0 - stride * 8.0, -30.0, 12.0)
		pose["el_l_rot"] = Vector3(-52.0, 0.0, 0.0)
	elif stance == "BOW_READY":
		pose["sh_l_rot"] = Vector3(-34.0 - stride * 10.0, 8.0, 10.0)
		pose["el_l_rot"] = Vector3(-16.0, 0.0, 0.0)

	pose["cape_rot"] = Vector3(18.0 + clampf(speed * 2.2, 4.0, 22.0) + absf(stride) * 6.0, 0.0, -stride * 5.0)


func _apply_work_layer(pose: Dictionary, work_anim: String, phase: float) -> void:
	var s := sin(phase)
	var swing := (s + 1.0) * 0.5
	match work_anim:
		"WORK_FORAGE":
			pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.10, 0.0)
			pose["spine_rot"] = Vector3(_spine_hunch + 34.0 + s * 6.0, s * 10.0, 0.0)
			pose["hip_l_rot"] = Vector3(-24.0, 0.0, -4.0)
			pose["knee_l_rot"] = Vector3(36.0, 0.0, 0.0)
			pose["hip_r_rot"] = Vector3(-16.0, 0.0, 4.0)
			pose["knee_r_rot"] = Vector3(24.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-62.0 + s * 28.0, s * 18.0, -12.0)
			pose["el_r_rot"] = Vector3(-42.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-50.0, -14.0, 12.0)
			pose["el_l_rot"] = Vector3(-45.0, 0.0, 0.0)
		"WORK_CHOP":
			pose["chest_rot"] = Vector3(12.0, lerpf(-34.0, 36.0, swing), 0.0)
			pose["sh_r_rot"] = Vector3(-75.0, lerpf(-20.0, 24.0, swing), -24.0)
			pose["el_r_rot"] = Vector3(-35.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-65.0, lerpf(-30.0, 15.0, swing), 18.0)
			pose["el_l_rot"] = Vector3(-45.0, 0.0, 0.0)
		"WORK_PRAY":
			pose["spine_rot"] = Vector3(_spine_hunch - 4.0 + s * 8.0, 0.0, 0.0)
			pose["head_rot"] = Vector3(-16.0 + s * 8.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-68.0 + s * 22.0, 0.0, -14.0)
			pose["el_r_rot"] = Vector3(-36.0, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-58.0 + s * 16.0, 0.0, 16.0)
			pose["el_l_rot"] = Vector3(-42.0, 0.0, 0.0)
		"WORK_SPAR":
			pose["sh_l_rot"] = Vector3(-45.0, -34.0, 12.0)
			pose["el_l_rot"] = Vector3(-56.0, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-42.0 - swing * 46.0, 0.0, -8.0)
			pose["el_r_rot"] = Vector3(lerpf(-65.0, -10.0, swing), 0.0, 0.0)
			pose["weapon_offset"] = Vector3(0.0, 0.0, swing * 0.24)
		_: # WORK_MINE / WORK_BUILD
			pose["spine_rot"] = Vector3(_spine_hunch + lerpf(-8.0, 20.0, swing), 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(lerpf(-118.0, -18.0, swing), 0.0, -12.0)
			pose["el_r_rot"] = Vector3(lerpf(-42.0, -14.0, swing), 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-30.0, -16.0, 12.0)
			pose["el_l_rot"] = Vector3(-44.0, 0.0, 0.0)


func _overlay_attack_layer(pose: Dictionary, anim_name: String, t: float) -> void:
	match anim_name:
		"SPEAR_THRUST":
			if t < 0.32:
				var w := t / 0.32
				pose["chest_rot"] = pose["chest_rot"].lerp(Vector3(-6.0, -30.0, 0.0), w)
				pose["sh_r_rot"] = pose["sh_r_rot"].lerp(Vector3(18.0, 0.0, -14.0), w)
				pose["el_r_rot"] = pose["el_r_rot"].lerp(Vector3(-96.0, 0.0, 0.0), w)
				pose["sh_l_rot"] = Vector3(-52.0, -40.0, 12.0)
				pose["el_l_rot"] = Vector3(-58.0, 0.0, 0.0)
			elif t < 0.62:
				var s := (t - 0.32) / 0.30
				var e := 1.0 - pow(1.0 - s, 2.0)
				pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.06 * e, 0.0)
				pose["spine_rot"] = Vector3(_spine_hunch + 16.0 * e, 0.0, 0.0)
				pose["chest_rot"] = Vector3(6.0 * e, lerpf(-30.0, 26.0, e), 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(18.0, -88.0, e), 0.0, -6.0)
				pose["el_r_rot"] = Vector3(lerpf(-96.0, -8.0, e), 0.0, 0.0)
				pose["weapon_offset"] = Vector3(0.0, 0.0, 0.34 * e)
				pose["hip_l_rot"] = Vector3(-24.0 * e, 0.0, -4.0)
				pose["knee_l_rot"] = Vector3(28.0 * e, 0.0, 0.0)
				pose["hip_r_rot"] = Vector3(22.0 * e, 0.0, 4.0)
				pose["sh_l_rot"] = Vector3(-48.0, -36.0, 16.0)
			else:
				var r := (t - 0.62) / 0.38
				pose["chest_rot"] = Vector3(6.0, 26.0, 0.0).lerp(Vector3.ZERO, r)
				pose["sh_r_rot"] = Vector3(-88.0, 0.0, -6.0).lerp(Vector3(-22.0, 0.0, -10.0), r)
				pose["el_r_rot"] = Vector3(-8.0, 0.0, 0.0).lerp(Vector3(-54.0, 0.0, 0.0), r)
				pose["weapon_offset"] = Vector3(0.0, 0.0, 0.34 * (1.0 - r))

		"DUAL_SLASH":
			pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.07, 0.0)
			pose["spine_rot"] = Vector3(_spine_hunch + 18.0, 0.0, 0.0)
			if t < 0.48:
				var p1 := t / 0.48
				pose["chest_rot"] = Vector3(8.0, lerpf(-34.0, 36.0, p1), 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-124.0, 14.0, p1), 16.0, -24.0)
				pose["el_r_rot"] = Vector3(lerpf(-45.0, -12.0, p1), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(-35.0, 0.0, 22.0)
				pose["el_l_rot"] = Vector3(-72.0, 0.0, 0.0)
			else:
				var p2 := (t - 0.48) / 0.52
				pose["chest_rot"] = Vector3(10.0, lerpf(36.0, -38.0, p2), 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-118.0, 16.0, p2), -18.0, 24.0)
				pose["el_l_rot"] = Vector3(lerpf(-48.0, -14.0, p2), 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(-28.0, 0.0, -18.0)
				pose["el_r_rot"] = Vector3(-68.0, 0.0, 0.0)

		"BOW_SHOT":
			pose["chest_rot"] = Vector3(2.0, 42.0, 0.0)
			pose["head_rot"] = Vector3(0.0, -40.0, 0.0)
			pose["hip_l_rot"] = Vector3(-12.0, 0.0, -4.0)
			pose["hip_r_rot"] = Vector3(14.0, 0.0, 4.0)
			if t < 0.55:
				var d := t / 0.55
				pose["sh_l_rot"] = Vector3(lerpf(-42.0, -88.0, d), -42.0 * d, 4.0)
				pose["el_l_rot"] = Vector3(-4.0, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-30.0, -82.0, d), -26.0 * d, -28.0 * d)
				pose["el_r_rot"] = Vector3(lerpf(-38.0, -112.0, d), 0.0, 0.0)
			elif t < 0.78:
				var rel := (t - 0.55) / 0.23
				pose["sh_l_rot"] = Vector3(-88.0 - 10.0 * sin(rel * PI), -42.0, 4.0)
				pose["el_l_rot"] = Vector3(-4.0, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-82.0, -42.0, rel), -26.0, -34.0)
				pose["el_r_rot"] = Vector3(lerpf(-112.0, -32.0, rel), 0.0, 0.0)
			else:
				var rec := (t - 0.78) / 0.22
				pose["chest_rot"] = Vector3(2.0, lerpf(42.0, 18.0, rec), 0.0)
				pose["head_rot"] = Vector3(0.0, lerpf(-40.0, -16.0, rec), 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-88.0, -38.0, rec), lerpf(-42.0, 10.0, rec), 8.0)
				pose["sh_r_rot"] = Vector3(lerpf(-42.0, 10.0, rec), 0.0, -12.0)
				pose["el_r_rot"] = Vector3(-32.0, 0.0, 0.0)

		"HEAVY_SMASH":
			if t < 0.42:
				var w := t / 0.42
				pose["spine_rot"] = Vector3(_spine_hunch - 18.0 * w, 0.0, 0.0)
				pose["head_rot"] = Vector3(-16.0 * w, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-20.0, -152.0, w), 0.0, -14.0)
				pose["el_r_rot"] = Vector3(lerpf(-58.0, -24.0, w), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-10.0, -138.0, w), 0.0, 14.0)
				pose["el_l_rot"] = Vector3(lerpf(-28.0, -30.0, w), 0.0, 0.0)
			elif t < 0.68:
				var s := (t - 0.42) / 0.26
				var e := s * s
				pose["hips_pos"] = _hips_base_pos + Vector3(0.0, -0.10 * e, 0.0)
				pose["spine_rot"] = Vector3(_spine_hunch + lerpf(-18.0, 38.0, e), 0.0, 0.0)
				pose["hip_l_rot"] = Vector3(-24.0 * e, 0.0, -6.0)
				pose["knee_l_rot"] = Vector3(38.0 * e, 0.0, 0.0)
				pose["hip_r_rot"] = Vector3(-18.0 * e, 0.0, 6.0)
				pose["knee_r_rot"] = Vector3(32.0 * e, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-152.0, 24.0, e), 0.0, -10.0)
				pose["el_r_rot"] = Vector3(lerpf(-24.0, -10.0, e), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-138.0, 12.0, e), 0.0, 12.0)
				pose["el_l_rot"] = Vector3(-18.0, 0.0, 0.0)
			else:
				var rec := (t - 0.68) / 0.32
				pose["hips_pos"] = _hips_base_pos + Vector3(0.0, lerpf(-0.10, -0.03, rec), 0.0)
				pose["spine_rot"] = Vector3(_spine_hunch + lerpf(38.0, 0.0, rec), 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(24.0, -20.0, rec), 0.0, -14.0)
				pose["el_r_rot"] = Vector3(lerpf(-10.0, -58.0, rec), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(12.0, -10.0, rec), 0.0, 16.0)

		"JAVELIN_THROW":
			if t < 0.38:
				var w := t / 0.38
				pose["spine_rot"] = Vector3(_spine_hunch - 14.0 * w, 0.0, 0.0)
				pose["chest_rot"] = Vector3(-6.0 * w, -46.0 * w, 0.0)
				pose["head_rot"] = Vector3(0.0, 38.0 * w, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-38.0, -82.0, w), 28.0 * w, 10.0)
				pose["el_l_rot"] = Vector3(-8.0, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-38.0, -138.0, w), 0.0, -22.0)
				pose["el_r_rot"] = Vector3(lerpf(-44.0, -76.0, w), 0.0, 0.0)
			elif t < 0.64:
				var th := (t - 0.38) / 0.26
				var e := 1.0 - pow(1.0 - th, 2.0)
				pose["spine_rot"] = Vector3(_spine_hunch + lerpf(-14.0, 24.0, e), 0.0, 0.0)
				pose["chest_rot"] = Vector3(8.0 * e, lerpf(-46.0, 40.0, e), 0.0)
				pose["head_rot"] = Vector3(0.0, lerpf(38.0, -26.0, e), 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-138.0, 18.0, e), 0.0, -12.0)
				pose["el_r_rot"] = Vector3(lerpf(-76.0, -6.0, e), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-82.0, 10.0, e), 0.0, 16.0)
			else:
				var rec := (t - 0.64) / 0.36
				pose["chest_rot"] = Vector3(8.0, 40.0, 0.0).lerp(Vector3.ZERO, rec)
				pose["sh_r_rot"] = Vector3(18.0, 0.0, -12.0).lerp(Vector3(-38.0, 0.0, -14.0), rec)
				pose["el_r_rot"] = Vector3(-6.0, 0.0, 0.0).lerp(Vector3(-44.0, 0.0, 0.0), rec)

		"LEADER_CLEAVE":
			if t < 0.28:
				var w := t / 0.28
				pose["chest_rot"] = Vector3(-8.0 * w, -46.0 * w, 0.0)
				pose["sh_r_rot"] = Vector3(-92.0 * w, 0.0, -48.0 * w)
				pose["el_r_rot"] = Vector3(-38.0, 0.0, 0.0)
				pose["cape_rot"] = Vector3(24.0, -18.0 * w, 0.0)
			elif t < 0.66:
				var sw := (t - 0.28) / 0.38
				var e := 1.0 - pow(1.0 - sw, 2.0)
				pose["spine_rot"] = Vector3(_spine_hunch + 16.0 * e, 0.0, 0.0)
				pose["chest_rot"] = Vector3(6.0, lerpf(-46.0, 52.0, e), 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-92.0, -54.0, e), 0.0, lerpf(-48.0, 38.0, e))
				pose["el_r_rot"] = Vector3(-16.0, 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(-35.0, -24.0, 22.0)
				pose["cape_rot"] = Vector3(34.0, lerpf(-18.0, 22.0, e), 0.0)
			else:
				var rec := (t - 0.66) / 0.34
				pose["chest_rot"] = Vector3(6.0, 52.0, 0.0).lerp(Vector3.ZERO, rec)
				pose["sh_r_rot"] = Vector3(-54.0, 0.0, 38.0).lerp(Vector3(-22.0, 0.0, -12.0), rec)

		"SHAMAN_CAST":
			if t < 0.42:
				var w := t / 0.42
				pose["spine_rot"] = Vector3(_spine_hunch - 12.0 * w, 0.0, 0.0)
				pose["head_rot"] = Vector3(-24.0 * w, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-24.0, -122.0, w), 0.0, -16.0)
				pose["el_r_rot"] = Vector3(-22.0, 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-22.0, -110.0, w), 0.0, 18.0)
				pose["el_l_rot"] = Vector3(-24.0, 0.0, 0.0)
			elif t < 0.72:
				var c := (t - 0.42) / 0.30
				pose["spine_rot"] = Vector3(_spine_hunch + lerpf(-12.0, 18.0, c), 0.0, 0.0)
				pose["head_rot"] = Vector3(lerpf(-24.0, 6.0, c), 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-122.0, -48.0, c), 0.0, -10.0)
				pose["el_r_rot"] = Vector3(-28.0, 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-110.0, -86.0, c), 0.0, 10.0)
				pose["el_l_rot"] = Vector3(-8.0, 0.0, 0.0)
			else:
				var rec := (t - 0.72) / 0.28
				pose["sh_r_rot"] = Vector3(-48.0, 0.0, -10.0).lerp(Vector3(-24.0, 0.0, -12.0), rec)
				pose["sh_l_rot"] = Vector3(-86.0, 0.0, 10.0).lerp(Vector3(-22.0, 0.0, 14.0), rec)

		"UNARMED_PUNCH":
			if t < 0.30:
				var w := t / 0.30
				pose["chest_rot"] = Vector3(4.0 * w, -28.0 * w, 0.0)
				pose["sh_r_rot"] = Vector3(14.0 * w, 0.0, -14.0)
				pose["el_r_rot"] = Vector3(lerpf(-36.0, -98.0, w), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-10.0, -52.0, w), -18.0 * w, 12.0)
				pose["el_l_rot"] = Vector3(lerpf(-22.0, -72.0, w), 0.0, 0.0)
			elif t < 0.62:
				var p := (t - 0.30) / 0.32
				var e := 1.0 - pow(1.0 - p, 2.0)
				pose["spine_rot"] = Vector3(_spine_hunch + 15.0 * e, 0.0, 0.0)
				pose["chest_rot"] = Vector3(6.0 * e, lerpf(-28.0, 34.0, e), 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(14.0, -88.0, e), 0.0, -6.0)
				pose["el_r_rot"] = Vector3(lerpf(-98.0, -8.0, e), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(-48.0, -24.0, 14.0)
				pose["el_l_rot"] = Vector3(-68.0, 0.0, 0.0)
			else:
				var rec := (t - 0.62) / 0.38
				pose["chest_rot"] = Vector3(6.0, 34.0, 0.0).lerp(Vector3.ZERO, rec)
				pose["sh_r_rot"] = Vector3(-88.0, 0.0, -6.0).lerp(Vector3(-12.0, 0.0, -10.0), rec)
				pose["el_r_rot"] = Vector3(-8.0, 0.0, 0.0).lerp(Vector3(-36.0, 0.0, 0.0), rec)

		_: # TOOL_SWING
			var swing := sin(t * PI)
			pose["spine_rot"] = Vector3(_spine_hunch + 12.0 * swing, 0.0, 0.0)
			pose["chest_rot"] = Vector3(0.0, lerpf(-26.0, 28.0, t) * swing, 0.0)
			pose["sh_r_rot"] = Vector3(lerpf(-124.0, 18.0, clampf(t * 1.4, 0.0, 1.0)), 0.0, -18.0 * swing)
			pose["el_r_rot"] = Vector3(-26.0, 0.0, 0.0)


func _overlay_damage_layer(pose: Dictionary, t: float, hit_dir: Vector3, is_heavy: bool, has_shield: bool) -> void:
	# Sharp initial snap followed by smooth stagger recovery
	var curve: float = sin(t * PI) * (1.0 - t * 0.25)
	var amp: float = (1.45 if is_heavy else 1.0) * curve

	var front_hit: float = clampf(hit_dir.z, -1.0, 1.0) # +1 = hit from front -> lean back
	var side_hit: float = clampf(hit_dir.x, -1.0, 1.0)

	pose["hips_pos"] = pose["hips_pos"] + Vector3(0.0, -0.07 * amp, 0.0)
	pose["spine_rot"] = pose["spine_rot"] + Vector3(-22.0 * front_hit * amp, -16.0 * side_hit * amp, 18.0 * side_hit * amp)
	pose["chest_rot"] = pose["chest_rot"] + Vector3(-14.0 * front_hit * amp, -12.0 * side_hit * amp, 10.0 * side_hit * amp)
	pose["head_rot"] = pose["head_rot"] + Vector3(-28.0 * front_hit * amp, 14.0 * side_hit * amp, 20.0 * side_hit * amp)
	pose["knee_l_rot"] = pose["knee_l_rot"] + Vector3(24.0 * amp, 0.0, 0.0)
	pose["knee_r_rot"] = pose["knee_r_rot"] + Vector3(24.0 * amp, 0.0, 0.0)
	pose["hip_l_rot"] = pose["hip_l_rot"] + Vector3(-14.0 * amp, 0.0, 0.0)
	pose["hip_r_rot"] = pose["hip_r_rot"] + Vector3(-10.0 * amp, 0.0, 0.0)

	if has_shield and front_hit > -0.2:
		pose["sh_l_rot"] = pose["sh_l_rot"].lerp(Vector3(-74.0, -56.0, 12.0), clampf(curve * 1.2, 0.0, 1.0))
		pose["el_l_rot"] = pose["el_l_rot"].lerp(Vector3(-84.0, 0.0, 0.0), clampf(curve * 1.2, 0.0, 1.0))
		pose["sh_r_rot"] = pose["sh_r_rot"] + Vector3(14.0 * amp, 0.0, -18.0 * amp)
	else:
		pose["sh_l_rot"] = pose["sh_l_rot"] + Vector3(-24.0 * amp, 0.0, 32.0 * amp)
		pose["el_l_rot"] = pose["el_l_rot"] + Vector3(-36.0 * amp, 0.0, 0.0)
		pose["sh_r_rot"] = pose["sh_r_rot"] + Vector3(-18.0 * amp, 0.0, -32.0 * amp)
		pose["el_r_rot"] = pose["el_r_rot"] + Vector3(-32.0 * amp, 0.0, 0.0)


func _compute_wounded_pose(phase: float) -> Dictionary:
	var pose := _make_empty_pose()
	var heave := sin(phase)
	pose["hips_pos"] = Vector3(0.0, 0.14 + heave * 0.015, 0.0)
	pose["hips_rot"] = Vector3(-76.0, 0.0, 18.0)
	pose["spine_rot"] = Vector3(12.0 + heave * 4.5, 8.0, 6.0)
	pose["chest_rot"] = Vector3(8.0 + heave * 4.0, 0.0, 0.0)
	pose["head_rot"] = Vector3(18.0, -18.0 + sin(phase * 0.4) * 8.0, -14.0)
	pose["hip_l_rot"] = Vector3(-22.0, 0.0, -8.0)
	pose["knee_l_rot"] = Vector3(44.0, 0.0, 0.0)
	pose["hip_r_rot"] = Vector3(-8.0, 0.0, 10.0)
	pose["knee_r_rot"] = Vector3(24.0, 0.0, 0.0)
	pose["sh_r_rot"] = Vector3(-44.0, 18.0, -24.0)
	pose["el_r_rot"] = Vector3(-78.0, 0.0, 0.0)
	pose["sh_l_rot"] = Vector3(-26.0, 0.0, 34.0)
	pose["el_l_rot"] = Vector3(-48.0, 0.0, 0.0)
	return pose


func _compute_death_pose(variant: int, p: float, side_sign: float) -> Dictionary:
	var pose := _make_empty_pose()
	var t := clampf(p, 0.0, 1.0)
	match variant:
		DeathVariant.KNEE_CRUMPLE:
			if t < 0.38:
				var k := 1.0 - pow(1.0 - (t / 0.38), 2.0)
				pose["hips_pos"] = _hips_base_pos.lerp(Vector3(0.0, 0.35, 0.0), k)
				pose["hips_rot"] = Vector3(lerpf(0.0, 14.0, k), 0.0, 0.0)
				pose["hip_l_rot"] = Vector3(-56.0 * k, 0.0, -6.0 * k)
				pose["knee_l_rot"] = Vector3(110.0 * k, 0.0, 0.0)
				pose["hip_r_rot"] = Vector3(-52.0 * k, 0.0, 6.0 * k)
				pose["knee_r_rot"] = Vector3(106.0 * k, 0.0, 0.0)
				pose["spine_rot"] = Vector3(_spine_hunch + 28.0 * k, 0.0, 0.0)
				pose["head_rot"] = Vector3(24.0 * k, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(-48.0 * k, 18.0 * k, -14.0)
				pose["el_r_rot"] = Vector3(-86.0 * k, 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(-46.0 * k, -18.0 * k, 14.0)
				pose["el_l_rot"] = Vector3(-82.0 * k, 0.0, 0.0)
			else:
				var f := 1.0 - pow(1.0 - ((t - 0.38) / 0.62), 2.0)
				pose["hips_pos"] = Vector3(0.0, 0.35, 0.0).lerp(Vector3(0.0, 0.14, 0.0), f)
				pose["hips_rot"] = Vector3(lerpf(14.0, 82.0, f), 0.0, lerpf(0.0, 22.0 * side_sign, f))
				pose["hip_l_rot"] = Vector3(lerpf(-56.0, -18.0, f), 0.0, -8.0)
				pose["knee_l_rot"] = Vector3(lerpf(110.0, 34.0, f), 0.0, 0.0)
				pose["hip_r_rot"] = Vector3(lerpf(-52.0, -10.0, f), 0.0, 8.0)
				pose["knee_r_rot"] = Vector3(lerpf(106.0, 22.0, f), 0.0, 0.0)
				pose["spine_rot"] = Vector3(lerpf(28.0, 8.0, f), 12.0 * side_sign * f, 0.0)
				pose["head_rot"] = Vector3(lerpf(24.0, -12.0, f), 34.0 * side_sign * f, 16.0 * side_sign * f)
				pose["sh_r_rot"] = Vector3(lerpf(-48.0, -96.0, f), 0.0, -34.0 * f)
				pose["el_r_rot"] = Vector3(lerpf(-86.0, -18.0, f), 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-46.0, -78.0, f), 0.0, 38.0 * f)
				pose["el_l_rot"] = Vector3(lerpf(-82.0, -24.0, f), 0.0, 0.0)
				pose["cape_rot"] = Vector3(lerpf(14.0, 42.0, f), 0.0, 0.0)

		DeathVariant.SIDE_COLLAPSE:
			var f := 1.0 - pow(1.0 - t, 2.0)
			pose["hips_pos"] = _hips_base_pos.lerp(Vector3(0.0, 0.15, 0.0), f)
			pose["hips_rot"] = Vector3(-14.0 * f, 18.0 * side_sign * f, 84.0 * side_sign * f)
			pose["spine_rot"] = Vector3(_spine_hunch + 10.0 * f, 20.0 * side_sign * f, -10.0 * side_sign * f)
			pose["head_rot"] = Vector3(12.0 * f, -26.0 * side_sign * f, -20.0 * side_sign * f)
			pose["hip_l_rot"] = Vector3(-34.0 * f, 0.0, -12.0 * f)
			pose["knee_l_rot"] = Vector3(64.0 * f, 0.0, 0.0)
			pose["hip_r_rot"] = Vector3(12.0 * f, 0.0, 8.0 * f)
			pose["knee_r_rot"] = Vector3(22.0 * f, 0.0, 0.0)
			pose["sh_r_rot"] = Vector3(-35.0 * f, 0.0, -48.0 * f)
			pose["el_r_rot"] = Vector3(-28.0 * f, 0.0, 0.0)
			pose["sh_l_rot"] = Vector3(-52.0 * f, 0.0, 42.0 * f)
			pose["el_l_rot"] = Vector3(-38.0 * f, 0.0, 0.0)

		_: # DeathVariant.BACKWARD_STAGGER
			if t < 0.25:
				var s := t / 0.25
				pose["hips_pos"] = _hips_base_pos.lerp(Vector3(0.0, 0.54, 0.0), s)
				pose["hips_rot"] = Vector3(-22.0 * s, 0.0, 0.0)
				pose["spine_rot"] = Vector3(_spine_hunch - 24.0 * s, 0.0, 0.0)
				pose["head_rot"] = Vector3(-34.0 * s, 0.0, 14.0 * side_sign * s)
				pose["knee_l_rot"] = Vector3(32.0 * s, 0.0, 0.0)
				pose["knee_r_rot"] = Vector3(24.0 * s, 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(-38.0 * s, 0.0, -46.0 * s)
				pose["sh_l_rot"] = Vector3(-42.0 * s, 0.0, 46.0 * s)
			else:
				var f := 1.0 - pow(1.0 - ((t - 0.25) / 0.75), 2.0)
				pose["hips_pos"] = Vector3(0.0, 0.54, 0.0).lerp(Vector3(0.0, 0.19, 0.0), f)
				pose["hips_rot"] = Vector3(lerpf(-22.0, -82.0, f), 0.0, 16.0 * side_sign * f)
				pose["spine_rot"] = Vector3(lerpf(-24.0, 10.0, f), 0.0, 0.0)
				pose["head_rot"] = Vector3(lerpf(-34.0, 18.0, f), 32.0 * side_sign * f, 12.0 * side_sign * f)
				pose["hip_l_rot"] = Vector3(-16.0 * f, 0.0, -10.0 * f)
				pose["knee_l_rot"] = Vector3(lerpf(32.0, 28.0, f), 0.0, 0.0)
				pose["hip_r_rot"] = Vector3(-8.0 * f, 0.0, 10.0 * f)
				pose["knee_r_rot"] = Vector3(lerpf(24.0, 14.0, f), 0.0, 0.0)
				pose["sh_r_rot"] = Vector3(lerpf(-38.0, -14.0, f), 0.0, lerpf(-46.0, -64.0, f))
				pose["el_r_rot"] = Vector3(-18.0 * f, 0.0, 0.0)
				pose["sh_l_rot"] = Vector3(lerpf(-42.0, -18.0, f), 0.0, lerpf(46.0, 62.0, f))
				pose["el_l_rot"] = Vector3(-22.0 * f, 0.0, 0.0)
	return pose


func _apply_pose(pose: Dictionary, w: float, immediate: bool) -> void:
	var weight: float = 1.0 if immediate else clampf(w, 0.0, 1.0)
	_hips.position = _hips.position.lerp(pose["hips_pos"], weight)
	_hips.rotation_degrees = _hips.rotation_degrees.lerp(pose["hips_rot"], weight)
	if _spine != null:
		_spine.rotation_degrees = _spine.rotation_degrees.lerp(pose["spine_rot"], weight)
	if _chest != null:
		_chest.rotation_degrees = _chest.rotation_degrees.lerp(pose["chest_rot"], weight)
	if _head != null:
		_head.rotation_degrees = _head.rotation_degrees.lerp(pose["head_rot"], weight)
	if _sh_l != null:
		_sh_l.rotation_degrees = _sh_l.rotation_degrees.lerp(pose["sh_l_rot"], weight)
	if _el_l != null:
		_el_l.rotation_degrees = _el_l.rotation_degrees.lerp(pose["el_l_rot"], weight)
	if _sh_r != null:
		_sh_r.rotation_degrees = _sh_r.rotation_degrees.lerp(pose["sh_r_rot"], weight)
	if _el_r != null:
		_el_r.rotation_degrees = _el_r.rotation_degrees.lerp(pose["el_r_rot"], weight)
	if _hip_l != null:
		_hip_l.rotation_degrees = _hip_l.rotation_degrees.lerp(pose["hip_l_rot"], weight)
	if _knee_l != null:
		_knee_l.rotation_degrees = _knee_l.rotation_degrees.lerp(pose["knee_l_rot"], weight)
	if _hip_r != null:
		_hip_r.rotation_degrees = _hip_r.rotation_degrees.lerp(pose["hip_r_rot"], weight)
	if _knee_r != null:
		_knee_r.rotation_degrees = _knee_r.rotation_degrees.lerp(pose["knee_r_rot"], weight)
	if _cape != null:
		_cape.rotation_degrees = _cape.rotation_degrees.lerp(pose["cape_rot"], weight)
	if _weapon_mount != null:
		_weapon_mount.position = _weapon_mount.position.lerp(_weapon_base_pos + pose["weapon_offset"], weight)

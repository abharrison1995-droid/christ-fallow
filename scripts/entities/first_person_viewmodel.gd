extends Node3D
## First-person weapon, javelin, tool, and forearm viewmodel attached to Camera3D.

const _REST_RIGHT_POS := Vector3(0.42, -0.36, -0.46)
const _REST_LEFT_POS := Vector3(-0.40, -0.38, -0.44)
const _REST_RIGHT_ROT := Vector3(-10.0, 8.0, -4.0)
const _REST_LEFT_ROT := Vector3(-12.0, -10.0, 8.0)

static var _scene_cache: Dictionary = {}

var _right_pivot: Node3D = null
var _left_pivot: Node3D = null
var _spear_mount: Node3D = null
var _tool_mount: Node3D = null
var _javelin_mount: Node3D = null
var _jav_base_pos: Vector3 = Vector3(0.01, 0.03, -0.16)

var _built_faction_id: int = -999
var _built_lineage: int = -999
var _built_tier: int = -1
var _built_weapon_id: String = ""
var _built_armor_id: String = ""

var _bob_time: float = 0.0
var _idle_time: float = 0.0
var _action_name: String = ""
var _action_timer: float = 0.0
var _action_duration: float = 0.38
var _look_sway_pos: Vector3 = Vector3.ZERO
var _look_sway_rot: Vector3 = Vector3.ZERO
var _idle_settled: bool = false
var _last_pose_mounted: bool = false
var _last_pose_jav_hidden: bool = false


static func _get_cached_scene(res_path: String) -> PackedScene:
	if _scene_cache.has(res_path):
		return _scene_cache[res_path] as PackedScene
	if not ResourceLoader.exists(res_path, "PackedScene"):
		return null
	var packed := load(res_path) as PackedScene
	if packed != null:
		_scene_cache[res_path] = packed
	return packed


func get_built_tier() -> int:
	return _built_tier


func has_stale_gear(leader: Node) -> bool:
	if leader == null or _right_pivot == null:
		return true
	var fid: int = int(leader.get("faction_id"))
	var eff_lin: int = GameData.resolve_effective_lineage(int(leader.get("lineage")), leader.get("is_caveman") == true)
	var tier: int = maxi(1, int(leader.get("weapon_tier")))
	var w_id: String = leader.get_equipped_weapon_id() if leader.has_method("get_equipped_weapon_id") else str(leader.get("equipped_weapon_id"))
	var a_id: String = leader.get_equipped_armor_id() if leader.has_method("get_equipped_armor_id") else str(leader.get("equipped_armor_id"))
	return fid != _built_faction_id or eff_lin != _built_lineage or tier != _built_tier or w_id != _built_weapon_id or a_id != _built_armor_id


func setup_for_leader(leader: Node) -> void:
	if not has_stale_gear(leader):
		return
	var fid: int = int(leader.get("faction_id")) if leader != null else 0
	var eff_lin: int = GameData.Lineage.CRAG_BORN
	var role_val: int = GameData.Role.WARRIOR
	var wclass_val: int = GameData.WarriorClass.SPEARMAN
	var w_id: String = "GREAT_SPEAR"
	var a_id: String = "BONE_GUARD"
	if leader != null:
		eff_lin = GameData.resolve_effective_lineage(int(leader.get("lineage")), leader.get("is_caveman") == true)
		role_val = int(leader.get("role"))
		wclass_val = int(leader.get("warrior_class"))
		w_id = leader.get_equipped_weapon_id() if leader.has_method("get_equipped_weapon_id") else str(leader.get("equipped_weapon_id"))
		a_id = leader.get_equipped_armor_id() if leader.has_method("get_equipped_armor_id") else str(leader.get("equipped_armor_id"))
	var tier: int = maxi(1, int(leader.get("weapon_tier"))) if leader != null else 1

	_built_faction_id = fid
	_built_lineage = eff_lin
	_built_tier = tier
	_built_weapon_id = w_id
	_built_armor_id = a_id
	_idle_settled = false
	_clear_children()

	var ldata: Dictionary = GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN])
	var skin_col: Color = ldata.get("skin_color", Color(0.68, 0.50, 0.36))
	var trim_col: Color = GameData.FACTION_COLORS.get(fid, Color(0.82, 0.64, 0.25))
	var cuff_col: Color = trim_col
	var armored := (a_id != "" and a_id != "NONE")
	if armored:
		match a_id:
			"HIDE_TUNIC":
				cuff_col = trim_col.lerp(Color(0.54, 0.36, 0.22), 0.58)
			"BONE_GUARD":
				cuff_col = trim_col.lerp(Color(0.78, 0.74, 0.64), 0.55)
			"PELT_MANTLE":
				cuff_col = trim_col.lerp(Color(0.68, 0.60, 0.48), 0.62)
			"OBSIDIAN_PLATE":
				cuff_col = Color(0.22, 0.16, 0.30)
	var skin_mat: StandardMaterial3D = MeshFactory.make_mat(skin_col, 0.88, Color.BLACK, 0.0, 1.0, "skin")
	var cuff_mat: StandardMaterial3D = MeshFactory.make_mat(cuff_col, 0.85 if armored else 0.90, cuff_col * 0.15 if a_id == "OBSIDIAN_PLATE" else Color.BLACK, 0.3 if a_id == "OBSIDIAN_PLATE" else 0.0, 1.0, "bone" if a_id in ["BONE_GUARD", "OBSIDIAN_PLATE"] else "hide")
	var strap_mat: StandardMaterial3D = MeshFactory.make_mat(Color(0.36, 0.23, 0.14), 0.94, Color.BLACK, 0.0, 1.0, "hide")

	# Right arm + Equipped Weapon / Build Mallet
	_right_pivot = Node3D.new()
	_right_pivot.name = "RightArmPivot"
	_right_pivot.position = _REST_RIGHT_POS
	_right_pivot.rotation_degrees = _REST_RIGHT_ROT
	add_child(_right_pivot)
	_build_forearm(_right_pivot, skin_mat, cuff_mat, strap_mat, 1.0, armored)

	var wdef: Dictionary = GameData.resolve_weapon_def(w_id, role_val, wclass_val, true, false)
	var eff_w_id: String = str(wdef.get("id", "GREAT_SPEAR"))
	var w_glb: String = str(wdef.get("glb_path", "res://assets/models/gear/leader/great_spear.glb"))
	if eff_w_id == "HUNTING_BOW":
		w_glb = str(wdef.get("offhand_glb", "res://assets/models/gear/archer/bow.glb"))
	var w_tier: int = maxi(tier, 3) if eff_w_id == "OBSIDIAN_CLEAVER" else tier
	var is_spear_like: bool = eff_w_id in ["GREAT_SPEAR", "STONE_SPEAR", "BARBED_JAVELIN", ""]
	_spear_mount = _load_gear_or_fallback(w_glb, trim_col, w_tier, is_spear_like)
	match eff_w_id:
		"HUNTING_BOW":
			_spear_mount.position = Vector3(-0.04, 0.04, -0.14)
			_spear_mount.rotation_degrees = Vector3(-12.0, 14.0, -10.0)
			_spear_mount.scale = Vector3.ONE * 0.65
		"WAR_CLUB", "OBSIDIAN_CLEAVER":
			_spear_mount.position = Vector3(-0.01, 0.04, -0.12)
			_spear_mount.rotation_degrees = Vector3(-42.0, 8.0, 6.0)
			_spear_mount.scale = Vector3.ONE * 0.64
		"FLINT_DIRK":
			_spear_mount.position = Vector3(0.0, 0.03, -0.09)
			_spear_mount.rotation_degrees = Vector3(-36.0, 10.0, 4.0)
			_spear_mount.scale = Vector3.ONE * 0.78
		_:
			_spear_mount.position = Vector3(-0.02, 0.03, -0.18)
			_spear_mount.rotation_degrees = Vector3(-58.0, 6.0, 4.0)
			_spear_mount.scale = Vector3.ONE * 0.54
	_right_pivot.add_child(_spear_mount)

	_tool_mount = _load_gear_or_fallback(
		"res://assets/models/gear/builder_crafter/mallet.glb",
		trim_col, tier, false
	)
	_tool_mount.position = Vector3(-0.01, 0.02, -0.08)
	_tool_mount.rotation_degrees = Vector3(-52.0, 8.0, 6.0)
	_tool_mount.scale = Vector3.ONE * 0.70
	_tool_mount.visible = false
	_right_pivot.add_child(_tool_mount)

	# Left arm + Javelin
	_left_pivot = Node3D.new()
	_left_pivot.name = "LeftArmPivot"
	_left_pivot.position = _REST_LEFT_POS
	_left_pivot.rotation_degrees = _REST_LEFT_ROT
	add_child(_left_pivot)
	_build_forearm(_left_pivot, skin_mat, cuff_mat, strap_mat, -1.0, armored)

	_javelin_mount = _load_gear_or_fallback(
		"res://assets/models/gear/javelineer/barbed_javelin.glb",
		trim_col, tier, true
	)
	_jav_base_pos = Vector3(0.01, 0.03, -0.16)
	_javelin_mount.position = _jav_base_pos
	_javelin_mount.rotation_degrees = Vector3(-62.0, -6.0, -4.0)
	_javelin_mount.scale = Vector3.ONE * 0.52
	_left_pivot.add_child(_javelin_mount)


func notify_look_delta(yaw_delta_deg: float, pitch_delta_deg: float, reduced_motion: bool = false) -> void:
	if reduced_motion:
		return
	_look_sway_pos.x = clampf(_look_sway_pos.x - yaw_delta_deg * 0.0022, -0.045, 0.045)
	_look_sway_pos.y = clampf(_look_sway_pos.y + pitch_delta_deg * 0.0018, -0.038, 0.038)
	_look_sway_rot.y = clampf(_look_sway_rot.y + yaw_delta_deg * 0.16, -6.5, 6.5)
	_look_sway_rot.x = clampf(_look_sway_rot.x - pitch_delta_deg * 0.14, -5.5, 5.5)
	_look_sway_rot.z = clampf(_look_sway_rot.z - yaw_delta_deg * 0.12, -5.0, 5.0)
	_idle_settled = false


func reset_pose() -> void:
	_action_name = ""
	_action_timer = 0.0
	_look_sway_pos = Vector3.ZERO
	_look_sway_rot = Vector3.ZERO
	_bob_time = 0.0
	_idle_time = 0.0
	_idle_settled = false


func trigger_action(action: String, duration: float = 0.38) -> void:
	_action_name = action
	_action_duration = maxf(0.05, duration)
	_action_timer = _action_duration
	_idle_settled = false


func update_viewmodel(delta: float, speed_ratio: float, mounted: bool, javelin_cd: float, reduced_motion: bool) -> void:
	if _right_pivot == null or _left_pivot == null:
		return

	var has_active_action := _action_timer > 0.0
	var sway_active := _look_sway_pos.length_squared() > 0.000004 or _look_sway_rot.length_squared() > 0.01
	var javelin_reloading := javelin_cd > 0.0 and javelin_cd <= 0.30
	var hide_javelin := (_javelin_mount != null and (
		(javelin_cd > 0.28 and _action_name != "JAVELIN")
		or (_action_name == "JAVELIN" and _action_timer > 0.0 and (1.0 - _action_timer / _action_duration) >= 0.38)
	))
	var pose_state_changed := (mounted != _last_pose_mounted) or (hide_javelin != _last_pose_jav_hidden)

	# Zero-work fast path when standing completely idle with no active swings/sway/reload
	if reduced_motion and not has_active_action and speed_ratio <= 0.02 and not sway_active and not javelin_reloading and not pose_state_changed and _idle_settled:
		return

	if delta > 0.0:
		_idle_time += delta
		if speed_ratio > 0.05:
			_bob_time += delta * lerpf(6.5, 11.0, clampf(speed_ratio, 0.0, 1.5))
		var decay: float = minf(1.0, delta * 12.0)
		_look_sway_pos = _look_sway_pos.lerp(Vector3.ZERO, decay)
		_look_sway_rot = _look_sway_rot.lerp(Vector3.ZERO, decay)
		if _look_sway_pos.length_squared() < 0.000004:
			_look_sway_pos = Vector3.ZERO
		if _look_sway_rot.length_squared() < 0.01:
			_look_sway_rot = Vector3.ZERO

	if _action_timer > 0.0:
		_action_timer = maxf(0.0, _action_timer - delta)
		if _action_timer <= 0.0:
			_action_name = ""

	var bob_x := 0.0
	var bob_y := 0.0
	var idle_y := sin(_idle_time * 1.9) * 0.004 if not reduced_motion else 0.0
	if not reduced_motion and speed_ratio > 0.05:
		var amp := minf(speed_ratio, 1.3) * 0.015
		bob_x = cos(_bob_time * 0.5) * amp
		bob_y = absf(sin(_bob_time * 0.5)) * -amp * 1.15

	var mount_y := -0.052 if mounted else 0.0
	var mount_pitch := -7.0 if mounted else 0.0
	var sway_off := _look_sway_pos if not reduced_motion else Vector3.ZERO
	var sway_rot := _look_sway_rot if not reduced_motion else Vector3.ZERO

	var base_r_pos := _REST_RIGHT_POS + Vector3(bob_x, idle_y + bob_y + mount_y, 0.0) + sway_off
	var base_l_pos := _REST_LEFT_POS + Vector3(bob_x * 0.7, idle_y + bob_y * 0.8 + mount_y, 0.0) + sway_off * 0.85
	var base_r_rot := _REST_RIGHT_ROT + Vector3(mount_pitch, 0.0, 0.0) + sway_rot
	var base_l_rot := _REST_LEFT_ROT + Vector3(mount_pitch, 0.0, 0.0) + sway_rot * 0.85

	var r_pos_add := Vector3.ZERO
	var l_pos_add := Vector3.ZERO
	var r_rot_add := Vector3.ZERO
	var l_rot_add := Vector3.ZERO

	var working := (_action_name == "WORK" and _action_timer > 0.0)
	if _spear_mount != null:
		_spear_mount.visible = not working
	if _tool_mount != null:
		_tool_mount.visible = working

	if _javelin_mount != null:
		_javelin_mount.visible = not hide_javelin
		if javelin_reloading and not hide_javelin:
			var reload_t: float = clampf(1.0 - (javelin_cd / 0.28), 0.0, 1.0)
			_javelin_mount.position = _jav_base_pos + Vector3(0.0, lerpf(-0.18, 0.0, reload_t), lerpf(0.14, 0.0, reload_t))
		else:
			_javelin_mount.position = _jav_base_pos

	if _action_timer > 0.0:
		var t: float = clampf(1.0 - _action_timer / _action_duration, 0.0, 1.0)
		match _action_name:
			"HEAVY_SMASH":
				if t < 0.22:
					var k := _ease_out(t / 0.22)
					r_pos_add = Vector3(0.05, 0.18, 0.08) * k
					r_rot_add = Vector3(32.0, -10.0, -14.0) * k
				elif t < 0.54:
					var k := _ease_in_out((t - 0.22) / 0.32)
					r_pos_add = Vector3(0.05, 0.18, 0.08).lerp(Vector3(-0.14, -0.10, -0.28), k)
					r_rot_add = Vector3(32.0, -10.0, -14.0).lerp(Vector3(-28.0, 20.0, 20.0), k)
				else:
					var k := _ease_out((t - 0.54) / 0.46)
					r_pos_add = Vector3(-0.14, -0.10, -0.28).lerp(Vector3.ZERO, k)
					r_rot_add = Vector3(-28.0, 20.0, 20.0).lerp(Vector3.ZERO, k)
			"BOW_SHOT":
				if t < 0.25:
					var k := _ease_out(t / 0.25)
					r_pos_add = Vector3(-0.08, 0.05, 0.06) * k
					r_rot_add = Vector3(4.0, 12.0, 6.0) * k
					l_pos_add = Vector3(0.10, 0.04, -0.08) * k
				else:
					var k := _ease_out((t - 0.25) / 0.75)
					r_pos_add = Vector3(-0.08, 0.05, 0.06).lerp(Vector3.ZERO, k)
					r_rot_add = Vector3(4.0, 12.0, 6.0).lerp(Vector3.ZERO, k)
					l_pos_add = Vector3(0.10, 0.04, -0.08).lerp(Vector3.ZERO, k)
			"CLEAVE", "DUAL_SLASH":
				if t < 0.10:
					var k := _ease_out(t / 0.10)
					r_pos_add = Vector3(0.11, 0.06, 0.08) * k
					r_rot_add = Vector3(12.0, -20.0, -24.0) * k
					l_pos_add = Vector3(-0.04, -0.02, 0.04) * k
				elif t < 0.44:
					var k := _ease_in_out((t - 0.10) / 0.34)
					r_pos_add = Vector3(0.11, 0.06, 0.08).lerp(Vector3(-0.26, 0.02, -0.26), k)
					r_rot_add = Vector3(12.0, -20.0, -24.0).lerp(Vector3(10.0, 42.0, 38.0), k)
					l_pos_add = Vector3(-0.04, -0.02, 0.04).lerp(Vector3(-0.08, -0.04, 0.08), k)
				else:
					var k := _ease_out((t - 0.44) / 0.56)
					r_pos_add = Vector3(-0.26, 0.02, -0.26).lerp(Vector3.ZERO, k)
					r_rot_add = Vector3(10.0, 42.0, 38.0).lerp(Vector3.ZERO, k)
					l_pos_add = Vector3(-0.08, -0.04, 0.08).lerp(Vector3.ZERO, k)
			"JAVELIN":
				if t < 0.16:
					var k := _ease_out(t / 0.16)
					l_pos_add = Vector3(-0.05, 0.11, 0.14) * k
					l_rot_add = Vector3(15.0, 10.0, -12.0) * k
					r_pos_add = Vector3(0.05, -0.03, 0.05) * k
				elif t < 0.46:
					var k := _ease_out((t - 0.16) / 0.30)
					l_pos_add = Vector3(-0.05, 0.11, 0.14).lerp(Vector3(0.14, 0.05, -0.32), k)
					l_rot_add = Vector3(15.0, 10.0, -12.0).lerp(Vector3(-10.0, -18.0, 16.0), k)
					r_pos_add = Vector3(0.05, -0.03, 0.05).lerp(Vector3.ZERO, k)
				else:
					var k := _ease_out((t - 0.46) / 0.54)
					l_pos_add = Vector3(0.14, 0.05, -0.32).lerp(Vector3.ZERO, k)
					l_rot_add = Vector3(-10.0, -18.0, 16.0).lerp(Vector3.ZERO, k)
			"WORK":
				if t < 0.26:
					var k := _ease_out(t / 0.26)
					r_pos_add = Vector3(0.03, 0.15, 0.06) * k
					r_rot_add = Vector3(28.0, -8.0, -10.0) * k
				elif t < 0.58:
					var k := _ease_in_out((t - 0.26) / 0.32)
					r_pos_add = Vector3(0.03, 0.15, 0.06).lerp(Vector3(-0.09, -0.08, -0.22), k)
					r_rot_add = Vector3(28.0, -8.0, -10.0).lerp(Vector3(-22.0, 18.0, 16.0), k)
				else:
					var k := _ease_out((t - 0.58) / 0.42)
					r_pos_add = Vector3(-0.09, -0.08, -0.22).lerp(Vector3.ZERO, k)
					r_rot_add = Vector3(-22.0, 18.0, 16.0).lerp(Vector3.ZERO, k)
			"BLESSING":
				var lift := sin(t * PI)
				r_pos_add = Vector3(-0.04, 0.16, -0.09) * lift
				l_pos_add = Vector3(0.05, 0.16, -0.09) * lift
				r_rot_add = Vector3(26.0, 8.0, 12.0) * lift
				l_rot_add = Vector3(26.0, -8.0, -12.0) * lift
			"DASH":
				var dash_k := sin(t * PI)
				r_pos_add = Vector3(-0.06, -0.06, -0.14) * dash_k
				l_pos_add = Vector3(0.05, -0.05, -0.12) * dash_k
				r_rot_add = Vector3(-14.0, 16.0, 10.0) * dash_k
				l_rot_add = Vector3(-12.0, -14.0, -8.0) * dash_k

	_right_pivot.position = base_r_pos + r_pos_add
	_right_pivot.rotation_degrees = base_r_rot + r_rot_add
	_left_pivot.position = base_l_pos + l_pos_add
	_left_pivot.rotation_degrees = base_l_rot + l_rot_add

	_last_pose_mounted = mounted
	_last_pose_jav_hidden = hide_javelin
	_idle_settled = reduced_motion and _action_timer <= 0.0 and speed_ratio <= 0.02 and not sway_active and not javelin_reloading


static func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


static func _ease_in_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _build_forearm(arm_root: Node3D, skin_mat: Material, cuff_mat: Material, strap_mat: Material, side_sign: float, armored: bool = false) -> void:
	var forearm := CylinderMesh.new()
	forearm.top_radius = 0.032
	forearm.bottom_radius = 0.042
	forearm.height = 0.25
	var arm_mesh := MeshFactory.add_mesh(arm_root, forearm, Vector3(0.015 * side_sign, -0.03, 0.13), skin_mat, Vector3(-76.0, 10.0 * side_sign, 0.0), "Forearm")
	arm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.042 if armored else 0.038
	cuff.bottom_radius = 0.048 if armored else 0.044
	cuff.height = 0.095 if armored else 0.075
	var cuff_mesh := MeshFactory.add_mesh(arm_root, cuff, Vector3(0.01 * side_sign, -0.015, 0.04), cuff_mat, Vector3(-76.0, 10.0 * side_sign, 0.0), "WristCuff")
	cuff_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var hand := BoxMesh.new()
	hand.size = Vector3(0.056, 0.054, 0.072)
	var hand_mesh := MeshFactory.add_mesh(arm_root, hand, Vector3(0.0, 0.008, -0.02), strap_mat, Vector3(-12.0, 0.0, 0.0), "HandGrip")
	hand_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _load_gear_or_fallback(glb_path: String, trim_col: Color, tier: int, is_spear_like: bool) -> Node3D:
	var holder := Node3D.new()
	var packed := _get_cached_scene(glb_path)
	if packed != null:
		var model := packed.instantiate()
		if model is Node3D:
			_apply_psx_viewmodel_materials(model, trim_col, tier)
			holder.add_child(model)
			return holder
		if model != null:
			model.free()
	# Procedural fallback if an asset is missing
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.020
	shaft.bottom_radius = 0.024
	shaft.height = 1.15 if is_spear_like else 0.55
	var sm := MeshFactory.add_mesh(holder, shaft, Vector3.ZERO, MeshFactory.make_mat(Color(0.45, 0.28, 0.15), 0.92, Color.BLACK, 0.0, 1.0, "wood"))
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head: Mesh
	if is_spear_like:
		var pm := PrismMesh.new()
		pm.size = Vector3(0.11, 0.26, 0.04)
		head = pm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.24, 0.14, 0.14)
		head = bm
	var stone_col := _tier_stone_color(Color(0.54, 0.54, 0.58), tier)
	var hm := MeshFactory.add_mesh(holder, head, Vector3(0.0, 0.65 if is_spear_like else 0.30, 0.0), MeshFactory.make_mat(stone_col, 0.88, Color.BLACK, 0.0, 1.0, "stone"))
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _apply_psx_viewmodel_materials(model: Node, trim_col: Color, tier: int) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mi.mesh.get_surface_count()):
			var src := mi.get_surface_override_material(surface) as StandardMaterial3D
			if src == null:
				src = mi.mesh.surface_get_material(surface) as StandardMaterial3D
			if src == null:
				continue
			var mat_name := str(src.resource_name)
			var lower := mat_name.to_lower()
			var tex_kind := _resolve_tex_kind(lower)
			var col: Color = trim_col if (mat_name == "FactionTrim" or mat_name == "Mat_Trim" or "trim" in lower) else src.albedo_color
			if tex_kind == "stone":
				col = _tier_stone_color(col, tier)
			mi.set_surface_override_material(surface, MeshFactory.make_mat(col, src.roughness, Color.BLACK, 0.0, 1.0, tex_kind))


static func _tier_stone_color(base: Color, tier: int) -> Color:
	if tier >= 3:
		return base.lerp(Color(0.11, 0.09, 0.14), 0.65)
	if tier == 2:
		return base.lightened(0.24)
	return base


static func _resolve_tex_kind(lower: String) -> String:
	if "bone" in lower or "ivory" in lower or "horn" in lower:
		return "bone"
	if "wood" in lower or "oak" in lower or "reed" in lower:
		return "wood"
	if "flint" in lower or "stone" in lower or "edge" in lower or "obsidian" in lower:
		return "stone"
	return "hide"


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_right_pivot = null
	_left_pivot = null
	_spear_mount = null
	_tool_mount = null
	_javelin_mount = null

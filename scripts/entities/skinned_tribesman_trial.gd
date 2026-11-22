extends Node3D

const LAUNCH_FLAG := "--skinned-tribesman-trial"
const MODEL_PATH := "res://assets/models/characters/tribesman_base.glb"
const SHADER := preload("res://scripts/shaders/psx_unit_skinned.gdshader")
# Fine snapping matches psx_diablo_post.gdshader and keeps thin tools/braids intact at 12 m.
const DEFAULT_SNAP_RESOLUTION := Vector2(560.0, 315.0)
const DEFAULT_JITTER_INTENSITY := 0.13

var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _body_materials: Array[ShaderMaterial] = []
var _base_emissions: Array[Dictionary] = []
var _jitter_enabled := true
var _idle_clip: StringName = &"Idle"
var _walk_clip: StringName = &"Walk"
var _attack_clip: StringName = &"Attack"
var _current_clip: StringName = &""
var _pending_restart_clip: StringName = &""
var _oneshot_elapsed := 0.0
var _last_hit_flash := -1.0
var _base_scale := Vector3.ONE


func set_rig_scale(rig_scale: Vector3) -> void:
	_base_scale = rig_scale
	scale = rig_scale


func squash_corpse(height_ratio: float) -> void:
	scale = _base_scale * Vector3(1.0, height_ratio, 1.0)


func apply_riding_pose(leg_spread: float) -> void:
	if _skeleton == null:
		return
	for side in ["L", "R"]:
		for joint in ["UpperLeg", "LowerLeg"]:
			var index := _skeleton.find_bone("%s.%s" % [joint, side])
			if index < 0:
				continue
			var to_bone := _skeleton.get_bone_global_rest(index).basis.inverse()
			var rest := _skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			var angle := deg_to_rad(67.0 if joint == "UpperLeg" else -84.0)
			var pose := Quaternion((to_bone * Vector3.RIGHT).normalized(), angle)
			if joint == "UpperLeg":
				var spread := deg_to_rad(-leg_spread if side == "L" else leg_spread)
				pose = Quaternion((to_bone * Vector3.UP).normalized(), spread) * pose
			_skeleton.set_bone_pose_rotation(index, rest * pose)


func riding_hip_height() -> float:
	var hips := _skeleton.find_bone("Hips") if _skeleton != null else -1
	if hips < 0:
		return 0.0
	return _skeleton.get_bone_global_rest(hips).origin.y * _base_scale.y


func setup(mesh_factory: Node, faction_color: Color, spear_template: Node3D) -> bool:
	if spear_template == null or not ResourceLoader.exists(MODEL_PATH, "PackedScene"):
		return false
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate()
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		return false
	var skeleton := skeletons[0] as Skeleton3D
	_skeleton = skeleton
	_animation = players[0] as AnimationPlayer
	var hand_idx := skeleton.find_bone("Hand.R")
	if hand_idx < 0 or not _animation.has_animation("Idle") or not _animation.has_animation("Walk"):
		return false

	var hand := BoneAttachment3D.new()
	hand.name = "TrialWeaponHand"
	hand.bone_name = "Hand.R"
	skeleton.add_child(hand)
	var spear := spear_template.duplicate() as Node3D
	spear.name = "TrialSpear"
	hand.add_child(spear)
	spear.position = Vector3(0.0, 0.057, 0.0)
	var hand_rest := skeleton.get_bone_global_rest(hand_idx)
	var carry_direction := hand_rest.basis.inverse() * Vector3(0.0, 0.96, -0.28)
	spear.quaternion = Quaternion(Vector3.BACK, carry_direction.normalized())
	spear.show()

	_body_materials = apply_materials(mesh_factory, model, faction_color)
	if _body_materials.is_empty():
		return false
	_capture_base_emissions()

	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return true


func _capture_base_emissions() -> void:
	_base_emissions.clear()
	for material in _body_materials:
		var col_v: Variant = material.get_shader_parameter("emission_color")
		var energy_v: Variant = material.get_shader_parameter("emission_energy")
		var col: Color = col_v if col_v is Color else Color(0.0, 0.0, 0.0, 1.0)
		var energy: float = float(energy_v) if energy_v != null else 0.0
		_base_emissions.append({"color": col, "energy": energy})


func restart_clip(clip_name: StringName) -> void:
	_pending_restart_clip = _attack_clip if clip_name == &"Attack" else clip_name
	_oneshot_elapsed = 0.0


func set_hit_flash(hit_flash: float) -> void:
	var clamped := maxf(0.0, hit_flash)
	if is_equal_approx(_last_hit_flash, clamped):
		return
	_last_hit_flash = clamped
	for i in range(_body_materials.size()):
		var material: ShaderMaterial = _body_materials[i]
		if clamped > 0.0:
			material.set_shader_parameter("emission_color", Color(1.0, 0.25, 0.2))
			material.set_shader_parameter("emission_energy", clamped * 1.4)
		else:
			var base_col := Color(0.0, 0.0, 0.0, 1.0)
			var base_energy := 0.0
			if i < _base_emissions.size():
				var entry: Dictionary = _base_emissions[i]
				base_col = entry["color"]
				base_energy = float(entry["energy"])
			material.set_shader_parameter("emission_color", base_col)
			material.set_shader_parameter("emission_energy", base_energy)


func set_hand_mounts_visible(vis: bool) -> void:
	for slot_name in ["Weapon", "Offhand", "TrialWeaponHand"]:
		var slot := find_child(slot_name, true, false) as Node3D
		if slot != null:
			slot.visible = vis


func _resolve_clip(anim_state: String) -> StringName:
	if anim_state == "WALK" or anim_state == "KITE":
		return _walk_clip
	if anim_state == "TOOL_SWING" or anim_state.begins_with("WORK_"):
		return &"Work"
	if anim_state in [
		"SPEAR_THRUST", "DUAL_SLASH", "BOW_SHOT", "HEAVY_SMASH",
		"JAVELIN_THROW", "LEADER_CLEAVE", "SHAMAN_CAST", "UNARMED_PUNCH"
	]:
		return _attack_clip
	if anim_state.begins_with("DAMAGE_"):
		return &"Hit"
	if anim_state.begins_with("DEATH_"):
		return &"Death"
	if anim_state == "WOUNDED":
		return &"Wounded"
	return _idle_clip


func _is_oneshot_clip(clip: StringName) -> bool:
	return clip == _attack_clip or clip == &"Hit" or clip == &"Death"


func update_action(anim_state: String, speed: float, delta: float, jitter_enabled: bool, hit_flash: float = 0.0) -> void:
	if _jitter_enabled != jitter_enabled:
		_jitter_enabled = jitter_enabled
		for material in _body_materials:
			material.set_shader_parameter("enable_jitter", jitter_enabled)
	set_hit_flash(hit_flash)
	if _animation == null:
		return

	var target_clip := _resolve_clip(anim_state)
	if not _animation.has_animation(target_clip):
		target_clip = _idle_clip

	var is_oneshot := _is_oneshot_clip(target_clip)
	var need_start := (_current_clip != target_clip) or (_pending_restart_clip == target_clip)
	if need_start:
		_current_clip = target_clip
		if _pending_restart_clip == target_clip:
			_pending_restart_clip = &""
		_oneshot_elapsed = 0.0
		var blend := 0.06 if is_oneshot else 0.14
		if is_oneshot:
			_animation.stop(true)
			_animation.play(target_clip, blend)
			_animation.seek(0.0, true)
		else:
			_animation.play(target_clip, blend)

	var dt := maxf(0.0, delta)
	if is_oneshot:
		var clip_res: Animation = _animation.get_animation(target_clip)
		var clip_len := clip_res.length if clip_res != null else 0.5
		var hold_pos := maxf(0.0, clip_len - 0.001)
		_oneshot_elapsed = minf(_oneshot_elapsed + dt, hold_pos)
		if _oneshot_elapsed >= hold_pos:
			if _animation.current_animation != target_clip:
				_animation.play(target_clip, 0.0)
			_animation.speed_scale = 0.0
			_animation.seek(hold_pos, true)
		else:
			_animation.speed_scale = 1.0
			if _animation.current_animation != target_clip:
				_animation.play(target_clip, 0.0)
				_animation.seek(_oneshot_elapsed, true)
			else:
				_animation.advance(dt)
	else:
		if _animation.current_animation != target_clip:
			_animation.play(target_clip, 0.14)
		_animation.speed_scale = clampf(speed / 4.3, 0.45, 1.85) if target_clip == _walk_clip else 1.0
		_animation.advance(dt)


func update_locomotion(speed: float, delta: float, jitter_enabled: bool) -> void:
	update_action("WALK" if speed > 0.25 else "IDLE", speed, delta, jitter_enabled, 0.0)


static func _resolve_texture_kind(mat_name: String) -> String:
	var key := mat_name.to_lower()
	if "skin" in key:
		return "skin"
	if "bone" in key or "ivory" in key or "horn" in key:
		return "bone"
	if "wood" in key or "reed" in key or "straw" in key or "bark" in key or "oak" in key:
		return "wood"
	if "flint" in key or "stone" in key or "edge" in key or "slate" in key or "obsidian" in key:
		return "stone"
	if "hair" in key or "auburn" in key:
		return "wood"
	if "cloth" in key or "trim" in key or "leather" in key or "hide" in key or "fur" in key:
		return "hide"
	return "hide"


static func _make_skinned_shader_material(mesh_factory: Node, source: StandardMaterial3D, faction_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var mat_name: String = source.resource_name
	var is_trim := mat_name == "FactionTrim" or mat_name == "Mat_Trim"
	var tint := faction_color if is_trim else source.albedo_color
	var tex: Texture2D = source.albedo_texture
	if tex == null:
		tex = mesh_factory.get_gritty_texture(_resolve_texture_kind(mat_name))
	material.set_shader_parameter("base_color", tint)
	material.set_shader_parameter("roughness", source.roughness)
	material.set_shader_parameter("albedo_texture", tex)
	material.set_shader_parameter("snap_resolution", DEFAULT_SNAP_RESOLUTION)
	material.set_shader_parameter("jitter_intensity", DEFAULT_JITTER_INTENSITY)
	material.set_shader_parameter("enable_jitter", true)
	if source.emission_enabled and source.emission_energy_multiplier > 0.0:
		material.set_shader_parameter("emission_color", source.emission)
		material.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	return material


static func apply_materials(mesh_factory: Node, model: Node, faction_color: Color) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		if instance.material_override is StandardMaterial3D:
			var override_mat := _make_skinned_shader_material(mesh_factory, instance.material_override as StandardMaterial3D, faction_color)
			instance.material_override = override_mat
			materials.append(override_mat)
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var imported := instance.get_surface_override_material(surface) as StandardMaterial3D
			if imported == null:
				imported = instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if imported == null:
				continue
			var material := _make_skinned_shader_material(mesh_factory, imported, faction_color)
			instance.set_surface_override_material(surface, material)
			materials.append(material)
	return materials

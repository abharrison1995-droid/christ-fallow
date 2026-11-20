extends Node3D

const LAUNCH_FLAG := "--skinned-tribesman-trial"
const MODEL_PATH := "res://assets/models/characters/tribesman_base.glb"
const SHADER := preload("res://scripts/shaders/psx_unit_skinned.gdshader")

var _animation: AnimationPlayer
var _body_materials: Array[ShaderMaterial] = []
var _jitter_enabled := true
var _idle_clip: StringName = &"Idle"
var _walk_clip: StringName = &"Walk"


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
	_animation = players[0] as AnimationPlayer
	var hand_idx := skeleton.find_bone("Hand.R")
	if hand_idx < 0 or not _animation.has_animation("Idle") or not _animation.has_animation("Walk"):
		return false

	_body_materials = apply_materials(mesh_factory, model, faction_color)
	if _body_materials.is_empty():
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
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return true


func update_locomotion(speed: float, delta: float, jitter_enabled: bool) -> void:
	var walking := speed > 0.25
	var clip := _walk_clip if walking else _idle_clip
	if _animation.current_animation != clip:
		_animation.play(clip, 0.14)
	_animation.speed_scale = clampf(speed / 4.3, 0.45, 1.85) if walking else 1.0
	_animation.advance(delta)
	if _jitter_enabled != jitter_enabled:
		_jitter_enabled = jitter_enabled
		for material in _body_materials:
			material.set_shader_parameter("enable_jitter", jitter_enabled)


static func apply_materials(mesh_factory: Node, model: Node, faction_color: Color) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var imported := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if imported == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = SHADER
			var tint := faction_color if imported.resource_name == "FactionTrim" else imported.albedo_color
			var texture_kind := "hide"
			match imported.resource_name:
				"Mat_Skin":
					texture_kind = "skin"
				"Mat_Bone":
					texture_kind = "bone"
			material.set_shader_parameter("base_color", tint)
			material.set_shader_parameter("roughness", imported.roughness)
			material.set_shader_parameter("albedo_texture", mesh_factory.get_gritty_texture(texture_kind))
			instance.set_surface_override_material(surface, material)
			materials.append(material)
	return materials

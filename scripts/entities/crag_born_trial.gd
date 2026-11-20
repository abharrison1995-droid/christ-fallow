extends "res://scripts/entities/skinned_tribesman_trial.gd"

const PILOT_FLAG := "--crag-born-trial"
const BODIES := "res://assets/models/characters/lineages/crag_born"
const GEAR := "res://assets/models/gear"
const CHILD_SCALE := 0.68
const GRIP_R := Vector3(-0.012, -0.054, -0.006)
const GRIP_L := Vector3(0.012, -0.054, -0.006)


static func enabled() -> bool:
	return PILOT_FLAG in OS.get_cmdline_user_args()


func setup_kit(mesh_factory: Node, faction_color: Color, variant: String, class_key: String) -> bool:
	var guard := class_key == "SPEARMAN"
	if guard:
		_idle_clip = &"GuardIdle"
		_walk_clip = &"GuardWalk"
	var body_path := "%s/crag_born_%s.glb" % [BODIES, variant]
	var model := _instantiate_model(body_path)
	if model == null:
		return false
	add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or _animation == null:
		return false
	if not _animation.has_animation(_idle_clip) or not _animation.has_animation(_walk_clip):
		return false

	if guard:
		if not _mount(skeleton, "Hand.R", "Weapon", "spearman/spear", GRIP_R,
				Basis(Quaternion(Vector3.UP, Vector3(-0.085, 0.84, -0.54).normalized()))):
			return false
		if not _mount(skeleton, "Hand.L", "Offhand", "spearman/hide_buckler", GRIP_L,
				Basis(Vector3.RIGHT, -0.70)):
			return false
		if not _mount(skeleton, "Chest", "Chestwear", "spearman/bone_guard", Vector3.ZERO):
			return false
	else:
		if not _mount(skeleton, "Hand.R", "Weapon", "forager/flint_sickle", GRIP_R,
				Basis(Vector3.RIGHT, -0.58) * Basis(Vector3.BACK, 0.56)):
			return false
		if not _mount(skeleton, "Chest", "Back", "forager/reed_basket", Vector3(0.0, 0.0, 0.326)):
			return false
		if not _mount(skeleton, "Chest", "Chestwear", "forager/workwear", Vector3(0, 0, -0.038)):
			return false

	_body_materials = apply_materials(mesh_factory, model, faction_color)
	for material in _body_materials:
		# Fine snapping keeps thin tools and braids intact at the default 12 m camera distance.
		material.set_shader_parameter("snap_resolution", Vector2(560, 315))
		material.set_shader_parameter("jitter_intensity", 0.13)
		material.set_shader_parameter("enable_jitter", true)
	if variant == "child":
		scale = Vector3.ONE * CHILD_SCALE
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return not _body_materials.is_empty()


func _mount(skeleton: Skeleton3D, bone_name: String, slot_name: String, asset: String,
		offset: Vector3, orientation := Basis.IDENTITY) -> bool:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return false
	var item := _instantiate_model("%s/%s.glb" % [GEAR, asset])
	if item == null:
		return false

	var slot := BoneAttachment3D.new()
	slot.name = slot_name
	slot.bone_name = bone_name
	skeleton.add_child(slot)
	slot.add_child(item)
	# Gear is authored in Godot model axes. Convert the rest-axis offset to bone space.
	var inverse_rest := skeleton.get_bone_global_rest(bone).basis.inverse()
	item.transform = Transform3D(inverse_rest * orientation, inverse_rest * offset)
	return true


static func _instantiate_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D

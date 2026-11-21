extends "res://scripts/entities/skinned_tribesman_trial.gd"

const PILOT_FLAG := "--crag-born-trial"
const PROCEDURAL_ROSTER_FLAG := "--procedural-roster"
const BODIES := "res://assets/models/characters/lineages"
const LINEAGE_KEYS := {
	GameData.Lineage.CRAG_BORN: "crag_born",
	GameData.Lineage.GOLIATH: "goliath",
	GameData.Lineage.SWIFT_KIN: "swift_kin",
	GameData.Lineage.STALKER: "stalker",
	GameData.Lineage.ASH_WALKER: "ash_walker",
}
const GEAR := "res://assets/models/gear"
const CHILD_SCALE := 0.68
const GRIP_R := Vector3(-0.012, -0.054, -0.006)
const GRIP_L := Vector3(0.012, -0.054, -0.006)


static func enabled() -> bool:
	return not (PROCEDURAL_ROSTER_FLAG in OS.get_cmdline_user_args())


static func supports_lineage(lineage: int) -> bool:
	return LINEAGE_KEYS.has(lineage)


static func select_body_variant(gender: int, is_child: bool, unit_id: int) -> String:
	var male := gender == GameData.Gender.MALE
	if is_child:
		return "boy" if male else "child"
	# Use the second ID bit so alternating male and female spawns can both vary.
	if (unit_id & 2) != 0:
		return "cropped" if male else "twin_knots"
	return "broad" if male else "braided"


func setup_kit(mesh_factory: Node, faction_color: Color, variant: String, class_key: String,
		lineage: int = GameData.Lineage.CRAG_BORN) -> bool:
	if not supports_lineage(lineage):
		return false
	var guard := class_key == "SPEARMAN"
	_idle_clip = &"GuardIdle" if guard else &"Idle"
	_walk_clip = &"GuardWalk" if guard else &"Walk"
	var key: String = LINEAGE_KEYS[lineage]
	var body_path := "%s/%s/%s_%s.glb" % [BODIES, key, key, variant]
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
	if _body_materials.is_empty():
		return false
	_capture_base_emissions()
	# Bodies and kit grip origins share Crag-Born rest dimensions. Scale them together.
	var profile: Dictionary = GameData.LINEAGE_DATA[lineage]
	var reference: Dictionary = GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN]
	var relative_width := float(profile["width_scale"]) / float(reference["width_scale"])
	var age_scale := CHILD_SCALE if variant in ["child", "boy"] else 1.0
	set_rig_scale(Vector3(relative_width, float(profile["height_scale"]), relative_width) * age_scale)
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return true


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

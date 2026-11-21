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
	GameData.Lineage.FEN_TIDAL: "fen_tidal",
	GameData.Lineage.CAVEMAN: "caveman",
}
const GEAR := "res://assets/models/gear"
const CHILD_SCALE := 0.68
const GRIP_R := Vector3(-0.012, -0.054, -0.006)
const GRIP_L := Vector3(0.012, -0.054, -0.006)
const COMBAT_MOVES := "res://assets/models/characters/moves/combat.glb"
const COMBAT_CLIPS := {
	"KNIFE_RAIDER": &"KnifeSlash", "ARCHER": &"BowRelease",
	"BRUTE": &"ClubSmash", "JAVELINEER": &"JavelinCast",
}
const KIT_ITEMS := {
	"KNIFE_RAIDER": [
		["Hand.R", "Weapon", "knife_raider/dirk", GRIP_R, Vector3(-0.47, 0, 0.22)],
		["Hand.L", "Offhand", "knife_raider/dirk", GRIP_L, Vector3(-0.48, 0, -0.22)],
		["Chest", "Back", "knife_raider/sheaths", Vector3(0, 0, 0.22), Vector3.ZERO],
	],
	"ARCHER": [
		["Hand.R", "Weapon", "archer/arrow", GRIP_R, Vector3(-1.45, 0, 0)],
		["Hand.L", "Offhand", "archer/bow", GRIP_L, Vector3(-0.20, 0.14, -0.26)],
		["Chest", "Back", "archer/quiver", Vector3(0, 0, 0.23), Vector3.ZERO],
	],
	"BRUTE": [
		["Hand.R", "Weapon", "brute/flint_maul", GRIP_R, Vector3(-0.40, 0, 0.34)],
		["Chest", "Back", "brute/trophy_rack", Vector3(0, 0, 0.21), Vector3.ZERO],
	],
	"JAVELINEER": [
		["Hand.R", "Weapon", "javelineer/barbed_javelin", GRIP_R, Vector3(-0.78, 0, 0.21)],
		["Hand.L", "Offhand", "spearman/hide_buckler", GRIP_L, Vector3(-0.70, 0, 0)],
		["Chest", "Back", "javelineer/javelin_bundle", Vector3(0, 0.04, 0.26), Vector3.ZERO],
	],
}

static var _combat_moves: AnimationLibrary
var _armor: Node3D
var _tier_surfaces: Array[ShaderMaterial] = []


static func enabled() -> bool:
	return not (PROCEDURAL_ROSTER_FLAG in OS.get_cmdline_user_args())


static func supports_lineage(lineage: int) -> bool:
	return LINEAGE_KEYS.has(lineage)


static func supports_kit(class_key: String, is_child: bool) -> bool:
	return class_key == "FORAGER" or (not is_child and (class_key in ["SPEARMAN", "CAVEMAN"] or KIT_ITEMS.has(class_key)))


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
	var guard := class_key in ["SPEARMAN", "CAVEMAN"]
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

	if KIT_ITEMS.has(class_key):
		for item in KIT_ITEMS[class_key]:
			if not _mount(skeleton, item[0], item[1], item[2], item[3], Basis.from_euler(item[4])):
				return false
		if not _mount(skeleton, "Chest", "Armor", "spearman/bone_guard", Vector3.ZERO):
			return false
		_armor = skeleton.get_node("Armor")
		_armor.hide()
		var moves := _get_combat_moves()
		var clip: StringName = COMBAT_CLIPS[class_key]
		if moves == null or not moves.has_animation(clip):
			return false
		_animation.add_animation_library(&"combat", moves)
		_attack_clip = StringName("combat/" + String(clip))
	elif class_key == "CAVEMAN":
		if not _mount(skeleton, "Hand.R", "Weapon", "caveman/bone_club", GRIP_R, Basis(Vector3.RIGHT, -0.39)):
			return false
		if not _mount(skeleton, "Chest", "Chestwear", "caveman/trophy_pelt", Vector3.ZERO):
			return false
	elif guard:
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
	if KIT_ITEMS.has(class_key):
		_collect_tier_surfaces(skeleton)
	_capture_base_emissions()
	# Bodies and kit grip origins share Crag-Born rest dimensions. Scale them together.
	var profile: Dictionary = GameData.LINEAGE_DATA[lineage]
	var reference: Dictionary = GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN]
	var relative_width := float(profile["width_scale"]) / float(reference["width_scale"])
	var age_scale := CHILD_SCALE if variant in ["child", "boy"] else 1.0
	set_rig_scale(Vector3(relative_width, float(profile["height_scale"]), relative_width) * age_scale)
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return true


static func _get_combat_moves() -> AnimationLibrary:
	if _combat_moves != null:
		return _combat_moves
	var model := _instantiate_model(COMBAT_MOVES)
	if model == null:
		return null
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation_library(&""):
		_combat_moves = player.get_animation_library(&"")
	model.free()
	return _combat_moves


func _collect_tier_surfaces(skeleton: Skeleton3D) -> void:
	for slot_name in ["Weapon", "Offhand"]:
		var slot := skeleton.get_node_or_null(slot_name)
		if slot == null:
			continue
		for node in slot.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			for surface in range(mesh_node.mesh.get_surface_count()):
				var source := mesh_node.mesh.surface_get_material(surface)
				if _resolve_texture_kind(source.resource_name) == "stone":
					var shader := mesh_node.get_surface_override_material(surface) as ShaderMaterial
					if shader != null:
						shader.set_meta("base_tint", shader.get_shader_parameter("base_color"))
						_tier_surfaces.append(shader)


func sync_equipment(tier: int, armored: bool) -> void:
	if _armor != null:
		_armor.visible = armored
	for shader in _tier_surfaces:
		var base: Color = shader.get_meta("base_tint")
		var tint := base.lightened(0.24) if tier == 2 else base
		if tier >= 3:
			tint = base.lerp(Color(0.11, 0.09, 0.14), 0.65)
		shader.set_shader_parameter("base_color", tint)


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

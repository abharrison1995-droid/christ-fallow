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
const ROLE_MOVES := "res://assets/models/characters/moves"
const COMBAT_CLIPS := {
	"KNIFE_RAIDER": &"KnifeSlash", "ARCHER": &"BowRelease",
	"BRUTE": &"ClubSmash", "JAVELINEER": &"JavelinCast",
}
const SPECIALIST_CLIPS := {
	"HUNTER": [&"combat", &"BowRelease"], "SHAMAN": [&"specialist", &"ShamanCast"],
	"LEADER": [&"leader", &"LeaderCleave"],
}
const WORKFORCE_KITS := ["HUNTER", "LUMBERJACK", "STONEKNAPPER", "BUILDER_CRAFTER", "SHAMAN", "TRAINEE"]
const WEAPON_MOUNT_TRANSFORMS := {
	"GREAT_SPEAR": {
		"offset": GRIP_R, "rot": Vector3(-0.37, 0.0, 0.23),
		"offhand_offset": GRIP_L, "offhand_rot": Vector3(-0.70, 0.0, 0.0),
	},
	"STONE_SPEAR": {
		"offset": GRIP_R, "dir": Vector3(-0.085, 0.84, -0.54),
		"offhand_offset": GRIP_L, "offhand_rot": Vector3(-0.70, 0.0, 0.0),
	},
	"FLINT_DIRK": {
		"offset": GRIP_R, "rot": Vector3(-0.47, 0.0, 0.22),
		"offhand_offset": GRIP_L, "offhand_rot": Vector3(-0.48, 0.0, -0.22),
	},
	"HUNTING_BOW": {
		"offset": GRIP_R, "rot": Vector3(-1.45, 0.0, 0.0),
		"offhand_offset": GRIP_L, "offhand_rot": Vector3(-0.20, 0.14, -0.26),
	},
	"WAR_CLUB": {
		"offset": GRIP_R, "rot": Vector3(-0.40, 0.0, 0.34),
	},
	"OBSIDIAN_CLEAVER": {
		"offset": GRIP_R, "rot": Vector3(-0.40, 0.0, 0.34),
	},
	"BARBED_JAVELIN": {
		"offset": GRIP_R, "rot": Vector3(-0.78, 0.0, 0.21),
		"offhand_offset": GRIP_L, "offhand_rot": Vector3(-0.70, 0.0, 0.0),
	},
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
	"HUNTER": [
		["Hand.R", "Weapon", "archer/arrow", GRIP_R, Vector3(-1.45, 0, 0)],
		["Hand.L", "Offhand", "archer/bow", GRIP_L, Vector3(-0.26, 0.14, -0.26)],
		["Chest", "Back", "archer/quiver", Vector3(0, 0, 0.23), Vector3.ZERO],
		["Chest", "Chestwear", "hunter/pelt_capelet", Vector3.ZERO, Vector3.ZERO],
	],
	"LUMBERJACK": [
		["Hand.R", "Weapon", "lumberjack/axe", GRIP_R, Vector3(-0.45, 0, 0.26)],
		["Chest", "Back", "lumberjack/timber_pack", Vector3(0, 0, 0.27), Vector3.ZERO],
	],
	"STONEKNAPPER": [
		["Hand.R", "Weapon", "stoneknapper/pick", GRIP_R, Vector3(-0.39, 0, 0.26)],
		["Chest", "Back", "stoneknapper/stone_satchel", Vector3(0, -0.09, 0.24), Vector3.ZERO],
	],
	"BUILDER_CRAFTER": [
		["Hand.R", "Weapon", "builder_crafter/mallet", GRIP_R, Vector3(-0.38, 0, 0.20)],
		["Hand.L", "Offhand", "builder_crafter/adze", GRIP_L, Vector3(-0.35, 0, -0.27)],
		["Chest", "Back", "lumberjack/timber_pack", Vector3(0, -0.07, 0.26), Vector3(0, 0, 0.41)],
	],
	"SHAMAN": [
		["Hand.R", "Weapon", "shaman/spirit_staff", GRIP_R, Vector3(-0.32, 0, 0.22)],
		["Hand.L", "Offhand", "shaman/ritual_charm", GRIP_L, Vector3(-0.34, 0, -0.24)],
		["Chest", "Chestwear", "caveman/trophy_pelt", Vector3.ZERO, Vector3.ZERO],
	],
	"TRAINEE": [
		["Hand.R", "Weapon", "trainee/sparring_spear", GRIP_R, Vector3(-0.51, 0, 0.24)],
		["Hand.L", "Offhand", "spearman/hide_buckler", GRIP_L, Vector3(-0.60, 0, 0)],
		["Chest", "Chestwear", "forager/workwear", Vector3.ZERO, Vector3.ZERO],
	],
	"LEADER": [
		["Hand.R", "Weapon", "leader/great_spear", GRIP_R, Vector3(-0.37, 0, 0.23)],
		["Hand.L", "Offhand", "spearman/hide_buckler", GRIP_L, Vector3(-0.70, 0, 0)],
		["Chest", "Cape", "leader/split_mantle", Vector3(0, 0.05, 0.206), Vector3.ZERO],
		["Chest", "Back", "javelineer/javelin_bundle", Vector3(0.06, 0.05, 0.272), Vector3(0, 0, -0.18)],
		["Head", "Crown", "leader/bone_crown", Vector3(0, 0.177, 0.005), Vector3.ZERO],
	],
	"FLINTMASK_SCOUT": [
		["Hand.R", "Weapon", "flintmask_scout/hooked_club", GRIP_R, Vector3(-0.40, 0, 0.30)],
		["Chest", "Chestwear", "caveman/trophy_pelt", Vector3.ZERO, Vector3.ZERO],
	],
}

static var _move_libraries := {}
static var _scene_cache: Dictionary = {}
var _armor: Node3D
var _tier_surfaces: Array[ShaderMaterial] = []
var _faction_color: Color = Color.WHITE
var _class_key: String = ""
var _equipped_weapon_id: String = ""
var _equipped_armor_id: String = ""
var _force_obsidian_weapon: bool = false


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
	_faction_color = faction_color
	_class_key = class_key
	var guard := class_key in ["SPEARMAN", "CAVEMAN", "TRAINEE"]
	_idle_clip = &"GuardIdle" if guard else &"Idle"
	_walk_clip = &"GuardWalk" if guard else &"Walk"
	var key: String = LINEAGE_KEYS[lineage]
	var body_path := "%s/%s/%s_%s.glb" % [BODIES, key, key, variant]
	if class_key == GameData.FLINTMASK_SCOUT:
		body_path = "res://assets/models/characters/archetypes/flintmask_scout.glb"
	var model := _instantiate_model(body_path)
	if model == null:
		return false
	add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_skeleton = skeleton
	_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or _animation == null:
		return false
	if not _animation.has_animation(_idle_clip) or not _animation.has_animation(_walk_clip):
		return false

	if KIT_ITEMS.has(class_key):
		for item in KIT_ITEMS[class_key]:
			if not _mount(skeleton, item[0], item[1], item[2], item[3], Basis.from_euler(item[4])):
				return false
		if COMBAT_CLIPS.has(class_key):
			if not _mount(skeleton, "Chest", "Armor", "spearman/bone_guard", Vector3.ZERO):
				return false
			_armor = skeleton.get_node("Armor")
			_armor.hide()
			if not _set_role_clip(&"combat", COMBAT_CLIPS[class_key]):
				return false
		elif SPECIALIST_CLIPS.has(class_key):
			var clips: Array = SPECIALIST_CLIPS[class_key]
			if not _set_role_clip(clips[0], clips[1]):
				return false
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

	_equipped_weapon_id = _default_weapon_for_kit(class_key)
	_equipped_armor_id = "BONE_GUARD" if class_key == "SPEARMAN" else "NONE"

	_body_materials = apply_materials(mesh_factory, model, faction_color)
	if _body_materials.is_empty():
		return false
	if COMBAT_CLIPS.has(class_key):
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


static func _default_weapon_for_kit(class_key: String) -> String:
	match class_key:
		"LEADER":
			return "GREAT_SPEAR"
		"SPEARMAN":
			return "STONE_SPEAR"
		"KNIFE_RAIDER":
			return "FLINT_DIRK"
		"ARCHER":
			return "HUNTING_BOW"
		"BRUTE":
			return "WAR_CLUB"
		"JAVELINEER":
			return "BARBED_JAVELIN"
	return ""


func _set_role_clip(library_name: StringName, clip: StringName) -> bool:
	var moves := _get_moves(library_name)
	if moves == null or not moves.has_animation(clip):
		return false
	if not _animation.has_animation_library(library_name):
		_animation.add_animation_library(library_name, moves)
	_attack_clip = StringName("%s/%s" % [library_name, clip])
	return true


static func _get_moves(library_name: StringName) -> AnimationLibrary:
	if _move_libraries.has(library_name):
		return _move_libraries[library_name]
	var model := _instantiate_model("%s/%s.glb" % [ROLE_MOVES, library_name])
	if model == null:
		return null
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var moves: AnimationLibrary
	if player != null and player.has_animation_library(&""):
		moves = player.get_animation_library(&"")
		_move_libraries[library_name] = moves
	model.free()
	return moves


func _collect_tier_surfaces(skeleton: Skeleton3D) -> void:
	_tier_surfaces.clear()
	for slot_name in ["Weapon", "Offhand"]:
		var slot := skeleton.get_node_or_null(slot_name)
		if slot == null:
			continue
		for node in slot.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node == null or mesh_node.mesh == null:
				continue
			for surface in range(mesh_node.mesh.get_surface_count()):
				var source := mesh_node.mesh.surface_get_material(surface)
				if source != null and _resolve_texture_kind(source.resource_name) == "stone":
					var shader := mesh_node.get_surface_override_material(surface) as ShaderMaterial
					if shader != null:
						if not shader.has_meta("base_tint"):
							shader.set_meta("base_tint", shader.get_shader_parameter("base_color"))
						_tier_surfaces.append(shader)


func _rebuild_body_material_list() -> void:
	_body_materials.clear()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.material_override is ShaderMaterial:
			_body_materials.append(mi.material_override as ShaderMaterial)
			continue
		for surface in range(mi.mesh.get_surface_count()):
			var mat := mi.get_surface_override_material(surface) as ShaderMaterial
			if mat != null:
				_body_materials.append(mat)
	_capture_base_emissions()
	_last_hit_flash = -1.0


func equip_gear(mesh_factory: Node, weapon_id: String, armor_id: String, weapon_tier: int) -> void:
	if _skeleton == null or mesh_factory == null:
		return
	var materials_dirty := false

	if weapon_id != "" and GameData.WEAPON_DEFS.has(weapon_id):
		_force_obsidian_weapon = (weapon_id == "OBSIDIAN_CLEAVER")
		if weapon_id != _equipped_weapon_id:
			for slot_name in ["Weapon", "Offhand"]:
				var old_slot := _skeleton.get_node_or_null(slot_name)
				if old_slot != null:
					clear_surface_overrides(old_slot)
					_skeleton.remove_child(old_slot)
					old_slot.queue_free()
			var wdef: Dictionary = GameData.WEAPON_DEFS[weapon_id]
			var tf: Dictionary = WEAPON_MOUNT_TRANSFORMS.get(weapon_id, {"offset": GRIP_R, "rot": Vector3(-0.37, 0.0, 0.23)})
			var w_basis := Basis.IDENTITY
			if tf.has("dir"):
				var d: Vector3 = tf["dir"]
				w_basis = Basis(Quaternion(Vector3.UP, d.normalized()))
			elif tf.has("rot"):
				w_basis = Basis.from_euler(tf["rot"])
			var w_path: String = str(wdef.get("glb_path", ""))
			if w_path != "" and _mount_glb(_skeleton, "Hand.R", "Weapon", w_path, tf.get("offset", GRIP_R), w_basis):
				var w_slot := _skeleton.get_node_or_null("Weapon")
				if w_slot != null:
					apply_materials(mesh_factory, w_slot, _faction_color)
			var o_path: String = str(wdef.get("offhand_glb", ""))
			if o_path != "":
				var o_basis := Basis.from_euler(tf.get("offhand_rot", Vector3(-0.70, 0.0, 0.0)))
				if _mount_glb(_skeleton, "Hand.L", "Offhand", o_path, tf.get("offhand_offset", GRIP_L), o_basis):
					var o_slot := _skeleton.get_node_or_null("Offhand")
					if o_slot != null:
						apply_materials(mesh_factory, o_slot, _faction_color)
			_update_clips_for_weapon(weapon_id)
			_collect_tier_surfaces(_skeleton)
			_equipped_weapon_id = weapon_id
			materials_dirty = true
	else:
		_force_obsidian_weapon = false

	var eff_armor_id: String = armor_id if (armor_id != "" and GameData.ARMOR_DEFS.has(armor_id)) else "NONE"
	if eff_armor_id == "NONE":
		if _armor != null and is_instance_valid(_armor):
			_armor.visible = false
		if _class_key == "SPEARMAN":
			var cw := _skeleton.get_node_or_null("Chestwear") as Node3D
			if cw != null:
				cw.visible = false
		_equipped_armor_id = "NONE"
	elif eff_armor_id == "BONE_GUARD" and _class_key == "SPEARMAN" and _armor == null:
		var cw := _skeleton.get_node_or_null("Chestwear") as Node3D
		if cw != null:
			cw.visible = true
		_equipped_armor_id = "BONE_GUARD"
	else:
		if _class_key == "SPEARMAN":
			var cw := _skeleton.get_node_or_null("Chestwear") as Node3D
			if cw != null:
				cw.visible = false
		if eff_armor_id != _equipped_armor_id or _armor == null or not is_instance_valid(_armor):
			if _armor != null and is_instance_valid(_armor):
				clear_surface_overrides(_armor)
				_skeleton.remove_child(_armor)
				_armor.queue_free()
				_armor = null
			var adef: Dictionary = GameData.ARMOR_DEFS[eff_armor_id]
			var a_path: String = str(adef.get("glb_path", ""))
			var a_off := Vector3(0.0, 0.0, -0.038) if "workwear.glb" in a_path else Vector3.ZERO
			if a_path != "" and _mount_glb(_skeleton, "Chest", "Armor", a_path, a_off):
				_armor = _skeleton.get_node_or_null("Armor") as Node3D
				if _armor != null:
					var armor_mats := apply_materials(mesh_factory, _armor, _faction_color)
					var a_tint: Color = adef.get("tint", Color.WHITE)
					if a_tint != Color.WHITE:
						for smat in armor_mats:
							var cur_v: Variant = smat.get_shader_parameter("base_color")
							var cur_col: Color = cur_v if cur_v is Color else Color.WHITE
							smat.set_shader_parameter("base_color", cur_col.lerp(a_tint, 0.82))
					materials_dirty = true
			_equipped_armor_id = eff_armor_id
		if _armor != null and is_instance_valid(_armor):
			_armor.visible = true

	if materials_dirty:
		_rebuild_body_material_list()
		for smat in _body_materials:
			smat.set_shader_parameter("enable_jitter", _jitter_enabled)
	sync_equipment(weapon_tier, eff_armor_id != "NONE")


func _update_clips_for_weapon(weapon_id: String) -> void:
	if _animation == null:
		return
	var use_guard := (weapon_id == "STONE_SPEAR")
	_idle_clip = &"GuardIdle" if (use_guard and _animation.has_animation(&"GuardIdle")) else &"Idle"
	_walk_clip = &"GuardWalk" if (use_guard and _animation.has_animation(&"GuardWalk")) else &"Walk"
	match weapon_id:
		"GREAT_SPEAR":
			_set_role_clip(&"leader", &"LeaderCleave")
		"STONE_SPEAR":
			_attack_clip = &"Attack"
		"FLINT_DIRK":
			_set_role_clip(&"combat", &"KnifeSlash")
		"HUNTING_BOW":
			_set_role_clip(&"combat", &"BowRelease")
		"WAR_CLUB", "OBSIDIAN_CLEAVER":
			_set_role_clip(&"combat", &"ClubSmash")
		"BARBED_JAVELIN":
			_set_role_clip(&"combat", &"JavelinCast")


func sync_equipment(tier: int, armored: bool) -> void:
	if _armor != null:
		_armor.visible = armored
	var eff_tier := maxi(tier, 3) if _force_obsidian_weapon else tier
	for shader in _tier_surfaces:
		if not is_instance_valid(shader):
			continue
		var base: Color = shader.get_meta("base_tint")
		var tint := base.lightened(0.24) if eff_tier == 2 else base
		if eff_tier >= 3:
			tint = base.lerp(Color(0.11, 0.09, 0.14), 0.65)
		shader.set_shader_parameter("base_color", tint)


func _mount(skeleton: Skeleton3D, bone_name: String, slot_name: String, asset: String,
		offset: Vector3, orientation := Basis.IDENTITY) -> bool:
	return _mount_glb(skeleton, bone_name, slot_name, "%s/%s.glb" % [GEAR, asset], offset, orientation)


func _mount_glb(skeleton: Skeleton3D, bone_name: String, slot_name: String, glb_path: String,
		offset: Vector3, orientation := Basis.IDENTITY) -> bool:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return false
	var item := _instantiate_model(glb_path)
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
	var scene: PackedScene = null
	if _scene_cache.has(path):
		scene = _scene_cache[path] as PackedScene
	else:
		if not ResourceLoader.exists(path, "PackedScene"):
			return null
		scene = load(path) as PackedScene
		if scene != null:
			_scene_cache[path] = scene
	if scene == null:
		return null
	return scene.instantiate() as Node3D

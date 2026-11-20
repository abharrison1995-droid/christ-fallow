extends Node
## Procedural 3D Mesh Factory autoload facade.
## Owns gritty PSX surface textures/materials and delegates detailed asset
## assembly to HumanMeshBuilder and WorldMeshBuilder.

const HumanMeshBuilder = preload("res://scripts/core/human_mesh_builder.gd")
const WorldMeshBuilder = preload("res://scripts/core/world_mesh_builder.gd")

var _tex_stone: ImageTexture = null
var _tex_wood: ImageTexture = null
var _tex_hide: ImageTexture = null
var _tex_ground: ImageTexture = null
var _tex_skin: ImageTexture = null
var _tex_bone: ImageTexture = null


func _ready() -> void:
	_tex_stone = _gen_grit_tex(32, 101, 0.24, false)
	_tex_wood = _gen_grit_tex(32, 202, 0.22, true)
	_tex_hide = _gen_grit_tex(32, 303, 0.18, false)
	_tex_ground = _gen_grit_tex(32, 404, 0.28, false)
	_tex_skin = _gen_grit_tex(32, 505, 0.12, false)
	_tex_bone = _gen_grit_tex(32, 606, 0.16, true)


func _gen_grit_tex(sz: int, seed_val: int, variance: float, streaked: bool) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	for y in range(sz):
		for x in range(sz):
			var nx := x
			var ny := y / 3 if streaked else y
			var h := ((nx * 73856093) ^ (ny * 19349663) ^ (seed_val * 83492791)) & 0xFF
			var v := 0.88 + (float(h) / 255.0 - 0.5) * variance * 2.0
			if ((x * 13 + y * 29 + seed_val) % 19) == 0:
				v -= 0.14
			v = clampf(v, 0.58, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.95))
	return ImageTexture.create_from_image(img)


func get_gritty_texture(kind: String) -> ImageTexture:
	match kind:
		"wood":
			return _tex_wood
		"hide":
			return _tex_hide
		"ground":
			return _tex_ground
		"skin":
			return _tex_skin
		"bone":
			return _tex_bone
		_:
			return _tex_stone


func make_mat(color: Color, roughness: float = 0.92, emission: Color = Color.BLACK, emission_energy: float = 0.0, alpha: float = 1.0, tex_kind: String = "stone") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = get_gritty_texture(tex_kind)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = maxf(roughness, 0.86)
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	return mat


func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, node_name: String = "", mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	# Enforce chunky PSX low-poly faceted tessellation
	if mesh is SphereMesh:
		var sm := mesh as SphereMesh
		sm.radial_segments = 7
		sm.rings = 3
	elif mesh is CylinderMesh:
		var cm := mesh as CylinderMesh
		cm.radial_segments = 6
		cm.rings = 1
	elif mesh is CapsuleMesh:
		var cap := mesh as CapsuleMesh
		cap.radial_segments = 6
		cap.rings = 2
	elif mesh is TorusMesh:
		var tm := mesh as TorusMesh
		tm.rings = 8
		tm.ring_segments = 5

	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = mesh_scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func make_pivot(parent: Node3D, p_name: String, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var p := Node3D.new()
	p.name = p_name
	p.position = pos
	p.rotation_degrees = rot_deg
	parent.add_child(p)
	return p


func build_human_mesh(lineage: int, gender: int, faction_color: Color, is_leader: bool, is_caveman: bool, role: int = GameData.Role.FORAGER, warrior_class: int = GameData.WarriorClass.SPEARMAN, is_child: bool = false) -> Node3D:
	return HumanMeshBuilder.build_human_mesh(self, lineage, gender, faction_color, is_leader, is_caveman, role, warrior_class, is_child)


func update_human_gear(visual_root: Node3D, weapon_type: String, weapon_tier: int, has_armor: bool, is_worker_tool: bool, class_key: String = "") -> void:
	HumanMeshBuilder.update_human_gear(self, visual_root, weapon_type, weapon_tier, has_armor, is_worker_tool, class_key)


func build_building_mesh(building_type: String, faction_color: Color, is_blueprint: bool, damage_stage: int = 0) -> Node3D:
	return WorldMeshBuilder.build_building_mesh(self, building_type, faction_color, is_blueprint, damage_stage)


func build_building_stages(building_type: String, faction_color: Color, is_blueprint: bool) -> Node3D:
	return WorldMeshBuilder.build_building_stages(self, building_type, faction_color, is_blueprint)


func build_wildlife_mesh(animal_type: String) -> Node3D:
	return WorldMeshBuilder.build_wildlife_mesh(self, animal_type)


func build_resource_node_mesh(node_type: String) -> Node3D:
	return WorldMeshBuilder.build_resource_node_mesh(self, node_type)


func build_environment_mesh(asset: String) -> Node3D:
	return WorldMeshBuilder.build_environment_mesh(asset)


func build_projectile_mesh(proj_type: String, tier: int) -> Node3D:
	return WorldMeshBuilder.build_projectile_mesh(self, proj_type, tier)

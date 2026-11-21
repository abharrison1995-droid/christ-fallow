extends Node3D

const Wildlife = preload("res://scripts/entities/wildlife_entity.gd")
const Layout = preload("res://scripts/core/world_layout.gd")

var _sun_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _sky_mat: ProceduralSkyMaterial = null
var _psx_layer: CanvasLayer = null
var _psx_rect: ColorRect = null
var _brightness_mult: float = 1.25


func _ready() -> void:
	GameState.world_node = self
	_setup_containers()
	_setup_environment()
	_setup_psx_post_process()
	Preferences.changed.connect(_apply_visual_preferences)
	_apply_visual_preferences()
	_build_valley_terrain()


func _apply_visual_preferences() -> void:
	_psx_layer.visible = bool(Preferences.get_value("psx"))
	set_brightness_multiplier(float(Preferences.get_value("brightness")))


func toggle_psx_filter() -> bool:
	if _psx_layer != null:
		_psx_layer.visible = not _psx_layer.visible
		return _psx_layer.visible
	return false


func is_psx_filter_enabled() -> bool:
	return _psx_layer != null and _psx_layer.visible


func set_brightness_multiplier(mult: float) -> void:
	_brightness_mult = clampf(mult, 0.85, 1.85)
	if _psx_rect != null and _psx_rect.material is ShaderMaterial:
		(_psx_rect.material as ShaderMaterial).set_shader_parameter("brightness_boost", _brightness_mult)
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.ambient_light_energy = 0.68 * (_brightness_mult / 1.25)


func get_brightness_multiplier() -> float:
	return _brightness_mult


func _setup_psx_post_process() -> void:
	_psx_layer = CanvasLayer.new()
	_psx_layer.name = "PSXPostLayer"
	_psx_layer.layer = 1
	add_child(_psx_layer)

	_psx_rect = ColorRect.new()
	_psx_rect.name = "PSXFilterRect"
	_psx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_psx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://scripts/shaders/psx_diablo_post.gdshader") as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("brightness_boost", _brightness_mult)
		_psx_rect.material = mat
	_psx_layer.add_child(_psx_rect)


func _setup_containers() -> void:
	var c_names := ["Units", "Buildings", "Resources", "Wildlife", "Projectiles", "Factions"]
	for cname in c_names:
		var node := Node3D.new()
		node.name = cname
		add_child(node)

	GameState.units_container = get_node("Units")
	GameState.buildings_container = get_node("Buildings")
	GameState.resources_container = get_node("Resources")
	GameState.wildlife_container = get_node("Wildlife")
	GameState.projectiles_container = get_node("Projectiles")


func _setup_environment() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.24, 0.28, 0.36)
	_sky_mat.sky_horizon_color = Color(0.50, 0.44, 0.38)
	_sky_mat.ground_bottom_color = Color(0.18, 0.16, 0.14)
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.68
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.32, 0.28)
	env.fog_density = 0.0032
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.18
	_world_env.environment = env
	add_child(_world_env)

	_sun_light = DirectionalLight3D.new()
	_sun_light.shadow_enabled = true
	_sun_light.light_energy = 1.42
	_sun_light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	add_child(_sun_light)


func _process(_delta: float) -> void:
	if _sun_light == null or _sky_mat == null:
		return
	var t := GameState.time_of_day
	var sun_angle := ((t - 6.0) / 24.0) * 360.0
	_sun_light.rotation_degrees.x = -clampf(sin(deg_to_rad(sun_angle)) * 65.0 + 18.0, 12.0, 80.0)
	_sun_light.rotation_degrees.y = sun_angle * 0.45

	var env := _world_env.environment if _world_env != null else null
	if t >= 6.0 and t < 8.5:
		# Warm Dawn
		_sun_light.light_color = Color(1.0, 0.72, 0.52)
		_sun_light.light_energy = 1.10
		_sky_mat.sky_top_color = Color(0.24, 0.24, 0.34)
		_sky_mat.sky_horizon_color = Color(0.62, 0.40, 0.30)
		if env: env.fog_light_color = Color(0.38, 0.28, 0.24)
	elif t >= 8.5 and t < 17.5:
		# Clear Ash-Gold Day
		_sun_light.light_color = Color(0.98, 0.92, 0.80)
		_sun_light.light_energy = 1.42
		_sky_mat.sky_top_color = Color(0.25, 0.34, 0.44)
		_sky_mat.sky_horizon_color = Color(0.54, 0.50, 0.44)
		if env: env.fog_light_color = Color(0.38, 0.35, 0.30)
	elif t >= 17.5 and t < 20.5:
		# Amber Dusk
		_sun_light.light_color = Color(1.0, 0.54, 0.32)
		_sun_light.light_energy = 0.95
		_sky_mat.sky_top_color = Color(0.20, 0.16, 0.28)
		_sky_mat.sky_horizon_color = Color(0.64, 0.32, 0.20)
		if env: env.fog_light_color = Color(0.34, 0.22, 0.18)
	else:
		# Moonlit Night
		_sun_light.light_color = Color(0.52, 0.62, 0.88)
		_sun_light.light_energy = 0.58
		_sky_mat.sky_top_color = Color(0.08, 0.10, 0.18)
		_sky_mat.sky_horizon_color = Color(0.18, 0.20, 0.30)
		if env: env.fog_light_color = Color(0.14, 0.16, 0.22)


func _build_valley_terrain() -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)

	# Solid Ground Floor StaticBody3D
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Layout.GROUND_SIZE.x, 2.0, Layout.GROUND_SIZE.y)
	col.shape = box
	col.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(col)

	var ground_mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Layout.GROUND_SIZE
	ground_mesh_inst.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.43, 0.24)
	gmat.albedo_texture = MeshFactory.get_gritty_texture("ground")
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gmat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	gmat.uv1_scale = Vector3(120.0, 120.0, 120.0)
	gmat.roughness = 0.98
	ground_mesh_inst.material_override = gmat
	ground.add_child(ground_mesh_inst)
	terrain_root.add_child(ground)

	# Gritty biome ground patches (Ash highlands, Ochre plains, Forest woods, Fertile basin)
	_add_ground_patch(terrain_root, Vector3(0.0, 0.02, -118.0), Vector2(95.0, 80.0), Color(0.42, 0.39, 0.36))
	_add_ground_patch(terrain_root, Vector3(118.0, 0.02, -18.0), Vector2(85.0, 85.0), Color(0.50, 0.44, 0.24))
	_add_ground_patch(terrain_root, Vector3(-118.0, 0.02, -12.0), Vector2(85.0, 85.0), Color(0.26, 0.38, 0.22))
	_add_ground_patch(terrain_root, Vector3(58.0, 0.02, 112.0), Vector2(85.0, 80.0), Color(0.30, 0.45, 0.24))

	# Valley River running North-West to South-East
	var river := MeshInstance3D.new()
	var rmesh := PlaneMesh.new()
	rmesh.size = Vector2(Layout.RIVER_WIDTH, Layout.RIVER_LENGTH)
	river.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.20, 0.44, 0.62, 0.90)
	rmat.albedo_texture = MeshFactory.get_gritty_texture("stone")
	rmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rmat.uv1_scale = Vector3(4.0, 80.0, 1.0)
	rmat.roughness = 0.42
	river.material_override = rmat
	river.position = Vector3(Layout.RIVER_CENTER.x, 0.04, Layout.RIVER_CENTER.z)
	river.rotation_degrees.y = Layout.RIVER_ROTATION_Y_DEG
	terrain_root.add_child(river)
	_add_riverbank_reeds(terrain_root, river.transform)
	_add_river_fords(terrain_root)

	# Jagged PSX Slate Mountain Rim Crags
	var peak_mat := StandardMaterial3D.new()
	peak_mat.albedo_color = Color(0.34, 0.32, 0.30)
	peak_mat.albedo_texture = MeshFactory.get_gritty_texture("stone")
	peak_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	peak_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	peak_mat.uv1_scale = Vector3(4.0, 4.0, 4.0)
	peak_mat.roughness = 0.96
	for i in range(44):
		var ang := float(i) * TAU / 44.0
		var r := Layout.MOUNTAIN_RIM_RADIUS + randf_range(-4.0, 6.0)
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.radial_segments = 5
		cone.rings = 1
		cone.top_radius = randf_range(0.8, 3.2)
		cone.bottom_radius = randf_range(14.0, 22.0)
		cone.height = randf_range(20.0, 36.0)
		peak.mesh = cone
		peak.material_override = peak_mat
		peak.position = Vector3(cos(ang) * r, cone.height * 0.45, sin(ang) * r)
		peak.rotation_degrees.y = randf_range(0.0, 360.0)
		terrain_root.add_child(peak)


## Flat stone-and-log crossings on the river axis; they sit at y = 0.07 so units walk over them.
func _add_river_fords(parent: Node3D) -> void:
	var fords := Node3D.new()
	fords.name = "RiverFords"
	parent.add_child(fords)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.46, 0.43, 0.38)
	stone_mat.albedo_texture = MeshFactory.get_gritty_texture("stone")
	stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	stone_mat.roughness = 0.95
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.36, 0.25, 0.15)
	log_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	log_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	log_mat.roughness = 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var yaw: float = deg_to_rad(Layout.RIVER_ROTATION_Y_DEG)
	for local_z in Layout.RIVER_FORD_LOCAL_Z:
		var ford := Node3D.new()
		ford.position = Layout.river_point(local_z) + Vector3(0.0, 0.07, 0.0)
		ford.rotation.y = yaw
		fords.add_child(ford)
		# Shallow gravel bed across the river
		var bed := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(Layout.RIVER_WIDTH + 5.0, 0.05, 11.0)
		bed.mesh = bed_mesh
		bed.material_override = stone_mat
		ford.add_child(bed)
		# Flat stepping slabs and two log rails along the crossing direction
		for i in range(9):
			var slab := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(rng.randf_range(1.3, 2.1), 0.07, rng.randf_range(1.1, 1.9))
			slab.mesh = sm
			slab.material_override = stone_mat
			slab.position = Vector3(-6.4 + float(i) * 1.6, 0.05, rng.randf_range(-3.6, 3.6))
			slab.rotation.y = rng.randf_range(-0.5, 0.5)
			ford.add_child(slab)
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(Layout.RIVER_WIDTH + 4.0, 0.12, 0.38)
			rail.mesh = rm
			rail.material_override = log_mat
			rail.position = Vector3(0.0, 0.06, float(side) * 5.2)
			ford.add_child(rail)


func _add_riverbank_reeds(parent: Node3D, river_transform: Transform3D) -> void:
	var template := MeshFactory.build_environment_mesh("riverbank_reeds")
	if template == null:
		return
	var beds := Node3D.new()
	beds.name = "RiverbankReeds"
	parent.add_child(beds)
	# Reproduce the same decorative beds on each launch without consuming the campaign RNG.
	var rng := RandomNumberGenerator.new()
	rng.seed = 64903
	for bank in [-1, 1]:
		for z in range(-135, 146, 14):
			var patch := template.duplicate() as Node3D
			patch.position = river_transform * Vector3(float(bank) * rng.randf_range(5.7, 6.8),
				-0.04, float(z) + rng.randf_range(-4.0, 4.0))
			patch.rotation.y = rng.randf_range(0.0, TAU)
			patch.scale = Vector3.ONE * rng.randf_range(0.75, 1.25)
			beds.add_child(patch)
	template.free()


func _add_ground_patch(parent: Node3D, pos: Vector3, sz: Vector2, col: Color) -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = sz
	p.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = MeshFactory.get_gritty_texture("ground")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.uv1_scale = Vector3(28.0, 28.0, 28.0)
	m.roughness = 0.98
	p.material_override = m
	p.position = pos
	parent.add_child(p)


func populate_new_world() -> void:
	_clear_dynamic_world()
	_create_faction_controllers()
	_spawn_resources_and_caves()
	_spawn_wildlife()
	_spawn_player_awakening()
	_spawn_rival_colonies()
	GameState.rebuild_spatial_systems()


func _clear_containers(containers: Array) -> void:
	for container in containers:
		if container != null:
			for c in container.get_children():
				container.remove_child(c)
				c.queue_free()


func _clear_dynamic_world() -> void:
	_clear_containers([
		GameState.units_container,
		GameState.buildings_container,
		GameState.resources_container,
		GameState.wildlife_container,
		GameState.projectiles_container,
		get_node_or_null("Factions"),
	])
	GameState.faction_controllers.clear()
	GameState.clear_spatial_systems()


func _create_faction_controllers() -> void:
	var fc_script := load("res://scripts/systems/faction_controller.gd")
	var f_node := get_node("Factions")
	for fid in range(7):
		var fc := Node.new()
		fc.name = "Faction_%d" % fid
		fc.set_script(fc_script)
		f_node.add_child(fc)
		fc.setup(fid)
		GameState.faction_controllers[fid] = fc


func _spawn_resources_and_caves() -> void:
	# Starter resource cluster around player awakening glade (0, 0, 52)
	_spawn_resource_cluster(Vector3(0.0, 0.0, 52.0), 14.0, 28.0, 6, 4, 3, 5)
	# Rival region resources
	_spawn_resource_cluster(Vector3(0.0, 0.0, -118.0), 16.0, 32.0, 6, 6, 4, 4)
	_spawn_resource_cluster(Vector3(118.0, 0.0, -18.0), 16.0, 32.0, 6, 4, 4, 5)
	_spawn_resource_cluster(Vector3(-118.0, 0.0, -12.0), 16.0, 32.0, 8, 4, 3, 5)
	_spawn_resource_cluster(Vector3(58.0, 0.0, 112.0), 16.0, 32.0, 6, 5, 3, 6)

	# Scattered wilderness groves & flint crags
	for i in range(45):
		var pos := Vector3(randf_range(-Layout.SCATTER_HALF_EXTENT, Layout.SCATTER_HALF_EXTENT), 0.0, randf_range(-Layout.SCATTER_HALF_EXTENT, Layout.SCATTER_HALF_EXTENT))
		var r := randf()
		var ntype := "TREE"
		if r < 0.42:
			ntype = "TREE"
		elif r < 0.65:
			ntype = "STONE"
		elif r < 0.82:
			ntype = "FLINT"
		else:
			ntype = "BERRY_BUSH"
		_spawn_resource_node(ntype, pos)

	# 3 Wilderness Bone-Caves for Nomadic Cavemen
	var cave_positions := [
		Vector3(-125.0, 0.0, 115.0),
		Vector3(128.0, 0.0, 108.0),
		Vector3(-82.0, 0.0, -122.0),
	]
	for cp in cave_positions:
		_spawn_resource_node("CAVEMAN_CAVE", cp)


func _spawn_resource_cluster(center: Vector3, min_r: float, max_r: float, trees: int, stones: int, flints: int, berries: int) -> void:
	for i in range(trees):
		_spawn_resource_node("TREE", _rand_ring(center, min_r, max_r))
	for i in range(stones):
		_spawn_resource_node("STONE", _rand_ring(center, min_r, max_r))
	for i in range(flints):
		_spawn_resource_node("FLINT", _rand_ring(center, min_r, max_r))
	for i in range(berries):
		_spawn_resource_node("BERRY_BUSH", _rand_ring(center, min_r, max_r))


func _rand_ring(center: Vector3, min_r: float, max_r: float) -> Vector3:
	var ang := randf_range(0.0, TAU)
	var d := randf_range(min_r, max_r)
	return center + Vector3(cos(ang) * d, 0.0, sin(ang) * d)


func _spawn_resource_node(ntype: String, pos: Vector3) -> void:
	var n := MeshFactory.build_resource_node_mesh(ntype)
	n.position = pos
	n.rotation_degrees.y = randf_range(0.0, 360.0)
	n.set_meta("node_type", ntype)
	GameState.resources_container.add_child(n)


func _spawn_wildlife() -> void:
	var spawns := [
		{"type": "DEER", "pos": Vector3(24.0, 0.0, 40.0), "count": 4},
		{"type": "DEER", "pos": Vector3(-30.0, 0.0, 36.0), "count": 4},
		{"type": "BOAR", "pos": Vector3(28.0, 0.0, 74.0), "count": 3},
		{"type": "BOAR", "pos": Vector3(-55.0, 0.0, 60.0), "count": 2},
		{"type": "SLATEBACK_BOAR", "pos": Vector3(-55.0, 0.0, 60.0), "count": 1},
		{"type": "WOLF", "pos": Vector3(-78.0, 0.0, 38.0), "count": 3},
		{"type": "WOLF", "pos": Vector3(72.0, 0.0, -58.0), "count": 2},
		{"type": "REEDJAW", "pos": Layout.river_point(-120.0) + Vector3(18.0, 0.0, 0.0), "count": 1},
		{"type": "SABERTOOTH", "pos": Vector3(-55.0, 0.0, -68.0), "count": 2},
		{"type": "MAMMOTH", "pos": Vector3(0.0, 0.0, -45.0), "count": 1},
		{"type": "MAMMOTH", "pos": Vector3(-84.0, 0.0, 68.0), "count": 1},
		{"type": "CAVE_BEAR", "pos": Vector3(74.0, 0.0, 48.0), "count": 1},
	]
	for s in spawns:
		for i in range(int(s["count"])):
			var p: Vector3 = s["pos"] + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
			_spawn_animal(s["type"], p)


func _spawn_animal(animal_type: String, pos: Vector3) -> CharacterBody3D:
	var animal := Wildlife.new()
	GameState.wildlife_container.add_child(animal)
	animal.setup(animal_type, pos)
	return animal


func _spawn_player_awakening() -> void:
	var fc0 = GameState.faction_controllers[0]
	var f0: Dictionary = GameState.factions[0]
	var start_pos: Vector3 = f0["camp_position"]
	var leader = fc0.spawn_colonist(start_pos, f0["primary_lineage"], GameData.Gender.MALE, GameData.Role.WARRIOR, true, false, false, f0["leader_name"])

	if GameState.player_controller != null:
		GameState.player_controller.setup(leader)

	# Spawn wild local men & women around the awakening glade waiting to be recruited
	var u_script := load("res://scripts/entities/human_unit.gd")
	var wanderer_configs := [
		{"offset": Vector3(-5.0, 0.0, -4.0), "gender": GameData.Gender.FEMALE, "lineage": f0["primary_lineage"]},
		{"offset": Vector3(5.5, 0.0, -3.5), "gender": GameData.Gender.MALE, "lineage": f0["primary_lineage"]},
		{"offset": Vector3(-7.0, 0.0, 4.0), "gender": GameData.Gender.FEMALE, "lineage": GameData.Lineage.ASH_WALKER},
		{"offset": Vector3(6.0, 0.0, 5.0), "gender": GameData.Gender.MALE, "lineage": GameData.Lineage.FEN_TIDAL},
		{"offset": Vector3(0.0, 0.0, -7.5), "gender": GameData.Gender.FEMALE, "lineage": GameData.Lineage.STALKER},
		{"offset": Vector3(-3.0, 0.0, 7.0), "gender": GameData.Gender.MALE, "lineage": GameData.Lineage.CRAG_BORN},
	]
	for wc in wanderer_configs:
		var u := CharacterBody3D.new()
		u.set_script(u_script)
		GameState.units_container.add_child(u)
		u.setup({
			"faction_id": -1,
			"pos": start_pos + wc["offset"],
			"gender": wc["gender"],
			"lineage": wc["lineage"],
			"role": GameData.Role.FORAGER,
		})


func _spawn_rival_colonies() -> void:
	for fid in range(1, 5):
		var fdata: Dictionary = GameState.factions[fid]
		var fc = GameState.faction_controllers[fid]
		var camp: Vector3 = fdata["camp_position"]
		var lin: int = int(fdata["primary_lineage"])
		var spec: int = int(fdata["weapon_specialty"])

		# Core buildings
		fc.spawn_building("CAMPFIRE", camp, 0.0, true)
		fc.spawn_building("SACRED_TOTEM", camp + Vector3(0.0, 0.0, -6.0), 0.0, true)
		fc.spawn_building("SLEEPING_HUT", camp + Vector3(-8.0, 0.0, -3.0), 0.4, true)
		fc.spawn_building("SLEEPING_HUT", camp + Vector3(8.0, 0.0, -3.0), -0.4, true)
		fc.spawn_building("CRAFTING_PIT", camp + Vector3(-6.0, 0.0, 6.0), 0.0, true)
		fc.spawn_building("WEAPON_RACK", camp + Vector3(6.0, 0.0, 6.0), 0.0, true)
		fc.spawn_building("PALISADE_WALL", camp + Vector3(0.0, 0.0, 12.0), 0.0, true)
		fc.spawn_building("PALISADE_WALL", camp + Vector3(-11.0, 0.0, 8.0), 0.7, true)
		fc.spawn_building("PALISADE_WALL", camp + Vector3(11.0, 0.0, 8.0), -0.7, true)
		if fid == 4:
			fc.spawn_building("WATCHTOWER", camp + Vector3(-7.0, 0.0, 11.0), 0.0, true)

		# Leader + 4 Warriors (including Brutes & Javelineers) + 4 Citizens
		fc.spawn_colonist(camp + Vector3(0.0, 0.0, 2.5), lin, GameData.Gender.MALE, GameData.Role.WARRIOR, true, false, false, fdata["leader_name"])
		for w_i in range(4):
			var w: Node = fc.spawn_colonist(camp + Vector3(-4.5 + float(w_i) * 3.0, 0.0, 5.0), lin, GameData.Gender.MALE if w_i % 2 == 0 else GameData.Gender.FEMALE, GameData.Role.WARRIOR, false)
			var w_cls: int = spec
			if w_i == 2:
				w_cls = GameData.WarriorClass.BRUTE if fid == 1 else GameData.WarriorClass.JAVELINEER
			elif w_i == 3:
				w_cls = GameData.WarriorClass.ARCHER if spec != GameData.WarriorClass.ARCHER else GameData.WarriorClass.SPEARMAN
			w.set_role_and_class(GameData.Role.WARRIOR, w_cls)
		var citizen_roles := [GameData.Role.FORAGER, GameData.Role.LUMBERJACK, GameData.Role.STONEKNAPPER, GameData.Role.SHAMAN]
		for c_i in range(4):
			fc.spawn_colonist(camp + Vector3(-4.5 + float(c_i) * 3.0, 0.0, -2.5), lin, GameData.Gender.FEMALE if c_i % 2 == 0 else GameData.Gender.MALE, citizen_roles[c_i], false)


func restore_from_save(save: Dictionary, starting_campaign: bool) -> void:
	if GameState.player_controller != null:
		GameState.player_controller.exit_build_mode()
		GameState.player_controller.attach_leader(null)
	if starting_campaign:
		_clear_dynamic_world()
		_create_faction_controllers()
		_spawn_resources_and_caves()
	else:
		_clear_containers([
			GameState.units_container,
			GameState.buildings_container,
			GameState.wildlife_container,
			GameState.projectiles_container,
		])

	for fid in GameState.faction_controllers.keys():
		var fc: Node = GameState.faction_controllers[fid]
		if is_instance_valid(fc) and fc.has_method("restore_from_save"):
			var fdata: Dictionary = GameState.factions.get(int(fid), {})
			fc.restore_from_save(fdata)

	if save.has("wildlife"):
		for entry in save["wildlife"]:
			var animal := _spawn_animal(entry["animal_type"], entry["pos"])
			animal.restore_snapshot(entry)
	else:
		_spawn_wildlife()

	var b_script := load("res://scripts/entities/building_entity.gd")
	for bd in save["buildings"]:
		var b := StaticBody3D.new()
		b.set_script(b_script)
		GameState.buildings_container.add_child(b)
		b.restore_snapshot(bd)

	var u_script := load("res://scripts/entities/human_unit.gd")
	var leader: CharacterBody3D = null
	for ud in save["units"]:
		var u := CharacterBody3D.new()
		u.set_script(u_script)
		GameState.units_container.add_child(u)
		u.restore_snapshot(ud)
		if u.faction_id == 0 and u.is_leader:
			leader = u
	GameState.rebuild_spatial_systems()
	if leader == null and not GameState.get_faction_units(0, true).is_empty():
		var fc0: Node = GameState.faction_controllers.get(0)
		if is_instance_valid(fc0) and fc0.has_method("handle_player_leader_death"):
			fc0.handle_player_leader_death(null)
			leader = GameState.get_faction_leader(0) as CharacterBody3D
	if GameState.player_controller != null:
		GameState.player_controller.setup(leader)
		var pc_data: Dictionary = save.get("player_controller", {})
		if not pc_data.has("blessing_cooldown") and GameState.factions.has(0):
			pc_data = {"blessing_cooldown": float(GameState.factions[0].get("blessing_cooldown", 0.0))}
		if GameState.player_controller.has_method("restore_from_save"):
			GameState.player_controller.restore_from_save(pc_data)

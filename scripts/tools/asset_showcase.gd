extends Node3D

const DEFAULT_OUT_DIR := "<USERPROFILE>/.gemini/antigravity/brain/25bfd11b-d070-4027-8aaf-08069c9fcc2b/scratch"
const TribesmanAnimator = preload("res://scripts/entities/tribesman_animator.gd")

var _out_dir: String = DEFAULT_OUT_DIR
var _cam: Camera3D = null
var _stage: Node3D = null
var _ui_layer: CanvasLayer = null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.substr("--out-dir=".length())
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_setup_env_and_ground()
	_setup_psx_shader()
	_setup_camera()
	_setup_containers()
	call_deferred("_run_showcase")


func _setup_env_and_ground() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var smat := ProceduralSkyMaterial.new()
	smat.sky_top_color = Color(0.11, 0.08, 0.12)
	smat.sky_horizon_color = Color(0.38, 0.19, 0.14)
	smat.ground_bottom_color = Color(0.06, 0.05, 0.04)
	sky.sky_material = smat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.68
	env.fog_enabled = true
	env.fog_light_color = Color(0.26, 0.22, 0.19)
	env.fog_density = 0.0032
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.22
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 1.42
	sun.rotation_degrees = Vector3(-40.0, 32.0, 0.0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.28, 0.30, 0.20)
	gmat.albedo_texture = MeshFactory.get_gritty_texture("ground")
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gmat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	gmat.uv1_scale = Vector3(72.0, 72.0, 72.0)
	gmat.roughness = 0.98
	ground.material_override = gmat
	add_child(ground)

	# Atmospheric mountain ring in background
	var peak_mat := StandardMaterial3D.new()
	peak_mat.albedo_color = Color(0.15, 0.13, 0.13)
	peak_mat.albedo_texture = MeshFactory.get_gritty_texture("stone")
	peak_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	peak_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for i in range(28):
		var ang := float(i) * TAU / 28.0
		var cone := CylinderMesh.new()
		cone.radial_segments = 5
		cone.rings = 1
		cone.top_radius = 1.5
		cone.bottom_radius = 14.0
		cone.height = 24.0 + float(i % 3) * 6.0
		var pk := MeshInstance3D.new()
		pk.mesh = cone
		pk.material_override = peak_mat
		pk.position = Vector3(cos(ang) * 78.0, cone.height * 0.45, sin(ang) * 78.0)
		add_child(pk)


func _setup_psx_shader() -> void:
	var psx := CanvasLayer.new()
	psx.name = "PSXPostLayer"
	psx.layer = 1
	add_child(psx)

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://scripts/shaders/psx_diablo_post.gdshader") as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
	psx.add_child(rect)


func _setup_camera() -> void:
	_cam = Camera3D.new()
	_cam.far = 250.0
	_cam.fov = 52.0
	add_child(_cam)
	_cam.current = true


func _setup_containers() -> void:
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)

	var units := Node3D.new()
	units.name = "Units"
	add_child(units)
	GameState.units_container = units

	var buildings := Node3D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	GameState.buildings_container = buildings

	var resources := Node3D.new()
	resources.name = "Resources"
	add_child(resources)
	GameState.resources_container = resources

	var wildlife := Node3D.new()
	wildlife.name = "Wildlife"
	add_child(wildlife)
	GameState.wildlife_container = wildlife


func _clear_stage() -> void:
	for parent in [_stage, GameState.units_container, GameState.buildings_container, GameState.resources_container, GameState.wildlife_container]:
		if parent != null:
			for c in parent.get_children():
				c.queue_free()


func _add_torch_light(pos: Vector3, energy: float = 2.6, range_m: float = 16.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.22)
	light.light_energy = energy
	light.omni_range = range_m
	light.position = pos
	_stage.add_child(light)


func _capture(filename: String, cam_pos: Vector3, look_pos: Vector3) -> void:
	_cam.global_position = cam_pos
	_cam.look_at(look_pos, Vector3.UP)
	for _i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var full_path := _out_dir + "/" + filename
	var err := img.save_png(full_path)
	print("Saved screenshot: ", full_path, " status=", err)


func _add_stage_label(pos: Vector3, text_str: String) -> void:
	var lbl := Label3D.new()
	lbl.text = text_str
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 20
	lbl.pixel_size = 0.013
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.05, 0.03, 0.02, 1.0)
	lbl.modulate = Color(1.0, 0.90, 0.55)
	lbl.position = pos
	_stage.add_child(lbl)


func _spawn_showcase_human(pos: Vector3, rot_y: float, lineage: int, gender: int, fid: int, is_leader: bool, is_caveman: bool, w_type: String, tier: int, armored: bool, role: int = GameData.Role.WARRIOR, w_class: int = GameData.WarriorClass.SPEARMAN, is_child: bool = false, pose_anim: String = "IDLE", pose_t: float = 0.0, label_txt: String = "") -> Node3D:
	var col: Color = GameData.FACTION_COLORS.get(fid, Color.WHITE)
	var mesh: Node3D = MeshFactory.build_human_mesh(lineage, gender, col, is_leader, is_caveman, role, w_class, is_child)
	mesh.position = pos
	mesh.rotation_degrees.y = rot_y
	var class_key := GameData.resolve_class_key(role, w_class, is_leader, is_caveman, false)
	MeshFactory.update_human_gear(mesh, w_type, tier, armored, w_type == "TOOL", class_key)
	var anim := TribesmanAnimator.new()
	var eff_lin := GameData.resolve_effective_lineage(lineage, is_caveman)
	var hunch := float(GameData.LINEAGE_DATA[eff_lin].get("spine_hunch", 0.0))
	anim.bind(mesh, hunch)
	var stance := str(GameData.CLASS_DEFINITIONS.get(class_key, {}).get("idle_stance", "RELAXED"))
	anim.set_preview_pose(pose_anim, pose_t, stance)
	_stage.add_child(mesh)
	if label_txt != "":
		_add_stage_label(pos + Vector3(0.0, 2.75 if lineage != GameData.Lineage.GOLIATH else 3.25, 0.0), label_txt)
	return mesh


func _run_showcase() -> void:
	GameState.initialize_new_campaign("Enoch", "Fallow Chosen", GameData.Lineage.CRAG_BORN)

	# 1. All 7 Races Lineup
	_clear_stage()
	_add_torch_light(Vector3(0.0, 4.0, 6.0), 3.0, 24.0)
	var race_specs := [
		{"lin": GameData.Lineage.GOLIATH, "g": GameData.Gender.MALE, "fid": 1, "cav": false, "lbl": "Goliath"},
		{"lin": GameData.Lineage.SWIFT_KIN, "g": GameData.Gender.FEMALE, "fid": 3, "cav": false, "lbl": "Swift-Kin"},
		{"lin": GameData.Lineage.STALKER, "g": GameData.Gender.FEMALE, "fid": 2, "cav": false, "lbl": "Stalker"},
		{"lin": GameData.Lineage.CRAG_BORN, "g": GameData.Gender.MALE, "fid": 4, "cav": false, "lbl": "Crag-Born"},
		{"lin": GameData.Lineage.ASH_WALKER, "g": GameData.Gender.MALE, "fid": 0, "cav": false, "lbl": "Ash-Born"},
		{"lin": GameData.Lineage.FEN_TIDAL, "g": GameData.Gender.FEMALE, "fid": 0, "cav": false, "lbl": "Fen-Tidal"},
		{"lin": GameData.Lineage.CAVEMAN, "g": GameData.Gender.MALE, "fid": 5, "cav": true, "lbl": "Cave-Kin"},
	]
	for idx in range(race_specs.size()):
		var rs: Dictionary = race_specs[idx]
		var x := -6.3 + float(idx) * 2.1
		_spawn_showcase_human(Vector3(x, 0.0, 0.0), 175.0, rs["lin"], rs["g"], rs["fid"], false, rs["cav"], "SPEAR", 2, false, GameData.Role.WARRIOR, GameData.WarriorClass.SPEARMAN, false, "IDLE", 0.0, rs["lbl"])
	await _capture("01_races_lineup.png", Vector3(0.0, 2.7, 9.8), Vector3(0.0, 1.2, 0.0))

	# 2. Combat, Leader & Mystic Classes
	_clear_stage()
	_add_torch_light(Vector3(0.0, 4.0, 6.0), 3.0, 24.0)
	var combat_specs := [
		{"lin": GameData.Lineage.CRAG_BORN, "ldr": true, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "fid": 0, "lbl": "Warchief"},
		{"lin": GameData.Lineage.GOLIATH, "ldr": false, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "fid": 1, "lbl": "Spearman"},
		{"lin": GameData.Lineage.SWIFT_KIN, "ldr": false, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.KNIFE_RAIDER, "fid": 3, "lbl": "Knife-Raider"},
		{"lin": GameData.Lineage.STALKER, "ldr": false, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.ARCHER, "fid": 2, "lbl": "Archer"},
		{"lin": GameData.Lineage.GOLIATH, "ldr": false, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.BRUTE, "fid": 1, "lbl": "Club Brute"},
		{"lin": GameData.Lineage.FEN_TIDAL, "ldr": false, "cav": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.JAVELINEER, "fid": 4, "lbl": "Javelineer"},
		{"lin": GameData.Lineage.ASH_WALKER, "ldr": false, "cav": false, "r": GameData.Role.SHAMAN, "wc": GameData.WarriorClass.SPEARMAN, "fid": 0, "lbl": "Shaman"},
	]
	for idx in range(combat_specs.size()):
		var cs: Dictionary = combat_specs[idx]
		var x := -6.3 + float(idx) * 2.1
		_spawn_showcase_human(Vector3(x, 0.0, 0.0), 162.0, cs["lin"], GameData.Gender.MALE if idx % 2 == 0 else GameData.Gender.FEMALE, cs["fid"], cs["ldr"], cs["cav"], "SPEAR", 3, true, cs["r"], cs["wc"], false, "IDLE", 0.0, cs["lbl"])
	await _capture("02_warrior_and_leader_classes.png", Vector3(0.0, 2.8, 10.0), Vector3(0.0, 1.2, 0.0))

	# 3. Specialist & Civilian Classes + Child
	_clear_stage()
	_add_torch_light(Vector3(0.0, 4.0, 6.0), 3.0, 24.0)
	var civ_specs := [
		{"lin": GameData.Lineage.STALKER, "r": GameData.Role.HUNTER, "ch": false, "lbl": "Hunter"},
		{"lin": GameData.Lineage.FEN_TIDAL, "r": GameData.Role.FORAGER, "ch": false, "lbl": "Forager"},
		{"lin": GameData.Lineage.CRAG_BORN, "r": GameData.Role.LUMBERJACK, "ch": false, "lbl": "Woodcutter"},
		{"lin": GameData.Lineage.ASH_WALKER, "r": GameData.Role.STONEKNAPPER, "ch": false, "lbl": "Stoneknapper"},
		{"lin": GameData.Lineage.CRAG_BORN, "r": GameData.Role.BUILDER_CRAFTER, "ch": false, "lbl": "Builder"},
		{"lin": GameData.Lineage.SWIFT_KIN, "r": GameData.Role.TRAINEE, "ch": false, "lbl": "Trainee"},
		{"lin": GameData.Lineage.CRAG_BORN, "r": GameData.Role.FORAGER, "ch": true, "lbl": "Child"},
	]
	for idx in range(civ_specs.size()):
		var vs: Dictionary = civ_specs[idx]
		var x := -6.6 + float(idx) * 2.2
		_spawn_showcase_human(Vector3(x, 0.0, 0.0), 160.0, vs["lin"], GameData.Gender.FEMALE if idx % 2 == 1 else GameData.Gender.MALE, 0, false, false, "TOOL", 2, false, vs["r"], GameData.WarriorClass.SPEARMAN, vs["ch"], "IDLE", 0.0, vs["lbl"])
	await _capture("03_civilian_and_worker_classes.png", Vector3(0.0, 2.7, 10.2), Vector3(0.0, 1.1, 0.0))

	# 4. Attack Animations (Mid-Strike Keyframes)
	_clear_stage()
	_add_torch_light(Vector3(0.0, 4.0, 6.0), 3.0, 24.0)
	var atk_specs := [
		{"lin": GameData.Lineage.GOLIATH, "ldr": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "anim": "SPEAR_THRUST", "t": 0.50, "lbl": "Spear Thrust"},
		{"lin": GameData.Lineage.SWIFT_KIN, "ldr": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.KNIFE_RAIDER, "anim": "DUAL_SLASH", "t": 0.62, "lbl": "Dual Slash"},
		{"lin": GameData.Lineage.STALKER, "ldr": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.ARCHER, "anim": "BOW_SHOT", "t": 0.48, "lbl": "Bow Draw"},
		{"lin": GameData.Lineage.GOLIATH, "ldr": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.BRUTE, "anim": "HEAVY_SMASH", "t": 0.56, "lbl": "Club Smash"},
		{"lin": GameData.Lineage.FEN_TIDAL, "ldr": false, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.JAVELINEER, "anim": "JAVELIN_THROW", "t": 0.34, "lbl": "Javelin Hurl"},
		{"lin": GameData.Lineage.CRAG_BORN, "ldr": true, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "anim": "LEADER_CLEAVE", "t": 0.45, "lbl": "Warchief Cleave"},
		{"lin": GameData.Lineage.ASH_WALKER, "ldr": false, "r": GameData.Role.SHAMAN, "wc": GameData.WarriorClass.SPEARMAN, "anim": "SHAMAN_CAST", "t": 0.52, "lbl": "Shaman Cast"},
	]
	for idx in range(atk_specs.size()):
		var ak: Dictionary = atk_specs[idx]
		var x := -6.6 + float(idx) * 2.2
		_spawn_showcase_human(Vector3(x, 0.0, 0.0), 145.0, ak["lin"], GameData.Gender.MALE, 0 if idx % 2 == 0 else 1, ak["ldr"], false, "SPEAR", 3, true, ak["r"], ak["wc"], false, ak["anim"], ak["t"], ak["lbl"])
	await _capture("04_attack_animations.png", Vector3(0.0, 2.9, 10.6), Vector3(0.0, 1.2, 0.0))

	# 5. Damage & Death Animations
	_clear_stage()
	_add_torch_light(Vector3(0.0, 4.0, 6.0), 3.0, 24.0)
	var dd_specs := [
		{"lin": GameData.Lineage.CRAG_BORN, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "cav": false, "anim": "DAMAGE_SHIELD", "t": 0.45, "lbl": "Shield Hit"},
		{"lin": GameData.Lineage.STALKER, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.ARCHER, "cav": false, "anim": "DAMAGE_LIGHT", "t": 0.45, "lbl": "Hit Flinch"},
		{"lin": GameData.Lineage.ASH_WALKER, "r": GameData.Role.SHAMAN, "wc": GameData.WarriorClass.SPEARMAN, "cav": false, "anim": "DAMAGE_HEAVY", "t": 0.45, "lbl": "Heavy Stagger"},
		{"lin": GameData.Lineage.CRAG_BORN, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.SPEARMAN, "cav": false, "anim": "DEATH_BACKWARD_STAGGER", "t": 0.95, "lbl": "Death Back"},
		{"lin": GameData.Lineage.CAVEMAN, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.BRUTE, "cav": true, "anim": "DEATH_KNEE_CRUMPLE", "t": 0.95, "lbl": "Death Crumple"},
		{"lin": GameData.Lineage.SWIFT_KIN, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.KNIFE_RAIDER, "cav": false, "anim": "DEATH_SIDE_COLLAPSE", "t": 0.95, "lbl": "Death Side"},
	]
	for idx in range(dd_specs.size()):
		var ds: Dictionary = dd_specs[idx]
		var x := -6.0 + float(idx) * 2.4
		_spawn_showcase_human(Vector3(x, 0.0, 0.0), 155.0, ds["lin"], GameData.Gender.MALE, 1 if idx >= 3 else 0, false, ds["cav"], "SPEAR", 2, idx == 0, ds["r"], ds["wc"], false, ds["anim"], ds["t"], ds["lbl"])
	await _capture("05_damage_and_death_animations.png", Vector3(0.0, 3.2, 10.6), Vector3(0.0, 0.9, 0.0))

	# 6. Full Live In-Game HUD + Awakening + PSX Viewport
	_clear_stage()
	GameState.is_paused = true
	GameState.tutorial_step = 3
	GameState.factions[0]["is_founded"] = true
	GameState.factions[0]["camp_position"] = Vector3.ZERO
	var b_script: Script = load("res://scripts/entities/building_entity.gd")
	var u_script: Script = load("res://scripts/entities/human_unit.gd")

	var campfire := StaticBody3D.new()
	campfire.set_script(b_script)
	GameState.buildings_container.add_child(campfire)
	campfire.setup("CAMPFIRE", 0, Vector3(0.0, 0.0, 0.0), 0.0, true)

	var p_leader := CharacterBody3D.new()
	p_leader.set_script(u_script)
	GameState.units_container.add_child(p_leader)
	p_leader.setup({
		"faction_id": 0,
		"pos": Vector3(0.0, 0.0, 2.8),
		"lineage": GameData.Lineage.ASH_WALKER,
		"gender": GameData.Gender.MALE,
		"role": GameData.Role.WARRIOR,
		"is_leader": true,
		"is_player_controlled": true,
		"weapon_tier": 3,
		"has_armor": true,
		"unit_name": "Enoch",
	})

	var inspected_target: Node = null
	var squad_configs := [
		{"lin": GameData.Lineage.GOLIATH, "g": GameData.Gender.MALE, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.BRUTE},
		{"lin": GameData.Lineage.FEN_TIDAL, "g": GameData.Gender.FEMALE, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.JAVELINEER},
		{"lin": GameData.Lineage.STALKER, "g": GameData.Gender.FEMALE, "r": GameData.Role.WARRIOR, "wc": GameData.WarriorClass.ARCHER},
		{"lin": GameData.Lineage.ASH_WALKER, "g": GameData.Gender.MALE, "r": GameData.Role.SHAMAN, "wc": GameData.WarriorClass.SPEARMAN},
	]
	for idx in range(squad_configs.size()):
		var sc: Dictionary = squad_configs[idx]
		var col_u := CharacterBody3D.new()
		col_u.set_script(u_script)
		GameState.units_container.add_child(col_u)
		col_u.setup({
			"faction_id": 0,
			"pos": Vector3(-3.0 + float(idx) * 2.0, 0.0, 5.2),
			"lineage": sc["lin"],
			"gender": sc["g"],
			"role": sc["r"],
			"warrior_class": sc["wc"],
			"weapon_tier": 3,
			"has_armor": idx < 2,
		})
		if idx == 0:
			inspected_target = col_u

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 2
	add_child(_ui_layer)
	var hud_scene: PackedScene = load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud: Control = hud_scene.instantiate() as Control
	_ui_layer.add_child(hud)
	var awakening := preload("res://scripts/ui/awakening_screen.gd").new()
	awakening.theme = preload("res://scripts/ui/fallow_theme.gd").create()
	_ui_layer.add_child(awakening)
	await _capture("06_awakening_6_races.png", Vector3(0.0, 7.2, 12.5), Vector3(0.0, 1.2, 1.5))

	_ui_layer.remove_child(awakening)
	awakening.queue_free()
	hud.activate_campaign()
	if inspected_target != null:
		hud.inspect_unit(inspected_target)
	await _capture("07_full_game_hud_view.png", Vector3(0.0, 7.2, 12.5), Vector3(0.0, 1.2, 1.5))
	get_tree().quit(0)

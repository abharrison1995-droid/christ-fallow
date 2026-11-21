extends SceneTree
## Run on a clean Forward+ import with -- --out-dir=<absolute directory>.

const Layout = preload("res://scripts/core/world_layout.gd")
const POST_SHADER = preload("res://scripts/shaders/psx_diablo_post.gdshader")
const SCENERY := {"windbent_pine": "Wind-bent pine", "moss_limestone": "Moss limestone",
	"berry_thicket": "Berry thicket", "riverbank_reeds": "Riverbank reeds"}
const BUILDINGS := ["STORAGE_PIT", "WATCHTOWER"]
const STAGES := ["Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble"]
const IMPORTED_WILDLIFE := {"BOAR": "Tusked Boar", "SABERTOOTH": "Sabertooth", "SLATEBACK_BOAR": "Slateback Boar", "REEDJAW": "Reedjaw"}
const ENCOUNTERS := ["BOAR", "SABERTOOTH", "WOLF", "SLATEBACK_BOAR", "REEDJAW"]
const FRAME := Rect2i(0, 0, 1320, 824)
const INK := Color("#f1e7d0")
const ACCENT := Color("#d9ad64")
const MUTED := Color("#b8c1af")

var _fails := 0
var _state: Node
var _factory: Node
var _stage: Node3D
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if not _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Pass a writable absolute --out-dir"):
		quit(1)
		return
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	await _verify_campaign()
	await _render_review(out_dir.path_join("valley-assets.png"))
	await _render_building_review(out_dir.path_join("valley-buildings.png"))
	if _fails == 0:
		print("VALLEY ASSETS PASSED")
	quit(0 if _fails == 0 else 1)


func _verify_campaign() -> void:
	seed(17394)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_check(_state.world_node.is_psx_filter_enabled(), "The campaign starts with the PSX filter on")
	var reeds: Node = _state.world_node.get_node_or_null("Terrain/RiverbankReeds")
	if _check(reeds != null and reeds.get_child_count() == 42, "Reed beds populate both riverbanks"):
		_check(reeds.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Reed beds leave river traversal clear")
	_state.start_new_campaign("Enoch", "Fallow Chosen", root.get_node("GameData").Lineage.CRAG_BORN, Layout.CLASSIC_ID)
	var leader: CharacterBody3D = _state.get_faction_leader(0)
	leader.set_physics_process(false)
	_state.player_controller.set_physics_process(false)
	var resource_types: Dictionary = {"TREE": false, "STONE": false, "BERRY_BUSH": false}
	var bush: Node3D
	for resource in _state.resources_container.get_children():
		var kind: String = resource.get_meta("node_type")
		if resource_types.has(kind) and not resource_types[kind]:
			var imported: Node = resource.get_child(0)
			resource_types[kind] = imported.scene_file_path.ends_with(".glb")
			if kind == "BERRY_BUSH":
				bush = resource
	for kind in resource_types:
		_check(resource_types[kind], "%s uses imported art and keeps its harvest type" % kind)
	if bush != null:
		leader.global_position = bush.global_position
		_state.spatial_index.update_unit(leader)
		var food: float = _state.factions[0]["resources"]["food"]
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		root.push_input(key, true)
		_check(is_equal_approx(_state.factions[0]["resources"]["food"], food + 5.0),
			"Leader harvests the imported berry thicket via E")

	var wildlife: Array = _state.wildlife_container.get_children()
	_check(wildlife.size() == 25, "Existing wildlife population count is retained")
	var examples := {}
	for animal in wildlife:
		animal.set_physics_process(false)
		examples[animal.animal_type] = animal
	for kind in ENCOUNTERS:
		if _check(examples.has(kind), "%s spawned during Awakening" % kind):
			_verify_animal(examples[kind], leader)
	for i in range(BUILDINGS.size()):
		await _verify_building(BUILDINGS[i], Vector3(158.0, 0.0, 130.0 + i * 12.0), leader)
	main.free()
	await process_frame
	print("Awakening, resource harvest, wildlife combat, and building stages checked.")


func _verify_animal(animal: Node, leader: CharacterBody3D) -> void:
	var kind: String = animal.animal_type
	animal.global_position = Vector3(110 + ENCOUNTERS.find(kind) * 12, 0.12, -145)
	_state.spatial_index.update_wildlife(animal)
	animal.velocity = Vector3.ZERO
	animal._target_unit = null
	animal._attack_cd = 0.0
	var player: AnimationPlayer = animal._bite_player
	if kind == "BOAR":
		var before: Vector3 = animal.global_position
		animal._roam_target = before + Vector3(4, 0, 0)
		animal._physics_process(1.0 / 60.0)
		animal._physics_process(1.0 / 60.0)
		_check(animal.global_position.x > before.x and (player == null or not player.is_playing()),
			"Boar roams through existing AI with its Bite clip idle")
		animal.take_damage(1.0, leader, 0)
	if kind == "SLATEBACK_BOAR":
		animal.take_damage(12.0, leader, 0)
		_check(is_equal_approx(float(animal.hp), 121.6) and animal._target_unit == leader,
			"Slateback mitigates 3.6 damage with its plates and retaliates when struck")
	if kind != "WOLF" and not _check(player != null, "%s spawns with imported Bite" % kind):
		return

	leader.global_position = animal.global_position + Vector3(-1.60, 0, 0)
	_state.spatial_index.update_unit(leader)
	if kind in ["SABERTOOTH", "REEDJAW"]:
		_check(animal._scan_for_prey(14.0) == leader, "%s finds quarry through the existing scan" % kind)
	leader.hp = leader.max_hp
	var hp: float = leader.hp
	animal._physics_process(1.0 / 60.0)
	var expected_damage := maxf(2.0, animal.damage - leader.armor * 0.45)
	var delayed := kind == "REEDJAW"
	_check(is_equal_approx(hp - leader.hp, 0.0 if delayed else expected_damage),
		"%s starts its attack with the expected damage timing" % kind)
	_check(animal.serialize()["animal_type"] == kind, "%s retains its save ID" % kind)
	if kind == "WOLF":
		_check(player == null and animal._attack_anim_timer > 0.0, "Wolf still attacks with procedural art")
		return

	var clip := player.get_animation(&"Bite")
	_check(clip.loop_mode == Animation.LOOP_NONE and clip.get_track_count() > 0,
		"%s imports a one-shot Bite" % kind)
	for clip_name in player.get_animation_list():
		_check(clip_name in ["Bite", "RESET"], "%s only exports the bite animation" % kind)
	_check(player.is_playing() and player.current_animation == &"Bite", "%s plays Bite on attack" % kind)
	var rig := animal._visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if not _check(rig != null and rig.find_bone("Jaw") >= 0, "%s has an articulated jaw" % kind):
		return
	var model_mesh := animal._visual_root.find_child("WildlifeMesh", true, false) as MeshInstance3D
	_check(model_mesh != null and model_mesh.skin != null
		and model_mesh.get_node_or_null(model_mesh.skeleton) == rig, "%s has a bound skin" % kind)
	var jaw := rig.find_bone("Jaw")
	var closed_jaw := rig.get_bone_pose_rotation(jaw)
	_state.is_paused = true
	animal._physics_process(0.09)
	_check(player.current_animation_position == 0.0, "%s bite pauses with the campaign" % kind)
	_state.is_paused = false
	animal._physics_process(0.09)
	_check(closed_jaw.angle_to(rig.get_bone_pose_rotation(jaw)) > 0.35, "%s opens its jaw" % kind)
	if delayed:
		_check(is_equal_approx(leader.hp, hp), "Reedjaw telegraphs the bite before it connects")
		animal._physics_process(0.075)
		_check(is_equal_approx(hp - leader.hp, expected_damage), "Reedjaw deals one hit when the bite closes")
	for i in range(10):
		animal._physics_process(0.05)
	_check(not player.is_playing() and closed_jaw.is_equal_approx(rig.get_bone_pose_rotation(jaw)),
		"%s closes its jaw and finishes the one-shot" % kind)
	animal._attack_cd = 0.0
	leader.global_position = animal.global_position - Vector3(1.6, 0, 0)
	_state.spatial_index.update_unit(leader)
	animal._physics_process(1.0 / 60.0)
	animal._physics_process(0.09)
	_check(player.is_playing() and closed_jaw.angle_to(rig.get_bone_pose_rotation(jaw)) > 0.35,
		"%s can start the bite again on the next attack" % kind)
	if delayed:
		hp = leader.hp
		leader.global_position = animal.global_position - Vector3(6, 0, 0)
		_state.spatial_index.update_unit(leader)
		animal._physics_process(0.10)
		_check(is_equal_approx(leader.hp, hp), "Leaving Reedjaw's reach during the wind-up avoids the bite")
		_verify_reedjaw_hit_volume(animal, leader)


func _verify_reedjaw_hit_volume(animal: Node, leader: Node) -> void:
	_state.spatial_index.update_wildlife(animal)
	var center: Vector3 = animal.projectile_hit_center()
	var hp: float = animal.hp
	var projectile_script := load("res://scripts/entities/projectile_3d.gd")
	for height in [1.3, 0.0]:
		var origin := center - Vector3(0.5, -height, 0)
		var shot: Node = projectile_script.spawn(leader, 0, origin, origin + Vector3.RIGHT, 12.0)
		shot.gravity = 0.0
		shot.velocity = Vector3(20, 0, 0)
		shot._physics_process(0.05)
		_check(is_equal_approx(float(animal.hp), hp - (12.0 if height == 0.0 else 0.0)),
			"Reedjaw's low hit volume distinguishes overhead and body-level projectiles")
		_state.projectiles_container.remove_child(shot)
		shot.free()


func _verify_building(type: String, point: Vector3, target: Node3D) -> void:
	var path := "res://assets/models/buildings/%s_stages.glb" % type.to_lower()
	var source: Node3D = load(path).instantiate()
	_check(not source.find_children("Collider*", "StaticBody3D", true, false).is_empty(),
		"%s imports an authored convex collider" % type)
	source.free()
	var nav: RefCounted = _state.valley_nav
	var cell: Vector2i = nav.world_to_cell(point)
	var pos: Vector3 = nav.cell_to_world(cell)
	var building: Node = _state.faction_controllers[0].spawn_building(type, pos, PI * 0.5, false)
	building.set_physics_process(false)
	_check(building._visual_root.scene_file_path == path and building._visual_root.get_node(STAGES[0]).visible,
		"%s blueprint uses the imported intact shape" % type)
	_check(not nav.is_cell_blocked(cell), "%s blueprint leaves navigation clear" % type)
	_check(building._visual_root.find_children("*", "Light3D", true, false).is_empty(), "%s blueprint emits no light" % type)
	building.advance_construction(building.build_time + 0.1)
	_check(building.is_constructed and building._col_shape.shape is BoxShape3D and nav.is_cell_blocked(cell),
		"%s construction registers the authored footprint at the saved rotation" % type)
	for stage in range(STAGES.size()):
		_check(building.damage_stage == stage and building._get_active_stage_node().visible, "%s switches to %s" % [type, STAGES[stage]])
		if type == "WATCHTOWER" and stage < 3:
			_verify_arrow_origin(building, target, stage)
		if stage < 3:
			var next_hp: float = building.max_hp * [0.5, 0.24, 0.0][stage]
			building.take_damage(building.hp - next_hp, 5)
	await process_frame
	_check(building.is_destroyed and building._col_shape.disabled and not nav.is_cell_blocked(cell),
		"%s rubble releases collision and navigation" % type)


func _verify_arrow_origin(tower: Node, target: Node3D, stage: int) -> void:
	var active: Node3D = tower._get_active_stage_node()
	var light := active.find_child("SignalLight*", false, false) as OmniLight3D
	var flame := active.find_child("FlameMesh*", false, false) as MeshInstance3D
	var marker := active.find_child("ArrowOrigin*", false, false) as Node3D
	_check(light != null and light.visible and flame != null and flame.visible, "Active tower stage has a lit brazier")
	if not _check(marker != null, "Watchtower stage mounts an arrow origin"):
		return
	var projectiles: Node = _state.projectiles_container
	tower._fire_watchtower_arrow(target)
	var arrow: Node3D = projectiles.get_child(projectiles.get_child_count() - 1)
	var deck_eye_height: float = [3.21, 3.0, 1.57][stage]
	_check(arrow.global_position.is_equal_approx(marker.global_position)
		and is_equal_approx(arrow.global_position.y - tower.global_position.y, deck_eye_height),
		"Watchtower projectile origin follows the active deck at its rotated stage marker")
	projectiles.remove_child(arrow)
	arrow.free()


func _render_review(path: String) -> void:
	_setup_stage()
	var pictures: Array[Image] = []
	var labels: Array[String] = []
	for name in SCENERY:
		var prop: Node3D = _factory.build_environment_mesh(name)
		if not _check(prop != null, "%s imports as scenery" % name):
			continue
		_check(not prop.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s contains geometry" % name)
		_stage.add_child(prop)
		var distance := 18.4 if name == "windbent_pine" else 8.6
		var focus := 2.58 if name == "windbent_pine" else 0.69
		pictures.append(await _capture(focus, distance, Vector2i(298, 269), 33.0))
		labels.append(SCENERY[name])
		prop.free()

	for kind in IMPORTED_WILDLIFE:
		var model: Node3D = _factory.build_wildlife_mesh(kind)
		var player := model.find_child("BiteAnimation", true, false) as AnimationPlayer
		if not _check(player != null, "%s can be posed for review" % kind):
			model.free()
			continue
		_stage.add_child(model)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(&"Bite")
		player.seek(0.09, true)
		pictures.append(await _capture(0.70, 11.4, Vector2i(298, 190), -58.0))
		labels.append(IMPORTED_WILDLIFE[kind])
		model.free()

	_stage.free()
	if not _check(pictures.size() == 8, "All eight review panels rendered"):
		return
	var canvas := Control.new()
	root.add_child(canvas)
	_box(canvas, Vector2.ZERO, Vector2(FRAME.size), Color("#161e1c"))
	_label(canvas, "CHRIST FALLOW  /  ASSET OVERHAUL", Vector2(38, 22), 16, ACCENT)
	_label(canvas, "Valley scenery & wildlife", Vector2(35, 48), 41, INK)
	_label(canvas, "Godot 4.3 Forward+   ·   PSX filter on", Vector2(40, 109), 17, MUTED)
	_label(canvas, "SCENERY", Vector2(40, 155), 20, ACCENT)
	_label(canvas, "BITE POSES", Vector2(40, 508), 20, ACCENT)
	for i in range(8):
		var left := 40 + (i % 4) * 314
		var top := 190 if i < 4 else 546
		var frame := TextureRect.new()
		frame.position = Vector2(left, top)
		frame.texture = ImageTexture.create_from_image(pictures[i])
		canvas.add_child(frame)
		_label(canvas, labels[i], frame.position + Vector2(0, pictures[i].get_height() + 11), 22, INK)
	_label(canvas, "Bite panels share the same camera angle and distance.", Vector2(40, 788), 15, MUTED)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().get_region(FRAME).save_png(path) == OK, "Comparison sheet saves")
	canvas.free()
	print("Review written to %s" % path)


func _render_building_review(path: String) -> void:
	_setup_stage()
	var size := Vector2i(298, 230)
	var sheet := Image.create(size.x * STAGES.size(), size.y * BUILDINGS.size(), false, Image.FORMAT_RGB8)
	for row in range(BUILDINGS.size()):
		var model: Node3D = _factory.build_building_stages(BUILDINGS[row], Color("#e6b958"), false)
		_stage.add_child(model)
		for column in range(STAGES.size()):
			for stage in model.get_children():
				stage.visible = stage.name == STAGES[column]
			var picture := await _capture(1.38, 14.0, size, 33.0)
			picture.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, size), Vector2i(column * size.x, row * size.y))
		model.free()
	_stage.free()
	_check(sheet.save_png(path) == OK, "Building stage comparison saves")


func _setup_stage() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#384544")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e3d7b7")
	env.ambient_light_energy = 0.63
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 32, 0)
	sun.light_energy = 1.1
	sun.light_color = Color("#fff1da")
	sun.shadow_enabled = true
	_stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45, 45)
	floor.mesh = plane
	var loam := StandardMaterial3D.new()
	loam.albedo_color = Color("#424940")
	loam.roughness = 1.0
	floor.material_override = loam
	_stage.add_child(floor)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_stage.add_child(_camera)
	_camera.make_current()
	var post := CanvasLayer.new()
	_stage.add_child(post)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var filter := ShaderMaterial.new()
	filter.shader = POST_SHADER
	rect.material = filter
	post.add_child(rect)


func _capture(height: float, distance: float, crop: Vector2i, azimuth: float) -> Image:
	var focus := Vector3(0, height, 0)
	var pitch := deg_to_rad(23.0)
	var yaw := deg_to_rad(azimuth)
	_camera.position = focus + distance * Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	_camera.look_at(focus)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image.get_region(Rect2i((image.get_size() - crop) / 2, crop))


func _box(parent: Control, at: Vector2, size: Vector2, color: Color) -> void:
	var box := ColorRect.new()
	box.position = at
	box.size = size
	box.color = color
	parent.add_child(box)


func _label(parent: Control, value: String, at: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		_fails += 1
	return ok

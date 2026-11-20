extends SceneTree

const STAGES := ["Intact", "Damaged", "Critical", "Rubble"]
const BUILDINGS := [
	["ridge_signal_tower", "Ridge Signal Tower", 1.43, 5.35, 1],
	["standing_stone_gate", "Standing-Stone Gate", 1.39, 5.5, 2],
	["reed_granary", "Reed Granary", 1.13, 4.95, 1],
]
const ENEMIES := [
	["characters/archetypes", "flintmask_scout", "Flintmask Scout", 0.95, 3.15],
	["wildlife", "slateback_boar", "Slateback Boar", 0.79, 3.85],
	["wildlife", "reedjaw", "Reedjaw", 0.50, 4.32],
]
const BACKGROUND := Color("#201c18")
const TEXT := Color("#f5e7ce")
const SECONDARY := Color("#c6ae8d")
const RULE := Color("#554536")
const WIDTH := 1440

var _output := ""
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_output = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless" or _output.is_empty():
		printerr("Run with a Forward+ display and an absolute --out-dir path.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		printerr("Could not create the output directory.")
		quit(1)
		return
	await _buildings_sheet()
	await _enemies_sheet()
	if not _failed:
		print("SIX ASSET EXAMPLES VERIFIED AND RENDERED")
	quit(1 if _failed else 0)


func _buildings_sheet() -> void:
	var page := _page("Village structures", "Damage progression", 1050)
	for column in range(STAGES.size()):
		_label(page, STAGES[column], Vector2(55 + 339 * column, 123), 21, SECONDARY)
	for row in range(BUILDINGS.size()):
		var entry: Array = BUILDINGS[row]
		var y := 178 + 289 * row
		_line(page, y - 24)
		_label(page, entry[1], Vector2(48, y - 11), 25, TEXT)
		for column in range(STAGES.size()):
			var stage_name := StringName("Stage_" + STAGES[column])
			var model := _load_example("buildings", entry[0])
			if model == null:
				continue
			if model.find_children("*", "CollisionShape3D", true, false).size() != int(entry[4]):
				_fail("%s did not import the expected authored colliders" % entry[0])
			for expected in STAGES:
				var stage := model.get_node_or_null("Stage_" + expected) as Node3D
				if stage == null or not _has_mesh(stage):
					_fail("%s is missing a stage mesh for %s" % [entry[0], expected])
					continue
				stage.visible = stage.name == stage_name
			var view := _view(page, Vector2i(48 + 339 * column, y + 31), Vector2i(326, 220),
				float(entry[2]), float(entry[3]), Vector3(3.8, 4.2, 8.4))
			view.add_child(model)
	await _write_sheet(page, "destruction-stages.png")


func _enemies_sheet() -> void:
	var page := _page("Enemy concepts", "Imported Idle and Walk poses", 955)
	for column in range(ENEMIES.size()):
		_label(page, ENEMIES[column][2], Vector2(48 + 451 * column, 121), 24, TEXT)
	for row in range(2):
		var clip := "Idle" if row == 0 else "Walk"
		var y := 194 + row * 377
		_line(page, y - 34)
		_label(page, clip, Vector2(48, y - 23), 20, SECONDARY)
		for column in range(ENEMIES.size()):
			var entry: Array = ENEMIES[column]
			var model := _load_example(entry[0], entry[1])
			if model == null:
				continue
			var offset := Vector3(3.2, 2.55, 7.5) if column == 0 else Vector3(6.0, 3.4, 6.1)
			var view := _view(page, Vector2i(48 + 451 * column, y + 7), Vector2i(437, 329),
				float(entry[3]), float(entry[4]), offset)
			view.add_child(model)
			model.rotation.y = PI
			_pose_enemy(model, entry[1], clip, 0.72 if column == 0 else 0.90)
	await _write_sheet(page, "enemy-concepts.png")


func _pose_enemy(model: Node3D, slug: String, clip: String, walk_phase: float) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		_fail("%s requires an imported skeleton and animation player" % slug)
		return
	var skeleton := skeletons[0] as Skeleton3D
	var mesh_count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			mesh_count += 1
	if mesh_count == 0:
		_fail("%s has no mesh skinned to the skeleton" % slug)
	var player := players[0] as AnimationPlayer
	if not player.has_animation(clip):
		_fail("%s did not import %s" % [slug, clip])
		return
	var animation := player.get_animation(clip)
	if animation.loop_mode != Animation.LOOP_LINEAR or animation.length <= 0.0:
		_fail("%s %s must be a positive-length looping clip" % [slug, clip])
	player.play(clip)
	player.seek(0.0, true)
	var pose_start: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()):
		pose_start.append(skeleton.get_bone_pose(bone))
	player.seek(animation.length * (0.27 if clip == "Idle" else walk_phase), true)
	player.pause()
	var animated := false
	for bone in range(pose_start.size()):
		animated = animated or not pose_start[bone].is_equal_approx(skeleton.get_bone_pose(bone))
	if not animated:
		_fail("%s %s did not change the bone pose" % [slug, clip])


func _page(title: String, subtitle: String, height: int) -> SubViewport:
	var page := SubViewport.new()
	page.size = Vector2i(WIDTH, height)
	page.transparent_bg = false
	page.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(page)
	var paper := ColorRect.new()
	paper.color = BACKGROUND
	paper.size = Vector2(WIDTH, height)
	page.add_child(paper)
	_label(page, title, Vector2(48, 29), 49, TEXT)
	_label(page, subtitle, Vector2(49, 87), 19, SECONDARY)
	return page


func _view(page: SubViewport, position: Vector2i, size: Vector2i, focus_height: float, width: float, camera_offset: Vector3) -> SubViewport:
	var container := SubViewportContainer.new()
	container.position = position
	container.size = size
	page.add_child(container)
	var view := SubViewport.new()
	view.size = size
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#322e27")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f5eddd")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, -38, 0)
	key.light_energy = 1.16
	key.light_color = Color("#fff0d5")
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 14.0
	view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 134, 0)
	fill.light_energy = 0.27
	fill.light_color = Color("#dbedfd")
	view.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor.mesh = plane
	floor.position.y = -0.035
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("#4f493b")
	ground.roughness = 1.0
	floor.material_override = ground
	view.add_child(floor)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = width
	view.add_child(camera)
	var focus := Vector3(0, focus_height, 0)
	camera.position = focus + camera_offset
	camera.look_at(focus)
	camera.current = true
	return view


func _load_example(category: String, slug: String) -> Node3D:
	var path := "res://models/%s/%s.glb" % [category, slug]
	if not ResourceLoader.exists(path, "PackedScene"):
		_fail("Missing imported GLB %s" % path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _has_mesh(node: Node3D) -> bool:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		return instance.mesh != null and instance.mesh.get_surface_count() > 0
	return not node.find_children("*", "MeshInstance3D", true, false).is_empty()


func _label(parent: Node, value: String, pos: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _line(parent: Node, y: int) -> void:
	var line := ColorRect.new()
	line.position = Vector2(48, y)
	line.size = Vector2(1344, 1)
	line.color = RULE
	parent.add_child(line)


func _write_sheet(page: SubViewport, file_name: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := page.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(_output.path_join(file_name)) != OK:
		_fail("Could not save %s" % file_name)
	page.queue_free()


func _fail(message: String) -> void:
	_failed = true
	printerr("FAIL: " + message)

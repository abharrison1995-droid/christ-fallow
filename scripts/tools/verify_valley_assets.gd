extends SceneTree
## Run on a clean Forward+ import with -- --out-dir=<absolute directory>.

const POST_SHADER = preload("res://scripts/shaders/psx_diablo_post.gdshader")
const SCENERY := {"windbent_pine": "Wind-bent pine", "moss_limestone": "Moss limestone",
	"berry_thicket": "Berry thicket", "riverbank_reeds": "Riverbank reeds"}
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
	_state.start_new_campaign("Enoch", "Fallow Chosen", root.get_node("GameData").Lineage.CRAG_BORN)
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
	for kind in ["BOAR", "SABERTOOTH", "WOLF"]:
		if _check(examples.has(kind), "%s spawned during Awakening" % kind):
			_verify_animal(examples[kind], leader)
	main.free()
	await process_frame
	print("Awakening, resource harvest, boar roaming, bite damage and procedural fallback checked.")


func _verify_animal(animal: Node, leader: CharacterBody3D) -> void:
	var kind: String = animal.animal_type
	animal.global_position = Vector3(160, 0.12, -145)
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
	if kind != "WOLF" and not _check(player != null, "%s spawns with imported Bite" % kind):
		return

	leader.global_position = animal.global_position + Vector3(-1.60, 0, 0)
	_state.spatial_index.update_unit(leader)
	if kind == "SABERTOOTH":
		_check(animal._scan_for_prey(14.0) == leader, "Sabertooth finds quarry through the existing scan")
	leader.hp = leader.max_hp
	var hp: float = leader.hp
	animal._physics_process(1.0 / 60.0)
	_check(is_equal_approx(hp - leader.hp, maxf(2.0, animal.damage - leader.armor * 0.45)),
		"%s applies the current attack damage through the AI" % kind)
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

	for kind in ["BOAR", "SABERTOOTH"]:
		var model: Node3D = _factory.build_wildlife_mesh(kind)
		var player := model.find_child("BiteAnimation", true, false) as AnimationPlayer
		if not _check(player != null, "%s can be posed for review" % kind):
			model.free()
			continue
		_stage.add_child(model)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(&"Bite")
		player.seek(0.0, true)
		pictures.append(await _capture(0.75, 9.2, Vector2i(298, 190), -58.0))
		player.seek(0.09, true)
		pictures.append(await _capture(0.75, 9.2, Vector2i(298, 190), -58.0))
		labels.append_array(["Tusked boar" if kind == "BOAR" else "Sabertooth", "Jaw open"])
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
	print("Review written to %s" % path)


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

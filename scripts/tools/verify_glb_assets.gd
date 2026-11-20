extends SceneTree
## Run with a Forward+ display after importing the project.

const WorldMeshBuilder = preload("res://scripts/core/world_mesh_builder.gd")
const SkinnedTribesmanTrial = preload("res://scripts/entities/skinned_tribesman_trial.gd")
const BUILDING_SCRIPT := "res://scripts/entities/building_entity.gd"
const CHARACTER_PATH := SkinnedTribesmanTrial.MODEL_PATH
const BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"UpperArm.L", "LowerArm.L", "Hand.L", "UpperArm.R", "LowerArm.R", "Hand.R",
	"UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R",
]

var _errors := 0
var _completed_renders := 0
var _out_dir := ""
var _require_gameplay_rig := false
var _stage: Node3D
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	if DisplayServer.get_name() == "headless" or renderer != "forward_plus" or RenderingServer.get_rendering_device() == null:
		printerr("Asset verification requires a Forward+ display.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
		elif arg == "--require-gameplay-rig":
			_require_gameplay_rig = true
	if not _out_dir.is_empty() and DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		printerr("Could not create asset render directory: %s" % _out_dir)
		quit(1)
		return

	_setup_stage()
	await _verify_building("SLEEPING_HUT", 5.4)
	await _verify_building("PALISADE_WALL", 4.6)
	_verify_blueprint()
	await _verify_character()
	_check(_completed_renders == 3, "All three asset views must reach the renderer")
	if _errors == 0:
		print("ASSET VERIFICATION PASSED (%s rig contract)" % ("gameplay" if _require_gameplay_rig else "prototype"))
		quit(0)
	else:
		printerr("Asset verification failed (%d errors)." % _errors)
		quit(1)


func _verify_building(building_type: String, spacing: float) -> void:
	var slug := building_type.to_lower()
	var path := "res://assets/models/buildings/%s_stages.glb" % slug
	var source := _load_scene(path)
	if source == null:
		return
	if not _check(WorldMeshBuilder.has_building_stages(source), "Expected four exact stage names directly under %s" % path):
		source.free()
		return
	for stage_name in WorldMeshBuilder.BUILDING_STAGE_NAMES:
		var stage_meshes := _meshes(source.get_node(stage_name))
		_check(stage_meshes.any(func(mesh: MeshInstance3D) -> bool: return mesh.mesh != null and mesh.mesh.get_surface_count() > 0),
			"%s is missing geometry in %s" % [path, stage_name])
	source.free()

	var data: Node = root.get_node("GameData")
	var tint: Color = data.FACTION_COLORS[0]
	for stage_idx in range(WorldMeshBuilder.BUILDING_STAGE_NAMES.size()):
		var pos := Vector3((float(stage_idx) - 1.5) * spacing, 0, 0)
		var building := _spawn_building(building_type, pos)
		var visual: Node3D = building.get("_visual_root")
		_check(visual.scene_file_path == path, "%s must use the imported model in gameplay" % building_type)
		match stage_idx:
			0:
				_check(_has_faction_tint(visual.get_node("Stage_Intact"), tint), "%s must apply the faction tint to FactionTrim" % building_type)
			1:
				building.take_damage(building.max_hp * 0.50, 0)
			2:
				building.take_damage(building.max_hp * 0.80, 0)
			3:
				building.take_damage(building.max_hp, 0)
		_check(building.damage_stage == stage_idx, "%s did not enter damage stage %d" % [building_type, stage_idx])
		for index in range(WorldMeshBuilder.BUILDING_STAGE_NAMES.size()):
			var node := visual.get_node(WorldMeshBuilder.BUILDING_STAGE_NAMES[index]) as Node3D
			_check(node.visible == (index == stage_idx), "%s has inconsistent stage visibility" % building_type)
		if building_type == "PALISADE_WALL":
			var collider: CollisionShape3D = building.get("_col_shape")
			var wall_shape := collider.shape as BoxShape3D
			_check(wall_shape != null and wall_shape.size.is_equal_approx(Vector3(3.2, 2.2, 0.5)), "Palisade footprint must match the authored box")
			await process_frame
			_check(collider.disabled == (stage_idx == 3), "Only rubble should have collision disabled")
		_label(WorldMeshBuilder.BUILDING_STAGE_NAMES[stage_idx].trim_prefix("Stage_"), pos + Vector3(0, 0.12, 2.8), 0.016)
	await _capture("%s.png" % slug, Vector3(2.4, 9, 18), Vector3(0, 1.1, 0), spacing * 4.25)
	_clear()
	if building_type == "PALISADE_WALL":
		await _verify_wall_passage()
		_clear()


func _verify_blueprint() -> void:
	var blueprint := _spawn_building("SLEEPING_HUT", Vector3.ZERO, false)
	blueprint.sync_visual_from_state()
	_check(blueprint.damage_stage == 0 and blueprint.get("_critical_particles") == null,
		"Restoring an untouched blueprint must keep its hologram and suppress critical smoke")
	for yaw in [0.0, PI * 0.5]:
		var hut := _spawn_building("SLEEPING_HUT", Vector3(12, 0, 0), true, yaw)
		var visual: Node3D = hut.get("_visual_root")
		var intact_stage := visual.get_node("Stage_Intact")
		var expected_forward := hut.global_transform.basis.z
		var door_faces_preview := false
		for mesh in _meshes(intact_stage):
			if mesh.mesh == null:
				continue
			for slot in range(mesh.mesh.get_surface_count()):
				var material := mesh.mesh.surface_get_material(slot)
				if material == null or material.resource_name != "Mat_DarkWood":
					continue
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]
				door_faces_preview = not vertices.is_empty()
				for vertex in vertices:
					if (mesh.to_global(vertex) - hut.global_position).dot(expected_forward) <= 0.0:
						door_faces_preview = false
						break
		_check(door_faces_preview, "Sleeping Hut doorway must face its placement preview at yaw %f" % yaw)
		hut.free()
	var fallback := _spawn_building("CAMPFIRE", Vector3(6, 0, 0))
	_check(WorldMeshBuilder.has_building_stages(fallback.get("_visual_root")), "The procedural building fallback must provide four stages")
	_clear()


func _verify_wall_passage() -> void:
	var first := _spawn_building("PALISADE_WALL", Vector3(0, 0, -1.6), true, PI * 0.5)
	_spawn_building("PALISADE_WALL", Vector3(0, 0, 1.6), true, PI * 0.5)
	await physics_frame
	await physics_frame
	var character := CapsuleShape3D.new()
	character.radius = 0.36
	character.height = 1.65
	var beside := PhysicsShapeQueryParameters3D.new()
	beside.shape = character
	beside.transform = Transform3D(Basis.IDENTITY, Vector3(0.68, 0.84, -1.4))
	beside.motion = Vector3(0, 0, 2.8)
	var space := first.get_world_3d().direct_space_state
	var travel := space.cast_motion(beside)
	_check(travel.size() == 2 and is_equal_approx(travel[0], 1.0), "A tribesman must pass beside joined rotated palisades")
	var across := PhysicsRayQueryParameters3D.create(Vector3(1.0, 0.8, -1.6), Vector3(-1.0, 0.8, -1.6))
	_check(not space.intersect_ray(across).is_empty(), "A rotated palisade must block paths through the wall")


func _verify_character() -> void:
	var original := _load_scene(CHARACTER_PATH)
	if original == null:
		return
	_stage.add_child(original)
	var skeletons := original.find_children("*", "Skeleton3D", true, false)
	if not _check(not skeletons.is_empty(), "Tribesman scene requires a Skeleton3D"):
		_clear()
		return
	var skeleton := skeletons[0] as Skeleton3D
	for bone in BONES:
		_check(skeleton.find_bone(bone) >= 0, "Tribesman is missing bone %s" % bone)
	var mesh_instances := _meshes(original)
	_check(mesh_instances.any(func(mesh: MeshInstance3D) -> bool: return _uses_skin(mesh, skeleton)),
		"Tribesman requires a mesh with bone weights and a binding to its skeleton")
	var players := original.find_children("*", "AnimationPlayer", true, false)
	if _check(not players.is_empty(), "Tribesman scene requires an AnimationPlayer"):
		var player: AnimationPlayer = players[0]
		_verify_clip(player, skeleton, "Idle")
		if _require_gameplay_rig:
			_verify_clip(player, skeleton, "Walk", true)
			_verify_clip(player, skeleton, "Work", true)
			_verify_clip(player, skeleton, "Wounded", true)
			_verify_clip(player, skeleton, "Attack", false)
			_verify_clip(player, skeleton, "Hit", false)
			_verify_clip(player, skeleton, "Death", false)
	if _require_gameplay_rig:
		var has_trim := false
		for mesh in mesh_instances:
			if mesh.mesh == null:
				continue
			for slot in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(slot)
				_check(arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(),
					"Gameplay tribesman surfaces require UVs")
				var material := mesh.mesh.surface_get_material(slot)
				has_trim = has_trim or (material != null and material.resource_name == "FactionTrim")
		_check(has_trim, "Gameplay tribesman requires a FactionTrim surface")
	else:
		print("Tribesman checked as a prototype. Gameplay rig verification also requires Walk, looping clips, UVs and faction trim.")

	original.position.x = -1.35
	original.rotation.y = PI
	_label("Imported material", Vector3(-1.35, 0.08, 1.2), 0.008)
	var shader_model := _load_scene(CHARACTER_PATH)
	if shader_model != null:
		_stage.add_child(shader_model)
		shader_model.position.x = 1.35
		shader_model.rotation.y = PI + 0.35
		var data: Node = root.get_node("GameData")
		var tint: Color = data.FACTION_COLORS[0]
		var materials := SkinnedTribesmanTrial.apply_materials(root.get_node("MeshFactory"), shader_model, tint)
		_check(not materials.is_empty(), "Could not apply the PSX character shader")
		if _require_gameplay_rig:
			_check(_has_skinned_faction_tint(shader_model, tint), "Tribesman shader must apply the faction color to its trim")
		_label("Forward+ shader", Vector3(1.35, 0.08, 1.2), 0.008)
	await _capture("tribesman.png", Vector3(0, 2.8, 9), Vector3(0, 0.9, 0), 6.3)
	_clear()


func _verify_clip(player: AnimationPlayer, skeleton: Skeleton3D, clip_name: String, expect_loop: bool = true) -> void:
	if not _check(player.has_animation(clip_name), "Tribesman is missing the %s clip" % clip_name):
		return
	var clip := player.get_animation(clip_name)
	if _require_gameplay_rig:
		var expected_mode := Animation.LOOP_LINEAR if expect_loop else Animation.LOOP_NONE
		_check(clip.loop_mode == expected_mode,
			"%s must have %s loop mode for gameplay" % [clip_name, "linear" if expect_loop else "one-shot"])
	if not _check(clip.length > 0.0 and clip.get_track_count() > 0, "%s must contain animation tracks" % clip_name):
		return
	player.play(clip_name)
	player.seek(0.0, true)
	var initial_pose := []
	for bone in range(skeleton.get_bone_count()):
		initial_pose.append(skeleton.get_bone_pose(bone))
	var animated := false
	for sample in [0.25, 0.50, 0.75]:
		player.seek(clip.length * sample, true)
		for bone in range(skeleton.get_bone_count()):
			animated = animated or not skeleton.get_bone_pose(bone).is_equal_approx(initial_pose[bone])
	player.pause()
	_check(animated, "%s does not animate the imported skeleton" % clip_name)


func _setup_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.14, 0.16, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.91, 0.88)
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -28, 0)
	key.light_energy = 1.15
	key.shadow_enabled = true
	root.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.17, 0.18, 0.16)
	ground.material_override = floor_material
	ground.position.y = -0.05
	root.add_child(ground)
	_stage = Node3D.new()
	root.add_child(_stage)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	root.add_child(_camera)
	_camera.current = true


func _capture(file_name: String, eye: Vector3, focus: Vector3, size: float) -> void:
	_camera.position = eye
	_camera.look_at(focus)
	_camera.size = size
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if not _out_dir.is_empty():
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty() and image.save_png(_out_dir.path_join(file_name)) == OK,
			"Could not render %s" % file_name)
	_completed_renders += 1


func _spawn_building(kind: String, pos: Vector3, constructed := true, yaw := 0.0) -> Node3D:
	var script: Script = load(BUILDING_SCRIPT)
	var building: Node3D = script.new()
	_stage.add_child(building)
	building.setup(kind, 0, pos, yaw, constructed)
	return building


func _load_scene(path: String) -> Node3D:
	if not _check(ResourceLoader.exists(path), "Missing imported asset %s. Run Godot import first." % path):
		return null
	var packed := load(path) as PackedScene
	if not _check(packed != null, "%s must import as a PackedScene" % path):
		return null
	return packed.instantiate() as Node3D


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		result.append(child)
	return result


func _has_faction_tint(node: Node, tint: Color) -> bool:
	for mesh in _meshes(node):
		if mesh.mesh == null:
			continue
		for slot in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(slot)
			if material == null or material.resource_name != "FactionTrim":
				continue
			var painted := mesh.get_surface_override_material(slot) as StandardMaterial3D
			if painted != null and painted.albedo_color.is_equal_approx(tint):
				return true
	return false


func _uses_skin(mesh: MeshInstance3D, skeleton: Skeleton3D) -> bool:
	if mesh.mesh == null or mesh.skin == null or mesh.get_node_or_null(mesh.skeleton) != skeleton:
		return false
	for slot in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(slot)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_BONES].size() == weights.size():
			for weight in weights:
				if weight > 0.0:
					return true
	return false


func _has_skinned_faction_tint(model: Node, tint: Color) -> bool:
	for mesh in _meshes(model):
		if mesh.mesh == null:
			continue
		for slot in range(mesh.mesh.get_surface_count()):
			var surface := mesh.mesh.surface_get_material(slot)
			if surface != null and surface.resource_name == "FactionTrim":
				var material := mesh.get_surface_override_material(slot) as ShaderMaterial
				return material != null and material.get_shader_parameter("base_color") == tint
	return false


func _label(value: String, pos: Vector3, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stage.add_child(label)


func _clear() -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("FAIL: %s" % message)
		_errors += 1
	return ok

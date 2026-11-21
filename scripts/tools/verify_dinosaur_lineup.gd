extends "res://scripts/tools/verify_crag_born.gd"
## Copy the example GLBs to assets/models/dinosaurs in a scratch project before importing.

const LINEUP := [
	["Velociraptor", "velociraptor", ["Bracken", "Embercrest", "Nightfeather"], "Pounce"],
	["Parasaurolophus", "parasaurolophus", ["Reedbank", "Coppercrest", "Bluecrest"], "Call"],
	["Stegosaurus", "stegosaurus", ["Mossplate", "Rustplate", "Slateplate"], "TailSweep"],
	["Triceratops", "triceratops", ["Ochrefrill", "Redshield", "Ironfrill"], "HeadCharge"],
	["Tyrannosaurus", "tyrannosaurus", ["Sandjaw", "Ridgejaw", "Blackcrown"], "Bite"],
	["Brachiosaurus", "brachiosaurus", ["Fernback", "Sunspine", "Stormneck"], "Browse"],
]
const GROUPS := [[0, 1, 2], [3, 4, 5]]
const TITLES := ["Raptors, crests and plates", "Horns, jaws and long necks"]
const PLATE := Vector2i(1360, 832)
const CELL := Vector2i(416, 176)
const SCALE_CELL := Vector2i(416, 274)
const VIEW := Vector3(-0.79, 0.24, -0.56)
const FIELD := Color("#1c2522")
const CREAM := Color("#fcf0da")
const GOLD := Color("#dfc08d")


func _run() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if not _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK,
			"Pass an absolute writable --out-dir"):
		quit(1)
		return
	_setup_stage()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var shade := _stage.get_child(2) as MeshInstance3D
	(shade.material_override as StandardMaterial3D).albedo_color = Color("#35413b")
	(shade.mesh as PlaneMesh).size = Vector2(180, 180)
	var filter := _stage.get_child(_stage.get_child_count() - 1).get_child(0) as ColorRect
	var material := filter.material as ShaderMaterial
	material.set_shader_parameter("desaturation", 0.04)
	material.set_shader_parameter("dither_strength", 0.26)
	material.set_shader_parameter("brightness_boost", 1.05)
	material.set_shader_parameter("target_resolution", Vector2(780, 439))

	var shots: Array[Image] = []
	var scale_shots: Array[Image] = []
	var dimensions: Array[Vector3] = []
	for data in LINEUP:
		var models: Array[Node3D] = []
		var boxes: Array[AABB] = []
		for label in data[2]:
			var model := _load_dinosaur(data[1], label)
			if model == null:
				quit(1)
				return
			_stage.add_child(model)
			var box := _bounds(model)
			_verify_dinosaur(model, data[3], label)
			if not boxes.is_empty():
				var previous: AABB = boxes.back()
				_check(box.size.y > previous.size.y * 1.15 and box.size.z > previous.size.z * 1.15,
					"%s increases both height and length" % label)
			model.hide()
			models.append(model)
			boxes.append(box)
			dimensions.append(box.size)
		_frame(boxes[2], CELL, 1.04)
		for model in models:
			model.show()
			shots.append(await _shot(CELL))
			model.hide()
		var reference := AABB(Vector3(-1.20, 0.0, -3.85), Vector3(2.40, 8.20, 9.65))
		_frame(reference, SCALE_CELL, 1.04)
		models[1].show()
		scale_shots.append(await _shot(SCALE_CELL))
		print("%s: %.2f m / %.2f m / %.2f m tall | %s" % [data[0], boxes[0].size.y, boxes[1].size.y, boxes[2].size.y, data[3]])
		for model in models:
			model.free()
	_stage.free()
	for i in range(GROUPS.size()):
		await _write_variants(out_dir, shots, dimensions, GROUPS[i], i)
	await _write_scale(out_dir, scale_shots, dimensions)
	if _issues.is_empty():
		print("DINOSAUR LINEUP VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _load_dinosaur(species: String, label: String) -> Node3D:
	var path := "res://assets/models/dinosaurs/%s_%s.glb" % [species, label.to_lower()]
	var packed := load(path) as PackedScene
	if not _check(packed != null, "Import %s" % path):
		return null
	return packed.instantiate() as Node3D


func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_check(not first and bounds.has_volume() and bounds.end.y > 0.5, "Model has a visible silhouette")
	_check(absf(bounds.position.y) < 0.12, "Model meets the ground at rest")
	return bounds


func _verify_dinosaur(model: Node3D, signature: String, variant: String) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if not _check(skeleton != null and skeleton.get_bone_count() >= 15 and player != null and meshes.size() == 1,
			"%s has an articulated skeleton and one mesh" % variant):
		return
	_check((meshes[0] as MeshInstance3D).skin != null, "%s has a bound skin" % variant)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["Idle", "Walk", signature]:
		if not _check(player.has_animation(clip), "%s imports %s" % [variant, clip]):
			continue
		var animation := player.get_animation(clip)
		_check(animation.length > 0.55 and animation.get_track_count() > 5, "%s clip contains authored keys" % clip)
		var should_loop: bool = clip != signature
		_check((animation.loop_mode != Animation.LOOP_NONE) == should_loop, "%s loop flag is correct" % clip)
		player.play(clip)
		player.seek(0.0, true)
		var before: Array[Quaternion] = []
		for bone in range(skeleton.get_bone_count()):
			before.append(skeleton.get_bone_pose_rotation(bone))
		player.seek(animation.length * 0.57, true)
		var moved := false
		for bone in range(skeleton.get_bone_count()):
			if before[bone].angle_to(skeleton.get_bone_pose_rotation(bone)) > 0.012:
				moved = true
				break
		_check(moved, "%s moves the skeleton on %s" % [clip, variant])
	if player.has_animation("Idle"):
		player.play("Idle")
		player.seek(0.0, true)


func _frame(box: AABB, cell: Vector2i, pad: float) -> void:
	var center := box.get_center()
	_camera.position = center + VIEW.normalized() * 26.0
	_camera.look_at(center)
	var view_box := Transform3D(_camera.global_basis.inverse(), Vector3.ZERO) * box
	var height := maxf(view_box.size.y, view_box.size.x * float(cell.y) / cell.x)
	_camera.size = height * pad * root.size.y / cell.y


func _shot(cell: Vector2i) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image.get_region(Rect2i((image.get_size() - cell) / 2, cell))


func _start_plate(title: String, subtitle: String) -> Control:
	var canvas := Control.new()
	root.add_child(canvas)
	_block(canvas, Vector2.ZERO, Vector2(PLATE), FIELD)
	_caption(canvas, title, Vector2(36, 22), 39, CREAM)
	_caption(canvas, subtitle, Vector2(37, 74), 20, GOLD)
	return canvas


func _write_variants(out_dir: String, shots: Array[Image], dimensions: Array[Vector3], group: Array, index: int) -> void:
	var canvas := _start_plate(TITLES[index], "Compact, standard and large variants share a scale within each row")
	for row in range(group.size()):
		var species: int = group[row]
		var data: Array = LINEUP[species]
		var y := 140 + row * 232
		_caption(canvas, data[0], Vector2(36, y - 29), 21, GOLD)
		for column in range(3):
			var x := 35 + column * 437
			var variant := species * 3 + column
			_picture(canvas, shots[variant], Rect2i(Vector2i.ZERO, CELL), Vector2(x, y))
			_caption(canvas, "%s   %.1f m" % [data[2][column], dimensions[variant].y], Vector2(x + 2, y + CELL.y + 3), 20, CREAM)
	await _save_plate(canvas, out_dir.path_join("dinosaurs-variants-%d.png" % (index + 1)))


func _write_scale(out_dir: String, shots: Array[Image], dimensions: Array[Vector3]) -> void:
	var canvas := _start_plate("Christ Fallow dinosaur lineup", "Six standard variants at one scale · heights measured from the game models")
	for i in range(LINEUP.size()):
		var x := 35 + (i % 3) * 437
		var y := 118 + floori(i / 3.0) * 332
		_picture(canvas, shots[i], Rect2i(Vector2i.ZERO, SCALE_CELL), Vector2(x, y))
		_caption(canvas, "%s   %.1f m" % [LINEUP[i][0], dimensions[i * 3 + 1].y], Vector2(x + 3, y + SCALE_CELL.y + 3), 21, CREAM)
	await _save_plate(canvas, out_dir.path_join("dinosaurs-scale.png"))


func _save_plate(canvas: Control, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var plate := root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, PLATE))
	_check(plate.save_png(path) == OK, "Write %s" % path.get_file())
	canvas.free()

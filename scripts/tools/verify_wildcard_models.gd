extends "res://scripts/tools/verify_crag_born.gd"
## Import review GLBs in a staged project under assets/models/wildcard.

const MODELS := [
	["antler_beacon", "Antler Beacon", Vector3(0, 1.36, 0), 9.7, Vector3(-0.28, 0.51, 0.81)],
	["river_fish_weir", "River Fish Weir", Vector3(0, 0.39, -0.38), 10.3, Vector3(-0.13, 0.66, 0.84)],
	["mossback_ibex", "Mossback Ibex", Vector3(0, 1.10, -0.04), 9.0, Vector3(-0.74, 0.39, -0.57)],
	["obsidian_cache", "Obsidian Cache", Vector3(0, 0.32, 0), 8.1, Vector3(-0.28, 0.51, 0.81)],
	["shell_courier_kit", "Shell Courier Kit", Vector3(0, 0.63, 0), 8.1, Vector3(-0.28, 0.51, 0.81)],
	["bone_sled", "Mammoth-Bone Sled", Vector3(0, 0.36, -0.16), 8.8, Vector3(-0.61, 0.49, 0.63)],
]
const TILE := Vector2i(340, 236)
const SHEET := Vector2i(1140, 626)


func _run() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if not _check(out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK, "Set a review output directory"):
		quit(1)
		return
	_setup_stage()
	var gameplay: Array[Image] = []
	var close: Array[Image] = []
	for model_data in MODELS:
		var path := "res://assets/models/wildcard/%s.glb" % model_data[0]
		var scene := load(path) as PackedScene
		if not _check(scene != null, "%s is an importable Blender prototype" % model_data[1]):
			continue
		var model := scene.instantiate() as Node3D
		var mesh_nodes := model.find_children("*", "MeshInstance3D", true, false)
		_check(not mesh_nodes.is_empty() and mesh_nodes[0].get_aabb().get_volume() > 0.0,
			"%s has visible geometry" % model_data[1])
		_stage.add_child(model)
		var focus: Vector3 = model_data[2]
		var close_direction: Vector3 = model_data[4]
		var gameplay_direction := Vector3(0.40, 0.55, 0.71 * signf(close_direction.z))
		gameplay.append(await _view(focus, 12.0, gameplay_direction))
		close.append(await _view(focus, model_data[3], close_direction))
		model.free()
	_stage.free()
	if gameplay.size() == MODELS.size():
		await _write_review(gameplay, "Gameplay scale · 12 m · PSX", out_dir.path_join("wildcard-gameplay.png"))
		await _write_review(close, "Close views · PSX", out_dir.path_join("wildcard-close.png"))
	if _issues.is_empty():
		print("WILDCARD MODEL VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _view(focus: Vector3, distance: float, direction: Vector3) -> Image:
	_camera.position = focus + direction.normalized() * distance
	_camera.look_at(focus)
	await process_frame
	await RenderingServer.frame_post_draw
	var center := Vector2i(_camera.unproject_position(focus))
	return root.get_texture().get_image().get_region(Rect2i(center - TILE / 2, TILE))


func _write_review(shots: Array[Image], subtitle: String, path: String) -> void:
	var canvas := Control.new()
	root.add_child(canvas)
	_block(canvas, Vector2.ZERO, Vector2(SHEET), Color("#232924"))
	_caption(canvas, "Christ Fallow wildcard models", Vector2(35, 22), 32, Color("#f4e9d6"))
	_caption(canvas, subtitle, Vector2(36, 61), 16, Color("#dac08d"))
	for i in range(MODELS.size()):
		var x := 35 + (i % 3) * 365
		var y := 85 + floori(i / 3.0) * 265
		_picture(canvas, shots[i], Rect2i(Vector2i.ZERO, TILE), Vector2(x, y))
		_caption(canvas, "%d. %s" % [i + 1, MODELS[i][1]], Vector2(x + 2, y + 235), 19, Color("#f4e9d6"))
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, SHEET))
	_check(image.save_png(path) == OK, "Write the numbered model sheet")
	canvas.free()

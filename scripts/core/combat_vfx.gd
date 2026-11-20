extends RefCounted
## Shared procedural combat VFX helpers (hit flashes, damage popups, blood pools, slash arcs).

const Look = preload("res://scripts/ui/fallow_theme.gd")

static var _hit_flash_mat: StandardMaterial3D = null


static func get_hit_flash_material() -> StandardMaterial3D:
	if _hit_flash_mat == null:
		_hit_flash_mat = StandardMaterial3D.new()
		_hit_flash_mat.albedo_color = Color(1.0, 0.32, 0.22, 0.72)
		_hit_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hit_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _hit_flash_mat


static func apply_overlay_recursive(node: Node, mat: Material) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = mat
	for child in node.get_children():
		apply_overlay_recursive(child, mat)


static func spawn_damage_popup(anchor: Node3D, text_str: String, col: Color, size_mult: float = 1.0, height_offset: float = 2.15) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var host: Node = GameState.world_node if GameState.world_node != null else anchor.get_tree().current_scene
	if host == null:
		host = anchor.get_parent()
	if host == null:
		return
	var lbl := Label3D.new()
	lbl.text = text_str
	lbl.font = Look.body_font()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = int(28.0 * size_mult)
	lbl.pixel_size = 0.015
	lbl.modulate = col
	lbl.outline_modulate = Look.INK
	lbl.outline_size = 5
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(lbl)
	lbl.global_position = anchor.global_position + Vector3(randf_range(-0.25, 0.25), height_offset, randf_range(-0.25, 0.25))
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	if not bool(Preferences.get_value("reduced_motion")):
		tw.tween_property(lbl, "position:y", lbl.position.y + 1.15, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.12)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.85).set_delay(0.12)
	tw.chain().tween_callback(lbl.queue_free)


static func spawn_blood_pool(parent: Node3D, radius: float = 0.70) -> void:
	if parent == null:
		return
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 1.08
	cm.height = 0.03
	cm.radial_segments = 10
	pool.mesh = cm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.32, 0.03, 0.03, 0.88)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.roughness = 0.35
	pool.material_override = pmat
	pool.position = Vector3(0.0, 0.03, 0.0)
	pool.scale = Vector3(0.15, 1.0, 0.15)
	parent.add_child(pool)
	var tw := pool.create_tween()
	tw.tween_property(pool, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func spawn_slash_arc(host: Node, origin: Vector3, forward_dir: Vector3, col: Color = Color(1.0, 0.90, 0.55, 0.85), arc_scale: float = 1.0) -> void:
	if host == null:
		return
	var arc := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.15 * arc_scale
	tm.outer_radius = 1.55 * arc_scale
	tm.rings = 10
	tm.ring_segments = 6
	arc.mesh = tm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = col
	smat.emission_enabled = true
	smat.emission = Color(col.r, col.g, col.b, 1.0)
	smat.emission_energy_multiplier = 2.0
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.material_override = smat
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dir := Vector3(forward_dir.x, 0.0, forward_dir.z).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	arc.position = origin + Vector3(0.0, 1.05, 0.0) + dir * (0.9 * arc_scale)
	arc.rotation.y = atan2(-dir.x, -dir.z) - 0.65
	arc.rotation.z = deg_to_rad(-16.0)
	arc.scale = Vector3(0.55, 0.18, 0.55)
	host.add_child(arc)
	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "rotation:y", arc.rotation.y + 1.35, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "scale", Vector3(1.15, 0.18, 1.15), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(smat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(arc.queue_free)

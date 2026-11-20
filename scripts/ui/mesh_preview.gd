extends SubViewportContainer

var _viewport: SubViewport
var _camera: Camera3D
var _model: Node3D


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.world_3d = World3D.new()
	_viewport.gui_disable_input = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("becbbd")
	environment.environment.ambient_light_energy = 0.73
	_viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -38, 0)
	sun.light_color = Color("ffd4a3")
	sun.light_energy = 1.17
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)


func show_model(model: Node3D, camera_offset: Vector3, zoom: float = 1.0) -> void:
	if _model != null:
		_viewport.remove_child(_model)
		_model.queue_free()
	_model = model
	_viewport.add_child(_model)
	var bounds := AABB()
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var mesh_bounds := mesh.global_transform * mesh.get_aabb()
		bounds = mesh_bounds if not bounds.has_volume() else bounds.merge(mesh_bounds)
	var look_at_point := bounds.get_center()
	_camera.position = look_at_point + camera_offset
	_camera.look_at(look_at_point)
	_camera.size = maxf(1.0, bounds.size.length() * zoom)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

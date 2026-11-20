extends Node3D

const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const Look = preload("res://scripts/ui/fallow_theme.gd")

var _ring: MeshInstance3D = null
var _marker_pivot: Node3D = null
var _prompt_label: Label3D = null
var _anim_time: float = 0.0
var _prompt_text: String = ""


func _init() -> void:
	name = "TutorialBeacon"
	visible = false
	_build_visuals()


func _build_visuals() -> void:
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.84, 0.28, 0.86)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.render_priority = 2

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.88
	ring_mesh.outer_radius = 1.18
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6

	_ring = MeshInstance3D.new()
	_ring.name = "GroundRing"
	_ring.mesh = ring_mesh
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(0.0, 0.08, 0.0)
	add_child(_ring)

	_marker_pivot = Node3D.new()
	_marker_pivot.name = "MarkerPivot"
	_marker_pivot.position = Vector3(0.0, 2.6, 0.0)
	add_child(_marker_pivot)

	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.92, 0.42, 0.95)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.render_priority = 2

	var diamond_mesh := SphereMesh.new()
	diamond_mesh.radius = 0.28
	diamond_mesh.height = 0.72
	diamond_mesh.radial_segments = 4
	diamond_mesh.rings = 2

	var diamond := MeshInstance3D.new()
	diamond.name = "DiamondMarker"
	diamond.mesh = diamond_mesh
	diamond.material_override = marker_mat
	diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker_pivot.add_child(diamond)

	var chevron_mesh := CylinderMesh.new()
	chevron_mesh.top_radius = 0.22
	chevron_mesh.bottom_radius = 0.0
	chevron_mesh.height = 0.42
	chevron_mesh.radial_segments = 4

	var chevron := MeshInstance3D.new()
	chevron.name = "ChevronPointer"
	chevron.mesh = chevron_mesh
	chevron.material_override = marker_mat
	chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chevron.position = Vector3(0.0, -0.58, 0.0)
	_marker_pivot.add_child(chevron)

	_prompt_label = Label3D.new()
	_prompt_label.name = "ProximityPrompt"
	_prompt_label.font = Look.body_font()
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.font_size = 30
	_prompt_label.pixel_size = 0.014
	_prompt_label.modulate = Color(1.0, 0.93, 0.48)
	_prompt_label.outline_modulate = Look.INK
	_prompt_label.outline_size = 6
	_prompt_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prompt_label.position = Vector3(0.0, 2.05, 0.0)
	_prompt_label.visible = false
	add_child(_prompt_label)


func sync_with_state(leader: Node, delta: float = 0.0) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		_hide_beacon()
		return

	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	if not bool(target.get("active", false)) or not bool(target.get("has_position", false)):
		_hide_beacon()
		return

	var target_pos: Vector3 = target["position"]
	visible = true
	global_position = Vector3(target_pos.x, 0.0, target_pos.z)

	_anim_time += delta
	if bool(Preferences.get_value("reduced_motion")):
		_marker_pivot.position.y = 2.6
		_marker_pivot.rotation.y = 0.0
		_ring.scale = Vector3.ONE
	else:
		_marker_pivot.position.y = 2.6 + sin(_anim_time * 3.2) * 0.25
		_marker_pivot.rotation.y = fmod(_anim_time * 1.4, TAU)
		var pulse: float = 1.0 + sin(_anim_time * 4.0) * 0.08
		_ring.scale = Vector3(pulse, 1.0, pulse)

	var next_prompt := ""
	if is_instance_valid(leader) and leader.get("is_dead") != true:
		var lpos: Vector3 = (leader as Node3D).global_position
		var dist: float = Vector2(lpos.x - global_position.x, lpos.z - global_position.z).length()
		var step: int = int(target.get("step", 0))
		if step == 1 and dist <= 6.5:
			next_prompt = "[E] Recruit"
		elif step == 3 and not bool(GameState.tutorial_harvested) and dist <= 5.2:
			next_prompt = "[E] Harvest"
		elif step == 4 and AwakeningGuide.find_pending_building(GameState, "SLEEPING_HUT", lpos) != null and dist <= 5.0:
			next_prompt = "[E] Help Build"

	_prompt_text = next_prompt
	_prompt_label.text = next_prompt
	_prompt_label.visible = not next_prompt.is_empty()


func _hide_beacon() -> void:
	visible = false
	_prompt_text = ""
	if _prompt_label != null:
		_prompt_label.visible = false
		_prompt_label.text = ""


func is_beacon_visible() -> bool:
	return visible


func get_beacon_position() -> Vector3:
	return global_position


func get_prompt_text() -> String:
	return _prompt_text

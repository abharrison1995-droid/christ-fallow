extends Control

signal close_requested

const Look = preload("res://scripts/ui/fallow_theme.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const TERRAIN := Color("293a30")
const WATER := Color("527f84")
const MAX_ZOOM := 4.0

var waypoint: Variant = null
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _redraw_timer := 0.0
var _map_area: Control
var _surface: Control
var _clear_button: Button
var _close_button: Button
var _zoom_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color("141b18")
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layout.offset_left = 24.0
	layout.offset_right = -24.0
	layout.offset_top = 18.0
	layout.offset_bottom = -18.0
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	var title := Look.label("World Map", &"SectionTitle", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	var zoom_out := Look.button("−", func(): _zoom_at(_map_area.size * 0.5, 0.8))
	zoom_out.tooltip_text = "Zoom out"
	toolbar.add_child(zoom_out)
	_zoom_label = Look.label("100%")
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.custom_minimum_size.x = 58.0
	toolbar.add_child(_zoom_label)
	var zoom_in := Look.button("+", func(): _zoom_at(_map_area.size * 0.5, 1.25))
	zoom_in.tooltip_text = "Zoom in"
	toolbar.add_child(zoom_in)
	toolbar.add_child(Look.button("Reset view", _reset_view))
	_clear_button = Look.button("Clear waypoint", _clear_waypoint)
	toolbar.add_child(_clear_button)
	_close_button = Look.button("Close  [Esc]", func(): close_requested.emit())
	toolbar.add_child(_close_button)

	var map_frame := PanelContainer.new()
	map_frame.add_theme_stylebox_override("panel", Look.panel(Color("19241e"), Look.EDGE, 1, 0))
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(map_frame)
	_map_area = Control.new()
	_map_area.clip_contents = true
	_map_area.mouse_filter = MOUSE_FILTER_STOP
	_map_area.mouse_default_cursor_shape = CURSOR_CROSS
	map_frame.add_child(_map_area)
	_map_area.gui_input.connect(_on_map_input)
	_map_area.resized.connect(_clamp_pan)
	_surface = Control.new()
	_surface.mouse_filter = MOUSE_FILTER_IGNORE
	_map_area.add_child(_surface)
	_surface.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_surface.draw.connect(_draw_map)
	var controls := Look.label("Drag with right mouse to pan   ·   Scroll to zoom   ·   Click to place a waypoint", &"", 15)
	controls.modulate = Look.MUTED
	layout.add_child(controls)
	clear_campaign()


func open() -> void:
	_dragging = false
	show()
	_close_button.grab_focus()
	_surface.queue_redraw()


func close() -> void:
	_dragging = false
	hide()


func clear_campaign() -> void:
	_clear_waypoint()
	_reset_view()
	close()


func _process(delta: float) -> void:
	if not visible:
		return
	_redraw_timer += delta
	if _redraw_timer >= 0.1:
		_redraw_timer = 0.0
		_surface.queue_redraw()


func world_to_map(point: Vector3) -> Vector2:
	return _map_area.size * 0.5 + _pan + Vector2(point.x, point.z) * _pixels_per_meter()


func map_to_world(point: Vector2) -> Vector3:
	var xz := (point - _map_area.size * 0.5 - _pan) / _pixels_per_meter()
	return Vector3(xz.x, 0.0, xz.y)


func _pixels_per_meter() -> float:
	var width := GameState.valley_layout.ground_size.x
	return maxf(0.0001, minf(_map_area.size.x, _map_area.size.y) * 0.90 * _zoom / width)


func _clamp_pan() -> void:
	var half_world := GameState.valley_layout.ground_size * _pixels_per_meter() * 0.5
	var limit := (half_world - _map_area.size * 0.2).max(Vector2.ZERO)
	_pan = _pan.clamp(-limit, limit)
	_surface.queue_redraw()


func _zoom_at(cursor: Vector2, factor: float) -> void:
	var anchor := map_to_world(cursor)
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	_pan += cursor - world_to_map(anchor)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
	_clamp_pan()


func _reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_zoom_label.text = "100%"
	_surface.queue_redraw()


func _clear_waypoint() -> void:
	waypoint = null
	_clear_button.disabled = true
	_surface.queue_redraw()


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					var point := map_to_world(event.position)
					var half := GameState.valley_layout.ground_size * 0.5
					if absf(point.x) <= half.x and absf(point.z) <= half.y:
						waypoint = point
						_clear_button.disabled = false
						_surface.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_clamp_pan()
		get_viewport().set_input_as_handled()


func _draw_map() -> void:
	if not GameState.game_active or GameState.wildlife_container == null:
		return
	var geography := GameState.valley_layout
	var half := geography.ground_size * 0.5
	var top_left := world_to_map(Vector3(-half.x, 0.0, -half.y))
	var bounds := Rect2(top_left, geography.ground_size * _pixels_per_meter())
	_surface.draw_rect(bounds, TERRAIN)
	for line in range(-int(half.x / 50.0), int(half.x / 50.0) + 1):
		var meter := float(line) * 50.0
		var x := world_to_map(Vector3(meter, 0.0, 0.0)).x
		var y := world_to_map(Vector3(0.0, 0.0, meter)).y
		_surface.draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), Color("33463b"))
		_surface.draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color("33463b"))
	_surface.draw_rect(bounds, Look.EDGE, false, 1.0)
	var river_start := world_to_map(geography.river_start())
	var river_end := world_to_map(geography.river_end())
	_surface.draw_line(river_start, river_end, WATER, maxf(5.0, geography.river_width * _pixels_per_meter()), true)
	for ford in geography.river_crossings():
		_marker(ford["pos"], "Ford", Look.MUTED, 3.0)
	for point in geography.cave_positions:
		_marker(point, "Bone cave", Look.DANGER, 4.0)
	for id in GameState.factions:
		var faction: Dictionary = GameState.factions[id]
		if faction["is_founded"] and not faction["is_defeated"] and id != 5:
			var color: Color = GameData.FACTION_COLORS.get(id, Look.BONE)
			_marker(faction["camp_position"], faction["name"], color.lightened(0.30), 5.0)
	for animal in GameState.wildlife_container.get_children():
		if animal.is_boss and not animal.is_dead:
			_marker(animal.global_position, animal.animal_name, Look.MOSS, 3.0)
	var objective := AwakeningGuide.get_objective_target(GameState)
	if objective.get("active", false) and objective.get("has_position", false):
		_marker(objective["position"], "Awakening objective", Look.GOLD, 7.0, Vector2(-9, -7))
	var leader := GameState.get_faction_leader(0) as Node3D
	if leader != null:
		_marker(leader.global_position, "You", Color.WHITE, 5.0, Vector2(9, 17))
	if waypoint is Vector3:
		_marker(waypoint, "Waypoint", Look.ICE, 7.0, Vector2(-9, 18))
	var font := get_theme_default_font()
	_surface.draw_string(font, Vector2(_map_area.size.x - 34.0, 31.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Look.GOLD)
	var meters := 50 if _zoom >= 2.5 else 100
	var measure_end := _map_area.size - Vector2(20, 22)
	var measure_start := measure_end - Vector2(float(meters) * _pixels_per_meter(), 0.0)
	_surface.draw_line(measure_start, measure_end, Look.MUTED, 2.0)
	_surface.draw_line(measure_start - Vector2(0, 4), measure_start + Vector2(0, 4), Look.MUTED, 2.0)
	_surface.draw_line(measure_end - Vector2(0, 4), measure_end + Vector2(0, 4), Look.MUTED, 2.0)
	_surface.draw_string(font, measure_start - Vector2(0, 8), "%d m" % meters, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Look.MUTED)


func _marker(point: Vector3, label: String, color: Color, radius: float, label_offset := Vector2(9, -6)) -> void:
	var pos := world_to_map(point)
	if not Rect2(Vector2.ZERO, _map_area.size).has_point(pos):
		return
	var diamond := PackedVector2Array([pos + Vector2.UP * radius, pos + Vector2.RIGHT * radius,
		pos + Vector2.DOWN * radius, pos + Vector2.LEFT * radius])
	_surface.draw_colored_polygon(diamond, color)
	var font := get_theme_default_font()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	var label_position := pos + label_offset
	if label_offset.x < 0.0:
		label_position.x -= text_size.x
	label_position.x = clampf(label_position.x, 5.0, maxf(5.0, _map_area.size.x - text_size.x - 5.0))
	label_position.y = clampf(label_position.y, text_size.y, maxf(text_size.y, _map_area.size.y - 5.0))
	_surface.draw_string(font, label_position + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Look.INK)
	_surface.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)

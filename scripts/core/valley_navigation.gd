extends RefCounted
## AStarGrid2D-backed valley pathing with river fords and dynamic building obstacles.
## Grid x/y maps to world X/Z. Loaded via preload (no class_name).

const CELL_SIZE := 4.0
const FOOTPRINT_MARGIN := 0.0
## Building types that never block movement.
const NON_SOLID_TYPES: Array[String] = []

const WorldLayout = preload("res://scripts/core/world_layout.gd")

var _grid: AStarGrid2D = null
var _origin := Vector2.ZERO # world XZ of grid cell (0,0) min corner
var _size := Vector2i.ZERO
var _river_center := Vector3.ZERO
var _river_length: float = 0.0
var _river_width: float = 0.0
var _river_rot_deg: float = 0.0
var _fords: Array = []
var _river_solid: Dictionary = {} # Vector2i -> true (deep, non-ford river cells)
var _block_count: Dictionary = {} # Vector2i -> int (building refs)
var _obstacles: Dictionary = {} # instance_id -> Array[Vector2i]

## Builds the grid from WorldLayout bounds. River local axes: X = width, Z = length;
## rotation_deg is rotation about Y (same as MeshInstance3D.rotation_degrees.y).
## fords: Array of {pos: Vector3, half_width: float}.
func configure_from_layout(river_center: Vector3 = Vector3.ZERO, river_length: float = 0.0, river_width: float = 0.0, river_rotation_deg: float = 0.0, fords: Array = []) -> void:
	clear()
	var half: float = WorldLayout.GROUND_SIZE.x * 0.5
	var halfz: float = WorldLayout.GROUND_SIZE.y * 0.5
	_origin = Vector2(-half, -halfz)
	_size = Vector2i(int(ceilf(WorldLayout.GROUND_SIZE.x / CELL_SIZE)), int(ceilf(WorldLayout.GROUND_SIZE.y / CELL_SIZE)))
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _size)
	_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.update()
	_river_center = river_center
	_river_length = river_length
	_river_width = river_width
	_river_rot_deg = river_rotation_deg
	_fords = fords.duplicate(true)
	_bake_river()

## Scans world_node for BuildingEntity nodes and registers their obstacles.
func rebuild_from_world(world_node: Node) -> void:
	_clear_buildings()
	if world_node == null or _grid == null:
		return
	_scan_buildings(world_node)

func _scan_buildings(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D and "building_type" in c and "is_constructed" in c:
			if c.get("is_constructed") == true and c.get("is_destroyed") != true:
				var r: float = float(c.call("_nav_footprint_radius")) if c.has_method("_nav_footprint_radius") else _default_radius(String(c.get("building_type")))
				register_building_obstacle(c, String(c.get("building_type")), r)
			continue
		_scan_buildings(c)

static func _default_radius(building_type: String) -> float:
	if building_type == "PALISADE_WALL":
		return 2.0
	return 3.0

func clear() -> void:
	_grid = null
	_river_solid.clear()
	_block_count.clear()
	_obstacles.clear()
	_fords.clear()

func is_ready() -> bool:
	return _grid != null

# ---------- coordinates ----------
func world_to_cell(p: Vector3) -> Vector2i:
	var cx: int = clampi(int(floorf((p.x - _origin.x) / CELL_SIZE)), 0, _size.x - 1)
	var cz: int = clampi(int(floorf((p.z - _origin.y) / CELL_SIZE)), 0, _size.y - 1)
	return Vector2i(cx, cz)

func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(_origin.x + (float(c.x) + 0.5) * CELL_SIZE, 0.0, _origin.y + (float(c.y) + 0.5) * CELL_SIZE)

# ---------- river ----------
func _in_river(p: Vector3) -> bool:
	if _river_length <= 0.0 or _river_width <= 0.0:
		return false
	var local: Vector3 = Basis(Vector3.UP, deg_to_rad(_river_rot_deg)).inverse() * (p - _river_center)
	return absf(local.x) <= _river_width * 0.5 and absf(local.z) <= _river_length * 0.5

func _in_ford(p: Vector3) -> bool:
	for f in _fords:
		var fp: Vector3 = f.get("pos", Vector3.ZERO)
		var hw: float = float(f.get("half_width", 0.0))
		var dx: float = p.x - fp.x
		var dz: float = p.z - fp.z
		if dx * dx + dz * dz <= hw * hw:
			return true
	return false

func _bake_river() -> void:
	if _grid == null or _river_length <= 0.0:
		return
	# Cells whose centre OR corners touch deep water are impassable, so diagonals cannot leak.
	var q: float = CELL_SIZE * 0.5
	for x in range(_size.x):
		for z in range(_size.y):
			var c := Vector2i(x, z)
			var p: Vector3 = cell_to_world(c)
			var wet: bool = _in_river(p)
			if not wet:
				for off in [Vector3(q, 0, q), Vector3(-q, 0, q), Vector3(q, 0, -q), Vector3(-q, 0, -q)]:
					if _in_river(p + off):
						wet = true
						break
			if wet and not _in_ford(p):
				_river_solid[c] = true
				_grid.set_point_solid(c, true)

func is_cell_blocked(c: Vector2i) -> bool:
	if _grid == null or not _grid.is_in_boundsv(c):
		return true
	return _grid.is_point_solid(c)

# ---------- buildings ----------
func register_building_obstacle(building: Node3D, building_type: String, footprint_radius: float) -> void:
	if _grid == null or building == null or not is_instance_valid(building):
		return
	var id: int = building.get_instance_id()
	if _obstacles.has(id):
		unregister_building_obstacle(building)
	var r: float = maxf(footprint_radius + FOOTPRINT_MARGIN, 0.0)
	var p: Vector3 = building.global_position
	var lo: Vector2i = world_to_cell(Vector3(p.x - r, 0, p.z - r))
	var hi: Vector2i = world_to_cell(Vector3(p.x + r, 0, p.z + r))
	var cells: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var c := Vector2i(x, z)
			var cp: Vector3 = cell_to_world(c)
			# include cell if its centre is inside the footprint square (always include the centre cell)
			if (absf(cp.x - p.x) <= r and absf(cp.z - p.z) <= r) or c == world_to_cell(p):
				cells.append(c)
				_block_count[c] = int(_block_count.get(c, 0)) + 1
				_grid.set_point_solid(c, true)
	_obstacles[id] = cells

func unregister_building_obstacle(building: Node3D) -> void:
	if building == null:
		return
	_release_id(building.get_instance_id() if is_instance_valid(building) else -1)

## Remove obstacles whose building node has been freed (safe to call periodically).
func prune_freed_obstacles() -> void:
	for id in _obstacles.keys():
		if not is_instance_id_valid(int(id)):
			_release_id(int(id))

func _release_id(id: int) -> void:
	if _grid == null or not _obstacles.has(id):
		return
	for c in (_obstacles[id] as Array):
		var cell: Vector2i = c
		var n: int = int(_block_count.get(cell, 0)) - 1
		if n <= 0:
			_block_count.erase(cell)
			if not _river_solid.has(cell):
				_grid.set_point_solid(cell, false)
		else:
			_block_count[cell] = n
	_obstacles.erase(id)

func _clear_buildings() -> void:
	for id in _obstacles.keys():
		_release_id(int(id))
	_obstacles.clear()
	_block_count.clear()

# ---------- pathing ----------
func _nearest_passable(c: Vector2i) -> Vector2i:
	if not is_cell_blocked(c):
		return c
	for ring in range(1, 12):
		var best := Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var n := Vector2i(c.x + dx, c.y + dz)
				if not is_cell_blocked(n):
					var d: int = dx * dx + dz * dz
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return c

## DDA grid walk: true when no blocked cell lies between the two cells.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	if _grid == null:
		return false
	var dx: int = absi(b.x - a.x)
	var dz: int = absi(b.y - a.y)
	var sx: int = 1 if b.x > a.x else -1
	var sz: int = 1 if b.y > a.y else -1
	var x: int = a.x
	var z: int = a.y
	var err: int = dx - dz
	var guard: int = dx + dz + 2
	while guard > 0:
		guard -= 1
		# start/end cells are allowed to be blocked (edge snapping); interior cells are not
		if (x != a.x or z != a.y) and (x != b.x or z != b.y) and is_cell_blocked(Vector2i(x, z)):
			return false
		if x == b.x and z == b.y:
			return true
		var e2: int = 2 * err
		var step_x: bool = e2 > -dz
		var step_z: bool = e2 < dx
		# forbid corner cutting between two blocked neighbours
		if step_x and step_z:
			if is_cell_blocked(Vector2i(x + sx, z)) or is_cell_blocked(Vector2i(x, z + sz)):
				return false
		if step_x:
			err -= dz
			x += sx
		if step_z:
			err += dx
			z += sz
	return true

## World-space XZ waypoints (y = 0), excluding the start, ending exactly at to_world.
func find_path(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var goal := Vector3(to_world.x, 0.0, to_world.z)
	if _grid == null:
		out.append(goal)
		return out
	var a: Vector2i = world_to_cell(from_world)
	var b: Vector2i = world_to_cell(to_world)
	if a == b or has_line_of_sight(a, b):
		out.append(goal)
		return out
	var sa: Vector2i = _nearest_passable(a)
	var sb: Vector2i = _nearest_passable(b)
	if is_cell_blocked(sa) or is_cell_blocked(sb):
		out.append(goal)
		return out
	var ids: Array[Vector2i] = _grid.get_id_path(sa, sb)
	if ids.size() <= 1:
		out.append(goal)
		return out
	for i in range(1, ids.size() - 1):
		out.append(cell_to_world(ids[i]))
	out.append(goal)
	return out

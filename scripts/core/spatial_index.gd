extends RefCounted
## 2D (XZ) spatial hash for units, wildlife and buildings, plus per-faction caches.
## Loaded via preload (no class_name). Entities are handled untyped (duck-typed on
## `faction_id`, `is_leader`, `is_dead`, `is_constructed`, `is_destroyed`, `building_type`).

const CELL_SIZE := 20.0
const INV_CELL := 1.0 / CELL_SIZE

# kind -> {cell: Vector2i -> Array[Node3D]}
var _unit_cells: Dictionary = {}
var _wild_cells: Dictionary = {}
var _bld_cells: Dictionary = {}
# instance_id -> Vector2i (current cell)
var _unit_at: Dictionary = {}
var _wild_at: Dictionary = {}
var _bld_at: Dictionary = {}
# faction_id -> Array of nodes
var _faction_units: Dictionary = {}
var _faction_buildings: Dictionary = {}
# faction_id -> leader node
var _leaders: Dictionary = {}

static func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floorf(pos.x * INV_CELL)), int(floorf(pos.z * INV_CELL)))

static func _valid(n: Object) -> bool:
	return n != null and is_instance_valid(n) and not (n as Node).is_queued_for_deletion()

func clear() -> void:
	_unit_cells.clear()
	_wild_cells.clear()
	_bld_cells.clear()
	_unit_at.clear()
	_wild_at.clear()
	_bld_at.clear()
	_faction_units.clear()
	_faction_buildings.clear()
	_leaders.clear()

## Drops everything, then registers every unit/wildlife/building found under world_node.
func rebuild_from_world(world_node: Node) -> void:
	clear()
	if world_node == null:
		return
	_scan(world_node)

func _scan(n: Node) -> void:
	for c in n.get_children():
		if not _valid(c):
			continue
		if c is Node3D:
			var path: String = ""
			var s: Variant = c.get_script()
			if s != null:
				path = (s as Script).resource_path
			if path.ends_with("human_unit.gd"):
				register_unit(c)
				continue
			elif path.ends_with("wildlife_entity.gd"):
				register_wildlife(c)
				continue
			elif path.ends_with("building_entity.gd"):
				register_building(c)
				continue
		_scan(c)

# ---------- generic cell helpers ----------
func _cell_add(cells: Dictionary, at: Dictionary, n: Node3D) -> void:
	var id: int = n.get_instance_id()
	var cell: Vector2i = cell_of(n.global_position)
	var arr: Array = cells.get(cell, [])
	if arr.is_empty():
		cells[cell] = arr
	arr.append(n)
	at[id] = cell

func _cell_remove(cells: Dictionary, at: Dictionary, id: int, n: Node3D) -> void:
	if not at.has(id):
		return
	var cell: Vector2i = at[id]
	at.erase(id)
	var arr: Array = cells.get(cell, [])
	arr.erase(n)
	if arr.is_empty():
		cells.erase(cell)

func _cell_move(cells: Dictionary, at: Dictionary, n: Node3D) -> void:
	var id: int = n.get_instance_id()
	if not at.has(id):
		_cell_add(cells, at, n)
		return
	var new_cell: Vector2i = cell_of(n.global_position)
	if new_cell == (at[id] as Vector2i):
		return
	_cell_remove(cells, at, id, n)
	_cell_add(cells, at, n)

func _cell_query(cells: Dictionary, at: Dictionary, pos: Vector3, radius: float, dead_flag: String) -> Array:
	var out: Array = []
	var lo: Vector2i = cell_of(Vector3(pos.x - radius, 0.0, pos.z - radius))
	var hi: Vector2i = cell_of(Vector3(pos.x + radius, 0.0, pos.z + radius))
	var r2: float = radius * radius
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cz)
			if not cells.has(key):
				continue
			var arr: Array = cells[key]
			var i: int = arr.size() - 1
			while i >= 0:
				var n: Node3D = arr[i] as Node3D
				if not _valid(n):
					# lazy prune of freed/queued nodes
					arr.remove_at(i)
					i -= 1
					continue
				if dead_flag != "" and n.get(dead_flag) == true:
					i -= 1
					continue
				var d: Vector3 = n.global_position - pos
				if d.x * d.x + d.z * d.z <= r2:
					out.append(n)
				i -= 1
			if arr.is_empty():
				cells.erase(key)
	return out

# ---------- units ----------
func register_unit(unit: Node3D) -> void:
	if not _valid(unit):
		return
	var id: int = unit.get_instance_id()
	if _unit_at.has(id):
		_cell_move(_unit_cells, _unit_at, unit)
		return
	_cell_add(_unit_cells, _unit_at, unit)
	var fid: int = int(unit.get("faction_id"))
	var arr: Array = _faction_units.get(fid, [])
	if arr.is_empty():
		_faction_units[fid] = arr
	arr.append(unit)
	if unit.get("is_leader") == true:
		_leaders[fid] = unit

func update_unit(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_cell_move(_unit_cells, _unit_at, unit)

func unregister_unit(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		_prune_all()
		return
	var id: int = unit.get_instance_id()
	if not _unit_at.has(id):
		return
	_cell_remove(_unit_cells, _unit_at, id, unit)
	var fid: int = int(unit.get("faction_id"))
	if not _remove_from_faction(_faction_units, fid, unit):
		for k in _faction_units.keys():
			if _remove_from_faction(_faction_units, int(k), unit):
				break
	for k in _leaders.keys():
		if _leaders[k] == unit:
			_leaders.erase(k)

func query_units_in_radius(pos: Vector3, radius: float) -> Array:
	return _cell_query(_unit_cells, _unit_at, pos, radius, "is_dead")

## Call BEFORE/AFTER changing faction_id; old_fid is the previous faction.
func on_unit_faction_changed(unit: Node3D, old_fid: int, new_fid: int) -> void:
	if old_fid == new_fid or not _valid(unit):
		return
	if not _unit_at.has(unit.get_instance_id()):
		return
	_remove_from_faction(_faction_units, old_fid, unit)
	if _leaders.get(old_fid) == unit:
		_leaders.erase(old_fid)
	var arr: Array = _faction_units.get(new_fid, [])
	if arr.is_empty():
		_faction_units[new_fid] = arr
	if not arr.has(unit):
		arr.append(unit)
	if unit.get("is_leader") == true:
		_leaders[new_fid] = unit

func on_unit_leader_changed(unit: Node3D) -> void:
	if not _valid(unit):
		return
	var fid: int = int(unit.get("faction_id"))
	if unit.get("is_leader") == true:
		_leaders[fid] = unit
	elif _leaders.get(fid) == unit:
		_leaders.erase(fid)

## Living units of a faction (fresh array; pruned of freed/dead nodes).
func get_faction_units(faction_id: int) -> Array:
	var out: Array = []
	var arr: Array = _faction_units.get(faction_id, [])
	var i: int = arr.size() - 1
	while i >= 0:
		var n: Node3D = arr[i] as Node3D
		if not _valid(n):
			arr.remove_at(i)
		i -= 1
	for n in arr:
		if n.get("is_dead") != true:
			out.append(n)
	return out

func get_faction_leader(faction_id: int) -> Node3D:
	var l: Node3D = _leaders.get(faction_id) as Node3D
	if _valid(l) and l.get("is_dead") != true and l.get("is_leader") == true:
		return l
	_leaders.erase(faction_id)
	for n in get_faction_units(faction_id):
		if n.get("is_leader") == true:
			_leaders[faction_id] = n
			return n as Node3D
	return null

# ---------- wildlife ----------
func register_wildlife(animal: Node3D) -> void:
	if _valid(animal):
		_cell_move(_wild_cells, _wild_at, animal)

func update_wildlife(animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal):
		return
	_cell_move(_wild_cells, _wild_at, animal)

func unregister_wildlife(animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal):
		_prune_all()
		return
	_cell_remove(_wild_cells, _wild_at, animal.get_instance_id(), animal)

func query_wildlife_in_radius(pos: Vector3, radius: float) -> Array:
	return _cell_query(_wild_cells, _wild_at, pos, radius, "is_dead")

# ---------- buildings ----------
func register_building(building: Node3D) -> void:
	if not _valid(building):
		return
	var id: int = building.get_instance_id()
	if _bld_at.has(id):
		return
	_cell_add(_bld_cells, _bld_at, building)
	var fid: int = int(building.get("faction_id"))
	var arr: Array = _faction_buildings.get(fid, [])
	if arr.is_empty():
		_faction_buildings[fid] = arr
	arr.append(building)

func unregister_building(building: Node3D) -> void:
	if building == null or not is_instance_valid(building):
		_prune_all()
		return
	var id: int = building.get_instance_id()
	if not _bld_at.has(id):
		return
	_cell_remove(_bld_cells, _bld_at, id, building)
	var fid: int = int(building.get("faction_id"))
	if not _remove_from_faction(_faction_buildings, fid, building):
		for k in _faction_buildings.keys():
			if _remove_from_faction(_faction_buildings, int(k), building):
				break

func query_buildings_in_radius(pos: Vector3, radius: float) -> Array:
	return _cell_query(_bld_cells, _bld_at, pos, radius, "is_destroyed")

## Mirrors GameState.get_faction_buildings semantics: destroyed buildings are excluded.
func get_faction_buildings(faction_id: int, building_type: String = "", constructed_only: bool = false) -> Array:
	var out: Array = []
	var arr: Array = _faction_buildings.get(faction_id, [])
	var i: int = arr.size() - 1
	while i >= 0:
		if not _valid(arr[i] as Node3D):
			arr.remove_at(i)
		i -= 1
	for b in arr:
		if b.get("is_destroyed") == true:
			continue
		if building_type != "" and String(b.get("building_type")) != building_type:
			continue
		if constructed_only and b.get("is_constructed") != true:
			continue
		out.append(b)
	return out

# ---------- internals ----------
func _remove_from_faction(reg: Dictionary, fid: int, n: Node3D) -> bool:
	if not reg.has(fid):
		return false
	var arr: Array = reg[fid]
	var idx: int = arr.find(n)
	if idx < 0:
		return false
	arr.remove_at(idx)
	return true

## Removes freed instances everywhere (used when an invalid ref was passed to unregister).
func _prune_all() -> void:
	for pair in [[_unit_cells, _unit_at], [_wild_cells, _wild_at], [_bld_cells, _bld_at]]:
		var cells: Dictionary = pair[0]
		var at: Dictionary = pair[1]
		for key in cells.keys():
			var arr: Array = cells[key]
			var i: int = arr.size() - 1
			while i >= 0:
				if not _valid(arr[i] as Node3D):
					arr.remove_at(i)
				i -= 1
			if arr.is_empty():
				cells.erase(key)
		for id in at.keys():
			if not is_instance_id_valid(int(id)):
				at.erase(id)
	for reg in [_faction_units, _faction_buildings]:
		var d: Dictionary = reg
		for fid in d.keys():
			var arr2: Array = d[fid]
			var j: int = arr2.size() - 1
			while j >= 0:
				if not _valid(arr2[j] as Node3D):
					arr2.remove_at(j)
				j -= 1

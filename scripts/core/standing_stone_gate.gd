extends RefCounted

const TYPE := "STANDING_STONE_GATE"
const PIER_OFFSET := 1.25
const PIER_SIZE := Vector3(1.04, 2.51, 1.05)
const UNIT_CLEARANCE := 0.40


static func pier_bounds(side: float) -> Rect2:
	var half := Vector2(PIER_SIZE.x, PIER_SIZE.z) * 0.5 + Vector2.ONE * UNIT_CLEARANCE
	return Rect2(Vector2(side * PIER_OFFSET, 0.0) - half, half * 2.0)


static func crosses_pier(gate: Node3D, from_world: Vector3, to_world: Vector3) -> bool:
	var local_a := gate.to_local(from_world)
	var local_b := gate.to_local(to_world)
	var a := Vector2(local_a.x, local_a.z)
	var b := Vector2(local_b.x, local_b.z)
	for side in [-1.0, 1.0]:
		var bounds := pier_bounds(side)
		if bounds.has_point(a) or bounds.has_point(b):
			return true
		var corners := _corners(bounds)
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
				return true
	return false


static func detour_corners(gate: Node3D) -> PackedVector3Array:
	var corners := PackedVector3Array()
	for side in [-1.0, 1.0]:
		for corner in _corners(pier_bounds(side).grow(0.12)):
			var point := gate.to_global(Vector3(corner.x, 0.0, corner.y))
			corners.append(Vector3(point.x, 0.0, point.z))
	return corners


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

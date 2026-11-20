extends RefCounted
## Each bound retains its purpose in the original valley.

const GROUND_SIZE := Vector2(380.0, 380.0)
const BLUEPRINT_HALF_EXTENT := 165.0
const WILDLIFE_ROAM_HALF_EXTENT := 165.0
const UNIT_HALF_EXTENT := 172.0
const RADAR_HALF_EXTENT := 180.0

## Valley river: a PlaneMesh of RIVER_WIDTH (local X) by RIVER_LENGTH (local Z), yawed about Y.
const RIVER_CENTER := Vector3(-48.0, 0.0, 0.0)
const RIVER_LENGTH := 340.0
const RIVER_WIDTH := 12.0
const RIVER_ROTATION_Y_DEG := -24.0
const RIVER_FORD_HALF_WIDTH := 9.0
## Ford centres in river-local Z (north, centre, south crossing).
const RIVER_FORD_LOCAL_Z: Array[float] = [-95.0, 0.0, 85.0]

const CAMERA_FAR := 450.0
const CAMERA_RAY_LENGTH := 250.0
const MOUNTAIN_RIM_RADIUS := 178.0
const SCATTER_HALF_EXTENT := 148.0
const REBEL_CAMP_CLAMP := 140.0

const SCAN_RANGE_COMBAT := 24.0
const SCAN_RANGE_CAMP := 35.0
const SCAN_RANGE_GATHER := 70.0


## World-space point on the river axis at river-local z (y = 0).
static func river_point(local_z: float) -> Vector3:
	return RIVER_CENTER + Basis(Vector3.UP, deg_to_rad(RIVER_ROTATION_Y_DEG)) * Vector3(0.0, 0.0, local_z)


static func river_start() -> Vector3:
	return river_point(-RIVER_LENGTH * 0.5)


static func river_end() -> Vector3:
	return river_point(RIVER_LENGTH * 0.5)


## Array of {pos: Vector3, half_width: float}, lying on the river axis.
static func river_crossings() -> Array:
	var out: Array = []
	for z in RIVER_FORD_LOCAL_Z:
		out.append({"pos": river_point(z), "half_width": RIVER_FORD_HALF_WIDTH})
	return out

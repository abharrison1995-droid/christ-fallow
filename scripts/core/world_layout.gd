extends RefCounted
## Campaign geography. A save selects one layout before terrain and entities are restored.

const CLASSIC_ID := "valley_classic_380"
const EXPANDED_ID := "valley_expanded_760"
const DEFAULT_ID := EXPANDED_ID

const SCAN_RANGE_COMBAT := 24.0
const SCAN_RANGE_CAMP := 35.0
const SCAN_RANGE_CHARGE := 65.0
const SCAN_RANGE_GATHER := 70.0
const SCAN_RANGE_BLUEPRINT := 80.0
const SCAN_RANGE_WOUNDED := 85.0
const SCAN_RANGE_RECRUIT := 6.5
const SCAN_RANGE_FIELD_AID := 5.5
const SCAN_RANGE_CONSTRUCTION_ASSIST := 4.6
const SCAN_RANGE_HARVEST := 4.8
const SCAN_RANGE_INSPECT := 1.5
const SCAN_RANGE_INSPECT_ENEMY := 4.2
const SCAN_RANGE_INSPECT_WILDLIFE := 4.2
const SCAN_RANGE_INSPECT_BOSS := 4.8

const CLASSIC_CAMPS := [
	Vector3(0, 0, 52), Vector3(0, 0, -118), Vector3(118, 0, -18), Vector3(-118, 0, -12),
	Vector3(58, 0, 112), Vector3(-125, 0, 115), Vector3(-55, 0, 52),
]
const EXPANDED_CAMPS := [
	Vector3(0, 0, 52), Vector3(64, 0, -172), Vector3(214, 0, 26), Vector3(-238, 0, -58),
	Vector3(16, 0, 248), Vector3(-238, 0, 198), Vector3(-180, 0, 52),
]

var id: String
var ground_size := Vector2(380, 380)
var blueprint_half_extent := 165.0
var wildlife_roam_half_extent := 165.0
var unit_half_extent := 172.0
var radar_half_extent := 180.0
var camera_far := 450.0
var camera_ray_length := 250.0
var mountain_rim_radius := 178.0
var scatter_half_extent := 148.0
var rebel_camp_clamp := 140.0
var settlement_radius := 28.0
var rival_building_spacing := 1.0

# River local X is across the river, local Z follows its axis.
var river_center := Vector3(-48, 0, 0)
var river_length := 340.0
var river_width := 12.0
var river_rotation_y_deg := -24.0
var river_ford_half_width := 9.0
var river_ford_local_z: Array[float] = [-95.0, 0.0, 85.0]
var cave_positions: Array[Vector3] = [Vector3(-125, 0, 115), Vector3(128, 0, 108), Vector3(-82, 0, -122)]


func _init(layout_id: String = CLASSIC_ID) -> void:
	id = layout_id
	if id == EXPANDED_ID:
		ground_size = Vector2(760, 760)
		blueprint_half_extent = 348.0
		wildlife_roam_half_extent = 351.0
		unit_half_extent = 356.0
		radar_half_extent = 374.0
		camera_far = 850.0
		camera_ray_length = 450.0
		mountain_rim_radius = 365.0
		scatter_half_extent = 326.0
		rebel_camp_clamp = 330.0
		settlement_radius = 62.0
		# Leave passable grid cells between the starting fortifications and work sites.
		rival_building_spacing = 1.5
		river_center = Vector3(-105, 0, 0)
		river_length = 724.0
		river_width = 14.0
		river_rotation_y_deg = -8.0
		river_ford_half_width = 13.0
		river_ford_local_z = [-262.0, -142.0, -24.0, 95.0, 225.0]
		cave_positions = [Vector3(-238, 0, 198), Vector3(256, 0, -208), Vector3(-312, 0, -225)]


static func has_layout(layout_id: String) -> bool:
	return layout_id == CLASSIC_ID or layout_id == EXPANDED_ID


func camp_position(faction_id: int) -> Vector3:
	return EXPANDED_CAMPS[faction_id] if id == EXPANDED_ID else CLASSIC_CAMPS[faction_id]


func river_point(local_z: float) -> Vector3:
	return river_center + Basis(Vector3.UP, deg_to_rad(river_rotation_y_deg)) * Vector3(0.0, 0.0, local_z)


func river_start() -> Vector3:
	return river_point(-river_length * 0.5)


func river_end() -> Vector3:
	return river_point(river_length * 0.5)


func river_crossings() -> Array[Dictionary]:
	var crossings: Array[Dictionary] = []
	for z in river_ford_local_z:
		crossings.append({"pos": river_point(z), "half_width": river_ford_half_width})
	return crossings


func wildlife_territories() -> Array:
	if id == EXPANDED_ID:
		return [
			["DEER", Vector3(24, 0, 40), 4], ["DEER", Vector3(-175, 0, -105), 4],
			["BOAR", Vector3(28, 0, 74), 3], ["BOAR", Vector3(-222, 0, 112), 2],
			["SLATEBACK_BOAR", Vector3(-214, 0, 112), 1],
			["WOLF", Vector3(-300, 0, 42), 3], ["WOLF", Vector3(148, 0, -82), 2],
			["REEDJAW", river_point(-205.0) + Vector3(18, 0, 0), 1],
			["SABERTOOTH", Vector3(-178, 0, -258), 2],
			["MAMMOTH", Vector3(60, 0, -70), 1], ["MAMMOTH", Vector3(-287, 0, 116), 1],
			["CAVE_BEAR", Vector3(283, 0, 116), 1],
		]
	return [
		["DEER", Vector3(24, 0, 40), 4], ["DEER", Vector3(-30, 0, 36), 4],
		["BOAR", Vector3(28, 0, 74), 3], ["BOAR", Vector3(-55, 0, 60), 2],
		["SLATEBACK_BOAR", Vector3(-55, 0, 60), 1],
		["WOLF", Vector3(-78, 0, 38), 3], ["WOLF", Vector3(72, 0, -58), 2],
		["REEDJAW", river_point(-120.0) + Vector3(18, 0, 0), 1],
		["SABERTOOTH", Vector3(-55, 0, -68), 2],
		["MAMMOTH", Vector3(0, 0, -45), 1], ["MAMMOTH", Vector3(-84, 0, 68), 1],
		["CAVE_BEAR", Vector3(74, 0, 48), 1],
	]

extends RefCounted
## Shared limits for farm work, livestock, and their save fields.

enum CropStage { EMPTY, GROWING, RIPE }

const WALKABLE_BUILDINGS := ["CROP_FIELD", "ANIMAL_PEN"]
const CROP_GROW_TIME := 48.0
const CROP_TEND_FRACTION := 0.35
const CROP_TEND_BOOST := 7.0
const CROP_WORK_TIMES := [2.0, 1.5, 2.5]
const PEN_CAPACITY := 6
const PEN_INTERVAL := 18.0
const PEN_RADIUS := 4.0
const FEED_COST := 2.0
const BREED_COST := 6.0
const MATURITY_TIME := 45.0
const MOUNT_TRAINING := 2
const TAME_COST := 8.0
const TAME_CHANCES := {"DEER": 0.82, "BOAR": 0.62, "MAMMOTH": 0.40}
const MOUNTS := {
	"MAMMOTH": {"speed_mult": 1.15, "seat": Vector3(0, 2.76, 0.06), "leg_spread": 63.0},
	"BOAR": {"speed_mult": 1.32, "seat": Vector3(0, 1.49, 0.15), "leg_spread": 35.0},
	"DEER": {"speed_mult": 1.58, "seat": Vector3(0, 1.52, 0.12), "leg_spread": 18.0},
}

extends Node

enum Lineage {
	GOLIATH,
	SWIFT_KIN,
	STALKER,
	CRAG_BORN,
	ASH_WALKER,
	FEN_TIDAL,
	CAVEMAN,
}

enum Gender {
	MALE,
	FEMALE,
}

enum Role {
	FORAGER,
	HUNTER,
	LUMBERJACK,
	STONEKNAPPER,
	BUILDER_CRAFTER,
	SHAMAN,
	TRAINEE,
	WARRIOR,
	FARMER,
}

enum WarriorClass {
	SPEARMAN,
	KNIFE_RAIDER,
	ARCHER,
	BRUTE,
	JAVELINEER,
}

enum SquadOrder {
	FOLLOW,
	HOLD,
	CHARGE,
	RETREAT,
	GUARD_BASE,
}

enum SchedulePhase {
	DAY_WORK,
	DUSK_HEARTH,
	NIGHT_SLEEP,
}

enum PatronGod {
	NONE,
	SOL_KAR,
	GAIA_MAR,
	FEN_ROR,
	VALK_TOR,
	KRAG_UL,
}

enum AIPersonality {
	PLAYER,
	WARLORD,
	ZEALOT,
	OPPORTUNIST,
	GUARDIAN,
	FERAL_BANDIT,
}

enum DiplomaticState {
	NEUTRAL,
	ALLIED,
	AT_WAR,
	TRIBUTARY,
}

const FACTION_COLORS := {
	0: Color(0.95, 0.72, 0.20), # Player: Sun Gold
	1: Color(0.80, 0.24, 0.22), # Crag-Goliaths: Crimson
	2: Color(0.92, 0.48, 0.14), # Sun-Stalkers: Ember Orange
	3: Color(0.58, 0.28, 0.78), # Swift-Fang Clan: Dusk Violet
	4: Color(0.24, 0.68, 0.36), # Earth-Root Tribe: Moss Green
	5: Color(0.45, 0.36, 0.30), # Nomadic Cavemen: Feral Brown
	6: Color(0.92, 0.18, 0.36), # The Outcast Rebels: Rebel Crimson
}

const PLAYABLE_LINEAGES := [
	Lineage.GOLIATH,
	Lineage.SWIFT_KIN,
	Lineage.STALKER,
	Lineage.CRAG_BORN,
	Lineage.ASH_WALKER,
	Lineage.FEN_TIDAL,
]

const LINEAGE_DATA := {
	Lineage.GOLIATH: {
		"name": "Tall Folk (Goliath)",
		"short_name": "Goliath",
		"playable": true,
		"description": "Towering, heavy-boned giants. Crushing melee power and resilience, slower stride and slower birthrate.",
		"visual_summary": "Massive barrel chest, wide shoulders, heavy brow, topknot & mammoth-fur mantle.",
		"height_scale": 1.35,
		"width_scale": 1.28,
		"shoulder_scale": 1.24,
		"chest_depth": 1.18,
		"limb_thick": 1.22,
		"head_scale": 0.96,
		"jaw_width": 1.22,
		"brow_depth": 1.20,
		"ear_style": "human",
		"hair_style": "topknot",
		"spine_hunch": 4.0,
		"hp_mult": 1.50,
		"melee_mult": 1.35,
		"ranged_mult": 0.90,
		"speed_mult": 0.82,
		"attack_speed_mult": 0.88,
		"repro_mult": 0.65,
		"gather_mult": 1.10,
		"armor_bonus": 4.0,
		"knockback_resist": 0.60,
		"skin_color": Color(0.76, 0.58, 0.45),
		"hair_color": Color(0.14, 0.10, 0.08),
		"warpaint_color": Color(0.82, 0.24, 0.16),
		"accent_color": Color(0.86, 0.78, 0.64),
	},
	Lineage.SWIFT_KIN: {
		"name": "Small Folk (Swift-Kin)",
		"short_name": "Swift-Kin",
		"playable": true,
		"description": "Nimble, compact tribesfolk who sprint rapidly, strike fast with flint knives, and multiply quickly.",
		"visual_summary": "Compact frame, pointed fox-ears, wild spiky hair, light scout wraps & quick forward stance.",
		"height_scale": 0.76,
		"width_scale": 0.86,
		"shoulder_scale": 0.90,
		"chest_depth": 0.90,
		"limb_thick": 0.86,
		"head_scale": 1.14,
		"jaw_width": 0.86,
		"brow_depth": 0.85,
		"ear_style": "pointed",
		"hair_style": "spiky",
		"spine_hunch": 6.0,
		"hp_mult": 0.75,
		"melee_mult": 0.92,
		"ranged_mult": 1.05,
		"speed_mult": 1.30,
		"attack_speed_mult": 1.25,
		"repro_mult": 1.60,
		"gather_mult": 1.00,
		"armor_bonus": 0.0,
		"knockback_resist": 0.0,
		"skin_color": Color(0.85, 0.69, 0.54),
		"hair_color": Color(0.32, 0.18, 0.10),
		"warpaint_color": Color(0.92, 0.78, 0.30),
		"accent_color": Color(0.68, 0.50, 0.30),
	},
	Lineage.STALKER: {
		"name": "Lean Folk (Stalker)",
		"short_name": "Stalker",
		"playable": true,
		"description": "Tall, sinewy trackers with sharp eyes. Exceptional bow range, speed, and hunting accuracy.",
		"visual_summary": "Elongated limbs, narrow athletic waist, swept ears, hunter crest & cheek warpaint.",
		"height_scale": 1.10,
		"width_scale": 0.84,
		"shoulder_scale": 0.96,
		"chest_depth": 0.88,
		"limb_thick": 0.84,
		"head_scale": 0.98,
		"jaw_width": 0.88,
		"brow_depth": 0.95,
		"ear_style": "swept",
		"hair_style": "crest",
		"spine_hunch": 2.0,
		"hp_mult": 0.92,
		"melee_mult": 0.95,
		"ranged_mult": 1.30,
		"speed_mult": 1.15,
		"attack_speed_mult": 1.10,
		"repro_mult": 1.00,
		"gather_mult": 1.05,
		"armor_bonus": 0.0,
		"knockback_resist": 0.10,
		"skin_color": Color(0.68, 0.50, 0.38),
		"hair_color": Color(0.12, 0.10, 0.10),
		"warpaint_color": Color(0.95, 0.52, 0.18),
		"accent_color": Color(0.55, 0.36, 0.22),
	},
	Lineage.CRAG_BORN: {
		"name": "Hardy Folk (Crag-Born)",
		"short_name": "Crag-Born",
		"playable": true,
		"description": "Broad-shouldered stone-workers with natural toughness, fast gathering/building, and steady endurance.",
		"visual_summary": "Stocky broad shoulders, thick forearms, braided beard/crown & heavy stone-worker hide plates.",
		"height_scale": 1.00,
		"width_scale": 1.20,
		"shoulder_scale": 1.18,
		"chest_depth": 1.14,
		"limb_thick": 1.14,
		"head_scale": 1.04,
		"jaw_width": 1.14,
		"brow_depth": 1.08,
		"ear_style": "human",
		"hair_style": "braided_beard",
		"spine_hunch": 2.0,
		"hp_mult": 1.15,
		"melee_mult": 1.05,
		"ranged_mult": 1.00,
		"speed_mult": 0.96,
		"attack_speed_mult": 1.00,
		"repro_mult": 1.05,
		"gather_mult": 1.25,
		"armor_bonus": 6.0,
		"knockback_resist": 0.30,
		"skin_color": Color(0.78, 0.58, 0.44),
		"hair_color": Color(0.24, 0.15, 0.10),
		"warpaint_color": Color(0.84, 0.78, 0.68),
		"accent_color": Color(0.50, 0.46, 0.40),
	},
	Lineage.ASH_WALKER: {
		"name": "Ash-Born (Ember-Kin)",
		"short_name": "Ash-Born",
		"playable": true,
		"description": "Wiry highland mystics dusted in pale hearth-ash and glowing ember markings. Skilled in both blade and bow.",
		"visual_summary": "Pale ash-grey skin, angular jaw, silver-white locks, glowing ember tattoos & obsidian bead collar.",
		"height_scale": 1.05,
		"width_scale": 0.96,
		"shoulder_scale": 1.02,
		"chest_depth": 0.94,
		"limb_thick": 0.94,
		"head_scale": 1.00,
		"jaw_width": 0.92,
		"brow_depth": 1.05,
		"ear_style": "swept",
		"hair_style": "ash_locks",
		"spine_hunch": 0.0,
		"hp_mult": 1.05,
		"melee_mult": 1.12,
		"ranged_mult": 1.15,
		"speed_mult": 1.05,
		"attack_speed_mult": 1.06,
		"repro_mult": 0.90,
		"gather_mult": 1.15,
		"armor_bonus": 2.0,
		"knockback_resist": 0.15,
		"skin_color": Color(0.58, 0.54, 0.56),
		"hair_color": Color(0.82, 0.80, 0.78),
		"warpaint_color": Color(1.0, 0.44, 0.12),
		"accent_color": Color(0.20, 0.16, 0.24),
	},
	Lineage.FEN_TIDAL: {
		"name": "Fen-Tidal (Mire-Folk)",
		"short_name": "Fen-Tidal",
		"playable": true,
		"description": "Sleek river-valley reed-stalkers with finned crests, agile strikes, and bountiful foraging.",
		"visual_summary": "Moss-teal skin, finned ear-frills, kelp dorsal crest, golden eyes & reed/shell necklets.",
		"height_scale": 0.96,
		"width_scale": 0.94,
		"shoulder_scale": 0.98,
		"chest_depth": 0.96,
		"limb_thick": 0.94,
		"head_scale": 1.02,
		"jaw_width": 0.96,
		"brow_depth": 0.92,
		"ear_style": "finned",
		"hair_style": "fin_crest",
		"spine_hunch": 5.0,
		"hp_mult": 0.95,
		"melee_mult": 1.02,
		"ranged_mult": 1.08,
		"speed_mult": 1.14,
		"attack_speed_mult": 1.12,
		"repro_mult": 1.20,
		"gather_mult": 1.18,
		"armor_bonus": 1.0,
		"knockback_resist": 0.10,
		"skin_color": Color(0.46, 0.62, 0.54),
		"hair_color": Color(0.14, 0.28, 0.20),
		"warpaint_color": Color(0.42, 0.90, 0.78),
		"accent_color": Color(0.76, 0.72, 0.52),
	},
	Lineage.CAVEMAN: {
		"name": "Feral Caveman (Cave-Kin)",
		"short_name": "Cave-Kin",
		"playable": false,
		"description": "Un-enlightened bone-cave marauders with hunched frames, heavy brows, and wild shaggy pelts.",
		"visual_summary": "Hunched primal spine, protruding jaw & tusks, wild matted mane, shaggy shoulder pelt & bone trophies.",
		"height_scale": 1.06,
		"width_scale": 1.24,
		"shoulder_scale": 1.22,
		"chest_depth": 1.20,
		"limb_thick": 1.20,
		"head_scale": 1.08,
		"jaw_width": 1.26,
		"brow_depth": 1.32,
		"ear_style": "human",
		"hair_style": "wild_mane",
		"spine_hunch": 16.0,
		"hp_mult": 1.18,
		"melee_mult": 1.18,
		"ranged_mult": 0.70,
		"speed_mult": 0.95,
		"attack_speed_mult": 0.96,
		"repro_mult": 0.80,
		"gather_mult": 0.85,
		"armor_bonus": 4.0,
		"knockback_resist": 0.40,
		"skin_color": Color(0.54, 0.41, 0.33),
		"hair_color": Color(0.20, 0.14, 0.10),
		"warpaint_color": Color(0.65, 0.14, 0.10),
		"accent_color": Color(0.40, 0.28, 0.18),
	},
}

const ROLE_NAMES := {
	Role.FORAGER: "Forager",
	Role.HUNTER: "Hunter",
	Role.LUMBERJACK: "Woodcutter",
	Role.STONEKNAPPER: "Stoneknapper",
	Role.BUILDER_CRAFTER: "Builder/Crafter",
	Role.SHAMAN: "Shaman",
	Role.TRAINEE: "Barracks Trainee",
	Role.WARRIOR: "Warrior",
	Role.FARMER: "Farmer",
}

const WARRIOR_CLASS_NAMES := {
	WarriorClass.SPEARMAN: "Spearman",
	WarriorClass.KNIFE_RAIDER: "Knife-Raider",
	WarriorClass.ARCHER: "Archer",
	WarriorClass.BRUTE: "Club Brute",
	WarriorClass.JAVELINEER: "Javelineer",
}

const FLINTMASK_SCOUT := "FLINTMASK_SCOUT"
const FLINTMASK_STATS := {"hp": 100.0, "speed": 7.4, "damage": 13.0, "cooldown": 0.85, "reach": 1.9, "armor": 4.0}

const CLASS_DEFINITIONS := {
	"LEADER": {
		"name": "Tribal Warchief",
		"category": "Leader",
		"weapon": "GREAT_SPEAR",
		"offhand": "BUCKLER_SHIELD",
		"headgear": "LEADER_CROWN",
		"back_gear": "JAVELIN_BUNDLE",
		"has_cape": true,
		"attack_anim": "LEADER_CLEAVE",
		"secondary_anim": "JAVELIN_THROW",
		"idle_stance": "COMMAND",
		"summary": "Horned sun-crown, split war-cape, chieftain great-spear, javelin pack & heavy bone pauldrons.",
	},
	"SPEARMAN": {
		"name": "Spearman",
		"category": "Warrior",
		"weapon": "SPEAR",
		"offhand": "BUCKLER_SHIELD",
		"headgear": "BONE_CREST",
		"back_gear": "NONE",
		"has_cape": false,
		"attack_anim": "SPEAR_THRUST",
		"idle_stance": "SHIELD_GUARD",
		"summary": "Long war spear with feather tassel, round hide buckler shield, banded kilt & bone brow crest.",
	},
	"KNIFE_RAIDER": {
		"name": "Knife-Raider",
		"category": "Warrior",
		"weapon": "KNIFE",
		"offhand": "OFFHAND_DIRK",
		"headgear": "PELT_COWL",
		"back_gear": "DUAL_SHEATH",
		"has_cape": false,
		"attack_anim": "DUAL_SLASH",
		"idle_stance": "CROUCH_DUAL",
		"summary": "Dual curved flint/obsidian daggers, wolf-pelt neck cowl, warpaint straps & crouched flanker stance.",
	},
	"ARCHER": {
		"name": "Archer",
		"category": "Warrior",
		"weapon": "ARROW_HAND",
		"offhand": "BOW",
		"headgear": "FEATHER_HOOD",
		"back_gear": "ARROW_QUIVER",
		"has_cape": false,
		"attack_anim": "BOW_SHOT",
		"idle_stance": "BOW_READY",
		"summary": "Curved recurve bow in left hand, drawn arrow, feathered back quiver & scout headband.",
	},
	"BRUTE": {
		"name": "Club Brute",
		"category": "Warrior",
		"weapon": "WAR_CLUB",
		"offhand": "NONE",
		"headgear": "SKULL_CAP",
		"back_gear": "TROPHY_RACK",
		"has_cape": false,
		"attack_anim": "HEAVY_SMASH",
		"idle_stance": "HEAVY_STANCE",
		"summary": "Massive stone-studded jawbone war-maul, beast-skull pauldron, heavy fur harness & bone helm.",
	},
	"JAVELINEER": {
		"name": "Javelineer",
		"category": "Warrior",
		"weapon": "JAVELIN",
		"offhand": "TARGET_SHIELD",
		"headgear": "PLUME_BAND",
		"back_gear": "JAVELIN_BUNDLE",
		"has_cape": false,
		"attack_anim": "JAVELIN_THROW",
		"idle_stance": "SKIRMISHER",
		"summary": "Barbed throwing javelin, 3-javelin back bundle, light hide target shield & plumed runner band.",
	},
	"SHAMAN": {
		"name": "Shaman",
		"category": "Specialist",
		"weapon": "SHAMAN_STAFF",
		"offhand": "FETISH_CHARM",
		"headgear": "SKULL_ANTLER_MASK",
		"back_gear": "TOTEM_POUCH",
		"has_cape": true,
		"attack_anim": "SHAMAN_CAST",
		"work_anim": "WORK_PRAY",
		"idle_stance": "MYSTIC",
		"summary": "Horned stag-skull mask, glowing spirit-totem staff, feathered shawl & medicine fetishes.",
	},
	"HUNTER": {
		"name": "Hunter",
		"category": "Specialist",
		"weapon": "ARROW_HAND",
		"offhand": "SHORT_BOW",
		"headgear": "PELT_HOOD",
		"back_gear": "ARROW_QUIVER",
		"has_cape": true,
		"attack_anim": "BOW_SHOT",
		"work_anim": "BOW_SHOT",
		"idle_stance": "BOW_READY",
		"summary": "Pelt tracker hood & capelet, short hunting bow, fur quiver & bone trophy necklace.",
	},
	"FORAGER": {
		"name": "Forager",
		"category": "Civilian",
		"weapon": "SICKLE_TOOL",
		"offhand": "HERB_BUNDLE",
		"headgear": "LEAF_BAND",
		"back_gear": "FORAGER_BASKET",
		"has_cape": false,
		"attack_anim": "TOOL_SWING",
		"work_anim": "WORK_FORAGE",
		"idle_stance": "RELAXED",
		"summary": "Woven reed back-basket filled with berries, flint sickle, leafy browband & herb apron.",
	},
	"LUMBERJACK": {
		"name": "Woodcutter",
		"category": "Civilian",
		"weapon": "FELLING_AXE",
		"offhand": "NONE",
		"headgear": "WORK_BAND",
		"back_gear": "TIMBER_PACK",
		"has_cape": false,
		"attack_anim": "HEAVY_SMASH",
		"work_anim": "WORK_CHOP",
		"idle_stance": "RELAXED",
		"summary": "Heavy hafted stone felling axe, timber-rope back harness, leather apron & knotted headband.",
	},
	"STONEKNAPPER": {
		"name": "Stoneknapper",
		"category": "Civilian",
		"weapon": "MINING_PICK",
		"offhand": "NONE",
		"headgear": "MINER_WRAP",
		"back_gear": "ORE_SATCHEL",
		"has_cape": false,
		"attack_anim": "TOOL_SWING",
		"work_anim": "WORK_MINE",
		"idle_stance": "RELAXED",
		"summary": "Twin-pointed stone pick-maul, heavy flint satchel, protective brow-wrap & leather shoulder guard.",
	},
	"BUILDER_CRAFTER": {
		"name": "Builder / Crafter",
		"category": "Civilian",
		"weapon": "BUILD_MALLET",
		"offhand": "FLINT_ADZE",
		"headgear": "CRAFT_VISOR",
		"back_gear": "BUILDER_PACK",
		"has_cape": false,
		"attack_anim": "TOOL_SWING",
		"work_anim": "WORK_BUILD",
		"idle_stance": "RELAXED",
		"summary": "Stone builder mallet & flint adze, rolled hide/stake pack, craftsman apron & wrist guards.",
	},
	"TRAINEE": {
		"name": "Barracks Trainee",
		"category": "Specialist",
		"weapon": "SPARRING_SPEAR",
		"offhand": "TARGET_SHIELD",
		"headgear": "TRAINING_BAND",
		"back_gear": "NONE",
		"has_cape": false,
		"attack_anim": "SPEAR_THRUST",
		"work_anim": "WORK_SPAR",
		"idle_stance": "SHIELD_GUARD",
		"summary": "Blunted wooden sparring spear, light hide training shield, padded chest-wrap & tied headband.",
	},
	"CAVEMAN": {
		"name": "Feral Caveman",
		"category": "Feral",
		"weapon": "BONE_CLUB",
		"offhand": "NONE",
		"headgear": "NONE",
		"back_gear": "FUR_PELT",
		"has_cape": false,
		"attack_anim": "HEAVY_SMASH",
		"idle_stance": "HEAVY_STANCE",
		"summary": "Gnarled mammoth-bone club, shaggy shoulder fur pelt, tusk belt & hunched primal silhouette.",
	},
	"FLINTMASK_SCOUT": {
		"name": "Flintmask Scout",
		"category": "Feral",
		"weapon": "BONE_CLUB",
		"offhand": "NONE",
		"headgear": "NONE",
		"back_gear": "FUR_PELT",
		"has_cape": false,
		"attack_anim": "HEAVY_SMASH",
		"idle_stance": "HEAVY_STANCE",
		"summary": "A light cave scout with a carved flint mask and hooked club.",
	},
}

const SQUAD_ORDER_NAMES := {
	SquadOrder.FOLLOW: "Follow Me",
	SquadOrder.HOLD: "Hold Position",
	SquadOrder.CHARGE: "Charge!",
	SquadOrder.RETREAT: "Retreat to Camp",
	SquadOrder.GUARD_BASE: "Guard Base",
}

const GOD_DATA := {
	PatronGod.NONE: {
		"name": "Unawakened Spirit",
		"title": "No Patron Deity",
		"buff_summary": "Build a Sacred Totem or open Religion [R] to choose a Patron God.",
		"blessing_name": "Leader's Rally",
		"blessing_desc": "Inspires nearby allies with +20% speed and heals 15 HP.",
		"color": Color(0.8, 0.8, 0.8),
	},
	PatronGod.SOL_KAR: {
		"name": "Sol-Kar",
		"title": "Sun & Hearth God",
		"buff_summary": "+20% daytime combat damage; +50% faster campfire healing.",
		"blessing_name": "Solar Radiance",
		"blessing_desc": "Scorches nearby enemies for 35 fire damage and heals allies within 10m.",
		"color": Color(1.0, 0.68, 0.18),
	},
	PatronGod.GAIA_MAR: {
		"name": "Gaia-Mar",
		"title": "Earth & Fallow Mother",
		"buff_summary": "+35% reproduction rate; +25% foraging & berry yields.",
		"blessing_name": "Fallow Renewal",
		"blessing_desc": "Restores 45 HP to all nearby tribesfolk and grants +15 Food.",
		"color": Color(0.35, 0.85, 0.42),
	},
	PatronGod.FEN_ROR: {
		"name": "Fen-Ror",
		"title": "Beast & Hunt Spirit",
		"buff_summary": "+20% move speed & hunting yields; +20% knife & bow crit chance.",
		"blessing_name": "Pack Frenzy",
		"blessing_desc": "Grants nearby warriors +40% attack & move speed for 10s.",
		"color": Color(0.85, 0.30, 0.25),
	},
	PatronGod.VALK_TOR: {
		"name": "Valk-Tor",
		"title": "Storm & Sky God",
		"buff_summary": "+25% spear damage & knockback; warcry strikes foes with lightning.",
		"blessing_name": "Sky-Bolt Strike",
		"blessing_desc": "Calls storm lightning hitting up to 5 enemies around you for 42 damage.",
		"color": Color(0.45, 0.78, 1.0),
	},
	PatronGod.KRAG_UL: {
		"name": "Krag-Ul",
		"title": "Ancestor & Stone Spirit",
		"buff_summary": "+25% building HP; +20% natural armor & stone/flint gathering.",
		"blessing_name": "Stone Bulwark",
		"blessing_desc": "Hardens skin of nearby allies (+18 armor & stun immunity for 10s).",
		"color": Color(0.70, 0.65, 0.58),
	},
}

const TENET_DATA := {
	"PEACEFUL_OFFERING": {
		"name": "Peaceful Offering",
		"opposing": "BLOOD_SACRIFICE",
		"desc": "+15 Diplomatic opinion with neighbors; Shamans generate +30% more Faith.",
	},
	"BLOOD_SACRIFICE": {
		"name": "Blood Sacrifice",
		"opposing": "PEACEFUL_OFFERING",
		"desc": "Slaying enemies or megafauna grants +8 Faith and restores +10 HP.",
	},
	"KINSHIP": {
		"name": "Kinship of Tribes",
		"opposing": "SACRED_CONQUEST",
		"desc": "Assimilated colonists & enlightened cavemen join with +25% bonus stats.",
	},
	"SACRED_CONQUEST": {
		"name": "Sacred Conquest",
		"opposing": "KINSHIP",
		"desc": "+18% attack damage against rival tribesmen and fortifications.",
	},
	"ANCESTRAL_STONE": {
		"name": "Ancestral Stone",
		"opposing": "WILD_HARMONY",
		"desc": "-20% building stone/wood cost; Watchtowers deal +25% damage.",
	},
	"WILD_HARMONY": {
		"name": "Wild Harmony",
		"opposing": "ANCESTRAL_STONE",
		"desc": "+25% Hunter & Forager yield; wildlife less likely to ambush workers.",
	},
}

const TECH_TIER_NAMES := {
	1: "Tier I: Crude Wood & River Stone",
	2: "Tier II: Knapped Flint & Cured Hide",
	3: "Tier III: Obsidian Edge & Carved Bone",
}

const TIER_UPGRADE_COSTS := {
	2: {"wood": 35, "stone": 30, "flint": 25, "hide": 15},
	3: {"wood": 50, "stone": 45, "flint": 40, "hide": 30, "bone": 25},
}

const CRAFT_RECIPES := {
	"spears": {
		"name": "Stone Spear",
		"costs": {"wood": 4, "flint": 2},
		"craft_time": 4.0,
	},
	"knives": {
		"name": "Flint Knife / Dirk",
		"costs": {"wood": 2, "flint": 3},
		"craft_time": 3.0,
	},
	"bows": {
		"name": "Hunting Bow",
		"costs": {"wood": 5, "hide": 2, "flint": 1},
		"craft_time": 4.5,
	},
	"clubs": {
		"name": "Bone War-Club",
		"costs": {"wood": 4, "stone": 3, "bone": 2},
		"craft_time": 4.2,
	},
	"javelins": {
		"name": "Barbed Javelins",
		"costs": {"wood": 4, "flint": 3},
		"craft_time": 3.8,
	},
	"armor": {
		"name": "Hide & Bone Armor",
		"costs": {"hide": 4, "bone": 2},
		"craft_time": 5.0,
	},
}

const BUILDINGS := {
	"CAMPFIRE": {
		"name": "Tribal Campfire",
		"desc": "Heart of your colony. Required to found your tribe, heals nearby units at dusk, and serves as drop-off.",
		"costs": {"wood": 8, "stone": 6},
		"build_time": 3.0,
		"max_hp": 500.0,
		"housing": 2,
		"radius": 2.0,
	},
	"SLEEPING_HUT": {
		"name": "Sleeping Hut",
		"desc": "Houses 4 colonists. Paired men and women reproduce here at night when food is plentiful.",
		"costs": {"wood": 14, "hide": 4},
		"build_time": 7.0,
		"max_hp": 240.0,
		"housing": 4,
		"radius": 2.4,
	},
	"FORAGER_LODGE": {
		"name": "Forager & Hunter Lodge",
		"desc": "Increases local Food, Hide, and Bone gathering yields by +25%.",
		"costs": {"wood": 16, "stone": 6},
		"build_time": 8.0,
		"max_hp": 260.0,
		"housing": 0,
		"radius": 2.4,
	},
	"CRAFTING_PIT": {
		"name": "Flint-Knapping & Crafting Pit",
		"desc": "Required to craft Spears, Flint Knives, Bows, and Hide/Bone Armor and upgrade Stone Age Gear Tiers.",
		"costs": {"wood": 12, "stone": 14, "flint": 4},
		"build_time": 9.0,
		"max_hp": 300.0,
		"housing": 0,
		"radius": 2.3,
	},
	"WEAPON_RACK": {
		"name": "Weapon & Armor Rack",
		"desc": "Warriors visit here to automatically equip the best crafted gear for their class.",
		"costs": {"wood": 10, "stone": 4},
		"build_time": 5.0,
		"max_hp": 220.0,
		"housing": 0,
		"radius": 1.6,
	},
	"SACRED_TOTEM": {
		"name": "Sacred Totem",
		"desc": "Unlocks Patron God & Tenets, lets Shamans generate Faith, and enlightens captured Cavemen.",
		"costs": {"wood": 15, "stone": 12, "bone": 4},
		"build_time": 10.0,
		"max_hp": 420.0,
		"housing": 0,
		"radius": 1.8,
	},
	"STORAGE_PIT": {
		"name": "Storage Mound",
		"desc": "Extra drop-off depot that speeds up gathering runs across larger villages.",
		"costs": {"wood": 12, "stone": 10},
		"build_time": 6.0,
		"max_hp": 320.0,
		"housing": 0,
		"radius": 2.0,
		"collider_size": Vector3(3.10, 2.47, 1.83),
	},
	"CROP_FIELD": {
		"name": "Crop Field",
		"desc": "Farmers sow, tend, and harvest grain. Harvests are carried to the nearest food drop-off.",
		"costs": {"wood": 10, "stone": 4},
		"build_time": 6.5,
		"max_hp": 180.0,
		"housing": 0,
		"radius": 2.6,
	},
	"ANIMAL_PEN": {
		"name": "Animal Pen",
		"desc": "Houses tamed deer and boars. Fed adults can breed, and fed boars train as mounts.",
		"costs": {"wood": 20, "stone": 6},
		"build_time": 8.0,
		"max_hp": 260.0,
		"housing": 0,
		"radius": 3.2,
	},
	"PALISADE_WALL": {
		"name": "Log Palisade",
		"desc": "Sturdy sharpened-log fortification that blocks and slows hostile raiders.",
		"costs": {"wood": 10, "stone": 4},
		"build_time": 4.5,
		"max_hp": 450.0,
		"housing": 0,
		"radius": 2.2,
		"collider_size": Vector3(3.2, 2.2, 0.5),
	},
	"STANDING_STONE_GATE": {
		"name": "Standing-Stone Gate",
		"desc": "Two standing stones define a walkable opening in your defences.",
		"costs": {"stone": 18, "wood": 4},
		"build_time": 11.0,
		"max_hp": 430.0,
		"housing": 0,
		"radius": 2.1,
	},
	"WATCHTOWER": {
		"name": "Lookout Watchtower",
		"desc": "Elevated wooden tower that automatically fires Stone Age arrows at nearby enemies.",
		"costs": {"wood": 20, "stone": 10, "flint": 6},
		"build_time": 11.0,
		"max_hp": 380.0,
		"housing": 0,
		"radius": 2.0,
		"collider_size": Vector3(2.65, 3.02, 2.28),
	},
	"BARRACKS": {
		"name": "Tribal Barracks",
		"desc": "Training grounds where Trainees and idle Guards practice Close-Quarters & Ranged skills (up to Rank V).",
		"costs": {"wood": 18, "stone": 12, "hide": 4},
		"build_time": 9.0,
		"max_hp": 340.0,
		"housing": 0,
		"radius": 2.5,
	},
	"SHAMAN_SHACK": {
		"name": "Shaman's Healing Shack",
		"desc": "Sacred medicine hut where wounded rebels are healed and restored to loyalty before they defect.",
		"costs": {"wood": 14, "stone": 8, "hide": 6},
		"build_time": 8.0,
		"max_hp": 280.0,
		"housing": 0,
		"radius": 2.2,
	},
}

const WILDLIFE_DATA := {
	"DEER": {
		"name": "Stag / Deer",
		"hp": 55.0,
		"speed": 7.5,
		"damage": 4.0,
		"aggro": false,
		"flee": true,
		"is_boss": false,
		"yield": {"food": 18, "hide": 6, "bone": 4},
	},
	"BOAR": {
		"name": "Tusked Boar",
		"hp": 85.0,
		"speed": 6.2,
		"damage": 11.0,
		"aggro": false,
		"flee": false,
		"is_boss": false,
		"yield": {"food": 24, "hide": 8, "bone": 6},
	},
	"SLATEBACK_BOAR": {
		"name": "Slateback Boar",
		"hp": 130.0,
		"speed": 5.8,
		"damage": 16.0,
		"armor": 8.0,
		"attack_cooldown": 1.6,
		"capsule_height": 1.65,
		"aggro": false,
		"flee": false,
		"is_boss": false,
		"yield": {"food": 28, "hide": 10, "bone": 8},
	},
	"REEDJAW": {
		"name": "Reedjaw",
		"hp": 135.0,
		"speed": 6.6,
		"damage": 18.0,
		"attack_cooldown": 1.45,
		"attack_windup": 0.16,
		"attack_reach": 2.15,
		"capsule_radius": 0.46,
		"capsule_height": 0.94,
		"projectile_hit_height": 0.52,
		"projectile_hit_radius": 0.86,
		"aggro": true,
		"flee": false,
		"is_boss": false,
		"yield": {"food": 18, "hide": 14, "bone": 10},
	},
	"WOLF": {
		"name": "Dire Wolf",
		"hp": 95.0,
		"speed": 7.4,
		"damage": 14.0,
		"aggro": true,
		"flee": false,
		"is_boss": false,
		"yield": {"food": 12, "hide": 10, "bone": 8},
	},
	"SABERTOOTH": {
		"name": "Sabertooth Tiger",
		"hp": 160.0,
		"speed": 8.0,
		"damage": 22.0,
		"aggro": true,
		"flee": false,
		"is_boss": false,
		"yield": {"food": 22, "hide": 16, "bone": 14},
	},
	"MAMMOTH": {
		"name": "Woolly Mammoth",
		"hp": 520.0,
		"speed": 4.4,
		"damage": 34.0,
		"aggro": false,
		"flee": false,
		"is_boss": true,
		"yield": {"food": 90, "hide": 30, "bone": 32},
	},
	"CAVE_BEAR": {
		"name": "Giant Cave Bear",
		"hp": 410.0,
		"speed": 5.2,
		"damage": 29.0,
		"aggro": true,
		"flee": false,
		"is_boss": true,
		"yield": {"food": 65, "hide": 26, "bone": 24},
	},
}

const RIVAL_PRESETS := {
	1: {
		"name": "Crag-Goliaths",
		"leader_name": "Brog the Mountain",
		"personality": AIPersonality.WARLORD,
		"personality_name": "Warlord",
		"personality_desc": "Aggressive conqueror who marches heavy Goliath spear walls against weak neighbors.",
		"lineage": Lineage.GOLIATH,
		"specialty": WarriorClass.SPEARMAN,
		"god": PatronGod.KRAG_UL,
		"tenets": ["SACRED_CONQUEST", "ANCESTRAL_STONE"],
	},
	2: {
		"name": "Sun-Stalkers",
		"leader_name": "Syra Dawn-Eye",
		"personality": AIPersonality.ZEALOT,
		"personality_name": "Zealot",
		"personality_desc": "Devout archers who cherish tribes of matching faith and launch crusades against heretics.",
		"lineage": Lineage.STALKER,
		"specialty": WarriorClass.ARCHER,
		"god": PatronGod.SOL_KAR,
		"tenets": ["SACRED_CONQUEST", "PEACEFUL_OFFERING"],
	},
	3: {
		"name": "Swift-Fang Clan",
		"leader_name": "Skrit Quick-Blade",
		"personality": AIPersonality.OPPORTUNIST,
		"personality_name": "Opportunist",
		"personality_desc": "Fast-breeding raiders who ambush unguarded bases when your army leaves home.",
		"lineage": Lineage.SWIFT_KIN,
		"specialty": WarriorClass.KNIFE_RAIDER,
		"god": PatronGod.FEN_ROR,
		"tenets": ["BLOOD_SACRIFICE", "WILD_HARMONY"],
	},
	4: {
		"name": "Earth-Root Tribe",
		"leader_name": "Thoran Stone-Hand",
		"personality": AIPersonality.GUARDIAN,
		"personality_name": "Guardian",
		"personality_desc": "Fortified builders who favor peaceful alliances and defend their fertile basin fiercely.",
		"lineage": Lineage.CRAG_BORN,
		"specialty": WarriorClass.SPEARMAN,
		"god": PatronGod.GAIA_MAR,
		"tenets": ["PEACEFUL_OFFERING", "KINSHIP"],
	},
	5: {
		"name": "Nomadic Cavemen",
		"leader_name": "Feral Pack",
		"personality": AIPersonality.FERAL_BANDIT,
		"personality_name": "Feral Raiders",
		"personality_desc": "Un-enlightened cave marauders who raid settlements at will. Capture and enlighten them!",
		"lineage": Lineage.CAVEMAN,
		"specialty": WarriorClass.BRUTE,
		"god": PatronGod.NONE,
		"tenets": [],
	},
	6: {
		"name": "The Outcast Rebels",
		"leader_name": "Rebel Outcast",
		"personality": AIPersonality.WARLORD,
		"personality_name": "Rebel Defector",
		"personality_desc": "Former members of your tribe who revolted and formed a rival warband targeting your colony.",
		"lineage": Lineage.CRAG_BORN,
		"specialty": WarriorClass.SPEARMAN,
		"god": PatronGod.FEN_ROR,
		"tenets": ["BLOOD_SACRIFICE", "SACRED_CONQUEST"],
	},
}

const LEADER_IDENTITIES := {
	0: ["◆", "Chieftain"],
	1: ["▲", "Mountain Warlord"],
	2: ["☀", "Dawn Seer"],
	3: ["✦", "Fang Chief"],
	4: ["⬟", "Earth Warden"],
	6: ["◇", "Outcast Chief"],
}

const FIRST_NAMES_MALE := [
	"Abel", "Kael", "Toren", "Milo", "Jorah", "Bram", "Oren", "Dagan",
	"Soren", "Ronan", "Caleb", "Garr", "Varn", "Lukas", "Halen", "Tarn",
]

const FIRST_NAMES_FEMALE := [
	"Mara", "Lyra", "Sela", "Nora", "Talia", "Bryn", "Kira", "Elowen",
	"Veya", "Rhea", "Yara", "Hana", "Orla", "Mina", "Sora", "Daria",
]

const CAVEMAN_NAMES := [
	"Grug", "Ugg", "Bork", "Krag", "Zug", "Thok", "Morg", "Ruk",
]


static func resolve_class_key(role_id: int, w_class: int, is_leader_flag: bool, is_caveman_flag: bool, militia_active: bool = false) -> String:
	if is_leader_flag:
		return "LEADER"
	if is_caveman_flag:
		return "CAVEMAN"
	if role_id == Role.WARRIOR or militia_active:
		match w_class:
			WarriorClass.KNIFE_RAIDER:
				return "KNIFE_RAIDER"
			WarriorClass.ARCHER:
				return "ARCHER"
			WarriorClass.BRUTE:
				return "BRUTE"
			WarriorClass.JAVELINEER:
				return "JAVELINEER"
			_:
				return "SPEARMAN"
	match role_id:
		Role.HUNTER:
			return "HUNTER"
		Role.LUMBERJACK:
			return "LUMBERJACK"
		Role.STONEKNAPPER:
			return "STONEKNAPPER"
		Role.BUILDER_CRAFTER:
			return "BUILDER_CRAFTER"
		Role.SHAMAN:
			return "SHAMAN"
		Role.TRAINEE:
			return "TRAINEE"
		_:
			return "FORAGER"


static func resolve_effective_lineage(lineage_id: int, is_caveman_flag: bool) -> int:
	if is_caveman_flag:
		return Lineage.CAVEMAN
	if LINEAGE_DATA.has(lineage_id):
		return lineage_id
	return Lineage.CRAG_BORN

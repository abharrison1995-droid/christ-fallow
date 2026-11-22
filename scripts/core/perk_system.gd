extends RefCounted
## Tribal level progression, skill points, perks, building unlocks, and stat multipliers.

const MAX_LEVEL := 12

const BRANCH_ORDER := ["MASONRY", "MIGHT", "KINSHIP"]

const BRANCH_TITLES := {
	"MASONRY": "Masonry & Settlement",
	"MIGHT": "Chieftain & Lineage Might",
	"KINSHIP": "Kinship & Warband Mastery",
}

const PERK_ORDER := [
	"MASTER_BUILDERS",
	"STONE_FOUNDATIONS",
	"GREAT_LODGES",
	"MASTERWORK_DEFENCES",
	"PRIMAL_VIGOR",
	"WARLORDS_EDGE",
	"SWIFT_STRIDE",
	"DIVINE_CONDUIT",
	"CALL_OF_THE_HEARTH",
	"SEASONED_BLOODLINES",
	"BARRACKS_DRILLMASTERS",
	"BATTLE_VETERANS",
]

const PERK_DEFINITIONS := {
	"MASTER_BUILDERS": {
		"branch": "MASONRY",
		"name": "Master Builders",
		"max_rank": 3,
		"min_level": 1,
		"requires": "",
		"desc": "+25%/+50%/+75% build speed; -10%/-18%/-25% building Wood & Stone cost. Unlocks Crop Field & Storage Mound.",
	},
	"STONE_FOUNDATIONS": {
		"branch": "MASONRY",
		"name": "Stone-Bound Foundations",
		"max_rank": 3,
		"min_level": 2,
		"requires": "MASTER_BUILDERS",
		"desc": "+20%/+40%/+60% building Max HP; passive out-of-combat repair (1.5/3.0/4.5 HP/s). Unlocks Standing-Stone Gate & Healing Shack.",
	},
	"GREAT_LODGES": {
		"branch": "MASONRY",
		"name": "Great Lodges & Hearthcraft",
		"max_rank": 2,
		"min_level": 3,
		"requires": "MASTER_BUILDERS",
		"desc": "Sleeping Huts house +1/+2 colonists; Campfires house +1/+2 & heal +50%/+100% at Dusk; Lodge & Crop yields +20%/+40%. Unlocks Animal Pen.",
	},
	"MASTERWORK_DEFENCES": {
		"branch": "MASONRY",
		"name": "Masterwork Defences",
		"max_rank": 2,
		"min_level": 4,
		"requires": "STONE_FOUNDATIONS",
		"desc": "Watchtowers fire +25%/+50% faster with +25%/+50% arrow damage & +3/+6 m range; Animal Pens hold +2/+4 animals. Unlocks Lookout Watchtower.",
	},
	"PRIMAL_VIGOR": {
		"branch": "MIGHT",
		"name": "Primal Vigor",
		"max_rank": 3,
		"min_level": 1,
		"requires": "",
		"desc": "Leader gains +20%/+40%/+60% Max HP & +3/+6/+9 Armor; all tribesfolk gain +10%/+20%/+30% Max HP.",
	},
	"WARLORDS_EDGE": {
		"branch": "MIGHT",
		"name": "Warlord's Edge",
		"max_rank": 3,
		"min_level": 2,
		"requires": "PRIMAL_VIGOR",
		"desc": "Leader Cleave & Javelin deal +20%/+40%/+60% damage with -15%/-25%/-35% cooldown; warriors gain +10%/+20%/+30% damage & +2/+4/+6 Armor.",
	},
	"SWIFT_STRIDE": {
		"branch": "MIGHT",
		"name": "Swift Stride & Harvest Hands",
		"max_rank": 2,
		"min_level": 3,
		"requires": "PRIMAL_VIGOR",
		"desc": "Tribe-wide +10%/+20% Move Speed and +20%/+40% Gather & Craft speed; Leader Dash cooldown -30%/-50%.",
	},
	"DIVINE_CONDUIT": {
		"branch": "MIGHT",
		"name": "Divine Conduit",
		"max_rank": 1,
		"min_level": 5,
		"requires": "WARLORDS_EDGE",
		"desc": "Patron Blessing [Q] cooldown reduced by 35% and Blessing damage & healing increased by +35%.",
	},
	"CALL_OF_THE_HEARTH": {
		"branch": "KINSHIP",
		"name": "Call of the Hearth",
		"max_rank": 3,
		"min_level": 1,
		"requires": "",
		"desc": "Unlocks 'Hire Nomad Villager' in Colony [C] (12/10/8 Food); raises max population cap to 40/48/56 and boosts night birth chance by +25%/+50%/+75%.",
	},
	"SEASONED_BLOODLINES": {
		"branch": "KINSHIP",
		"name": "Seasoned Bloodlines",
		"max_rank": 3,
		"min_level": 2,
		"requires": "CALL_OF_THE_HEARTH",
		"desc": "New recruits, hired nomads, enlightened captives, and grown children gain +15%/+30%/+45% base stats, +10 Morale, and start at Rank I (R2) or Rank II (R3).",
	},
	"BARRACKS_DRILLMASTERS": {
		"branch": "KINSHIP",
		"name": "Barracks Drillmasters",
		"max_rank": 3,
		"min_level": 2,
		"requires": "CALL_OF_THE_HEARTH",
		"desc": "Unlocks Tribal Barracks. Barracks training XP +50%/+100%/+150% faster; raises max training rank from V to VI/VII/VIII; idle Warriors spar at Barracks.",
	},
	"BATTLE_VETERANS": {
		"branch": "KINSHIP",
		"name": "Battle-Hardened Veterans",
		"max_rank": 1,
		"min_level": 4,
		"requires": "BARRACKS_DRILLMASTERS",
		"desc": "Warriors earn Training XP directly from live combat strikes and auto-equip stockpile weapons & armor on assignment.",
	},
}

const BUILDING_UNLOCK_RULES := {
	"STORAGE_PIT": {"min_level": 2, "perk": "MASTER_BUILDERS", "rank": 1},
	"CROP_FIELD": {"min_level": 2, "perk": "MASTER_BUILDERS", "rank": 1},
	"BARRACKS": {"min_level": 2, "perk": "BARRACKS_DRILLMASTERS", "rank": 1},
	"SHAMAN_SHACK": {"min_level": 2, "perk": "STONE_FOUNDATIONS", "rank": 1},
	"STANDING_STONE_GATE": {"min_level": 3, "perk": "STONE_FOUNDATIONS", "rank": 1},
	"ANIMAL_PEN": {"min_level": 3, "perk": "GREAT_LODGES", "rank": 1},
	"WATCHTOWER": {"min_level": 4, "perk": "MASTERWORK_DEFENCES", "rank": 1},
}

const RIVAL_PRIORITIES := {
	GameData.AIPersonality.WARLORD: [
		"PRIMAL_VIGOR", "WARLORDS_EDGE", "CALL_OF_THE_HEARTH", "BARRACKS_DRILLMASTERS",
		"BATTLE_VETERANS", "DIVINE_CONDUIT", "MASTER_BUILDERS", "STONE_FOUNDATIONS",
		"MASTERWORK_DEFENCES", "SEASONED_BLOODLINES", "SWIFT_STRIDE", "GREAT_LODGES",
	],
	GameData.AIPersonality.ZEALOT: [
		"PRIMAL_VIGOR", "WARLORDS_EDGE", "DIVINE_CONDUIT", "CALL_OF_THE_HEARTH",
		"SEASONED_BLOODLINES", "BARRACKS_DRILLMASTERS", "MASTER_BUILDERS", "STONE_FOUNDATIONS",
		"GREAT_LODGES", "SWIFT_STRIDE", "BATTLE_VETERANS", "MASTERWORK_DEFENCES",
	],
	GameData.AIPersonality.OPPORTUNIST: [
		"PRIMAL_VIGOR", "SWIFT_STRIDE", "CALL_OF_THE_HEARTH", "WARLORDS_EDGE",
		"SEASONED_BLOODLINES", "BARRACKS_DRILLMASTERS", "MASTER_BUILDERS", "BATTLE_VETERANS",
		"DIVINE_CONDUIT", "STONE_FOUNDATIONS", "GREAT_LODGES", "MASTERWORK_DEFENCES",
	],
	GameData.AIPersonality.GUARDIAN: [
		"MASTER_BUILDERS", "STONE_FOUNDATIONS", "GREAT_LODGES", "MASTERWORK_DEFENCES",
		"PRIMAL_VIGOR", "CALL_OF_THE_HEARTH", "SEASONED_BLOODLINES", "BARRACKS_DRILLMASTERS",
		"WARLORDS_EDGE", "SWIFT_STRIDE", "DIVINE_CONDUIT", "BATTLE_VETERANS",
	],
}

const DEFAULT_RIVAL_PRIORITY := [
	"PRIMAL_VIGOR", "WARLORDS_EDGE", "CALL_OF_THE_HEARTH", "BARRACKS_DRILLMASTERS",
	"MASTER_BUILDERS", "STONE_FOUNDATIONS", "SEASONED_BLOODLINES", "SWIFT_STRIDE",
	"GREAT_LODGES", "MASTERWORK_DEFENCES", "DIVINE_CONDUIT", "BATTLE_VETERANS",
]


static func xp_for_next_level(level: int) -> float:
	return 80.0 + float(maxi(1, level) - 1) * 55.0


static func get_level(faction: Dictionary) -> int:
	return clampi(int(faction.get("level", 1)), 1, MAX_LEVEL)


static func get_xp(faction: Dictionary) -> float:
	return maxf(0.0, float(faction.get("xp", 0.0)))


static func get_skill_points(faction: Dictionary) -> int:
	return maxi(0, int(faction.get("skill_points", 0)))


static func get_perk_rank(faction: Dictionary, perk_id: String) -> int:
	var perks: Variant = faction.get("perks", {})
	if typeof(perks) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((perks as Dictionary).get(perk_id, 0)))


static func get_total_perk_ranks(faction: Dictionary) -> int:
	var total := 0
	for perk_id in PERK_ORDER:
		total += get_perk_rank(faction, perk_id)
	return total


static func get_perk_lock_reason(faction: Dictionary, perk_id: String) -> String:
	if not PERK_DEFINITIONS.has(perk_id):
		return "Unknown perk"
	var def: Dictionary = PERK_DEFINITIONS[perk_id]
	var cur_rank: int = get_perk_rank(faction, perk_id)
	var max_rank: int = int(def["max_rank"])
	if cur_rank >= max_rank:
		return "Maxed"
	var min_lvl: int = int(def["min_level"])
	if get_level(faction) < min_lvl:
		return "Requires Lv. %d" % min_lvl
	var req_id: String = str(def.get("requires", ""))
	if not req_id.is_empty() and get_perk_rank(faction, req_id) < 1:
		var req_name: String = str(PERK_DEFINITIONS.get(req_id, {}).get("name", req_id))
		return "Requires %s" % req_name
	if get_skill_points(faction) < 1:
		return "No Skill Points"
	return ""


static func can_unlock_perk(faction: Dictionary, perk_id: String) -> bool:
	return get_perk_lock_reason(faction, perk_id).is_empty()


static func get_building_lock_reason(faction: Dictionary, building_type: String) -> String:
	if not BUILDING_UNLOCK_RULES.has(building_type):
		return ""
	var rule: Dictionary = BUILDING_UNLOCK_RULES[building_type]
	var req_lvl: int = int(rule["min_level"])
	var req_perk: String = str(rule["perk"])
	var req_rank: int = int(rule["rank"])
	var need_lvl: bool = get_level(faction) < req_lvl
	var need_perk: bool = get_perk_rank(faction, req_perk) < req_rank
	var perk_name: String = str(PERK_DEFINITIONS.get(req_perk, {}).get("name", req_perk))
	if need_lvl and need_perk:
		return "Requires Lv. %d & %s [K]" % [req_lvl, perk_name]
	if need_lvl:
		return "Requires Tribal Level %d" % req_lvl
	if need_perk:
		return "Requires %s [K]" % perk_name
	return ""


static func is_building_unlocked(faction: Dictionary, building_type: String) -> bool:
	return get_building_lock_reason(faction, building_type).is_empty()


static func get_build_speed_mult(faction: Dictionary) -> float:
	return 1.0 + 0.25 * float(get_perk_rank(faction, "MASTER_BUILDERS"))


static func get_building_cost_mult(faction: Dictionary) -> float:
	var table := [1.0, 0.90, 0.82, 0.75]
	return float(table[clampi(get_perk_rank(faction, "MASTER_BUILDERS"), 0, 3)])


static func get_building_hp_mult(faction: Dictionary) -> float:
	return 1.0 + 0.20 * float(get_perk_rank(faction, "STONE_FOUNDATIONS"))


static func get_building_regen_per_sec(faction: Dictionary) -> float:
	return 1.5 * float(get_perk_rank(faction, "STONE_FOUNDATIONS"))


static func get_extra_housing(faction: Dictionary, building_type: String) -> int:
	if building_type == "SLEEPING_HUT" or building_type == "CAMPFIRE":
		return get_perk_rank(faction, "GREAT_LODGES")
	return 0


static func get_campfire_heal_mult(faction: Dictionary) -> float:
	return 1.0 + 0.50 * float(get_perk_rank(faction, "GREAT_LODGES"))


static func get_lodge_crop_yield_mult(faction: Dictionary) -> float:
	return 1.0 + 0.20 * float(get_perk_rank(faction, "GREAT_LODGES"))


static func get_watchtower_mult(faction: Dictionary) -> float:
	return 1.0 + 0.25 * float(get_perk_rank(faction, "MASTERWORK_DEFENCES"))


static func get_watchtower_range_bonus(faction: Dictionary) -> float:
	return 3.0 * float(get_perk_rank(faction, "MASTERWORK_DEFENCES"))


static func get_pen_extra_capacity(faction: Dictionary) -> int:
	return 2 * get_perk_rank(faction, "MASTERWORK_DEFENCES")


static func get_unit_hp_mult(faction: Dictionary, is_leader: bool) -> float:
	var r: int = get_perk_rank(faction, "PRIMAL_VIGOR")
	return (1.0 + 0.20 * float(r)) if is_leader else (1.0 + 0.10 * float(r))


static func get_unit_armor_bonus(faction: Dictionary, is_leader: bool, is_warrior: bool) -> float:
	var armor_bonus := 0.0
	if is_leader:
		armor_bonus += 3.0 * float(get_perk_rank(faction, "PRIMAL_VIGOR"))
	if is_leader or is_warrior:
		armor_bonus += 2.0 * float(get_perk_rank(faction, "WARLORDS_EDGE"))
	return armor_bonus


static func get_unit_damage_mult(faction: Dictionary, is_leader: bool, is_warrior: bool) -> float:
	var r: int = get_perk_rank(faction, "WARLORDS_EDGE")
	if is_leader:
		return 1.0 + 0.20 * float(r)
	if is_warrior:
		return 1.0 + 0.10 * float(r)
	return 1.0


static func get_leader_attack_cd_mult(faction: Dictionary) -> float:
	var table := [1.0, 0.85, 0.75, 0.65]
	return float(table[clampi(get_perk_rank(faction, "WARLORDS_EDGE"), 0, 3)])


static func get_move_speed_mult(faction: Dictionary) -> float:
	return 1.0 + 0.10 * float(get_perk_rank(faction, "SWIFT_STRIDE"))


static func get_work_speed_mult(faction: Dictionary) -> float:
	return 1.0 + 0.20 * float(get_perk_rank(faction, "SWIFT_STRIDE"))


static func get_leader_dash_cd_mult(faction: Dictionary) -> float:
	var table := [1.0, 0.70, 0.50]
	return float(table[clampi(get_perk_rank(faction, "SWIFT_STRIDE"), 0, 2)])


static func get_blessing_cd_mult(faction: Dictionary) -> float:
	return 0.65 if get_perk_rank(faction, "DIVINE_CONDUIT") > 0 else 1.0


static func get_blessing_power_mult(faction: Dictionary) -> float:
	return 1.35 if get_perk_rank(faction, "DIVINE_CONDUIT") > 0 else 1.0


static func get_hire_nomad_cost(faction: Dictionary) -> int:
	var table := [12, 12, 10, 8]
	return int(table[clampi(get_perk_rank(faction, "CALL_OF_THE_HEARTH"), 0, 3)])


static func get_max_population_cap(faction: Dictionary) -> int:
	return 32 + 8 * get_perk_rank(faction, "CALL_OF_THE_HEARTH")


static func get_repro_chance_mult(faction: Dictionary) -> float:
	return 1.0 + 0.25 * float(get_perk_rank(faction, "CALL_OF_THE_HEARTH"))


static func get_recruit_stat_mult(faction: Dictionary) -> float:
	return 1.0 + 0.15 * float(get_perk_rank(faction, "SEASONED_BLOODLINES"))


static func get_recruit_starting_rank(faction: Dictionary) -> int:
	return maxi(0, get_perk_rank(faction, "SEASONED_BLOODLINES") - 1)


static func get_recruit_morale_bonus(faction: Dictionary) -> float:
	return 10.0 if get_perk_rank(faction, "SEASONED_BLOODLINES") > 0 else 0.0


static func get_training_xp_mult(faction: Dictionary) -> float:
	return 1.0 + 0.50 * float(get_perk_rank(faction, "BARRACKS_DRILLMASTERS"))


static func get_training_max_rank(faction: Dictionary) -> int:
	return 5 + get_perk_rank(faction, "BARRACKS_DRILLMASTERS")


static func can_idle_warriors_train(faction: Dictionary) -> bool:
	return get_perk_rank(faction, "BARRACKS_DRILLMASTERS") > 0


static func has_battle_veterans(faction: Dictionary) -> bool:
	return get_perk_rank(faction, "BATTLE_VETERANS") > 0


static func pick_rival_perk(faction: Dictionary) -> String:
	var personality: int = int(faction.get("ai_personality", GameData.AIPersonality.WARLORD))
	var order: Array = RIVAL_PRIORITIES.get(personality, DEFAULT_RIVAL_PRIORITY)
	for perk_id in order:
		if can_unlock_perk(faction, str(perk_id)):
			return str(perk_id)
	for perk_id in PERK_ORDER:
		if can_unlock_perk(faction, perk_id):
			return perk_id
	return ""

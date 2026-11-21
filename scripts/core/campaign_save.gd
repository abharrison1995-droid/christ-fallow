extends RefCounted

const Layout = preload("res://scripts/core/world_layout.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")
const VERSION := 4

const FACTION_FIELDS := {
	"name": TYPE_STRING, "leader_name": TYPE_STRING, "personality_name": TYPE_STRING,
	"ai_personality": TYPE_INT, "primary_lineage": TYPE_INT, "weapon_specialty": TYPE_INT,
	"patron_god": TYPE_INT, "tech_tier": TYPE_INT, "is_founded": TYPE_BOOL, "is_defeated": TYPE_BOOL,
	"tenets": TYPE_ARRAY, "resources": TYPE_DICTIONARY, "stockpile": TYPE_DICTIONARY,
	"craft_queue": TYPE_ARRAY,
}
const RESOURCE_FIELDS := {
	"food": TYPE_FLOAT, "wood": TYPE_FLOAT, "stone": TYPE_FLOAT, "flint": TYPE_FLOAT,
	"hide": TYPE_FLOAT, "bone": TYPE_FLOAT, "faith": TYPE_FLOAT,
}
const STOCKPILE_FIELDS := {
	"spears": TYPE_INT, "knives": TYPE_INT, "bows": TYPE_INT, "clubs": TYPE_INT,
	"javelins": TYPE_INT, "armor": TYPE_INT,
}
const UNIT_FIELDS := {
	"unit_id": TYPE_INT, "unit_name": TYPE_STRING, "original_faction_id": TYPE_INT,
	"gender": TYPE_INT, "lineage": TYPE_INT, "role": TYPE_INT, "warrior_class": TYPE_INT,
	"is_player_controlled": TYPE_BOOL, "is_child": TYPE_BOOL, "is_caveman": TYPE_BOOL,
	"growth_progress": TYPE_FLOAT, "base_hp_stat": TYPE_FLOAT, "base_melee_stat": TYPE_FLOAT,
	"base_ranged_stat": TYPE_FLOAT, "melee_rank": TYPE_INT, "ranged_rank": TYPE_INT,
	"training_xp": TYPE_FLOAT, "morale": TYPE_FLOAT, "is_revolting": TYPE_BOOL,
	"is_wounded": TYPE_BOOL, "is_healing_in_shack": TYPE_BOOL, "being_rescued": TYPE_BOOL,
	"wounded_timer": TYPE_FLOAT, "field_aid_applied": TYPE_BOOL, "has_equipped_weapon": TYPE_BOOL,
	"weapon_tier": TYPE_INT, "has_armor": TYPE_BOOL, "squad_order": TYPE_INT, "fire_at_will": TYPE_BOOL,
	"is_raiding": TYPE_BOOL, "dusk_eaten_today": TYPE_INT, "night_morale_today": TYPE_INT,
	"leader_blessing_cd": TYPE_FLOAT, "buff_timer": TYPE_FLOAT, "buff_speed_mult": TYPE_FLOAT,
	"buff_armor_bonus": TYPE_FLOAT, "carry_type": TYPE_STRING, "carry_amount": TYPE_FLOAT,
}
const BUILDING_FIELDS := {
	"building_type": TYPE_STRING, "faction_id": TYPE_INT, "rot_y": TYPE_FLOAT,
	"is_constructed": TYPE_BOOL, "build_progress": TYPE_FLOAT, "hp": TYPE_FLOAT,
}
const COMMAND_FIELDS := {
	"selected_warrior_class": TYPE_INT, "last_issued_order": TYPE_INT, "global_fire_at_will": TYPE_BOOL,
}


static func unpack(parsed: Variant) -> Dictionary:
	if not _matches(parsed, {"factions": TYPE_DICTIONARY, "diplomacy": TYPE_DICTIONARY, "units": TYPE_ARRAY, "buildings": TYPE_ARRAY}):
		return {}
	var save: Dictionary = parsed
	if not _matches(save, {
		"version": TYPE_INT, "valley_layout_id": TYPE_STRING, "time_of_day": TYPE_FLOAT, "day_count": TYPE_INT,
		"bandit_grace_remaining": TYPE_FLOAT, "warhorn_active": TYPE_BOOL, "tutorial_step": TYPE_INT,
		"tutorial_completed": TYPE_BOOL, "tutorial_skipped": TYPE_BOOL, "tutorial_harvested": TYPE_BOOL,
		"tutorial_assigned_role": TYPE_BOOL, "tutorial_cleaved": TYPE_BOOL, "tutorial_thrown": TYPE_BOOL,
		"builder_tip_shown": TYPE_BOOL, "wildlife": TYPE_ARRAY, "combat_commands": TYPE_DICTIONARY,
		"pending_conquests": TYPE_ARRAY, "player_leader_id": TYPE_INT, "player_controller": TYPE_DICTIONARY,
	}, false):
		return {}
	if save.has("player_controller") and not _matches(save["player_controller"], {"blessing_cooldown": TYPE_FLOAT}, false):
		return {}
	var version := int(save.get("version", 1))
	if version < 1 or version > VERSION:
		return {}
	if version >= 3 and not save.has_all(["wildlife", "combat_commands"]):
		return {}
	if version < 4:
		save["valley_layout_id"] = Layout.CLASSIC_ID
	elif not Layout.has_layout(str(save.get("valley_layout_id", ""))):
		return {}
	var commands: Dictionary = save.get("combat_commands", {})
	if not _matches(commands, COMMAND_FIELDS, version >= 3):
		return {}
	var selected_class := int(commands.get("selected_warrior_class", -1))
	if selected_class != -1 and not GameData.WARRIOR_CLASS_NAMES.has(selected_class):
		return {}
	if not GameData.SQUAD_ORDER_NAMES.has(int(commands.get("last_issued_order", GameData.SquadOrder.FOLLOW))):
		return {}

	var loaded_factions: Dictionary = save["factions"]
	var factions := {}
	for id in range(7):
		var faction: Variant = loaded_factions.get(str(id))
		if not _matches(faction, FACTION_FIELDS) or not _normalize_faction(faction, id):
			return {}
		factions[id] = faction
	save["factions"] = factions
	for target_id in save.get("pending_conquests", []):
		if typeof(target_id) != TYPE_FLOAT and typeof(target_id) != TYPE_INT:
			return {}
		var id := int(target_id)
		if float(target_id) != float(id) or not id in [1, 2, 3, 4, 6] or factions[id]["is_defeated"]:
			return {}
	for relation in save["diplomacy"].values():
		if not _matches(relation, {"state": TYPE_INT, "opinion_mod": TYPE_INT, "truce_timer": TYPE_FLOAT}):
			return {}
		relation["state"] = int(relation["state"])
		if not GameData.DiplomaticState.values().has(relation["state"]):
			return {}
		relation["opinion_mod"] = int(relation["opinion_mod"])
		relation["truce_timer"] = maxf(0.0, float(relation["truce_timer"]))

	var expected_leader := int(save.get("player_leader_id", 0))
	if save.has("player_leader_id") and expected_leader <= 0:
		return {}
	var found_expected_leader := false
	for unit in save["units"]:
		if not _matches(unit, {"faction_id": TYPE_INT, "is_leader": TYPE_BOOL, "hp": TYPE_FLOAT}):
			return {}
		if not _unpack_unit(unit):
			return {}
		if int(unit["faction_id"]) == 0 and unit["is_leader"] and int(unit.get("unit_id", 0)) == expected_leader:
			found_expected_leader = true
	# A snapshot can legitimately have no leader during succession or after defeat.
	if expected_leader > 0 and not found_expected_leader:
		return {}
	for building in save["buildings"]:
		if not _matches(building, BUILDING_FIELDS) or not GameData.BUILDINGS.has(building["building_type"]):
			return {}
		building["pos"] = _position(building.get("pos"))
		if building["pos"] == null or not factions.has(int(building["faction_id"])):
			return {}
		if not _validate_farm_building(building):
			return {}
	var restored_rider := false
	for animal in save.get("wildlife", []):
		if not _matches(animal, {"animal_type": TYPE_STRING, "hp": TYPE_FLOAT, "rot_y": TYPE_FLOAT}):
			return {}
		animal["pos"] = _position(animal.get("pos"))
		animal["home_pos"] = _position(animal.get("home_pos"))
		if animal["pos"] == null or animal["home_pos"] == null or not GameData.WILDLIFE_DATA.has(animal["animal_type"]):
			return {}
		if not _unpack_livestock(animal, factions):
			return {}
		var rider := int(animal.get("rider_unit_id", 0))
		if rider > 0:
			if restored_rider or rider != expected_leader or not found_expected_leader \
					or int(animal.get("owner_faction", -1)) != 0 or animal["animal_type"] != "BOAR" \
					or float(animal.get("maturity_remaining", 0.0)) > 0.0 \
					or int(animal.get("training_feeds", 0)) < Farming.MOUNT_TRAINING:
				return {}
			restored_rider = true
	return save


static func _validate_farm_building(building: Dictionary) -> bool:
	if not _matches(building, {"crop_stage": TYPE_INT, "crop_progress": TYPE_FLOAT, "crop_work": TYPE_FLOAT,
		"crop_tended": TYPE_BOOL, "pen_clock": TYPE_FLOAT}, false):
		return false
	var stage := int(building.get("crop_stage", Farming.CropStage.EMPTY))
	return Farming.CropStage.values().has(stage) \
		and float(building.get("crop_progress", 0.0)) >= 0.0 \
		and float(building.get("crop_progress", 0.0)) <= Farming.CROP_GROW_TIME \
		and float(building.get("crop_work", 0.0)) >= 0.0 \
		and float(building.get("crop_work", 0.0)) <= Farming.CROP_WORK_TIMES[stage] \
		and float(building.get("pen_clock", 0.0)) >= 0.0 \
		and float(building.get("pen_clock", 0.0)) <= Farming.PEN_INTERVAL


static func _unpack_livestock(animal: Dictionary, factions: Dictionary) -> bool:
	if not _matches(animal, {"owner_faction": TYPE_INT, "maturity_remaining": TYPE_FLOAT,
		"training_feeds": TYPE_INT, "rider_unit_id": TYPE_INT, "tame_cooldown": TYPE_FLOAT}, false):
		return false
	var owner := int(animal.get("owner_faction", -1))
	var training := int(animal.get("training_feeds", 0))
	var maturity := float(animal.get("maturity_remaining", 0.0))
	var rider := int(animal.get("rider_unit_id", 0))
	if owner != -1 and (not factions.has(owner) or not Farming.TAME_CHANCES.has(animal["animal_type"])):
		return false
	if training < 0 or training > Farming.MOUNT_TRAINING or maturity < 0.0 or maturity > Farming.MATURITY_TIME or rider < 0:
		return false
	if owner == -1 and (training != 0 or maturity > 0.0 or rider != 0 or animal.has("pen_position")):
		return false
	if animal.has("pen_position"):
		animal["pen_position"] = _position(animal["pen_position"])
		if animal["pen_position"] == null:
			return false
	return float(animal.get("tame_cooldown", 0.0)) >= 0.0


static func _normalize_faction(faction: Dictionary, id: int) -> bool:
	if not _matches(faction, {
		"captured_cavemen": TYPE_INT,
		"blessing_cooldown": TYPE_FLOAT,
		"raid_cooldown": TYPE_FLOAT,
		"caveman_spawn_timer": TYPE_FLOAT,
		"diplomacy_event_cd": TYPE_FLOAT,
	}, false):
		return false
	faction["camp_position"] = _position(faction.get("camp_position"))
	if faction["camp_position"] == null:
		return false
	faction["id"] = id
	for key in ["ai_personality", "primary_lineage", "weapon_specialty", "patron_god", "tech_tier"]:
		faction[key] = int(faction[key])
	if not GameData.LINEAGE_DATA.has(faction["primary_lineage"]) or not GameData.WARRIOR_CLASS_NAMES.has(faction["weapon_specialty"]):
		return false
	if not GameData.PatronGod.values().has(faction["patron_god"]) or not GameData.TECH_TIER_NAMES.has(faction["tech_tier"]):
		return false
	faction["captured_cavemen"] = int(faction.get("captured_cavemen", 0))
	if not _matches(faction["resources"], RESOURCE_FIELDS) or not _matches(faction["stockpile"], STOCKPILE_FIELDS):
		return false
	for key in STOCKPILE_FIELDS:
		faction["stockpile"][key] = int(faction["stockpile"][key])
	for recipe in faction["craft_queue"]:
		if not GameData.CRAFT_RECIPES.has(recipe):
			return false
	for tenet in faction["tenets"]:
		if typeof(tenet) != TYPE_STRING:
			return false
	return true


static func _unpack_unit(unit: Dictionary) -> bool:
	if not _matches(unit, UNIT_FIELDS, false) or not int(unit["faction_id"]) in range(-3, 7):
		return false
	if not GameData.LINEAGE_DATA.has(int(unit.get("lineage", GameData.Lineage.CRAG_BORN))):
		return false
	if not GameData.ROLE_NAMES.has(int(unit.get("role", GameData.Role.FORAGER))):
		return false
	if not GameData.WARRIOR_CLASS_NAMES.has(int(unit.get("warrior_class", GameData.WarriorClass.SPEARMAN))):
		return false
	if not GameData.SQUAD_ORDER_NAMES.has(int(unit.get("squad_order", GameData.SquadOrder.FOLLOW))):
		return false
	unit["pos"] = _position(unit.get("pos"))
	unit["hold_position"] = _position(unit.get("hold_position", unit["pos"]))
	unit["raid_target_pos"] = _position(unit.get("raid_target_pos", Vector3.ZERO))
	return unit["pos"] != null and unit["hold_position"] != null and unit["raid_target_pos"] != null


static func _matches(value: Variant, fields: Dictionary, require_all: bool = true) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for key in fields:
		if not value.has(key):
			if require_all:
				return false
			continue
		var actual_type := typeof(value[key])
		var expected_type: int = fields[key]
		if expected_type == TYPE_INT or expected_type == TYPE_FLOAT:
			if (actual_type != TYPE_INT and actual_type != TYPE_FLOAT) or not is_finite(float(value[key])):
				return false
			if expected_type == TYPE_INT and float(value[key]) != floorf(float(value[key])):
				return false
		elif actual_type != expected_type:
			return false
	return true


static func _position(value: Variant) -> Variant:
	if value is Vector3:
		return value
	# Older saves contain the JSON string form of the faction camp position.
	if value is String:
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() != 3:
			return null
		for part in parts:
			if not part.strip_edges().is_valid_float():
				return null
		value = [parts[0].to_float(), parts[1].to_float(), parts[2].to_float()]
	if value is Array and value.size() == 3:
		for coordinate in value:
			if (typeof(coordinate) != TYPE_FLOAT and typeof(coordinate) != TYPE_INT) or not is_finite(float(coordinate)):
				return null
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return null


static func pack_position(position: Vector3) -> Array[float]:
	return [position.x, position.y, position.z]

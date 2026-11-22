extends "res://scripts/ui/drawers/feature_drawer.gd"

const PerkSystem = preload("res://scripts/core/perk_system.gd")

var _branch_filter := "ALL"
var _prog_sig: Array = []


func _init() -> void:
	title = "Tribal Perks & Skills"


func _progression_signature() -> Array:
	if not GameState.factions.has(0):
		return []
	var f0: Dictionary = GameState.factions[0]
	var perks: Variant = f0.get("perks", {})
	return [
		PerkSystem.get_level(f0),
		int(PerkSystem.get_xp(f0)),
		PerkSystem.get_skill_points(f0),
		perks.duplicate() if typeof(perks) == TYPE_DICTIONARY else {},
	]


func build_content() -> void:
	var f0: Dictionary = GameState.factions.get(0, {})
	_prog_sig = _progression_signature()

	var lvl: int = PerkSystem.get_level(f0)
	var xp: float = PerkSystem.get_xp(f0)
	var req_xp: float = PerkSystem.xp_for_next_level(lvl)
	var sp: int = PerkSystem.get_skill_points(f0)

	var summary := _card(self, Look.GOLD if sp > 0 else Look.EDGE)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 6)
	summary.add_child(svb)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	svb.add_child(top_row)
	var xp_str := "MAX LEVEL" if lvl >= PerkSystem.MAX_LEVEL else "%d / %d XP" % [int(xp), int(req_xp)]
	var lvl_lbl := Look.label("Tribal Level %d  ·  %s" % [lvl, xp_str], &"SectionTitle", 21)
	lvl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lvl_lbl)

	var sp_lbl := Look.label("Skill Points: %d" % sp, &"SectionTitle", 20)
	sp_lbl.add_theme_color_override("font_color", Look.GOLD if sp > 0 else Look.MUTED)
	top_row.add_child(sp_lbl)

	var bonus_lbl := Look.label(
		"Build Speed: %d%%  ·  Building HP: %d%%  ·  Unit HP: %d%%  ·  Max Training Rank: %d  ·  Pop Cap: %d" % [
			roundi(PerkSystem.get_build_speed_mult(f0) * 100.0),
			roundi(PerkSystem.get_building_hp_mult(f0) * 100.0),
			roundi(PerkSystem.get_unit_hp_mult(f0, false) * 100.0),
			PerkSystem.get_training_max_rank(f0),
			PerkSystem.get_max_population_cap(f0),
		],
		&"QuietLabel",
		13
	)
	bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	svb.add_child(bonus_lbl)

	var tabs := HBoxContainer.new()
	self.add_child(tabs)
	for item in [
		["ALL", "All Branches"],
		["MASONRY", "Masonry"],
		["MIGHT", "Might"],
		["KINSHIP", "Kinship"],
	]:
		var bkey: String = item[0]
		var tab_btn := Look.button(item[1], func():
			_branch_filter = bkey
			refresh()
		)
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = _branch_filter == bkey
		tag(tab_btn, "branch:" + bkey)
		tabs.add_child(tab_btn)

	for branch_key in PerkSystem.BRANCH_ORDER:
		if _branch_filter != "ALL" and _branch_filter != branch_key:
			continue
		self.add_child(Look.label(PerkSystem.BRANCH_TITLES[branch_key], &"SectionTitle", 21))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		self.add_child(grid)

		for perk_id in PerkSystem.PERK_ORDER:
			var def: Dictionary = PerkSystem.PERK_DEFINITIONS[perk_id]
			if str(def["branch"]) != branch_key:
				continue
			_add_perk_card(grid, f0, perk_id, def)


func _add_perk_card(parent: Control, f0: Dictionary, perk_id: String, def: Dictionary) -> void:
	var cur_rank: int = PerkSystem.get_perk_rank(f0, perk_id)
	var max_rank: int = int(def["max_rank"])
	var lock_reason: String = PerkSystem.get_perk_lock_reason(f0, perk_id)
	var edge: Color = Look.MOSS if cur_rank >= max_rank else (Look.GOLD if cur_rank > 0 or lock_reason.is_empty() else Look.EDGE)
	var card := _card(parent, edge)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var name_lbl := Look.label(str(def["name"]), &"SectionTitle", 18)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(name_lbl)
	var rank_lbl := Look.label("Rank %d/%d" % [cur_rank, max_rank], &"QuietLabel", 14)
	rank_lbl.add_theme_color_override("font_color", Look.MOSS if cur_rank >= max_rank else (Look.GOLD if cur_rank > 0 else Look.MUTED))
	hdr.add_child(rank_lbl)

	var req_parts := PackedStringArray()
	var min_lvl: int = int(def["min_level"])
	if min_lvl > 1:
		req_parts.append("Lv. %d+" % min_lvl)
	var req_id: String = str(def.get("requires", ""))
	if not req_id.is_empty():
		req_parts.append("Requires %s" % str(PerkSystem.PERK_DEFINITIONS.get(req_id, {}).get("name", req_id)))
	if not req_parts.is_empty():
		var req_lbl := Look.label("  ·  ".join(req_parts), &"QuietLabel", 12)
		vb.add_child(req_lbl)

	var desc_lbl := Look.label(str(def["desc"]), &"QuietLabel", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_lbl)

	var btn_caption := "Maxed"
	var can_buy := false
	if cur_rank < max_rank:
		if lock_reason.is_empty():
			btn_caption = "Learn (1 Pt)" if cur_rank == 0 else "Upgrade (1 Pt)"
			can_buy = true
		else:
			btn_caption = lock_reason
	var pid: String = perk_id
	var act_btn := Look.button(btn_caption, func():
		if GameState.unlock_perk(0, pid):
			refresh()
	, &"PrimaryButton" if can_buy else &"")
	act_btn.disabled = not can_buy
	tag(act_btn, "perk:" + pid)
	vb.add_child(act_btn)


func update_live_values() -> void:
	if _progression_signature() != _prog_sig:
		refresh()

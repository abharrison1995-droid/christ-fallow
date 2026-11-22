extends "res://scripts/ui/drawers/feature_drawer.gd"

const Options = preload("res://scripts/ui/hud_drawers.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")

var _section := "Roster"
var _queue_label: Label
var _farm_label: Label
var _roster_state: Array[Array] = []
var _craft_state: Array = []
var _hire_state: Array = []
var _roster_rows: Dictionary = {}
var _tutorial_role_target: int = -1
var _highlighted_role_controls: int = 0
var _role_highlight_style: StyleBoxFlat = null


func has_tutorial_role_highlight() -> bool:
	return _tutorial_role_target >= 0 and _highlighted_role_controls > 0


func _get_role_highlight_style() -> StyleBoxFlat:
	if _role_highlight_style == null:
		_role_highlight_style = Look.panel(Color("3d3320"), Look.GOLD, 6, 4)
		_role_highlight_style.set_border_width_all(2)
		_role_highlight_style.content_margin_left = 11
		_role_highlight_style.content_margin_right = 11
	return _role_highlight_style


func _init() -> void:
	title = "Colony"


func build_content() -> void:
	_roster_rows.clear()
	_queue_label = null
	_farm_label = null
	_highlighted_role_controls = 0
	var guide_target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	_tutorial_role_target = int(guide_target.get("highlight_colony_role", -1)) if bool(guide_target.get("active", false)) else -1
	var units := GameState.get_faction_units(0)
	_roster_state = _roster_signature(units)
	_craft_state = _craft_signature()
	_hire_state = _hire_signature()
	var tabs := HBoxContainer.new()
	self.add_child(tabs)
	for caption in ["Roster", "Workforce", "Crafting", "Fields & Herds"]:
		var select := Look.button(caption, func():
			_section = caption
			refresh()
		)
		select.toggle_mode = true
		select.button_pressed = _section == caption
		tag(select, "section:" + caption)
		tabs.add_child(select)

	if _tutorial_role_target >= 0:
		var guide_lbl := Look.label("Guide: Assign a villager to Builder / Crafter (Roster dropdown or Workforce [+]) to construct buildings.", &"QuietLabel", 13)
		guide_lbl.add_theme_color_override("font_color", Look.GOLD)
		guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		self.add_child(guide_lbl)

	match _section:
		"Roster": _populate_colony_roster(units)
		"Workforce": _populate_colony_alloc_card(units)
		"Crafting": _populate_colony_craft_card(GameState.factions[0])
		"Fields & Herds": _populate_farms()


func _populate_farms() -> void:
	var card := _card(self)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	_farm_label = Look.label("")
	_farm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_farm_label)
	var harvest := Look.button("Harvest surplus livestock", _harvest_livestock)
	tag(harvest, "harvest-livestock")
	stack.add_child(harvest)
	_update_farm_status()


func _update_farm_status() -> void:
	var lines := PackedStringArray()
	var fields := GameState.get_faction_buildings(0, "CROP_FIELD", true)
	for i in range(fields.size()):
		var field: Node = fields[i]
		var status: String = ["Fallow", "Growing · %d%%" % roundi(field.crop_progress / Farming.CROP_GROW_TIME * 100.0), "Ripe"][field.crop_stage]
		lines.append("Crop Field %d  ·  %s" % [i + 1, status])
	var pens := GameState.get_faction_buildings(0, "ANIMAL_PEN", true)
	var pen_cap: int = Farming.PEN_CAPACITY + PerkSystem.get_pen_extra_capacity(GameState.factions.get(0, {}))
	for i in range(pens.size()):
		var herd: Array = pens[i].get_herd()
		var trained := 0
		for animal in herd:
			if animal.can_mount(0) or animal.rider_unit_id > 0:
				trained += 1
		lines.append("Animal Pen %d  ·  %d/%d animals  ·  %d trained mounts" % [i + 1, herd.size(), pen_cap, trained])
	_farm_label.text = "\n".join(lines) if not lines.is_empty() else "Build a Crop Field or Animal Pen in [B] Build."


func _harvest_livestock() -> void:
	for pen in GameState.get_faction_buildings(0, "ANIMAL_PEN", true):
		if pen.harvest_surplus_livestock():
			_update_farm_status()
			return
	GameState.push_log("Keep at least two adults of a species in the pen to breed.", "info")


func _populate_colony_craft_card(f0: Dictionary) -> void:
	var craft_panel: PanelContainer = _card(self)
	var cvb := VBoxContainer.new()
	craft_panel.add_child(cvb)

	var cur_tier: int = int(f0.get("tech_tier", 1))
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 12)
	cvb.add_child(tier_row)

	var tier_lbl := Label.new()
	tier_lbl.text = "Gear Quality: %s" % GameData.TECH_TIER_NAMES[cur_tier]
	tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_row.add_child(tier_lbl)

	if cur_tier < 3:
		var next_t := cur_tier + 1
		var upg_costs: Dictionary = GameData.TIER_UPGRADE_COSTS[next_t]
		var cp := []
		for k in upg_costs.keys():
			cp.append("%d %s" % [int(upg_costs[k]), k])
		var upg_btn := Button.new()
		upg_btn.text = "Advance to Tier %d (%s)" % [next_t, ", ".join(cp)]
		upg_btn.pressed.connect(func():
			var fc = GameState.faction_controllers.get(0)
			if fc != null:
				fc.upgrade_stone_age_tier()
				refresh()
		)
		tag(upg_btn, "upgrade")
		tier_row.add_child(upg_btn)

	if not GameState.has_building(0, "CRAFTING_PIT", true):
		var pit_lbl := Look.label("Build a Flint-Knapping & Crafting Pit ([B]) to craft gear or advance tiers.", &"QuietLabel", 14)
		pit_lbl.modulate = Look.GOLD
		pit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvb.add_child(pit_lbl)

	var craft_row := GridContainer.new()
	craft_row.columns = 3
	cvb.add_child(craft_row)

	for item_k in GameData.CRAFT_RECIPES.keys():
		var rec: Dictionary = GameData.CRAFT_RECIPES[item_k]
		var r_parts := []
		for ck in rec["costs"].keys():
			r_parts.append("%d%s" % [int(rec["costs"][ck]), ck.substr(0, 1).to_upper()])
		var cbtn := Button.new()
		cbtn.text = "%s  ·  %s" % [rec["name"], " ".join(r_parts)]
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ik: String = str(item_k)
		cbtn.pressed.connect(func():
			var fc = GameState.faction_controllers.get(0)
			if fc != null:
				fc.queue_craft(ik)
				refresh()
		)
		tag(cbtn, "craft:" + ik)
		craft_row.add_child(cbtn)

	_queue_label = Label.new()
	var q_arr: Array = f0.get("craft_queue", [])
	_queue_label.text = "Crafting Queue: %d item(s) pending" % q_arr.size()
	_queue_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
	cvb.add_child(_queue_label)

	var cap_count: int = int(f0.get("captured_cavemen", 0))
	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 12)
	cvb.add_child(cap_row)

	var cap_lbl := Label.new()
	cap_lbl.text = "Captured Nomadic Cavemen: %d (Enlighten for 8 Food + 5 Faith)" % cap_count
	cap_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(cap_lbl)

	var enl_btn := Button.new()
	enl_btn.text = "Enlighten Captive"
	enl_btn.disabled = cap_count <= 0
	enl_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.enlighten_captured_caveman()
			refresh()
	)
	tag(enl_btn, "enlighten")
	cap_row.add_child(enl_btn)


func _populate_colony_alloc_card(units: Array) -> void:
	var role_counts := {}
	var w_counts := {}
	for r_id in GameData.ROLE_NAMES.keys():
		role_counts[r_id] = 0
	for w_id in GameData.WARRIOR_CLASS_NAMES.keys():
		w_counts[w_id] = 0
	for u in units:
		if u.get("is_leader") or u.get("is_child"):
			continue
		var ur: int = int(u.get("role"))
		role_counts[ur] = int(role_counts.get(ur, 0)) + 1
		if ur == GameData.Role.WARRIOR:
			var uc: int = int(u.get("warrior_class"))
			w_counts[uc] = int(w_counts.get(uc, 0)) + 1

	var alloc_panel: PanelContainer = _card(self)
	var alloc_vb := VBoxContainer.new()
	alloc_panel.add_child(alloc_vb)
	var alloc_hdr := Label.new()
	alloc_hdr.text = "Adult workers and warriors"
	alloc_hdr.theme_type_variation = &"SectionTitle"
	alloc_hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44))
	alloc_vb.add_child(alloc_hdr)

	var alloc_grid := GridContainer.new()
	alloc_grid.columns = 2
	alloc_grid.add_theme_constant_override("h_separation", 18)
	alloc_grid.add_theme_constant_override("v_separation", 6)
	alloc_vb.add_child(alloc_grid)

	var alloc_specs: Array = []
	for r_id in [
		GameData.Role.FORAGER, GameData.Role.HUNTER, GameData.Role.LUMBERJACK,
		GameData.Role.STONEKNAPPER, GameData.Role.BUILDER_CRAFTER, GameData.Role.SHAMAN, GameData.Role.TRAINEE, GameData.Role.FARMER,
	]:
		alloc_specs.append({"name": GameData.ROLE_NAMES[r_id], "r": r_id, "wc": -1, "cnt": int(role_counts.get(r_id, 0))})
	for c_id in [
		GameData.WarriorClass.SPEARMAN, GameData.WarriorClass.KNIFE_RAIDER,
		GameData.WarriorClass.ARCHER, GameData.WarriorClass.BRUTE, GameData.WarriorClass.JAVELINEER,
	]:
		alloc_specs.append({"name": GameData.WARRIOR_CLASS_NAMES[c_id], "r": GameData.Role.WARRIOR, "wc": c_id, "cnt": int(w_counts.get(c_id, 0))})

	for spec in alloc_specs:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		alloc_grid.add_child(cell)

		var lbl := Label.new()
		lbl.text = "%s: %d" % [spec["name"], spec["cnt"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r_val: int = int(spec["r"])
		var wc_val: int = int(spec["wc"])
		var is_guided_role: bool = (_tutorial_role_target >= 0 and r_val == _tutorial_role_target and wc_val == -1)
		if is_guided_role:
			lbl.add_theme_color_override("font_color", Look.GOLD)
		cell.add_child(lbl)

		for step in [[-1, "-"], [1, "+"]]:
			var delta_v: int = int(step[0])
			var b := Button.new()
			b.text = str(step[1])
			b.custom_minimum_size = Vector2(28, 0)
			if is_guided_role and delta_v == 1:
				b.add_theme_stylebox_override("normal", _get_role_highlight_style())
				b.add_theme_color_override("font_color", Look.GOLD)
				b.add_theme_color_override("font_focus_color", Look.GOLD)
				_highlighted_role_controls += 1
			b.pressed.connect(func():
				if GameState.combat_command_system != null:
					GameState.combat_command_system.adjust_role_count(r_val, wc_val, delta_v)
					refresh()
			)
			tag(b, "allocate:%d:%d:%d" % [r_val, wc_val, delta_v])
			cell.add_child(b)


func _populate_colony_roster(units: Array) -> void:
	var f0: Dictionary = GameState.factions.get(0, {})
	var housing_cap: int = GameState.get_housing_capacity(0)
	var max_cap: int = GameState.get_max_population_cap(0)
	var hearth_rank: int = PerkSystem.get_perk_rank(f0, "CALL_OF_THE_HEARTH")
	var has_camp: bool = GameState.has_building(0, "CAMPFIRE", true)
	var hire_cost: int = PerkSystem.get_hire_nomad_cost(f0)
	var has_food: bool = float(f0.get("resources", {}).get("food", 0.0)) >= float(hire_cost)

	var recruit_row := HBoxContainer.new()
	recruit_row.add_theme_constant_override("separation", 12)
	_card(self).add_child(recruit_row)
	var cap_lbl := Look.label("%d tribesfolk  ·  Housing %d/%d  ·  Max Cap %d" % [units.size(), units.size(), housing_cap, max_cap], &"SectionTitle", 18)
	cap_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_row.add_child(cap_lbl)

	var hire_btn := Look.button("", func():
		if GameState.hire_nomad_villager(0) != null:
			refresh()
	)
	if hearth_rank <= 0:
		hire_btn.text = "Hire Nomad (Requires Call of the Hearth [K])"
		hire_btn.disabled = true
	elif not has_camp:
		hire_btn.text = "Hire Nomad (Requires Campfire)"
		hire_btn.disabled = true
	elif units.size() >= mini(housing_cap, max_cap):
		hire_btn.text = "Hire Nomad (Housing Full)"
		hire_btn.disabled = true
	else:
		hire_btn.text = "Hire Nomad Villager (%d Food)" % hire_cost
		hire_btn.disabled = not has_food
	tag(hire_btn, "hire-nomad")
	recruit_row.add_child(hire_btn)

	for u in units:
		var u_row := HBoxContainer.new()
		u_row.add_theme_constant_override("separation", 10)
		_card(self).add_child(u_row)

		var info_lbl := Label.new()
		info_lbl.text = format_colonist_line(u)
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_row.add_child(info_lbl)
		_roster_rows[u.unit_id] = {"label": info_lbl, "unit": u}

		var unit_ref: Node = u
		var insp_btn := Button.new()
		insp_btn.text = "Inspect"
		insp_btn.pressed.connect(func():
			inspect_requested.emit(unit_ref)
		)
		tag(insp_btn, "inspect:%d" % unit_ref.unit_id)
		u_row.add_child(insp_btn)

		if GameState.can_assign_player_role(u):
			var role_opt := OptionButton.new()
			Options.fill_role_options(role_opt)
			role_opt.selected = role_opt.get_item_index(u.role)
			if _tutorial_role_target >= 0:
				role_opt.add_theme_stylebox_override("normal", _get_role_highlight_style())
				role_opt.add_theme_color_override("font_color", Look.GOLD)
				role_opt.add_theme_color_override("font_focus_color", Look.GOLD)
				role_opt.tooltip_text = "Guide: Select Builder / Crafter"
				_highlighted_role_controls += 1
			role_opt.item_selected.connect(func(idx: int):
				var rid: int = role_opt.get_item_id(idx)
				GameState.assign_player_role(unit_ref, rid)
				refresh()
			)
			tag(role_opt, "unit-role:%d" % unit_ref.unit_id)
			u_row.add_child(role_opt)

			if u.role == GameData.Role.WARRIOR:
				var cls_opt := OptionButton.new()
				Options.fill_class_options(cls_opt)
				cls_opt.selected = cls_opt.get_item_index(u.warrior_class)
				cls_opt.item_selected.connect(func(idx: int):
					var cid: int = cls_opt.get_item_id(idx)
					GameState.assign_player_role(unit_ref, GameData.Role.WARRIOR, cid)
					refresh()
				)
				tag(cls_opt, "unit-class:%d" % unit_ref.unit_id)
				u_row.add_child(cls_opt)


func format_colonist_line(u: Node) -> String:
	var g_str := "M" if int(u.get("gender")) == GameData.Gender.MALE else "F"
	var l_str: String = GameData.LINEAGE_DATA[int(u.get("lineage"))]["short_name"]
	var age_str := " [Child]" if bool(u.get("is_child")) else (" [LEADER]" if bool(u.get("is_leader")) else "")
	var gear_str := "Melee %.0f   ·   Ranged %.0f   ·   Morale %.0f%%" % [float(u.get("close_quarters_damage")), float(u.get("ranged_attack_damage")), float(u.get("morale"))]
	return "%s  ·  %s, %s%s     |     %.0f/%.0f HP\n%s" % [str(u.get("unit_name")), g_str, l_str, age_str, float(u.get("hp")), float(u.get("max_hp")), gear_str]


func update_live_values() -> void:
	if is_instance_valid(_farm_label):
		_update_farm_status()
	var guide_target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var next_role_target: int = int(guide_target.get("highlight_colony_role", -1)) if bool(guide_target.get("active", false)) else -1
	if next_role_target != _tutorial_role_target:
		refresh()
		return
	if _roster_signature(GameState.get_faction_units(0)) != _roster_state:
		refresh()
		return
	if _section == "Roster" and _hire_signature() != _hire_state:
		refresh()
		return
	if _section == "Crafting" and _craft_signature() != _craft_state:
		refresh()
		return
	if _queue_label != null and GameState.factions.has(0):
		var q_arr: Array = GameState.factions[0].get("craft_queue", [])
		_queue_label.text = "Crafting Queue: %d item(s) pending" % q_arr.size()
	for uid in _roster_rows.keys():
		var entry: Dictionary = _roster_rows[uid]
		var lbl: Label = entry["label"]
		var u: Node = entry["unit"]
		if is_instance_valid(lbl) and is_instance_valid(u) and not u.get("is_dead"):
			lbl.text = format_colonist_line(u)


func _roster_signature(units: Array) -> Array[Array]:
	var signature: Array[Array] = []
	for unit in units:
		signature.append([unit.unit_id, unit.role, unit.warrior_class, GameState.can_assign_player_role(unit)])
	return signature


func _craft_signature() -> Array:
	if not GameState.factions.has(0):
		return []
	var f0: Dictionary = GameState.factions[0]
	return [
		int(f0.get("captured_cavemen", 0)),
		int(f0.get("tech_tier", 1)),
		GameState.has_building(0, "CRAFTING_PIT", true),
	]


func _hire_signature() -> Array:
	if not GameState.factions.has(0):
		return []
	var f0: Dictionary = GameState.factions[0]
	var cost: int = PerkSystem.get_hire_nomad_cost(f0)
	return [
		PerkSystem.get_perk_rank(f0, "CALL_OF_THE_HEARTH"),
		GameState.get_housing_capacity(0),
		GameState.get_max_population_cap(0),
		GameState.has_building(0, "CAMPFIRE", true),
		float(f0.get("resources", {}).get("food", 0.0)) >= float(cost),
	]

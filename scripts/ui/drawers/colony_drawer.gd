extends "res://scripts/ui/drawers/feature_drawer.gd"

const Options = preload("res://scripts/ui/hud_drawers.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const ArenaRules = preload("res://scripts/core/arena_rules.gd")

var _section := "Roster"
var _queue_label: Label
var _farm_label: Label
var _roster_state: Array[Array] = []
var _craft_state: Array = []
var _hire_state: Array = []
var _arena_state: Array = []
var _roster_rows: Dictionary = {}
var _tutorial_role_target: int = -1
var _highlighted_role_controls: int = 0
var _role_highlight_style: StyleBoxFlat = null
var _arena_mode: String = ArenaRules.MODE_CHIEFTAIN
var _arena_tier: int = 1
var _arena_fighter_ids: Array[int] = []
var _arena_status_lbl: Label = null
var _arena_live_lbl: Label = null
var _arena_start_btn: Button = null
var _arena_spectate_btn: Button = null
var _arena_forfeit_btn: Button = null
var _arena_leader_lbl: Label = null
var _arena_fighter_rows: Dictionary = {}


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


func reset_campaign_state() -> void:
	_section = "Roster"
	_arena_mode = ArenaRules.MODE_CHIEFTAIN
	_arena_tier = 1
	_arena_fighter_ids.clear()


func select_section(sec: String) -> void:
	_section = sec
	refresh()


func build_content() -> void:
	_roster_rows.clear()
	_arena_fighter_rows.clear()
	_queue_label = null
	_farm_label = null
	_arena_status_lbl = null
	_arena_live_lbl = null
	_arena_start_btn = null
	_arena_spectate_btn = null
	_arena_forfeit_btn = null
	_arena_leader_lbl = null
	_highlighted_role_controls = 0
	var guide_target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	_tutorial_role_target = int(guide_target.get("highlight_colony_role", -1)) if bool(guide_target.get("active", false)) else -1
	var units := GameState.get_faction_units(0)
	_roster_state = _roster_signature(units)
	_craft_state = _craft_signature()
	_hire_state = _hire_signature()
	_arena_state = _arena_signature()
	var tabs := HBoxContainer.new()
	self.add_child(tabs)
	for caption in ["Roster", "Workforce", "Crafting", "Fields & Herds", "Arena"]:
		var sec_name: String = str(caption)
		var select := Button.new()
		select.text = sec_name
		select.toggle_mode = true
		select.button_pressed = _section == sec_name
		select.pressed.connect(func():
			select.release_focus()
			_section = sec_name
			refresh()
		)
		tag(select, "section:" + sec_name)
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
		"Arena": _populate_arena_card(GameState.factions.get(0, {}))


func _populate_farms() -> void:
	var card := _card(self)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	_farm_label = Look.label("")
	_farm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_farm_label)
	var harvest := Button.new()
	harvest.text = "Harvest surplus livestock"
	harvest.pressed.connect(func():
		harvest.release_focus()
		_harvest_livestock()
	)
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
	var stock: Dictionary = f0.get("stockpile", {})
	var cur_tier: int = int(f0.get("tech_tier", 1))

	# 1. Leader Armory & Tribe Gear card at top of Crafting tab
	var armory_panel: PanelContainer = _card(self, Look.GOLD)
	var avb := VBoxContainer.new()
	avb.add_theme_constant_override("separation", 8)
	armory_panel.add_child(avb)

	var armory_hdr := Look.label("Leader Armory & Tribe Gear", &"SectionTitle", 19)
	avb.add_child(armory_hdr)

	var leader: Node = GameState.get_faction_leader(0)
	if is_instance_valid(leader) and not bool(leader.get("is_dead")):
		var raw_wid: String = str(leader.get_equipped_weapon_id()) if leader.has_method("get_equipped_weapon_id") else str(leader.get("equipped_weapon_id"))
		var raw_aid: String = str(leader.get_equipped_armor_id()) if leader.has_method("get_equipped_armor_id") else str(leader.get("equipped_armor_id"))
		var wdef: Dictionary = GameData.resolve_weapon_def(raw_wid, int(leader.get("role")), int(leader.get("warrior_class")), true, false)
		var adef: Dictionary = GameData.resolve_armor_def(raw_aid, bool(leader.get("has_armor")), int(leader.get("weapon_tier")))
		var cur_wid: String = str(wdef.get("id", ""))
		var cur_aid: String = str(adef.get("id", "NONE"))
		var w_name: String = str(wdef.get("name", "Unarmed / Tool")) if not wdef.is_empty() else "Unarmed / Tool"
		var a_name: String = str(adef.get("name", "Unarmored"))

		var summary_lbl := Label.new()
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_lbl.text = "%s  ·  DMG %.0f  ·  Reach %.1fm  ·  ARM %.0f\nEquipped: %s  |  %s" % [
			str(leader.get("unit_name")),
			float(leader.get("attack_damage")),
			float(leader.get("attack_range")),
			float(leader.get("armor")),
			w_name,
			a_name,
		]
		avb.add_child(summary_lbl)

		var gear_row := HBoxContainer.new()
		gear_row.add_theme_constant_override("separation", 12)
		avb.add_child(gear_row)

		var w_box := HBoxContainer.new()
		w_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_box.add_theme_constant_override("separation", 6)
		gear_row.add_child(w_box)
		w_box.add_child(Look.label("Weapon:", &"QuietLabel", 14))

		var lw_opt := OptionButton.new()
		lw_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lw_opt.fit_to_longest_item = false
		lw_opt.clip_text = true
		if not wdef.is_empty():
			lw_opt.add_item("%s [Equipped]" % w_name)
			lw_opt.set_item_metadata(0, cur_wid)
		else:
			lw_opt.add_item("Unarmed / Tool [Equipped]")
			lw_opt.set_item_metadata(0, "")
		for wid in GameData.WEAPON_DEFS.keys():
			var w_key: String = str(wid)
			if w_key == cur_wid:
				continue
			var cand_w: Dictionary = GameData.WEAPON_DEFS[w_key]
			var s_key: String = str(cand_w.get("stock_key", ""))
			var cnt: int = int(stock.get(s_key, 0))
			var min_t: int = int(cand_w.get("min_tier", 1))
			if cnt > 0 and cur_tier >= min_t:
				var idx: int = lw_opt.item_count
				lw_opt.add_item("%s (%d)" % [str(cand_w.get("name", w_key)), cnt])
				lw_opt.set_item_metadata(idx, w_key)
		lw_opt.selected = 0
		lw_opt.disabled = (lw_opt.item_count <= 1)
		lw_opt.item_selected.connect(func(idx: int):
			lw_opt.release_focus()
			var picked_wid: String = str(lw_opt.get_item_metadata(idx))
			if not picked_wid.is_empty() and is_instance_valid(leader):
				GameState.equip_unit_weapon(leader, picked_wid)
			refresh()
		)
		tag(lw_opt, "leader-weapon")
		w_box.add_child(lw_opt)

		var a_box := HBoxContainer.new()
		a_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a_box.add_theme_constant_override("separation", 6)
		gear_row.add_child(a_box)
		a_box.add_child(Look.label("Armor:", &"QuietLabel", 14))

		var la_opt := OptionButton.new()
		la_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		la_opt.fit_to_longest_item = false
		la_opt.clip_text = true
		la_opt.add_item("%s [Equipped]" % a_name)
		la_opt.set_item_metadata(0, cur_aid)
		if cur_aid != "NONE":
			var none_idx: int = la_opt.item_count
			la_opt.add_item(str(GameData.ARMOR_DEFS["NONE"]["name"]))
			la_opt.set_item_metadata(none_idx, "NONE")
		for aid in GameData.ARMOR_DEFS.keys():
			var a_key: String = str(aid)
			if a_key == "NONE" or a_key == cur_aid:
				continue
			var cand_a: Dictionary = GameData.ARMOR_DEFS[a_key]
			var s_key: String = str(cand_a.get("stock_key", ""))
			var cnt: int = int(stock.get(s_key, 0))
			var min_t: int = int(cand_a.get("min_tier", 1))
			if not s_key.is_empty() and cnt > 0 and cur_tier >= min_t:
				var idx: int = la_opt.item_count
				la_opt.add_item("%s (%d)" % [str(cand_a.get("name", a_key)), cnt])
				la_opt.set_item_metadata(idx, a_key)
		la_opt.selected = 0
		la_opt.disabled = (la_opt.item_count <= 1)
		la_opt.item_selected.connect(func(idx: int):
			la_opt.release_focus()
			var picked_aid: String = str(la_opt.get_item_metadata(idx))
			if is_instance_valid(leader):
				GameState.equip_unit_armor(leader, picked_aid)
			refresh()
		)
		tag(la_opt, "leader-armor")
		a_box.add_child(la_opt)
	else:
		var no_ldr := Look.label("No active Tribal Leader.", &"QuietLabel", 14)
		avb.add_child(no_ldr)

	# 2. Gear Quality, Recipes (Weapons & Armor), Crafting Queue & Enlighten Captive
	var craft_panel: PanelContainer = _card(self)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 8)
	craft_panel.add_child(cvb)

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
			upg_btn.release_focus()
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

	var weapon_keys: Array[String] = []
	var armor_keys: Array[String] = []
	for item_k in GameData.CRAFT_RECIPES.keys():
		var ik_str: String = str(item_k)
		var rec: Dictionary = GameData.CRAFT_RECIPES[ik_str]
		if rec.has("armor_id"):
			armor_keys.append(ik_str)
		else:
			weapon_keys.append(ik_str)

	for group in [["Weapons", weapon_keys], ["Armor", armor_keys]]:
		var group_name: String = str(group[0])
		var group_keys: Array = group[1]
		if group_keys.is_empty():
			continue
		var grp_lbl := Look.label(group_name, &"SectionTitle", 16)
		cvb.add_child(grp_lbl)

		var craft_grid := GridContainer.new()
		craft_grid.columns = 2
		craft_grid.add_theme_constant_override("h_separation", 12)
		craft_grid.add_theme_constant_override("v_separation", 6)
		cvb.add_child(craft_grid)

		for ik in group_keys:
			var item_key: String = str(ik)
			var rec: Dictionary = GameData.CRAFT_RECIPES[item_key]
			var min_tier: int = int(rec.get("min_tier", 1))
			var stock_cnt: int = int(stock.get(item_key, 0))
			var bonus_txt: String = _format_recipe_bonus(rec)

			var r_parts := []
			var costs: Dictionary = rec.get("costs", {})
			for ck in costs.keys():
				r_parts.append("%d%s" % [int(costs[ck]), str(ck).substr(0, 1).to_upper()])

			var row_box := HBoxContainer.new()
			row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_box.add_theme_constant_override("separation", 8)
			craft_grid.add_child(row_box)

			var info_lbl := Label.new()
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info_lbl.text = "%s (T%d · Stock: %d)\n%s" % [str(rec["name"]), min_tier, stock_cnt, bonus_txt]
			if cur_tier < min_tier:
				info_lbl.add_theme_color_override("font_color", Look.MUTED)
			row_box.add_child(info_lbl)

			var cbtn := Button.new()
			cbtn.text = "Craft · %s" % " ".join(r_parts)
			cbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cbtn.disabled = (cur_tier < min_tier)
			if cur_tier < min_tier:
				cbtn.tooltip_text = "Requires Stone Age Gear Tier %d" % min_tier
			cbtn.pressed.connect(func():
				cbtn.release_focus()
				var fc = GameState.faction_controllers.get(0)
				if fc != null:
					fc.queue_craft(item_key)
					refresh()
			)
			tag(cbtn, "craft:" + item_key)
			row_box.add_child(cbtn)

	_queue_label = Label.new()
	var q_arr: Array = f0.get("craft_queue", [])
	_queue_label.text = _format_queue_text(q_arr)
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		enl_btn.release_focus()
		if GameState.combat_command_system != null:
			GameState.combat_command_system.enlighten_captured_caveman()
			refresh()
	)
	tag(enl_btn, "enlighten")
	cap_row.add_child(enl_btn)


func _format_recipe_bonus(rec: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if rec.has("weapon_id"):
		var wid: String = str(rec.get("weapon_id", ""))
		var wdef: Dictionary = GameData.WEAPON_DEFS.get(wid, {})
		if not wdef.is_empty():
			parts.append("Ranged" if bool(wdef.get("is_ranged", false)) else "Melee")
			parts.append("Dmg x%.2f" % float(wdef.get("dmg_mult", 1.0)))
			var rng: float = float(wdef.get("range_override", 0.0))
			if rng > 0.0:
				parts.append("%s %.1fm" % ["Range" if bool(wdef.get("is_ranged", false)) else "Reach", rng])
			var arm_b: float = float(wdef.get("armor_bonus", 0.0))
			if arm_b > 0.0:
				parts.append("+%.0f ARM" % arm_b)
			var cdm: float = float(wdef.get("cooldown_mult", 1.0))
			if not is_equal_approx(cdm, 1.0):
				parts.append("CD x%.2f" % cdm)
	elif rec.has("armor_id"):
		var aid: String = str(rec.get("armor_id", ""))
		var adef: Dictionary = GameData.ARMOR_DEFS.get(aid, {})
		if not adef.is_empty():
			var arm_b: float = float(adef.get("armor_bonus", 0.0))
			if arm_b > 0.0:
				parts.append("+%.0f ARM" % arm_b)
			var hp_b: float = float(adef.get("hp_bonus", 0.0))
			if hp_b > 0.0:
				parts.append("+%.0f HP" % hp_b)
			var mm: float = float(adef.get("move_mult", 1.0))
			if not is_equal_approx(mm, 1.0):
				parts.append("Spd x%.2f" % mm)
	return ", ".join(parts) if not parts.is_empty() else "Tribal Gear"


func _format_queue_text(q_arr: Array) -> String:
	if q_arr.is_empty():
		return "Crafting Queue: 0 item(s) pending"
	var names: PackedStringArray = PackedStringArray()
	for i in range(mini(q_arr.size(), 4)):
		var k: String = str(q_arr[i])
		var rec: Dictionary = GameData.CRAFT_RECIPES.get(k, {})
		names.append(str(rec.get("name", k)))
	var suffix: String = ", ..." if q_arr.size() > 4 else ""
	return "Crafting Queue: %d item(s) pending (%s%s)" % [q_arr.size(), ", ".join(names), suffix]


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
				b.release_focus()
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

	var hire_btn := Button.new()
	hire_btn.pressed.connect(func():
		hire_btn.release_focus()
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
			insp_btn.release_focus()
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
				role_opt.release_focus()
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
					cls_opt.release_focus()
					var cid: int = cls_opt.get_item_id(idx)
					GameState.assign_player_role(unit_ref, GameData.Role.WARRIOR, cid)
					refresh()
				)
				tag(cls_opt, "unit-class:%d" % unit_ref.unit_id)
				u_row.add_child(cls_opt)


func _get_unit_recovery(u: Node) -> float:
	if u == null or not is_instance_valid(u):
		return 0.0
	var rec_v: Variant = u.get("arena_recovery_remaining")
	return maxf(0.0, float(rec_v)) if rec_v != null else 0.0


func _is_unit_ooc(u: Node) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	if u.has_method("is_out_of_commission") and bool(u.is_out_of_commission()):
		return true
	return _get_unit_recovery(u) > 0.0


func _unit_arena_badges(u: Node) -> String:
	var badges := ""
	if u.get("is_arena_champion") == true:
		badges += " [Arena Champion]"
	var rec_rem: float = _get_unit_recovery(u)
	if _is_unit_ooc(u):
		if rec_rem > 0.0:
			badges += " [Out of Commission · %ds]" % maxi(1, int(ceilf(rec_rem)))
		else:
			badges += " [Out of Commission]"
	return badges


func _populate_arena_card(f0: Dictionary) -> void:
	var status: Dictionary = GameState.get_arena_status()
	if not bool(status.get("has_arena", false)):
		var card := _card(self, Look.GOLD)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)

		var hdr := Look.label("Blood-Pit Arena", &"SectionTitle", 20)
		vb.add_child(hdr)

		var lock_reason: String = GameState.get_building_lock_reason(0, "ARENA_PIT")
		var desc := Look.label(
			"Unlock the Blood-Pit Arena at Tribal Level 3 + Barracks Drillmasters ([K] Perks) and build it in [B] Build (Defences) to host Chieftain Trials and Warband Exhibitions.",
			&"QuietLabel",
			14
		)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc)

		var status_txt := lock_reason if not lock_reason.is_empty() else "Unlocked — Ready to construct in [B] Build (24 Wood · 20 Stone · 8 Bone)."
		var status_lbl := Look.label(status_txt, &"QuietLabel", 14)
		status_lbl.add_theme_color_override("font_color", Look.GOLD if lock_reason.is_empty() else Look.MUTED)
		status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(status_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 10)
		vb.add_child(btn_row)

		var perks_btn := Button.new()
		perks_btn.text = "Open Perks [K]"
		if not lock_reason.is_empty():
			perks_btn.theme_type_variation = &"PrimaryButton"
		perks_btn.pressed.connect(func():
			perks_btn.release_focus()
			navigate_requested.emit("PERKS")
		)
		tag(perks_btn, "arena-open-perks")
		btn_row.add_child(perks_btn)

		var build_btn := Button.new()
		build_btn.text = "Open Build [B]"
		if lock_reason.is_empty():
			build_btn.theme_type_variation = &"PrimaryButton"
		build_btn.pressed.connect(func():
			build_btn.release_focus()
			navigate_requested.emit("BUILD")
		)
		tag(build_btn, "arena-open-build")
		btn_row.add_child(build_btn)
		return

	if _arena_mode != ArenaRules.MODE_CHIEFTAIN and _arena_mode != ArenaRules.MODE_EXHIBITION:
		_arena_mode = ArenaRules.MODE_CHIEFTAIN
	if not ArenaRules.BOUT_TIERS.has(_arena_tier):
		_arena_tier = 1
	_prune_arena_fighters()
	_arena_state = _arena_signature()

	var is_active: bool = bool(status.get("active", false))
	var tier_data: Dictionary = ArenaRules.BOUT_TIERS[_arena_tier]
	var max_tier_fighters: int = int(tier_data.get("max_fighters", 4))
	var guard_limit: int = mini(2, max_tier_fighters - 1)
	var exh_limit: int = mini(4, max_tier_fighters)
	var max_allowed: int = guard_limit if _arena_mode == ArenaRules.MODE_CHIEFTAIN else exh_limit

	# 1. Mode & Bout Tier Card
	var setup_card := _card(self, Look.EDGE)
	var setup_vb := VBoxContainer.new()
	setup_vb.add_theme_constant_override("separation", 8)
	setup_card.add_child(setup_vb)

	var setup_hdr := Look.label("Blood-Pit Arena · Bout Setup", &"SectionTitle", 19)
	setup_vb.add_child(setup_hdr)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	setup_vb.add_child(mode_row)
	mode_row.add_child(Look.label("Mode:", &"QuietLabel", 14))

	for mode_spec in [
		[ArenaRules.MODE_CHIEFTAIN, "Chieftain's Trial (Join Fight)"],
		[ArenaRules.MODE_EXHIBITION, "Warband Exhibition (Spectate Fighters)"],
	]:
		var m_key: String = str(mode_spec[0])
		var m_btn := Button.new()
		m_btn.text = str(mode_spec[1])
		m_btn.toggle_mode = true
		m_btn.button_pressed = (_arena_mode == m_key)
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.pressed.connect(func():
			m_btn.release_focus()
			_arena_mode = m_key
			_prune_arena_fighters()
			refresh()
		)
		tag(m_btn, "arena-mode:" + m_key)
		mode_row.add_child(m_btn)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	setup_vb.add_child(tier_row)
	tier_row.add_child(Look.label("Bout Tier:", &"QuietLabel", 14))

	var romans := {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V"}
	var tier_opt := OptionButton.new()
	tier_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_opt.fit_to_longest_item = false
	tier_opt.clip_text = true
	for tid_v in [1, 2, 3, 4, 5]:
		var tid: int = int(tid_v)
		var t_info: Dictionary = ArenaRules.BOUT_TIERS[tid]
		var idx: int = tier_opt.item_count
		tier_opt.add_item("Tier %s · %s" % [str(romans.get(tid, str(tid))), str(t_info.get("name", ""))], tid)
		tier_opt.set_item_metadata(idx, tid)
	var sel_idx: int = tier_opt.get_item_index(_arena_tier)
	if sel_idx >= 0:
		tier_opt.selected = sel_idx
	tier_opt.item_selected.connect(func(idx: int):
		tier_opt.release_focus()
		_arena_tier = int(tier_opt.get_item_id(idx))
		_prune_arena_fighters()
		refresh()
	)
	tag(tier_opt, "arena-tier")
	tier_row.add_child(tier_opt)

	var preview_lbl := Look.label(_format_arena_tier_preview(tier_data, _arena_mode), &"QuietLabel", 13)
	preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_vb.add_child(preview_lbl)

	# 2. Action Row & Live Bout Status
	var act_card := _card(self, Look.GOLD if is_active else Look.EDGE)
	var act_vb := VBoxContainer.new()
	act_vb.add_theme_constant_override("separation", 8)
	act_card.add_child(act_vb)

	var check: Dictionary = ArenaRules.can_start_bout(GameState, _arena_mode, _arena_tier, _arena_fighter_ids)
	var can_start: bool = bool(check.get("ok", false))
	var reason: String = str(check.get("reason", ""))

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	act_vb.add_child(act_row)

	_arena_status_lbl = Label.new()
	_arena_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	act_row.add_child(_arena_status_lbl)

	_arena_start_btn = Button.new()
	_arena_start_btn.text = "Start Arena Bout"
	_arena_start_btn.theme_type_variation = &"PrimaryButton"
	_arena_start_btn.disabled = not can_start
	_arena_start_btn.pressed.connect(func():
		_arena_start_btn.release_focus()
		var chosen_mode: String = _arena_mode
		if GameState.start_arena_bout(chosen_mode, _arena_tier, _arena_fighter_ids):
			if chosen_mode == ArenaRules.MODE_CHIEFTAIN:
				close_requested.emit()
			else:
				refresh()
		else:
			refresh()
	)
	tag(_arena_start_btn, "arena-start")
	act_row.add_child(_arena_start_btn)

	if is_active:
		var live_row := HBoxContainer.new()
		live_row.add_theme_constant_override("separation", 10)
		act_vb.add_child(live_row)

		_arena_live_lbl = Look.label("", &"SectionTitle", 16)
		_arena_live_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_arena_live_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		live_row.add_child(_arena_live_lbl)

		var pc: Node = GameState.player_controller
		var spectating: bool = is_instance_valid(pc) and pc.get("is_spectating_arena") == true
		_arena_spectate_btn = Button.new()
		_arena_spectate_btn.toggle_mode = true
		_arena_spectate_btn.button_pressed = spectating
		_arena_spectate_btn.text = "Stop Spectating" if spectating else "Spectate Ring"
		_arena_spectate_btn.pressed.connect(func():
			_arena_spectate_btn.release_focus()
			var cur_pc: Node = GameState.player_controller
			if is_instance_valid(cur_pc) and cur_pc.has_method("set_arena_spectate"):
				var cur_status: Dictionary = GameState.get_arena_status()
				var cur_spec: bool = cur_pc.get("is_spectating_arena") == true
				var center: Vector3 = cur_status.get("arena_pos", Vector3.ZERO)
				cur_pc.set_arena_spectate(not cur_spec, center)
			refresh()
		)
		tag(_arena_spectate_btn, "arena-spectate")
		live_row.add_child(_arena_spectate_btn)

		_arena_forfeit_btn = Button.new()
		_arena_forfeit_btn.text = "Forfeit Bout"
		_arena_forfeit_btn.pressed.connect(func():
			_arena_forfeit_btn.release_focus()
			GameState.forfeit_arena_bout()
			refresh()
		)
		tag(_arena_forfeit_btn, "arena-forfeit")
		live_row.add_child(_arena_forfeit_btn)

	# 3. Fighter Selection List
	var roster_card := _card(self, Look.EDGE)
	var roster_vb := VBoxContainer.new()
	roster_vb.add_theme_constant_override("separation", 6)
	roster_card.add_child(roster_vb)

	var f_hdr_txt: String = (
		"Chieftain & Optional Guards (%d/%d selected)" % [_arena_fighter_ids.size(), guard_limit]
		if _arena_mode == ArenaRules.MODE_CHIEFTAIN
		else "Eligible Warriors & Trainees (%d/%d selected)" % [_arena_fighter_ids.size(), exh_limit]
	)
	roster_vb.add_child(Look.label(f_hdr_txt, &"SectionTitle", 17))

	if _arena_mode == ArenaRules.MODE_CHIEFTAIN:
		var leader: Node = GameState.get_faction_leader(0)
		_arena_leader_lbl = Label.new()
		_arena_leader_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if is_instance_valid(leader) and not bool(leader.get("is_dead")):
			_arena_leader_lbl.text = _format_arena_fighter_line(leader, true)
			if _is_unit_ooc(leader):
				_arena_leader_lbl.add_theme_color_override("font_color", Look.DANGER)
			else:
				_arena_leader_lbl.add_theme_color_override("font_color", Look.GOLD)
		else:
			_arena_leader_lbl.text = "No living Chieftain available."
			_arena_leader_lbl.add_theme_color_override("font_color", Look.DANGER)
		roster_vb.add_child(_arena_leader_lbl)

	var eligible: Array = _get_eligible_arena_fighters()
	if eligible.is_empty():
		var empty_lbl := Look.label("No eligible adult Warriors or Trainees available. Assign Warriors or Trainees in Roster or Workforce.", &"QuietLabel", 13)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		roster_vb.add_child(empty_lbl)
	else:
		for u in eligible:
			var uid: int = int(u.get("unit_id"))
			var f_row := HBoxContainer.new()
			f_row.add_theme_constant_override("separation", 10)
			roster_vb.add_child(f_row)

			var info_lbl := Label.new()
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info_lbl.text = _format_arena_fighter_line(u, false)
			f_row.add_child(info_lbl)

			var is_ooc: bool = _is_unit_ooc(u)
			var rec_rem: float = _get_unit_recovery(u)
			var is_sel: bool = (not is_ooc) and _arena_fighter_ids.has(uid)
			var f_btn := Button.new()
			f_btn.toggle_mode = true
			f_btn.button_pressed = is_sel
			if is_ooc:
				f_btn.text = "Out of Commission (%ds)" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else "Out of Commission"
				f_btn.disabled = true
			else:
				f_btn.text = "Selected" if is_sel else "Select"
				f_btn.disabled = (not is_sel) and (_arena_fighter_ids.size() >= max_allowed)
				f_btn.pressed.connect(func():
					f_btn.release_focus()
					if _arena_fighter_ids.has(uid):
						_arena_fighter_ids.erase(uid)
					elif _arena_fighter_ids.size() < max_allowed:
						_arena_fighter_ids.append(uid)
					refresh()
				)
			tag(f_btn, "arena-fighter:%d" % uid)
			f_row.add_child(f_btn)
			_arena_fighter_rows[uid] = {"label": info_lbl, "button": f_btn, "unit": u, "max_allowed": max_allowed}

	_update_arena_live_labels(status, check)


func _get_eligible_arena_fighters() -> Array:
	var out: Array = []
	for u in GameState.get_faction_units(0, true):
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		if int(u.get("faction_id")) != 0 or bool(u.get("is_leader")):
			continue
		if bool(u.get("is_child")) or bool(u.get("is_dead")) or bool(u.get("is_wounded")) or bool(u.get("is_revolting")):
			continue
		var ur: int = int(u.get("role"))
		if ur != GameData.Role.WARRIOR and ur != GameData.Role.TRAINEE:
			continue
		out.append(u)
	return out


func _prune_arena_fighters() -> void:
	var tier_data: Dictionary = ArenaRules.BOUT_TIERS.get(_arena_tier, ArenaRules.BOUT_TIERS[1])
	var max_tier_fighters: int = int(tier_data.get("max_fighters", 4))
	var max_allowed: int = mini(2, max_tier_fighters - 1) if _arena_mode == ArenaRules.MODE_CHIEFTAIN else mini(4, max_tier_fighters)
	var valid_by_id := {}
	for u in _get_eligible_arena_fighters():
		if not _is_unit_ooc(u):
			valid_by_id[int(u.get("unit_id"))] = true
	var kept: Array[int] = []
	for uid in _arena_fighter_ids:
		if valid_by_id.has(uid) and not kept.has(uid) and kept.size() < max_allowed:
			kept.append(uid)
	_arena_fighter_ids = kept


func _format_arena_fighter_line(u: Node, is_chieftain: bool) -> String:
	var uname: String = str(u.get("unit_name"))
	var ur: int = int(u.get("role"))
	var role_lbl: String = "Chieftain" if is_chieftain else (str(GameData.WARRIOR_CLASS_NAMES.get(int(u.get("warrior_class")), "Warrior")) if ur == GameData.Role.WARRIOR else "Trainee")
	var rank_val: int = maxi(int(u.get("melee_rank")), int(u.get("ranged_rank")))
	var raw_wid: String = str(u.get_equipped_weapon_id()) if u.has_method("get_equipped_weapon_id") else str(u.get("equipped_weapon_id"))
	var raw_aid: String = str(u.get_equipped_armor_id()) if u.has_method("get_equipped_armor_id") else str(u.get("equipped_armor_id"))
	var wdef: Dictionary = GameData.resolve_weapon_def(raw_wid, ur, int(u.get("warrior_class")), is_chieftain, false)
	var adef: Dictionary = GameData.resolve_armor_def(raw_aid, bool(u.get("has_armor")), int(u.get("weapon_tier")))
	var w_name: String = str(wdef.get("name", "Unarmed")) if not wdef.is_empty() else "Unarmed"
	var a_name: String = str(adef.get("name", "Unarmored"))
	var badges := ""
	if u.get("is_arena_champion") == true:
		badges += " [Champion]"
	var rec_rem: float = _get_unit_recovery(u)
	if _is_unit_ooc(u):
		badges += " [Out of Commission · %ds]" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else " [Out of Commission]"
	var prefix: String = "Chieftain (Auto-Entered): " if is_chieftain else ""
	return "%s%s (%s · Rank %d)%s\n%s  |  %s  ·  %.0f/%.0f HP" % [prefix, uname, role_lbl, rank_val, badges, w_name, a_name, float(u.get("hp")), float(u.get("max_hp"))]


func _format_arena_tier_preview(tier_data: Dictionary, mode: String) -> String:
	var min_f: int = int(tier_data.get("min_fighters", 1))
	var max_f: int = int(tier_data.get("max_fighters", 4))
	var fighter_cap_str: String = (
		"Chieftain + up to %d guard%s (max %d)" % [mini(2, max_f - 1), "" if mini(2, max_f - 1) == 1 else "s", max_f]
		if mode == ArenaRules.MODE_CHIEFTAIN
		else "%d–%d Warriors / Trainees" % [min_f, mini(4, max_f)]
	)
	var rewards: Dictionary = tier_data.get("rewards", {})
	var reward_parts := PackedStringArray()
	var res_dict: Dictionary = rewards.get("resources", {})
	for rk in res_dict.keys():
		reward_parts.append("%d %s" % [int(res_dict[rk]), str(rk).capitalize()])
	var xp_amt: int = int(rewards.get("xp", 0))
	if xp_amt > 0:
		reward_parts.append("+%d Tribal XP" % xp_amt)
	var txp_amt: int = int(rewards.get("train_xp", 0))
	if txp_amt > 0:
		reward_parts.append("+%d Training XP" % txp_amt)
	var gear_list: Array = rewards.get("gear", [])
	for gk in gear_list:
		var g_key: String = str(gk)
		var g_name: String = str(GameData.CRAFT_RECIPES.get(g_key, {}).get("name", g_key.capitalize()))
		reward_parts.append("Gear: %s" % g_name)
	if bool(rewards.get("champion", false)):
		reward_parts.append("[Arena Champion] (+15 HP, +10% DMG)")
	return "Opponents: %s\nAllowed Fighters: %s\nVictory Rewards: %s" % [
		str(tier_data.get("summary", "")),
		fighter_cap_str,
		", ".join(reward_parts),
	]


func _update_arena_live_labels(status: Dictionary, check: Dictionary) -> void:
	var is_active: bool = bool(status.get("active", false))
	var cd: float = float(status.get("cooldown", 0.0))
	var can_start: bool = bool(check.get("ok", false))
	var reason: String = str(check.get("reason", ""))
	if is_instance_valid(_arena_status_lbl):
		if is_active:
			_arena_status_lbl.text = "Bout in progress."
			_arena_status_lbl.add_theme_color_override("font_color", Look.GOLD)
		elif cd > 0.0:
			_arena_status_lbl.text = "Cooldown: %ds" % maxi(1, int(ceilf(cd)))
			_arena_status_lbl.add_theme_color_override("font_color", Look.DANGER)
		elif can_start:
			_arena_status_lbl.text = "Ready to fight."
			_arena_status_lbl.add_theme_color_override("font_color", Look.MOSS)
		else:
			_arena_status_lbl.text = reason
			_arena_status_lbl.add_theme_color_override("font_color", Look.DANGER)
	if is_instance_valid(_arena_start_btn):
		_arena_start_btn.disabled = not can_start
	if is_instance_valid(_arena_live_lbl):
		var opp_left: int = int(status.get("opponent_count", 0))
		var elapsed_s: int = int(floorf(float(status.get("elapsed", 0.0))))
		_arena_live_lbl.text = "Bout Active · Opponents Left: %d · Elapsed: %ds" % [opp_left, elapsed_s]
	if is_instance_valid(_arena_spectate_btn):
		var pc: Node = GameState.player_controller
		var spectating: bool = is_instance_valid(pc) and pc.get("is_spectating_arena") == true
		_arena_spectate_btn.set_pressed_no_signal(spectating)
		_arena_spectate_btn.text = "Stop Spectating" if spectating else "Spectate Ring"
	if is_instance_valid(_arena_leader_lbl) and _arena_mode == ArenaRules.MODE_CHIEFTAIN:
		var leader: Node = GameState.get_faction_leader(0)
		if is_instance_valid(leader) and not bool(leader.get("is_dead")):
			_arena_leader_lbl.text = _format_arena_fighter_line(leader, true)
	for uid in _arena_fighter_rows.keys():
		var entry: Dictionary = _arena_fighter_rows[uid]
		var lbl: Label = entry["label"]
		var btn: Button = entry["button"]
		var u: Node = entry["unit"]
		if is_instance_valid(u) and not bool(u.get("is_dead")):
			if is_instance_valid(lbl):
				lbl.text = _format_arena_fighter_line(u, false)
			if is_instance_valid(btn) and _is_unit_ooc(u):
				var rec_rem: float = _get_unit_recovery(u)
				btn.text = "Out of Commission (%ds)" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else "Out of Commission"
				btn.disabled = true


func format_colonist_line(u: Node) -> String:
	var g_str := "M" if int(u.get("gender")) == GameData.Gender.MALE else "F"
	var l_str: String = GameData.LINEAGE_DATA[int(u.get("lineage"))]["short_name"]
	var age_str := " [Child]" if bool(u.get("is_child")) else (" [LEADER]" if bool(u.get("is_leader")) else "")
	var arena_badges := _unit_arena_badges(u)
	var gear_str := "Melee %.0f   ·   Ranged %.0f   ·   Morale %.0f%%" % [float(u.get("close_quarters_damage")), float(u.get("ranged_attack_damage")), float(u.get("morale"))]
	return "%s  ·  %s, %s%s%s     |     %.0f/%.0f HP\n%s" % [str(u.get("unit_name")), g_str, l_str, age_str, arena_badges, float(u.get("hp")), float(u.get("max_hp")), gear_str]


func _has_open_popup() -> bool:
	for ctrl in find_children("*", "OptionButton", true, false):
		var opt := ctrl as OptionButton
		if opt != null:
			var popup: PopupMenu = opt.get_popup()
			if popup != null and popup.visible:
				return true
	return false


func update_live_values() -> void:
	if is_instance_valid(_farm_label):
		_update_farm_status()
	if not _has_open_popup():
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
		if _section == "Arena" and _arena_signature() != _arena_state:
			refresh()
			return
	if is_instance_valid(_queue_label) and GameState.factions.has(0):
		var q_arr: Array = GameState.factions[0].get("craft_queue", [])
		_queue_label.text = _format_queue_text(q_arr)
	for uid in _roster_rows.keys():
		var entry: Dictionary = _roster_rows[uid]
		var lbl: Label = entry["label"]
		var u: Node = entry["unit"]
		if is_instance_valid(lbl) and is_instance_valid(u) and not u.get("is_dead"):
			lbl.text = format_colonist_line(u)
	if _section == "Arena" and bool(GameState.get_arena_status().get("has_arena", false)):
		var status: Dictionary = GameState.get_arena_status()
		var check: Dictionary = ArenaRules.can_start_bout(GameState, _arena_mode, _arena_tier, _arena_fighter_ids)
		_update_arena_live_labels(status, check)


func _roster_signature(units: Array) -> Array[Array]:
	var signature: Array[Array] = []
	for unit in units:
		signature.append([
			unit.unit_id,
			unit.role,
			unit.warrior_class,
			GameState.can_assign_player_role(unit),
			unit.get("is_arena_champion") == true,
			_is_unit_ooc(unit),
		])
	return signature


func _arena_signature() -> Array:
	var status: Dictionary = GameState.get_arena_status()
	var has_arena: bool = bool(status.get("has_arena", false))
	var pc: Node = GameState.player_controller
	var spectating: bool = is_instance_valid(pc) and pc.get("is_spectating_arena") == true
	var leader: Node = GameState.get_faction_leader(0)
	var ldr_id: int = int(leader.get("unit_id")) if is_instance_valid(leader) else -1
	var ldr_ooc: bool = is_instance_valid(leader) and _is_unit_ooc(leader)
	var sig: Array = [
		has_arena,
		GameState.get_building_lock_reason(0, "ARENA_PIT") if not has_arena else "",
		bool(status.get("active", false)),
		float(status.get("cooldown", 0.0)) > 0.0,
		spectating,
		ldr_id,
		ldr_ooc,
	]
	if has_arena:
		for u in _get_eligible_arena_fighters():
			sig.append([
				int(u.get("unit_id")),
				int(u.get("role")),
				int(u.get("warrior_class")),
				u.get("is_arena_champion") == true,
				_is_unit_ooc(u),
			])
	return sig


func _craft_signature() -> Array:
	if not GameState.factions.has(0):
		return []
	var f0: Dictionary = GameState.factions[0]
	var stock: Dictionary = f0.get("stockpile", {})
	var leader: Node = GameState.get_faction_leader(0)
	var ldr_id: int = int(leader.get("unit_id")) if is_instance_valid(leader) else -1
	var ldr_w: String = ""
	var ldr_a: String = ""
	if is_instance_valid(leader):
		ldr_w = str(leader.get_equipped_weapon_id()) if leader.has_method("get_equipped_weapon_id") else str(leader.get("equipped_weapon_id"))
		ldr_a = str(leader.get_equipped_armor_id()) if leader.has_method("get_equipped_armor_id") else str(leader.get("equipped_armor_id"))
	var sig: Array = [
		int(f0.get("captured_cavemen", 0)),
		int(f0.get("tech_tier", 1)),
		GameState.has_building(0, "CRAFTING_PIT", true),
		ldr_id,
		ldr_w,
		ldr_a,
	]
	for item_k in GameData.CRAFT_RECIPES.keys():
		sig.append(int(stock.get(str(item_k), 0)))
	return sig


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

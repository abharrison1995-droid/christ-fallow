extends PanelContainer

const Look = preload("res://scripts/ui/fallow_theme.gd")
const HUDDrawers = preload("res://scripts/ui/hud_drawers.gd")

var _inspected_unit: Node = null
var _insp_title: Label = null
var _insp_status: Label = null
var _insp_hp_bar: ProgressBar = null
var _insp_hp_lbl: Label = null
var _insp_morale_bar: ProgressBar = null
var _insp_morale_lbl: Label = null
var _insp_stats_lbl: Label = null
var _insp_role_opt: OptionButton = null
var _insp_cls_opt: OptionButton = null
var _insp_weapon_row: HBoxContainer = null
var _insp_weapon_opt: OptionButton = null
var _insp_armor_row: HBoxContainer = null
var _insp_armor_opt: OptionButton = null
var _insp_rescue_btn: Button = null
var _scroll: ScrollContainer = null
var _body_vb: VBoxContainer = null
var _hdr: HBoxContainer = null
var _insp_syncing: bool = false
var _weapon_sig: Array = []
var _armor_sig: Array = []


func _ready() -> void:
	hide()
	add_theme_stylebox_override("panel", Look.panel(Color(0.07, 0.06, 0.06, 0.94), Color(0.68, 0.50, 0.24), 14))
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -356.0
	offset_top = 252.0
	offset_right = -20.0
	offset_bottom = 545.0

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	_hdr = HBoxContainer.new()
	vb.add_child(_hdr)

	_insp_title = Look.label("Tribesman", &"SectionTitle", 21)
	_insp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hdr.add_child(_insp_title)

	var x_btn := Button.new()
	x_btn.text = "Close"
	x_btn.pressed.connect(close)
	_hdr.add_child(x_btn)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_scroll)

	_body_vb = VBoxContainer.new()
	_body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vb.add_theme_constant_override("separation", 6)
	_scroll.add_child(_body_vb)

	_insp_status = Label.new()
	_insp_status.text = "Status: Loyal"
	_insp_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body_vb.add_child(_insp_status)

	_insp_hp_lbl = Label.new()
	_insp_hp_lbl.text = "HP: 100 / 100"
	_body_vb.add_child(_insp_hp_lbl)

	_insp_hp_bar = ProgressBar.new()
	_insp_hp_bar.custom_minimum_size = Vector2(0, 16)
	_insp_hp_bar.show_percentage = false
	_body_vb.add_child(_insp_hp_bar)

	_insp_morale_lbl = Label.new()
	_insp_morale_lbl.text = "Morale: 78%"
	_body_vb.add_child(_insp_morale_lbl)

	_insp_morale_bar = ProgressBar.new()
	_insp_morale_bar.custom_minimum_size = Vector2(0, 16)
	_insp_morale_bar.max_value = 100.0
	_insp_morale_bar.show_percentage = false
	_body_vb.add_child(_insp_morale_bar)

	_insp_stats_lbl = Label.new()
	_insp_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body_vb.add_child(_insp_stats_lbl)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	_body_vb.add_child(role_row)

	_insp_role_opt = OptionButton.new()
	_insp_role_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insp_role_opt.fit_to_longest_item = false
	_insp_role_opt.clip_text = true
	HUDDrawers.fill_role_options(_insp_role_opt)
	_insp_role_opt.item_selected.connect(func(idx: int):
		_insp_role_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var rid: int = _insp_role_opt.get_item_id(idx)
		GameState.assign_player_role(_inspected_unit, rid)
		_weapon_sig = []
		_armor_sig = []
		update_live_values()
	)
	role_row.add_child(_insp_role_opt)

	_insp_cls_opt = OptionButton.new()
	_insp_cls_opt.fit_to_longest_item = false
	_insp_cls_opt.clip_text = true
	HUDDrawers.fill_class_options(_insp_cls_opt)
	_insp_cls_opt.item_selected.connect(func(idx: int):
		_insp_cls_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var cid: int = _insp_cls_opt.get_item_id(idx)
		GameState.assign_player_role(_inspected_unit, GameData.Role.WARRIOR, cid)
		_weapon_sig = []
		_armor_sig = []
		update_live_values()
	)
	role_row.add_child(_insp_cls_opt)

	_insp_weapon_row = HBoxContainer.new()
	_insp_weapon_row.add_theme_constant_override("separation", 6)
	_body_vb.add_child(_insp_weapon_row)

	var w_lbl := Look.label("Weapon", &"QuietLabel", 14)
	w_lbl.custom_minimum_size = Vector2(58, 0)
	_insp_weapon_row.add_child(w_lbl)

	_insp_weapon_opt = OptionButton.new()
	_insp_weapon_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insp_weapon_opt.fit_to_longest_item = false
	_insp_weapon_opt.clip_text = true
	_insp_weapon_opt.get_popup().popup_hide.connect(_insp_weapon_opt.release_focus)
	_insp_weapon_opt.item_selected.connect(func(idx: int):
		_insp_weapon_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var wid: String = str(_insp_weapon_opt.get_item_metadata(idx))
		if not wid.is_empty():
			GameState.equip_unit_weapon(_inspected_unit, wid)
		_weapon_sig = []
		update_live_values()
	)
	_insp_weapon_row.add_child(_insp_weapon_opt)

	_insp_armor_row = HBoxContainer.new()
	_insp_armor_row.add_theme_constant_override("separation", 6)
	_body_vb.add_child(_insp_armor_row)

	var a_lbl := Look.label("Armor", &"QuietLabel", 14)
	a_lbl.custom_minimum_size = Vector2(58, 0)
	_insp_armor_row.add_child(a_lbl)

	_insp_armor_opt = OptionButton.new()
	_insp_armor_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insp_armor_opt.fit_to_longest_item = false
	_insp_armor_opt.clip_text = true
	_insp_armor_opt.get_popup().popup_hide.connect(_insp_armor_opt.release_focus)
	_insp_armor_opt.item_selected.connect(func(idx: int):
		_insp_armor_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var aid: String = str(_insp_armor_opt.get_item_metadata(idx))
		GameState.equip_unit_armor(_inspected_unit, aid)
		_armor_sig = []
		update_live_values()
	)
	_insp_armor_row.add_child(_insp_armor_opt)

	_insp_rescue_btn = Button.new()
	_insp_rescue_btn.text = "Send to Shaman Shack"
	_insp_rescue_btn.visible = false
	_insp_rescue_btn.pressed.connect(func():
		_insp_rescue_btn.release_focus()
		if _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var shacks: Array = GameState.get_faction_buildings(0, "SHAMAN_SHACK", true)
		if shacks.is_empty():
			GameState.push_log("Build a Shaman's Healing Shack ([B]) first!", "warning")
			return
		_inspected_unit.send_to_shaman_shack((shacks[0] as Node3D).global_position)
		update_live_values()
	)
	_body_vb.add_child(_insp_rescue_btn)


func inspect_unit(u: Node) -> void:
	if u == null or not is_instance_valid(u):
		return
	_inspected_unit = u
	_weapon_sig = []
	_armor_sig = []
	if _scroll != null:
		_scroll.scroll_vertical = 0
	show()
	update_live_values()


func update_live_values() -> void:
	if _inspected_unit == null or not is_instance_valid(_inspected_unit) or _inspected_unit.get("is_dead"):
		close()
		return
	var u: Node = _inspected_unit
	var g_str := "M" if int(u.get("gender")) == GameData.Gender.MALE else "F"
	var eff_lin := GameData.resolve_effective_lineage(int(u.get("lineage")), bool(u.get("is_caveman")))
	var l_str: String = GameData.LINEAGE_DATA[eff_lin]["short_name"]
	var ckey := GameData.resolve_class_key(int(u.get("role")), int(u.get("warrior_class")), bool(u.get("is_leader")), bool(u.get("is_caveman")), false)
	var c_str: String = GameData.CLASS_DEFINITIONS.get(ckey, {}).get("name", "Tribesman")
	_insp_title.text = "%s (%s %s · %s)" % [str(u.get("unit_name")), g_str, l_str, c_str]

	var status_txt := "Loyal (%s)" % GameData.ROLE_NAMES.get(int(u.get("role")), "Worker")
	var status_col := Color(0.70, 0.92, 0.70)
	var rec_v: Variant = u.get("arena_recovery_remaining")
	var rec_rem: float = maxf(0.0, float(rec_v)) if rec_v != null else 0.0
	var is_ooc: bool = (u.has_method("is_out_of_commission") and bool(u.is_out_of_commission())) or rec_rem > 0.0
	var is_champ: bool = (u.get("is_arena_champion") == true)
	if u.get("is_leader"):
		status_txt = "Tribal Leader"
		status_col = Color(1.0, 0.86, 0.35)
	elif u.get("is_wounded"):
		if u.get("is_healing_in_shack"):
			status_txt = "Healing in Shaman Shack"
			status_col = Color(0.45, 0.95, 0.55)
		else:
			var wt: float = float(u.get("wounded_timer"))
			status_txt = "WOUNDED! (%.0fs until defection)" % wt
			status_col = Color(1.0, 0.65, 0.22)
	elif u.get("is_revolting"):
		status_txt = "REVOLTING!"
		status_col = Color(1.0, 0.30, 0.22)
	elif is_ooc:
		status_txt = "[Out of Commission · Recovering (%ds)]" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else "[Out of Commission · Recovering]"
		status_col = Color(0.95, 0.72, 0.35)
	elif int(u.get("role")) == GameData.Role.TRAINEE:
		status_txt = "Training at Barracks"
		status_col = Color(0.65, 0.88, 1.0)
	if is_ooc and (u.get("is_leader") or u.get("is_wounded") or u.get("is_revolting")):
		status_txt += "  [Out of Commission · Recovering (%ds)]" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else "  [Out of Commission · Recovering]"
	if is_champ:
		status_txt += "  [Arena Champion (+15 HP, +10% DMG)]"
	_insp_status.text = "Status: %s" % status_txt
	_insp_status.add_theme_color_override("font_color", status_col)

	var cur_hp: float = float(u.get("hp"))
	var m_hp: float = float(u.get("max_hp"))
	_insp_hp_lbl.text = "HP: %.0f / %.0f (Base %.0f)" % [cur_hp, m_hp, float(u.get("base_hp_stat"))]
	_insp_hp_bar.max_value = maxf(m_hp, 1.0)
	_insp_hp_bar.value = cur_hp

	var mor: float = float(u.get("morale"))
	_insp_morale_lbl.text = "Morale: %.0f%% (Revolt < 15%%)" % mor
	_insp_morale_bar.value = mor
	_insp_morale_bar.modulate = Color(0.95, 0.30, 0.25) if mor < 25.0 else (Color(0.95, 0.80, 0.25) if mor < 50.0 else Color(0.40, 0.90, 0.45))

	var raw_wid: String = str(u.get_equipped_weapon_id()) if u.has_method("get_equipped_weapon_id") else str(u.get("equipped_weapon_id"))
	var raw_aid: String = str(u.get_equipped_armor_id()) if u.has_method("get_equipped_armor_id") else str(u.get("equipped_armor_id"))
	var wdef: Dictionary = GameData.resolve_weapon_def(raw_wid, int(u.get("role")), int(u.get("warrior_class")), bool(u.get("is_leader")), bool(u.get("is_caveman")))
	var adef: Dictionary = GameData.resolve_armor_def(raw_aid, bool(u.get("has_armor")), int(u.get("weapon_tier")))
	var cur_wid: String = str(wdef.get("id", ""))
	var cur_aid: String = str(adef.get("id", "NONE"))
	var w_tier: int = int(u.get("weapon_tier"))
	var w_line: String = "%s%s" % [str(wdef.get("name", "Unarmed / Tool")), _format_weapon_bonus(wdef)] if not wdef.is_empty() else "Unarmed / Tool"
	var a_line: String = "%s%s" % [str(adef.get("name", "Unarmored")), _format_armor_bonus(adef, w_tier)]

	var cq_dmg: float = float(u.get("close_quarters_damage"))
	var rng_dmg: float = float(u.get("ranged_attack_damage"))
	var b_cq: float = float(u.get("base_melee_stat"))
	var b_rng: float = float(u.get("base_ranged_stat"))
	var m_rk: int = int(u.get("melee_rank"))
	var r_rk: int = int(u.get("ranged_rank"))
	var xp: float = float(u.get("training_xp"))
	var arm: float = float(u.get("armor"))
	var spd: float = float(u.get("move_speed"))
	var arena_extra := ""
	if is_champ:
		arena_extra += "\n[Arena Champion (+15 HP, +10% DMG)]"
	if is_ooc:
		arena_extra += "\n[Out of Commission · Recovering (%ds)]" % maxi(1, int(ceilf(rec_rem))) if rec_rem > 0.0 else "\n[Out of Commission · Recovering]"
	_insp_stats_lbl.text = "Weapon: %s\nArmor Gear: %s\nClose-Quarters Dmg: %.1f (Base %.1f, Rank %d/5)\nRanged Dmg: %.1f (Base %.1f, Rank %d/5)\nTraining XP: %.0f / 20\nArmor: %.0f | Speed: %.1f | Gear Tier %d%s" % [
		w_line, a_line, cq_dmg, b_cq, m_rk, rng_dmg, b_rng, r_rk, xp, arm, spd, w_tier, arena_extra
	]

	var editable := GameState.can_assign_player_role(u)
	_insp_syncing = true
	_insp_role_opt.visible = editable
	if editable:
		_insp_role_opt.selected = _insp_role_opt.get_item_index(int(u.get("role")))
		_insp_cls_opt.visible = (int(u.get("role")) == GameData.Role.WARRIOR)
		if _insp_cls_opt.visible:
			_insp_cls_opt.selected = _insp_cls_opt.get_item_index(int(u.get("warrior_class")))
	else:
		_insp_cls_opt.visible = false

	var gear_editable: bool = _is_gear_editable(u)
	_insp_weapon_row.visible = gear_editable
	_insp_armor_row.visible = gear_editable
	if gear_editable:
		_sync_gear_selectors(u, cur_wid, cur_aid)
	_insp_syncing = false
	_insp_rescue_btn.visible = bool(u.get("is_wounded")) and (not bool(u.get("is_healing_in_shack")))
	_fit_panel_bounds()


func _is_gear_editable(u: Node) -> bool:
	return (
		is_instance_valid(u)
		and not u.is_queued_for_deletion()
		and int(u.get("faction_id")) == 0
		and not (bool(u.get("is_child")) or bool(u.get("is_dead")) or bool(u.get("is_wounded")) or bool(u.get("is_revolting")))
	)


func _sync_gear_selectors(u: Node, cur_wid: String, cur_aid: String) -> void:
	var f0: Dictionary = GameState.factions.get(0, {})
	var stock: Dictionary = f0.get("stockpile", {})
	var tech_tier: int = int(f0.get("tech_tier", 1))
	var uid: int = int(u.get("unit_id"))

	var w_popup: PopupMenu = _insp_weapon_opt.get_popup()
	if w_popup == null or not w_popup.visible:
		var next_wsig: Array = [uid, cur_wid, tech_tier]
		for wid in GameData.WEAPON_DEFS.keys():
			var wdef: Dictionary = GameData.WEAPON_DEFS[wid]
			next_wsig.append(int(stock.get(str(wdef.get("stock_key", "")), 0)))
		if next_wsig != _weapon_sig:
			_weapon_sig = next_wsig
			_insp_weapon_opt.clear()
			if cur_wid != "" and GameData.WEAPON_DEFS.has(cur_wid):
				var cur_wdef: Dictionary = GameData.WEAPON_DEFS[cur_wid]
				_insp_weapon_opt.add_item("%s [Equipped]" % str(cur_wdef.get("name", cur_wid)))
				_insp_weapon_opt.set_item_metadata(0, cur_wid)
			else:
				_insp_weapon_opt.add_item("Unarmed / Tool [Equipped]")
				_insp_weapon_opt.set_item_metadata(0, "")
			for wid in GameData.WEAPON_DEFS.keys():
				var w_key: String = str(wid)
				if w_key == cur_wid:
					continue
				var wdef: Dictionary = GameData.WEAPON_DEFS[w_key]
				var s_key: String = str(wdef.get("stock_key", ""))
				var cnt: int = int(stock.get(s_key, 0))
				var min_tier: int = int(wdef.get("min_tier", 1))
				if cnt > 0 and tech_tier >= min_tier:
					var idx: int = _insp_weapon_opt.item_count
					_insp_weapon_opt.add_item("%s (%d)" % [str(wdef.get("name", w_key)), cnt])
					_insp_weapon_opt.set_item_metadata(idx, w_key)
			_insp_weapon_opt.selected = 0
			_insp_weapon_opt.disabled = (_insp_weapon_opt.item_count <= 1)

	var a_popup: PopupMenu = _insp_armor_opt.get_popup()
	if a_popup == null or not a_popup.visible:
		var next_asig: Array = [uid, cur_aid, tech_tier]
		for aid in GameData.ARMOR_DEFS.keys():
			var adef: Dictionary = GameData.ARMOR_DEFS[aid]
			var s_key: String = str(adef.get("stock_key", ""))
			if not s_key.is_empty():
				next_asig.append(int(stock.get(s_key, 0)))
		if next_asig != _armor_sig:
			_armor_sig = next_asig
			_insp_armor_opt.clear()
			var cur_adef: Dictionary = GameData.ARMOR_DEFS.get(cur_aid, GameData.ARMOR_DEFS["NONE"])
			var eff_aid: String = str(cur_adef.get("id", "NONE"))
			_insp_armor_opt.add_item("%s [Equipped]" % str(cur_adef.get("name", "Unarmored")))
			_insp_armor_opt.set_item_metadata(0, eff_aid)
			if eff_aid != "NONE":
				var none_idx: int = _insp_armor_opt.item_count
				_insp_armor_opt.add_item(str(GameData.ARMOR_DEFS["NONE"]["name"]))
				_insp_armor_opt.set_item_metadata(none_idx, "NONE")
			for aid in GameData.ARMOR_DEFS.keys():
				var a_key: String = str(aid)
				if a_key == "NONE" or a_key == eff_aid:
					continue
				var adef: Dictionary = GameData.ARMOR_DEFS[a_key]
				var s_key: String = str(adef.get("stock_key", ""))
				var cnt: int = int(stock.get(s_key, 0))
				var min_tier: int = int(adef.get("min_tier", 1))
				if not s_key.is_empty() and cnt > 0 and tech_tier >= min_tier:
					var idx: int = _insp_armor_opt.item_count
					_insp_armor_opt.add_item("%s (%d)" % [str(adef.get("name", a_key)), cnt])
					_insp_armor_opt.set_item_metadata(idx, a_key)
			_insp_armor_opt.selected = 0
			_insp_armor_opt.disabled = (_insp_armor_opt.item_count <= 1)


func _format_weapon_bonus(wdef: Dictionary) -> String:
	if wdef.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("Ranged" if bool(wdef.get("is_ranged", false)) else "Melee")
	var dm: float = float(wdef.get("dmg_mult", 1.0))
	if not is_equal_approx(dm, 1.0):
		parts.append("Dmg x%.2f" % dm)
	var rng: float = float(wdef.get("range_override", 0.0))
	if rng > 0.0:
		parts.append("%s %.1fm" % ["Range" if bool(wdef.get("is_ranged", false)) else "Reach", rng])
	var arm_b: float = float(wdef.get("armor_bonus", 0.0))
	if arm_b > 0.0:
		parts.append("+%.0f ARM" % arm_b)
	var cdm: float = float(wdef.get("cooldown_mult", 1.0))
	if not is_equal_approx(cdm, 1.0):
		parts.append("CD x%.2f" % cdm)
	return " (" + ", ".join(parts) + ")"


func _format_armor_bonus(adef: Dictionary, weapon_tier: int) -> String:
	if adef.is_empty() or str(adef.get("id", "NONE")) == "NONE":
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var arm_b: float = float(adef.get("armor_bonus", 0.0))
	if str(adef.get("id", "")) == "BONE_GUARD":
		arm_b += float(maxi(0, weapon_tier - 1)) * 4.0
	if arm_b > 0.0:
		parts.append("+%.0f ARM" % arm_b)
	var hp_b: float = float(adef.get("hp_bonus", 0.0))
	if hp_b > 0.0:
		parts.append("+%.0f HP" % hp_b)
	var mm: float = float(adef.get("move_mult", 1.0))
	if not is_equal_approx(mm, 1.0):
		parts.append("Spd x%.2f" % mm)
	return " (" + ", ".join(parts) + ")" if not parts.is_empty() else ""


func _fit_panel_bounds() -> void:
	if _hdr == null or _body_vb == null:
		return
	var vp_rect: Rect2 = get_viewport_rect()
	var vp_h: float = vp_rect.size.y if vp_rect.size.y > 0.0 else 900.0
	var top_y: float = 252.0
	var max_bottom: float = maxf(top_y + 160.0, vp_h - 166.0)
	var desired_h: float = _hdr.get_combined_minimum_size().y + _body_vb.get_combined_minimum_size().y + 36.0
	var next_bottom: float = minf(top_y + desired_h, max_bottom)
	offset_top = top_y
	if absf(offset_bottom - next_bottom) > 1.0:
		offset_bottom = next_bottom


func close() -> void:
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and (focused == self or is_ancestor_of(focused)):
			focused.release_focus()
	hide()
	_inspected_unit = null
	_weapon_sig = []
	_armor_sig = []

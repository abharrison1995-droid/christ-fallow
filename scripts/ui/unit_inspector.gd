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
var _insp_rescue_btn: Button = null
var _insp_syncing: bool = false


func _ready() -> void:
	hide()
	add_theme_stylebox_override("panel", Look.panel(Color(0.07, 0.06, 0.06, 0.94), Color(0.68, 0.50, 0.24), 14))
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -342.0
	offset_top = 255.0
	offset_right = -20.0
	offset_bottom = 545.0

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	_insp_title = Look.label("Tribesman", &"SectionTitle", 21)
	_insp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_insp_title)

	var x_btn := Button.new()
	x_btn.text = "Close"
	x_btn.pressed.connect(close)
	hdr.add_child(x_btn)

	_insp_status = Label.new()
	_insp_status.text = "Status: Loyal"
	_insp_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_insp_status)

	_insp_hp_lbl = Label.new()
	_insp_hp_lbl.text = "HP: 100 / 100"
	vb.add_child(_insp_hp_lbl)

	_insp_hp_bar = ProgressBar.new()
	_insp_hp_bar.custom_minimum_size = Vector2(0, 16)
	_insp_hp_bar.show_percentage = false
	vb.add_child(_insp_hp_bar)

	_insp_morale_lbl = Label.new()
	_insp_morale_lbl.text = "Morale: 78%"
	vb.add_child(_insp_morale_lbl)

	_insp_morale_bar = ProgressBar.new()
	_insp_morale_bar.custom_minimum_size = Vector2(0, 16)
	_insp_morale_bar.max_value = 100.0
	_insp_morale_bar.show_percentage = false
	vb.add_child(_insp_morale_bar)

	_insp_stats_lbl = Label.new()
	_insp_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_insp_stats_lbl)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	vb.add_child(role_row)

	_insp_role_opt = OptionButton.new()
	_insp_role_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HUDDrawers.fill_role_options(_insp_role_opt)
	_insp_role_opt.item_selected.connect(func(idx: int):
		_insp_role_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var rid: int = _insp_role_opt.get_item_id(idx)
		GameState.assign_player_role(_inspected_unit, rid)
		update_live_values()
	)
	role_row.add_child(_insp_role_opt)

	_insp_cls_opt = OptionButton.new()
	HUDDrawers.fill_class_options(_insp_cls_opt)
	_insp_cls_opt.item_selected.connect(func(idx: int):
		_insp_cls_opt.release_focus()
		if _insp_syncing or _inspected_unit == null or not is_instance_valid(_inspected_unit):
			return
		var cid: int = _insp_cls_opt.get_item_id(idx)
		GameState.assign_player_role(_inspected_unit, GameData.Role.WARRIOR, cid)
		update_live_values()
	)
	role_row.add_child(_insp_cls_opt)

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
	vb.add_child(_insp_rescue_btn)


func inspect_unit(u: Node) -> void:
	if u == null or not is_instance_valid(u):
		return
	_inspected_unit = u
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
	elif int(u.get("role")) == GameData.Role.TRAINEE:
		status_txt = "Training at Barracks"
		status_col = Color(0.65, 0.88, 1.0)
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

	var cq_dmg: float = float(u.get("close_quarters_damage"))
	var rng_dmg: float = float(u.get("ranged_attack_damage"))
	var b_cq: float = float(u.get("base_melee_stat"))
	var b_rng: float = float(u.get("base_ranged_stat"))
	var m_rk: int = int(u.get("melee_rank"))
	var r_rk: int = int(u.get("ranged_rank"))
	var xp: float = float(u.get("training_xp"))
	var arm: float = float(u.get("armor"))
	var spd: float = float(u.get("move_speed"))
	_insp_stats_lbl.text = "Close-Quarters Dmg: %.1f (Base %.1f, Rank %d/5)\nRanged Dmg: %.1f (Base %.1f, Rank %d/5)\nTraining XP: %.0f / 20\nArmor: %.0f | Speed: %.1f | Gear Tier %d" % [
		cq_dmg, b_cq, m_rk, rng_dmg, b_rng, r_rk, xp, arm, spd, int(u.get("weapon_tier"))
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
	_insp_syncing = false
	_insp_rescue_btn.visible = bool(u.get("is_wounded")) and (not bool(u.get("is_healing_in_shack")))


func close() -> void:
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and (focused == self or is_ancestor_of(focused)):
			focused.release_focus()
	hide()
	_inspected_unit = null

extends "res://scripts/ui/menu_overlay.gd"

signal closed
signal campaign_selected(leader_name: String, tribe_name: String, lineage: int)

const MeshPreview = preload("res://scripts/ui/mesh_preview.gd")

var _lineage: int = GameData.Lineage.CRAG_BORN
var _choices: Dictionary = {}
var _leader: LineEdit
var _tribe: LineEdit
var _name_label: Label
var _description: Label
var _stats: Label
var _preview: SubViewportContainer


func _ready() -> void:
	setup("Awakening", Vector2(1050, 640))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 345
	columns.add_child(form)
	_leader = _name_field(form, "Leader name", "Enoch")
	_tribe = _name_field(form, "Tribe name", "Fallow Chosen")
	form.add_child(Look.label("Lineage", &"SectionTitle"))
	var selections := GridContainer.new()
	selections.columns = 2
	form.add_child(selections)
	for id in GameData.PLAYABLE_LINEAGES:
		var lineage_id: int = id
		var entry: Dictionary = GameData.LINEAGE_DATA[lineage_id]
		var choice := Look.button(entry["short_name"], func(): _select_lineage(lineage_id))
		choice.toggle_mode = true
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choices[lineage_id] = choice
		selections.add_child(choice)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail)
	var showcase := PanelContainer.new()
	showcase.add_theme_stylebox_override("panel", Look.panel(Color("242c24"), Look.EDGE, 0))
	detail.add_child(showcase)
	_preview = MeshPreview.new()
	_preview.custom_minimum_size = Vector2(0, 246)
	showcase.add_child(_preview)
	_name_label = Look.label("", &"SectionTitle")
	detail.add_child(_name_label)
	_description = Look.label("", &"QuietLabel")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_description)
	_stats = Look.label("")
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_stats)
	footer.add_child(Look.button("Back", func(): closed.emit()))
	footer.add_child(Look.button("Awaken in the Valley", _start, &"PrimaryButton"))
	_select_lineage(_lineage)
	(_choices[_lineage] as Button).grab_focus()


func _name_field(parent: VBoxContainer, caption: String, initial_value: String) -> LineEdit:
	parent.add_child(Look.label(caption, &"QuietLabel"))
	var edit := LineEdit.new()
	edit.text = initial_value
	edit.placeholder_text = initial_value
	edit.max_length = 32
	parent.add_child(edit)
	return edit


func _select_lineage(lineage_id: int) -> void:
	_lineage = lineage_id
	for id in _choices:
		(_choices[id] as Button).set_pressed_no_signal(id == _lineage)
	var data: Dictionary = GameData.LINEAGE_DATA[_lineage]
	_name_label.text = data["name"]
	_description.text = data["description"]
	_stats.text = "Health %d%%   ·   Melee %d%%   ·   Ranged %d%%\nSpeed %d%%   ·   Gathering %d%%" % [
		roundi(data["hp_mult"] * 100.0), roundi(data["melee_mult"] * 100.0),
		roundi(data["ranged_mult"] * 100.0), roundi(data["speed_mult"] * 100.0),
		roundi(data["gather_mult"] * 100.0),
	]
	var model := MeshFactory.build_human_mesh(_lineage, GameData.Gender.MALE, Look.GOLD, true, false)
	_preview.show_model(model, Vector3(2.0, 0.45, -4.8), 1.05)


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _start() -> void:
	var leader := _leader.text.strip_edges()
	var tribe := _tribe.text.strip_edges()
	campaign_selected.emit(leader if not leader.is_empty() else "Enoch", tribe if not tribe.is_empty() else "Fallow Chosen", _lineage)

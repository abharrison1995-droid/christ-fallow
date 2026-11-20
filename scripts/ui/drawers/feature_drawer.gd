extends VBoxContainer

signal focus_lost
signal close_requested
signal navigate_requested(tab: String)
signal inspect_requested(unit: Node)
signal pause_requested

const Look = preload("res://scripts/ui/fallow_theme.gd")

var title: String
var scroll_host: ScrollContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)


func refresh() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var restore := is_instance_valid(focus) and is_ancestor_of(focus)
	var key: String = focus.get_meta("drawer_focus", "") if restore else ""
	var scroll_position := scroll_host.scroll_vertical if scroll_host != null else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build_content()
	if scroll_host != null:
		scroll_host.set_deferred("scroll_vertical", scroll_position)
	if not restore:
		return
	for control in find_children("*", "BaseButton", true, false):
		if not key.is_empty() and control.get_meta("drawer_focus", "") == key and not control.disabled:
			control.grab_focus()
			return
	focus_lost.emit()


func build_content() -> void:
	pass


func tag(button: BaseButton, key: String) -> void:
	button.set_meta("drawer_focus", key)


func _card(parent: Control, edge: Color = Look.EDGE) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Look.panel(Look.SURFACE, edge, 15))
	parent.add_child(card)
	return card

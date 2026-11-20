extends Control

const Look = preload("res://scripts/ui/fallow_theme.gd")

var content: VBoxContainer
var footer: HBoxContainer
var title_label: Label


func setup(title: String, bounds: Vector2, shade: Color = Color(0.027, 0.035, 0.031, 0.83)) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = shade
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -bounds.x * 0.5
	frame.offset_right = bounds.x * 0.5
	frame.offset_top = -bounds.y * 0.5
	frame.offset_bottom = bounds.y * 0.5
	frame.add_theme_stylebox_override("panel", Look.panel(Look.INK, Look.EDGE, 26))
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	frame.add_child(stack)
	title_label = Look.label(title, &"DisplayTitle")
	stack.add_child(title_label)
	stack.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	stack.add_child(footer)

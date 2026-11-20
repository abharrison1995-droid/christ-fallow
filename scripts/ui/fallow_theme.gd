extends RefCounted

const INK := Color("151917")
const SURFACE := Color("202521")
const EDGE := Color("4e5041")
const BONE := Color("f1e9d8")
const MUTED := Color("b6b8a9")
const GOLD := Color("e1b777")
const MOSS := Color("b4cb9d")
const DANGER := Color("f2a390")
const ICE := Color("b5d4d1")

static var _body_font: SystemFont


static func body_font() -> SystemFont:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray(["Segoe UI", "DejaVu Sans"])
	return _body_font


static func panel(color: Color = INK, edge: Color = EDGE, padding: int = 14, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func create() -> Theme:
	var result := Theme.new()
	var display := SystemFont.new()
	display.font_names = PackedStringArray(["Georgia", "Liberation Serif"])
	result.default_font = body_font()
	result.default_font_size = 16
	result.set_color("font_color", "Label", BONE)
	result.set_color("default_color", "RichTextLabel", BONE)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_constant("h_separation", "GridContainer", 10)
	result.set_constant("v_separation", "GridContainer", 10)
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("panel", "PopupPanel", panel())
	result.set_stylebox("panel", "PopupMenu", panel(INK, EDGE, 8))
	result.set_stylebox("hover", "PopupMenu", panel(SURFACE, GOLD, 6))
	result.set_color("font_color", "PopupMenu", BONE)

	var focus := panel(Color.TRANSPARENT, GOLD, 0)
	focus.set_border_width_all(2)
	for kind in ["Button", "OptionButton"]:
		result.set_stylebox("normal", kind, _button_style(Color("252b25"), EDGE))
		result.set_stylebox("hover", kind, _button_style(Color("3c4033"), GOLD))
		result.set_stylebox("pressed", kind, _button_style(Color("614a2e"), GOLD))
		result.set_stylebox("hover_pressed", kind, _button_style(Color("715735"), GOLD))
		result.set_stylebox("disabled", kind, _button_style(Color("1c201d"), Color("373b34")))
		result.set_stylebox("focus", kind, focus)
		result.set_color("font_color", kind, BONE)
		result.set_color("font_hover_color", kind, Color.WHITE)
		result.set_color("font_pressed_color", kind, BONE)
		result.set_color("font_focus_color", kind, BONE)
		result.set_color("font_disabled_color", kind, Color("989b8c"))

	result.set_type_variation("PrimaryButton", "Button")
	result.set_stylebox("normal", "PrimaryButton", _button_style(Color("c39a62"), GOLD))
	result.set_stylebox("hover", "PrimaryButton", _button_style(Color("e3be87"), BONE))
	result.set_stylebox("pressed", "PrimaryButton", _button_style(Color("a97d48"), GOLD))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		result.set_color(state, "PrimaryButton", Color("20170e"))
	result.set_type_variation("MenuButtonRow", "Button")
	var menu := _button_style(Color(0.10, 0.12, 0.10, 0.84), EDGE)
	menu.content_margin_left = 19
	menu.content_margin_right = 19
	result.set_stylebox("normal", "MenuButtonRow", menu)
	result.set_stylebox("hover", "MenuButtonRow", _button_style(Color("36392e"), GOLD))
	result.set_font_size("font_size", "MenuButtonRow", 20)

	result.set_stylebox("normal", "LineEdit", panel(Color("111411"), EDGE, 10))
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_color("font_color", "LineEdit", BONE)
	result.set_color("caret_color", "LineEdit", GOLD)
	result.set_color("selection_color", "LineEdit", Color("6e5234"))
	result.set_stylebox("background", "ProgressBar", panel(Color("101410"), EDGE, 0, 3))
	result.set_stylebox("fill", "ProgressBar", panel(Color("9a693e"), GOLD, 0, 3))
	result.set_stylebox("scroll", "VScrollBar", panel(Color("161a16"), EDGE, 4))
	result.set_stylebox("grabber", "VScrollBar", panel(Color("7e775e"), EDGE, 5))
	result.set_stylebox("grabber_highlight", "VScrollBar", panel(GOLD, EDGE, 5))
	result.set_stylebox("grabber_pressed", "VScrollBar", panel(GOLD, EDGE, 5))
	result.set_stylebox("slider", "HSlider", panel(Color("131713"), EDGE, 4))
	result.set_stylebox("grabber_area", "HSlider", panel(Color("987548"), GOLD, 4))
	result.set_stylebox("grabber_area_highlight", "HSlider", panel(GOLD, GOLD, 4))
	result.set_stylebox("panel", "TabContainer", panel(SURFACE, EDGE, 14))
	result.set_stylebox("tab_selected", "TabContainer", _button_style(SURFACE, GOLD))
	result.set_stylebox("tab_unselected", "TabContainer", _button_style(INK, EDGE))
	result.set_color("font_selected_color", "TabContainer", BONE)
	result.set_color("font_unselected_color", "TabContainer", MUTED)

	result.set_type_variation("DisplayTitle", "Label")
	result.set_font("font", "DisplayTitle", display)
	result.set_font_size("font_size", "DisplayTitle", 42)
	result.set_type_variation("SectionTitle", "Label")
	result.set_font("font", "SectionTitle", display)
	result.set_font_size("font_size", "SectionTitle", 25)
	result.set_color("font_color", "SectionTitle", GOLD)
	result.set_type_variation("QuietLabel", "Label")
	result.set_color("font_color", "QuietLabel", MUTED)
	return result


static func _button_style(color: Color, edge: Color) -> StyleBoxFlat:
	var style := panel(color, edge, 6, 4)
	style.content_margin_left = 11
	style.content_margin_right = 11
	return style


static func label(value: String, variation: StringName = &"", size: int = 0) -> Label:
	var result := Label.new()
	result.text = value
	result.theme_type_variation = variation
	if size > 0:
		result.add_theme_font_size_override("font_size", size)
	return result


static func button(caption: String, action: Callable, variation: StringName = &"") -> Button:
	var result := Button.new()
	result.text = caption
	result.theme_type_variation = variation
	result.pressed.connect(action)
	return result

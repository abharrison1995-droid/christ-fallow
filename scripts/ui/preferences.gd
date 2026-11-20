extends Node

signal changed

const PATH := "user://ui_preferences.cfg"
const DEFAULTS := {
	"fullscreen": false, "brightness": 1.25, "psx": true,
	"ui_scale": 1.0, "reduced_motion": false, "master": 0.85, "ambience": 0.65,
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in DEFAULTS:
			var value: Variant = config.get_value("interface", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]):
				_values[key] = _normalize(key, value)
	_apply.call_deferred()


func get_value(key: String) -> Variant:
	return _values[key]


func set_value(key: String, value: Variant) -> void:
	_values[key] = _normalize(key, value)
	_apply()


func save() -> bool:
	var config := ConfigFile.new()
	for key in _values:
		config.set_value("interface", key, _values[key])
	return config.save(PATH) == OK


func _normalize(key: String, value: Variant) -> Variant:
	match key:
		"brightness": return clampf(value, 1.0, 1.5)
		"ui_scale": return clampf(value, 0.9, 1.1)
		"master", "ambience": return clampf(value, 0.0, 1.0)
	return value


func _apply() -> void:
	var window := get_tree().root
	window.content_scale_factor = float(_values["ui_scale"])
	var mode := Window.MODE_FULLSCREEN if _values["fullscreen"] else Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and window.mode != mode:
		# Leave the user's maximized window alone when applying unrelated settings.
		if mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_FULLSCREEN:
			window.mode = mode
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(_values["master"]), 0.001)))
	AudioServer.set_bus_mute(0, float(_values["master"]) <= 0.0)
	changed.emit()

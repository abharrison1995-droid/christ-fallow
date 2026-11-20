extends Control

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree() or bool(Preferences.get_value("reduced_motion")):
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	for i in range(20):
		var age := fposmod(_elapsed * (0.12 + float(i % 5) * 0.014) + float(i) * 0.271, 1.0)
		var x := 0.80 + sin(float(i) * 2.4 + age) * 0.042 + age * 0.044
		var y := 0.65 - age * 0.28 + sin(float(i) * 1.7) * 0.032
		var opacity := sin(age * PI) * (0.27 + 0.07 * float(i % 4))
		draw_circle(Vector2(x, y) * size, 0.8 + float(i % 3) * 0.42, Color(1.0, 0.64, 0.30, opacity), true, -1.0, true)

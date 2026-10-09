extends Area2D

var is_active = true

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			$Line2D.show()
			is_active = false
			

func _process(delta: float) -> void:
	if not is_active:
		$light.color.a = clamp(float(Global.phancuc) / 180.0, 0.0, 1.0)

extends Area2D



func _on_body_entered(body: Node2D) -> void:
	Global.has_key = true
	queue_free()

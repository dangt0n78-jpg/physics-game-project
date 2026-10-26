extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if Global.has_key:
		Global.has_key = false
		get_tree().change_scene_to_file("res://_scenes/level_" + str(Global.current_level + 1) + ".tscn")
		Global.current_level += 1

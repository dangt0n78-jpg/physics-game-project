extends Area2D

var currentlevel = 1


func _on_body_entered(body: Node2D) -> void:
	get_tree().change_scene_to_file("res://_scenes/level_1.tscn")

extends StaticBody2D

func _process(delta: float) -> void:
	if Global.phancuc > 10 and Global.phancuc < 170: 
		$ColorRect.color.a = 0.25
		$CollisionShape2D.disabled = true
	else:
		$ColorRect.color.a = 1.0
		$CollisionShape2D.disabled = false

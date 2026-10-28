@tool
extends StaticBody2D

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

# Kéo node trapdoorlamp trong màn chơi vào ô này trên Inspector
@export var target_lamp: Area2D

# Giá trị x (khoảng hợp lệ sẽ là x - tolerance đến x + tolerance)
@export_range(0, 180) var target_degree: int = 95:
	set(value):
		target_degree = value
		update_label_text()

# Độ lệch (mặc định = 5 để tạo khoảng x - 5 đến x + 5)
@export var tolerance: int = 5:
	set(value):
		tolerance = value
		update_label_text()

func _ready() -> void:
	update_label_text()
	if not Engine.is_editor_hint():
		set_bridge_active(false)

func update_label_text() -> void:
	var lbl = get_node_or_null("Label")
	if lbl:
		var min_deg = max(0, target_degree - tolerance)
		var max_deg = min(180, target_degree + tolerance)
		lbl.text = str(min_deg) + " - " + str(max_deg)

func _physics_process(_delta: float) -> void:
	# Không chạy logic va chạm khi đang ở trong màn hình thiết kế Editor
	if Engine.is_editor_hint():
		return
		
	if target_lamp:
		var min_deg = target_degree - tolerance
		var max_deg = target_degree + tolerance
		
		# Kiểm tra đèn đã áp tấm phân cực (not is_active) và góc nằm trong [x - 5, x + 5]
		var in_range = (target_lamp.degree >= min_deg and target_lamp.degree <= max_deg)
		if not target_lamp.is_active and in_range:
			set_bridge_active(true)
		else:
			set_bridge_active(false)
	else:
		set_bridge_active(false)

func set_bridge_active(active: bool) -> void:
	if collision:
		# disabled = false tức là BẬT va chạm, disabled = true là TẮT va chạm
		collision.disabled = not active
	
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("default")
		if active:
			$AnimatedSprite2D.frame = 0
		else:
			$AnimatedSprite2D.frame = 1

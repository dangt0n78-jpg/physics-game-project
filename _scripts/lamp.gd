extends Area2D

@onready var rayleft: RayCast2D = $rayleft
@onready var rayright: RayCast2D = $rayright
@onready var light: Polygon2D = $light

@export var timeleft :float= 5.0
var is_active = true
var degree :int= 180
# Số lượng điểm quét ở đáy (30 điểm sẽ giúp mép ánh sáng ôm sát bục xanh)
@export var ray_count: int = 30

var top_left_offset: Vector2
var top_right_offset: Vector2
var max_bottom_left: Vector2
var max_bottom_right: Vector2

func _ready() -> void:
	light.position = Vector2.ZERO
	light.offset = Vector2.ZERO
	
	# Lấy 2 đỉnh trên cùng từ hình vẽ gốc của bạn
	if light.polygon.size() >= 2:
		top_left_offset = light.polygon[0]
		top_right_offset = light.polygon[-1]
	
	# Lưu lại tọa độ đích xa nhất của 2 tia sáng ban đầu
	max_bottom_left = rayleft.position + rayleft.target_position
	max_bottom_right = rayright.position + rayright.target_position
	
	update_light()

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if has_node("Line2D"):
				$Line2D.show()
			is_active = false
			$timeleft.wait_time = timeleft
			$timeleft.start()
			$timeleftcounter.show()

func _physics_process(delta: float) -> void:
	update_light()
	
	if not is_active:
		$timeleftcounter.text = str(int($timeleft.time_left))
	
	# Giữ nguyên cơ chế phân cực và is_active của bạn
	if not is_active:
		$light.color.a = clamp(float(Global.phancuc) / 180.0, 0.0, 1.0)
	else:
		$light.color.a = 1.0

func update_light() -> void:
	var points = PackedVector2Array()
	
	# 1. Thêm 2 đỉnh miệng đèn (Trên-Trái và Trên-Phải)
	points.append(top_left_offset)
	points.append(top_right_offset)
	
	# 2. Quét 30 tia từ Phải sang Trái để ôm theo mép bục
	for i in range(ray_count):
		var t: float = float(i) / float(ray_count - 1) # Chạy từ 0.0 (Phải) sang 1.0 (Trái)
		
		# Nội suy điểm bắt đầu và điểm kết thúc của từng tia nhỏ
		var start_pos: Vector2 = top_right_offset.lerp(top_left_offset, t)
		var end_pos: Vector2 = max_bottom_right.lerp(max_bottom_left, t)
		
		# Di chuyển tia quét đến vị trí mới và cập nhật va chạm ngay lập tức
		rayleft.position = start_pos
		rayleft.target_position = end_pos - start_pos
		rayleft.force_raycast_update()
		
		if rayleft.is_colliding():
			points.append(to_local(rayleft.get_collision_point()))
		else:
			points.append(end_pos)
			
	# 3. Gán toàn bộ các điểm vào Polygon2D
	light.polygon = points


func _on_timeleft_timeout() -> void:
	$Line2D.hide()
	$timeleftcounter.hide()
	is_active = true

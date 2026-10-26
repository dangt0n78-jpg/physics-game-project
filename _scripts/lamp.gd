extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var rayleft: RayCast2D = $rayleft
@onready var rayright: RayCast2D = $rayright
@onready var light: Polygon2D = $light
@onready var line_2d: Line2D = $Line2D
@onready var timer: Timer = $timeleft
@onready var time_label: Label = $timeleft2
@onready var degree_label: Label = $degree

@export var timeleft: float = 5.0
@export var ray_count: int = 30

var is_active: bool = true
var is_editing: bool = false
var degree: int = 180
var is_mouse_in_area: bool = false

var top_left_offset: Vector2
var top_right_offset: Vector2
var max_bottom_left: Vector2
var max_bottom_right: Vector2

func _ready() -> void:
	# 1. Quy đổi chính xác vị trí các đỉnh Polygon2D từ Editor (bao gồm cả Scale, Position, Offset)
	var editor_points: Array[Vector2] = []
	for p in light.polygon:
		editor_points.append(to_local(light.to_global(p + light.offset)))
	
	# 2. Đưa Transform của light và rayleft về chuẩn (1:1) với node gốc lamp
	light.position = Vector2.ZERO
	light.offset = Vector2.ZERO
	light.rotation = 0.0
	light.scale = Vector2.ONE
	
	rayleft.rotation = 0.0
	rayleft.scale = Vector2.ONE
	
	# 3. Tự động lấy 2 đỉnh miệng đèn (ở trên) và 2 đỉnh đáy (ở dưới) theo đúng hình bạn vẽ
	if editor_points.size() >= 4:
		# Sắp xếp từ cao xuống thấp (theo trục Y tăng dần)
		editor_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
		
		# 2 điểm cao nhất là miệng đèn Trên-Trái và Trên-Phải
		var top_pts = [editor_points[0], editor_points[1]]
		top_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		top_left_offset = top_pts[0]
		top_right_offset = top_pts[1]
		
		# Các điểm còn lại ở dưới đáy: lấy điểm ngoài cùng bên trái và ngoài cùng bên phải
		var bottom_pts = editor_points.slice(2)
		bottom_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		max_bottom_left = bottom_pts[0]
		max_bottom_right = bottom_pts[-1]
	
	# Đảm bảo Timer chỉ đếm ngược 1 lần mỗi khi kích hoạt
	timer.one_shot = true
	if not timer.timeout.is_connected(_on_timeleft_timeout):
		timer.timeout.connect(_on_timeleft_timeout)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	# Ẩn các UI khi mới vào màn
	line_2d.hide()
	degree_label.hide()
	time_label.hide()
	
	update_light()

# Bắt sự kiện click vào đèn và click ra ngoài
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_on_lamp():
			# Khi đèn đang bình thường và click vào đèn -> Mở chế độ chỉnh góc
			if is_active and not is_editing:
				is_editing = true
				line_2d.show()
				degree_label.show()
				time_label.hide()
		else:
			# Khi đang chỉnh góc mà click ra ngoài -> Khóa góc và bắt đầu đếm ngược
			if is_editing:
				is_editing = false
				is_active = false
				time_label.show()
				timer.wait_time = timeleft
				timer.start()

# Kiểm tra chuột có nằm trên vùng va chạm hoặc hình ảnh của chiếc đèn không
func is_mouse_on_lamp() -> bool:
	if is_mouse_in_area:
		return true
	if sprite and sprite.texture:
		var local_mouse = sprite.to_local(get_global_mouse_position())
		return sprite.get_rect().has_point(local_mouse)
	return false

func _physics_process(_delta: float) -> void:
	update_light()
	
	if is_editing:
		# Trong lúc đang mở chỉnh: cập nhật góc theo Global.phancuc
		degree = clamp(int(Global.phancuc), 0, 180)
		degree_label.text = str(degree)
		light.color.a = clamp(float(degree) / 180.0, 0.0, 1.0)
	elif not is_active:
		# Sau khi đã ấn ra ngoài để áp dụng: giữ nguyên góc degree đã khóa và đếm ngược
		time_label.text = str(int(ceil(timer.time_left)))
		light.color.a = clamp(float(degree) / 180.0, 0.0, 1.0)
	else:
		# Trạng thái bình thường (chưa áp tấm phân cực)
		light.color.a = 1.0

func update_light() -> void:
	var points = PackedVector2Array()
	
	# 1. Thêm 2 đỉnh miệng đèn (Trên-Trái và Trên-Phải)
	points.append(top_left_offset)
	points.append(top_right_offset)
	
	# 2. Quét 30 tia từ Phải sang Trái để ôm theo mép bục
	for i in range(ray_count):
		var t: float = float(i) / float(ray_count - 1)
		
		var start_pos: Vector2 = top_right_offset.lerp(top_left_offset, t)
		var end_pos: Vector2 = max_bottom_right.lerp(max_bottom_left, t)
		
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
	line_2d.hide()
	time_label.hide()
	degree_label.hide()
	is_active = true
	is_editing = false

func _on_mouse_entered() -> void:
	is_mouse_in_area = true

func _on_mouse_exited() -> void:
	is_mouse_in_area = false

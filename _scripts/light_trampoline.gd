extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var poly: Polygon2D = $Polygon2D
@onready var degree_label: Label = $degree
@onready var time_label: Label = $timeleft
@onready var timer: Timer = $timeleft/timeleft # Node Timer nằm trong Label timeleft

@export var duration: float = 5.0 # Thời gian tồn tại của tấm phân cực
@export var max_bounce_force: float = 900.0 # Lực nảy tối đa (khi góc = 180)
@export var min_bounce_force: float = 300.0 # Lực nảy tối thiểu

enum State { IDLE, EDITING, ACTIVE }
var current_state: State = State.IDLE

var current_degree: int = 180
var is_mouse_in_area: bool = false

func _ready() -> void:
	# Cài đặt Timer chạy 1 lần rồi dừng khi về 0
	timer.one_shot = true
	timer.wait_time = duration
	
	# Tự động kết nối các Signal để tránh quên nối trong Editor
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
		
	reset_to_idle()

func _physics_process(_delta: float) -> void:
	match current_state:
		State.EDITING:
			# Lấy góc từ Global.phancuc trong lúc đang chỉnh
			current_degree = clamp(int(Global.phancuc), 0, 180)
			degree_label.text = str(current_degree)
			update_visual_alpha()
			
		State.ACTIVE:
			# Cập nhật số giây đếm ngược trên màn hình
			time_label.text = str(int(ceil(timer.time_left)))
			
			# Nếu Player đang đứng sẵn trong vùng nảy ngay lúc vừa kích hoạt thì đẩy lên luôn
			for body in get_overlapping_bodies():
				bounce_player(body)

# Bắt sự kiện click chuột vào trampoline và click ra ngoài
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_on_trampoline():
			# Khi ấn vào light_trampoline -> Mở chế độ chỉnh góc
			if current_state == State.IDLE:
				current_state = State.EDITING
				degree_label.show()
				time_label.hide()
				poly.show()
				update_visual_alpha()
		else:
			# Khi đang chỉnh mà ấn ra ngoài -> Xác nhận và bắt đầu đếm ngược
			if current_state == State.EDITING:
				current_state = State.ACTIVE
				time_label.show()
				timer.wait_time = duration
				timer.start()
				update_visual_alpha()

# Kiểm tra chuột có nằm trên hình ảnh hoặc vùng va chạm của Trampoline không
func is_mouse_on_trampoline() -> bool:
	if is_mouse_in_area:
		return true
	if sprite and sprite.texture:
		var local_mouse = sprite.to_local(get_global_mouse_position())
		return sprite.get_rect().has_point(local_mouse)
	return false

# Tính tỉ lệ sức nảy (0.0 -> 1.0) và cập nhật độ đậm của Polygon2D
func get_power_ratio() -> float:
	return clamp(float(current_degree) / 180.0, 0.0, 1.0)

func update_visual_alpha() -> void:
	# Sức nảy càng lớn thì Polygon2D alpha càng lớn
	poly.color.a = get_power_ratio()

# Xử lý khi Player nhảy vào CollisionShape2D
func _on_body_entered(body: Node2D) -> void:
	if current_state == State.ACTIVE:
		bounce_player(body)

func bounce_player(body: Node2D) -> void:
	if body is CharacterBody2D:
		var ratio = get_power_ratio()
		if ratio <= 0.05:
			return # Nếu góc quá nhỏ (gần bằng 0) thì không nảy
			
		var bounce_power = lerp(min_bounce_force, max_bounce_force, ratio)
		
		# Đẩy Player bật lên theo hướng của Trampoline (hỗ trợ cả đặt ngang lẫn đặt nghiêng)
		var bounce_dir = -global_transform.y.normalized()
		if abs(bounce_dir.x) < 0.01:
			body.velocity.y = -bounce_power
		else:
			body.velocity = bounce_dir * bounce_power

# Khi thời gian giảm về 0 -> Mất tấm phân cực
func _on_timer_timeout() -> void:
	reset_to_idle()

func reset_to_idle() -> void:
	current_state = State.IDLE
	degree_label.hide()
	time_label.hide()
	poly.color.a = 0.0

func _on_mouse_entered() -> void:
	is_mouse_in_area = true

func _on_mouse_exited() -> void:
	is_mouse_in_area = false

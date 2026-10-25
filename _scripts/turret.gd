@tool
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var time_label: Label = $timeleft
@onready var degree_label: Label = $degree
@onready var raylight: RayCast2D = $raylight
@onready var poly: Polygon2D = $Polygon2D

# Khoảng góc phân cực an toàn: [target_degree - tolerance, target_degree + tolerance]
@export_range(0, 180) var target_degree: int = 90:
	set(value):
		target_degree = value
		update_range_text()

@export var tolerance: int = 5:
	set(value):
		tolerance = value
		update_range_text()

# Thời gian hiệu lực của tấm phân cực và thông số tia laser
@export var duration: float = 5.0
@export var laser_width: float = 16.0
@export var rotation_speed: float = 2.0
@export var always_show_laser: bool = true

enum State { IDLE, EDITING, ACTIVE }
var current_state: State = State.IDLE

var current_degree: int = 180
var is_mouse_in_area: bool = false
var is_killing: bool = false
var timer: Timer
var player: Node2D = null

func _ready() -> void:
	update_range_text()
	
	# Nếu đang ở trong màn hình thiết kế Editor thì chỉ hiện số độ, không chạy logic bắn
	if Engine.is_editor_hint():
		return

	# 1. Tự động tạo Timer đếm ngược tấm phân cực
	timer = get_node_or_null("Timer")
	if not timer:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)
	timer.one_shot = true
	timer.wait_time = duration
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
		
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# 2. Đảm bảo RayCast2D quét trúng cả Tường (Layer 1) và Player (Layer 2)
	raylight.enabled = true
	raylight.set_collision_mask_value(1, true)
	raylight.set_collision_mask_value(2, true)

	# 3. Đặt gốc và Z-Index cho tia laser
	poly.position = Vector2.ZERO
	poly.offset = Vector2.ZERO
	poly.z_as_relative = false
	poly.z_index = 50
	
	# HIỆN sẵn khoảng độ yêu cầu ngay khi vào màn chơi
	degree_label.show()
	time_label.hide()
	
	find_player()

# Hàm cập nhật chữ hiển thị khoảng độ "min - max"
func update_range_text() -> void:
	var lbl = get_node_or_null("degree")
	if lbl:
		var min_deg = max(0, target_degree - tolerance)
		var max_deg = min(180, target_degree + tolerance)
		lbl.text = str(min_deg) + " - " + str(max_deg)

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child is CharacterBody2D:
				player = child
				break
	if player and player is CollisionObject2D:
		raylight.collision_mask |= player.collision_layer

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_on_turret():
			if current_state == State.IDLE:
				current_state = State.EDITING
				degree_label.show()
				time_label.hide()
		else:
			if current_state == State.EDITING:
				current_state = State.ACTIVE
				time_label.show()
				degree_label.hide() # Ẩn góc đi để nhường chỗ hiện số giây đếm ngược
				timer.wait_time = duration
				timer.start()

func is_mouse_on_turret() -> bool:
	if is_mouse_in_area:
		return true
	if sprite and sprite.texture:
		var local_mouse = sprite.to_local(get_global_mouse_position())
		return sprite.get_rect().has_point(local_mouse)
	return false

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# 1. Giữ chữ luôn nằm ngang dễ đọc khi súng xoay
	degree_label.rotation = -rotation
	time_label.rotation = -rotation
	
	match current_state:
		State.IDLE:
			# Khi chưa click vào súng: Hiện khoảng độ yêu cầu (VD: "85 - 95")
			update_range_text()
		State.EDITING:
			# Khi đang chỉnh: Hiện góc phân cực hiện tại của người chơi
			current_degree = clamp(int(Global.phancuc), 0, 180)
			degree_label.text = str(current_degree)
		State.ACTIVE:
			# Khi đã áp kính: Hiện thời gian đếm ngược
			time_label.text = str(int(ceil(timer.time_left)))

	# 2. Xoay Turret nhìn về phía Player
	if not is_instance_valid(player):
		find_player()
	if is_instance_valid(player):
		var target_angle = (player.global_position - global_position).angle() - PI / 2.0
		rotation = rotate_toward(rotation, target_angle, rotation_speed * delta)

	# 3. Bắn và cập nhật hình dáng tia laser
	check_raylight_and_fire()

func check_raylight_and_fire() -> void:
	raylight.force_raycast_update()
	var max_dist = raylight.target_position.length()
	
	if not raylight.is_colliding():
		if always_show_laser:
			poly.show()
			poly.color.a = 0.35 if is_polarized_safely() else 1.0
			draw_laser_to(max_dist)
		else:
			poly.hide()
		return
		
	var collider = raylight.get_collider()
	var hit_dist = to_local(raylight.get_collision_point()).length()
	
	if not is_player(collider):
		if always_show_laser:
			poly.show()
			poly.color.a = 0.35 if is_polarized_safely() else 1.0
			draw_laser_to(hit_dist)
		else:
			poly.hide()
		return
		
	poly.show()
	
	if is_polarized_safely():
		poly.color.a = 0.35
		raylight.add_exception(collider)
		raylight.force_raycast_update()
		
		var behind_dist: float = max_dist
		if raylight.is_colliding():
			behind_dist = to_local(raylight.get_collision_point()).length()
			
		raylight.remove_exception(collider)
		draw_laser_to(behind_dist)
	else:
		poly.color.a = 1.0
		draw_laser_to(hit_dist)
		kill_player(collider)

func is_player(obj: Object) -> bool:
	if obj is CharacterBody2D:
		return true
	if obj is Node and (obj.name.to_lower().contains("player") or obj.is_in_group("player")):
		return true
	return false

func is_polarized_safely() -> bool:
	if current_state != State.ACTIVE:
		return false
	var min_deg = target_degree - tolerance
	var max_deg = target_degree + tolerance
	return current_degree >= min_deg and current_degree <= max_deg

func draw_laser_to(length: float) -> void:
	var half_w = laser_width / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, length),
		Vector2(-half_w, length)
	])

func kill_player(player_node: Object) -> void:
	if is_killing:
		return
	is_killing = true
	
	await get_tree().create_timer(0.15).timeout
	
	if is_instance_valid(player_node) and player_node.has_method("die"):
		player_node.die()
	else:
		get_tree().call_deferred("reload_current_scene")

func _on_timer_timeout() -> void:
	current_state = State.IDLE
	time_label.hide()
	# Khi hết giờ, hiện lại khoảng độ yêu cầu trên súng
	degree_label.show()
	update_range_text()

func _on_mouse_entered() -> void:
	is_mouse_in_area = true

func _on_mouse_exited() -> void:
	is_mouse_in_area = false

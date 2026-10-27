@tool
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var time_label: Label = $timeleft
@onready var degree_label: Label = $degree
@onready var raylight: RayCast2D = $raylight
@onready var poly: Polygon2D = $Polygon2D

@export_range(0, 180) var target_degree: int = 90:
	set(value):
		target_degree = value
		update_range_text()

@export var tolerance: int = 5:
	set(value):
		tolerance = value
		update_range_text()

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
var sight_ray: RayCast2D # Tia chuyên dụng kiểm tra tường chắn
var player: Node2D = null

func _ready() -> void:
	update_range_text()
	if Engine.is_editor_hint():
		return

	# 1. Tạo Timer
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

	# 2. Cấu hình raylight (tia bắn laser)
	raylight.enabled = true
	raylight.exclude_parent = true
	raylight.hit_from_inside = false
	raylight.collide_with_bodies = true
	raylight.collide_with_areas = false
	# Quét tất cả các Layer để không bao giờ bỏ sót TileMapLayer hoặc Player
	raylight.collision_mask = 0xFFFFFFFF

	# 3. Tạo tia kiểm tra tầm nhìn (sight_ray) để không nhìn xuyên tường
	sight_ray = RayCast2D.new()
	sight_ray.enabled = true
	sight_ray.exclude_parent = true
	sight_ray.hit_from_inside = false
	sight_ray.collide_with_bodies = true
	sight_ray.collide_with_areas = false
	sight_ray.collision_mask = 0xFFFFFFFF
	add_child(sight_ray)

	poly.position = Vector2.ZERO
	poly.offset = Vector2.ZERO
	poly.z_as_relative = false
	poly.z_index = 50
	
	degree_label.show()
	time_label.hide()
	
	find_player()

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
				degree_label.hide()
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

	degree_label.rotation = -rotation
	time_label.rotation = -rotation
	
	match current_state:
		State.IDLE:
			update_range_text()
		State.EDITING:
			current_degree = clamp(int(Global.phancuc), 0, 180)
			degree_label.text = str(current_degree)
		State.ACTIVE:
			time_label.text = str(int(ceil(timer.time_left)))

	# CHỈ xoay súng khi tia sight_ray chạm trực tiếp vào Player mà không vướng tường
	if not is_instance_valid(player):
		find_player()
	if is_instance_valid(player) and can_see_player():
		var target_angle = (player.global_position - global_position).angle() - PI / 2.0
		rotation = rotate_toward(rotation, target_angle, rotation_speed * delta)

	check_raylight_and_fire()

# Dùng RayCast2D phụ bắn thẳng tới vị trí của Player để kiểm tra vật cản
func can_see_player() -> bool:
	sight_ray.target_position = to_local(player.global_position)
	sight_ray.force_raycast_update()
	
	if not sight_ray.is_colliding():
		return false
		
	var first_hit = sight_ray.get_collider()
	# Nếu tia chạm TileMapLayer trước -> first_hit là TileMapLayer -> Trả về false (Bị khuất tầm nhìn!)
	return is_player(first_hit)

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
	
	# Nếu tia laser đụng phải Tường (TileMapLayer) -> Chặn đứng tại mặt tường, KHÔNG giết Player
	if not is_player(collider):
		if always_show_laser:
			poly.show()
			poly.color.a = 0.35 if is_polarized_safely() else 1.0
			draw_laser_to(hit_dist)
		else:
			poly.hide()
		return
		
	# Chỉ khi vật đầu tiên đụng phải là Player mới xử lý bắn trúng
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
	if obj == null:
		return false
	if obj is TileMapLayer:
		return false
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
	degree_label.show()
	update_range_text()

func _on_mouse_entered() -> void:
	is_mouse_in_area = true

func _on_mouse_exited() -> void:
	is_mouse_in_area = false

@tool
class_name KeyZap
extends Node2D

@export var key_label: Label
var initial_pos: Vector2
var current_pos: Vector2
var current_velocity: Vector2
var max_speed: float = 2000.0
var steering_force: float = 40.0
var arrival_radius: float = 200.0
var lerp_speed: float = 20.0
var was_set: bool = false

func _ready() -> void:
	set_process(false)
	if not Engine.is_editor_hint() && not was_set:
		return

func set_key(key: String, font_size: int) -> void:
	var top_or_bottom: int = sign(global_position.direction_to(get_global_mouse_position())).y * -1
	current_velocity = Vector2(1000 * randf_range(-0.5, 1.0), -2000 * randf_range(0.5, 1.0) * top_or_bottom)
	current_pos = global_position
	
	key_label.text = key
	var scale: float = float(font_size) / 14.0
	$".".scale = Vector2(scale, scale)
	
	set_process(true)
	was_set = true

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() && not was_set:
		return
		
	current_pos = global_position
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var distance: float = current_pos.distance_to(mouse_pos)
	
	# Different behavior based on distance to target
	if distance < arrival_radius:
		var desired_velocity: Vector2 = current_pos.direction_to(mouse_pos) * max_speed
		var steering: Vector2 = (desired_velocity - current_velocity).limit_length(steering_force)
		current_velocity = (current_velocity + steering).limit_length(max_speed) * (distance / arrival_radius)
		global_position = global_position.lerp(mouse_pos, lerp_speed * delta * 0.5)
		global_position += current_velocity * delta
	else:
		var desired_velocity: Vector2 = current_pos.direction_to(mouse_pos) * max_speed
		var steering: Vector2 = (desired_velocity - current_velocity).limit_length(steering_force)
		current_velocity = (current_velocity + steering).limit_length(max_speed)
		global_position += current_velocity * delta
	
	if key_label != null and distance <= arrival_radius:
		key_label.modulate.a = distance / arrival_radius
	
	# reached target
	if distance <= 5:
		queue_free()

func _on_timer_timeout() -> void:
	if not Engine.is_editor_hint() && not was_set:
		return
	print("asd")
	queue_free()

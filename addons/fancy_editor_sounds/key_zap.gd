@tool
class_name KeyZap
extends Node2D

@export var key_label: Label
var initial_pos: Vector2
var current_pos: Vector2
var current_velocity: Vector2
var max_speed: float = 2000.0
var arrival_radius: float = 200.0
var lerp_speed: float = 30.0
var was_set: bool = false
var editor_sounds: FancyEditorSounds = null
var played_sound: bool = false
var use_gravity_keys: bool = false

var lifetime: float = 0.0
var max_lifetime: float = 3.0
var horizontal_drag: float = 0.98
var vertical_drag: float = 0.99
var rotation_speed: float = 0.0

func _ready() -> void:
	set_process(false)
	if not Engine.is_editor_hint() && not was_set:
		return

func set_key(key: String, font_size: int, sounds_plugin: FancyEditorSounds = null) -> void:
	editor_sounds = sounds_plugin
	use_gravity_keys = editor_sounds.settings.gravity_keys_enabled
	
	# Set initial velocity based on mode
	if use_gravity_keys:
		current_velocity = Vector2(
			randf_range(editor_sounds.settings.gravity_keys_start_force_x_min, editor_sounds.settings.gravity_keys_start_force_x_max),
			randf_range(editor_sounds.settings.gravity_keys_start_force_y_min, editor_sounds.settings.gravity_keys_start_force_y_max)
		)
		current_velocity *= editor_sounds.settings.gravity_keys_start_force_multiplier
		rotation_speed = randf_range(-5.0, 5.0)
	else:
		# Original behavior for cursor-following mode
		var top_or_bottom: int = sign(global_position.direction_to(get_global_mouse_position())).y
		current_velocity = Vector2(100 * randf_range(-1.0, 1.0), -editor_sounds.settings.zap_starting_velocity * randf_range(0.7, 1.0) * top_or_bottom)
	
	current_pos = global_position
	key_label.text = key
	var scale: float = float(font_size) / 14.0
	$".".scale = Vector2(scale, scale)
	
	set_process(true)
	was_set = true

func move_towards_cursor(delta: float) -> void:
	current_pos = global_position
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var distance: float = current_pos.distance_to(mouse_pos)
	
	# Different behavior based on distance to target
	if distance < arrival_radius:
		var desired_velocity: Vector2 = current_pos.direction_to(mouse_pos) * max_speed
		var steering: Vector2 = (desired_velocity - current_velocity).limit_length(editor_sounds.settings.zap_steering_force * delta) 
		current_velocity = (current_velocity + steering).limit_length(max_speed) * (distance / arrival_radius)
		global_position = global_position.lerp(mouse_pos, lerp_speed * delta * 0.5)
		global_position += current_velocity * delta
	else:
		var desired_velocity: Vector2 = current_pos.direction_to(mouse_pos) * max_speed
		var steering: Vector2 = (desired_velocity - current_velocity).limit_length(editor_sounds.settings.zap_steering_force * delta)
		current_velocity = (current_velocity + steering).limit_length(max_speed)
		global_position += current_velocity * delta
		
	if key_label != null and distance <= arrival_radius:
		key_label.modulate.a = distance / arrival_radius
	
	if distance <= arrival_radius / 8.0:
		if not played_sound:
			played_sound = true
			editor_sounds.play_zap_sound()
	
	# reached target
	if distance <= 10:
		queue_free()

func apply_gravity(delta: float) -> void:
	# Apply gravity
	current_velocity.y += editor_sounds.settings.gravity_keys_gravity * delta * 60.0
	
	# Apply drag to slow down
	current_velocity.x *= pow(horizontal_drag, delta * 60.0)
	current_velocity.y *= pow(vertical_drag, delta * 60.0)
	
	rotation += rotation_speed * delta
	global_position += current_velocity * delta
	
	# Fade out over time
	lifetime += delta
	if lifetime > max_lifetime * 0.5:
		var fade_factor = 1.0 - ((lifetime - max_lifetime * 0.5) / (max_lifetime * 0.5))
		key_label.modulate.a = fade_factor
	
	# Lifetime reached, delete
	if lifetime > max_lifetime:
		queue_free()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() && not was_set:
		return
		
	if use_gravity_keys:
		apply_gravity(delta)
	else:
		move_towards_cursor(delta)

func _on_timer_timeout() -> void:
	if not Engine.is_editor_hint() && not was_set:
		return
	queue_free()

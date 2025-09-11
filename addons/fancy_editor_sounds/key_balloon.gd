@tool
class_name KeyBalloon
extends Node2D

enum BalloonState {
	UPWARD,
	LINGERING, 
	DOWNWARD,
	FINISHED
}

var editor_sounds: FancyEditorSounds = null
var was_set: bool = false
var word_was_completed: bool = false
var current_state: BalloonState = BalloonState.UPWARD
var starting_position: Vector2
var upward_tween: Tween
var linger_tween: Tween 

func _ready() -> void:
	set_process(false)
	if not Engine.is_editor_hint() && not was_set:
		return

func set_key(key: String, font_size: int, sounds_plugin: FancyEditorSounds = null) -> void:
	editor_sounds = sounds_plugin
	editor_sounds.single_word_typed.connect(start_downward_phase)
	set_process(true)
	was_set = true
	var key_label: Label = $Control/Label
	key_label.text = key
	key_label.modulate.a = 0.0 
	var scale_factor: float = float(font_size) / 14.0
	$".".scale = Vector2(scale_factor, scale_factor)
	starting_position = global_position
	start_upward_phase()


func start_upward_phase() -> void:
	current_state = BalloonState.UPWARD
	
	upward_tween = create_tween()
	upward_tween.set_ease(Tween.EASE_IN_OUT)
	upward_tween.set_trans(Tween.TRANS_CUBIC)
	upward_tween.set_parallel(true)
	
	# Movement 
	upward_tween.tween_property(self, "global_position:y", starting_position.y - 25, 0.4)
	upward_tween.tween_property($Control/Label, "modulate:a", 1.0, 0.3).set_delay(0.1)
	
	# Gentle stretch during upward movement
	upward_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.4)
	
	# When upward phase completes, enter lingering state
	upward_tween.tween_callback(enter_lingering_state).set_delay(0.4)

func enter_lingering_state() -> void:
	current_state = BalloonState.LINGERING
	if word_was_completed:
		start_downward_phase()
		return

	var linger_tween = create_tween()
	linger_tween.set_loops()
	linger_tween.set_ease(Tween.EASE_IN_OUT)
	linger_tween.set_trans(Tween.TRANS_SINE)
	linger_tween.set_parallel(true)
	
	# Gentle bobbing motion  
	linger_tween.tween_property(self, "global_position:y", global_position.y - 3, 0.8)
	linger_tween.tween_property(self, "global_position:y", global_position.y + 3, 0.8).set_delay(0.8)
	
	# Subtle scale 
	linger_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.8)
	linger_tween.tween_property(self, "scale", Vector2(0.6, 1.0), 0.4).set_delay(0.4)
	linger_tween.tween_property(self, "scale", Vector2(1.2, 0.9), 0.8).set_delay(0.8)

func start_downward_phase() -> void:
	if current_state == BalloonState.UPWARD:
		word_was_completed = true
		return
		
	editor_sounds.single_word_typed.disconnect(start_downward_phase)
	
	current_state = BalloonState.DOWNWARD
	
	# Kill any existing tweens
	if upward_tween:
		upward_tween.kill()
	if linger_tween:
		linger_tween.kill()
	
	# Start downward animation
	var downward_tween = create_tween()
	downward_tween.set_ease(Tween.EASE_IN_OUT)
	downward_tween.set_trans(Tween.TRANS_CUBIC)
	downward_tween.set_parallel(true)
	
	# Move back to starting position and below
	downward_tween.tween_property(self, "global_position:y", starting_position.y + 10, 0.4)
	
	# Impact squish
	downward_tween.tween_property(self, "scale", Vector2(1.3, 0.5), 0.2)
	
	# Stretch inwards and disappear
	downward_tween.tween_property(self, "scale", Vector2(0.1, 2.0), 0.25).set_delay(0.2)
	downward_tween.tween_property($Control/Label, "modulate:a", 0.0, 0.25).set_delay(0.2)
	
	# Cleanup when animation finishes
	downward_tween.tween_callback(finish_animation).set_delay(0.45)

func finish_animation() -> void:
	current_state = BalloonState.FINISHED
	queue_free()

func _on_timer_timeout() -> void:
	queue_free()

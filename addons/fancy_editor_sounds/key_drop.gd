@tool
class_name KeyDrop
extends Node2D

func _on_timer_timeout() -> void:
	queue_free()

func set_key(key: String, font_size: int) -> void:
	var key_label: Label = $Control/Label
	key_label.text = key
	var scale: float = float(font_size) / 14.0
	$".".scale = Vector2(scale, scale)
	$AnimationPlayer.play("default")

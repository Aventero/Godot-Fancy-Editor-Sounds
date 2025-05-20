class_name SoundPlayerData
extends RefCounted

var volume_multiplier: float
var player: AudioStreamPlayer
var enabled: bool
var action_name: String

func _init(_volume_multiplier: float, _action_name: String) -> void:
	player = AudioStreamPlayer.new()
	volume_multiplier = _volume_multiplier
	enabled = true
	action_name = _action_name

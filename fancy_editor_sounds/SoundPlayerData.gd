class_name SoundPlayerData
extends RefCounted

var volume_multiplier: float
var volume: float
var player: AudioStreamPlayer
var enabled: bool
var action_name: String

func _init(_volume: int, _volume_multiplier: int, _action_name: String) -> void:
	player = AudioStreamPlayer.new()
	volume_multiplier = _volume_multiplier
	volume = _volume
	enabled = true
	action_name = _action_name

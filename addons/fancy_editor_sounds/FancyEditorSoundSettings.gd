@tool
extends RefCounted
class_name FancyEditorSoundsSettings

# Constants
const SETTINGS_ROOT = "fancy_editor_sounds/"
const SETTINGS_CODE_EDITOR = SETTINGS_ROOT + "code_editor/"
const SETTINGS_ANIMATION = SETTINGS_ROOT + "animation/"
const SETTINGS_INTERFACE = SETTINGS_ROOT + "editor_interface/"

# Editor
var editor_settings: EditorSettings

# Animation
var initial_max_deleted_characters: int = 25
var max_deleted_characters: int = initial_max_deleted_characters
var initial_volume_percentage: float = 50.0 
var delete_animations_enabled: bool = true
var standard_delete_animations_enabled: bool = true
var tabbing_delete_animations_enabled: bool = true

# Zap Keys
var zap_delete_animations_enabled: bool = false
var zap_starting_velocity: float = 1000
var zap_steering_force: float = 5000

# Gravity Keys
var gravity_keys_enabled: bool = false
var gravity_keys_gravity: float = 10.0
var gravity_keys_start_force_multiplier: float = 1.0
var gravity_keys_start_force_x_min: float = -600
var gravity_keys_start_force_x_max: float = 100
var gravity_keys_start_force_y_min: float = -500
var gravity_keys_start_force_y_max: float = -200

# Sound
var volume_percentage: float = initial_volume_percentage
var initial_interface_volume_percentage: float = 100.0 
var interface_volume_percentage: float = initial_interface_volume_percentage
var interface_volume_multiplier: float = 1.0
var editor_interface_sounds_enabled: bool = true
var code_editor_sounds_enabled: bool = true
var sound_player_settings: Dictionary = {}


func _init(p_editor_settings: EditorSettings) -> void:
	editor_settings = p_editor_settings

func initialize() -> void:
	if should_reset_settings():
		print_rich("[color=#FF79B8][b][Fancy Editor Sounds][/b][/color] [color=#FFFFFF]Welcome! To adjust settings go to:[/color]")
		print_rich("[color=#FF79B8][b][Fancy Editor Sounds][/b][/color] [color=#AAAAFF]Editor[/color] → [color=#AAAAFF]Editor Settings...[/color] → [color=#AAAAFF]Enable Advanced Settings[/color]")
		print_rich("[color=#FF79B8][b][Fancy Editor Sounds][/b][/color] [color=#FFFFFF]Then scroll down to:[/color] [color=#90EE90]'Fancy Editor Sounds'[/color]")
		clean_all_settings()

	setup_settings_structure()
	load_settings_values()

func should_reset_settings() -> bool:
	# 
	var core_settings = [
		SETTINGS_CODE_EDITOR + "master_volume_percentage",
		SETTINGS_ANIMATION + "enabled",
		SETTINGS_ANIMATION + "gravity_keys",
		SETTINGS_ANIMATION + "standard_delete",
		SETTINGS_CODE_EDITOR + "typing"
	]
	
	# Check if any required setting is missing
	for path in core_settings:
		if !editor_settings.has_setting(path):
			return true
	
	return false

func clean_all_settings() -> void:
	var property_list = editor_settings.get_property_list()
	for property in property_list:
		if "name" in property and property.name.begins_with(SETTINGS_ROOT):
			editor_settings.erase(property.name)

func setup_settings_structure() -> void:
	# Root settings
	register_setting(SETTINGS_CODE_EDITOR + "master_volume_percentage", initial_volume_percentage, TYPE_FLOAT, 
					 PROPERTY_HINT_RANGE, "0.0, 100.0, 1.0", "Master Volume")
	
	# Register individual code editor sounds 
	register_setting(SETTINGS_CODE_EDITOR + "enabled", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "typing", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "deleting", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "selecting", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "selecting_word", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "selecting_all", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "deselecting", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "caret_moving", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "undo", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "redo", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "copy", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "paste", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "save", true, TYPE_BOOL)
	register_setting(SETTINGS_CODE_EDITOR + "zap_reached", true, TYPE_BOOL)
	
	# Animation section
	register_setting(SETTINGS_ANIMATION + "enabled", true, TYPE_BOOL, 
					 PROPERTY_HINT_NONE, "", "Enable Delete Animations")
	register_setting(SETTINGS_ANIMATION + "standard_delete", false, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "zap_delete_or_gravity_keys_enabled", true, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "show_deleted_on_tabbing", true, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "max_deleted_chars", initial_max_deleted_characters, 
					 TYPE_INT, PROPERTY_HINT_RANGE, "0, 5000, 1")
	register_setting(SETTINGS_ANIMATION + "zap_starting_velocity", zap_starting_velocity, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.0, 50000.0, 50.0")
	register_setting(SETTINGS_ANIMATION + "zap_steering_force", zap_steering_force, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.0, 50000.0, 50.0")
	
	# Gravity keys
	register_setting(SETTINGS_ANIMATION + "gravity_keys", false, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "gravity_keys_gravity", gravity_keys_gravity, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-100.0, 100.0, 1.0")
	register_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_multiplier", gravity_keys_start_force_multiplier, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-5.0, 5.0, 0.01")
					
	register_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_min", gravity_keys_start_force_x_min, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-2000.0, 2000.0, 1.0")
	register_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_max", gravity_keys_start_force_x_max, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-2000.0, 2000.0, 1.0")
	register_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_min", gravity_keys_start_force_y_min, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-2000.0, 2000.0, 1.0")
	register_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_max", gravity_keys_start_force_y_max, 
					 TYPE_FLOAT, PROPERTY_HINT_RANGE, "-2000.0, 2000.0, 1.0")
					
	# Interface section
	register_setting(SETTINGS_INTERFACE + "editor_ui_volume_percentage", initial_interface_volume_percentage, TYPE_FLOAT,
					 PROPERTY_HINT_RANGE, "0.0, 200.0, 5.0", "Interface Volume")
	register_setting(SETTINGS_INTERFACE + "enabled", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "button_click", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "button_on", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "button_off", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "slider_tick", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "hover", true, TYPE_BOOL)
	register_setting(SETTINGS_INTERFACE + "select_item", true, TYPE_BOOL)


func register_setting(path: String, default_value, type: int = TYPE_BOOL, 
					 hint: int = PROPERTY_HINT_NONE, hint_string: String = "", 
					 display_name: String = "") -> void:
	# Set the setting if it doesn't exist
	if not editor_settings.has_setting(path):
		editor_settings.set_setting(path, default_value)
		
		# Set initial value different from default
		var initial_value = default_value
		if typeof(default_value) == TYPE_BOOL:
			initial_value = !default_value
		elif typeof(default_value) == TYPE_INT or typeof(default_value) == TYPE_FLOAT:
			initial_value = default_value - 1
		
		editor_settings.set_initial_value(path, initial_value, false)
	
	# Always add property info
	var property_info = {
		"name": path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}
	
	if display_name != "":
		property_info["usage"] = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CATEGORY
	
	editor_settings.add_property_info(property_info)

func load_settings_values() -> void:
	# Load master volume
	if editor_settings.has_setting(SETTINGS_CODE_EDITOR + "master_volume_percentage"):
		volume_percentage = editor_settings.get_setting(SETTINGS_CODE_EDITOR + "master_volume_percentage")

	# Code Editor Sounds
	if editor_settings.has_setting(SETTINGS_CODE_EDITOR + "enabled"):
		code_editor_sounds_enabled = editor_settings.get_setting(SETTINGS_CODE_EDITOR + "enabled")

	# Interface
	if editor_settings.has_setting(SETTINGS_INTERFACE + "enabled"):
		editor_interface_sounds_enabled = editor_settings.get_setting(SETTINGS_INTERFACE + "enabled")

	if editor_settings.has_setting(SETTINGS_INTERFACE + "editor_ui_volume_percentage"):
		interface_volume_percentage = editor_settings.get_setting(SETTINGS_INTERFACE + "editor_ui_volume_percentage")

	# Load animation settings
	if editor_settings.has_setting(SETTINGS_ANIMATION + "enabled"):
		delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "enabled")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "standard_delete"):
		standard_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "standard_delete")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "zap_delete_or_gravity_keys_enabled"):
		zap_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "zap_delete_or_gravity_keys_enabled")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "show_deleted_on_tabbing"):
		tabbing_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "show_deleted_on_tabbing")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "max_deleted_chars"):
		max_deleted_characters = editor_settings.get_setting(SETTINGS_ANIMATION + "max_deleted_chars")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "zap_starting_velocity"):
		zap_starting_velocity = editor_settings.get_setting(SETTINGS_ANIMATION + "zap_starting_velocity")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "zap_steering_force"):
		zap_steering_force = editor_settings.get_setting(SETTINGS_ANIMATION + "zap_steering_force")
	
	# Gravity Keys
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys"):
		gravity_keys_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_gravity"):
		gravity_keys_gravity = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_gravity")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_multiplier"):
		gravity_keys_start_force_multiplier = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_multiplier")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_min"):
		gravity_keys_start_force_x_min = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_min")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_max"):
		gravity_keys_start_force_x_max = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_x_max")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_min"):
		gravity_keys_start_force_y_min = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_min")
	if editor_settings.has_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_max"):
		gravity_keys_start_force_y_max = editor_settings.get_setting(SETTINGS_ANIMATION + "gravity_keys_start_force_y_max")
		
		
		
func get_player_enabled(action_type_name: String) -> bool:
	var category_path = SETTINGS_CODE_EDITOR
	var setting_name = action_type_name.to_lower()
	
	if action_type_name.begins_with("INTERFACE_"):
		category_path = SETTINGS_INTERFACE
		setting_name = action_type_name.trim_prefix("INTERFACE_").to_lower()
		
	if editor_settings.has_setting(category_path + setting_name):
		return editor_settings.get_setting(category_path + setting_name)
	
	return true

func on_settings_changed() -> void:
	load_settings_values()

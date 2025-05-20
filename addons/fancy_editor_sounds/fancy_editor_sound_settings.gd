@tool
extends RefCounted
class_name FancyEditorSoundsSettings

# Constants
const SETTINGS_ROOT = "fancy_editor_sounds/"
const SETTINGS_CODE_EDITOR = SETTINGS_ROOT + "code_editor/"
const SETTINGS_ANIMATION = SETTINGS_ROOT + "animation/"
const SETTINGS_INTERFACE = SETTINGS_ROOT + "editor_interface/"

# Settings references
var editor_settings: EditorSettings
var initial_volume_db: int = -35
var initial_max_deleted_characters: int = 50

# Current setting values
var volume_db: int = initial_volume_db
var delete_animations_enabled: bool = true
var standard_delete_animations_enabled: bool = true
var zap_delete_animations_enabled: bool = false
var zap_tabbing_delete_animations_enabled: bool = true
var max_deleted_characters: int = initial_max_deleted_characters

# Dictionary to store player settings references
var sound_player_settings: Dictionary = {}

func _init(p_editor_settings: EditorSettings) -> void:
	editor_settings = p_editor_settings

func initialize() -> void:
	if should_reset_settings():
		print("[Fancy Editor Sounds] Initializing or updating settings structure")
		clean_all_settings()
		setup_settings_structure()
	
	load_settings_values()

func should_reset_settings() -> bool:
	# Define core settings that must exist in the current version
	var core_settings = [
		SETTINGS_ROOT + "volume_db",
		SETTINGS_ANIMATION + "enabled",
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
	register_setting(SETTINGS_ROOT + "volume_db", initial_volume_db, TYPE_FLOAT, 
					 PROPERTY_HINT_RANGE, "-80.0, 0.0, 1.0", "Master Volume")
	
	# Register individual code editor sounds 
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
	register_setting(SETTINGS_ANIMATION + "standard_delete", true, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "zap_delete", false, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "zap_tabbing", true, TYPE_BOOL)
	register_setting(SETTINGS_ANIMATION + "max_deleted_chars", initial_max_deleted_characters, 
					 TYPE_INT, PROPERTY_HINT_RANGE, "0, 5000, 1")
	
	# Interface section
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
		
		# Set initial value different from default to ensure it saves
		var initial_value = default_value
		if typeof(default_value) == TYPE_BOOL:
			initial_value = !default_value
		elif typeof(default_value) == TYPE_INT or typeof(default_value) == TYPE_FLOAT:
			initial_value = default_value - 1
		
		editor_settings.set_initial_value(path, initial_value, false)
		
		# Add property info for proper display
		var property_info = {
			"name": path,
			"type": type,
			"hint": hint,
			"hint_string": hint_string
		}
		
		# Add display name if provided
		if display_name != "":
			property_info["usage"] = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CATEGORY
		
		editor_settings.add_property_info(property_info)

func load_settings_values() -> void:
	# Load master volume
	if editor_settings.has_setting(SETTINGS_ROOT + "volume_db"):
		volume_db = editor_settings.get_setting(SETTINGS_ROOT + "volume_db")
	
	# Load animation settings
	if editor_settings.has_setting(SETTINGS_ANIMATION + "enabled"):
		delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "enabled")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "standard_delete"):
		standard_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "standard_delete")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "zap_delete"):
		zap_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "zap_delete")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "zap_tabbing"):
		zap_tabbing_delete_animations_enabled = editor_settings.get_setting(SETTINGS_ANIMATION + "zap_tabbing")
	
	if editor_settings.has_setting(SETTINGS_ANIMATION + "max_deleted_chars"):
		max_deleted_characters = editor_settings.get_setting(SETTINGS_ANIMATION + "max_deleted_chars")

# Helper function to get player settings
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

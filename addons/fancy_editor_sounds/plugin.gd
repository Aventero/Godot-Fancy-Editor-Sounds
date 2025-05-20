@tool
extends EditorPlugin
class_name FancyEditorSounds

# Import the settings manager
const SettingsManager = preload("res://addons/fancy_editor_sounds/FancyEditorSoundSettings.gd")

#region SOUND
var KEY_DROP: Resource
var KEY_ZAP: Resource
var sound_player_datas: Dictionary
var typing_sounds: Array[Resource]
var settings: FancyEditorSoundsSettings
enum ActionType {
	NONE,
	TYPING,
	DELETING,
	SELECTING,
	SELECTING_ALL,
	SELECTING_WORD,
	DESELECTING,
	CARET_MOVING,
	UNDO,
	REDO,
	COPY,
	PASTE,
	SAVE,
	ZAP_REACHED,
	INTERFACE_BUTTON_CLICK,
	INTERFACE_BUTTON_ON,
	INTERFACE_BUTTON_OFF,
	INTERFACE_SLIDER_TICK,
	INTERFACE_HOVER,
}
enum DeleteDirection {
	LEFT,
	RIGHT,
	LINE,
	SELECTION,
}
enum AnimationType {
	STANDARD,
	ZAP
}
#endregion

#region ANIMATION SETTINGS
var zap_accumulator: int = 0
#endregion

#region EDITOR SCANNING
var last_focused_editor_id: String = ""
var has_editor_focused: bool = false
var editors: Dictionary = {}
var shader_tab_container: TabContainer
#endregion

#region EDITOR INTERFACE
var current_control: Control = null
var current_hover_tree_item: TreeItem = null
var current_hover_list_item: int = 0
var current_slider: EditorSpinSlider = null
var previous_slider_value: float = 0.0
var is_mouse_button_pressed: bool = false
var is_dragging_slider: bool = false
#endregion


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
		
	register_script_editor()
	
	has_editor_focused = false
	
	# Check if any editor has focus
	for editor_id in editors.keys():
		var info: SoundEditorInfo = editors[editor_id]
		if not is_instance_valid(info.code_edit):
			editors.erase(editor_id)
			continue
			
		if info.code_edit.has_focus():
			has_editor_focused = true
			last_focused_editor_id = editor_id
			break
	
	# Always process the last focused editor
	if last_focused_editor_id != "" and editors.has(last_focused_editor_id):
		var info = editors[last_focused_editor_id]
		if is_instance_valid(info.code_edit):
			play_editor_sounds(last_focused_editor_id, info)

#region SETUP

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	initialize()
	get_tree().create_timer(2.0).timeout.connect(find_shader_editor_container)

func initialize() -> void:
	
	settings = FancyEditorSoundsSettings.new(EditorInterface.get_editor_settings())
	settings.initialize()
	
	# Find shader container after UI is fully loaded
	EditorInterface.get_editor_settings().settings_changed.connect(_on_settings_changed)
	
	KEY_DROP = load("res://addons/fancy_editor_sounds/key_drop.tscn")
	KEY_ZAP = load("res://addons/fancy_editor_sounds/key_zap.tscn")
	
	# Init Sounds
	create_sound_player(ActionType.TYPING, 0.7, "res://addons/fancy_editor_sounds/keyboard_sounds/key-press-1.mp3")
	create_sound_player(ActionType.SELECTING, 0.6, "res://addons/fancy_editor_sounds/keyboard_sounds/select-char.wav")
	create_sound_player(ActionType.SELECTING_WORD, 0.5, "res://addons/fancy_editor_sounds/keyboard_sounds/select-all.wav")
	create_sound_player(ActionType.DESELECTING, 0.5, "res://addons/fancy_editor_sounds/keyboard_sounds/deselect.wav")
	create_sound_player(ActionType.SELECTING_ALL, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/select-word.wav")
	create_sound_player(ActionType.CARET_MOVING, 0.2, "res://addons/fancy_editor_sounds/keyboard_sounds/key-movement.mp3")
	create_sound_player(ActionType.REDO, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/key-invalid.wav")
	create_sound_player(ActionType.UNDO, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/key-invalid.wav")
	create_sound_player(ActionType.SAVE, 0.18, "res://addons/fancy_editor_sounds/keyboard_sounds/date-impact.wav")
	create_sound_player(ActionType.DELETING, 0.85, "res://addons/fancy_editor_sounds/keyboard_sounds/key-delete.mp3")
	create_sound_player(ActionType.COPY, 0.4, "res://addons/fancy_editor_sounds/keyboard_sounds/check-on.wav")
	create_sound_player(ActionType.PASTE, 0.2, "res://addons/fancy_editor_sounds/keyboard_sounds/badge-dink-max.wav")
	create_sound_player(ActionType.ZAP_REACHED, 0.3, "res://addons/fancy_editor_sounds/keyboard_sounds/select-char.wav")
	
	create_sound_player(ActionType.INTERFACE_BUTTON_CLICK, 0.3, "res://addons/fancy_editor_sounds/keyboard_sounds/notch-tick.wav")
	create_sound_player(ActionType.INTERFACE_BUTTON_ON, 0.5, "res://addons/fancy_editor_sounds/keyboard_sounds/check-on.wav")
	create_sound_player(ActionType.INTERFACE_BUTTON_OFF, 0.5, "res://addons/fancy_editor_sounds/keyboard_sounds/check-off.wav")
	create_sound_player(ActionType.INTERFACE_HOVER, 0.5, "res://addons/fancy_editor_sounds/keyboard_sounds/button-sidebar-hover-megashort.wav")
	create_sound_player(ActionType.INTERFACE_SLIDER_TICK, 0.2, "res://addons/fancy_editor_sounds/keyboard_sounds/notch-tick-very-short.wav")
	
	load_typing_sounds()
	set_player_volumes()
	
	# Start the plugin basically
	set_process(true)

func create_sound_player(action_type: ActionType, volume_multiplier: float, sound_path: String) -> AudioStreamPlayer:
	# Create the player data with the new parameters
	var player_data: SoundPlayerData = SoundPlayerData.new(volume_multiplier, ActionType.keys()[action_type])
	add_child(player_data.player)
	sound_player_datas[action_type] = player_data
	sound_player_datas[action_type].player.stream = load(sound_path)
	update_player_volume(action_type)
	return player_data.player

func update_player_volume(action_type: ActionType) -> void:
	var player_data = sound_player_datas[action_type]
	
	var volume_db = base_volume_from_percentage(settings.volume_percentage)
	
	# For interface sounds, apply the interface volume adjustment
	if player_data.action_name.begins_with("INTERFACE_"):
		var interface_adjustment = additional_db_from_percentage(settings.interface_volume_percentage)
		volume_db += interface_adjustment
	
	volume_db += 20 * log(player_data.volume_multiplier) / log(10)
	player_data.player.volume_db = volume_db

# Convert percentage to dB
func base_volume_from_percentage(percentage: float) -> float:
	# Map 0% to -80 dB and 100% to 0 dB
	return lerp(-80.0, 0.0, percentage / 100.0)

# Calculate dB adjustment from percentage
func additional_db_from_percentage(percentage: float) -> float:
	if percentage <= 0:
		return -80.0
	else:
		# Convert percentage to dB (100% = 0dB, 200% = +6dB, 50% = -6dB)
		return 20 * log(percentage / 100.0) / log(10)

func load_typing_sounds() -> void:
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-1.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-2.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-3.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-4.mp3"))

#endregion

#region INPUT INTERFACE

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	
	handle_tab_input(event)
	
	if settings.editor_interface_sounds_enabled:
		handle_interface_input(event)

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_S and event.ctrl_pressed and not event.echo and not event.is_released() and has_editor_focused:
			if not settings.code_editor_sounds_enabled:
				return
			play_sound(ActionType.SAVE)

func handle_interface_input(event: InputEvent) -> void:
	await get_tree().process_frame
	var base_control = EditorInterface.get_base_control()
	var focused = base_control.get_viewport().gui_get_hovered_control()
	
	# Track slider dragging state
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Mouse pressed down -> on slider or children?
			var slider = find_parent_slider(focused)
			if slider:
				is_dragging_slider = true
				setup_slider_tracking(slider)
		else:
			# Mouse released - end dragging state
			if is_dragging_slider:
				is_dragging_slider = false
			
			# Update the previous value if we have a slider
			if current_slider != null:
				previous_slider_value = current_slider.value
	
	if current_slider != null:
		if !is_instance_valid(current_slider):
			cleanup_slider_tracking()
		elif !is_dragging_slider && !is_control_related_to_slider(focused, current_slider):
			cleanup_slider_tracking()
	
	# Handle focus when not dragging
	if !is_dragging_slider && is_instance_valid(focused) && current_control != focused:
		handle_focus_hover(focused)
	
		# Setup slider tracking when focus changes to a slider
		var slider = find_parent_slider(focused)
		if slider && !is_dragging_slider:
			setup_slider_tracking(slider)
	
	if focused is Tree:
		handle_tree_interactions(focused, event)
	elif focused is ItemList:
		handle_item_list_interactions(focused, event)
	elif is_control_related_to_slider(focused, current_slider):
		handle_editor_slider_interactions(current_slider, event)
		
	# Handle button clicks
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		handle_button_click(focused, event)

func handle_tab_input(event: InputEvent) -> void:
	
	# Only process tab key events when an editor is focused
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_TAB and has_editor_focused):
		return
		
	# Find which editor is focused
	for editor_id in editors:
		var info: SoundEditorInfo = editors[editor_id]
		if is_instance_valid(info.code_edit) and info.code_edit.has_focus():
			# Set tab_pressed for this specific editor
			info.tab_pressed = true
			info.tab_affected_lines = []
			
			# Store the affected lines
			if info.code_edit.has_selection():
				var start_line = info.code_edit.get_selection_from_line()
				var end_line = info.code_edit.get_selection_to_line()
				
				for line in range(start_line, end_line + 1):
					info.tab_affected_lines.append(info.code_edit.get_line(line))
			else:
				# No selection, just the current line
				info.tab_affected_lines.append(info.code_edit.get_line(info.code_edit.get_caret_line()))
			break

#region SLIDER

func find_parent_slider(control: Control) -> EditorSpinSlider:
	if !is_instance_valid(control):
		return null
		
	if control is EditorSpinSlider:
		return control
	
	var parent = control.get_parent()
	for i in range(3):
		if parent is EditorSpinSlider:
			return parent
		if parent is Control:
			parent = parent.get_parent()
		else:
			break
	
	return null

func is_control_related_to_slider(control: Control, slider: EditorSpinSlider) -> bool:
	if !is_instance_valid(control) or !is_instance_valid(slider):
		return false
	
	# Direct match
	if control == slider:
		return true
	
	# Child of slider
	var parent = control.get_parent()
	for i in range(3):
		if parent == slider:
			return true
		if parent is Control:
			parent = parent.get_parent()
		else:
			break
	
	return false

func setup_slider_tracking(slider: EditorSpinSlider) -> void:
	if current_slider == slider:
		return
	
	# Clean up existing slider
	if current_slider != null and current_slider != slider:
		cleanup_slider_tracking()
	
	current_slider = slider
	previous_slider_value = slider.value
	
	# Connect to value_changed signal if not already connected
	if not slider.is_connected("value_changed", Callable(self, "_on_slider_value_changed")):
		slider.value_changed.connect(_on_slider_value_changed)

func cleanup_slider_tracking() -> void:
	if current_slider != null:
		if is_instance_valid(current_slider) and current_slider.is_connected("value_changed", Callable(self, "_on_slider_value_changed")):
			current_slider.value_changed.disconnect(_on_slider_value_changed)
		current_slider = null

func _on_slider_value_changed(new_value: float) -> void:
	if abs(new_value - previous_slider_value) > 0.001:
		# Determine if value is increasing or decreasing
		var is_increasing = new_value > previous_slider_value
		play_slider_sound(is_increasing)
	previous_slider_value = new_value

func handle_editor_slider_interactions(slider: EditorSpinSlider, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if abs(slider.value - previous_slider_value) > 0.001:
				var is_increasing = slider.value > previous_slider_value
				play_slider_sound(is_increasing)
				previous_slider_value = slider.value

func play_slider_sound(is_increasing: bool) -> void:
	if is_increasing:
		# Higher pitch when increasing
		sound_player_datas[ActionType.INTERFACE_SLIDER_TICK].player.pitch_scale = randf_range(1.0, 1.1)
	else:
		# Lower pitch when decreasing
		sound_player_datas[ActionType.INTERFACE_SLIDER_TICK].player.pitch_scale = randf_range(0.8, 0.9)
	
	play_sound(ActionType.INTERFACE_SLIDER_TICK, false)

#endregion

#region OTHER

func handle_focus_hover(focused: Control) -> void:
	current_control = focused
	if current_control is Button or current_control is LineEdit:
		play_hover_sound()

func handle_tree_interactions(tree: Tree, event: InputEvent) -> void:
	var tree_mouse_pos: Vector2 = tree.get_local_mouse_position()
	var current_hovered_item: TreeItem = tree.get_item_at_position(tree_mouse_pos)
	
	# Handle hover state changes
	if current_hovered_item != current_hover_tree_item:
		current_hover_tree_item = current_hovered_item
		
		# Play sound if valid
		if is_instance_valid(current_hovered_item):
			play_hover_sound()
	
	# Play selection sound, only when actively hovered
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(tree.get_item_at_position(tree_mouse_pos)):
			if current_hovered_item == tree.get_selected():
				play_select_sound()

func handle_item_list_interactions(item_list: ItemList, event: InputEvent) -> void:
	var item_mouse_pos: Vector2 = item_list.get_local_mouse_position()
	var current_hovered_item: int = item_list.get_item_at_position(item_mouse_pos, true)
	
	# Handle hover state changes
	if current_hovered_item != current_hover_list_item:
		current_hover_list_item = current_hovered_item
		
		# Play sound if valid
		if current_hovered_item != -1:
			play_hover_sound()
	
	# Play selection sound, only when actively hovered
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if item_list.is_anything_selected() and current_hovered_item != -1:
			if item_list.get_item_at_position(item_mouse_pos) == item_list.get_selected_items().get(0):
				play_select_sound()

func handle_button_click(control: Control, event: InputEvent) -> void:
	if control is CheckBox or control is OptionButton or control is CheckButton:
		play_option_button_sound(control.button_pressed)
		return
	
	if control is Button:
		play_button_sound(control.button_pressed)

# Helper methods for sound effects
func play_hover_sound() -> void:
	sound_player_datas[ActionType.INTERFACE_HOVER].player.pitch_scale = randf_range(1.0, 1.1)
	play_sound(ActionType.INTERFACE_HOVER, false)

func play_select_sound() -> void:
	sound_player_datas[ActionType.INTERFACE_BUTTON_CLICK].player.pitch_scale = randf_range(1.0, 1.1)
	play_sound(ActionType.INTERFACE_BUTTON_CLICK)

func play_option_button_sound(is_on: bool) -> void:
	if is_on:
		play_sound(ActionType.INTERFACE_BUTTON_ON)
	else:
		play_sound(ActionType.INTERFACE_BUTTON_OFF)

func play_button_sound(is_pressed: bool) -> void:
	if is_pressed:
		sound_player_datas[ActionType.INTERFACE_BUTTON_CLICK].player.pitch_scale = randf_range(1.1, 1.2)
	else:
		sound_player_datas[ActionType.INTERFACE_BUTTON_CLICK].player.pitch_scale = randf_range(0.9, 1.0)
	play_sound(ActionType.INTERFACE_BUTTON_CLICK, true)

#endregion

#endregion

#region SETTINGS

func _on_settings_changed() -> void:
	settings.on_settings_changed()
	set_player_volumes()
	
func set_player_volumes() -> void:
	for action_type in sound_player_datas.keys():
		update_player_volume(action_type)
		
		# Set enabled state
		var player_data = sound_player_datas[action_type]
		player_data.enabled = settings.get_player_enabled(player_data.action_name)
#endregion

#region SOUNDS

func play_sound(action_type: ActionType, should_overwrite_playing: bool = true) -> void:
	var data = sound_player_datas[action_type]
	if not data.enabled:
		return
	
	# Only play a sound if its not already playing
	if not should_overwrite_playing:
		if not data.player.playing:
			data.player.play()
			return
	else:
		data.player.play()

func play_zap_sound() -> void:
	if not settings.code_editor_sounds_enabled:
		return
	
	zap_accumulator += 1
	var accumulator_pitching = clamp(1 + float(zap_accumulator) / 200.0, 1.0, 2.0)
	sound_player_datas[ActionType.ZAP_REACHED].player.pitch_scale = randf_range(0.875, 1.025) * accumulator_pitching
	play_sound(ActionType.ZAP_REACHED, false)

func handle_action(action_type: ActionType, code_edit: CodeEdit, current_selection_length: int, new_selection: String, info: SoundEditorInfo) -> bool:
	if not settings.code_editor_sounds_enabled:
		return false
	
	match action_type:
		ActionType.UNDO:
			play_sound(action_type)
			return true
		ActionType.REDO:
			sound_player_datas[ActionType.REDO].player.pitch_scale = 1.1
			play_sound(action_type)
			return true
		ActionType.COPY:
			play_sound(action_type)
			return true
		ActionType.PASTE:
			sound_player_datas[ActionType.PASTE].player.pitch_scale = 1.5
			play_sound(action_type)
			return true
		ActionType.TYPING:
			play_random_typing_sound()
			return true
		ActionType.DELETING:
			play_sound(action_type)
			return true
		ActionType.SELECTING:
			return handle_selection(code_edit, current_selection_length, new_selection, info)
		ActionType.DESELECTING:
			info.has_unselected = true
			info.selection_length = 0
			play_sound(action_type)
			return true
		ActionType.CARET_MOVING:
			sound_player_datas[ActionType.CARET_MOVING].player.pitch_scale = randf_range(0.9, 1.0)
			play_sound(action_type)
			return true
	return false

func handle_delete_animation(info: SoundEditorInfo) -> void:
	if settings.delete_animations_enabled:
		if settings.zap_delete_animations_enabled:
			play_key_zap_animation(info)
		if settings.standard_delete_animations_enabled: 
			play_delete_animation(info)

func handle_selection(code_edit: CodeEdit, current_selection_length: int, new_selection: String, info: SoundEditorInfo) -> bool:
	var single_select: bool = abs(info.selection_length - current_selection_length) == 1
	var current_selection_mode = code_edit.get_selection_mode()

	match current_selection_mode:
		CodeEdit.SelectionMode.SELECTION_MODE_WORD:
			play_sound(ActionType.SELECTING_WORD)
			return true
		CodeEdit.SelectionMode.SELECTION_MODE_SHIFT, CodeEdit.SelectionMode.SELECTION_MODE_LINE:
			if single_select:
				return play_selection_sound(code_edit, current_selection_length, new_selection, info)
			else:
				play_sound(ActionType.SELECTING_ALL)
				return true
		_:
			return play_selection_sound(code_edit, current_selection_length, new_selection, info)
	return false

func play_selection_sound(code_edit: CodeEdit, selection_length: int, new_selection: String, info: SoundEditorInfo) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_delta = max(0.001, current_time - info.last_selection_time)

	# Calculate selection velocity (chars per second)
	var selection_velocity = abs(selection_length - info.selection_length) / time_delta

	# Base cooldown and pitch calculations
	var selection_cooldown: float = 0.025
	var base_pitch = 0.8

	# Adjust pitch based on both selection length and velocity
	var length_factor = min(selection_length / 500.0, 0.25)
	var velocity_factor = min(selection_velocity / 500.0, 0.25)
	var pitch_scale = base_pitch + length_factor + velocity_factor

	if current_time - info.last_selection_time >= selection_cooldown:
		sound_player_datas[ActionType.SELECTING].player.pitch_scale = pitch_scale * randf_range(0.975, 1.025)
		play_sound(ActionType.SELECTING)

		info.last_selection_time = current_time
		info.selection_length = selection_length
		return true
	else:
		# Just update text (cooldown)
		info.selection_length = selection_length
	return false

func has_editor_changed_state(code_edit: CodeEdit, info: SoundEditorInfo) -> bool:
	# Quick check if anything has changed
	var current_text = code_edit.text
	var has_selection_now = code_edit.has_selection()
	var selection_length = code_edit.get_selected_text().length() if has_selection_now else 0
	
	# Check if nothing has changed
	var nothing_changed = (
		current_text == info.previous_text 
		and code_edit.get_caret_column() == info.caret_column 
		and code_edit.get_caret_line() == info.caret_line
		and has_selection_now == (info.selection_length > 0)
		and selection_length == info.selection_length
	)
	
	# Return true if editor state changed, false otherwise
	return !nothing_changed

func just_pressed_action() -> ActionType:
	
	if Input.is_action_just_pressed("ui_undo") and has_editor_focused:
		return ActionType.UNDO

	if Input.is_action_just_pressed("ui_redo") and has_editor_focused:
		return ActionType.REDO

	if Input.is_action_just_pressed("ui_copy") and has_editor_focused:
		return ActionType.COPY

	if Input.is_action_just_pressed("ui_paste") and has_editor_focused:
		return ActionType.PASTE
	
	return ActionType.NONE

func play_editor_sounds(editor_id: String, info: SoundEditorInfo) -> bool:
	var code_edit: CodeEdit = info.code_edit
	if not code_edit:
		return false
	
	var pressed_action = just_pressed_action()
	
	if not has_editor_changed_state(code_edit, info) and pressed_action == ActionType.NONE:
		return false
		
	if not has_editor_focused:
		has_editor_focused = code_edit.has_focus()

	var current_text = code_edit.text
	var current_char_count = code_edit.text.length()
	var current_caret_column = code_edit.get_caret_column()
	var current_caret_line = code_edit.get_caret_line()
	var caret_changed = (current_caret_column != info.caret_column || current_caret_line != info.caret_line)

	# Determine what changed and in what order
	var action_type = ActionType.NONE

	# Check for selection status
	var has_selection_now = code_edit.has_selection()
	var new_selection = code_edit.get_selected_text()
	var current_selection_length = new_selection.length()

	if has_selection_now && current_selection_length != info.selection_length:
		action_type = ActionType.SELECTING
	elif !has_selection_now && info.selection_length > 0:
		action_type = ActionType.DESELECTING
	elif action_type == ActionType.NONE && caret_changed:
		action_type = ActionType.CARET_MOVING

	# Check for text changes first
	if current_char_count > info.char_count:
		action_type = ActionType.TYPING
	elif current_char_count < info.char_count:
		action_type = ActionType.DELETING
		
	var single_select: bool = abs(info.selection_length - current_selection_length) == 1
	
	if pressed_action != ActionType.NONE:
		action_type = pressed_action

	
	var sound_played: bool = handle_action(action_type, code_edit, current_selection_length, new_selection, info)
	if action_type == ActionType.DELETING:
		handle_delete_animation(info)
	
	info.previous_caret_pos = code_edit.get_caret_draw_pos()
	info.previous_text = current_text
	info.previous_line = code_edit.get_line(current_caret_line)
	info.char_count = current_char_count
	info.caret_column = current_caret_column
	info.caret_line = current_caret_line
	info.previous_line_count = code_edit.get_line_count()
	info.previous_selection = code_edit.get_selected_text()

	if has_selection_now:
		info.has_unselected = false
		info.selection_length = current_selection_length
	else:
		info.selection_length = 0
	
	if should_reset_zap_accumulator(action_type):
		zap_accumulator = 0
		
	info.tab_pressed = false

	return sound_played

func play_random_typing_sound() -> void:
	var random_index = randi() % typing_sounds.size()
	sound_player_datas[ActionType.TYPING].player.stream = typing_sounds[random_index]
	play_sound(ActionType.TYPING)

#endregion

#region ANIMATION

func check_deleted_text(info: SoundEditorInfo, animation_type: AnimationType) -> String:
	if info.tab_pressed:  # Use editor-specific tab_pressed
		if not settings.zap_tabbing_delete_animations_enabled:
			return ""
		
		# Ignore when Standard Animation
		if animation_type == AnimationType.STANDARD: 
			return ""
			
		# Single Line Tabbed
		if info.tab_affected_lines.size() == 1:
			return info.tab_affected_lines[0]
		
		# Multiple lines Tabbed
		return "\n".join(info.tab_affected_lines)
	
	var current_line_pos: int = info.code_edit.get_caret_line()
	var previous_line: String = info.previous_line
	var current_line: String = info.code_edit.get_line(current_line_pos)
	var current_col = info.code_edit.get_caret_column()

	# First check if there was a selection that was deleted
	if info.previous_selection.length() > 0 && animation_type == AnimationType.ZAP:
		return info.previous_selection

	# Line deletion
	if info.code_edit.get_line_count() < info.previous_line_count:
		if animation_type == AnimationType.STANDARD:
			return ""
		
		# Backspace at beginning of line
		if current_line_pos < info.caret_line && current_col > 0:
			return "\n"
		
		# Ctrl+X, multiple backspace...
		return previous_line

	# Backspace Delete
	if current_col < info.caret_column:
		var deletion_start = current_col
		var deletion_end = info.caret_column
		return previous_line.substr(deletion_start, deletion_end - deletion_start)

	# Delete key
	if current_col == info.caret_column:
		var chars_deleted = previous_line.length() - current_line.length()
		if chars_deleted > 0:
			return previous_line.substr(current_col, chars_deleted)
	return ""

func play_delete_animation(info: SoundEditorInfo) -> void:
	if not is_instance_valid(info.code_edit):
		return
	
	var deleted_char = check_deleted_text(info, AnimationType.STANDARD)
	var falling_key: KeyDrop = KEY_DROP.instantiate()
	var line_height = info.code_edit.get_line_height()
	var adjusted_pos = info.code_edit.get_caret_draw_pos() + Vector2(4, -line_height/2.0)
	falling_key.position = adjusted_pos
	falling_key.set_key(deleted_char, info.code_edit.get_theme_font_size("font_size", "CodeEdit"))
	info.code_edit.add_child(falling_key)

func get_selection_base_position(info: SoundEditorInfo) -> Vector2:
	var selection_from_line = info.code_edit.get_selection_from_line()
	var selection_to_line = info.code_edit.get_selection_to_line()
	
	# Which is the base line? (Top or bottom)
	var base_line = selection_from_line
	if selection_from_line > selection_to_line:
		# Selection from bottom to top
		base_line = selection_to_line
	
	var rect = info.code_edit.get_rect_at_line_column(base_line, 0)
	return Vector2(rect.position + Vector2i(0, rect.size.y / 2))
	
func play_key_zap_animation(info: SoundEditorInfo) -> void:
	if not is_instance_valid(info.code_edit):
		return
	
	var deleted_chars: String = check_deleted_text(info, AnimationType.ZAP)
	if deleted_chars.is_empty():
		return
	
	var base_pos = get_animation_base_position(info, deleted_chars)
	var all_char_positions = calculate_char_positions(info, deleted_chars, base_pos)
	spawn_zap_characters(info, all_char_positions)

func get_animation_base_position(info: SoundEditorInfo, deleted_chars: String) -> Vector2:
	var lines = deleted_chars.split("\n")
	var is_likely_cut = info.code_edit.get_line_count() < info.previous_line_count
	if info.tab_pressed or lines.size() > 1 or is_likely_cut:
		return get_selection_base_position(info)
	else:
		return info.code_edit.get_caret_draw_pos()

func calculate_char_positions(info: SoundEditorInfo, deleted_chars: String, base_pos: Vector2) -> Array:
	var lines = deleted_chars.split("\n")
	var line_height = info.code_edit.get_line_height()
	var font_size = info.code_edit.get_theme_font_size("font_size", "CodeEdit")
	var char_width = font_size * 0.6
	var tab_width = info.code_edit.get_tab_size() * char_width
	
	var char_positions = []
	var valid_char_count = 0
	for line_idx in range(lines.size()):
		var line = lines[line_idx]
		var y_offset = line_idx * line_height
		var current_x_offset = 0.0
		
		for char_idx in range(line.length()):
			var character = line[char_idx]
			
			if character == "\t":
				current_x_offset += tab_width
				continue
			elif character == " " or character == "\n" or character == "\r":
				current_x_offset += char_width
				continue
			
			valid_char_count += 1
			if valid_char_count <= settings.max_deleted_characters:
				char_positions.append({
					"char": character,
					"position": base_pos + Vector2(current_x_offset, -line_height/2.0 + y_offset)
				})
			else:
				# Reached max deleted, set random char indexes for remaining chars
				var random_idx = randi() % valid_char_count
				if random_idx < settings.max_deleted_characters:
					char_positions[random_idx] = {
						"char": character,
						"position": base_pos + Vector2(current_x_offset, -line_height/2.0 + y_offset)
					}
			
			current_x_offset += char_width
	
	return char_positions

func spawn_zap_characters(info: SoundEditorInfo, char_positions: Array) -> void:
	var font_size = info.code_edit.get_theme_font_size("font_size", "CodeEdit")
	for char_info in char_positions:
		var zapping_key: KeyZap = KEY_ZAP.instantiate()
		info.code_edit.add_child(zapping_key)
		zapping_key.position = char_info.position
		zapping_key.set_key(char_info.char, font_size, self)

func should_reset_zap_accumulator(action_type: ActionType) -> bool:
	match action_type:
		ActionType.NONE, ActionType.SELECTING, ActionType.DESELECTING, ActionType.DELETING:
			return false
	return true

#endregion

#region REGISTER EDITORS

func add_new_editor(code_edit: CodeEdit, editor_id: String) -> void:
	if not editors.has(editor_id):
		editors[editor_id] = SoundEditorInfo.new(code_edit)

func register_script_editor() -> void:
	var current_editor = EditorInterface.get_script_editor().get_current_editor()
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			# Create unique ID for each script editor
			var script_path = EditorInterface.get_script_editor().get_current_script().resource_path
			var editor_id = "script_editor_" + script_path
			
			if not editors.has(editor_id):
				add_new_editor(code_edit, editor_id)
			else:
				editors[editor_id].code_edit = code_edit

func find_shader_editor_container() -> void:
	var base_control: Control = EditorInterface.get_base_control()
	var shader_file_editor_node: Node = find_node_by_class_name(base_control, "ShaderFileEditor")
	if shader_file_editor_node:
		var parent: Node = shader_file_editor_node.get_parent()
		var shader_create_node: Node = find_node_by_class_name(parent, "ShaderCreateDialog")
		for child in shader_create_node.get_parent().get_children():
			if child is TabContainer:
				shader_tab_container = child
				
	if not shader_tab_container:
		printerr("[Fancy Editor Sounds] Unable not find the shader tab container. (Sounds wont play inside shader editor)")
		return
	else:
		shader_tab_container.tab_changed.connect(_on_shader_tab_changed)
		initial_shader_editor_lookup(shader_tab_container)

func _on_shader_tab_changed(tab: int) -> void:
	add_shader_edit(shader_tab_container, tab)

func find_node_by_class_name(node: Node, class_string: String) -> Node:
	if node.get_class() == class_string:
		return node;
	for child in node.get_children():
		var result: Node = find_node_by_class_name(child, class_string)
		if result:
			return result
	return null

func add_shader_edit(container: TabContainer, tab_number: int) -> void:
	if not is_instance_valid(container):
		return
	
	var text_shader_editor = container.get_tab_control(tab_number)
	if not text_shader_editor or "TextShaderEditor" not in text_shader_editor.name: 
		return
	
	var previous_editors = editors.duplicate()
	
	# Find the CodeEdit component(s) in this text_shader_editor
	var code_edit: CodeEdit = find_node_by_class_name(text_shader_editor, "CodeEdit")
	var editor_id = text_shader_editor.name + "_" + str(code_edit)
	if not previous_editors.has(editor_id):
		add_new_editor(code_edit, editor_id)
	else:
		editors[editor_id].code_edit = code_edit

func initial_shader_editor_lookup(container: TabContainer) -> void:
	if not is_instance_valid(container):
		return

	for i in range(container.get_tab_count()):
		add_shader_edit(container, i)

#endregion

#region CLEANUP
func _exit_tree() -> void:
	for data: SoundPlayerData in sound_player_datas.values():
		data.player.queue_free()
	set_process(false)

func _disable_plugin() -> void:
	settings.clean_all_settings()

#endregion

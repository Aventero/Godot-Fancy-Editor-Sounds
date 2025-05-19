@tool
extends EditorPlugin
class_name FancyEditorSounds

#region SOUND
var KEY_DROP: Resource
var KEY_ZAP: Resource
var sound_player_datas: Dictionary
var typing_sounds: Array[Resource]
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
	BUTTON_ON,
	BUTTON_OFF,
	SLIDER_TICK,
	HOVER,
	SELECT_ITEM,
}
enum DeleteDirection {
	LEFT,
	RIGHT,
	LINE,
	SELECTION,
}
#endregion

#region SETTINGS
const initial_volume_db: int = -35
const SOUND_SETTINGS_PATH = "fancy_editor_sounds/"
const SETTINGS_VOLUME_PATH = SOUND_SETTINGS_PATH + "volume_db"
const DELETE_ANIMATION_PATH = SOUND_SETTINGS_PATH + "delete_animations"
const DELETE_STANDARD_ANIMATION_PATH = DELETE_ANIMATION_PATH + " standard"
const DELETE_ZAP_ANIMATION_PATH = DELETE_ANIMATION_PATH + " zap"
var volume_db: int = initial_volume_db
var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
var delete_animations_enabled: bool = true
var zap_delete_animations_enabled: bool = true
var zap_accumulator: int = 0
var standard_delete_animations_enabled: bool = true
#endregion

#region EDITOR SCANNING
var has_editor_focused: bool = false
var editors: Dictionary = {}
var shader_tab_container: TabContainer
#endregion

#region NORMAL_EDITOR
var current_control: Control = null
var current_hover_tree_item: TreeItem = null
var current_hover_list_item: int = 0
#endregion

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	_initialize()
	get_tree().create_timer(2.0).timeout.connect(find_shader_editor_container)

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_S and event.ctrl_pressed and not event.echo and not event.is_released() and has_editor_focused:
			play_sound(ActionType.SAVE)

func _exit_tree() -> void:
	for data: SoundPlayerData in sound_player_datas.values():
		data.player.queue_free()
	set_process(false)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	register_script_editor()

	var sound_played: bool = false
	has_editor_focused = false
	for editor_id: String in editors.keys():
		var info: SoundEditorInfo = editors[editor_id]
		if not is_instance_valid(info.code_edit):
			editors.erase(editor_id)
			continue
		if not sound_played:
			sound_played = play_editor_sounds(editor_id, info)

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	await get_tree().process_frame
	var base_control = EditorInterface.get_base_control()
	var focused = base_control.get_viewport().gui_get_hovered_control()

	# Focus switched
	if is_instance_valid(focused) and current_control != focused:
		current_control = focused
		if current_control is Button or current_control is LineEdit:
			sound_player_datas[ActionType.HOVER].player.pitch_scale = randf_range(1.0, 1.1)
			play_sound(ActionType.HOVER, false)
	
	if focused is Tree:
		var tree_mouse_pos: Vector2 = focused.get_local_mouse_position()
		var current_hovered_item: TreeItem = focused.get_item_at_position(tree_mouse_pos)
		
		# Play Hover sound
		if is_instance_valid(current_hovered_item) and current_hover_tree_item != current_hovered_item:
			current_hover_tree_item = current_hovered_item
			sound_player_datas[ActionType.HOVER].player.pitch_scale = randf_range(1.0, 1.1)
			play_sound(ActionType.HOVER, false)
		
		# Play selection sound, only when actively hovered
		if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(focused.get_item_at_position(tree_mouse_pos)):
				if current_hovered_item == focused.get_selected():
					sound_player_datas[ActionType.SELECT_ITEM].player.pitch_scale = randf_range(1.0, 1.2)
					play_sound(ActionType.SELECT_ITEM)
				
	if focused is ItemList:
		var item_mouse_pos: Vector2 = focused.get_local_mouse_position()
		var current_hovered_item: int  = focused.get_item_at_position(item_mouse_pos, true)
		var is_hovering_over_any_item: bool = current_hovered_item != -1
		var is_hovering_over_new_item: bool = is_hovering_over_any_item and current_hover_list_item != current_hovered_item
		
		# Play hover sound
		if is_hovering_over_new_item:
			current_hover_list_item = current_hovered_item
			sound_player_datas[ActionType.HOVER].player.pitch_scale = randf_range(1.0, 1.1)
			play_sound(ActionType.HOVER, false)
		
		# Play selection sound, only when actively hovered
		if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if focused.is_anything_selected() and is_hovering_over_any_item:
				if focused.get_item_at_position(item_mouse_pos) == focused.get_selected_items().get(0):
					sound_player_datas[ActionType.SELECT_ITEM].player.pitch_scale = randf_range(1.0, 1.2)
					play_sound(ActionType.SELECT_ITEM)
		
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		if focused is Button:
			if focused.button_pressed:
				play_sound(ActionType.BUTTON_ON)
			else:
				play_sound(ActionType.BUTTON_OFF)
		
func play_button_click_sound() -> void:
	play_sound(ActionType.COPY)

func _on_settings_changed() -> void:
	if editor_settings.has_setting(SETTINGS_VOLUME_PATH):
		volume_db = editor_settings.get_setting(SETTINGS_VOLUME_PATH)

		for player_data: SoundPlayerData in sound_player_datas.values():
			var setting_enabled_path: String = SOUND_SETTINGS_PATH + player_data.action_name
			player_data.player.volume_db = volume_db * player_data.volume_multiplier
			
			if editor_settings.has_setting(setting_enabled_path):
				player_data.enabled = editor_settings.get_setting(setting_enabled_path)
			
		if editor_settings.has_setting(DELETE_ANIMATION_PATH):
			delete_animations_enabled = editor_settings.get_setting(DELETE_ANIMATION_PATH)
		
		if editor_settings.has_setting(DELETE_STANDARD_ANIMATION_PATH):
			standard_delete_animations_enabled = editor_settings.get_setting(DELETE_STANDARD_ANIMATION_PATH)
		
		if editor_settings.has_setting(DELETE_ZAP_ANIMATION_PATH):
			zap_delete_animations_enabled = editor_settings.get_setting(DELETE_ZAP_ANIMATION_PATH)


func create_sound_player(action_type: ActionType, volume_multiplier, sound_path: String) -> AudioStreamPlayer:
	var player_data: SoundPlayerData = SoundPlayerData.new(volume_db, volume_multiplier, ActionType.keys()[action_type])
	player_data.volume_multiplier = volume_multiplier
	player_data.player.volume_db = volume_db * player_data.volume_multiplier
	add_child(player_data.player)
	sound_player_datas[action_type] = player_data
	sound_player_datas[action_type].player.stream = load(sound_path)
	return player_data.player

func _initialize() -> void:
	
	KEY_DROP = load("res://addons/fancy_editor_sounds/key_drop.tscn")
	KEY_ZAP = load("res://addons/fancy_editor_sounds/key_zap.tscn")
	
	# Find shader container after UI is fully loaded
	editor_settings.settings_changed.connect(_on_settings_changed)
	
	# Init Sounds
	create_sound_player(ActionType.TYPING, 1.1, "res://addons/fancy_editor_sounds/keyboard_sounds/key-press-1.mp3")
	create_sound_player(ActionType.SELECTING, 1.2, "res://addons/fancy_editor_sounds/keyboard_sounds/select-char.wav")
	create_sound_player(ActionType.SELECTING_WORD, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/select-all.wav")
	create_sound_player(ActionType.DESELECTING, 1.3, "res://addons/fancy_editor_sounds/keyboard_sounds/deselect.wav")
	create_sound_player(ActionType.SELECTING_ALL, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/select-word.wav")
	create_sound_player(ActionType.CARET_MOVING, 1.5, "res://addons/fancy_editor_sounds/keyboard_sounds/key-movement.mp3")
	create_sound_player(ActionType.REDO, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/key-invalid.wav")
	create_sound_player(ActionType.UNDO, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/key-invalid.wav")
	create_sound_player(ActionType.SAVE, 1.5, "res://addons/fancy_editor_sounds/keyboard_sounds/date-impact.wav")
	create_sound_player(ActionType.DELETING, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/key-delete.mp3")
	create_sound_player(ActionType.COPY, 1.0, "res://addons/fancy_editor_sounds/keyboard_sounds/check-on.wav")
	create_sound_player(ActionType.PASTE, 1.3, "res://addons/fancy_editor_sounds/keyboard_sounds/badge-dink-max.wav")
	create_sound_player(ActionType.ZAP_REACHED, 1.3, "res://addons/fancy_editor_sounds/keyboard_sounds/select-char.wav")
	create_sound_player(ActionType.BUTTON_ON, 1.2, "res://addons/fancy_editor_sounds/keyboard_sounds/check-on.wav")
	create_sound_player(ActionType.BUTTON_OFF, 1.2, "res://addons/fancy_editor_sounds/keyboard_sounds/check-off.wav")
	create_sound_player(ActionType.HOVER, 1.3, "res://addons/fancy_editor_sounds/keyboard_sounds/button-sidebar-hover-megashort.wav")
	create_sound_player(ActionType.SELECT_ITEM, 1.3, "res://addons/fancy_editor_sounds/keyboard_sounds/notch-tick.wav")
	
	load_typing_sounds()
	register_sound_settings()
	
	# Start the plugin basically
	set_process(true)

func load_typing_sounds() -> void:
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-1.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-2.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-3.mp3"))
	typing_sounds.append(load("res://addons/fancy_editor_sounds/keyboard_sounds/key-press-4.mp3"))

func add_new_editor(code_edit: CodeEdit, editor_id: String) -> void:
	if not editors.has(editor_id):
		editors[editor_id] = SoundEditorInfo.new(code_edit)

func play_random_typing_sound() -> void:
	var random_index = randi() % typing_sounds.size()
	sound_player_datas[ActionType.TYPING].player.stream = typing_sounds[random_index]
	play_sound(ActionType.TYPING)

func _disable_plugin() -> void:
	if editor_settings.has_setting(SETTINGS_VOLUME_PATH):
		editor_settings.erase(SETTINGS_VOLUME_PATH)
		for player_data: SoundPlayerData in sound_player_datas.values():
			var sound_player_setting: String = SOUND_SETTINGS_PATH + player_data.action_name
			if editor_settings.has_setting(sound_player_setting):
				editor_settings.erase(sound_player_setting)
		editor_settings.erase(DELETE_ANIMATION_PATH)
		editor_settings.erase(DELETE_STANDARD_ANIMATION_PATH)
		editor_settings.erase(DELETE_ZAP_ANIMATION_PATH)

func register_animation_setting(path: String, default_enabled: bool) -> bool:
	# Delete Animation setting
	if not editor_settings.has_setting(path):
		editor_settings.set_setting(path, default_enabled)
		editor_settings.set_initial_value(path, false, false)
		editor_settings.add_property_info({
			"name": path,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})
	
	return editor_settings.get_setting(path)

func register_sound_settings() -> void:
	# Volume setting
	if not editor_settings.has_setting(SETTINGS_VOLUME_PATH):
		# Set the setting to a value DIFFERENT from the initial value
		editor_settings.set_setting(SETTINGS_VOLUME_PATH, initial_volume_db)
		editor_settings.set_initial_value(SETTINGS_VOLUME_PATH, initial_volume_db - 1, false)
		editor_settings.add_property_info({
			"name": SETTINGS_VOLUME_PATH,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80, 0, 1"
		})
	else:
		volume_db = editor_settings.get_setting(SETTINGS_VOLUME_PATH)

	delete_animations_enabled = register_animation_setting(DELETE_ANIMATION_PATH, true)
	standard_delete_animations_enabled = register_animation_setting(DELETE_STANDARD_ANIMATION_PATH, true)
	zap_delete_animations_enabled = register_animation_setting(DELETE_ZAP_ANIMATION_PATH, false)
	
	# Setting for each sound
	for player_data: SoundPlayerData in sound_player_datas.values():
		var setting_name: String = SOUND_SETTINGS_PATH + player_data.action_name
		if not editor_settings.has_setting(setting_name):
			editor_settings.set_setting(setting_name, true)
			editor_settings.set_initial_value(setting_name, false, false)
			editor_settings.add_property_info({
				"name": setting_name,
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"hint_string": ""
			})
		else:
			player_data.enabled = editor_settings.get_setting(setting_name)

func register_script_editor() -> void:
	var current_editor = EditorInterface.get_script_editor().get_current_editor()
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			# Use a consistent ID for the script editor
			var editor_id = "script_editor"

			if not editors.has(editor_id):
				add_new_editor(code_edit, editor_id)
			else:
				editors[editor_id].code_edit = code_edit

func play_editor_sounds(editor_id: String, info: SoundEditorInfo) -> bool:
	var code_edit: CodeEdit = info.code_edit
	if not code_edit:
		return false
	
	if not has_editor_focused:
		has_editor_focused = code_edit.has_focus()

	var current_text = code_edit.text
	var current_char_count = code_edit.text.length()
	var current_caret_column = code_edit.get_caret_column()
	var current_caret_line = code_edit.get_caret_line()
	var caret_changed = (current_caret_column != info.caret_column|| current_caret_line != info.caret_line)

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

	if Input.is_action_just_pressed("ui_undo") and has_editor_focused:
		action_type = ActionType.UNDO

	if Input.is_action_just_pressed("ui_redo") and has_editor_focused:
		action_type = ActionType.REDO

	if Input.is_action_just_pressed("ui_copy") and has_editor_focused:
		action_type = ActionType.COPY

	if Input.is_action_just_pressed("ui_paste") and has_editor_focused:
		action_type = ActionType.PASTE
	
	var sound_played: bool = handle_action(action_type, code_edit, current_selection_length, new_selection, info)
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

	return sound_played

func check_deleted_text(info: SoundEditorInfo) -> String:
	var deleted_text = ""
	var current_line_pos: int = info.code_edit.get_caret_line()
	var previous_line: String = info.previous_line
	var current_line: String = info.code_edit.get_line(current_line_pos)
	var current_col = info.code_edit.get_caret_column()
	var current_lines: int = info.code_edit.get_line_count()

	if info.caret_line == current_line_pos:
		if current_line.length() != previous_line.length():
			var chars_deleted = previous_line.length() - current_line.length()
			var dir: DeleteDirection = DeleteDirection.LINE
			if current_col < info.caret_column:
				dir = DeleteDirection.LEFT
			if current_col > info.caret_column:
				dir = DeleteDirection.RIGHT
			if current_lines < info.previous_line_count:
				dir = DeleteDirection.LINE

			var deleted_lines: int = abs(info.previous_line_count - current_lines)
			if current_col == info.caret_column && deleted_lines == 0:
				dir = DeleteDirection.SELECTION

			match dir:
				DeleteDirection.SELECTION:
					deleted_text = info.previous_selection
				DeleteDirection.LINE:
					deleted_text = ""
				DeleteDirection.LEFT:
					var start_pos = current_col
					deleted_text = previous_line.substr(start_pos, chars_deleted)
				DeleteDirection.RIGHT:
					deleted_text = previous_line.substr(current_col, chars_deleted)

	return deleted_text

func play_delete_animation(info: SoundEditorInfo) -> void:
	if not is_instance_valid(info.code_edit):
		return
	
	var deleted_char = check_deleted_text(info)
	var falling_key: KeyDrop = KEY_DROP.instantiate()
	var line_height = info.code_edit.get_line_height()
	var adjusted_pos = info.code_edit.get_caret_draw_pos() + Vector2(4, -line_height/2.0)
	falling_key.position = adjusted_pos
	falling_key.set_key(deleted_char, info.code_edit.get_theme_font_size("font_size", "CodeEdit"))
	info.code_edit.add_child(falling_key)
	
func play_key_zap_animation(info: SoundEditorInfo) -> void:
	if not is_instance_valid(info.code_edit):
		return
	
	var deleted_chars = check_deleted_text(info)
	for deleted_char in deleted_chars:
		var zapping_key: KeyZap = KEY_ZAP.instantiate()
		var line_height = info.code_edit.get_line_height()
		var adjusted_pos = info.code_edit.get_caret_draw_pos() + Vector2(4, -line_height/2.0)
		info.code_edit.add_child(zapping_key)
		zapping_key.position = adjusted_pos
		zapping_key.set_key(deleted_char, info.code_edit.get_theme_font_size("font_size", "CodeEdit"), self)
	
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
	zap_accumulator += 1
	var accumulator_pitching = clamp(1 + float(zap_accumulator) / 200.0, 1.0, 2.0)
	sound_player_datas[ActionType.ZAP_REACHED].player.pitch_scale = randf_range(0.875, 1.025) * accumulator_pitching
	play_sound(ActionType.ZAP_REACHED, false)

func should_reset_zap_accumulator(action_type: ActionType) -> bool:
	match action_type:
		ActionType.NONE, ActionType.SELECTING, ActionType.DESELECTING, ActionType.DELETING:
			return false
	return true

func handle_action(action_type: ActionType, code_edit: CodeEdit, current_selection_length: int, new_selection: String, info: SoundEditorInfo) -> bool:
	match action_type:
		ActionType.UNDO:
			play_sound(action_type)
			return true
		ActionType.REDO:
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
			# Delete Animations
			if delete_animations_enabled:
				if zap_delete_animations_enabled:
					play_key_zap_animation(info)
				if standard_delete_animations_enabled: 
					play_delete_animation(info)
			return true
		ActionType.SELECTING:
			return handle_selection(code_edit, current_selection_length, new_selection, info)
		ActionType.DESELECTING:
			info.has_unselected = true
			info.selection_length = 0
			play_sound(action_type)
			return true
		ActionType.CARET_MOVING:
			play_sound(action_type)
			return true
	return false

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
	var time_delta = max(0.001, current_time - info.last_selection_time)  # Avoid division by zero

	# Calculate selection velocity (chars per second) dasd
	var selection_velocity = abs(selection_length - info.selection_length) / time_delta

	# Base cooldown and pitch calculations
	var selection_cooldown: float = 0.025
	var base_pitch = 0.8

	# Adjust pitch based on both selection length and velocity
	var length_factor = min(selection_length / 500.0, 0.25)
	var velocity_factor = min(selection_velocity / 500.0, 0.25)
	var pitch_scale = base_pitch + length_factor + velocity_factor

	if current_time - info.last_selection_time >= selection_cooldown:
		# Add slight randomization for variety
		sound_player_datas[ActionType.SELECTING].player.pitch_scale = pitch_scale * randf_range(0.975, 1.025)
		play_sound(ActionType.SELECTING)

		# Update tracking variables
		info.last_selection_time = current_time
		info.selection_length = selection_length
		return true
	else:
		# Still update the selected text but don't play sound
		info.selection_length = selection_length
	return false

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

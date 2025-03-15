class_name SoundEditorInfo
extends RefCounted

var code_edit: CodeEdit
var char_count: int
var caret_column: int
var caret_line: int
var previous_text: String = ""
var selection_length: int
var has_unselected: bool
var last_selection_time: float
var previous_line: String
var previous_selection: String
var previous_caret_pos: Vector2
var previous_line_count: int

func _init(_code_edit: CodeEdit) -> void:
	code_edit = _code_edit
	char_count = _code_edit.text.length()
	caret_column = _code_edit.get_caret_column()
	caret_line = _code_edit.get_caret_line()
	selection_length = 0
	has_unselected = false
	last_selection_time = 0.0
	previous_text = _code_edit.text
	previous_line = _code_edit.get_line(caret_line)
	previous_caret_pos = _code_edit.get_caret_draw_pos()
	previous_line_count = _code_edit.get_line_count()
	previous_selection = _code_edit.get_selected_text()

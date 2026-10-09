class_name TextKeyboard extends Control

const COLUMNS = 12
const LOWER = ["1234567890-=", "qwertyuiop/_", "asdfghjkl:{}", "zxcvbnm,.'~$"]
const UPPER = ["!@#%^&*()\"+;", "QWERTYUIOP\\|", "ASDFGHJKL?[]", "ZXCVBNM<>`~$"]
const ACTION_ROW = [["shift", "Shift", 3], ["space", "Space", 5], ["delete", "Del", 2], ["done", "Done", 2]]

var prompt = ""
var text = ""
var password = false
var shifted = false
var keys: Array = []
var index = 0
var _column = 0
var on_done: Callable = Callable()
var on_cancel: Callable = Callable()
var typed_frame = -1
var cursor = 0

func set_text(value: String):
	text = value
	cursor = value.length()
	queue_redraw()

func move_cursor(delta: int):
	cursor = clampi(cursor + delta, 0, text.length())
	queue_redraw()

static func insert_at(current: String, at: int, typed: String) -> String:
	return current.left(at) + typed + current.substr(at)

static func delete_before(current: String, at: int) -> String:
	return current if at <= 0 else current.left(at - 1) + current.substr(at)

func type_text(typed: String):
	text = insert_at(text, cursor, typed)
	cursor += typed.length()
	queue_redraw()

static func build_keys(upper: bool) -> Array:
	var result = []
	var rows = UPPER if upper else LOWER
	for row in range(rows.size()):
		for col in range(rows[row].length()):
			result.append({"row": row, "col": col, "span": 1, "type": "char", "label": rows[row][col], "char": rows[row][col]})
	var col = 0
	for action in ACTION_ROW:
		result.append({"row": rows.size(), "col": col, "span": action[2], "type": action[0], "label": action[1], "char": " " if action[0] == "space" else ""})
		col += action[2]
	return result

static func apply_key(current: String, key: Dictionary) -> String:
	match key.type:
		"char", "space":
			return current + key.char
		"delete":
			return current.left(-1) if current != "" else current
	return current

static func key_in_row(all_keys: Array, row: int, column: int) -> int:
	for i in range(all_keys.size()):
		var key = all_keys[i]
		if key.row == row and column >= key.col and column < key.col + key.span:
			return i
	return -1

func _init():
	keys = build_keys(false)

func rows() -> int:
	return keys[-1].row + 1

func set_shifted(value: bool):
	shifted = value
	keys = build_keys(shifted)
	queue_redraw()

func on_delete() -> bool:
	return index >= 0 and index < keys.size() and keys[index].type == "delete"

func press(i: int) -> bool:
	var key = keys[i]
	if key.type == "done":
		return true
	if key.type == "shift":
		set_shifted(not shifted)
		return false
	if key.type == "delete":
		backspace()
	elif key.char != "":
		type_text(key.char)
	return false

func type_key(event: InputEventKey) -> String:
	match event.keycode:
		KEY_BACKSPACE:
			backspace()
			return ""
		KEY_ENTER, KEY_KP_ENTER:
			return "done"
		KEY_ESCAPE:
			return "cancel"
		KEY_LEFT:
			move_cursor(-1)
			return ""
		KEY_RIGHT:
			move_cursor(1)
			return ""
		KEY_HOME:
			move_cursor(-text.length())
			return ""
		KEY_END:
			move_cursor(text.length())
			return ""
	if event.unicode >= 32:
		type_text(char(event.unicode))
	return ""

func _input(event):
	if not event is InputEventKey or not is_visible_in_tree():
		return
	typed_frame = Engine.get_process_frames()
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	match type_key(event):
		"done":
			Global.waiting_for_confirm_release = true
			if on_done.is_valid():
				on_done.call()
		"cancel":
			if on_cancel.is_valid():
				on_cancel.call()

func backspace():
	if cursor <= 0:
		return
	text = delete_before(text, cursor)
	cursor -= 1
	queue_redraw()

func move(dx: int, dy: int):
	var key = keys[index]
	if dy != 0:
		var row = posmod(key.row + dy, rows())
		var found = key_in_row(keys, row, _column)
		index = found if found >= 0 else index
	elif dx != 0:
		var row_keys = range(keys.size()).filter(func(i): return keys[i].row == key.row)
		var at = row_keys.find(index)
		index = row_keys[posmod(at + dx, row_keys.size())]
		_column = keys[index].col
	queue_redraw()

func pick(found: int):
	index = found
	_column = keys[index].col
	queue_redraw()

func field_height() -> float:
	return size.y * 0.3

func cell_size() -> Vector2:
	return Vector2(size.x / COLUMNS, (size.y - field_height()) / rows())

func index_at(local: Vector2) -> int:
	var cell = cell_size()
	var y = local.y - field_height()
	if local.x < 0 or y < 0 or cell.x <= 0 or cell.y <= 0:
		return -1
	return key_in_row(keys, int(y / cell.y), int(local.x / cell.x))

func shown_text() -> String:
	return "•".repeat(text.length()) if password else text

func _draw():
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	var font: Font = Global.font if Global.font != null else ThemeDB.fallback_font
	var field = field_height()
	var prompt_size = int(field * 0.22)
	draw_string(font, Vector2(0, prompt_size), prompt, HORIZONTAL_ALIGNMENT_LEFT, size.x, prompt_size, Color(fg, 0.6))
	var box = Rect2(0, prompt_size * 1.5, size.x, field - prompt_size * 2.0)
	draw_rect(box, bg)
	draw_rect(box, Color(fg, 0.5), false, 2.0)
	var text_size = int(box.size.y * 0.5)
	var shown = shown_text()
	var caret_x = font.get_string_size(shown.left(cursor), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var x = box.position.x + 8 - maxf(0.0, caret_x - (box.size.x - 24))
	draw_string(font, Vector2(x, box.position.y + box.size.y * 0.5 + text_size * 0.36), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, fg)
	var caret_top = box.position.y + box.size.y * 0.2
	draw_line(Vector2(x + caret_x + 1, caret_top), Vector2(x + caret_x + 1, box.end.y - box.size.y * 0.2), fg, maxf(2.0, text_size * 0.08))
	var cell = cell_size()
	var label_size = int(minf(cell.x, cell.y) * 0.45)
	for i in range(keys.size()):
		var key = keys[i]
		var rect = Rect2(Vector2(key.col * cell.x, field + key.row * cell.y), Vector2(key.span * cell.x, cell.y)).grow(-2)
		var selected = i == index
		var on = key.type == "shift" and shifted
		draw_rect(rect, fg if selected else Color(fg, 0.25 if on else 0.1))
		var label_width = font.get_string_size(key.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(font, rect.get_center() + Vector2(-label_width / 2.0, label_size * 0.36), key.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, bg if selected else fg)

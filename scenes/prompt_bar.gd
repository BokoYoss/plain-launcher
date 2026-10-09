extends Node2D

const GLYPH_TEXT_GAP = 0.35
const PROMPT_GAP = 1.1
const PILL_ANGLE = -0.5
const CORNER_DETAIL = 16

var prompts: Array = []

const KEY_GLYPHS = {"confirm": "space", "back": "backspace", "options": "tab", "favorite": "F", "start": "Esc", "select": "tab", "shoulders": "Q E", "trigger": "R"}
const KEY_SYMBOL_WIDTHS = {"space": 2.2, "tab": 1.6, "backspace": 1.6}

static func glyph_for(action: String, confirm_swapped: bool, keyboard: bool = false, xbox_labels: bool = false) -> String:
	if keyboard and KEY_GLYPHS.has(action):
		return "key:" + KEY_GLYPHS[action]
	match action:
		"confirm":
			return "A"
		"back":
			return "B"
		"options":
			return "X" if xbox_labels else "Y"
		"favorite":
			return "Y" if xbox_labels else "X"
		"start":
			return "START"
		"select":
			return "SELECT"
		"shoulders":
			return "LR"
		"trigger":
			return "RT"
	return action.to_upper()

func set_prompts(list: Array):
	prompts = list
	queue_redraw()

static func key_width(text: String, size: int) -> float:
	if KEY_SYMBOL_WIDTHS.has(text):
		return size * KEY_SYMBOL_WIDTHS[text]
	return size * (0.5 + 0.52 * text.length())

static func glyph_width(glyph: String, size: int) -> float:
	if glyph.begins_with("key:"):
		return key_width(glyph.substr(4), size)
	match glyph:
		"START", "SELECT":
			return size * 2.05
		"LR":
			return size * 2.8
		"RT":
			return size * 1.75
	return size * 1.24

func _text_size() -> int:
	return Global.prompt_text_size()

func _label(prompt: Array) -> String:
	return prompt[1].to_upper() if Settings.get_setting(Settings.CFG_CAPS_LOCK) else prompt[1]

func content_end() -> float:
	var size = _text_size()
	var x = Global.left_bound + size * 0.5
	for prompt in prompts:
		x += glyph_width(glyph_for(prompt[0], Global.confirm_swapped, Global.using_keyboard, Global.xbox_labels()), size) + size * GLYPH_TEXT_GAP
		x += _font().get_string_size(_label(prompt), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * PROMPT_GAP
	return x - size * PROMPT_GAP

func _font() -> Font:
	if Global.font != null:
		return Global.font
	return Global.title.get_theme_font("font") if Global.title != null else ThemeDB.fallback_font

func _draw():
	if prompts.is_empty() or not Global.prompt_bar_enabled():
		return
	var size = _text_size()
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Global.bar_color()
	var center_y = Global.window_height - Global.prompt_bar_height() / 2.0
	draw_rect(Rect2(0, Global.window_height - Global.prompt_bar_height(), Global.window_width, Global.prompt_bar_height() + Global.title_offset), bg)
	var x = Global.left_bound + size * 0.5
	for prompt in prompts:
		var glyph = glyph_for(prompt[0], Global.confirm_swapped, Global.using_keyboard, Global.xbox_labels())
		_draw_glyph(glyph, x, center_y, size, fg, bg)
		x += glyph_width(glyph, size) + size * GLYPH_TEXT_GAP
		var label = _label(prompt)
		draw_string(_font(), Vector2(x, center_y + size * Global.PROMPT_BASELINE), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
		x += _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * PROMPT_GAP

func _draw_glyph(glyph: String, x: float, center_y: float, size: int, fg: Color, bg: Color) -> float:
	if glyph.begins_with("key:"):
		return _draw_key(glyph.substr(4), x, center_y, size, fg, bg)
	match glyph:
		"START", "SELECT":
			return _draw_pills(glyph == "START", x, center_y, size, fg)
		"LR":
			x = _draw_shoulder("L", x, center_y, size, fg, bg)
			return _draw_shoulder("R", x + size * 0.2, center_y, size, fg, bg)
		"RT":
			return _draw_shoulder("RT", x, center_y, size, fg, bg)
	var radius = size * 0.62
	var center = Vector2(x + radius, center_y)
	draw_circle(center, radius, fg, true, -1.0, true)
	_draw_centered_letter(glyph, center, int(size * 0.8), bg)
	return x + radius * 2.0

func _draw_key(text: String, x: float, center_y: float, size: int, fg: Color, bg: Color) -> float:
	var box = Vector2(key_width(text, size), size * 1.05)
	var style = StyleBoxFlat.new()
	style.bg_color = fg
	style.set_corner_radius_all(int(box.y * 0.22))
	style.corner_detail = CORNER_DETAIL
	draw_style_box(style, Rect2(Vector2(x, center_y - box.y / 2.0), box))
	var center = Vector2(x + box.x / 2.0, center_y)
	if KEY_SYMBOL_WIDTHS.has(text):
		_draw_key_symbol(text, center, size, bg)
	else:
		_draw_centered_letter(text, center, int(size * 0.62), bg)
	return x + box.x

func _draw_key_symbol(symbol: String, center: Vector2, size: int, color: Color):
	var line = maxf(1.5, size * 0.09)
	var half = size * 0.32
	match symbol:
		"space":
			var w = size * 0.7
			draw_polyline(PackedVector2Array([center + Vector2(-w, -half * 0.45), center + Vector2(-w, half * 0.45), center + Vector2(w, half * 0.45), center + Vector2(w, -half * 0.45)]), color, line, true)
		"tab":
			var tip = center + Vector2(half * 0.9, 0)
			draw_line(center + Vector2(-half * 1.1, 0), tip, color, line, true)
			draw_polyline(PackedVector2Array([tip + Vector2(-half * 0.55, -half * 0.55), tip, tip + Vector2(-half * 0.55, half * 0.55)]), color, line, true)
			draw_line(tip + Vector2(line * 1.5, -half * 0.75), tip + Vector2(line * 1.5, half * 0.75), color, line, true)
		"backspace":
			var w = half * 1.25
			var h = half * 0.75
			draw_polyline(PackedVector2Array([center + Vector2(-w, 0), center + Vector2(-w * 0.45, -h), center + Vector2(w, -h), center + Vector2(w, h), center + Vector2(-w * 0.45, h), center + Vector2(-w, 0)]), color, line, true)
			var cross = center + Vector2(w * 0.28, 0)
			var arm = h * 0.45
			draw_line(cross + Vector2(-arm, -arm), cross + Vector2(arm, arm), color, line, true)
			draw_line(cross + Vector2(-arm, arm), cross + Vector2(arm, -arm), color, line, true)

func _draw_shoulder(letter: String, x: float, center_y: float, size: int, fg: Color, bg: Color) -> float:
	var box = Vector2(size * (1.3 if letter.length() == 1 else 1.75), size * 0.95)
	var style = StyleBoxFlat.new()
	style.bg_color = fg
	style.corner_radius_top_left = int(box.y * 0.5)
	style.corner_radius_top_right = int(box.y * 0.5)
	style.corner_radius_bottom_left = int(box.y * 0.15)
	style.corner_radius_bottom_right = int(box.y * 0.15)
	style.corner_detail = CORNER_DETAIL
	draw_style_box(style, Rect2(Vector2(x, center_y - box.y / 2.0), box))
	_draw_centered_letter(letter, Vector2(x + box.x / 2.0, center_y), int(size * 0.7), bg)
	return x + box.x

func _draw_pills(right_highlighted: bool, x: float, center_y: float, size: int, fg: Color) -> float:
	var pill = Vector2(size * 1.0, size * 0.42)
	var spacing = size * 0.95
	for i in range(2):
		var highlighted = (i == 1) == right_highlighted
		var center = Vector2(x + pill.x * 0.55 + i * spacing, center_y)
		var round_radius = pill.y / 2.0
		if highlighted:
			var shape = capsule(center, pill.x / 2.0 - round_radius, round_radius, PILL_ANGLE)
			draw_colored_polygon(shape, fg)
			draw_polyline(shape + PackedVector2Array([shape[0]]), fg, 1.0, true)
		else:
			var line = maxf(1.0, size * 0.08)
			var outline = capsule(center, pill.x / 2.0 - round_radius, round_radius - line / 2.0, PILL_ANGLE)
			draw_polyline(outline + PackedVector2Array([outline[0]]), Color(fg, 0.45), line, true)
	return x + pill.x * 1.1 + spacing

static func capsule(center: Vector2, half_length: float, round_radius: float, tilt: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 24
	for end in [1, -1]:
		var cap = Vector2(half_length * end, 0)
		for i in range(steps + 1):
			var angle = -PI / 2.0 + PI * i / steps + (0.0 if end == 1 else PI)
			points.append(center + (cap + Vector2(cos(angle), sin(angle)) * round_radius).rotated(tilt))
	return points

func _draw_centered_letter(letter: String, center: Vector2, size: int, color: Color):
	var width = _font().get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font(), Vector2(center.x - width / 2.0, center.y + size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

extends Node2D

const GLYPH_TEXT_GAP = 0.35
const PROMPT_GAP = 1.1
const PILL_ANGLE = -0.5

var prompts: Array = []

static func glyph_for(action: String, confirm_swapped: bool) -> String:
	match action:
		"confirm":
			return "B" if confirm_swapped else "A"
		"back":
			return "A" if confirm_swapped else "B"
		"options":
			return "Y"
		"favorite":
			return "X"
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

static func glyph_width(glyph: String, size: int) -> float:
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
		x += glyph_width(glyph_for(prompt[0], Global.confirm_swapped), size) + size * GLYPH_TEXT_GAP
		x += _font().get_string_size(_label(prompt), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * PROMPT_GAP
	return x - size * PROMPT_GAP

func _font() -> Font:
	return Global.font if Global.font != null else ThemeDB.fallback_font

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
		var glyph = glyph_for(prompt[0], Global.confirm_swapped)
		_draw_glyph(glyph, x, center_y, size, fg, bg)
		x += glyph_width(glyph, size) + size * GLYPH_TEXT_GAP
		var label = _label(prompt)
		draw_string(_font(), Vector2(x, center_y + size * Global.PROMPT_BASELINE), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
		x += _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * PROMPT_GAP

func _draw_glyph(glyph: String, x: float, center_y: float, size: int, fg: Color, bg: Color) -> float:
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
	draw_circle(center, radius, fg)
	_draw_centered_letter(glyph, center, int(size * 0.8), bg)
	return x + radius * 2.0

func _draw_shoulder(letter: String, x: float, center_y: float, size: int, fg: Color, bg: Color) -> float:
	var box = Vector2(size * (1.3 if letter.length() == 1 else 1.75), size * 0.95)
	var style = StyleBoxFlat.new()
	style.bg_color = fg
	style.corner_radius_top_left = int(box.y * 0.5)
	style.corner_radius_top_right = int(box.y * 0.5)
	style.corner_radius_bottom_left = int(box.y * 0.15)
	style.corner_radius_bottom_right = int(box.y * 0.15)
	draw_style_box(style, Rect2(Vector2(x, center_y - box.y / 2.0), box))
	_draw_centered_letter(letter, Vector2(x + box.x / 2.0, center_y), int(size * 0.7), bg)
	return x + box.x

func _draw_pills(right_highlighted: bool, x: float, center_y: float, size: int, fg: Color) -> float:
	var pill = Vector2(size * 1.0, size * 0.42)
	var spacing = size * 0.95
	for i in range(2):
		var highlighted = (i == 1) == right_highlighted
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(int(pill.y / 2.0))
		if highlighted:
			style.bg_color = fg
		else:
			style.draw_center = false
			style.set_border_width_all(maxi(1, int(size * 0.08)))
			style.border_color = Color(fg, 0.45)
		draw_set_transform(Vector2(x + pill.x * 0.55 + i * spacing, center_y), PILL_ANGLE)
		draw_style_box(style, Rect2(-pill / 2.0, pill))
	draw_set_transform(Vector2.ZERO, 0.0)
	return x + pill.x * 1.1 + spacing

func _draw_centered_letter(letter: String, center: Vector2, size: int, color: Color):
	var width = _font().get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font(), Vector2(center.x - width / 2.0, center.y + size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

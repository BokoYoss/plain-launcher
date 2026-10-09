class_name PressGlyph extends Node2D

const WORD = "Press"
const GAP = 0.5
const PRESS_SECONDS = 0.45
const RING_GROWTH = 0.6

var glyph = "A"
var squash = 1.0:
	set(value):
		squash = value
		queue_redraw()
var ring = 0.0:
	set(value):
		ring = value
		queue_redraw()

static func layout(word_width: float, size: float, screen: Vector2) -> Dictionary:
	var radius = size * 0.62
	var total = word_width + size * GAP + radius * 2.0
	var left = (screen.x - total) / 2.0
	return {"word_x": left, "center": Vector2(left + word_width + size * GAP + radius, screen.y / 2.0), "radius": radius}

func press():
	var bounce = create_tween()
	bounce.tween_property(self, "squash", 0.78, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(self, "squash", 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(self, "squash", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var burst = create_tween()
	burst.tween_interval(0.06)
	burst.tween_property(self, "ring", 1.0, PRESS_SECONDS - 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _font() -> Font:
	if Global.font != null:
		return Global.font
	return Global.title.get_theme_font("font") if Global.title != null else ThemeDB.fallback_font

func _draw():
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	var size = int(Global.scaled_text_height * 0.5)
	var font = _font()
	var screen = Vector2(Global.window_width, Global.window_height + Global.title_offset)
	draw_rect(Rect2(Vector2.ZERO, screen), bg)
	var spot = layout(font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, size, screen)
	draw_string(font, Vector2(spot.word_x, spot.center.y + size * 0.36), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
	if ring > 0.0 and ring < 1.0:
		draw_arc(spot.center, spot.radius * (1.0 + ring * RING_GROWTH), 0.0, TAU, 64, Color(fg, 1.0 - ring), maxf(2.0, size * 0.08) * (1.0 - ring * 0.5), true)
	draw_circle(spot.center, spot.radius * squash, fg, true, -1.0, true)
	var letter_size = maxi(1, int(size * 0.8 * squash))
	var letter_width = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
	draw_string(font, Vector2(spot.center.x - letter_width / 2.0, spot.center.y + letter_size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, bg)

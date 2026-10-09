extends Control

const PromptBar = preload("res://scenes/prompt_bar.gd")

const SHOW_SECONDS = 5.0
const FADE_SECONDS = 0.3
const FACE_ALPHA = 0.5
const PRESSED_ALPHA = 0.75
const PRESSED_SCALE = 0.9
const PRESSED_DROP = 0.08
const PILL_TILT = -0.45

var pressed = ""
var _hide_at = 0.0
var _fade: Tween = null

func radius() -> float:
	return maxf(42.0, Global.scaled_text_height * 0.5)

func right_edge() -> float:
	var panel = Global.settings_panel
	if panel != null and panel.is_open and panel.custom != null and not panel.vertical():
		return panel._target_x()
	return Global.window_width

static func layout(right: float, bottom: float, r: float, with_x: bool = false) -> Dictionary:
	var confirm = Vector2(right - r * 1.6, bottom - r * 1.9)
	var back = confirm + Vector2(-r * 2.4, r * 1.0)
	var start = back + Vector2(-r * 2.4, r * 0.35)
	var buttons = {"confirm": confirm, "back": back, "start": start, "options": start + Vector2(-r * 2.1, 0)}
	if with_x:
		buttons["favorite"] = confirm + Vector2(0, -r * 2.4)
	return buttons

static func offers_x(prompts: Array) -> bool:
	return prompts.any(func(p): return p[0] == "favorite")

func centers() -> Dictionary:
	var r = radius()
	return layout(right_edge(), Global.window_height - Global.prompt_bar_height() - r * 0.6, r, offers_x(Global.prompts))

static func hit(centers_by_action: Dictionary, at: Vector2, r: float) -> String:
	for action in centers_by_action:
		if at.distance_to(centers_by_action[action]) <= r * 1.05:
			return action
	return ""

func button_at(at: Vector2) -> String:
	return hit(centers(), at, radius())

func hide_now():
	if _fade != null:
		_fade.kill()
	pressed = ""
	modulate.a = 0.0
	visible = false

func poke():
	_hide_at = Time.get_ticks_msec() / 1000.0 + SHOW_SECONDS
	if not visible or modulate.a < 1.0:
		visible = true
		_fade_to(1.0)
	queue_redraw()

func dismiss():
	if visible and pressed == "":
		_hide_at = 0.0

func press(action: String):
	pressed = action
	poke()

func release():
	pressed = ""
	queue_redraw()

func _ready():
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	if not visible:
		return
	queue_redraw()
	if pressed == "" and Time.get_ticks_msec() / 1000.0 > _hide_at and modulate.a >= 1.0:
		_fade_to(0.0)

func _fade_to(alpha: float):
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	if alpha == 0.0:
		_fade.tween_callback(func(): visible = false)

func _draw():
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	var font: Font = Global.font if Global.font != null else ThemeDB.fallback_font
	var points = centers()
	for action in points:
		var held = pressed == action
		var r = radius() * (PRESSED_SCALE if held else 1.0)
		var center: Vector2 = points[action] + Vector2(0, radius() * PRESSED_DROP if held else 0.0)
		var face = Color(fg, PRESSED_ALPHA if held else FACE_ALPHA)
		if action == "start" or action == "options":
			var pill = PromptBar.capsule(center, r * 0.6, r * 0.21, PILL_TILT)
			draw_colored_polygon(pill, face)
			draw_polyline(pill + PackedVector2Array([pill[0]]), face, 1.0, true)
			continue
		draw_circle(center, r, face, true, -1.0, true)
		var letter = PromptBar.glyph_for(action, Global.confirm_swapped, false, Global.xbox_labels())
		var size = int(r * 0.9)
		var letter_width = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, center + Vector2(-letter_width / 2.0, size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, bg)


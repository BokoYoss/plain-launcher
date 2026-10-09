extends Control

const REPEAT_DELAY_MS = 350
const REPEAT_MS = 110

var letters: Array = []
var starts: Array = []
var index = 0
var active = false
var by_touch = false
var peeking = false
var _peek_until = 0
const PEEK_MS = 900
var _repeat_at = 0
var slide = 0.0
var pop = 1.0
var _slide_tween: Tween = null
var _pop_tween: Tween = null
const SLIDE_SECONDS = 0.22
const POP_SECONDS = 0.22
const POP_SCALE = 1.12

static func letter_for(name: String) -> String:
	var first = name.strip_edges().left(1).to_upper()
	return first if first >= "A" and first <= "Z" else "#"

static func letter_groups(names: Array) -> Dictionary:
	var found = []
	var first_rows = []
	for i in range(names.size()):
		var letter = letter_for(names[i])
		if letter not in found:
			found.append(letter)
			first_rows.append(i)
	return {"letters": found, "starts": first_rows}

static func letter_index_at(y: float, top: float, bottom: float, count: int) -> int:
	if count == 0 or bottom <= top:
		return 0
	return clampi(int((y - top) / (bottom - top) * count), 0, count - 1)

func band_width() -> float:
	return maxf(48.0, Global.scaled_text_height * 0.45)

func top() -> float:
	var title_bottom = Global.title.position.y + Global.title.size.y if Global.title != null else 0.0
	return title_bottom

func bottom() -> float:
	return Global.window_height - Global.prompt_bar_height()

func in_band(at: Vector2) -> bool:
	return at.x >= Global.window_width - band_width() and at.y >= top() and at.y <= bottom()

func peek():
	if not active:
		begin()
		peeking = true
	elif peeking:
		var before = index
		sync_to_selection()
		if index != before:
			_bounce()
	_peek_until = Time.get_ticks_msec() + PEEK_MS

func sync_to_selection():
	index = 0
	for i in range(starts.size()):
		if starts[i] <= Global.option_selection:
			index = i

func begin(from_touch: bool = false):
	by_touch = from_touch
	peeking = false
	var groups = letter_groups(Global.option_list.map(func(o): return Global.shown_name(o)))
	letters = groups.letters
	starts = groups.starts
	if letters.is_empty():
		return
	print("Letter scroller opened (touch: %s)" % from_touch)
	sync_to_selection()
	active = true
	visible = true
	if Global.touch_buttons != null:
		Global.touch_buttons.hide_now()
	_slide_to(1.0, Tween.TRANS_BACK)

func finish():
	print("Letter scroller closed")
	active = false
	by_touch = false
	peeking = false
	_slide_to(0.0, Tween.TRANS_CUBIC)

func _slide_to(target: float, transition: Tween.TransitionType):
	if _slide_tween != null:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "slide", target, SLIDE_SECONDS).set_trans(transition).set_ease(Tween.EASE_OUT)
	if target == 0.0:
		_slide_tween.tween_callback(func():
			visible = active
			if Global.cover != null and not active:
				Global.cover.position.x = Global.window_width * Global.cover_anchor().x)

func _bounce():
	if _pop_tween != null:
		_pop_tween.kill()
	pop = POP_SCALE
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "pop", 1.0, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func choose(new_index: int):
	if not active or new_index == index:
		return
	index = clampi(new_index, 0, letters.size() - 1)
	Global.vibrate(20)
	Global.play_sound("move")
	Global.jump_to_row(starts[index])
	_bounce()

func follow(y: float):
	choose(letter_index_at(y, top(), bottom(), letters.size()))

func step(direction: int):
	choose(posmod(index + direction, letters.size()))

static func wrapped_group(group_starts: Array, row: int, direction: int) -> int:
	var current = 0
	for i in range(group_starts.size()):
		if group_starts[i] <= row:
			current = i
	return posmod(current + direction, group_starts.size())

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var _was_moving = false

func handle_held_input():
	var now = Time.get_ticks_msec()
	var stick = Global.control_tilt.y
	var direction = int(Global.down_held() or stick > 0.5) - int(Global.up_held() or stick < -0.5)
	if Global.down_just_pressed() or Global.up_just_pressed() or (direction != 0 and not _was_moving):
		step(direction if direction != 0 else (1 if Global.down_just_pressed() else -1))
		_repeat_at = now + REPEAT_DELAY_MS
	elif direction != 0 and now >= _repeat_at:
		step(direction)
		_repeat_at = now + REPEAT_MS
	_was_moving = direction != 0

func _process(_delta):
	if peeking and Time.get_ticks_msec() > _peek_until:
		finish()
	if visible:
		queue_redraw()
	if Global.cover != null and not Global.cover_on_left() and (visible or slide > 0.0):
		Global.cover.position.x = Global.window_width * Global.cover_anchor().x - slide * cover_shift()

func bubble_offset() -> float:
	return bubble_radius() * 1.4

func bubble_radius() -> float:
	return maxf(40.0, Global.scaled_text_height * 0.6)

func popup_left() -> float:
	return Global.window_width - band_width() - bubble_offset() - bubble_radius() * POP_SCALE

static func clearance(cover_right: float, popup_edge: float, gap: float) -> float:
	return maxf(0.0, cover_right - popup_edge + gap)

func cover_shift() -> float:
	if Global.cover_halo == null:
		return 0.0
	var cover_right = Global.window_width * Global.cover_anchor().x + Global.cover_halo.half_size.x
	return clearance(cover_right, popup_left(), Global.scaled_text_height * 0.15)

func _draw():
	if letters.is_empty():
		return
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	var font: Font = Global.font if Global.font != null else ThemeDB.fallback_font
	var width = band_width()
	var column_top = top()
	var row = (bottom() - column_top) / letters.size()
	var tuck = (1.0 - slide) * width * 1.5
	var x = Global.window_width - width / 2.0 + tuck
	var size = minf(width * 0.55, row * 0.85)
	draw_rect(Rect2(Global.window_width - width + tuck, column_top, width, bottom() - column_top), Color(fg, 0.12))
	for i in range(letters.size()):
		var y = column_top + row * (i + 0.5)
		var letter_size = int(size)
		var letter_width = font.get_string_size(letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
		draw_string(font, Vector2(x - letter_width / 2.0, y + letter_size * 0.36), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, Color(fg, 1.0 if i == index else 0.5))
	var bubble = bubble_radius() * pop
	var finger_y = clampf(column_top + row * (index + 0.5), column_top + bubble, bottom() - bubble)
	var center = Vector2(Global.window_width - width - bubble_offset() + tuck, finger_y)
	draw_circle(center, bubble, Color(fg, 0.85), true, -1.0, true)
	var big = int(bubble * 1.1)
	var big_width = font.get_string_size(letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(font, center + Vector2(-big_width / 2.0, big * 0.36), letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1, big, bg)

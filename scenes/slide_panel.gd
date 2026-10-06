class_name SlidePanel extends Control

const WIDTH_RATIO = 0.5
const WIDE_RATIO = 0.75
const FULL_RATIO = 0.96
const SLIDE_SECONDS = 0.15
const HOLD_DELAY_MS = 400
const HOLD_REPEAT_MS = 60
const DIM_ALPHA = 0.55
const PEEK_ALPHA = 0.3
const PEEK_FADE_SECONDS = 0.12
const PEEK_HOLD_SECONDS = 0.6

var list: ListView
var title_label: Label
var corner_label: Label
var corner_text = ""
var background: ColorRect
var edge: ColorRect
var title_line: ColorRect
var dim: ColorRect
var menus: Array = []
var _selections: Array = []
var custom: Control = null
var _menu: Dictionary = {}
var is_open = false
var side = "right"
var on_close: Callable = Callable()
var _paused_screen = null
var _saved_prompts: Array = []
var _opened_frame = -1
var _hold_until = 0
var _slide: Tween = null
var _laid_out_size = Vector2.ZERO
const MIN_FONT_SIZE = 12
var _peek: Tween = null
var _touch_start = null
var _touch_last = Vector2.ZERO
var _touch_scrolling = false
var _touch_accum = 0.0
var _touch_velocity = 0.0
var _momentum = 0.0
const MOMENTUM_DECAY = 0.88
const MOMENTUM_STOP = 0.5
const STICK_DEADZONE = 0.5
var _stick_last = Vector2i.ZERO
var _stick_at = 0

func _init():
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	add_child(dim)
	background = ColorRect.new()
	add_child(background)
	edge = ColorRect.new()
	add_child(edge)
	title_label = Label.new()
	title_label.uppercase = true
	add_child(title_label)
	title_line = ColorRect.new()
	add_child(title_line)
	corner_label = Label.new()
	corner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(corner_label)
	list = ListView.new()
	add_child(list)
	visible = false

func _font() -> Font:
	if Global.font != null:
		return Global.font
	return Global.title.get_theme_font("font") if Global.title != null else ThemeDB.fallback_font

func relayout():
	if is_open:
		_layout()
		list.refresh()
		if custom != null:
			custom.position = list.position
			custom.size = list.size
			custom.queue_redraw()

func vertical() -> bool:
	return side == "top" or side == "bottom"

static func side_for(requested: String, width: float, height: float) -> String:
	if height <= width:
		return requested
	return "bottom" if requested == "left" else "top"

func panel_ratio() -> float:
	return _menu.get("width", WIDTH_RATIO)

func available_height() -> float:
	return Global.window_height - Global.prompt_bar_height()

func panel_width() -> float:
	return Global.window_width if vertical() else Global.window_width * panel_ratio()

func panel_height() -> float:
	return available_height() * panel_ratio() if vertical() else available_height()

func _target_x() -> float:
	return _target_position().x

func _target_position() -> Vector2:
	match side:
		"left", "top":
			return Vector2.ZERO
		"bottom":
			return Vector2(0, available_height() - panel_height())
	return Vector2(Global.window_width - panel_width(), 0)

func _hidden_position() -> Vector2:
	match side:
		"left":
			return Vector2(-panel_width(), 0)
		"top":
			return Vector2(0, -panel_height())
		"bottom":
			return Vector2(0, Global.window_height)
	return Vector2(Global.window_width, 0)

func _layout():
	var height = panel_height()
	var width = panel_width()
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var bg: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	var pad = Global.scaled_text_height * 0.25
	dim.size = Vector2(Global.window_width * 2.0, available_height())
	background.color = bg.lerp(fg, 0.08)
	edge.color = Color(fg, 0.3)
	if vertical():
		background.size = Vector2(width, height)
		background.position = Vector2.ZERO
		edge.size = Vector2(width, 2)
		edge.position = Vector2(0, height - 2 if side == "top" else 0.0)
	else:
		background.size = Vector2(Global.window_width, height)
		background.position = Vector2(width - Global.window_width if side == "left" else 0.0, 0)
		edge.size = Vector2(2, height)
		edge.position = Vector2(width - 2 if side == "left" else 0.0, 0)
	var title_size = int(Global.scaled_text_height * 0.22)
	title_label.position = Vector2(pad, pad * 0.5)
	title_label.size = Vector2(width - pad * 2, title_size * 1.6)
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_font_override("font", _font())
	title_label.modulate = Color(fg, 0.7)
	corner_label.position = title_label.position
	corner_label.size = title_label.size
	corner_label.add_theme_font_size_override("font_size", title_size)
	corner_label.add_theme_font_override("font", _font())
	corner_label.modulate = Color(fg, 0.45)
	list.font = _font()
	list.font_size = int(Global.scaled_text_height * 0.3)
	list.row_height = list.font_size * 1.6
	list.color = fg
	list.position = Vector2(pad, title_label.position.y + title_label.size.y + pad * 0.5)
	list.size = Vector2(width - pad * 2, height - list.position.y - pad)
	list.stripe_margin = pad
	title_line.color = Color(fg, 0.3)
	title_line.position = Vector2(pad, list.position.y - pad * 0.3)
	title_line.size = Vector2(width - pad * 2, 2)
	if _menu.get("static", false):
		var lines = _menu.get("items", []).map(func(o): return o.clean)
		list.font_size = fitted_font_size(_font(), lines, list.size.x, list.font_size)
		list.row_height = list.font_size * 1.6
	_laid_out_size = Vector2(width, height)

static func fitted_font_size(font: Font, lines: Array, width: float, size: int) -> int:
	var widest = 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if widest <= width or widest <= 0.0:
		return size
	return maxi(MIN_FONT_SIZE, int(size * width / widest))

func open(builder: Callable, from_side: String = "right", closed: Callable = Callable()):
	if not is_open:
		side = side_for(from_side, Global.window_width, Global.window_height)
		on_close = closed
		is_open = true
		_opened_frame = Engine.get_process_frames()
		_saved_prompts = Global.prompts
		var top = Navigator._stack.back() if not Navigator._stack.is_empty() else null
		_paused_screen = top.node if top != null else null
		if _paused_screen != null:
			_paused_screen.process_mode = Node.PROCESS_MODE_DISABLED
		Global.disable_scroll = true
		visible = true
		_menu = {}
		position = _hidden_position()
		_pin_dim()
		create_tween().tween_property(dim, "color:a", DIM_ALPHA, SLIDE_SECONDS)
	menus = [builder]
	_selections = []
	show_menu(false)

func push_menu(builder: Callable):
	_selections.append([list.selection, list.scroll_offset])
	menus.append(builder)
	show_menu(false)

func show_menu(keep_selection: bool = true):
	if menus.is_empty():
		return
	_menu = menus.back().call()
	var size_now = Vector2(panel_width(), panel_height())
	if is_open and is_inside_tree() and (not position.is_equal_approx(_target_position()) or not _laid_out_size.is_equal_approx(size_now)):
		if side == "left" and _laid_out_size.x > 0.0:
			position.x += _laid_out_size.x - size_now.x
		elif side == "top" and _laid_out_size.y > 0.0:
			position.y += _laid_out_size.y - size_now.y
		_layout()
		if _slide != null:
			_slide.kill()
		_slide = create_tween()
		_slide.tween_property(self, "position", _target_position(), SLIDE_SECONDS)
	title_label.text = _menu.get("title", "")
	corner_label.text = corner_text
	_set_custom(_menu.get("custom"))
	list.static_rows = _menu.get("static", false)
	list.choice_rows = _menu.get("choices", false)
	list.set_items(_menu.get("items", []), keep_selection)
	if (not keep_selection or _menu.get("locked", false)) and _menu.has("selection"):
		list.select(_menu.selection)
	_update_prompts()
	if Global.cover != null:
		Global.cover.z_index = Global.cover_z()

func _set_custom(node):
	if custom != null and custom != node:
		custom.queue_free()
	custom = node
	list.visible = custom == null
	if custom != null:
		if custom.get_parent() == null:
			add_child(custom)
		custom.position = list.position
		custom.size = list.size
		custom.queue_redraw()

func back():
	if _menu.has("on_cancel"):
		_menu.on_cancel.call()
	if menus.size() > 1:
		menus.pop_back()
		var saved = _selections.pop_back() if not _selections.is_empty() else [0, 0]
		list.selection = saved[0]
		list.scroll_offset = saved[1]
		show_menu(true)
	else:
		close()

func close():
	if not is_open:
		return
	if _menu.has("on_cancel"):
		_menu.on_cancel.call()
	var hidden = _hidden_position()
	_laid_out_size = Vector2.ZERO
	is_open = false
	menus = []
	_menu = {}
	_set_custom(null)
	if _paused_screen != null and is_instance_valid(_paused_screen):
		_paused_screen.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	_paused_screen = null
	Global.disable_scroll = false
	Global.set_prompts(_saved_prompts)
	if _slide != null:
		_slide.kill()
	if _peek != null:
		_peek.kill()
	modulate.a = 1.0
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "position", hidden, SLIDE_SECONDS)
	tween.tween_property(dim, "color:a", 0.0, SLIDE_SECONDS)
	tween.chain().tween_callback(func(): visible = is_open)
	if on_close.is_valid():
		var closed = on_close
		on_close = Callable()
		closed.call()

func open_screen(screen: String):
	close()
	visible = false
	Navigator.push(screen)

func _update_prompts():
	if _menu.has("prompts"):
		Global.set_prompts(_menu.prompts)
		return
	if _menu.get("static", false):
		Global.set_prompts([["back", "Back"]])
		return
	var prompts = [["confirm", "Select"]]
	var item = list.selected()
	if item != null and item.handles(Actions.START):
		prompts.append(["favorite", "Default"])
	prompts.append(["back", "Back" if menus.size() > 1 else "Close"])
	Global.set_prompts(prompts)

func peek():
	if _peek != null:
		_peek.kill()
	_peek = create_tween()
	_peek.tween_property(self, "modulate:a", PEEK_ALPHA, PEEK_FADE_SECONDS)
	_peek.tween_interval(PEEK_HOLD_SECONDS)
	_peek.tween_property(self, "modulate:a", 1.0, PEEK_FADE_SECONDS * 2.0)

func _pin_dim():
	dim.position = Vector2(-position.x - Global.window_width * 0.5, -position.y)

func _process(_delta):
	if visible:
		_pin_dim()
	if not is_open or Engine.get_process_frames() == _opened_frame:
		return
	_glide()
	var now = Time.get_ticks_msec()
	if custom != null:
		_process_custom(now)
		return
	if list.static_rows:
		if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("options"):
			close()
		elif Global.back_pressed():
			back()
		return
	var stick = _stick_step(now)
	if _menu.get("locked", false):
		pass
	elif stick.y != 0:
		_move(stick.y)
	elif Global.up_just_pressed():
		_move(-1)
		_hold_until = now + HOLD_DELAY_MS
	elif Global.down_just_pressed():
		_move(1)
		_hold_until = now + HOLD_DELAY_MS
	elif (Global.up_held() or Global.down_held()) and now >= _hold_until:
		_move(-1 if Global.up_held() else 1)
		_hold_until = now + HOLD_REPEAT_MS
	var item = list.selected()
	if (Global.left_just_pressed() or stick.x < 0) and item != null:
		item.trigger(Actions.DIRECTION, [-1])
	elif (Global.right_just_pressed() or stick.x > 0) and item != null:
		item.trigger(Actions.DIRECTION, [1])
	elif Global.confirm_pressed() and item != null:
		item.trigger(Actions.CONFIRM)
	elif Input.is_action_just_pressed("favorite") and item != null:
		item.trigger(Actions.START)
	elif Input.is_action_just_pressed("start") or Input.is_action_just_pressed("options"):
		close()
	elif Global.back_pressed():
		back()

func _process_custom(now: int):
	var direction = Vector2i(int(Global.right_just_pressed()) - int(Global.left_just_pressed()), int(Global.down_just_pressed()) - int(Global.up_just_pressed()))
	if direction != Vector2i.ZERO:
		_hold_until = now + HOLD_DELAY_MS
	elif now >= _hold_until:
		direction = Vector2i(int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left")), int(Global.down_held()) - int(Global.up_held()))
		if direction != Vector2i.ZERO:
			_hold_until = now + HOLD_REPEAT_MS
	if direction == Vector2i.ZERO:
		direction = _stick_step(now)
	if direction != Vector2i.ZERO:
		custom.move(direction.x, direction.y)
	if Global.confirm_pressed() and _menu.has("on_confirm"):
		_menu.on_confirm.call()
	elif Input.is_action_just_pressed("favorite") and _menu.has("on_start"):
		_menu.on_start.call()
	elif Input.is_action_just_pressed("start") or Input.is_action_just_pressed("options"):
		close()
	elif Global.back_pressed():
		back()

static func stick_direction(tilt: Vector2) -> Vector2i:
	if absf(tilt.y) > STICK_DEADZONE and absf(tilt.y) >= absf(tilt.x):
		return Vector2i(0, 1 if tilt.y > 0 else -1)
	if absf(tilt.x) > STICK_DEADZONE:
		return Vector2i(1 if tilt.x > 0 else -1, 0)
	return Vector2i.ZERO

func _stick_step(now: int) -> Vector2i:
	var tilt = Global.control_tilt
	var direction = stick_direction(tilt)
	var fresh = direction != _stick_last
	_stick_last = direction
	if direction == Vector2i.ZERO:
		return direction
	if fresh:
		_stick_at = now + HOLD_DELAY_MS
		return direction
	if direction.y != 0 and now >= _stick_at:
		_stick_at = now + int(Global.stick_repeat_ms(1.0 - absf(tilt.y)))
		return direction
	return Vector2i.ZERO

func touch(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed:
		_touch_start = event.position
		_touch_last = event.position
		_touch_scrolling = false
		_touch_accum = 0.0
		_touch_velocity = 0.0
		_momentum = 0.0
	elif event is InputEventScreenDrag and _touch_start != null:
		var dy = event.position.y - _touch_last.y
		_touch_velocity = _touch_velocity * 0.6 + dy * 0.4
		_touch_last = event.position
		var diff = event.position - _touch_start
		if custom != null:
			_touch_pick(event.position)
			return
		if not _touch_scrolling and absf(diff.y) > list.row_height * 0.4 and absf(diff.y) > absf(diff.x):
			_touch_scrolling = true
		if _touch_scrolling and not _menu.get("locked", false):
			_scroll_by(dy)
	elif event is InputEventScreenTouch and not event.pressed and _touch_start != null:
		var diff = event.position - _touch_start
		_touch_last = _touch_start
		_touch_start = null
		if _touch_scrolling:
			_momentum = _touch_velocity
			return
		if custom != null and diff.length() < list.row_height:
			_tap(event.position)

func _scroll_by(dy: float):
	var direction = -1.0 if Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL) else 1.0
	_touch_accum += dy * direction
	while list.row_height > 0 and absf(_touch_accum) >= list.row_height:
		var step = 1 if _touch_accum > 0 else -1
		_touch_accum -= step * list.row_height
		if list.items.is_empty():
			continue
		var moved = clampi(list.selection + step, 0, list.items.size() - 1)
		if moved != list.selection:
			Global.vibrate(30)
		list.select(moved)
		_update_prompts()

func _glide():
	if absf(_momentum) < MOMENTUM_STOP or _touch_start != null or custom != null:
		_momentum = 0.0
		return
	_scroll_by(_momentum)
	_momentum *= MOMENTUM_DECAY

func _tap(at: Vector2):
	var before = custom.index
	_touch_pick(at)
	if custom.index == before and custom.index_at(at - position - custom.position) >= 0 and _menu.has("on_confirm"):
		_menu.on_confirm.call()

func _touch_pick(at: Vector2):
	var found = custom.index_at(at - position - custom.position)
	if found >= 0 and found != custom.index:
		Global.vibrate(30)
		custom.pick(found)

func _move(delta: int):
	list.move(delta)
	Global.vibrate(30)
	_update_prompts()

extends "res://tests/test_case.gd"

const ROWS = 5

var saved_slots

func before_each():
	saved_slots = Global.visible_slots
	var slots = []
	for i in range(ROWS):
		slots.append(Label.new())
	Global.visible_slots = slots
	var items = []
	for i in range(20):
		var opt = option.new()
		opt.clean = "g%d" % i
		items.append(opt)
	Global.option_list = items
	Global.no_alias = true
	Global.can_scroll = true
	Global.scroll_offset = 0
	Global.option_selection = 0
	Global.show_options(0)
	Global.highlight_selection(0)

func after_each():
	for slot in Global.visible_slots:
		slot.free()
	Global.visible_slots = saved_slots
	Global.option_list = []

func _texts() -> Array:
	return Global.visible_slots.map(func(s): return s.text)

func _window() -> Array:
	var expected = []
	for i in range(ROWS):
		expected.append("g%d" % (Global.scroll_offset + i))
	return expected

func _mark_rows():
	for slot in Global.visible_slots:
		slot.text = "x"

func test_moving_inside_window_does_not_relabel():
	_mark_rows()
	Global.move_down()
	assert_eq(Global.option_selection, 1, "moved down")
	assert_eq(_texts(), ["x", "x", "x", "x", "x"], "rows untouched going down")
	Global.move_up()
	assert_eq(Global.option_selection, 0, "moved up")
	assert_eq(_texts(), ["x", "x", "x", "x", "x"], "rows untouched going up")

func test_moving_inside_scrolled_window_does_not_relabel():
	for i in range(10):
		Global.move_down()
	assert_eq(Global.scroll_offset, 6, "window scrolled")
	_mark_rows()
	Global.move_up()
	Global.move_down()
	assert_eq(_texts(), ["x", "x", "x", "x", "x"], "deep in the list, rows untouched")

func test_window_moves_at_edges():
	for i in range(ROWS - 1):
		Global.move_down()
	_mark_rows()
	Global.move_down()
	assert_eq(Global.scroll_offset, 1, "scrolled down at bottom edge")
	assert_eq(_texts(), _window(), "rows relabelled at bottom edge")
	for i in range(ROWS - 1):
		Global.move_up()
	_mark_rows()
	Global.move_up()
	assert_eq(Global.scroll_offset, 0, "scrolled up at top edge")
	assert_eq(_texts(), _window(), "rows relabelled at top edge")

func test_selection_stays_visible_and_rows_match():
	var problems = []
	var moves = []
	for i in range(60):
		moves.append("down")
	for i in range(60):
		moves.append("up")
	for move in moves:
		if move == "down":
			Global.move_down()
		else:
			Global.move_up()
		var sel = Global.option_selection
		var offset = Global.scroll_offset
		if sel < offset or sel >= offset + ROWS:
			problems.append("selection %d outside window at %d" % [sel, offset])
		if _texts() != _window():
			problems.append("rows %s at offset %d" % [str(_texts()), offset])
	assert_eq(problems.slice(0, 3), [], "no visibility or label problems through wraps")

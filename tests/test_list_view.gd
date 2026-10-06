extends "res://tests/test_case.gd"

var view: ListView

func before_each():
	view = ListView.new()
	view.row_height = 10.0
	view.size = Vector2(100, 30)
	var items = []
	for i in range(8):
		items.append(option.new_option("item%d" % i))
	view.set_items(items)

func after_each():
	view.free()

func _shown() -> Array:
	return view._labels.filter(func(l): return l.visible).map(func(l): return l.text)

func test_shows_first_rows_and_highlights_selection():
	assert_eq(_shown(), ["item0", "item1", "item2"], "first page")
	assert_eq(view._labels[0].modulate.a, 1.0, "selected row bright")
	assert_true(is_equal_approx(view._labels[1].modulate.a, view.dim_alpha), "other rows dim")

func test_scrolls_to_keep_selection_visible():
	for i in range(4):
		view.move(1)
	assert_eq(view.selection, 4, "moved")
	assert_eq(_shown(), ["item2", "item3", "item4"], "scrolled down")
	view.move(-3)
	assert_eq(_shown(), ["item1", "item2", "item3"], "scrolled up")

func test_wraps_at_both_ends():
	view.move(-1)
	assert_eq(view.selected().clean, "item7", "wraps to last")
	assert_eq(_shown(), ["item5", "item6", "item7"], "last page shown")
	view.move(1)
	assert_eq(view.selected().clean, "item0", "wraps to first")

func test_keeps_selection_when_items_refresh():
	view.move(2)
	var items = view.items.duplicate()
	items[2] = option.new_option("changed")
	view.set_items(items, true)
	assert_eq(view.selected().clean, "changed", "same row stays selected")
	view.set_items(items)
	assert_eq(view.selection, 0, "new menu starts at the top")

func test_selection_clamped_when_list_shrinks():
	view.move(7)
	view.set_items([option.new_option("only")], true)
	assert_eq(view.selection, 0, "clamped")
	assert_eq(_shown(), ["only"], "one row")

func test_panel_back_returns_to_parent_selection():
	var saved_prompts = Global.prompts
	var panel = SlidePanel.new()
	panel.list.row_height = 10.0
	panel.list.size = Vector2(100, 30)
	var parent = func(): return {"title": "Parent", "items": view.items}
	panel.menus = [parent]
	panel.show_menu(false)
	panel.list.move(5)
	panel.push_menu(func(): return {"title": "Child", "items": [option.new_option("x")]})
	assert_eq(panel.list.selection, 0, "child starts at top")
	panel.back()
	assert_eq(panel.list.selected().clean, "item5", "parent selection restored")
	panel.free()
	Global.set_prompts(saved_prompts)

func _touch(panel, at: Vector2, pressed: bool):
	var event = InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	panel.touch(event)

func _drag(panel, at: Vector2):
	var event = InputEventScreenDrag.new()
	event.position = at
	panel.touch(event)

func _touch_panel(tapped: Array):
	var panel = SlidePanel.new()
	panel.position = Vector2(500, 0)
	panel.list.position = Vector2(10, 40)
	panel.list.row_height = 10.0
	panel.list.size = Vector2(100, 30)
	var items = []
	for i in range(8):
		items.append(option.with_callback("item%d" % i, func(): tapped.append(i)))
	panel.menus = [func(): return {"title": "Touch", "items": items}]
	panel.is_open = true
	panel.show_menu(false)
	return panel

func test_list_index_at():
	view.scroll_offset = 2
	assert_eq(view.index_at(15), 3, "second visible row")
	assert_eq(view.index_at(-1), -1, "above list")
	assert_eq(view.index_at(35), -1, "below visible rows")

func test_panel_taps_only_scroll():
	var saved_prompts = Global.prompts
	var tapped = []
	var panel = _touch_panel(tapped)
	_touch(panel, Vector2(520, 65), true)
	_touch(panel, Vector2(521, 65), false)
	_touch(panel, Vector2(520, 65), true)
	_touch(panel, Vector2(521, 65), false)
	assert_eq(tapped, [], "taps on rows do nothing")
	assert_eq(panel.list.selection, 0, "selection unchanged by taps")
	panel.free()
	Global.set_prompts(saved_prompts)

func test_panel_drag_scrolls_without_confirming():
	var saved_prompts = Global.prompts
	var saved_invert = Settings._data.get(Settings.CFG_TOUCH_INVERT_SCROLL)
	Settings._data[Settings.CFG_TOUCH_INVERT_SCROLL] = false
	var tapped = []
	var panel = _touch_panel(tapped)
	_touch(panel, Vector2(520, 45), true)
	for y in [50, 60, 70, 80, 90]:
		_drag(panel, Vector2(520, y))
	_touch(panel, Vector2(520, 90), false)
	assert_eq(tapped, [], "drag does not confirm")
	assert_true(panel.list.selection > 0, "cursor moved like the game lists")
	assert_true(panel.list.scroll_offset > 0, "long list follows the cursor")
	if saved_invert == null:
		Settings._data.erase(Settings.CFG_TOUCH_INVERT_SCROLL)
	else:
		Settings._data[Settings.CFG_TOUCH_INVERT_SCROLL] = saved_invert
	panel.free()
	Global.set_prompts(saved_prompts)

func test_palette_index_at():
	var grid = PaletteGrid.new()
	grid.size = Vector2(30, 30)
	grid.colors = [Color.RED, Color.GREEN, Color.BLUE, Color.WHITE]
	assert_eq(grid.index_at(Vector2(20, 5)), 1, "top right")
	assert_eq(grid.index_at(Vector2(5, 20)), 2, "bottom left")
	assert_eq(grid.index_at(Vector2(40, 5)), -1, "outside")
	grid.free()

func test_value_right_aligned_and_checkbox_drawn():
	view.size = Vector2(300, 30)
	view.font_size = 10
	var a = option.new_option("Speed")
	a.set_meta("value", "Fast")
	var b = option.new_option("Sound")
	b.set_meta("checked", true)
	view.set_items([a, b])
	assert_eq(view._labels[0].text, "Speed", "label alone")
	assert_eq(view._values[0].text, "Fast", "value separate")
	assert_eq(view._values[0].horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "value right aligned")
	assert_true(view._values[0].position.x + view._values[0].size.x <= 300.5, "value ends at right edge")
	assert_eq(view._checks.size(), 1, "one checkbox")
	assert_true(view._checks[0][1], "checkbox checked")

func test_left_panel_positions():
	var panel = SlidePanel.new()
	panel.side = "left"
	assert_eq(panel._target_x(), 0.0, "left panel rests at the left edge")
	assert_true(panel._hidden_position().x <= 0.0, "hidden off the left edge")
	panel.side = "right"
	assert_eq(panel._hidden_position().x, float(Global.window_width), "right panel hides off the right edge")
	panel.side = "top"
	assert_eq(panel._hidden_position().y, -panel.panel_height(), "top panel hides above the screen")
	assert_eq(panel.panel_width(), float(Global.window_width), "vertical panel spans the width")
	panel.free()

func test_stick_direction_picks_dominant_axis():
	assert_eq(SlidePanel.stick_direction(Vector2(0.1, 0.9)), Vector2i(0, 1), "down")
	assert_eq(SlidePanel.stick_direction(Vector2(0.2, -0.7)), Vector2i(0, -1), "up")
	assert_eq(SlidePanel.stick_direction(Vector2(-0.8, 0.3)), Vector2i(-1, 0), "left")
	assert_eq(SlidePanel.stick_direction(Vector2(0.3, 0.2)), Vector2i.ZERO, "inside deadzone")

func test_portrait_panels_come_from_top_and_bottom():
	assert_eq(SlidePanel.side_for("right", 1920, 1080), "right", "landscape keeps right")
	assert_eq(SlidePanel.side_for("left", 1920, 1080), "left", "landscape keeps left")
	assert_eq(SlidePanel.side_for("right", 1080, 2400), "top", "portrait settings from the top")
	assert_eq(SlidePanel.side_for("left", 1080, 2400), "bottom", "portrait options from the bottom")

func test_back_runs_cancel_for_any_menu():
	var saved_prompts = Global.prompts
	var panel = SlidePanel.new()
	var cancelled = []
	panel.menus = [func(): return {"title": "A", "items": view.items}, func(): return {"title": "B", "items": view.items, "on_cancel": func(): cancelled.append(true)}]
	panel.show_menu(false)
	panel.back()
	assert_eq(cancelled, [true], "cancel hook ran")
	panel.free()
	Global.set_prompts(saved_prompts)

func test_favorite_star_shape():
	var points = FavoriteStar.star_points(Vector2(10, 10), 10)
	assert_eq(points.size(), 10, "five points and five notches")
	assert_true(points[0].is_equal_approx(Vector2(10, 0)), "top point straight up")
	assert_true(points[1].distance_to(Vector2(10, 10)) < 5.0, "notches pulled in")

func test_static_rows_show_headings_dim_and_values_bright():
	var heading = option.new_option("Path")
	heading.set_meta("heading", true)
	view.static_rows = true
	view.set_items([heading, option.new_option("/roms/a.gba")])
	assert_true(is_equal_approx(view._labels[0].modulate.a, view.dim_alpha), "heading dim")
	assert_eq(view._labels[1].modulate.a, 1.0, "value bright without selection")

func test_short_value_stays_whole_beside_long_label():
	view.size = Vector2(300, 30)
	view.font_size = 16
	var row = option.new_option("A very long setting label that will not fit")
	row.set_meta("value", "Not set")
	view.set_items([row])
	var needed = view._values[0].get_theme_font("font").get_string_size("Not set", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	assert_true(view._values[0].size.x >= needed, "value keeps its full width")
	assert_true(view._labels[0].size.x < 300 - needed, "label gives way")

func test_locked_menu_keeps_cursor_on_action():
	var saved_prompts = Global.prompts
	var panel = SlidePanel.new()
	var state = {"rows": [option.new_option("Game"), option.new_option("Searching..."), option.with_callback("Stop", func(): pass)]}
	panel.menus = [func(): return {"title": "Scraping", "items": state.rows, "selection": state.rows.size() - 1, "locked": true}]
	panel.show_menu(false)
	assert_eq(panel.list.selected().clean, "Stop", "starts on Stop")
	panel._move(-1)
	state.rows = [option.new_option("Saved"), option.with_callback("Done", func(): pass)]
	panel.show_menu(true)
	assert_eq(panel.list.selected().clean, "Done", "follows the action when rows change")
	panel.free()
	Global.set_prompts(saved_prompts)

func test_arrows_on_actions_and_right_aligned_confirmations():
	var submenu = option.with_callback("Visuals", func(): pass)
	var info = option.new_option("Saved")
	var valued = option.with_callback("Text size", func(): pass)
	valued.set_meta("value", "Medium")
	view.set_items([submenu, info, valued])
	assert_eq(view._arrows.size(), 1, "only the plain pressable row gets an arrow")
	assert_eq(view._labels[0].horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "submenu text stays left")
	view.choice_rows = true
	view.set_items([option.with_callback("Overwrite", func(): pass), option.with_callback("Cancel", func(): pass)])
	assert_eq(view._arrows.size(), 0, "no arrows on a confirmation")
	assert_eq(view._labels[0].horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "confirmation choices right aligned")

func test_static_text_shrinks_to_fit_longest_line():
	var font = ThemeDB.fallback_font
	var long_line = "/storage/9A7C-056B/ROMs/neogeo/Some Very Long Game Name (USA) (Rev 1).zip"
	var width = font.get_string_size(long_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x / 2.0
	var fitted = SlidePanel.fitted_font_size(font, ["Path", long_line], width, 40)
	assert_true(fitted < 40 and fitted >= SlidePanel.MIN_FONT_SIZE, "shrunk but readable")
	assert_true(font.get_string_size(long_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x <= width + 1.0, "longest line fits")
	assert_eq(SlidePanel.fitted_font_size(font, ["Path"], 1000.0, 40), 40, "short text untouched")

func test_panel_flick_keeps_gliding():
	var saved_prompts = Global.prompts
	var saved_invert = Settings._data.get(Settings.CFG_TOUCH_INVERT_SCROLL)
	Settings._data[Settings.CFG_TOUCH_INVERT_SCROLL] = false
	var tapped = []
	var panel = _touch_panel(tapped)
	var many = []
	for i in range(40):
		many.append(option.with_callback("row%d" % i, func(): pass))
	panel.menus = [func(): return {"title": "Long", "items": many}]
	panel.show_menu(false)
	_touch(panel, Vector2(520, 45), true)
	for y in [50, 60, 70, 80]:
		_drag(panel, Vector2(520, y))
	_touch(panel, Vector2(520, 80), false)
	var after_release = panel.list.selection
	for i in range(20):
		panel._glide()
	assert_true(panel.list.selection > after_release, "keeps moving after the finger lifts")
	if saved_invert == null:
		Settings._data.erase(Settings.CFG_TOUCH_INVERT_SCROLL)
	else:
		Settings._data[Settings.CFG_TOUCH_INVERT_SCROLL] = saved_invert
	panel.free()
	Global.set_prompts(saved_prompts)

func test_touch_buttons_hit_areas():
	var buttons = load("res://scenes/touch_buttons.gd")
	var centers = buttons.layout(1920.0, 1000.0, 50.0)
	for action in centers:
		assert_eq(buttons.hit(centers, centers[action], 50.0), action, action + " pressed at its center")
	assert_eq(buttons.hit(centers, Vector2(400, 400), 50.0), "", "list area is not a button")
	assert_true(centers.options.x < centers.start.x and centers.start.x < centers.back.x and centers.back.x < centers.confirm.x, "Select, Start, B, A from left to right")
	var shifted = buttons.layout(1000.0, 1000.0, 50.0)
	assert_true(shifted.confirm.x < 1000.0, "buttons move left of an open panel")

func test_letter_groups_and_band_mapping():
	var scroller = load("res://scenes/letter_scroller.gd")
	var groups = scroller.letter_groups(["1942", "Aladdin", "Alien", "Batman", "zelda"])
	assert_eq(groups.letters, ["#", "A", "B", "Z"], "one entry per starting letter, digits under #")
	assert_eq(groups.starts, [0, 1, 3, 4], "first row of each letter")
	assert_eq(scroller.letter_index_at(0.0, 100.0, 500.0, 4), 0, "above the band clamps to first")
	assert_eq(scroller.letter_index_at(499.0, 100.0, 500.0, 4), 3, "bottom of the band is the last letter")
	assert_eq(scroller.letter_index_at(250.0, 100.0, 500.0, 4), 1, "middle maps proportionally")

func test_x_button_only_when_x_does_something():
	var buttons = load("res://scenes/touch_buttons.gd")
	assert_false(buttons.layout(1920.0, 1000.0, 50.0).has("favorite"), "no X by default")
	var with_x = buttons.layout(1920.0, 1000.0, 50.0, true)
	assert_true(with_x.favorite.y < with_x.confirm.y and is_equal_approx(with_x.favorite.x, with_x.confirm.x), "X sits above A")
	assert_true(buttons.offers_x([["confirm", "Launch"], ["favorite", "Favorite"]]), "game list offers X")
	assert_false(buttons.offers_x([["confirm", "Open"]]), "systems list does not")

func test_letter_jumps_wrap_around():
	var scroller = load("res://scenes/letter_scroller.gd")
	var starts = [0, 3, 7]
	assert_eq(scroller.wrapped_group(starts, 0, -1), 2, "# back to Z")
	assert_eq(scroller.wrapped_group(starts, 8, 1), 0, "Z forward to #")
	assert_eq(scroller.wrapped_group(starts, 5, 1), 2, "middle of a group moves to the next one")

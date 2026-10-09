extends "res://tests/test_case.gd"

const SettingsMenu = preload("res://scenes/settings_menu.gd")

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

func test_cover_slides_only_enough_to_clear_the_popup():
	var scroller = load("res://scenes/letter_scroller.gd")
	assert_eq(scroller.clearance(1500.0, 1600.0, 10.0), 0.0, "small cover stays put")
	assert_eq(scroller.clearance(1700.0, 1600.0, 10.0), 110.0, "big cover moves just past the popup")
	assert_eq(scroller.clearance(1595.0, 1600.0, 10.0), 5.0, "near miss only nudges")

func test_press_pivots_at_the_start_of_the_text():
	assert_eq(Global.text_start(200.0, 800.0, HORIZONTAL_ALIGNMENT_LEFT), 0.0, "left text from its left edge")
	assert_eq(Global.text_start(200.0, 800.0, HORIZONTAL_ALIGNMENT_CENTER), 300.0, "centered text from where it begins")
	assert_eq(Global.text_start(200.0, 800.0, HORIZONTAL_ALIGNMENT_RIGHT), 600.0, "right text from where it begins")
	assert_eq(Global.text_start(1000.0, 800.0, HORIZONTAL_ALIGNMENT_RIGHT), 0.0, "cut-off text from the slot edge")

func test_lifted_text_lands_centered():
	assert_eq(Global.centered_left(200.0, 1000.0), 400.0, "text centered on screen")
	assert_eq(Global.centered_left(1000.0, 1000.0), 0.0, "full-width text starts at the edge")

func test_launch_view_names_the_retroarch_core():
	assert_eq(Global.launcher_label("retroarch", "gambatte"), "retroarch (gambatte)", "core after RetroArch")
	assert_eq(Global.launcher_label("retroarch64", "mgba"), "retroarch64 (mgba)", "any RetroArch build")
	assert_eq(Global.launcher_label("duckstation", "pcsx_rearmed"), "duckstation", "other launchers unchanged")
	assert_eq(Global.launcher_label("retroarch", null), "retroarch", "no core set")
	assert_eq(Global.launcher_label("retroarch", "NULL"), "retroarch", "placeholder core ignored")

func test_scrolling_waits_for_the_cover():
	assert_false(Global.art_wait_over("/a.png", false, 100), "waits while the cover loads")
	assert_true(Global.art_wait_over("/a.png", true, 100), "moves once it is loaded")
	assert_true(Global.art_wait_over("", false, 0), "no cover to wait for")
	assert_true(Global.art_wait_over("/a.png", false, Global.ART_WAIT_MAX_MS), "gives up on a slow cover")

func test_list_locked_while_an_effect_plays():
	var was = Global.launching
	Global.launching = true
	var locked = Global.cursor_locked()
	var special = Global.special_allowed()
	Global.launching = was
	assert_true(locked, "no scrolling during the open or launch animation")
	assert_false(special, "no options or letter jumps either")

func test_inline_covers():
	assert_eq(SettingsMenu.COVER_SIZE_NAMES, ["Off", "Small", "Medium", "Large"], "sizes no longer include Inline")
	assert_eq(SettingsMenu.COVER_STYLE_NAMES.size(), Settings.COVER_STYLES.size(), "a name per style")
	var covers = load("res://scenes/inline_covers.gd")
	assert_true(covers.fit_rect(Vector2(100, 200), Rect2(0, 0, 60, 60)).is_equal_approx(Rect2(15, 0, 30, 60)), "tall cover centered in its box")
	assert_true(covers.fit_rect(Vector2(200, 100), Rect2(10, 10, 60, 60)).is_equal_approx(Rect2(10, 25, 60, 30)), "wide cover centered in its box")
	assert_eq(Global.inline_row_step(20.0, 100.0), 100.0 * (1.0 + Global.INLINE_ROW_GAP), "rows grow to fit big covers")
	assert_eq(Global.inline_row_step(200.0, 100.0), 200.0, "big text keeps its own spacing")
	var saved_style = Settings._data.get(Settings.CFG_COVER_STYLE)
	var saved_size = Settings._data.get(Settings.CFG_VISUAL_COVER_SIZE)
	Settings._data[Settings.CFG_COVER_STYLE] = "inline"
	Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = Settings.COVER_SIZES[1]
	var inline_on = Global.inline_covers()
	var big_cover = Global.cover_size()
	Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = Vector2.ZERO
	var off_inline = Global.inline_covers()
	for pair in [[Settings.CFG_COVER_STYLE, saved_style], [Settings.CFG_VISUAL_COVER_SIZE, saved_size]]:
		if pair[1] == null:
			Settings._data.erase(pair[0])
		else:
			Settings._data[pair[0]] = pair[1]
	assert_true(inline_on, "Inline style on")
	assert_eq(big_cover, Vector2.ZERO, "no side cover in Inline")
	assert_true(Global.inline_box_for(720.0, Settings.COVER_SIZES[3]).y > Global.inline_box_for(720.0, Settings.COVER_SIZES[1]).y, "cover size sets the inline size")
	assert_eq(Global.inline_box_for(1000.0, Settings.COVER_SIZES[2]), Vector2(135.0, 180.0), "Medium is 18% of the screen height, in a portrait box")
	assert_false(off_inline, "Off hides inline covers too")

func test_inline_rows_make_room_only_for_art():
	assert_eq(Global.inline_slot_frame(10.0, 1000.0, 100.0, true, true), Vector2(110.0, 900.0), "left covers push the title right")
	assert_eq(Global.inline_slot_frame(10.0, 1000.0, 100.0, false, true), Vector2(10.0, 900.0), "right covers shorten the title")
	assert_eq(Global.inline_slot_frame(10.0, 1000.0, 100.0, true, false), Vector2(110.0, 900.0), "no art on the left, title stays lined up")
	assert_eq(Global.inline_slot_frame(10.0, 1000.0, 100.0, false, false), Vector2(10.0, 1000.0), "no art on the right, title runs full width")

func test_inline_titles_clear_the_cover_area():
	var width = 1280.0
	var box = Global.inline_box().x
	var reserve = Global.inline_reserve()
	var left_area = Global.cover_area_span(width, Global.left_bound, box, 0.0, true, true)
	var left_frame = Global.inline_slot_frame(Global.left_bound, width - Global.left_bound * 2.0, reserve, true, true)
	assert_true(left_frame.x >= left_area.y, "left covers keep titles out of the cover area")
	var right_area = Global.cover_area_span(width, Global.left_bound, box, 0.0, false, true)
	var right_frame = Global.inline_slot_frame(Global.left_bound, width - Global.left_bound * 2.0, reserve, false, true)
	assert_true(right_frame.x + right_frame.y <= right_area.x, "right covers cut titles before the cover area")

func test_cover_style_migration():
	var inline = Settings.migrated_cover_style({Settings.CFG_VISUAL_COVER_SIZE: Settings.INLINE_COVER})
	assert_eq(inline[Settings.CFG_COVER_STYLE], "inline", "old Inline size becomes the Inline style")
	assert_eq(inline[Settings.CFG_VISUAL_COVER_SIZE], Settings.COVER_SIZES[2], "at Medium size")
	var nearby = Settings.migrated_cover_style({Settings.CFG_NEARBY_COVERS: true})
	assert_eq(nearby[Settings.CFG_COVER_STYLE], "stacked", "Nearby covers becomes Stacked")
	assert_false(nearby.has(Settings.CFG_NEARBY_COVERS), "old key dropped")
	var plain = {Settings.CFG_VISUAL_COVER_SIZE: Settings.COVER_SIZES[1]}
	assert_eq(Settings.migrated_cover_style(plain), plain, "nothing to migrate")
	var chosen = Settings.migrated_cover_style({Settings.CFG_COVER_STYLE: "wheel", Settings.CFG_NEARBY_COVERS: true})
	assert_eq(chosen[Settings.CFG_COVER_STYLE], "wheel", "a chosen style is kept")

func test_wheel_curves_away_from_the_list():
	var center = Global.wheel_place(0.0, 400.0, 20.0, 1.0)
	assert_eq(center.offset, Vector2.ZERO, "selected cover at home")
	assert_eq(center.scale, 1.0, "full size")
	var below = Global.wheel_place(1.0, 400.0, 20.0, 1.0)
	var above = Global.wheel_place(-1.0, 400.0, 20.0, 1.0)
	assert_true(below.offset.y > 0.0 and above.offset.y < 0.0, "neighbors above and below")
	assert_true(below.offset.x > 0.0 and is_equal_approx(below.offset.x, above.offset.x), "both bend right, away from a left list")
	assert_true(is_equal_approx(below.offset.y, 400.0 * (0.5 + Global.NEARBY_SCALE * 0.5) + 20.0), "first neighbor clears the main cover")
	var far = Global.wheel_place(2.0, 400.0, 20.0, 1.0)
	assert_true(far.offset.x > below.offset.x and far.scale < below.scale and far.alpha < below.alpha, "further covers curve more, shrink, and fade")
	assert_true(Global.wheel_place(1.0, 400.0, 20.0, -1.0).offset.x < 0.0, "left covers bend left")
	var halfway = Global.wheel_place(0.5, 400.0, 20.0, 1.0)
	assert_true(halfway.scale < 1.0 and halfway.scale > below.scale, "sliding covers resize smoothly")

func test_hiding_keeps_a_spot_in_the_list():
	assert_eq(Global.kept_position(4, 2, 10, 5), Vector2i(4, 2), "next item slides into the hidden one's place")
	assert_eq(Global.kept_position(9, 5, 9, 5), Vector2i(8, 4), "hiding the last item selects the new last one")
	assert_eq(Global.kept_position(0, 0, 0, 5), Vector2i(0, 0), "empty list stays at the top")
	assert_eq(Global.kept_position(3, 3, 4, 5), Vector2i(3, 0), "short list scrolls back to the top")

func test_closing_a_panel_does_not_confirm_underneath():
	assert_true(Global.confirm_blocked(100, 102), "same frame as the close")
	assert_true(Global.confirm_blocked(102, 102), "still settling")
	assert_false(Global.confirm_blocked(103, 102), "back to normal afterwards")
	var saved = Global.waiting_for_confirm_release
	Global.block_confirm()
	var pressed = Global.confirm_pressed()
	Global.waiting_for_confirm_release = saved
	Global._confirm_blocked_until = -1
	assert_false(pressed, "no confirm right after a panel closes")

func test_refresh_shake_settles_where_it_started():
	var offsets = Global.shake_offsets(10.0)
	assert_eq(offsets.back(), 0.0, "ends back in place")
	assert_true(offsets.any(func(o): return o > 0.0) and offsets.any(func(o): return o < 0.0), "goes both ways")
	assert_true(absf(offsets[0]) > absf(offsets[-3]), "dies down")

func test_systems_screen_refreshes_on_x():
	var systems = load("res://scenes/subscreens/system_browser.gd")
	assert_true(["favorite", "Refresh"] in systems.PROMPTS, "X refreshes on the Systems screen")
	var buttons = load("res://scenes/touch_buttons.gd")
	assert_true(buttons.offers_x(systems.PROMPTS), "touch X shown there too")

func test_holding_delete_keeps_deleting():
	var panel = SlidePanel.new()
	var deleted = [0]
	var held = [true]
	panel._menu = {"repeat_held": func(): return held[0], "on_repeat": func(): deleted[0] += 1}
	panel._update_repeat(1000)
	panel._update_repeat(1000 + SlidePanel.HOLD_DELAY_MS - 1)
	assert_eq(deleted[0], 0, "a quick press doesn't repeat")
	panel._update_repeat(1000 + SlidePanel.HOLD_DELAY_MS)
	panel._update_repeat(1000 + SlidePanel.HOLD_DELAY_MS + SlidePanel.HOLD_REPEAT_MS)
	panel._update_repeat(1000 + SlidePanel.HOLD_DELAY_MS + SlidePanel.HOLD_REPEAT_MS * 2)
	assert_eq(deleted[0], 3, "keeps deleting while held")
	assert_true(panel._repeated, "release won't delete one more")
	held[0] = false
	panel._update_repeat(2000)
	assert_false(panel._repeated, "stops when let go")
	panel.free()

func test_keyboard_knows_the_delete_key():
	var keyboard = TextKeyboard.new()
	keyboard.index = keyboard.keys.find_custom(func(k): return k.type == "delete")
	assert_true(keyboard.on_delete(), "Del key selected")
	keyboard.index = 0
	assert_false(keyboard.on_delete(), "a letter isn't")
	keyboard.free()

func test_dpad_locked_while_letters_peek():
	var scroller = Global.letter_scroller
	var made = scroller == null
	if made:
		scroller = load("res://scenes/letter_scroller.gd").new()
		Global.letter_scroller = scroller
	var was = [scroller.active, scroller.peeking, Global.disable_scroll, Global.launching]
	Global.disable_scroll = false
	Global.launching = false
	scroller.active = true
	scroller.peeking = true
	var locked = Global.cursor_locked()
	scroller.active = was[0]
	scroller.peeking = was[1]
	Global.disable_scroll = was[2]
	Global.launching = was[3]
	if made:
		Global.letter_scroller = null
		scroller.free()
	assert_true(locked, "the d-pad doesn't move the list while L/R letter jumps are showing")

func test_cover_stays_shifted_while_letters_scroll():
	assert_eq(Global.letter_shifted_x(960.0, 1.0, 200.0), 760.0, "new cover lands where the scroller holds it")
	assert_eq(Global.letter_shifted_x(960.0, 0.0, 200.0), 960.0, "normal spot once the scroller is gone")

func test_peek_row_shows_any_visible_sliver():
	assert_eq(Global.peek_rows_for(100.0, 3, 130.0, 460.0), 1, "next row's stripe starts at 425, so it peeks")
	assert_eq(Global.peek_rows_for(100.0, 3, 130.0, 425.0), 0, "nothing of it would show")

func test_peek_row_title_hidden_when_cut_off():
	assert_true(Global.text_fits(600.0, 650.0), "title shows when it fits")
	assert_false(Global.text_fits(700.0, 650.0), "hidden instead of overlapping the prompts")

func test_peek_row_cover_is_cut_at_the_bottom():
	var covers = load("res://scenes/inline_covers.gd")
	assert_eq(covers.cropped_to(Rect2(0, 600, 50, 100), 650.0), 50.0, "half of the peeking cover shows")
	assert_eq(covers.cropped_to(Rect2(0, 600, 50, 100), 800.0), 100.0, "whole cover when it fits")
	assert_eq(covers.cropped_to(Rect2(0, 700, 50, 100), 650.0), 0.0, "nothing below the edge")

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

func test_cut_off_rows_are_known():
	view.size = Vector2(200, 60)
	view.font_size = 10
	view.row_height = 20
	var short = option.new_option("Path")
	var long_line = option.new_option("/storage/9A7C-056B/PlainLauncher/Games/GBA/A Really Long Game Name That Will Not Fit (USA, Europe).gba")
	var long_value = option.new_option("Command")
	long_value.set_meta("value", "retroarch -f -c /run/muos/storage/info/config/retroarch.cfg -L /mnt/mmc/MUOS/core/mgba_libretro.so {game}")
	view.set_items([short, long_line, long_value])
	assert_false(view.is_cut_off(0), "short row fits")
	assert_true(view.is_cut_off(1), "long line is cut off")
	assert_true(view.is_cut_off(2), "long value is cut off")

func test_full_text_page_shows_the_whole_value():
	var panel = SlidePanel.new()
	var item = option.new_option("Command")
	item.set_meta("value", "retroarch -L core.so game.gba")
	panel.show_full_text_of(item)
	var page = panel.menus.back().call()
	assert_true(page.static, "read-only page")
	assert_eq(page.title, "Command", "titled by the row")
	assert_eq(page.items.map(func(o): return o.clean), ["retroarch -L core.so game.gba"], "whole value")
	panel.free()

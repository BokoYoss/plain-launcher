extends "res://tests/test_case.gd"

const SettingsMenu = preload("res://scenes/settings_menu.gd")
const PromptBar = preload("res://scenes/prompt_bar.gd")
const OptionsMenu = preload("res://scenes/options_menu.gd")

class FakePanel:
	var pushed: Array = []
	var peeks = 0
	func peek():
		peeks += 1
	var opened_screens: Array = []
	var backs = 0
	var is_open = true
	func relayout():
		pass
	func push_menu(builder: Callable):
		pushed.append(builder)
	func show_menu(_keep := true):
		pass
	func back():
		backs += 1
	func open_screen(screen: String):
		opened_screens.append(screen)
	func open(builder: Callable):
		pushed.append(builder)

var panel: FakePanel
var menu
var saved = {}

func before_each():
	panel = FakePanel.new()
	menu = SettingsMenu.new(panel)
	for key in [Settings.CFG_VISUAL_BORDER, Settings.CFG_LEFT_MARGIN, Settings.CFG_BG_COLOR, Settings.CFG_FG_COLOR, Settings.CFG_VISUAL_ART_POSITION_X, Settings.CFG_VISUAL_ART_POSITION_Y]:
		saved[key] = Settings._data.get(key) if Settings._data != null else null

func after_each():
	for key in saved:
		if saved[key] == null:
			Settings._data.erase(key)
		else:
			Settings._data[key] = saved[key]
	Global.settings_reopen_section = null

static func _text(o) -> String:
	if o.has_meta("checked"):
		return o.clean + ": " + ("On" if o.get_meta("checked") else "Off")
	if o.has_meta("value"):
		return o.clean + ": " + str(o.get_meta("value"))
	return o.clean

func _labels(builder: Callable) -> Array:
	return builder.call().items.map(_text)

func test_text_size_words_follow_screen_default():
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(1.1, 1.1)], "Medium", "device default is Medium")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(1.32, 1.1)], "Large", "20% bigger is Large")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(0.5, 1.1)], "Small", "much smaller is Small")

func test_font_names():
	assert_eq(SettingsMenu.font_name("res://launcher_configs/COMMON/fonts/Grandstander/Grandstander-Medium.ttf"), "Grandstander", "folder name shown")
	assert_eq(SettingsMenu.font_name(null), "Default", "no font set")

func test_visual_settings_show_words_not_numbers():
	var labels = _labels(menu.visual_menu)
	var numeric = labels.filter(func(l): return RegEx.create_from_string(": \\d+$").search(l) != null)
	assert_eq(numeric, [], "no numeric values")
	for prefix in ["Text size: ", "Font: ", "Cover size: ", "Cover border: ", "Title alignment: ", "Button prompts: "]:
		assert_true(labels.any(func(l): return l.begins_with(prefix)), prefix + "present")
	for removed in ["Cover opacity", "Drop shadow", "Left margin", "Top margin", "Title size", "Text cutoff", "Letter outlines"]:
		assert_false(labels.any(func(l): return l.begins_with(removed)), removed + " removed")

func test_retired_settings_use_fixed_values():
	Settings._data[Settings.CFG_LEFT_MARGIN] = 64.0
	assert_eq(Settings.get_setting(Settings.CFG_LEFT_MARGIN), Settings.DEFAULT_SETTINGS[Settings.CFG_LEFT_MARGIN], "old margin ignored")

func test_old_border_widths_become_on():
	Settings._data[Settings.CFG_VISUAL_BORDER] = Vector2(32, 32)
	assert_eq(Settings.get_setting(Settings.CFG_VISUAL_BORDER), SettingsMenu.COVER_BORDER, "wide border normalized")
	Settings._data[Settings.CFG_VISUAL_BORDER] = Vector2.ZERO
	assert_eq(Settings.get_setting(Settings.CFG_VISUAL_BORDER), Vector2.ZERO, "off stays off")

func test_confirmation_steps_in_panel():
	var restore = menu.visual_menu().items.filter(func(o): return o.clean == "Restore defaults")
	assert_eq(restore.size(), 1, "restore item present")
	restore[0].trigger(Actions.CONFIRM)
	assert_eq(panel.pushed.size(), 1, "confirmation pushed")
	var confirm = panel.pushed[0].call()
	assert_eq(confirm.items.map(func(o): return o.clean), ["Restore", "Cancel"], "yes/cancel")
	confirm.items[1].trigger(Actions.CONFIRM)
	assert_eq(panel.backs, 1, "cancel goes back")

func test_color_picker_lives_in_panel():
	var color = menu.visual_menu().items.filter(func(o): return o.clean == "Background color")[0]
	color.trigger(Actions.CONFIRM)
	assert_eq(panel.opened_screens, [], "no separate screen")
	var picker = panel.pushed[0].call()
	var grid: PaletteGrid = picker.custom
	assert_eq(grid.colors.size(), 256, "whole palette loaded")
	var before: Color = Settings.get_setting(Settings.CFG_BG_COLOR)
	grid.move(1, 0)
	assert_eq(Settings.get_setting(Settings.CFG_BG_COLOR), grid.selected_color(), "moving previews the color")
	picker.on_cancel.call()
	assert_eq(Settings.get_setting(Settings.CFG_BG_COLOR), before, "cancel restores")
	grid.free()

func test_palette_grid_fills_panel():
	assert_eq(PaletteGrid.columns_for(256, Vector2(800, 800)), 16, "square area is 16x16")
	assert_true(PaletteGrid.columns_for(256, Vector2(400, 800)) < 16, "tall area uses fewer columns")
	for area in [Vector2(400, 800), Vector2(900, 900), Vector2(1400, 700), Vector2(700, 1000), Vector2(500, 300)]:
		assert_eq(256 % PaletteGrid.columns_for(256, area), 0, "rows always full at " + str(area))
	var grid = PaletteGrid.new()
	grid.size = Vector2(100, 100)
	grid.colors = [Color.RED, Color.GREEN, Color.BLUE, Color.WHITE, Color.BLACK, Color.GRAY]
	assert_eq(grid.columns(), 2, "six swatches in two full columns")
	grid.index = 1
	grid.move(0, 1)
	assert_eq(grid.selected_color(), Color.WHITE, "down keeps column")
	grid.move(1, 0)
	assert_eq(grid.selected_color(), Color.BLUE, "right wraps within the row")
	grid.select_color(Color.BLUE)
	assert_eq(grid.index, 2, "select finds swatch")
	grid.free()

func test_scraper_and_launchers_in_panel():
	assert_true(_labels(menu.scraper_menu).any(func(l): return l.begins_with("SteamGridDB key: ")), "sgdb key row")
	assert_eq(SettingsMenu.sgdb_result(401), "Invalid, not saved", "rejected key")
	assert_eq(_labels(menu.launchers_menu), ["Built-in launchers", "Custom launchers", "Exit RetroArch on focus loss: Off"], "launchers sections")
	var built_in = _labels(menu.built_in_launchers_menu)
	assert_true("nethersx2_turnip" in built_in, "built-ins listed")
	assert_eq(_labels(menu.custom_launchers_menu)[0], "Add new launcher", "add first in custom")
	assert_false("nethersx2_turnip" in _labels(menu.custom_launchers_menu), "built-ins not in custom list")

func test_built_in_launcher_is_read_only():
	var items = menu.intent_menu("nethersx2_turnip").items
	assert_true(_text(items[1]) == "Package: xyz.aethersx2.cturnip", "package shown")
	assert_false(items[1].handles(Actions.CONFIRM), "fields locked")
	assert_eq(items.back().clean, "Make a custom copy", "copy offered")
	assert_eq(menu.intent_menu("nethersx2_turnip").width, SlidePanel.WIDE_RATIO, "launcher details use a wide panel")
	assert_false(menu.visual_menu().has("width"), "regular menus use the default width")
	assert_false(items.any(func(o): return _text(o) == "File: None"), "empty fields hidden")

func test_credits_split_links():
	var lines = SettingsMenu.font_credit_lines("Rubik")
	assert_eq(lines[0], "Copyright 2015 The Rubik Project Authors", "copyright")
	assert_eq(lines[1], "https://github.com/googlefonts/rubik", "link on its own row")
	assert_eq(lines.back(), SettingsMenu.OFL_URL, "license link")

func test_font_picker_lives_in_panel():
	var font = menu.visual_menu().items.filter(func(o): return _text(o).begins_with("Font: "))[0]
	font.trigger(Actions.CONFIRM)
	assert_eq(panel.opened_screens, [], "no separate screen")
	var families = panel.pushed[0].call()
	var names = families.items.map(func(o): return o.clean.trim_prefix("• "))
	assert_true("Rubik" in names and "Grandstander" in names, "families listed")
	assert_true(families.items.all(func(o): return o.has_meta("font")), "each family drawn in its own font")
	var rubik = families.items.filter(func(o): return o.clean.trim_prefix("• ") == "Rubik")[0]
	rubik.trigger(Actions.CONFIRM)
	var weights = panel.pushed[1].call()
	assert_eq(weights.items.map(func(o): return o.clean.trim_prefix("• ")), SettingsMenu.FONT_WEIGHTS, "all weights offered")

func test_font_menu_marks_current_font():
	var saved_font = Settings._data.get(Settings.CFG_FONT)
	Settings._data.erase(Settings.CFG_FONT)
	var labels = menu.font_menu().items.map(func(o): return o.clean)
	if saved_font != null:
		Settings._data[Settings.CFG_FONT] = saved_font
	assert_true("• Rubik" in labels, "default font marked")

func test_main_menu_sections():
	assert_eq(_labels(menu.main_menu), ["General", "Visuals", "Controls", "Collections", "Scraper", "Launchers", "Credits", "Quit"], "main menu")
	for builder in [menu.main_menu, menu.visual_menu, menu.general_menu]:
		builder.call().items.map(func(o): o.trigger(Actions.CONFIRM) if o.clean in ["Scraper", "Launchers", "Credits", "Background color", "Text color"] else null)
	assert_eq(panel.opened_screens, [], "only storage opens a screen")
	assert_true("Refresh file cache" in _labels(menu.general_menu), "refresh moved to General")

func test_favorite_uses_x():
	assert_eq(PromptBar.glyph_for("favorite", false), "X", "favorite on X")

func test_default_values_show_correct_words():
	var keys = [Settings.CFG_VISUAL_COVER_SIZE, Settings.CFG_VISUAL_TITLE_ORIENTATION]
	var before = keys.map(func(k): return Settings._data.get(k))
	for k in keys:
		Settings._data.erase(k)
	var labels = _labels(menu.visual_menu)
	for i in range(keys.size()):
		if before[i] != null:
			Settings._data[keys[i]] = before[i]
	assert_true("Cover size: Medium" in labels, "default cover size is Medium")
	assert_true("Title alignment: Left" in labels, "default alignment is Left")

func test_values_and_checkboxes_are_separate_from_labels():
	var items = menu.visual_menu().items
	var size = items.filter(func(o): return o.clean == "Text size")[0]
	assert_true(size.has_meta("value"), "text size shows a value")
	var prompts = items.filter(func(o): return o.clean == "Button prompts")[0]
	assert_true(prompts.get_meta("checked") is bool, "booleans are checkboxes")
	assert_false(items.any(func(o): return ": " in o.clean), "no label: value text")

func test_options_labels():
	assert_eq(OptionsMenu.setting_name("EMULATOR", false), "Emulator", "game emulator")
	assert_eq(OptionsMenu.setting_name("EMULATOR", true), "Default emulator", "system emulator")
	assert_eq(OptionsMenu.value_text(["gba", "zip"]), "gba, zip", "lists joined")
	assert_eq(OptionsMenu.value_text(""), "None", "blank shown as None")
	assert_eq(OptionsMenu.decode_image(PackedByteArray([1, 2, 3])), null, "junk bytes rejected")

func test_forced_cover_shows_when_cover_art_off():
	var saved_size = Settings._data.get(Settings.CFG_VISUAL_COVER_SIZE)
	Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = Vector2.ZERO
	Global.force_cover = true
	var forced = Global.cover_size()
	var anchor = Global.cover_anchor()
	Global.force_cover = false
	var normal = Global.cover_size()
	if saved_size == null:
		Settings._data.erase(Settings.CFG_VISUAL_COVER_SIZE)
	else:
		Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = saved_size
	assert_eq(forced, Settings.COVER_SIZES[2], "options panel forces a medium cover")
	assert_eq(anchor, Vector2(0.75, 0.5), "cover sits right of the panel")
	assert_eq(normal, Vector2.ZERO, "off again after closing")

func test_options_hide_unknown_setting_keys():
	var current = {"Alternate Art Path": "/storage/FAILURE/", "CORE": "mgba", "EMULATOR": "retroarch", "EXTENSIONS": ["gba"]}
	var choices = {"EMULATOR": [], "CORE": [], "EXTENSIONS": []}
	assert_eq(OptionsMenu.shown_keys(current, choices), ["EMULATOR", "CORE", "EXTENSIONS"], "stray keys hidden, emulator first")

func test_cover_position_left_or_right():
	var saved_side = Settings._data.get(Settings.CFG_COVER_SIDE)
	Settings._data.erase(Settings.CFG_COVER_SIDE)
	assert_true("Cover position: Right" in _labels(menu.visual_menu), "right by default")
	Settings._data[Settings.CFG_VISUAL_ART_POSITION_X] = 0.25
	assert_eq(Global.cover_anchor(), Vector2(0.75, 0.5), "old free placement ignored")
	Settings._data[Settings.CFG_COVER_SIDE] = "left"
	assert_true(is_equal_approx(Global.left_cover_anchor_x(1920.0, 16.0, 384.0), 208.0 / 1920.0), "small cover hugs the left margin")
	Global.force_cover = true
	assert_eq(Global.cover_anchor(), Vector2(0.75, 0.5), "options panel keeps it on the right")
	Global.force_cover = false
	if saved_side == null:
		Settings._data.erase(Settings.CFG_COVER_SIDE)
	else:
		Settings._data[Settings.CFG_COVER_SIDE] = saved_side
	assert_eq(Global.left_cover_shift(384.0, 30.0), 414.0, "list slides just past a small cover")
	assert_eq(Settings.get_setting(Settings.CFG_VISUAL_ART_POSITION_X), 0.75, "old placement ignored")

func test_flipping_cover_size_peeks_panel():
	var saved_size = Settings._data.get(Settings.CFG_VISUAL_COVER_SIZE)
	var cover = menu.visual_menu().items.filter(func(o): return o.clean == "Cover size")[0]
	cover.trigger(Actions.DIRECTION, [1])
	cover.trigger(Actions.DIRECTION, [-1])
	if saved_size == null:
		Settings._data.erase(Settings.CFG_VISUAL_COVER_SIZE)
	else:
		Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = saved_size
	assert_eq(panel.peeks, 2, "panel fades while flipping cover sizes")

const ArtScraper = preload("res://scenes/art_scraper.gd")

func test_launch_failure_lines():
	assert_eq(SettingsMenu.failure_lines("No intent", "com.emu", "/roms/a.gba"), ["No intent", "Check that com.emu is installed and can read", "/roms/a.gba"], "game failure")
	assert_eq(SettingsMenu.failure_lines("Not installed", "com.app", ""), ["Not installed", "Check that com.app is installed"], "app failure")

func test_storage_lives_in_panel():
	var storage = menu.general_menu().items.filter(func(o): return o.clean == "Storage")[0]
	storage.trigger(Actions.CONFIRM)
	assert_eq(panel.opened_screens, [], "no storage screen")
	assert_true(_labels(panel.pushed[0]).has("Use removable storage"), "storage choices listed")

func test_scraper_helpers():
	assert_eq(ArtScraper.pick_ss_art_url([{"type": "box-2D", "region": "jp", "url": "j"}, {"type": "box-2D", "region": "us", "url": "u"}]), "u", "prefers US over JP")
	assert_eq(ArtScraper.missing_credentials("screenscraper", "NOTASYSTEM"), "NOTASYSTEM is not on ScreenScraper", "unsupported system")

func test_touch_controls_can_be_turned_off():
	var touch = menu.controls_menu().items.filter(func(o): return o.clean == "Touch controls")
	assert_eq(touch.size(), 1, "touch toggle in controls")
	assert_eq(Settings.DEFAULT_SETTINGS[Settings.CFG_TOUCH_ENABLED], true, "touch on by default")

func test_bar_color_defaults_to_background():
	assert_eq(Settings.DEFAULT_SETTINGS[Settings.CFG_BAR_COLOR], null, "off by default")
	assert_eq(Global.bar_color_for(null, Color.RED), Color.RED, "off follows the background")
	assert_eq(Global.bar_color_for(Color.BLUE, Color.RED), Color.BLUE, "set color used for bars")
	var saved = Settings._data.get(Settings.CFG_BAR_COLOR)
	Settings._data.erase(Settings.CFG_BAR_COLOR)
	assert_true("Bar color: Off" in _labels(menu.visual_menu), "row shows Off")
	var picker = menu.color_menu("Bar color", Settings.CFG_BAR_COLOR, Settings.CFG_FG_COLOR)
	assert_eq(picker.prompts[1], ["favorite", "Off"], "X turns bars off")
	picker.custom.free()
	if saved != null:
		Settings._data[Settings.CFG_BAR_COLOR] = saved

func test_keep_color_survives_closing_picker():
	var saved = Settings._data.get(Settings.CFG_BAR_COLOR)
	Settings._data.erase(Settings.CFG_BAR_COLOR)
	var picker = menu.color_menu("Bar color", Settings.CFG_BAR_COLOR, Settings.CFG_FG_COLOR)
	picker.custom.move(1, 0)
	var chosen = picker.custom.selected_color()
	picker.on_confirm.call()
	picker.on_cancel.call()
	assert_eq(Settings.get_setting(Settings.CFG_BAR_COLOR), chosen, "kept color stays after the panel closes")
	picker.custom.free()
	if saved == null:
		Settings._data.erase(Settings.CFG_BAR_COLOR)
	else:
		Settings._data[Settings.CFG_BAR_COLOR] = saved

func test_x_resets_every_visual_and_control_setting():
	var skip = ["Restore defaults"]
	for builder in [menu.visual_menu, menu.controls_menu]:
		for o in builder.call().items:
			if o.clean in skip:
				continue
			assert_true(o.handles(Actions.START), o.clean + " has a default")

func test_restore_defaults_reloads_font():
	var saved_font = Settings._data.get(Settings.CFG_FONT)
	var saved_global = Global.font
	Settings._data[Settings.CFG_FONT] = SettingsMenu.font_path("Grandstander", "Medium")
	Global.font = load(Settings._data[Settings.CFG_FONT])
	var restore = menu.visual_menu().items.filter(func(o): return o.clean == "Restore defaults")[0]
	restore.trigger(Actions.CONFIRM)
	var backup = Settings._data.duplicate()
	panel.pushed[0].call().items[0].trigger(Actions.CONFIRM)
	var restored_path = Global.font.resource_path
	Settings._data = backup
	if saved_font == null:
		Settings._data.erase(Settings.CFG_FONT)
	else:
		Settings._data[Settings.CFG_FONT] = saved_font
	Global.font = saved_global
	assert_eq(restored_path, SettingsMenu.DEFAULT_FONT, "default font loaded")

func test_list_hugs_title_and_stops_before_prompts():
	var layout = Global.hug_layout(40.0, 1000.0, 60.0, 48.0, 42.0, 12.0, 10.0, 15.0)
	assert_true(is_equal_approx(layout[1] + 48.0 - 42.0, 50.0), "first row a small gap under the title")
	var last_bottom = layout[1] + (layout[0] - 1) * 60.0 + 48.0 + 12.0
	assert_true(last_bottom <= 1000.0 - 15.0, "last row clears the prompts")
	assert_true(last_bottom + 60.0 > 1000.0 - 15.0, "no room for another row")

func test_more_rows_beat_bigger_text_then_bigger_prompts():
	assert_true(Global.better_layout([14, 0.9, 0.4], [13, 1.0, 0.5]), "an extra row wins")
	assert_true(Global.better_layout([13, 1.0, 0.4], [13, 0.94, 0.5]), "then text closest to the setting")
	assert_true(Global.better_layout([13, 1.0, 0.5], [13, 1.0, 0.4]), "then half-size prompts")
	assert_true(Global.prompt_scale >= Global.PROMPT_SCALE_MIN and Global.prompt_scale <= Global.PROMPT_SCALE_MAX, "scale in range")

func test_text_runs_full_width():
	assert_eq(Global.list_text_width(), Global.window_width - Global.left_bound * 2.0, "full width regardless of cover")

func test_cover_fade_surrounds_art():
	var quads = load("res://scenes/cover_halo.gd").fade_quads(Vector2(100, 150), 20.0)
	assert_eq(quads.size(), 8, "four edges and four corners")
	var reach = 0.0
	for quad in quads:
		for point in quad.points:
			reach = maxf(reach, absf(point.x))
	assert_eq(reach, 120.0, "fade extends past the art by the feather width")

func test_nearby_covers_option():
	assert_true(_labels(menu.visual_menu).has("Nearby covers: Off"), "off by default")
	assert_eq(Global.nearby_offset(600.0, 300.0, 20.0), 470.0, "small cover sits just past the main one")

func test_nearby_covers_stop_at_the_bars():
	assert_eq(Global.nearby_crop(100.0, 200.0, 60.0, 1000.0), Vector2(60.0, 0.0), "top trimmed at the title bar")
	assert_eq(Global.nearby_crop(980.0, 200.0, 60.0, 1000.0), Vector2(0.0, 80.0), "bottom trimmed at the prompt bar")
	assert_eq(Global.nearby_crop(500.0, 200.0, 60.0, 1000.0), Vector2.ZERO, "fully visible untouched")

func test_retired_font_weights_fall_back():
	var base = "res://launcher_configs/COMMON/fonts/Rubik/Rubik-"
	assert_eq(Settings.supported_font(base + "Regular.ttf"), base + "Medium.ttf", "Regular becomes Medium")
	assert_eq(Settings.supported_font(base + "ExtraBold.ttf"), base + "Bold.ttf", "ExtraBold becomes Bold")
	assert_eq(Settings.supported_font(base + "Light.ttf"), base + "Light.ttf", "kept weights stay")
	assert_eq(Settings.supported_font("res://launcher_configs/COMMON/fonts/Gone/Gone-Medium.ttf"), null, "missing family uses the default")
	assert_eq(Settings.supported_font(null), null, "no font stays unset")

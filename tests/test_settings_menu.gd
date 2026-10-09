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
	func text_input(prompt: String, value: String, password: bool, on_text: Callable):
		Platform.show_text_input(prompt, value, password, on_text)

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

func _visual_items() -> Array:
	var items = []
	for builder in [menu.visual_menu, menu.text_menu, menu.colors_menu, menu.cover_menu]:
		items.append_array(builder.call().items)
	return items

func _visual_labels() -> Array:
	return _visual_items().map(func(o): return _text(o))

func _labels(builder: Callable) -> Array:
	return builder.call().items.map(_text)

func test_text_size_words_follow_screen_default():
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(1.1, 1.1)], "Medium", "device default is Medium")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(1.32, 1.1)], "Large", "20% bigger is Large")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(0.88, 1.1)], "Small", "20% smaller is Small")

func test_visuals_grouped_into_submenus():
	var top = menu.visual_menu().items.map(func(o): return o.clean)
	assert_eq(top.slice(0, 3), ["Text", "Color", "Cover Art"], "groups first")
	assert_eq(menu.text_menu().items.map(func(o): return o.clean), ["Text size", "Font", "Uppercase text"], "text group")
	assert_eq(menu.colors_menu().items.map(func(o): return o.clean), ["Background color", "Text color", "Bar color", "Cover area", "Row stripes"], "color group")
	assert_eq(menu.cover_menu().items.map(func(o): return o.clean), ["Cover size", "Cover style", "Cover position", "Cover border", "System art"], "cover group")
	for moved in ["Text size", "Font", "Background color", "Cover size", "System art"]:
		assert_false(moved in top, moved + " not repeated at the top")
	var text = menu.visual_menu().items[0]
	text.trigger(Actions.CONFIRM)
	assert_eq(panel.pushed.back().call().title, "Text", "Text opens its submenu")

func test_extra_small_text():
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[0], "Extra small", "smallest option")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES[SettingsMenu.text_size_index(0.7, 1.1)], "Extra small", "much smaller is Extra small")
	assert_eq(SettingsMenu.TEXT_SIZE_NAMES.size(), SettingsMenu.TEXT_SIZE_FACTORS.size(), "a factor per name")

func test_font_names():
	assert_eq(SettingsMenu.font_name("res://launcher_configs/COMMON/fonts/Grandstander/Grandstander.ttf"), "Grandstander", "folder name shown")
	assert_eq(SettingsMenu.font_name(null), "Default", "no font set")

func test_visual_settings_show_words_not_numbers():
	var labels = _visual_labels()
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
	var restore = _visual_items().filter(func(o): return o.clean == "Restore defaults")
	assert_eq(restore.size(), 1, "restore item present")
	restore[0].trigger(Actions.CONFIRM)
	assert_eq(panel.pushed.size(), 1, "confirmation pushed")
	var confirm = panel.pushed[0].call()
	assert_eq(confirm.items.map(func(o): return o.clean), ["Restore", "Cancel"], "yes/cancel")
	confirm.items[1].trigger(Actions.CONFIRM)
	assert_eq(panel.backs, 1, "cancel goes back")

func test_color_picker_lives_in_panel():
	var color = _visual_items().filter(func(o): return o.clean == "Background color")[0]
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
	var comfortaa = SettingsMenu.font_credit_lines("Comfortaa")
	assert_eq(comfortaa[0], "Copyright 2011 The Comfortaa Project Authors, with Reserved Font Name \"Comfortaa\".", "text after the link kept")
	assert_eq(comfortaa[1], "https://github.com/alexeiva/comfortaa", "link pulled out mid-line")

func test_font_picker_lives_in_panel():
	var font = _visual_items().filter(func(o): return _text(o).begins_with("Font: "))[0]
	font.trigger(Actions.CONFIRM)
	assert_eq(panel.opened_screens, [], "no separate screen")
	var families = panel.pushed[0].call()
	var names = families.items.map(func(o): return o.clean.trim_prefix("• "))
	assert_true("Rubik" in names and "Grandstander" in names, "families listed")
	assert_true(families.items.all(func(o): return o.has_meta("font")), "each family drawn in its own font")
	assert_true("Caveat" in names and "AtkinsonHyperlegible" in names, "added families listed")
	assert_true(names.all(func(f): return ResourceLoader.exists(SettingsMenu.font_path(f))), "one file per family")
	assert_true(names.all(func(f): return FileAccess.file_exists(SettingsMenu.FONT_DIR + "/" + f + "/OFL.txt")), "each family has its license")
	var saved_font = Settings._data.get(Settings.CFG_FONT)
	var saved_global = Global.font
	var grandstander = families.items.filter(func(o): return o.clean.trim_prefix("• ") == "Grandstander")[0]
	grandstander.trigger(Actions.CONFIRM)
	var chosen = Settings._data.get(Settings.CFG_FONT)
	if saved_font == null:
		Settings._data.erase(Settings.CFG_FONT)
	else:
		Settings._data[Settings.CFG_FONT] = saved_font
	Global.font = saved_global
	Global.refresh_fonts()
	assert_eq(chosen, SettingsMenu.font_path("Grandstander"), "picking a family applies it")
	assert_eq(panel.pushed.size(), 1, "no weight submenu")

func test_font_menu_marks_current_font():
	var saved_font = Settings._data.get(Settings.CFG_FONT)
	Settings._data.erase(Settings.CFG_FONT)
	var fonts = menu.font_menu()
	var labels = fonts.items.map(func(o): return o.clean)
	if saved_font != null:
		Settings._data[Settings.CFG_FONT] = saved_font
	assert_true("• Rubik" in labels, "default font marked")
	assert_eq(labels[fonts.selection], "• Rubik", "opens on the current font")

func test_power_options_on_portmaster_only():
	var saved = OS.get_environment("PLAIN_LAUNCHER_PLATFORM")
	OS.set_environment("PLAIN_LAUNCHER_PLATFORM", "portmaster")
	var portmaster = _labels(menu.main_menu)
	OS.set_environment("PLAIN_LAUNCHER_PLATFORM", saved)
	assert_eq(portmaster.slice(-3), ["Reboot device", "Shut down device", "Quit"], "power options just above Quit")
	assert_false("Reboot device" in _labels(menu.main_menu), "not offered elsewhere")
	var reboot = func(): return menu.main_menu().items.filter(func(o): return o.clean == "Quit")
	assert_eq(reboot.call().size(), 1, "Quit still there")

func test_power_commands():
	var dir = OS.get_user_data_dir().path_join("fake_power")
	DirAccess.make_dir_recursive_absolute(dir + DevicePower.MUOS_HALT.get_base_dir())
	FileAccess.open(dir + DevicePower.MUOS_HALT, FileAccess.WRITE).close()
	DevicePower.root = dir
	var muos = DevicePower.command("reboot")
	DevicePower.root = dir.path_join("nothing")
	var other = DevicePower.command("poweroff")
	DevicePower.root = ""
	OS.execute("rm", ["-rf", dir])
	assert_eq(muos, [dir + DevicePower.MUOS_HALT, "reboot"], "muOS shuts down its own way")
	assert_eq(other, ["systemctl", "poweroff"] if Launcher.on_path("systemctl") else ["poweroff"], "systemd or plain poweroff elsewhere")
	DevicePower.root = dir
	var muos_script = DevicePower.script("reboot", "/tmp/power log.txt")
	DevicePower.root = ""
	assert_true(muos_script.contains(" || 'reboot'"), "plain reboot if muOS halt fails")
	assert_true(muos_script.ends_with(">>'/tmp/power log.txt' 2>&1"), "output kept in a log")
	var saved_esudo = OS.get_environment("PLAIN_LAUNCHER_ESUDO")
	OS.set_environment("PLAIN_LAUNCHER_ESUDO", "sudo")
	var elevated = DevicePower.command("reboot")
	var elevated_script = DevicePower.script("reboot", "/tmp/p.log")
	OS.set_environment("PLAIN_LAUNCHER_ESUDO", saved_esudo)
	assert_eq(elevated[0], "sudo", "ArkOS-style ports run it through sudo")
	assert_true(elevated_script.contains("|| 'sudo' 'reboot'"), "fallback too")
	assert_eq(DevicePower.command("reboot")[0] != "sudo", true, "no sudo when PortMaster doesn't need it")

func test_launch_on_boot_only_explains():
	var row = menu.launch_on_boot_row()
	assert_true(row.handles(Actions.CONFIRM), "A shows how to set it up")
	assert_false(row.handles(Actions.DIRECTION), "left/right does nothing")
	assert_false(row.handles(Actions.START), "nothing to reset")
	assert_eq(row.get_meta("value"), "Off", "off when the system isn't set to boot it")

func test_checkboxes_ignore_left_and_right():
	var checkboxes = 0
	var choices = 0
	for builder in [menu.visual_menu, menu.text_menu, menu.colors_menu, menu.cover_menu, menu.general_menu, menu.controls_menu, menu.audio_menu, menu.launchers_menu]:
		for o in builder.call().items:
			if o.get_meta("checked", null) is bool:
				checkboxes += 1
				assert_false(o.handles(Actions.DIRECTION), o.clean + " only changes with A")
			elif o.has_meta("value") and o.handles(Actions.DIRECTION):
				choices += 1
	assert_true(checkboxes > 3 and choices > 3, "both kinds of rows checked")

func test_left_cover_space_kept_for_games_without_art():
	assert_true(Global.art_enabled_for("game_browser", Settings.COVER_SIZES[2], false), "game lists keep the cover's space")
	assert_false(Global.art_enabled_for("game_browser", Vector2.ZERO, false), "cover size Off frees it")
	assert_false(Global.art_enabled_for("system_browser", Settings.COVER_SIZES[2], false), "systems without system art use full width")
	assert_true(Global.art_enabled_for("system_browser", Settings.COVER_SIZES[2], true), "systems with system art keep it")

func test_cover_area_column():
	assert_true("Cover area: Off" in _visual_labels(), "off by default")
	assert_true(Settings.CFG_COVER_AREA_COLOR in Settings.VISUAL_KEYS, "reset with visual settings")
	assert_eq(Global.cover_area_span(1000.0, 20.0, 400.0, 30.0, false, false), Vector2(565.0, 1000.0), "right cover: from just before its box to the edge")
	assert_eq(Global.cover_area_span(1000.0, 20.0, 400.0, 30.0, true, false), Vector2(0.0, 435.0), "left cover: from the edge to where the list starts")
	assert_eq(Global.cover_area_span(1000.0, 20.0, 100.0, 30.0, false, true), Vector2(860.0, 1000.0), "inline: the cover column, same margin on both sides")
	assert_eq(Global.cover_area_span(1000.0, 20.0, 100.0, 30.0, true, true), Vector2(0.0, 140.0), "inline on the left too")
	var span = Global.cover_area_span(1000.0, 20.0, 400.0, 30.0, false, false)
	assert_eq((span.x + span.y) / 2.0, 782.5, "the cover sits in the middle of its area")
	assert_eq(Global.right_cover_anchor_x(1000.0, 20.0, 200.0), 0.88, "small covers sit against the right margin")
	assert_eq(Global.right_cover_anchor_x(1000.0, 20.0, 400.0), 0.78, "medium too")

func test_neighbors_stay_without_main_art():
	assert_true(Global.keeps_empty_slot("stacked", Settings.COVER_SIZES[2], false, true), "stacked keeps neighbors around an empty slot")
	assert_true(Global.keeps_empty_slot("wheel", Settings.COVER_SIZES[2], false, true), "so does the wheel")
	assert_false(Global.keeps_empty_slot("single", Settings.COVER_SIZES[2], false, true), "single cover just hides")
	assert_false(Global.keeps_empty_slot("wheel", Vector2.ZERO, false, true), "cover size Off hides")
	assert_false(Global.keeps_empty_slot("wheel", Settings.COVER_SIZES[2], false, false), "systems without system art hide")
	assert_false(Global.keeps_empty_slot("wheel", Settings.COVER_SIZES[2], true, true), "options panel cover hides")

func test_text_stops_at_the_cover_area():
	var saved = [Settings._data.get(Settings.CFG_COVER_AREA_COLOR), Settings._data.get(Settings.CFG_COVER_SIDE), Settings._data.get(Settings.CFG_VISUAL_COVER_SIZE), Settings._data.get(Settings.CFG_COVER_STYLE)]
	Settings._data[Settings.CFG_VISUAL_COVER_SIZE] = Settings.COVER_SIZES[2]
	Settings._data[Settings.CFG_COVER_STYLE] = "single"
	Settings._data[Settings.CFG_COVER_SIDE] = "right"
	Settings._data.erase(Settings.CFG_COVER_AREA_COLOR)
	var without = Global.text_to_cover()
	Settings._data[Settings.CFG_COVER_AREA_COLOR] = Color.NAVY_BLUE
	var with_area = Global.text_to_cover()
	Settings._data[Settings.CFG_COVER_SIDE] = "left"
	var left = Global.text_to_cover()
	for pair in [[Settings.CFG_COVER_AREA_COLOR, saved[0]], [Settings.CFG_COVER_SIDE, saved[1]], [Settings.CFG_VISUAL_COVER_SIZE, saved[2]], [Settings.CFG_COVER_STYLE, saved[3]]]:
		if pair[1] == null:
			Settings._data.erase(pair[0])
		else:
			Settings._data[pair[0]] = pair[1]
	assert_false(without, "full width without a cover area color")
	assert_true(with_area, "text stops at the cover area")
	assert_false(left, "left covers already trim the text")
	assert_eq(Global.cover_text_limit(1000.0, 0.75, 0.4, 30.0), 520.0, "text stops a gap before the cover's box")

func test_credits_ask_for_support():
	var items = menu.credits_menu().items
	var labels = items.map(func(o): return o.clean)
	assert_eq(labels.slice(0, 5), SettingsMenu.SUPPORT_LINES, "support lines first, each on its own row")
	assert_true(items[1].handles(Actions.CONFIRM) and items[4].handles(Actions.CONFIRM), "Ko-fi and Steam rows open links")
	assert_false(items[0].handles(Actions.CONFIRM), "text rows don't")
	assert_true("Development" in labels and "Fonts" in labels, "other credits still there")

func test_main_menu_sections():
	assert_eq(_labels(menu.main_menu), ["General", "Visuals", "Audio", "Controls", "Collections", "Scraper", "Launchers", "Credits", "Quit"], "main menu")
	for builder in [menu.main_menu, menu.visual_menu, menu.colors_menu, menu.general_menu]:
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
	var labels = _visual_labels()
	for i in range(keys.size()):
		if before[i] != null:
			Settings._data[keys[i]] = before[i]
	assert_true("Cover size: Medium" in labels, "default cover size is Medium")
	assert_true("Title alignment: Left" in labels, "default alignment is Left")

func test_values_and_checkboxes_are_separate_from_labels():
	var items = _visual_items()
	var size = items.filter(func(o): return o.clean == "Text size")[0]
	assert_true(size.has_meta("value"), "text size shows a value")
	var prompts = items.filter(func(o): return o.clean == "Button prompts")[0]
	assert_true(prompts.get_meta("checked") is bool, "booleans are checkboxes")
	assert_false(items.any(func(o): return ": " in o.clean), "no label: value text")

func test_options_labels():
	assert_eq(OptionsMenu.setting_name("EMULATOR", false), "Emulator", "game emulator")
	assert_eq(OptionsMenu.setting_name("EMULATOR", true), "Default emulator", "system emulator")
	assert_eq(OptionsMenu.emulator_groups(["mgba", "drastic", "retroarch", "melonds"], ["retroarch", "mgba"]), [["mgba", "retroarch"], ["drastic", "melonds"]], "this system's launchers first, the rest after")
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
	assert_true("Cover position: Right" in _visual_labels(), "right by default")
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
	var cover = _visual_items().filter(func(o): return o.clean == "Cover size")[0]
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
	assert_true("Bar color: Off" in _visual_labels(), "row shows Off")
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
	var skip = ["Restore defaults", "Text", "Color", "Cover Art", "Set confirm button"]
	for builder in [menu.visual_menu, menu.text_menu, menu.colors_menu, menu.cover_menu, menu.controls_menu]:
		for o in builder.call().items:
			if o.clean in skip:
				continue
			assert_true(o.handles(Actions.START), o.clean + " has a default")

func test_restore_defaults_reloads_font():
	var saved_font = Settings._data.get(Settings.CFG_FONT)
	var saved_global = Global.font
	Settings._data[Settings.CFG_FONT] = SettingsMenu.font_path("Grandstander")
	Global.font = load(Settings._data[Settings.CFG_FONT])
	var restore = _visual_items().filter(func(o): return o.clean == "Restore defaults")[0]
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

func test_row_stripes_option():
	assert_true(_visual_labels().has("Row stripes: Off"), "stripes off by default")
	assert_true(Settings.CFG_ROW_STRIPES in Settings.VISUAL_KEYS, "stripes reset with visual settings")
	var stripes = load("res://scenes/row_stripes.gd")
	assert_eq([0, 1, 2, 3].map(func(r): return stripes.striped(r, 3)), [false, true, false, false], "every other row, only where there are items")
	assert_eq(stripes.stripe_rect(100.0, 40.0, 0.0, 800.0), Rect2(0.0, 80.0, 800.0, 40.0), "stripe centered on the text")
	assert_eq(stripes.left_edge(330.0, 20.0, 30.0, false), 335.0, "left cover: stripes start halfway between the cover (ends at 320) and the text (starts at 350)")
	assert_eq(stripes.left_edge(0.0, 20.0, 30.0, false), 0.0, "right cover: full width")
	assert_eq(stripes.left_edge(330.0, 20.0, 30.0, true), 0.0, "inline: full width behind the art")

func test_nearby_covers_option():
	assert_true(_visual_labels().has("Cover style: Single"), "single cover by default")
	assert_eq(Global.nearby_offset(600.0, 300.0, 20.0), 470.0, "small cover sits just past the main one")

func test_nearby_covers_stop_at_the_bars():
	assert_eq(Global.nearby_crop(100.0, 200.0, 60.0, 1000.0), Vector2(60.0, 0.0), "top trimmed at the title bar")
	assert_eq(Global.nearby_crop(980.0, 200.0, 60.0, 1000.0), Vector2(0.0, 80.0), "bottom trimmed at the prompt bar")
	assert_eq(Global.nearby_crop(500.0, 200.0, 60.0, 1000.0), Vector2.ZERO, "fully visible untouched")

func test_retired_font_weights_fall_back():
	var base = "res://launcher_configs/COMMON/fonts/Rubik/Rubik"
	for weight in ["Regular", "ExtraBold", "Light", "Medium", "Bold"]:
		assert_eq(Settings.supported_font(base + "-" + weight + ".ttf"), base + ".ttf", weight + " becomes the family font")
	assert_eq(Settings.supported_font(base + ".ttf"), base + ".ttf", "current path stays")
	assert_eq(Settings.supported_font("res://launcher_configs/COMMON/fonts/Gone/Gone-Medium.ttf"), null, "missing family uses the default")
	assert_eq(Settings.supported_font(null), null, "no font stays unset")

func test_launcher_program_is_checked():
	assert_eq(SettingsMenu.program_status({"command": ["bash", "{game}"]}), "Found", "program on PATH")
	assert_eq(SettingsMenu.program_status({"command": ["/no/such/emulator", "{game}"]}), "Not found", "typo or missing install")

func test_browsed_program_replaces_only_the_program():
	assert_eq(SettingsMenu.with_program(["myemu", "-f", "{game}"], "C:\\Emulators\\My Emu\\emu.exe"), ["C:/Emulators/My Emu/emu.exe", "-f", "{game}"], "arguments kept, slashes evened out")
	assert_eq(SettingsMenu.with_program([], "/opt/emu/emu"), ["/opt/emu/emu", "{game}"], "empty command gets the game")

func test_command_splits_and_joins_with_quotes():
	var args = ["retroarch", "-L", "/cores/mgba_libretro.so", "/ROMS/Game Boy/Link's.gb", ""]
	var line = SettingsMenu.join_command(args)
	assert_eq(SettingsMenu.split_command(line), args, "round trip keeps spaces, quotes and empty args")
	assert_eq(SettingsMenu.split_command("retroarch -L 'my core.so' {game}"), ["retroarch", "-L", "my core.so", "{game}"], "single quotes group")
	assert_eq(SettingsMenu.split_command("  a   b "), ["a", "b"], "extra spaces ignored")

func test_keyboard_types_shifts_and_deletes():
	var keyboard = TextKeyboard.new()
	var q = TextKeyboard.key_in_row(keyboard.keys, 1, 0)
	keyboard.press(q)
	keyboard.press(TextKeyboard.key_in_row(keyboard.keys, 4, 0))
	keyboard.press(TextKeyboard.key_in_row(keyboard.keys, 1, 0))
	keyboard.press(TextKeyboard.key_in_row(keyboard.keys, 4, 4))
	assert_eq(keyboard.text, "qQ ", "lower, shifted, then space")
	keyboard.backspace()
	assert_eq(keyboard.text, "qQ", "backspace removes one")
	assert_true(keyboard.press(TextKeyboard.key_in_row(keyboard.keys, 4, 11)), "done key finishes")
	keyboard.free()

func test_keyboard_moves_between_rows_by_column():
	var keyboard = TextKeyboard.new()
	keyboard.pick(TextKeyboard.key_in_row(keyboard.keys, 3, 6))
	keyboard.move(0, 1)
	assert_eq(keyboard.keys[keyboard.index].type, "space", "down from the middle lands on space")
	keyboard.move(0, 1)
	assert_eq(keyboard.keys[keyboard.index].row, 0, "down wraps to the top row")
	keyboard.move(-1, 0)
	keyboard.move(1, 0)
	assert_eq(keyboard.keys[keyboard.index].char, "7", "left then right comes back")
	keyboard.free()

func test_long_text_wraps_by_word_and_splits_long_paths():
	assert_eq(SlidePanel.wrap_text("retroarch -f -L core.so game.gba", 12), ["retroarch -f", "-L core.so", "game.gba"], "wraps on spaces")
	assert_eq(SlidePanel.wrap_text("abcdefghij", 4), ["abcd", "efgh", "ij"], "long words split")
	assert_eq(SlidePanel.wrap_text("", 10), [], "empty text has no lines")

func test_scraper_reads_gzipped_and_plain_replies():
	var Scraper = preload("res://scenes/art_scraper.gd")
	var json = "{\"response\": {\"jeu\": {\"nom\": \"Metal Slug\"}}}"
	var gzipped = json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	assert_eq(gzipped[0], 0x1f, "test data is gzip")
	assert_eq(Scraper.response_text(gzipped), json, "gzip reply unpacked")
	assert_eq(Scraper.response_text(json.to_utf8_buffer()), json, "plain reply untouched")

func test_physical_typing_fills_the_keyboard():
	var keyboard = TextKeyboard.new()
	var key = func(code: Key, unicode: int = 0) -> InputEventKey:
		var event = InputEventKey.new()
		event.keycode = code
		event.unicode = unicode
		event.pressed = true
		return event
	keyboard.type_key(key.call(KEY_R, 114))
	keyboard.type_key(key.call(KEY_A, 65))
	keyboard.type_key(key.call(KEY_SPACE, 32))
	keyboard.type_key(key.call(KEY_SLASH, 47))
	assert_eq(keyboard.text, "rA /", "printable keys type")
	keyboard.type_key(key.call(KEY_BACKSPACE))
	assert_eq(keyboard.text, "rA ", "backspace deletes")
	assert_eq(keyboard.type_key(key.call(KEY_ENTER)), "done", "enter finishes")
	assert_eq(keyboard.type_key(key.call(KEY_ESCAPE)), "cancel", "escape cancels")
	keyboard.free()

func test_keyboard_prompts_show_key_names():
	assert_eq(PromptBar.glyph_for("confirm", true, true), "key:space", "space confirms even when the pad is swapped")
	assert_eq(PromptBar.glyph_for("back", false, true), "key:backspace", "backspace goes back")
	assert_eq(PromptBar.glyph_for("options", false, true), "key:tab", "tab opens options")
	assert_eq(PromptBar.glyph_for("start", false, true), "key:Esc", "escape opens settings")
	assert_eq(PromptBar.glyph_for("confirm", false), "A", "controller glyphs unchanged")

func test_text_scale_follows_the_window():
	assert_true(absf(Settings.window_scaler(Vector2i(1280, 800)) - 800 / 960.0) < 0.001, "Steam Deck sized by its height")
	assert_true(absf(Settings.window_scaler(Vector2i(800, 1280)) - 800 / 960.0) < 0.001, "portrait uses the short side")
	assert_eq(Settings.window_scaler(Vector2i(7680, 4320)), Settings.LAYOUT_SIZES[-1], "huge windows capped")
	assert_true(Settings.window_scaler(Vector2i(1920, 1080)) > Settings.window_scaler(Vector2i(1280, 720)), "bigger window, bigger text")

func test_scrape_requests_send_a_fingerprint_and_hide_logins():
	var Scraper = preload("res://scenes/art_scraper.gd")
	var path = ProjectSettings.globalize_path("user://fingerprint.gba")
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("rom")
	f.close()
	assert_eq(Scraper.rom_fingerprint(path), "&romtaille=3&md5=" + "rom".md5_text(), "size and md5 sent")
	assert_eq(Scraper.rom_fingerprint(""), "", "nothing for missing files")
	assert_eq(Scraper.masked_url("https://x/ss?ssid=me&sspassword=secret&systemeid=12"), "https://x/ss?ssid=***&sspassword=***&systemeid=12", "login hidden in logs")
	assert_eq(Settings.loggable({"SS_PASS": "secret", "SS_USER": "me"}).SS_PASS, "***", "password hidden in settings log")
	DirAccess.remove_absolute(path)

func test_launch_card_lines_and_cover_growth():
	assert_eq(Global.launch_lines("Metroid Fusion", "retroarch").map(func(l): return l[0]), ["Launching", "Metroid Fusion", "with launcher config", "retroarch"], "card text")
	assert_eq(Global.launch_cover_scale(200.0, 800.0), Global.LAUNCH_COVER_MAX_SCALE, "small covers grow to the cap")
	assert_true(absf(Global.launch_cover_scale(400.0, 800.0) - 1.1) < 0.001, "covers grow to just over half the height")
	assert_eq(Global.launch_cover_scale(700.0, 800.0), 1.0, "big covers never shrink")

func test_launch_view_parts_and_click():
	assert_eq(Global.launch_parts("cover_info", true), {"cover": true, "info": true}, "cover and info")
	assert_eq(Global.launch_parts("cover_info", false), {"cover": false, "info": true}, "no cover art, info only")
	assert_eq(Global.launch_parts("cover", true), {"cover": true, "info": false}, "cover only")
	assert_eq(Global.launch_parts("info", true), {"cover": false, "info": true}, "info only")
	assert_eq(Global.launch_parts("none", true), {"cover": false, "info": false}, "nothing")
	assert_eq(Global.sound_db(0, 100), -80.0, "master at zero is silent")
	assert_eq(Global.sound_db(100, 0), -80.0, "a sound at zero is silent")
	assert_true(Global.sound_db(100, 30) < Global.sound_db(100, 60), "louder setting is louder")
	assert_true(Global.sound_db(50, 60) < Global.sound_db(100, 60), "master scales every sound")
	assert_true(Settings.DEFAULT_SETTINGS[Settings.CFG_VOLUME_SCROLL] < Settings.DEFAULT_SETTINGS[Settings.CFG_VOLUME_SELECT], "scrolling starts quieter than selecting")
	assert_eq(SettingsMenu.stepped_volume(100, 1), 0, "A past full wraps to zero")
	assert_eq(SettingsMenu.stepped_volume(0, -1), 0, "left stops at zero")
	assert_eq(SettingsMenu.stepped_volume(30, 1), 40, "steps of ten")
	assert_true(Global.SOUNDS.values().all(func(path): return ResourceLoader.exists(path)), "click sounds bundled")
	assert_true(Global.SOUND_PITCH_VARIATION.move > Global.SOUND_PITCH_VARIATION.accept, "navigation click varies more")

func test_keyboard_cursor_edits_in_the_middle():
	var keyboard = TextKeyboard.new()
	keyboard.set_text("Advance Wars.gba")
	assert_eq(keyboard.cursor, 16, "cursor starts at the end")
	keyboard.move_cursor(-4)
	keyboard.type_text(" 2")
	assert_eq(keyboard.text, "Advance Wars 2.gba", "typed at the cursor")
	keyboard.backspace()
	keyboard.backspace()
	assert_eq(keyboard.text, "Advance Wars.gba", "backspace deletes before the cursor")
	keyboard.move_cursor(-100)
	keyboard.backspace()
	assert_eq(keyboard.text, "Advance Wars.gba", "nothing to delete at the start")
	assert_eq(keyboard.cursor, 0, "cursor stops at the start")
	keyboard.free()

func test_scraper_search_defaults_and_selectable_rows():
	var Scraper = preload("res://scenes/art_scraper.gd")
	var game = option.new_option("Advance Wars (USA).gba")
	game.clean = "Advance Wars"
	assert_eq(Scraper.default_search(game, "screenscraper"), "Advance Wars (USA).gba", "ScreenScraper searches the file name")
	assert_eq(Scraper.default_search(game, "steamgriddb"), "Advance Wars", "SteamGridDB searches the title")
	assert_eq(SlidePanel.next_selectable([5, 6], 6, -1), 5, "up from Done reaches Edit Search")
	assert_eq(SlidePanel.next_selectable([5, 6], 5, -1), 6, "wraps between the two")
	assert_eq(SlidePanel.next_selectable([6], 6, 1), 6, "a single action stays put")

func test_steamgriddb_picks_the_matching_sequel():
	var Scraper = preload("res://scenes/art_scraper.gd")
	var results = [{"id": 2, "name": "Boktai 2: Solar Boy Django"}, {"id": 1, "name": "Boktai: The Sun Is in Your Hand"}, {"id": 3, "name": "Boktai 3: Sabata's Counterattack"}]
	assert_eq(Scraper.ranked_matches(results, "boktai 3")[0].id, 3, "the number decides")
	assert_eq(Scraper.ranked_matches(results, "Boktai")[0].id, 1, "no number prefers the original")
	var finals = [{"id": 1, "name": "Final Fantasy II"}, {"id": 2, "name": "Final Fantasy III"}]
	assert_eq(Scraper.ranked_matches(finals, "final fantasy 3")[0].id, 2, "roman numerals count")
	var exact = [{"id": 1, "name": "Metroid Fusion Collection"}, {"id": 2, "name": "Metroid Fusion"}]
	assert_eq(Scraper.ranked_matches(exact, "Metroid Fusion")[0].id, 2, "exact name wins")
	assert_eq(Scraper.ranked_matches([{"id": 7, "name": "Anything"}], "zzz")[0].id, 7, "a lone result is still used")

func test_screenscraper_result_must_have_the_searched_number():
	var Scraper = preload("res://scenes/art_scraper.gd")
	assert_false(Scraper.names_agree(["Boktai 2 - Solar Boy Django", "Bokura no Taiyou 2"], "boktai 3"), "a 2 is not a 3")
	assert_true(Scraper.names_agree(["Boktai 3 - Sabata's Counterattack", "Shin Bokura no Taiyou"], "boktai 3"), "any regional name can match")
	assert_true(Scraper.names_agree(["Final Fantasy III"], "final fantasy 3"), "roman numerals count")
	assert_true(Scraper.names_agree(["Shin Bokura no Taiyou"], "bokura no taiyou"), "no number in the search, nothing to check")

func test_xbox_pads_show_xbox_letters():
	assert_eq(PromptBar.glyph_for("confirm", true, false, true), "A", "Deck confirm is the bottom A button")
	assert_eq(PromptBar.glyph_for("back", true, false, true), "B", "Deck back is B")
	assert_eq(PromptBar.glyph_for("favorite", true, false, true), "Y", "top button is Y on Xbox pads")
	assert_eq(PromptBar.glyph_for("confirm", false, false, false), "A", "Nintendo-style confirm stays A")
	assert_eq(PromptBar.glyph_for("favorite", false, false, false), "X", "Nintendo-style top button stays X")

func test_controls_can_set_the_confirm_button():
	var row = menu.controls_menu().items.filter(func(o): return o.clean == "Set confirm button")
	assert_eq(row.size(), 1, "Controls offers to set the confirm button")

func test_confirm_button_asked_only_with_a_controller():
	assert_true(Global.needs_confirm_button(false, 1), "first controller asks which button is A")
	assert_false(Global.needs_confirm_button(true, 1), "asked once")
	assert_false(Global.needs_confirm_button(false, 0), "keyboard and touch skip it")

func test_panel_title_stops_before_corner_text():
	assert_eq(SlidePanel.title_width(300.0, 0.0, 10.0), 300.0, "full width with no corner text")
	assert_eq(SlidePanel.title_width(300.0, 40.0, 10.0), 250.0, "leaves room for the corner text")

func test_confirm_swap_also_swaps_x_and_y():
	assert_eq(Global.face_buttons(false), {"favorite": JOY_BUTTON_Y, "special": JOY_BUTTON_X}, "positional pads keep X on top")
	assert_eq(Global.face_buttons(true), {"favorite": JOY_BUTTON_X, "special": JOY_BUTTON_Y}, "label-based pads swap X and Y with A and B")
	Global.apply_face_swap(true)
	var pads = InputMap.action_get_events("favorite").filter(func(e): return e is InputEventJoypadButton)
	assert_eq(pads.size(), 1, "one pad button for favorite")
	assert_eq(pads[0].button_index, JOY_BUTTON_X, "favorite moved")
	assert_true(InputMap.action_get_events("favorite").any(func(e): return e is InputEventKey), "keyboard key kept")
	Global.apply_face_swap(false)
	assert_eq(InputMap.action_get_events("favorite").filter(func(e): return e is InputEventJoypadButton)[0].button_index, JOY_BUTTON_Y, "and back")

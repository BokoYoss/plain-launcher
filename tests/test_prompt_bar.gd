extends "res://tests/test_case.gd"

const PromptBar = preload("res://scenes/prompt_bar.gd")

var saved_setting

func before_each():
	saved_setting = Settings.get_setting(Settings.CFG_VISUAL_PROMPT_BAR)

func after_each():
	Settings.store(Settings.CFG_VISUAL_PROMPT_BAR, saved_setting)
	Global.set_prompts(Global.DEFAULT_PROMPTS)

func test_glyphs_follow_confirm_layout():
	assert_eq([PromptBar.glyph_for("confirm", false), PromptBar.glyph_for("back", false)], ["A", "B"], "default: A confirms")
	assert_eq([PromptBar.glyph_for("confirm", true), PromptBar.glyph_for("back", true)], ["B", "A"], "swapped confirm")
	assert_eq([PromptBar.glyph_for("options", false), PromptBar.glyph_for("start", false), PromptBar.glyph_for("select", false), PromptBar.glyph_for("shoulders", false)], ["Y", "START", "SELECT", "LR"], "other glyphs")

func test_bar_enabled_by_default():
	assert_true(Settings.DEFAULT_SETTINGS[Settings.CFG_VISUAL_PROMPT_BAR], "on by default")
	assert_true(Settings.CFG_VISUAL_PROMPT_BAR in Settings.VISUAL_KEYS, "reset with visual settings")

func test_bar_reserves_a_row_only_when_enabled():
	Settings.store(Settings.CFG_VISUAL_PROMPT_BAR, true)
	assert_eq(Global.prompt_bar_height(), Global.prompt_text_size() * 2.0, "row twice the prompt text")
	Settings.store(Settings.CFG_VISUAL_PROMPT_BAR, false)
	assert_eq(Global.prompt_bar_height(), 0.0, "no row when disabled")

func test_long_message_scroll_positions():
	assert_eq(Global.message_scroll_x(0.5, 200.0, 100.0, 1.0), 0.0, "holds at start")
	assert_eq(Global.message_scroll_x(2.0, 200.0, 100.0, 1.0), -100.0, "scrolls left")
	assert_eq(Global.message_scroll_x(10.0, 200.0, 100.0, 1.0), -200.0, "stops with the end visible")

func test_glyph_widths_match_drawing():
	assert_eq(PromptBar.glyph_width("A", 20), 24.8, "face button")
	assert_eq(PromptBar.glyph_width("START", 20), 41.0, "start pills")
	assert_eq(PromptBar.glyph_width("LR", 20), 56.0, "shoulders")

func test_favorites_list_offers_unfavorite():
	var browser = load("res://scenes/subscreens/game_browser.gd")
	assert_eq(browser.prompts_for("FAVORITES")[1], ["favorite", "Unfavorite"], "favorites list")
	assert_eq(browser.prompts_for("GBA")[1], ["favorite", "Favorite"], "regular list")

func test_jump_prompt_uses_right_trigger():
	assert_eq(PromptBar.glyph_for("trigger", false), "RT", "single RT glyph")
	var browser = load("res://scenes/subscreens/game_browser.gd")
	assert_true(browser.prompts_for("GBA").any(func(p): return p == ["trigger", "Jump"]), "jump prompt shows RT")

func test_face_and_menu_buttons_buzz():
	var start = InputEventKey.new()
	start.physical_keycode = KEY_SHIFT
	start.pressed = true
	assert_true(Global.is_button_press(start), "start buzzes")
	var held = start.duplicate()
	held.echo = true
	assert_false(Global.is_button_press(held), "held repeat does not")
	var up = InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	assert_false(Global.is_button_press(up), "d-pad does not")

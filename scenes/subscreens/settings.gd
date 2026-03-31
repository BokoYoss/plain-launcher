extends Screen

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")
var launcher
var _return_subscreen: String = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.fade.modulate.a = 1.0
	_show_settings_main()

	Global.post_scroll_callback = Callable(self, "on_scroll")

	if OS.get_name() == "Android":
		AndroidInterface.connect("configured_storage", get_storage_selection)
		AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)

	if Global.setting_subscreen == "visuals":
		show_visual_settings()
		Global.setting_subscreen = null
	if Global.setting_subscreen == "controls":
		show_control_settings()
		Global.setting_subscreen = null
	if Global.setting_subscreen == "system":
		show_system_settings()
		Global.setting_subscreen = null
	Global.show_message("v" + Global.VERSION)
	Global.refresh_art()

func _show_settings_main():
	Global.clear_visible("SETTINGS", ["General", "Visuals", "Controls", "Collections", "Scraper", "Launchers", "Credits", "Quit"])
	Global.post_scroll_callback = Callable(self, "on_scroll")

const VISUAL_SUBSCREENS = ["visual settings", "cover art", "text", "colors", "layout"]

static func _toggle(value: bool) -> String:
	return "Enabled" if value else "Disabled"

func _on_resume():
	var title = _return_subscreen if _return_subscreen != "" else Global.title.text.to_lower()
	_return_subscreen = ""
	if title == "visual settings":
		show_visual_settings()
	elif title == "cover art":
		show_cover_settings()
	elif title == "text":
		show_text_settings()
	elif title == "colors":
		show_color_settings()
	elif title == "layout":
		show_layout_settings()
	elif title == "collections":
		show_collections_settings()
	elif "control" in title:
		show_control_settings()
	elif "general" in title:
		show_system_settings()
	else:
		_show_settings_main()
	if title not in VISUAL_SUBSCREENS:
		Global.img_texture_override = null
	Global.refresh_art()

func get_storage_selection(path):
	pass

func on_storage_config_failure(msg):
	pass

# ── Visual settings ──────────────────────────────────────────────────────────

func show_visual_settings():
	Global.clear_visible("Visual Settings", [
		"Cover art",
		"Text",
		"Colors",
		"Layout",
		"Restore all visual settings",
	])
	show_example_art()

func show_cover_settings():
	Global.clear_visible("Cover art", [
		"Cover size",
		"Cover position",
		"Cover border",
		"Cover opacity",
		"Drop shadow",
		"System art: " + _toggle(Settings.get_setting(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART)),
		"System borders: " + _toggle(Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER)),
	])
	show_example_art()

const LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum"

func show_text_settings():
	var caps_toggle = "Caps Lock: " + _toggle(Settings.get_setting(Settings.CFG_CAPS_LOCK))
	Global.clear_visible("Text", [
		"Change font",
		"Title orientation",
		"Title size",
		"Main title: " + str(Settings.get_setting(Settings.CFG_SYSTEM_TITLE)),
		"Text cutoff: " + LOREM,
		"Letter outlines",
		caps_toggle,
	])
	show_example_art()

func show_color_settings():
	Global.clear_visible("Colors", [
		"Background color",
		"Text color",
	])
	show_example_art()

func show_layout_settings():
	Global.clear_visible("Layout", [
		"Change size",
		"Left margin",
		"Top margin",
	])
	show_example_art()

func show_collections_settings():
	var hide_toggle = "Show hidden: " + _toggle(Global.show_hidden)
	var favs_first = "Favorites first: " + _toggle(Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST))
	Global.clear_visible("Collections", [hide_toggle, favs_first, "Clear favorites", "Clear history"])

func show_example_art():
	var new_rand_art = randi() % 12
	while (new_rand_art == $ExampleArt.frame):
		new_rand_art = randi() % 12
	Global.img_texture_override = $ExampleArt.get_sprite_frames().get_frame_texture("default", new_rand_art)
	Global.refresh_art()

func on_scroll():
	if Global.title.text.to_lower() in VISUAL_SUBSCREENS:
		show_example_art()
	else:
		Global.img_texture_override = null

# ── Control settings ─────────────────────────────────────────────────────────

func show_control_settings():
	var vibe_setting = "Vibration: " + _toggle(Settings.get_setting(Settings.CFG_VIBRATE))
	var invert_scroll = "Invert touch scroll: " + _toggle(Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL))
	Global.clear_visible("Control Settings", ["Swap confirm button", vibe_setting, invert_scroll])

# ── General settings ─────────────────────────────────────────────────────────

func populate_minui_paths():
	var external_path = AndroidInterface.get_external_storage_path()
	if external_path == null:
		Global.clear_visible("Unable to access external storage", ["OK"])
		return

func show_system_settings():
	Global.clear_visible("General Settings", ["Select storage", "Reimport all configs", "Restore all game settings", "Remove Plain Launcher directory"])

# ── Process ───────────────────────────────────────────────────────────────────

func _process(_delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean.to_lower()

		# Top-level
		if selected == "quit":
			get_tree().quit()
		elif selected == "general":
			show_system_settings()
			return
		elif selected == "visuals":
			show_visual_settings()
			return
		elif selected == "controls":
			show_control_settings()
			return
		elif selected == "collections":
			show_collections_settings()
			return

		# Visual sub-menus
		elif selected == "cover art":
			show_cover_settings()
			return
		elif selected == "text":
			show_text_settings()
			return
		elif selected == "colors":
			show_color_settings()
			return
		elif selected == "layout":
			show_layout_settings()
			return
		elif selected == "collections":
			show_collections_settings()
			return

		# Cover art settings
		elif selected == "cover size":
			Global.cycle_cover_sizes()
			show_cover_settings()
			return
		elif selected == "cover position":
			_return_subscreen = "cover art"
			Global.clear_visible("Set cover position.")
			Navigator.push("art_placer")
			return
		elif selected == "cover border":
			Global.cycle_border_thickness()
			show_cover_settings()
			return
		elif selected == "cover opacity":
			Global.cycle_art_opacity()
			show_cover_settings()
			Global.refresh_art()
			return
		elif selected == "drop shadow":
			Global.cycle_drop_shadow_locations()
			show_cover_settings()
			return
		elif "system art" in selected:
			Settings.store(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART, !Settings.get_setting(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART))
			show_cover_settings()
			return
		elif "system borders" in selected:
			Settings.store(Settings.CFG_VISUAL_SYSTEM_BORDER, !Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER))
			show_cover_settings()
			return

		# Text settings
		elif "font" in selected:
			Navigator.push("font_picker")
			return
		elif selected == "title orientation":
			Global.cycle_title_allignment()
			show_text_settings()
			return
		elif selected == "title size":
			Global.cycle_title_size()
			show_text_settings()
			return
		elif "main title" in selected:
			Global.cycle_system_title()
			show_text_settings()
			return
		elif "text cutoff" in selected:
			Global.cycle_line_length()
			show_text_settings()
			return
		elif selected == "letter outlines":
			Global.toggle_text_outline()
			show_text_settings()
			return
		elif "caps lock" in selected:
			Global.caps_lock()
			show_text_settings()
			return

		# Colors
		elif "background" in selected:
			_return_subscreen = "colors"
			Global.clear_visible("Select BACKGROUND color.", ["START: Default"])
			Global.color_picker = "background"
			Navigator.push("color_picker")
		elif "text color" in selected:
			_return_subscreen = "colors"
			Global.clear_visible("Select TEXT color.", ["START: Default"])
			Global.color_picker = "foreground"
			Navigator.push("color_picker")

		# Layout
		elif "change size" in selected:
			Global.cycle_sizes()
			return
		elif selected == "left margin":
			Global.cycle_left_margin()
			show_layout_settings()
			return
		elif selected == "top margin":
			Global.cycle_top_margin()
			show_layout_settings()
			return

		# Collections settings
		elif "hidden" in selected:
			Global.show_hidden = !Global.show_hidden
			show_collections_settings()
			return
		elif "favorites first" in selected:
			Settings.store(Settings.CFG_SHOW_FAVS_FIRST, !Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST))
			show_collections_settings()
			return
		elif selected == "clear favorites":
			Global.clear_all_favorites()
			show_collections_settings()
			return
		elif selected == "clear history":
			Global.clear_recent_history()
			show_collections_settings()
			return

		# Control settings
		elif "swap" in selected:
			Global.swap_confirm_key()
			Global.clear_visible("Swapped CONFIRM and BACK keys.", ["OK"])
		elif "vibration" in selected:
			Global.toggle_vibrate()
			show_control_settings()
			return
		elif "invert touch scroll" in selected:
			Settings.store(Settings.CFG_TOUCH_INVERT_SCROLL, !Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL))
			show_control_settings()
			return

		# General settings
		elif "storage" in selected:
			Navigator.push("file_browser")
		elif "reimport all configs" in selected:
			Global.clear_visible("Overwrite all configs with bundled defaults?", ["Overwrite", "Cancel"])
			return
		elif "overwrite" in selected:
			Global.reimport_all_configs()
			Global.clear_visible("Configs reimported.", ["OK"])
			return
		elif "restore all game settings" in selected:
			Global.clear_all_settings()
			Global.clear_visible("Restored settings to default.", ["OK"])
			return
		elif "restore all visual settings" in selected:
			Settings.reset()
			Settings.store(Settings.CFG_ROOT, Global.root_path)
			Global.set_up_slots()
			Global.show_options(Global.scroll_offset)
			Global.set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
			Global.highlight_selection(Global.option_selection)
			Global.refresh_art()
			Global.clear_visible("Restored visual settings", ["OK"])
			return
		elif "remove" in selected:
			Global.clear_visible("Delete everything in " + Global.root_path + "?", ["Delete it", "Nevermind"])
			return
		elif "delete it" in selected:
			var root = DirAccess.open(Global.root_path)
			if root:
				root.rename_absolute(Global.root_path, Global.root_path + "-" + str(Time.get_unix_time_from_system()))
				Navigator.push("file_browser")
				return

		# Other
		elif selected == "ok":
			Navigator.go_to_main()
			return
		elif "scraper" in selected:
			Navigator.push("scraper_credentials")
			return
		elif "launchers" in selected:
			Navigator.push("intent_browser")
			return
		elif "credits" in selected:
			Navigator.push("credits")
		return

	if Global.back_pressed():
		Global.img_texture_override = null
		var title = Global.title.text.to_lower()
		if title == "settings":
			Navigator.go_to_main()
			return
		if title == "visual settings":
			_show_settings_main()
			return
		if title in VISUAL_SUBSCREENS:
			show_visual_settings()
			return
		_show_settings_main()
		return

	if Input.is_action_just_pressed("exit"):
		Navigator.go_to_main()

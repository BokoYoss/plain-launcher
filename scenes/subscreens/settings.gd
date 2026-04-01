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
	Global.clear_visible("SETTINGS", [
		option.with_callback("General", show_system_settings),
		option.with_callback("Visuals", show_visual_settings),
		option.with_callback("Controls", show_control_settings),
		option.with_callback("Collections", show_collections_settings),
		option.with_callback("Scraper", func(): Navigator.push("scraper_credentials")),
		option.with_callback("Launchers", func(): Navigator.push("intent_browser")),
		option.with_callback("Credits", func(): Navigator.push("credits")),
		option.with_callback("Quit", func(): get_tree().quit()),
	])
	Global.post_scroll_callback = Callable(self, "on_scroll")

const VISUAL_SUBSCREENS = ["visual settings", "cover art", "text", "colors"]

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
		option.with_callback("Cover art", show_cover_settings),
		option.with_callback("Text", show_text_settings),
		option.with_callback("Colors", show_color_settings),
		option.with_callback("Restore all visual settings", _restore_all_visual_settings),
	])
	show_example_art()


func _resettable(label: String, cfg_key: String, confirm_cb: Callable, refresh_fn: Callable) -> option:
	var opt = option.with_callback(label, confirm_cb)
	opt.callbacks[Actions.START] = func():
		Settings.store(cfg_key, Settings.DEFAULT_SETTINGS.get(cfg_key))
		refresh_fn.call()
	return opt

func _keeping_cursor(fn: Callable):
	var saved_selection = Global.option_selection
	var saved_scroll = Global.scroll_offset
	fn.call()
	Global.option_selection = mini(saved_selection, Global.option_list.size() - 1)
	Global.scroll_offset = mini(saved_scroll, Global.option_selection)
	Global.show_options(Global.scroll_offset)
	Global.highlight_selection(Global.option_selection)

func _cycle_setting(label: String, cfg_key: String, cycle_fn: Callable, refresh_fn: Callable, reset_fn: Callable = Callable()) -> option:
	var opt = option.with_callback(label, func():
		_keeping_cursor(func(): cycle_fn.call(1); refresh_fn.call())
	)
	opt.callbacks[Actions.DIRECTION] = func(direction: int):
		_keeping_cursor(func(): cycle_fn.call(direction); refresh_fn.call())
	opt.callbacks[Actions.START] = func():
		_keeping_cursor(func():
			if reset_fn.is_valid():
				reset_fn.call()
			else:
				Settings.store(cfg_key, Settings.DEFAULT_SETTINGS.get(cfg_key))
				refresh_fn.call()
		)
	return opt

func show_cover_settings():
	Global.clear_visible("Cover art", [
		_cycle_setting("Cover size: " + str(Global.get_cycle_index(Settings.CFG_VISUAL_COVER_SIZE, Settings.COVER_SIZES)), Settings.CFG_VISUAL_COVER_SIZE, func(direction): Global.cycle_cover_sizes(direction), show_cover_settings),
		option.with_callback("Cover position", func():
			_return_subscreen = "cover art"
			Global.clear_visible("Set cover position.")
			Navigator.push("art_placer")
		),
		_cycle_setting("Cover border: " + str(Global.get_cycle_index(Settings.CFG_VISUAL_BORDER, Settings.BORDER_SIZES)), Settings.CFG_VISUAL_BORDER, func(direction): Global.cycle_border_thickness(direction), show_cover_settings),
		_cycle_setting("Cover opacity: " + str(Global.get_cycle_index(Settings.CFG_VISUAL_COVER_OPACITY, Settings.OPACITY_LEVELS)), Settings.CFG_VISUAL_COVER_OPACITY, func(direction): Global.cycle_art_opacity(direction), show_cover_settings),
		_cycle_setting("Drop shadow: " + str(Global.get_cycle_index(Settings.CFG_VISUAL_DROP_SHOW, Settings.SHADOW_LOCATIONS)), Settings.CFG_VISUAL_DROP_SHOW, func(direction): Global.cycle_drop_shadow_locations(direction), show_cover_settings),
		_resettable("System art: " + _toggle(Settings.get_setting(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART)), Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART, func():
			Settings.store(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART, !Settings.get_setting(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART))
			show_cover_settings()
		, show_cover_settings),
		_resettable("System borders: " + _toggle(Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER)), Settings.CFG_VISUAL_SYSTEM_BORDER, func():
			Settings.store(Settings.CFG_VISUAL_SYSTEM_BORDER, !Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER))
			show_cover_settings()
		, show_cover_settings),
	])
	show_example_art()

const LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum"

func show_text_settings():
	Global.clear_visible("Text", [
		_cycle_setting("Change size: " + str(Global.get_cycle_index(Settings.CFG_SCALER, Settings.LAYOUT_SIZES)), Settings.CFG_SCALER, func(direction): Global.cycle_sizes(direction), show_text_settings,
			func():
				Settings.store(Settings.CFG_SCALER, Settings._compute_default_scaler())
				Global.set_up_slots()
				show_text_settings()
		),
		_cycle_setting("Left margin: " + str(Global.get_cycle_index(Settings.CFG_LEFT_MARGIN, Settings.MARGINS)), Settings.CFG_LEFT_MARGIN, func(direction): Global.cycle_left_margin(direction), show_text_settings),
		_cycle_setting("Top margin: " + str(Global.get_cycle_index(Settings.CFG_TOP_MARGIN, Settings.MARGINS)), Settings.CFG_TOP_MARGIN, func(direction): Global.cycle_top_margin(direction), show_text_settings),
		option.with_callback("Change font", func(): Navigator.push("font_picker")),
		_cycle_setting("Title orientation: " + str(Global.get_cycle_index(Settings.CFG_VISUAL_TITLE_ORIENTATION, Settings.TITLE_ORIENTATIONS)), Settings.CFG_VISUAL_TITLE_ORIENTATION, func(direction): Global.cycle_title_allignment(direction), show_text_settings),
		_cycle_setting("Title size: " + str(Global.get_cycle_index(Settings.CFG_TITLE_SIZE, Settings.TITLE_SIZES)), Settings.CFG_TITLE_SIZE, func(direction): Global.cycle_title_size(direction), show_text_settings),
		_cycle_setting("Main title: " + str(Settings.get_setting(Settings.CFG_SYSTEM_TITLE)), Settings.CFG_SYSTEM_TITLE, func(direction): Global.cycle_system_title(direction), show_text_settings),
		_cycle_setting("Text cutoff: " + str(Global.get_cycle_index(Settings.CFG_TEXT_LENGTH, Settings.LINE_LENGTHS)), Settings.CFG_TEXT_LENGTH, func(direction): Global.cycle_line_length(direction), show_text_settings),
		option.with_callback("Letter outlines", func(): Global.toggle_text_outline(); show_text_settings()),
		_resettable("Caps Lock: " + _toggle(Settings.get_setting(Settings.CFG_CAPS_LOCK)), Settings.CFG_CAPS_LOCK, func(): Global.caps_lock(); show_text_settings(), show_text_settings),
	])
	show_example_art()

func show_color_settings():
	Global.clear_visible("Colors", [
		option.with_callback("Background color", func():
			_return_subscreen = "colors"
			Global.clear_visible("Select BACKGROUND color.", ["START: Default"])
			Global.color_picker = "background"
			Navigator.push("color_picker")
		),
		option.with_callback("Text color", func():
			_return_subscreen = "colors"
			Global.clear_visible("Select TEXT color.", ["START: Default"])
			Global.color_picker = "foreground"
			Navigator.push("color_picker")
		),
	])
	show_example_art()

func show_collections_settings():
	Global.clear_visible("Collections", [
		option.with_callback("Show hidden: " + _toggle(Global.show_hidden), func():
			Global.show_hidden = !Global.show_hidden
			show_collections_settings()
		),
		option.with_callback("Favorites first: " + _toggle(Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST)), func():
			Settings.store(Settings.CFG_SHOW_FAVS_FIRST, !Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST))
			show_collections_settings()
		),
		option.with_callback("Clear favorites", func(): Global.clear_all_favorites(); show_collections_settings()),
		option.with_callback("Clear history", func(): Global.clear_recent_history(); show_collections_settings()),
	])

func _restore_all_visual_settings():
	Settings.reset_visual()
	Global.set_up_slots()
	Global.show_options(Global.scroll_offset)
	Global.set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	Global.highlight_selection(Global.option_selection)
	Global.refresh_art()
	Global.clear_visible("Restored visual settings", [option.with_callback("OK", func(): Navigator.go_to_main())])

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
	var sel = Global.get_selected()
	if sel.handles(Actions.START):
		Global.show_message("START: Restore Default", true)
	else:
		Global.show_message("")

# ── Control settings ─────────────────────────────────────────────────────────

func show_control_settings():
	Global.clear_visible("Control Settings", [
		option.with_callback("Swap confirm button", func():
			Global.swap_confirm_key()
			Global.clear_visible("Swapped CONFIRM and BACK keys.", [option.with_callback("OK", func(): show_control_settings())])
		),
		_resettable("Vibration: " + _toggle(Settings.get_setting(Settings.CFG_VIBRATE)), Settings.CFG_VIBRATE, func(): Global.toggle_vibrate(); show_control_settings(), show_control_settings),
		_resettable("Invert touch scroll: " + _toggle(Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL)), Settings.CFG_TOUCH_INVERT_SCROLL, func():
			Settings.store(Settings.CFG_TOUCH_INVERT_SCROLL, !Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL))
			show_control_settings()
		, show_control_settings),
	])

# ── General settings ─────────────────────────────────────────────────────────

func populate_minui_paths():
	var external_path = AndroidInterface.get_external_storage_path()
	if external_path == null:
		Global.clear_visible("Unable to access external storage", ["OK"])
		return

func show_system_settings():
	Global.clear_visible("General Settings", [
		option.with_callback("Select storage", func(): Navigator.push("file_browser")),
		option.with_callback("Refresh file cache", func():
			Global.clear_dir_cache()
			Global.clear_visible("File cache cleared.", [option.with_callback("OK", show_system_settings)])
		),
		option.with_callback("Reimport all configs", func():
			Global.clear_visible("Overwrite all configs with bundled defaults?", [
				option.with_callback("Overwrite", func():
					Global.reimport_all_configs()
					Global.clear_dir_cache()
					Global.clear_visible("Configs reimported.", [option.with_callback("OK", func(): Navigator.go_to_main())])
				),
				option.with_callback("Cancel", show_system_settings),
			])
		),
		option.with_callback("Restore all game settings", func():
			Global.clear_all_settings()
			Global.clear_visible("Restored settings to default.", [option.with_callback("OK", func(): Navigator.go_to_main())])
		),
		option.with_callback("Remove Plain Launcher directory", func():
			Global.clear_visible("Delete everything in " + Global.root_path + "?", [
				option.with_callback("Delete it", func():
					var root = DirAccess.open(Global.root_path)
					if root:
						root.rename_absolute(Global.root_path, Global.root_path + "-" + str(Time.get_unix_time_from_system()))
						Global.clear_dir_cache()
						Navigator.push("file_browser")
				),
				option.with_callback("Nevermind", show_system_settings),
			])
		),
	])

# ── Process ───────────────────────────────────────────────────────────────────

func _process(_delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected()
		selected.trigger(Actions.CONFIRM)
		return

	if Input.is_action_just_pressed("start"):
		var selected = Global.get_selected()
		selected.trigger(Actions.START)
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

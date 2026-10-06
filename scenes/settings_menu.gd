extends RefCounted

const StorageSetup = preload("res://scenes/storage_setup.gd")

const TEXT_SIZE_NAMES = ["Small", "Medium", "Large", "Extra large"]
const TEXT_SIZE_FACTORS = [0.8, 1.0, 1.2, 1.45]
const COVER_SIZE_NAMES = ["Off", "Small", "Medium", "Large"]
const ALIGNMENT_NAMES = ["Left", "Center", "Right"]
const COVER_BORDER = Vector2(8, 8)
const FONT_DIR = "res://launcher_configs/COMMON/fonts"
const DEFAULT_FONT = "res://launcher_configs/COMMON/fonts/Rubik/Rubik-Medium.ttf"
const FONT_WEIGHTS = ["Light", "Regular", "Medium", "Bold", "ExtraBold"]
const SGDB_VALIDATE_URL = "https://www.steamgriddb.com/api/v2/search/autocomplete/test"
const OFL_URL = "https://openfontlicense.org"

var panel
var http: HTTPRequest = null
var sgdb_status = ""

func _init(slide_panel):
	panel = slide_panel

static func nearest_index(value: float, options: Array) -> int:
	var best = 0
	for i in range(options.size()):
		if absf(options[i] - value) < absf(options[best] - value):
			best = i
	return best

static func text_size_index(scaler: float, default_scaler: float) -> int:
	return nearest_index(scaler / default_scaler, TEXT_SIZE_FACTORS)

static func font_name(path) -> String:
	if path == null or path == "":
		return "Default"
	return str(path).get_base_dir().get_file()

static func font_families() -> Array:
	var families = Array(DirAccess.get_directories_at(FONT_DIR))
	families.sort()
	return families

static func font_path(family: String, weight: String) -> String:
	return FONT_DIR + "/" + family + "/" + family + "-" + weight + ".ttf"

static func font_weights(family: String) -> Array:
	return FONT_WEIGHTS.filter(func(w): return ResourceLoader.exists(font_path(family, w)))

static func current_font_path() -> String:
	var path = Settings.get_setting(Settings.CFG_FONT)
	return path if path != null and path != "" else DEFAULT_FONT

func _with_font(opt: option, path: String) -> option:
	if ResourceLoader.exists(path):
		opt.set_meta("font", ResourceLoader.load(path))
	return opt

func _apply_font(path: String):
	Settings.store(Settings.CFG_FONT, path)
	Global.font = ResourceLoader.load(path)
	Global.refresh_fonts()
	Global.apply_visual_change()
	panel.relayout()

func font_menu() -> Dictionary:
	var current_family = current_font_path().get_base_dir().get_file()
	var items = []
	for family in font_families():
		var marker = "• " if family == current_family else ""
		items.append(_with_font(option.with_callback(marker + family, func(): panel.push_menu(func(): return font_weight_menu(family))), font_path(family, "Medium")))
	return {"title": "Font", "items": items}

func font_weight_menu(family: String) -> Dictionary:
	var current = current_font_path()
	var items = []
	for weight in font_weights(family):
		var path = font_path(family, weight)
		var marker = "• " if path == current else ""
		items.append(_with_font(option.with_callback(marker + weight, func():
			_apply_font(path)
			panel.back()
			panel.back()), path))
	return {"title": family, "items": items}

func open(section: String = ""):
	panel.corner_text = "v" + Global.VERSION
	panel.open(main_menu)
	match section:
		"general":
			panel.push_menu(general_menu)
		"visuals":
			panel.push_menu(visual_menu)
		"controls":
			panel.push_menu(controls_menu)
		"collections":
			panel.push_menu(collections_menu)
		"scraper":
			panel.push_menu(scraper_menu)

func open_failure():
	panel.corner_text = ""
	var lines = failure_lines(Global.failure_message, Global.pending_intent, Global.pending_game)
	Global.pending_game = ""
	panel.open(func(): return failure_menu(lines))

static func failure_lines(message: String, intent: String, game: String) -> Array:
	var lines = [message] if message != "" else []
	if intent != "":
		lines.append("Check that " + intent + " is installed" + (" and can read" if game != "" else ""))
	if game != "":
		lines.append(game)
	return lines

func failure_menu(lines: Array) -> Dictionary:
	var items = lines.map(func(l): return option.new_option(l))
	var retry = Global.last_launch
	if not retry.is_empty():
		items.append(option.with_callback("Retry", func():
			panel.close()
			Launcher.launch_entry(retry.path, retry.system, retry.name)))
	items.append(option.with_callback("Change emulator", func():
		var selected = Global.get_selected() if not Global.option_list.is_empty() else null
		panel.close()
		Global.open_options(selected)))
	return {"title": "Launch failed", "items": items, "width": SlidePanel.WIDE_RATIO, "selection": items.size() - 2 if not retry.is_empty() else items.size() - 1}

func storage_menu() -> Dictionary:
	var current = option.new_option("Current")
	current.set_meta("value", str(Global.root_path))
	return {"title": "Storage", "width": SlidePanel.WIDE_RATIO, "items": [
		current,
		option.with_callback("Use on-device storage", func(): AndroidInterface.create_internal_storage(_storage_chosen, _storage_failed)),
		option.with_callback("Use removable storage", func(): AndroidInterface.create_external_storage(_storage_chosen, _storage_failed)),
		option.with_callback("Choose a folder", func(): AndroidInterface.choose_storage_directory(_storage_chosen, _storage_failed)),
		option.with_callback("Grant file permissions", func(): AndroidInterface.request_permissions()),
	], "selection": 1}

func _storage_chosen(selection):
	var problem = StorageSetup.use_selection(str(selection))
	if problem != "":
		Global.show_message(problem, true)
		return
	panel.close()
	Global.clear_dir_cache()
	Navigator.go_to_main()
	Global.show_message("Storage set", true)

func _storage_failed(_message = ""):
	Global.show_message("Unable to access that storage", true)

func _refresh():
	panel.relayout()
	panel.show_menu(true)

static func with_value(opt: option, value) -> option:
	opt.set_meta("checked" if value is bool else "value", value)
	return opt

func _with_default(opt: option, reset: Callable) -> option:
	opt.callbacks[Actions.START] = func(): reset.call(); _refresh()
	return opt

func _color_row(label: String, key: String, other_key: String) -> option:
	var opt = option.with_callback(label, func(): panel.push_menu(func(): return color_menu(label, key, other_key)))
	return _with_default(opt, func():
		Settings.store(key, Settings.DEFAULT_SETTINGS[key])
		_apply_color())

func _value(label: String, value, step: Callable, reset: Callable) -> option:
	var opt = with_value(option.with_callback(label, func(): step.call(1); _refresh()), value)
	opt.callbacks[Actions.DIRECTION] = func(direction: int): step.call(direction); _refresh()
	opt.callbacks[Actions.START] = func(): reset.call(); _refresh()
	return opt

func _toggle(label: String, key: String) -> option:
	return _value(label, Settings.get_setting(key), func(_d):
		Settings.store(key, !Settings.get_setting(key))
		Global.apply_visual_change(), func():
		Settings.store(key, Settings.DEFAULT_SETTINGS.get(key))
		Global.apply_visual_change())

func _screen(label: String, section: String, screen: String, before: Callable = Callable()) -> option:
	return option.with_callback(label, func():
		Global.settings_reopen_section = section
		if before.is_valid():
			before.call()
		panel.open_screen(screen))

func _confirm(question: String, yes_label: String, action: Callable) -> option:
	return option.with_callback(question.split("?")[0].replace("Really ", ""), func():
		panel.push_menu(func(): return {"title": question, "choices": true, "items": [
			option.with_callback(yes_label, func(): panel.back(); action.call()),
			option.with_callback("Cancel", func(): panel.back()),
		]}))

func _cycle_index(current: int, count: int, direction: int) -> int:
	return posmod(current + direction, count)

func main_menu() -> Dictionary:
	return {"title": "Settings", "items": [
		option.with_callback("General", func(): panel.push_menu(general_menu)),
		option.with_callback("Visuals", func(): panel.push_menu(visual_menu)),
		option.with_callback("Controls", func(): panel.push_menu(controls_menu)),
		option.with_callback("Collections", func(): panel.push_menu(collections_menu)),
		option.with_callback("Scraper", func(): panel.push_menu(scraper_menu)),
		option.with_callback("Launchers", func(): panel.push_menu(launchers_menu)),
		option.with_callback("Credits", func(): panel.push_menu(credits_menu)),
		option.with_callback("Quit", func(): panel.get_tree().quit()),
	]}

func visual_menu() -> Dictionary:
	var default_scaler = Settings._compute_default_scaler()
	var size_index = text_size_index(Settings.get_setting(Settings.CFG_SCALER), default_scaler)
	var cover_index = Global.get_cycle_index(Settings.CFG_VISUAL_COVER_SIZE, Settings.COVER_SIZES) - 1
	var align_index = Global.get_cycle_index(Settings.CFG_VISUAL_TITLE_ORIENTATION, Settings.TITLE_ORIENTATIONS) - 1
	return {"title": "Visuals", "items": [
		_value("Text size", TEXT_SIZE_NAMES[size_index], func(d):
			Settings.store(Settings.CFG_SCALER, default_scaler * TEXT_SIZE_FACTORS[_cycle_index(size_index, TEXT_SIZE_NAMES.size(), d)])
			Global.apply_visual_change(), func():
			Settings.store(Settings.CFG_SCALER, default_scaler)
			Global.apply_visual_change()),
		_with_default(_with_font(with_value(option.with_callback("Font", func(): panel.push_menu(font_menu)), font_name(current_font_path())), current_font_path()), func(): _apply_font(DEFAULT_FONT)),
		_value("Uppercase text", Settings.get_setting(Settings.CFG_CAPS_LOCK), func(_d): Global.caps_lock(), func():
			if Settings.get_setting(Settings.CFG_CAPS_LOCK):
				Global.caps_lock()),
		_color_row("Background color", Settings.CFG_BG_COLOR, Settings.CFG_FG_COLOR),
		_color_row("Text color", Settings.CFG_FG_COLOR, Settings.CFG_BG_COLOR),
		with_value(_color_row("Bar color", Settings.CFG_BAR_COLOR, Settings.CFG_FG_COLOR), "Custom" if Settings.get_setting(Settings.CFG_BAR_COLOR) is Color else "Off"),
		_value("Cover size", COVER_SIZE_NAMES[cover_index], func(d):
			Settings.store(Settings.CFG_VISUAL_COVER_SIZE, Settings.COVER_SIZES[_cycle_index(cover_index, Settings.COVER_SIZES.size(), d)])
			Global.apply_visual_change()
			if not Global.cover_on_left():
				panel.peek(), func():
			Settings.store(Settings.CFG_VISUAL_COVER_SIZE, Settings.DEFAULT_SETTINGS[Settings.CFG_VISUAL_COVER_SIZE])
			Global.apply_visual_change()),
		_value("Cover position", "Left" if Settings.get_setting(Settings.CFG_COVER_SIDE) == "left" else "Right", func(_d):
			Settings.store(Settings.CFG_COVER_SIDE, "right" if Settings.get_setting(Settings.CFG_COVER_SIDE) == "left" else "left")
			Global.apply_visual_change()
			panel.peek(), func():
			Settings.store(Settings.CFG_COVER_SIDE, "right")
			Global.apply_visual_change()),
		_value("Nearby covers", Settings.get_setting(Settings.CFG_NEARBY_COVERS), func(_d):
			Settings.store(Settings.CFG_NEARBY_COVERS, not Settings.get_setting(Settings.CFG_NEARBY_COVERS))
			Global.apply_visual_change()
			if not Global.cover_on_left():
				panel.peek(), func():
			Settings.store(Settings.CFG_NEARBY_COVERS, false)
			Global.apply_visual_change()),
		_value("Cover border", Settings.get_setting(Settings.CFG_VISUAL_BORDER) != Vector2.ZERO, func(_d):
			Settings.store(Settings.CFG_VISUAL_BORDER, Vector2.ZERO if Settings.get_setting(Settings.CFG_VISUAL_BORDER) != Vector2.ZERO else COVER_BORDER)
			Global.apply_visual_change(), func():
			Settings.store(Settings.CFG_VISUAL_BORDER, Settings.DEFAULT_SETTINGS[Settings.CFG_VISUAL_BORDER])
			Global.apply_visual_change()),
		_toggle("System art", Settings.CFG_VISUAL_SYSTEM_ART),
		_value("Title alignment", ALIGNMENT_NAMES[align_index], func(d):
			Settings.store(Settings.CFG_VISUAL_TITLE_ORIENTATION, Settings.TITLE_ORIENTATIONS[_cycle_index(align_index, ALIGNMENT_NAMES.size(), d)])
			Global.apply_visual_change(), func():
			Settings.store(Settings.CFG_VISUAL_TITLE_ORIENTATION, Settings.DEFAULT_SETTINGS[Settings.CFG_VISUAL_TITLE_ORIENTATION])
			Global.apply_visual_change()),
		_value("Home title", home_title_name(), func(d): Global.cycle_system_title(d), func():
			Settings.store(Settings.CFG_SYSTEM_TITLE, Settings.DEFAULT_SETTINGS.get(Settings.CFG_SYSTEM_TITLE))
			Global.refresh_home_title()),
		_toggle("Button prompts", Settings.CFG_VISUAL_PROMPT_BAR),
		_confirm("Restore defaults?", "Restore", func():
			Settings.reset_visual()
			Global.font = ResourceLoader.load(current_font_path())
			Global.refresh_fonts()
			Global.refresh_home_title()
			_refresh()),
	]}

func general_menu() -> Dictionary:
	return {"title": "General", "items": [
		option.with_callback("Refresh file cache", func():
			Global.refresh_file_cache()
			Global.show_message("File cache refreshed", true)),
		option.with_callback("Storage", func(): panel.push_menu(storage_menu)),
		_confirm("Reimport all configs?", "Overwrite", func():
			Global.reimport_all_configs()
			Global.refresh_file_cache()
			Global.show_message("Configs reimported", true)),
		_confirm("Restore all game settings?", "Restore", func():
			Global.clear_all_settings()
			Global.show_message("Game settings restored", true)),
		_confirm("Remove Plain Launcher directory?", "Delete it", func():
			var root = DirAccess.open(Global.root_path)
			if root:
				root.rename_absolute(Global.root_path, Global.root_path + "-" + str(Time.get_unix_time_from_system()))
				Global.clear_dir_cache()
				panel.open_screen("file_browser")),
	]}

func controls_menu() -> Dictionary:
	return {"title": "Controls", "items": [
		_value("Swap confirm button", Global.confirm_swapped, func(_d):
			Global.swap_confirm_key()
			Global.refresh_prompt_bar(), func():
			if Global.confirm_swapped:
				Global.swap_confirm_key()
				Global.refresh_prompt_bar()),
		_toggle("Vibration", Settings.CFG_VIBRATE),
		_toggle("Touch controls", Settings.CFG_TOUCH_ENABLED),
		_toggle("Invert touch scroll", Settings.CFG_TOUCH_INVERT_SCROLL),
	]}

func collections_menu() -> Dictionary:
	return {"title": "Collections", "items": [
		_value("Show hidden", Global.show_hidden, func(_d):
			Global.show_hidden = !Global.show_hidden
			Global.refresh_file_cache(), func():
			Global.show_hidden = false
			Global.refresh_file_cache()),
		_toggle("Favorites first", Settings.CFG_SHOW_FAVS_FIRST),
		_confirm("Clear favorites?", "Clear", func():
			Global.clear_all_favorites()
			Global.show_message("Favorites cleared", true)),
		_confirm("Clear history?", "Clear", func():
			Global.clear_recent_history()
			Global.show_message("History cleared", true)),
	]}

static func home_title_name() -> String:
	var title = str(Settings.get_setting(Settings.CFG_SYSTEM_TITLE))
	return title.capitalize() if title != "" else "None"

func color_menu(title: String, key: String, other_key: String) -> Dictionary:
	var state = {"original": Settings.get_setting(key)}
	var grid = PaletteGrid.new()
	grid.colors = PaletteGrid.load_palette()
	grid.select_color(state.original if state.original is Color else Settings.get_setting(Settings.CFG_BG_COLOR))
	grid.on_change = func(color: Color):
		Settings.store(key, color)
		_apply_color()
	var default_label = "Off" if Settings.DEFAULT_SETTINGS[key] == null else "Default"
	return {"title": title, "custom": grid, "prompts": [["confirm", "Keep"], ["favorite", default_label], ["back", "Cancel"]],
		"on_confirm": func():
			if grid.selected_color().is_equal_approx(Settings.get_setting(other_key)):
				Global.show_message("Too close to the other color", true)
				return
			state.original = grid.selected_color()
			panel.back(),
		"on_start": func():
			var default = Settings.DEFAULT_SETTINGS[key]
			if default is Color:
				grid.select_color(default)
			Settings.store(key, default)
			_apply_color()
			if default == null:
				state.original = null
				panel.back(),
		"on_cancel": func():
			Settings.store(key, state.original)
			_apply_color(),
	}

func _apply_color():
	Global.apply_visual_change()
	panel.relayout()

func _input(prompt: String, value: String, password: bool, on_text: Callable):
	AndroidInterface.show_text_input(prompt, value, password, func(text: String):
		on_text.call(text)
		_refresh())

static func set_label(value: String) -> String:
	return "Set" if value != "" else "Not set"

func scraper_menu() -> Dictionary:
	var items = []
	if Settings.get_setting(Settings.CFG_SCREENSCRAPER_URL) != "":
		var user = Settings.get_setting(Settings.CFG_SS_USER)
		items.append(with_value(option.with_callback("ScreenScraper user", func():
			_input("ScreenScraper username", Settings.get_setting(Settings.CFG_SS_USER), false, func(text):
				if text != "":
					Settings.store(Settings.CFG_SS_USER, text))), user if user != "" else "Not set"))
		items.append(with_value(option.with_callback("ScreenScraper password", func():
			_input("ScreenScraper password", "", true, func(text):
				if text != "":
					Settings.store(Settings.CFG_SS_PASS, text))), set_label(Settings.get_setting(Settings.CFG_SS_PASS))))
	else:
		items.append(with_value(option.new_option("ScreenScraper"), "Not in this build"))
	var key_label = sgdb_status if sgdb_status != "" else set_label(Settings.get_setting(Settings.CFG_SGDB_KEY))
	items.append(with_value(option.with_callback("SteamGridDB key", func():
		_input("SteamGridDB API key", "", true, func(text):
			if text != "":
				Settings.store(Settings.CFG_SGDB_KEY, text)
				validate_sgdb_key(text))), key_label))
	return {"title": "Scraper", "items": items}

func validate_sgdb_key(key: String):
	if http == null:
		http = HTTPRequest.new()
		panel.add_child(http)
	sgdb_status = "Checking..."
	if http.request(SGDB_VALIDATE_URL, ["Authorization: Bearer " + key]) != OK:
		sgdb_status = "Could not reach SteamGridDB"
		return
	var args = await http.request_completed
	sgdb_status = sgdb_result(args[1])
	if args[1] == 401 or args[1] == 403:
		Settings.store(Settings.CFG_SGDB_KEY, "")
	if panel.is_open:
		_refresh()

static func sgdb_result(code: int) -> String:
	if code == 200:
		return "Valid"
	if code == 401 or code == 403:
		return "Invalid, not saved"
	return "Error (HTTP " + str(code) + ")"

func launchers_menu() -> Dictionary:
	return {"title": "Launchers", "items": [
		option.with_callback("Built-in launchers", func(): panel.push_menu(built_in_launchers_menu)),
		option.with_callback("Custom launchers", func(): panel.push_menu(custom_launchers_menu)),
		_toggle("Exit RetroArch on focus loss", Settings.CFG_RETROARCH_QUIT_ON_LEAVE),
	]}

static func launcher_names(built_in: bool) -> Array:
	var names = Launcher.load_intents().keys().filter(func(n): return Launcher.is_bundled_intent(n) == built_in)
	names.sort()
	return names

func built_in_launchers_menu() -> Dictionary:
	var items = launcher_names(true).map(func(name): return option.with_callback(name, func(): panel.push_menu(func(): return intent_menu(name))))
	return {"title": "Built-in launchers", "items": items, "width": SlidePanel.WIDE_RATIO}

func custom_launchers_menu() -> Dictionary:
	var items = [option.with_callback("Add new launcher", func():
		AndroidInterface.show_text_input("Launcher name (e.g. myemulator)", "", false, func(text: String):
			if text == "":
				return
			var id = Launcher.unused_intent_id(text)
			Launcher.save_custom_intent(id, {"action": "android.intent.action.VIEW", "componentPackage": "", "componentClass": "", "systems": []})
			panel.push_menu(func(): return intent_menu(id))))]
	for name in launcher_names(false):
		items.append(option.with_callback(name, func(): panel.push_menu(func(): return intent_menu(name))))
	return {"title": "Custom launchers", "items": items, "width": SlidePanel.WIDE_RATIO}

static func split_list(text: String, upper: bool = false) -> Array:
	return Array(text.split(",")).map(func(s): return s.strip_edges().to_upper() if upper else s.strip_edges()).filter(func(s): return s != "")

func intent_menu(name: String) -> Dictionary:
	var intent: Dictionary = Launcher.load_intents().get(name, {}).duplicate(true)
	var built_in = Launcher.is_bundled_intent(name)
	var save = func(): Launcher.save_custom_intent(name, intent)
	var edit = func(label: String, prompt: String, shown: String, current: String, apply: Callable):
		return with_value(option.with_callback(label, func():
			_input(prompt, current, false, func(text):
				apply.call(text)
				save.call())), shown)
	var field = func(label: String, key: String, prompt: String, fallback: String = ""):
		if built_in and str(intent.get(key, "")) == "":
			return null
		return edit.call(label, prompt, str(intent.get(key, "None")), str(intent.get(key, fallback)), func(text):
			if text == "":
				intent.erase(key)
			else:
				intent[key] = text)
	var flags = intent.get("flags", [])
	var systems = intent.get("systems", [])
	var extras = intent.get("extras", {})
	var items = [
		field.call("Action", "action", "Action"),
		field.call("Package", "componentPackage", "Package"),
		field.call("Class", "componentClass", "Activity class"),
		field.call("Data", "data", "Data URI (empty to remove)", "{game}"),
		field.call("File", "providedFile", "File path (empty to remove)", "{game}"),
		edit.call("Flags", "Flags (comma-separated, empty for default)", ", ".join(flags) if not flags.is_empty() else "Default", ", ".join(flags), func(text):
			if text == "":
				intent.erase("flags")
			else:
				intent["flags"] = split_list(text)),
		edit.call("Systems", "Systems (comma-separated, e.g. GBA, GBC)", ", ".join(systems) if not systems.is_empty() else "None", ", ".join(systems), func(text):
			intent["systems"] = split_list(text, true)),
	].filter(func(item): return item != null)
	for key in extras:
		items.append(edit.call(key, key + " (empty to remove)", str(extras[key]), str(extras[key]), func(text):
			if text == "":
				extras.erase(key)
			else:
				extras[key] = text))
	if built_in:
		for item in items:
			item.callbacks.clear()
		items.append(option.with_callback("Make a custom copy", func():
			var copy = Launcher.copy_as_custom(name)
			panel.back()
			panel.push_menu(func(): return intent_menu(copy))))
	else:
		items.append(option.with_callback("Add extra", func():
			AndroidInterface.show_text_input("Extra key name", "", false, func(key: String):
				if key == "":
					return
				_input("Value for " + key + " (use {game}, {core}, etc.)", "", false, func(text):
					if text != "":
						extras[key] = text
						intent["extras"] = extras
						save.call()))))
		items.append(_confirm("Delete launcher?", "Delete", func():
			Launcher.remove_custom_intent(name)
			panel.back()))
	return {"title": name + (" (built-in)" if built_in else ""), "items": items, "width": SlidePanel.WIDE_RATIO}

func _link(text: String) -> option:
	return option.with_callback(text, func(): AndroidInterface.launch_intent(JSON.stringify({"action": "android.intent.action.VIEW", "data": text})))

func _info(title: String, lines: Array) -> Callable:
	return func(): panel.push_menu(func(): return {"title": title, "items": lines.map(func(l): return _link(l) if l.begins_with("https") else option.new_option(l)), "width": SlidePanel.WIDE_RATIO})

static func font_credit_lines(family: String) -> Array:
	var lines = []
	var link = RegEx.create_from_string("^(.*?)\\s*\\((https?://[^)]+)\\)$")
	for line in FileAccess.get_file_as_string(FONT_DIR + "/" + family + "/OFL.txt").split("\n"):
		if line.strip_edges() == "":
			break
		var found = link.search(line)
		if found != null:
			lines.append_array([found.get_string(1), found.get_string(2)])
		else:
			lines.append(line)
	lines.append_array(["SIL Open Font License 1.1", OFL_URL])
	return lines

func credits_menu() -> Dictionary:
	return {"title": "Credits", "items": [
		option.with_callback("Development", _info("Development", ["Created with Godot 4", "https://godotengine.org/", "by Yossarian", "https://ko-fi.com/yossariano"])),
		option.with_callback("Fonts", func(): panel.push_menu(func(): return {"title": "Fonts", "items": font_families().map(func(f): return _with_font(option.with_callback(f, _info(f, font_credit_lines(f))), font_path(f, "Medium")))})),
		option.with_callback("System images", _info("System images", ["All system photos by Evan Amos", "https://commons.wikimedia.org/wiki/User:Evan-Amos"])),
		option.with_callback("Color palette", _info("Color palette", ["'Duel' palette created by Arilyn", "https://lospec.com/palette-list/duel"])),
	]}


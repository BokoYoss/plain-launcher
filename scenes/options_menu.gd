extends RefCounted

const ArtScraper = preload("res://scenes/art_scraper.gd")

const PREVIEW_DELAY_SECONDS = 0.3
const ART_SOURCES = ["Google", "DuckDuckGo", "TGDB", "Launchbox", "SteamGridDB"]
const SETTING_NAMES = {"EMULATOR": ["Emulator", "Default emulator"], "CORE": ["Core", "Default core"], "EXTENSIONS": ["File extensions", "File extensions"]}

var panel
var item = null
var settings: Dictionary = {}
var changed = false
var pending_image: Image = null

func _init(slide_panel):
	panel = slide_panel

func open(selected):
	item = selected
	Global.special_item = item
	settings = load_settings()
	changed = false
	panel.corner_text = ""
	panel.open(main_menu, "left", _on_close)
	Global.force_cover = true
	Global.refresh_art()

func _on_close():
	Global.force_cover = false
	Global.img_texture_override = null
	Global.special_item = null
	Global.refresh_art()
	if changed:
		Global.refresh_file_cache()
	item = null

func _refresh():
	panel.show_menu(true)

static func setting_name(key: String, is_dir: bool) -> String:
	var names = SETTING_NAMES.get(key)
	return names[1 if is_dir else 0] if names else key.capitalize()

func load_settings() -> Dictionary:
	if item.is_dir:
		return Global.get_system_settings(item.system)
	return Global.get_system_settings(item.system, item.filename, item.clean)

func settings_path() -> String:
	if item.is_dir:
		return Global.root_path + Global.PATH_CONFIG + item.system + "/config.json"
	return Global.get_game_settings_path(item.system, item.filename)

func matches_system_default() -> bool:
	var systemwide = Global.get_systemwide_settings(item.system)
	for key in systemwide.keys():
		if settings.get(key) != systemwide.get(key):
			return false
	return true

func save():
	var path = settings_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if not item.is_dir:
		var legacy = Global.get_legacy_game_settings_path(item.system, item.clean)
		if FileAccess.file_exists(legacy):
			DirAccess.remove_absolute(legacy)
	if settings.is_empty() or (not item.is_dir and matches_system_default()):
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	Global.write_json(path, settings)

func restore_defaults():
	settings = {}
	save()
	settings = load_settings()

func _check(label: String, checked: bool, toggle: Callable, default_checked = null) -> option:
	var opt = option.with_callback(label, func():
		toggle.call()
		changed = true
		_refresh())
	opt.set_meta("checked", checked)
	if default_checked != null:
		opt.callbacks[Actions.START] = func():
			if checked != default_checked:
				opt.trigger(Actions.CONFIRM)
	return opt

func _rename(text: String):
	Global.set_custom_name(item, text)
	if not item.is_dir:
		item.clean = text.strip_edges() if text.strip_edges() != "" else Global.default_name(item)
	changed = true
	_refresh()

func default_settings() -> Dictionary:
	if item.is_dir:
		return Global.build_system_settings_from_options(item.system)
	return Global.get_systemwide_settings(item.system)

func _reset_setting(key: String):
	_reset_setting_values(key)
	_refresh()

func _reset_setting_values(key: String):
	var defaults = default_settings()
	if defaults.has(key):
		settings[key] = defaults[key]
	else:
		settings.erase(key)
	save()

func _value(label: String, value: String, action: Callable) -> option:
	var opt = option.with_callback(label, action)
	opt.set_meta("value", value)
	return opt

static func value_text(value) -> String:
	if value is Array:
		return ", ".join(value) if not value.is_empty() else "None"
	return str(value) if value != null and str(value) != "" else "None"

func main_menu() -> Dictionary:
	var items = []
	if not item.is_dir:
		items.append(_check("Favorite", Global.favorites_list.has(item.absolute_path), func(): Global.toggle_favorite(item), false))
	items.append(_check("Hidden", Global.HIDDEN_LIST.get(item.absolute_path, false), func(): Global.toggle_hidden(), false))
	if item.is_dir or item.system != "ANDROID":
		var custom = Global.custom_name(item)
		var toggle = option.with_callback("Custom name", func(): _rename("" if custom != "" else Global.default_name(item)))
		toggle.set_meta("checked", custom != "")
		toggle.callbacks[Actions.START] = func(): _rename("")
		items.append(toggle)
		if custom != "":
			items.append(_value("Name", custom, func():
				AndroidInterface.show_text_input("Name to show", custom, false, func(text: String):
					_rename(text))))
	var is_retroarch = str(settings.get("EMULATOR", "")).to_lower().begins_with("retroarch")
	for key in shown_keys(settings, Global.get_system_settings_options(item.system)):
		if key == "EXTENSIONS" and not item.is_dir:
			continue
		if key == "CORE" and not is_retroarch:
			continue
		var row: option
		if key == "EXTENSIONS":
			row = _value(setting_name(key, true), value_text(settings[key]), func(): panel.push_menu(extensions_menu))
		else:
			row = _value(setting_name(key, item.is_dir), value_text(settings[key]), func(): panel.push_menu(func(): return choice_menu(key)))
		row.callbacks[Actions.START] = func(): _reset_setting(key)
		items.append(row)
	if item.is_dir:
		items.append(option.with_callback("Emulators", func(): panel.push_menu(emulators_menu)))
		items.append(option.with_callback("Additional game paths", func(): panel.push_menu(paths_menu)))
	if item.system == "ANDROID":
		items.append(option.with_callback("App settings", func(): AndroidInterface.app_settings(item.absolute_path)))
	items.append(option.with_callback("Find art" if item.is_dir else "Find cover art", func(): panel.push_menu(art_sources_menu)))
	if Global.is_system_item(item) and FileAccess.file_exists(Global.custom_art_path(item)):
		items.append(_confirm("Remove custom art?", "Remove", func():
			DirAccess.remove_absolute(Global.custom_art_path(item))
			Global.refresh_art()
			_refresh()))
	if not settings.is_empty():
		items.append(_confirm("Restore defaults?", "Restore", func():
			restore_defaults()
			Global.show_message("Options restored", true)
			_refresh()))
	items.append(option.with_callback("Details", func(): panel.push_menu(details_menu)))
	return {"title": item.clean, "items": items}

func _confirm(question: String, yes_label: String, action: Callable) -> option:
	return option.with_callback(question.trim_suffix("?"), func():
		panel.push_menu(func(): return {"title": question, "choices": true, "items": [
			option.with_callback(yes_label, func(): panel.back(); action.call()),
			option.with_callback("Cancel", func(): panel.back()),
		]}))

func choice_menu(key: String) -> Dictionary:
	var choices = Global.get_system_settings_options(item.system).get(key, [])
	var current = settings.get(key)
	var items = []
	for choice in choices:
		var opt = option.with_callback(str(choice), func():
			settings[key] = choice
			save()
			panel.back())
		opt.set_meta("checked", choice == current)
		items.append(opt)
	return {"title": setting_name(key, item.is_dir), "items": items, "selection": maxi(0, choices.find(current))}

func extensions_menu() -> Dictionary:
	var choices = Global.get_system_settings_options(item.system).get("EXTENSIONS", [])
	var active: Array = settings.get("EXTENSIONS", [])
	var items = []
	for extension in choices:
		items.append(_check(str(extension), extension in active, func():
			var updated: Array = settings.get("EXTENSIONS", []).duplicate()
			if extension in updated:
				updated.erase(extension)
			else:
				updated.append(extension)
			settings["EXTENSIONS"] = updated
			save()))
	return {"title": "File extensions", "items": items}

func emulators_menu() -> Dictionary:
	var all: Array = Launcher.load_intents().keys()
	all.sort()
	var active: Array = Global.get_system_settings_options(item.system).get("EMULATOR", [])
	var items = []
	for id in all:
		items.append(_check(id, id in active, func(): toggle_emulator(id)))
	return {"title": item.clean + " emulators", "items": items, "width": SlidePanel.WIDE_RATIO}

func toggle_emulator(id: String):
	var active: Array = Global.get_system_settings_options(item.system).get("EMULATOR", []).duplicate()
	if id in active:
		active.erase(id)
	else:
		active.append(id)
	var choices_path = Global.root_path + Global.PATH_CONFIG + item.system + "/choices.json"
	var choices = Global.read_json_dict(choices_path)
	choices["EMULATOR"] = active
	choices["EMULATOR_HIDDEN"] = Launcher.emulators_for_system(item.system).filter(func(e): return e not in active)
	Global.write_json(choices_path, choices)

static func shown_keys(current: Dictionary, choices: Dictionary) -> Array:
	var keys = current.keys().filter(func(k): return choices.has(k))
	var order = SETTING_NAMES.keys()
	keys.sort_custom(func(a, b): return (order.find(a) if a in order else 99) < (order.find(b) if b in order else 99))
	return keys

func art_sources_menu() -> Dictionary:
	var items = [option.with_callback("Scrape all games" if item.is_dir else "Scrape artwork", func():
		var scraper = ArtScraper.new(panel, item)
		panel.push_menu(scraper.backend_menu))]
	for source in ART_SOURCES:
		items.append(option.with_callback(source, func(): _watch_image(); AndroidInterface.look_for_art_web(item.clean, item.system, source)))
	items.append(option.with_callback("Choose from files", func(): _watch_image(); AndroidInterface.choose_file()))
	return {"title": "Find art", "items": items}

func _watch_image():
	if not AndroidInterface.got_image.is_connected(_on_image_chosen):
		AndroidInterface.got_image.connect(_on_image_chosen, CONNECT_ONE_SHOT)

static func decode_image(bytes: PackedByteArray) -> Image:
	var image = Image.new()
	if image.load_png_from_buffer(bytes) == OK or image.load_jpg_from_buffer(bytes) == OK or image.load_webp_from_buffer(bytes) == OK:
		return image
	return null

func _on_image_chosen(path: String):
	if item == null or path == "" or not FileAccess.file_exists(path):
		return
	pending_image = decode_image(FileAccess.get_file_as_bytes(path))
	if pending_image == null:
		Global.show_message("Could not read that image", true)
		return
	panel.push_menu(confirm_image_menu)
	await panel.get_tree().create_timer(PREVIEW_DELAY_SECONDS).timeout
	if pending_image != null:
		Global.img_texture_override = ImageTexture.create_from_image(pending_image)
		Global.refresh_art()

func confirm_image_menu() -> Dictionary:
	return {"title": "Use this image?", "choices": true, "items": [
		option.with_callback("Use it", func():
			var target = Global.custom_art_path(item)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			if pending_image.save_png(target) != OK:
				Global.show_message("Could not save image", true)
			Global.forget_missing_art(target)
			panel.back()
			panel.back()),
		option.with_callback("Cancel", func(): panel.back()),
	], "on_cancel": func():
		pending_image = null
		Global.img_texture_override = null
		Global.refresh_art()}

func paths_menu() -> Dictionary:
	var items = [option.with_callback("Add a path", func():
		AndroidInterface.choose_storage_directory(func(selection):
			var path = str(selection).replace(" ", "").replace(":", "/")
			if DirAccess.open(path) == null:
				Global.show_message("Unable to access " + path, true)
				return
			var paths = Global.get_user_paths(item.system)
			if path not in paths:
				paths.append(path)
				Global.store_additional_paths(item.system, paths)
				changed = true
			_refresh(), func(_message): Global.show_message("Unable to access that folder", true)))]
	for path in Global.get_user_paths(item.system):
		items.append(option.with_callback(path, func():
			panel.push_menu(func(): return {"title": "Remove this path?", "width": SlidePanel.WIDE_RATIO, "choices": true, "items": [
				option.new_option(path),
				option.with_callback("Remove", func():
					Global.remove_additional_path(item.system, path)
					changed = true
					panel.back()),
				option.with_callback("Cancel", func(): panel.back()),
			], "selection": 2})))
	return {"title": "Game paths", "items": items, "width": SlidePanel.WIDE_RATIO}

func details_menu() -> Dictionary:
	var path_heading = option.new_option("Path")
	path_heading.set_meta("heading", true)
	var image_heading = option.new_option("Image")
	image_heading.set_meta("heading", true)
	return {"title": "Details", "width": SlidePanel.FULL_RATIO, "static": true, "items": [
		path_heading,
		option.new_option(item.absolute_path),
		image_heading,
		option.new_option(Global.custom_art_path(item) if not Global.is_system_item(item) else Global.get_image_path(item)),
	]}

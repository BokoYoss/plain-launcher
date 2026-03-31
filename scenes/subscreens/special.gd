extends Screen

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")
var launcher

var pending_cover_download = false
var pending_cover_file = false
var pending_image = null
var download_path = null
var download_dir = null

var chosen_image_file = null

var system_settings = null
var system_settings_options = null
var settings_screen = false
var pending_setting = null
var _selector_mode: String = ""
var _key_display_map: Dictionary = {}

const _SETTING_DISPLAY = {
	"EMULATOR": ["Select emulator", "Select default emulator"],
	"CORE": ["Select core", "Select default core"],
	"EXTENSIONS": ["File extensions", "File extensions"],
}

func _setting_label(key: String) -> String:
	var variants = _SETTING_DISPLAY.get(key)
	if variants:
		return variants[1 if Global.special_item.is_dir else 0]
	return key

const download_dir_path = "/storage/emulated/0/Download"

var current_downloaded_list = []

var image_pending = false
var choosing_file = false
var showing_browser_sources = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if Global.special_item == null:
		return
	Global.populate_filter = Callable(self, "filter_item")
	$Path.bbcode_text = "[b]Path:[/b] " + Global.special_item.absolute_path + "\n[b]Image:[/b] " + Global.get_image_path(Global.special_item)
	$Path.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	$Path.position.y = Global.window_height - 64
	$Path.position.x = Global.left_bound
	$Path.size.x = Global.window_width
	$Path.size.y = 128
	$Path.set("theme_override_font_sizes/font_size", 16)
	$Path.add_theme_font_override("font", Global.font)
	AndroidInterface.connect("configured_storage", get_storage_selection)
	AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)
	AndroidInterface.connect("got_image", _on_image_chosen)
	populate_content()

func _on_resume():
	if _selector_mode != "":
		_apply_selector_result()
	populate_content()

func _apply_selector_result():
	match _selector_mode:
		"extensions":
			system_settings["EXTENSIONS"] = Global.selector_active.duplicate()
			write_settings_to_disk()
		"emulators":
			var choices_path = Global.root_path + Global.PATH_CONFIG + Global.special_item.system + "/choices.json"
			var choices = {}
			if FileAccess.file_exists(choices_path):
				choices = JSON.parse_string(FileAccess.get_file_as_string(choices_path))
				if choices == null: choices = {}
			choices["EMULATOR"] = Global.selector_active.duplicate()
			var f = FileAccess.open(choices_path, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(choices, "\t"))
				f.close()
		"EMULATOR", "CORE":
			if not Global.selector_active.is_empty():
				system_settings[_selector_mode] = Global.selector_active[0]
	_selector_mode = ""

func get_storage_selection(path):
	print("Got alt art path: " + path)
	Global.store_additional_art_path(path)
	populate_content()

func on_storage_config_failure(msg):
	pass

func populate_content():
	var settings = []
	var hide_toggle = "Hide"
	refresh_disk_settings()
	if Global.HIDDEN_LIST.get(Global.special_item.absolute_path, false):
		hide_toggle = "Unhide"
	if !Global.special_item.is_dir:
		var fave_toggle = "Add to favorites"
		if Global.favorites_list.get(Global.special_item.absolute_path, false) or Global.special_item.favorite_dir:
			fave_toggle = "Remove from favorites"
		settings.append(fave_toggle)
	else:
		settings.append("Additional game paths")
		settings.append("Additional art path: " + Global.get_additional_art_path())
	settings.append(hide_toggle)

	if not system_settings.is_empty():
		_key_display_map = {}
		var current_emulator = system_settings.get("EMULATOR", "")
		var is_retroarch = current_emulator.to_lower().begins_with("retroarch")
		for key in system_settings.keys():
			if key == "EXTENSIONS" and not Global.special_item.is_dir:
				continue
			if key == "CORE" and not is_retroarch:
				continue
			var label = _setting_label(key)
			_key_display_map[label.to_lower()] = key
			settings.append(label)
		if Global.special_item.is_dir:
			settings.append("Add emulators")
		settings.append("Restore defaults")
	if Global.special_item.system == "ANDROID":
		settings.append("Open app settings")
	if Global.special_item.is_dir:
		settings.append("Scrape all artwork")
		settings.append("Look for system art...")
	else:
		settings.append("Scrape artwork")
		settings.append("Look for cover art...")
	Global.clear_visible("Options - " + Global.special_item.clean, settings)
	show_image()
	Global.refresh_art()

func refresh_disk_settings():
	if system_settings == null:
		system_settings = Global.get_system_settings(Global.special_item.system)

func write_settings_to_disk():
	var settings_path = Global.root_path  + Global.PATH_CONFIG + Global.special_item.system
	if !Global.special_item.is_dir:
		settings_path = settings_path + "/" + Global.special_item.clean + ".json"
	else:
		settings_path = settings_path + "/config.json"
	if FileAccess.file_exists(settings_path):
		var settings_dir = DirAccess.open(settings_path.get_base_dir())
		print("DELETE SETTINGS at " + settings_path)
		settings_dir.remove_absolute(settings_path)
	if system_settings == null or system_settings.is_empty():
		return
	print("STORE SETTINGS " + str(system_settings) + " to " + settings_path)
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)
	var string_settings = JSON.stringify(system_settings, "    ")
	print("Saving " + Global.special_item.system + " settings: " + string_settings)
	settings_file.store_string(string_settings)
	settings_file.close()

func save_chosen_image():
	if pending_image != null:
		var new_path = Global.get_image_path(Global.special_item)
		print("Copying file from " + download_path + " to " + new_path)
		var result = pending_image.save_png(new_path)

		if result != 0:
			print("Error during copy: " + str(result))
			Global.clear_visible("Failure", ["Failed to access downloaded art."])
		else:
			if download_dir != null:
				print("Copy success, deleting file at " + download_path)
				download_dir.remove_absolute(download_path)

func game_settings_match_default():
	var systemwide = Global.get_systemwide_settings(Global.special_item.system)
	for key in systemwide.keys():
		if system_settings.get(key, null) != systemwide.get(key):
			print("FOUND CUSTOM SETTING FOR " + key + " GAME: " + str(system_settings.get(key, null)) + " SYSTEM: " + str(systemwide.get(key)))
			return false
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean.to_lower()
		if image_pending:
			image_pending = false
			if selected == "yes":
				save_chosen_image()
			else:
				Global.img_texture_override = null
			populate_content()
			return
		if "ok" == selected:
			populate_content()
			return
		if selected.begins_with("additional art path"):
			AndroidInterface.choose_storage_directory()
			return
		if Global.title.text.to_lower() == "failure":
			pass
		if "hide" in selected:
			Global.toggle_hidden()
		elif "favorites" in selected:
			Global.toggle_favorite(Global.special_item)
		elif selected == "additional game paths":
			Navigator.push("path_adder")
			return
		elif "app settings" in selected:
			AndroidInterface.app_settings(Global.special_item.absolute_path)
		elif "automatically" in selected:
			pending_cover_download = true
			if download_dir == null:
				download_dir = DirAccess.open(download_dir_path)
			if download_dir != null:
				current_downloaded_list = download_dir.get_files()

			get_normalized_art()
			return
		elif selected == "scrape all artwork" or selected == "scrape artwork":
			Navigator.push("scraper")
			return
		elif selected == "look for cover art..." or selected == "look for system art...":
			showing_browser_sources = true
			Global.clear_visible("Find cover art for " + Global.special_item.clean,
				["Google", "DuckDuckGo", "TGDB", "Launchbox", "SteamGridDB", "Choose from files"])
			return
		elif showing_browser_sources:
			showing_browser_sources = false
			if selected == "choose from files":
				choosing_file = true
				AndroidInterface.choose_file()
				return
			AndroidInterface.look_for_art_web(Global.special_item.clean, Global.special_item.system, selected)
			return
		elif selected == "add emulators":
			var intents_path = Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"
			const BUNDLED_INTENTS = "res://launcher_configs/COMMON/intents.json"
			var intents_raw = FileAccess.get_file_as_string(intents_path) if FileAccess.file_exists(intents_path) else FileAccess.get_file_as_string(BUNDLED_INTENTS)
			var intents = JSON.parse_string(intents_raw)
			var all_emulators: Array = intents.keys() if intents else []
			all_emulators.sort()
			var choices_path = Global.root_path + Global.PATH_CONFIG + Global.special_item.system + "/choices.json"
			var choices = {}
			if FileAccess.file_exists(choices_path):
				var c = JSON.parse_string(FileAccess.get_file_as_string(choices_path))
				if c != null: choices = c
			Global.selector_title = Global.special_item.system + " Emulators"
			Global.selector_items = all_emulators
			Global.selector_active = choices.get("EMULATOR", []).duplicate()
			Global.selector_multi = true
			_selector_mode = "emulators"
			Navigator.push("checkbox_selector")
			return
		elif "restore defaults" in selected:
			system_settings = null
			write_settings_to_disk()
			Global.clear_visible("Options restored.", ["OK"])
			return
		elif pending_setting == null and _key_display_map.has(selected):
			var key = _key_display_map[selected]
			var current_value = system_settings.get(key)
			print("CURRENT SETTING KEY: " + key + " VALUE: " + str(current_value))
			system_settings_options = Global.get_system_settings_options(Global.special_item.system)
			if system_settings_options == null:
				print("Options not found")
				return
			var options = system_settings_options.get(key, [])
			if key == "EXTENSIONS":
				var choices = Global.get_system_settings_options(Global.special_item.system)
				Global.selector_title = Global.special_item.system + " File Extensions"
				Global.selector_items = choices.get("EXTENSIONS", [])
				Global.selector_active = system_settings.get("EXTENSIONS", []).duplicate()
				Global.selector_multi = true
				_selector_mode = "extensions"
				Navigator.push("checkbox_selector")
				return
			elif key in ["EMULATOR", "CORE"] and options.size() > 0:
				Global.selector_title = Global.special_item.clean + " " + _setting_label(key)
				Global.selector_items = options
				Global.selector_active = [current_value] if current_value != null else []
				Global.selector_multi = false
				_selector_mode = key
				Navigator.push("checkbox_selector")
				return
			pending_setting = key
			Global.clear_visible(Global.special_item.clean + " " + pending_setting, options)
			for i in range(0, options.size()):
				if Global.option_list[i].filename == current_value:
					Global.highlight_selection(i)
					break
			return
		else:
			system_settings[pending_setting] = selected
			pending_setting = null
		populate_content()
		return
	if Global.back_pressed():
		Global.img_texture_override = null
		if showing_browser_sources:
			showing_browser_sources = false
			populate_content()
			return
		if pending_setting != null:
			pending_setting = null
			populate_content()
			return
		if image_pending:
			image_pending = false
			populate_content()
			return
		if Global.title.text.to_lower() == "failure":
			populate_content()
			return
		var is_system = Global.special_item.is_dir
		if is_system or (!is_system and !game_settings_match_default()):
			write_settings_to_disk()
		Global.special_item = null
		Navigator.pop()
		return

func _on_image_chosen(path: String):
	choosing_file = false
	if path == "":
		populate_content()
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		populate_content()
		return
	var bytes = file.get_buffer(file.get_length())
	file.close()
	var img = Image.new()
	if img.load_png_from_buffer(bytes) != OK and img.load_jpg_from_buffer(bytes) != OK and img.load_webp_from_buffer(bytes) != OK:
		Global.clear_visible("Could not decode image.", ["OK"])
		return
	pending_image = img
	download_path = path
	download_dir = null
	Global.clear_visible("Use this image?", ["Yes", "No"])
	image_pending = true
	await get_tree().create_timer(0.3).timeout
	Global.img_texture_override = ImageTexture.create_from_image(img)
	Global.refresh_art()

func show_image(path=Global.get_image_path(Global.special_item)):
	pending_image = Image.new()
	pending_image.load(path)

	var image_texture = ImageTexture.new()
	image_texture.set_image(pending_image)
	Global.img_texture_override = image_texture
	Global.refresh_art()

func get_normalized_art():
	var zip_reader = ZIPReader.new()
	var zip_path = Global.root_path + "/Imgs/IMAGES.zip"
	var error = zip_reader.open(zip_path)
	if error != OK:
		Global.clear_visible("Failed to open image pack.", ["Place pack at", zip_path])
		print("Failed to open image ZIP: " + error_string(error))
		return
	var normalized = "/" + Global.special_item.system + "/" + Global.normalize_regex.sub(Global.special_item.clean.to_lower(), "", true) + ".png"
	print("Looking for " + Global.special_item.clean + " in image pack at " + normalized)
	var zip_file := zip_reader.read_file(normalized)
	if zip_file.is_empty():
		var path = download_dir_path + "/" + Global.special_item.clean + ".png"
		var image_file = FileAccess.open(path, FileAccess.WRITE)
		image_file.store_buffer(zip_file)
		print("Copied " + normalized + " to " + path)
		access_downloaded_art()
	else:
		Global.clear_visible("Failed to find image in pack.")
		print("Failed to find image in pack.")
		return

func access_downloaded_art():
	pending_cover_download = false
	download_dir = DirAccess.open(download_dir_path)
	if download_dir != null:
		var newest = null
		var newest_time = -1
		for file in download_dir.get_files():
			if file in current_downloaded_list:
				continue
			var modtime = FileAccess.get_modified_time(download_dir.get_current_dir() + "/" + file)
			if modtime > newest_time:
				newest_time = modtime
				newest = file
		if newest == null:
			Global.clear_visible("No image found.")
			print("Failed to find files in download dir")
			return
		download_path = download_dir.get_current_dir() + "/" + newest

		show_image(download_path)
		Global.clear_visible("Use this image?", ["Yes", "No"])
		image_pending = true
		return
	else:
		Global.clear_visible("Failure", ["Failed to access downloaded art location."])

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_RESUMED and pending_cover_download:
		access_downloaded_art()

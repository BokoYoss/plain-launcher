extends component

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")
var launcher

var pending_cover_download = false
var pending_cover_file = false
#var pending_image_sprite = null
var pending_image = null
var download_path = null
var download_dir = null

var chosen_image_file = null

var system_settings = null
var system_settings_options = null
var settings_screen = false
var pending_setting = null

const download_dir_path = "/storage/emulated/0/Download"

var current_downloaded_list = []

var image_pending = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if Global.special_item == null:
		return
	#pending_image_sprite = Sprite2D.new()
	#add_child(pending_image_sprite)
	#pending_image_sprite.position = Vector2(Global.window_width * 0.75, Global.window_height / 2.0)
	Global.populate_filter = Callable(self, "filter_item")
	$Path.bbcode_text = "[b]Path:[/b] " + Global.special_item.absolute_path + "\n[b]Image:[/b] " + Global.get_image_path(Global.special_item)
	$Path.modulate = Global.get_setting(Global.CFG_FG_COLOR)
	$Path.position.y = Global.window_height - 64
	$Path.position.x = Global.left_bound
	$Path.size.x = Global.window_width
	$Path.size.y = 128
	$Path.set("theme_override_font_sizes/font_size", 16)
	$Path.add_theme_font_override("font", Global.font)
	AndroidInterface.connect("configured_storage", get_storage_selection)
	AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)
	populate_content()

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
		settings.append_array(system_settings.keys())
		settings.append("RESTORE DEFAULTS")
	#settings.append("Look for cover art automatically")
	if Global.special_item.system == "ANDROID":
		settings.append("Open app settings")
	settings.append("Look for cover art on Google")
	settings.append("Look for cover art on DuckDuckGo")
	settings.append("Look for cover art on TGDB")
	settings.append("Look for cover art on Launchbox")
	settings.append("Look for cover art on SteamGridDB")
	Global.clear_visible("Options - " + Global.special_item.clean, settings)
	show_image()
	Global.refresh_art()

func refresh_disk_settings():
	if system_settings == null:
		system_settings = Global.get_system_settings()

func write_settings_to_disk():
	var settings_path = Global.root_path  + Global.PATH_CONFIG + Global.subscreen
	if !Global.special_item.is_dir:
		settings_path = settings_path + "/" + Global.special_item.clean + ".json"
	else:
		settings_path = settings_path + "/config.json"
	if FileAccess.file_exists(settings_path):
		var settings_dir = DirAccess.open(settings_path.get_base_dir())
		print("DELETE SETTINGS at " + settings_path)
		settings_dir.remove_absolute(settings_path) # we need to delete in order to safely overwrite
	if system_settings == null or system_settings.is_empty():
		return
	print("STORE SETTINGS " + str(system_settings) + " to " + settings_path)
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)
	var string_settings = JSON.stringify(system_settings, "    ")
	print("Saving " + Global.subscreen + " settings: " + string_settings)
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
			print("Copy success, deleting file at " + download_path)
			download_dir.remove_absolute(download_path)

func game_settings_match_default():
	var systemwide = Global.get_systemwide_settings(Global.special_item.system)
	for key in systemwide.keys():
		if system_settings.get(key, null) != systemwide.get(key):
			print("FOUND CUSTOM SETTING FOR " + key + " GAME: " + str(system_settings.get(key, null)) + " SYSTEM: " + systemwide.get(key))
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
			Global.toggle_favorite()
		elif selected == "additional game paths":
			Global.go_to("path_adder")
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
		elif "cover art" in selected:
			pending_cover_download = true
			if download_dir == null:
				download_dir = DirAccess.open(download_dir_path)
			if download_dir != null:
				# get the list of files currently downloaded so we can find new ones
				current_downloaded_list = download_dir.get_files()

			var source = selected.replace("look for cover art on ", "")
			AndroidInterface.look_for_art(Global.special_item.clean, Global.special_item.system, source)
		elif selected == "extensions":
			Global.go_to("extension_selector")
			return
		elif "restore defaults" in selected:
			system_settings = null
			write_settings_to_disk()
			Global.clear_visible("Options restored.", ["OK"])
			return
		elif pending_setting == null:
			selected = selected.to_upper()
			var current_value = system_settings.get(selected)
			print("CURRENT SETTING KEY: " + selected + " VALUE: " + system_settings.get(selected))
			var display_options = []
			system_settings_options = Global.get_system_settings_options()
			if system_settings_options == null:
				print("Options not found")
				return
			if system_settings_options != null and system_settings_options.has(selected):
				display_options = system_settings_options.has(selected)
				print(display_options)
			pending_setting = selected
			Global.clear_visible(Global.special_item.clean + " " + pending_setting, system_settings_options.get(selected, []))
			for i in range(0, system_settings_options.get(selected, []).size()):
				# highlight current options
				var suboption = Global.option_list[i]
				if suboption.filename == current_value:
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
		if Global.previous_screen == "android_apps":
			Global.go_to("android_apps")
		elif is_system:
			Global.go_to_main()
		else:
			Global.go_to("game_browser")
		return

func show_image(path=Global.get_image_path(Global.special_item)):
	pending_image = Image.new()
	pending_image.load(path)

	var image_texture = ImageTexture.new()
	image_texture.set_image(pending_image)
	Global.img_texture_override = image_texture
	Global.refresh_art()
	#pending_image_sprite.texture = image_texture
	#pending_image_sprite.visible = true
	#var scale_ratio_x = (Global.window_width * 0.5) / pending_image_sprite.texture.get_size().x
	#var scale_ratio_y = (Global.window_height * 0.8) / pending_image_sprite.texture.get_size().y
	#var scale_ratio = min(scale_ratio_x, scale_ratio_y)
	#pending_image_sprite.scale = Vector2(scale_ratio, scale_ratio)

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

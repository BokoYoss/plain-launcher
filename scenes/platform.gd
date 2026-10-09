extends Node2D

var _plugin_name = "PlainLauncherPlugin"
var _android_plugin
var _on_storage_selected = Callable()
var _on_storage_failure = Callable()
var _on_text_input = Callable()

func _ready():
	if Engine.has_singleton(_plugin_name):
		_android_plugin = Engine.get_singleton(_plugin_name)
		_android_plugin.connect("configure_storage_location", storage_selection)
		_android_plugin.connect("image_downloaded", image_downloaded)
		_android_plugin.connect("failure_to_launch", failed_to_launch)
		_android_plugin.connect("text_input_complete", _on_text_input_complete)
	else:
		printerr("Couldn't find plugin " + _plugin_name)

signal got_image(path)
signal failure_to_launch(message)

static func tags() -> Array:
	var chosen = OS.get_environment("PLAIN_LAUNCHER_PLATFORM").to_lower()
	if chosen != "":
		return [chosen]
	var result = [OS.get_name().to_lower()]
	if OS.get_environment("SteamDeck") == "1" or (FileAccess.file_exists("/etc/os-release") and FileAccess.get_file_as_string("/etc/os-release").contains("ID=steamos")):
		result.append("steamdeck")
	return result

static func is_desktop_build() -> bool:
	return OS.get_name() in ["Linux", "Windows", "macOS"] and not OS.has_feature("editor")

static func home_dir() -> String:
	var home = OS.get_environment("HOME")
	return home if home != "" else OS.get_environment("USERPROFILE")

static func loading_screen_override() -> String:
	return OS.get_environment("PLAIN_LAUNCHER_OVERRIDE")

static func loading_screen_on() -> bool:
	return not FileAccess.file_exists(loading_screen_override())

static func set_loading_screen(on: bool):
	var path = loading_screen_override()
	if path == "":
		return
	if on:
		DirAccess.remove_absolute(path)
		return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("[application]\n\nboot_splash/show_image.portmaster=false\n")

static func uses_xbox_layout() -> bool:
	return is_desktop_build() and not "portmaster" in tags()

func is_android() -> bool:
	return _android_plugin != null

func has_web_art() -> bool:
	return _android_plugin != null

func has_native_dialogs() -> bool:
	return not "portmaster" in tags() and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)

func has_file_picker() -> bool:
	return _android_plugin != null or has_native_dialogs()

func open_url(url: String):
	if _android_plugin != null:
		launch_intent(JSON.stringify({"action": "android.intent.action.VIEW", "data": url}))
	else:
		OS.shell_open(url)

func _desktop_dialog(title: String, mode: DisplayServer.FileDialogMode, filters: PackedStringArray, on_path: Callable, on_cancel: Callable):
	if not has_native_dialogs():
		on_cancel.call()
		return
	DisplayServer.file_dialog_show(title, home_dir(), "", false, mode, filters, func(status: bool, paths: PackedStringArray, _filter: int):
		if status and not paths.is_empty():
			on_path.call(paths[0])
		else:
			on_cancel.call())

func failed_to_launch(message):
	if Global.pending_game != "":
		Global.show_launch_failure(str(message))

func image_downloaded(path):
	print("IMAGE DOWNLOADED: " + path)
	emit_signal("got_image", path)

func storage_selection(selection):
	# Do some cleanup of Android's URIs- this is probably brittle
	var storage_path
	if selection == null or selection == "" or selection == "NOT_FOUND" or selection == "FAILURE":
		_finish_storage_request(_on_storage_failure, selection)
		return
	if selection.begins_with("/mnt"):
		storage_path = selection.replace("/mnt/media_rw", "/storage")
	elif selection.begins_with("/tree") or selection.begins_with("/document"):
		# They chose an internal path
		storage_path = selection.replace("/tree/primary:", "/storage/emulated/0/").replace("/document/primary:", "/storage/emulated/0/").replace("/document/", "/storage/").replace("/tree/", "/storage/")
	else:
		# Removable card- extract the card path
		var split_path = selection.split(":")
		var card_path = split_path[0].replace("/tree/", "").replace("/storage/", "")
		var external_path = ":".join(split_path.slice(1, split_path.size()))
		storage_path = "/storage/" + card_path + "/" + external_path
	_finish_storage_request(_on_storage_selected, storage_path)

func _finish_storage_request(callback: Callable, value):
	_on_storage_selected = Callable()
	_on_storage_failure = Callable()
	if callback.is_valid():
		callback.call(value)

func request_storage(on_selected: Callable, on_failure: Callable):
	_on_storage_selected = on_selected
	_on_storage_failure = on_failure

func choose_storage_directory(on_selected: Callable, on_failure: Callable):
	if _android_plugin == null:
		_desktop_dialog("Choose a folder for Plain Launcher", DisplayServer.FILE_DIALOG_MODE_OPEN_DIR, PackedStringArray(), on_selected, func(): on_failure.call("NOT_FOUND"))
		return
	print("Opening storage dialogue..")
	request_storage(on_selected, on_failure)
	_android_plugin.chooseStorageDirectory()

func create_internal_storage(on_selected: Callable, on_failure: Callable):
	if _android_plugin == null:
		on_selected.call(home_dir())
		return
	print("Creating internal storage..")
	request_storage(on_selected, on_failure)
	_android_plugin.createStorage("internal")

func create_external_storage(on_selected: Callable, on_failure: Callable):
	if _android_plugin == null:
		on_failure.call("NOT_FOUND")
		return
	print("Creating external storage..")
	request_storage(on_selected, on_failure)
	_android_plugin.createStorage("external")

func has_file_permissions():
	if _android_plugin == null:
		return true
	var has_permissions = _android_plugin.hasFilePermissions()
	if !has_permissions:
		print("Missing file permissions")
	return has_permissions

func request_permissions():
	if _android_plugin == null:
		return
	print("Requesting permissions..")
	_android_plugin.requestFilePermissions()

func launch_intent(serialized_intent: String):
	if _android_plugin == null:
		return "Android intents only work on Android"
	Global.store_positions_files()
	print("Trying to launch [intent]:" + serialized_intent)
	return _android_plugin.launchIntent(serialized_intent)

func look_for_art_web(game: String, system: String, source: String):
	if _android_plugin == null:
		return null
	print("Opening in-app browser for " + game + " (" + system + ") on " + source)
	return _android_plugin.launchWebImagePicker(game, system, source)

func look_for_art(game: String, system: String, source: String = "google"):
	if _android_plugin == null:
		return null
	print("Looking for art for " + Global.ALIAS_MAP.get(game, game) + " (" + system + ") on " + source)
	return _android_plugin.launchBrowserForDownload(Global.ALIAS_MAP.get(game, game).split("[")[0], system, source.to_lower())

func get_app_list():
	if _android_plugin == null:
		return {}
	return JSON.parse_string(_android_plugin.getInstalledAppList())

func launch_package(package_name) -> String:
	if _android_plugin == null:
		return "Android apps only work on Android"
	Global.store_positions_files()
	print("Trying to launch package " + str(package_name))
	var result = _android_plugin.launchPackage(package_name)
	return "" if result == null else result

func app_settings(package_name):
	if _android_plugin == null:
		return
	Global.store_positions_files()
	print("Opening settings for " + str(package_name))
	_android_plugin.openAppSpecificSettings(package_name)

func has_text_input() -> bool:
	return _android_plugin != null

func show_text_input(prompt: String, current_value: String, is_password: bool, on_complete: Callable):
	if _android_plugin == null:
		return
	_on_text_input = on_complete
	_android_plugin.showTextInput(prompt, current_value, is_password)

func _on_text_input_complete(text: String):
	var callback = _on_text_input
	_on_text_input = Callable()
	if callback.is_valid():
		callback.call(text)

func choose_program(on_path: Callable):
	var filters = PackedStringArray(["*.exe, *.bat, *.cmd ; Programs"]) if OS.get_name() == "Windows" else PackedStringArray()
	_desktop_dialog("Choose the emulator", DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, on_path, func(): pass)

func choose_file():
	if _android_plugin == null:
		_desktop_dialog("Choose an image", DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]), func(path): emit_signal("got_image", path), func(): pass)
		return
	_android_plugin.chooseFile()

func get_external_storage_path():
	if _android_plugin == null:
		return null
	return _android_plugin.pathToRemovableStorage()

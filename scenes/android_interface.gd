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
	print("Opening storage dialogue..")
	request_storage(on_selected, on_failure)
	_android_plugin.chooseStorageDirectory()

func create_internal_storage(on_selected: Callable, on_failure: Callable):
	print("Creating internal storage..")
	request_storage(on_selected, on_failure)
	_android_plugin.createStorage("internal")

func create_external_storage(on_selected: Callable, on_failure: Callable):
	print("Creating external storage..")
	request_storage(on_selected, on_failure)
	_android_plugin.createStorage("external")

func has_file_permissions():
	var has_permissions = _android_plugin.hasFilePermissions()
	if !has_permissions:
		print("Missing file permissions")
	return has_permissions

func request_permissions():
	print("Requesting permissions..")
	_android_plugin.requestFilePermissions()

func launch_intent(serialized_intent: String):
	Global.store_positions_files()
	print("Trying to launch [intent]:" + serialized_intent)
	return _android_plugin.launchIntent(serialized_intent)

func look_for_art_web(game: String, system: String, source: String):
	print("Opening in-app browser for " + game + " (" + system + ") on " + source)
	return _android_plugin.launchWebImagePicker(game, system, source)

func look_for_art(game: String, system: String, source: String = "google"):
	print("Looking for art for " + Global.ALIAS_MAP.get(game, game) + " (" + system + ") on " + source)
	return _android_plugin.launchBrowserForDownload(Global.ALIAS_MAP.get(game, game).split("[")[0], system, source.to_lower())

func get_app_list():
	return JSON.parse_string(_android_plugin.getInstalledAppList())

func launch_package(package_name) -> String:
	Global.store_positions_files()
	print("Trying to launch package " + str(package_name))
	var result = _android_plugin.launchPackage(package_name)
	return "" if result == null else result

func app_settings(package_name):
	Global.store_positions_files()
	print("Opening settings for " + str(package_name))
	_android_plugin.openAppSpecificSettings(package_name)

func show_text_input(prompt: String, current_value: String, is_password: bool, on_complete: Callable):
	_on_text_input = on_complete
	_android_plugin.showTextInput(prompt, current_value, is_password)

func _on_text_input_complete(text: String):
	var callback = _on_text_input
	_on_text_input = Callable()
	if callback.is_valid():
		callback.call(text)

func choose_file():
	_android_plugin.chooseFile()

func get_external_storage_path():
	return _android_plugin.pathToRemovableStorage()

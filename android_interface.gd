extends Node2D

var _plugin_name = "PlainLauncherPlugin"
var _android_plugin

func _ready():
	if Engine.has_singleton(_plugin_name):
		_android_plugin = Engine.get_singleton(_plugin_name)
		_android_plugin.connect("configure_storage_location", storage_selection)
		_android_plugin.connect("image_downloaded", image_downloaded)
	else:
		printerr("Couldn't find plugin " + _plugin_name)

signal configured_storage(selection)
signal configure_storage_failure(message)
signal got_image(path)

func image_downloaded(path):
	print("IMAGE DOWNLOADED NOWWWWW " + path)

func storage_selection(selection: String):
	# Do some cleanup of Android's URIs- this is probably brittle
	var storage_path
	if selection == "NOT_FOUND":
		emit_signal("configure_storage_failure", selection)
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
	emit_signal("configured_storage", storage_path)

func choose_storage_directory():
	print("Opening storage dialogue..")
	_android_plugin.chooseStorageDirectory()

func create_internal_storage():
	print("Creating internal storage..")
	_android_plugin.createStorage("internal")

func create_external_storage():
	print("Creating external storage..")
	_android_plugin.createStorage("external")

func launch_intent(serialized_intent: String):
	print("Trying to launch [intent]:" + serialized_intent)
	return _android_plugin.launchIntent(serialized_intent)

func launch_default_app(category: String):
	return _android_plugin.launchDefaultApp(category)

func look_for_art(game: String, system: String):
	print("Looking for art for " + game + " (" + system + ")")
	return _android_plugin.launchBrowserForDownload(game, system)

func get_app_list():
	return JSON.parse_string(_android_plugin.getInstalledAppList())

func launch_package(package_name):
	print("Trying to launch package " + str(package_name))
	_android_plugin.launchPackage(package_name)

func choose_file():
	_android_plugin.chooseFile()

func get_external_storage_path():
	return _android_plugin.pathToRemovableStorage()

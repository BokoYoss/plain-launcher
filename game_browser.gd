extends component

var current_dir: DirAccess = null

var previous_selection = -1

var launcher = null

var system_settings = null

var ANDROID_LAUNCHER = preload("res://launcher_android.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	#populate_favorites()
	Global.fade.modulate.a = 1.0
	Global.populate_filter = Callable(self, "filter_item")

	populate_content()
	if OS.get_name() == "Android":
		launcher = ANDROID_LAUNCHER.instantiate()
		add_child.call_deferred(launcher)

func filter_item(item):
	if system_settings == null:
		system_settings = Global.get_system_settings()
	if system_settings == null:
		return false
	if system_settings.get("EXTENSIONS") == null:
		return false
	return item.filename.get_extension() not in system_settings.get("EXTENSIONS")

func populate_content(msg_override=null):
	print("GAMES BROWSER " + Global.subscreen)

	Global.clear_visible(Global.subscreen)

	var paths = Global.get_additional_paths()
	var system_dir = Global.root_path + "/" + Global.PATH_GAMES + "/" + Global.subscreen
	if paths == null:
		paths = []
	paths.append(system_dir)
	Global.refresh_alias(Global.subscreen)
	Global.list_multiple_paths_combined(paths)

	Global.show_message(str(Global.option_list.size()) + " games found", true)
	Global.show_message("SELECT for " + Global.subscreen + " options")
	# TODO: Per-game options
	#Global.show_message("START for PER-GAME options")

	if msg_override != null:
		Global.show_message(msg_override, true)
	Global.refresh_art()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()

		var selected = Global.get_selected()
		var game_path = selected.absolute_path
		if Global.get_selected().favorite_dir:
			# get the system in question from the path
			game_path = FileAccess.get_file_as_string(selected.absolute_path)

			#var system_in_question = game_path.replace(Global.root_path + Global.PATH_GAMES, "").split("/")[0]
			var system_in_question = selected.system
			print("Using FAVORITES launch with " + system_in_question + " path: " + game_path)

			if system_in_question == "ANDROID" or system_in_question == "EMULATORS":
				AndroidInterface.launch_package(game_path)
				return

		# TODO add game-specific settings?
		var system_settings = Global.get_system_settings(selected.system)
		print("Launching [game] " + game_path + " with [settings] " + str(system_settings))
		var launch_message = launcher.launch_with_settings(system_settings, game_path)
		Global.show_message(launch_message, true)
	if Global.back_pressed():
		Global.go_to("system_browser")
		return
	if Input.is_action_just_pressed("start"):
		if Global.get_selected().clean == "":
			return
		Global.store_position()
		Global.toggle_favorite()
		populate_content()

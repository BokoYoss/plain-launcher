extends component

var current_dir: DirAccess = null

var previous_selection = -1

var launcher = null

var system_settings = null
var shoulder_held_time = -1
var shoulder_held_dir = 0

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.fade.modulate.a = 1.0
	if Global.subscreen != "RECENT":
		Global.populate_filter = Callable(self, "filter_item")

	populate_content()
	if OS.get_name() == "Android":
		launcher = ANDROID_LAUNCHER.instantiate()
		add_child.call_deferred(launcher)

	Global.alt_art_path = Global.get_additional_art_path()
	print("got alt art path " + Global.alt_art_path)

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

	if Global.subscreen == "RECENT":
		populate_recent()
		return

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

	if msg_override != null:
		Global.show_message(msg_override, true)

	Global.refresh_art()

func populate_recent():
	Global.clear_visible("RECENT")
	var recent = Global.get_recent_list()
	for entry in recent:
		var opt = option.new()
		opt.clean = entry.get("name", "")
		opt.filename = entry.get("path", "").get_file()
		opt.absolute_path = entry.get("path", "")
		opt.system = entry.get("system", "")
		Global.option_list.append(opt)
	Global.set_up_slots()
	Global.restore_position()
	Global.highlight_selection()
	Global.show_message(str(Global.option_list.size()) + " recently played", true)
	Global.refresh_art()

func jump_to_letter(direction: int):
	var list = Global.option_list
	if list.size() == 0:
		return
	var current = Global.option_selection
	var current_letter = list[current].clean.to_lower().left(1)
	var i = current + direction
	while i >= 0 and i < list.size():
		if list[i].clean.to_lower().left(1) != current_letter:
			if direction == 1:
				Global.option_selection = i
				Global.scroll_offset = i
			else:
				# find the start of this new letter group
				var group_letter = list[i].clean.to_lower().left(1)
				while i > 0 and list[i - 1].clean.to_lower().left(1) == group_letter:
					i -= 1
				Global.option_selection = i
				Global.scroll_offset = i
			Global.show_options(Global.scroll_offset)
			Global.highlight_selection()
			Global.refresh_art()
			return
		i += direction

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()

		var selected = Global.get_selected()
		if selected.absolute_path == "":
			return
		var game_path = selected.absolute_path
		if Global.get_selected().favorite_dir:
			game_path = FileAccess.get_file_as_string(selected.absolute_path)

			var system_in_question = selected.system
			print("Using FAVORITES launch with " + system_in_question + " path: " + game_path)

			if system_in_question == "ANDROID" or system_in_question == "EMULATORS":
				AndroidInterface.launch_package(game_path)
				return

		var system_settings = Global.get_system_settings(selected.system)
		print("Launching [game] " + game_path + " with [settings] " + str(system_settings))
		var launch_message: String = launcher.launch_with_settings(system_settings, game_path)
		if launch_message != "":
			Global.failure_message = launch_message
			Navigator.go_to("failure_screen")
		else:
			Global.log_recent(game_path, selected.system, selected.clean)
	if Input.is_action_just_pressed("shoulder_r"):
		jump_to_letter(1)
		shoulder_held_time = Time.get_ticks_msec() + 500
		shoulder_held_dir = 1
	elif Input.is_action_just_pressed("shoulder_l"):
		jump_to_letter(-1)
		shoulder_held_time = Time.get_ticks_msec() + 500
		shoulder_held_dir = -1
	elif shoulder_held_dir != 0 and Input.is_action_pressed("shoulder_r" if shoulder_held_dir == 1 else "shoulder_l"):
		if Time.get_ticks_msec() - shoulder_held_time > 200:
			jump_to_letter(shoulder_held_dir)
			shoulder_held_time = Time.get_ticks_msec()
	else:
		shoulder_held_dir = 0
	if Global.back_pressed():
		Navigator.go_to("system_browser")
		return
	if Input.is_action_just_pressed("start"):
		if Global.get_selected().clean == "":
			return
		Global.store_position()
		Global.toggle_favorite()
		populate_content()

extends Screen

var current_dir: DirAccess = null

var previous_selection = -1

var launcher = null

var system_settings = null
var shoulder_held_time = -1
var shoulder_held_dir = 0

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.no_alias = false
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

func populate_favorites():
	Global.clear_visible("FAVORITES")
	for entry in Global.get_favorites_entries():
		var opt = option.new()
		opt.clean = entry.get("name", "")
		opt.filename = entry.get("filename", "")
		opt.absolute_path = entry.get("path", "")
		opt.system = entry.get("system", "")
		opt.favorite_dir = true
		Global.option_list.append(opt)
	Global.set_up_slots()
	Global.restore_position()
	Global.highlight_selection()
	Global.refresh_art()

func populate_content(msg_override=null):
	print("GAMES BROWSER " + Global.subscreen)

	if Global.subscreen == "RECENT":
		populate_recent()
		return

	if Global.subscreen == "FAVORITES":
		populate_favorites()
		return

	Global.clear_visible(Global.subscreen)

	var paths = Global.get_additional_paths()
	var system_dir = Global.root_path + "/" + Global.PATH_GAMES + "/" + Global.subscreen
	if paths == null:
		paths = []
	paths.append(system_dir)
	Global.refresh_alias(Global.subscreen)
	Global.list_multiple_paths_combined(paths)

	if Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST):
		var favs = Global.option_list.filter(func(o): return Global.favorites_list.has(o.absolute_path))
		var others = Global.option_list.filter(func(o): return not Global.favorites_list.has(o.absolute_path))
		Global.option_list = favs + others
		Global.restore_position()
		Global.highlight_selection()

	#Global.show_message(str(Global.option_list.size()) + " games found", true)
	#Global.show_message("SELECT for " + Global.subscreen + " options")

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
	#Global.show_message(str(Global.option_list.size()) + " recently played", true)
	Global.refresh_art()

func _on_resume():
	Global.no_alias = false
	if Global.subscreen == "FAVORITES":
		populate_favorites()
		return
	if Global.subscreen != "RECENT":
		Global.populate_filter = Callable(self, "filter_item")
	Global.set_up_slots()
	Global.show_options(Global.scroll_offset)
	Global.highlight_selection()
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
			var system_in_question = selected.system
			print("Using FAVORITES launch with " + system_in_question + " path: " + game_path)

			if system_in_question == "ANDROID" or system_in_question == "EMULATORS":
				Global.log_recent(game_path, system_in_question, selected.clean)
				AndroidInterface.launch_package(game_path)
				return

		var system_settings = Global.get_system_settings(selected.system)
		print("Launching [game] " + game_path + " with [settings] " + str(system_settings))
		var launch_message: String = launcher.launch_with_settings(system_settings, game_path)
		if launch_message != "":
			Global.failure_message = launch_message
			Navigator.push("failure_screen")
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
		Navigator.pop()
		return
	if Input.is_action_just_pressed("start"):
		if Global.get_selected().clean == "":
			return
		Global.store_position()
		Global.toggle_favorite(Global.get_selected())
		populate_content()

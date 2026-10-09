extends Screen

const LetterScroller = preload("res://scenes/letter_scroller.gd")

var current_dir: DirAccess = null

var previous_selection = -1

var system_settings = null
var shoulder_held_time = -1
var shoulder_held_dir = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.no_alias = false
	Global.fade.modulate.a = 1.0
	if Global.subscreen != "RECENT":
		Global.populate_filter = Callable(self, "filter_item")

	Global.set_prompts(prompts_for(Global.subscreen))
	Global.set_up_slots()
	populate_content()


static func prompts_for(screen: String) -> Array:
	return [["confirm", "Launch"], ["favorite", "Unfavorite" if screen == "FAVORITES" else "Favorite"], ["select", "Game Options"], ["start", "Settings"], ["trigger", "Jump"], ["back", "Back"]]

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

	var paths = Global.get_additional_paths(Global.subscreen)
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
	if Global.option_list.is_empty():
		return
	var groups = LetterScroller.letter_groups(Global.option_list.map(func(o): return Global.shown_name(o)))
	Global.jump_to_row(groups.starts[LetterScroller.wrapped_group(groups.starts, Global.option_selection, direction)])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.launching:
		return
	if Global.confirm_pressed():
		Global.store_position()

		var selected = Global.get_selected()
		if selected.absolute_path == "":
			return
		var settings = Global.get_system_settings(selected.system, selected.filename, selected.clean)
		var launcher_name = Global.launcher_label(str(settings.get("EMULATOR", "")), settings.get("CORE"))
		Global.launch_with_effect(func(): Launcher.launch_entry(selected.absolute_path, selected.system, selected.clean), Global.shown_title(selected), launcher_name)
	if Input.is_action_just_pressed("shoulder_r"):
		jump_to_letter(1)
		Global.letter_scroller.peek()
		shoulder_held_time = Time.get_ticks_msec() + 500
		shoulder_held_dir = 1
	elif Input.is_action_just_pressed("shoulder_l"):
		jump_to_letter(-1)
		Global.letter_scroller.peek()
		shoulder_held_time = Time.get_ticks_msec() + 500
		shoulder_held_dir = -1
	elif shoulder_held_dir != 0 and Input.is_action_pressed("shoulder_r" if shoulder_held_dir == 1 else "shoulder_l"):
		if Time.get_ticks_msec() - shoulder_held_time > 200:
			jump_to_letter(shoulder_held_dir)
			Global.letter_scroller.peek()
			shoulder_held_time = Time.get_ticks_msec()
	else:
		shoulder_held_dir = 0
	if Global.back_pressed():
		Navigator.pop()
		return
	if Input.is_action_just_pressed("start"):
		Global.open_settings()
		return
	if Input.is_action_just_pressed("favorite"):
		if Global.get_selected().clean == "":
			return
		var path = Global.get_selected().absolute_path
		var row = Global.option_selection
		var offset = Global.scroll_offset
		Global.toggle_favorite(Global.get_selected())
		if Settings.get_setting(Settings.CFG_SHOW_FAVS_FIRST) or Global.subscreen in ["FAVORITES", "RECENT"]:
			populate_content()
			Global.select_by_path(path, row, offset)

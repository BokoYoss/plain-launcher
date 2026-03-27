extends Screen

var current_dir: DirAccess = null

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.no_alias = false
	Global.fade.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)
	Global.fade.modulate.a = 1.0
	Global.subscreen = ""
	Global.alt_art_path = ""
	Global.title_can_be_blank = true
	populate_content()

func populate_content(msg_override=null):
	Global.clear_visible(Settings.get_setting(Settings.CFG_SYSTEM_TITLE))
	Global.set_up_slots()
	var system_dir: DirAccess = DirAccess.open(Global.root_path + "/" + Global.PATH_GAMES)

	Global.refresh_alias()
	Global.populate_favorites()
	var special = ["RECENT", "FAVORITES", "ANDROID"] # special directories placed at top
	Global.list_directory_contents(system_dir, true, special, false)
	#Global.show_message("SELECT for GLOBAL options", true)

	if msg_override != null:
		Global.show_message(msg_override, true)
	Global.refresh_art()

func _on_resume():
	Global.no_alias = false
	Global.title_can_be_blank = true
	Global.set_up_slots()
	Global.show_options(Global.scroll_offset)
	Global.highlight_selection()
	Global.refresh_art()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed() or Global.last_subscreen != "":
		Global.store_position()
		var selected_system = Global.get_selected().clean
		if Global.last_subscreen != "":
			selected_system = Global.last_subscreen
			Global.last_subscreen = ""
		if selected_system.to_lower() == "android":
			Global.subscreen = "ANDROID"
			Global.clear_visible("Loading..")
			Navigator.push("android_apps")
			return
		Global.special_item = Global.get_selected()
		Navigator.push("game_browser")
		Global.subscreen = selected_system
		return
	if Global.back_pressed():
		Navigator.push("settings")

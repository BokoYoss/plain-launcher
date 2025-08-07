extends component

var current_dir: DirAccess = null

# Called when the node enters the scene tree for the first time.
func _ready():

	Global.fade.modulate = Global.get_setting(Global.CFG_BG_COLOR)
	Global.fade.modulate.a = 1.0
	Global.subscreen = ""
	populate_content()

func populate_content(msg_override=null):
	Global.clear_visible("SYSTEMS")
	var system_dir: DirAccess = DirAccess.open(Global.root_path + "/" + Global.PATH_GAMES)

	Global.refresh_alias()
	Global.populate_favorites()
	var special = ["ANDROID", "FAVORITES"] # special directories placed at top
	Global.list_directory_contents(system_dir, true, special, false)
	Global.show_message("SELECT for GLOBAL options", true)

	if msg_override != null:
		Global.show_message(msg_override, true)
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
			Global.go_to("android_apps")
			return
		Global.special_item = Global.get_selected()
		Global.go_to("game_browser")
		Global.subscreen = selected_system
		return
	if Global.back_pressed():
		Global.go_to("settings")

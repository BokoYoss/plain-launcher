extends component

var launcher = null

var ANDROID_LAUNCHER = preload("res://launcher_android.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() != "Android":
		Global.go_to_main()
	launcher = ANDROID_LAUNCHER.instantiate()
	add_child.call_deferred(launcher)
	populate_content()


func populate_content(msg_override=null):
	var app_options = JSON.parse_string(FileAccess.get_file_as_string(Global.root_path + "/" + Global.PATH_CONFIG + "/COMMON/intents.json"))
	if app_options:
		Global.clear_visible("Emulators", app_options.keys())
	else:
		Global.go_to_main()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		var selected = Global.get_selected().filename.to_lower().replace(" ", "")
		print("PRESSED " + selected)
		var result = launcher.launch_with_settings({"EMULATOR": selected})
		Global.show_message(result, true)
	if Global.back_pressed():
		Global.back_to_previous_screen()

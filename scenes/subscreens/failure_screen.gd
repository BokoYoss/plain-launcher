extends component

var additional_paths = []
var pending_path = ""

var start_time = null

var launcher = null
var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	if OS.get_name() == "Android":
		populate_content()
		launcher = ANDROID_LAUNCHER.instantiate()
		add_child.call_deferred(launcher)
	else:
		Global.go_to_main()
	start_time = Time.get_ticks_msec()
	Global.refresh_art("")
	Global.can_scroll = false
	Global.option_selection = 2
	Global.highlight_selection(Global.option_selection)

func populate_content():
	if Global.pending_game != "":
		Global.clear_visible("Launch failed!", [Global.failure_message, "Check that", Global.pending_intent, "is installed and can read", Global.pending_game, "Or choose a different config", "by holding confirm", "on this system or game"])
	else:
		Global.clear_visible("Launch failed!", [Global.failure_message, "Check that", Global.pending_intent, "is installed.", "Or choose a different config", "by holding confirm", "on this system."])
	Global.pending_game = ""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if start_time != null and Time.get_ticks_msec() - start_time < 500:
		return
	if Global.confirm_pressed():
		if Global.option_selection == 2:
			Global.pending_game = ""
			Global.can_scroll = true
			launcher.launch_with_settings(Global.pending_launch)
	elif Global.back_pressed():
		Global.can_scroll = true
		Global.back_to_previous_screen()

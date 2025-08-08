extends component

# Called when the node enters the scene tree for the first time.

var SKIP_CONFIG = "CONFIRM_SET"

func _ready():
	if Global.get_setting(SKIP_CONFIG):
		Global.go_to("file_browser")
		return
	Global.clear_visible("PRESS CONFIRM BUTTON", ["OK"])
	Global.show_message("Confirm button can be changed later in settings", true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_setting(SKIP_CONFIG, true)
		Global.go_to("file_browser")
	if Global.back_pressed():
		Global.store_setting(SKIP_CONFIG, true)
		Global.swap_confirm_key()
		Global.go_to("file_browser")

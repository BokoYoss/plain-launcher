extends component

var SKIP_CONFIG = "CONFIRM_SET"

func _ready():
	if Settings.get_setting(SKIP_CONFIG):
		Navigator.go_to("file_browser")
		return
	Global.clear_visible("PRESS CONFIRM BUTTON", ["OK"])
	Global.show_message("Confirm button can be changed later in settings", true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Settings.store(SKIP_CONFIG, true)
		Navigator.go_to("file_browser")
	if Global.back_pressed():
		Settings.store(SKIP_CONFIG, true)
		Global.swap_confirm_key()
		Navigator.go_to("file_browser")

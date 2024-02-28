extends component

var launcher = null

# Called when the node enters the scene tree for the first time.
func _ready():
	populate_content()

func populate_content(msg_override=null):
	Global.clear_visible("Credits", ["Development", "Fonts", "System Images", "Color Palette"])

func populate_font_credits():
	var font_dir = DirAccess.open("res://launcher_configs/COMMON/fonts")
	var fonts = []
	font_dir.list_dir_begin()
	var subdir = font_dir.get_next()
	while subdir != "":
		fonts.append(subdir)
		subdir = font_dir.get_next()
	Global.clear_visible("Font credits", fonts)
	font_dir.list_dir_end()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		if Global.get_selected().clean == "Development":
			Global.clear_visible("Credits", ["Created with Godot 4", "https://godotengine.org/", "by Yossarian", "https://bokonon-yossarian.itch.io/"])
			return
		if Global.get_selected().clean == "Fonts":
			populate_font_credits()
			return
		if Global.get_selected().clean == "System Images":
			Global.clear_visible("System Images", ["All system photos by Evan Amos", "https://commons.wikimedia.org/wiki/User:Evan-Amos"])
			return
		if Global.title.text == "Font credits":
			Global.clear_visible(Global.get_selected().clean, FileAccess.get_file_as_string("res://launcher_configs/COMMON/fonts/" + Global.get_selected().clean + "/OFL.txt").split("\n"))
			return
		if Global.get_selected().clean == "Color Palette":
			Global.clear_visible("Color palette credits", ["'Duel' palette created by Arilyn", "https://lospec.com/palette-list/duel"])
			return
		if Global.get_selected().clean.begins_with("https"):
			AndroidInterface.launch_intent(JSON.stringify({"action": "android.intent.action.VIEW", "data": Global.get_selected().clean}))
			return
		Global.back_to_previous_screen()
	if Global.back_pressed():
		Global.store_position()
		if Global.title.text == "Font credits":
			populate_content()
			return
		Global.back_to_previous_screen()

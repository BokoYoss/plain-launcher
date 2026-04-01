extends Screen

var launcher = null

# Called when the node enters the scene tree for the first time.
func _ready():
	populate_content()

func populate_content(msg_override=null):
	Global.clear_visible("Credits", [
		option.with_callback("Development", func():
			Global.store_position()
			Global.clear_visible("Credits", ["Created with Godot 4", "https://godotengine.org/", "by Yossarian", "https://ko-fi.com/yossariano"])
		),
		option.with_callback("Fonts", func():
			Global.store_position()
			populate_font_credits()
		),
		option.with_callback("System Images", func():
			Global.store_position()
			Global.clear_visible("System Images", ["All system photos by Evan Amos", "https://commons.wikimedia.org/wiki/User:Evan-Amos"])
		),
		option.with_callback("Color Palette", func():
			Global.store_position()
			Global.clear_visible("Color palette credits", ["'Duel' palette created by Arilyn", "https://lospec.com/palette-list/duel"])
		),
	])

func populate_font_credits():
	var font_dir = DirAccess.open("res://launcher_configs/COMMON/fonts")
	var fonts = []
	font_dir.list_dir_begin()
	var subdir = font_dir.get_next()
	while subdir != "":
		var font_name = subdir
		fonts.append(option.with_callback(font_name, func():
			Global.store_position()
			Global.clear_visible(font_name, FileAccess.get_file_as_string("res://launcher_configs/COMMON/fonts/" + font_name + "/OFL.txt").split("\n"))
		))
		subdir = font_dir.get_next()
	font_dir.list_dir_end()
	Global.clear_visible("Font credits", fonts)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected()
		if selected.trigger(Actions.CONFIRM):
			return
		if selected.clean.begins_with("https"):
			AndroidInterface.launch_intent(JSON.stringify({"action": "android.intent.action.VIEW", "data": selected.clean}))
	if Global.back_pressed():
		Global.store_position()
		if Global.title.text == "Font credits":
			populate_content()
			return
		Navigator.pop()

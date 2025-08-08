extends component

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")
var launcher

var system_settings = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	var choice_path = Global.root_path + Global.PATH_CONFIG + Global.subscreen + "/choices.json"
	if Global.subscreen == "" or not FileAccess.file_exists(choice_path):
		print(choice_path)
		Global.go_to_main()
		return
	Global.post_draw_callback = Callable(self, "show_indicators")
	Global.on_leave_component = Callable(self, "store_settings")
	Global.no_alias = true
	refresh_extensions()

func refresh_extensions():
	var choice_path = Global.root_path + Global.PATH_CONFIG + Global.subscreen + "/choices.json"
	var choices = JSON.parse_string(FileAccess.get_file_as_string(choice_path))

	var valid_extensions = choices.get("EXTENSIONS")

	if system_settings.is_empty():
		system_settings = Global.get_system_settings()
	var selected_extensions = system_settings.get("EXTENSIONS")
	Global.clear_visible(Global.subscreen + " extensions", valid_extensions)
	show_indicators()

func show_indicators():
	if system_settings.is_empty():
		system_settings = Global.get_system_settings()
	if system_settings.is_empty():
		return
	var selected_extensions = system_settings.get("EXTENSIONS")
	for i in range(0, Global.visible_slots.size()):
		if i >= Global.option_list.size():
			break
		var opt: option = Global.option_list[Global.scroll_offset + i]
		Global.fav_indicators[i].visible = false
		if opt.clean in selected_extensions:
			Global.fav_indicators[i].visible = true

func store_settings():
	if system_settings.is_empty():
		system_settings = Global.get_system_settings()
	var settings_file = FileAccess.open(Global.root_path + Global.PATH_CONFIG + Global.subscreen + "/config.json", FileAccess.WRITE)
	settings_file.store_string(JSON.stringify(system_settings, "   "))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean.to_lower()
		if system_settings == null:
			Global.clear_visible("Error changing extension", ["OK"])
		elif system_settings.get("EXTENSIONS", []).has(selected):
			system_settings.get("EXTENSIONS").erase(selected)
		else:
			system_settings.get("EXTENSIONS").append(selected)
		refresh_extensions()
	if Global.back_pressed():
		store_settings()
		print("back")
		Global.go_to("special", "", true)
		return
	if Input.is_action_just_pressed("exit"):
		Global.go_to_main()

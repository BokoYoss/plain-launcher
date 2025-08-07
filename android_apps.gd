extends component

var launcher = null

var ANDROID_LAUNCHER = preload("res://launcher_android.tscn")

var app_list = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() != "Android":
		Global.go_to_main()
	launcher = ANDROID_LAUNCHER.instantiate()
	add_child.call_deferred(launcher)
	Global.subscreen = "ANDROID"
	Global.android_subscreen = "all"
	if Global.android_subscreen == "all":
		view_all()
		Global.restore_position()
	else:
		populate_content()

func view_all():
	Global.store_position()
	Global.android_subscreen = "all"
	populate_content()
	#Global.title.text = "All Android apps"
	Global.title.text = "Android"

func clean_options():
	var hidden = []
	for opt in Global.option_list:
		# For handling favorites
		if Global.android_subscreen != null:
			opt.absolute_path = app_list.get(opt.filename)
			opt.system = "ANDROID"
		else:
			opt.absolute_path = "ANDROID:" + opt.filename
		if Global.HIDDEN_LIST.get(opt.absolute_path, false) and !Global.show_hidden:
			hidden.append(opt)
	for hide in hidden:
		Global.option_list.erase(hide)
	for i in range(0, Global.visible_slots.size()):
		if i >= Global.option_list.size():
			Global.visible_slots[i].text = ""
	Global.show_options(Global.scroll_offset)
	Global.highlight_selection()

func populate_content(msg_override=null):
	if Global.android_subscreen == null:
		Global.clear_visible("Android", ["All", "Settings", "Browser", "Messaging", "Email", "Maps", "Calculator", "Calendar", "Market", "Files", "Gallery", "Emulators"])
		clean_options()
	else:
		app_list = AndroidInterface.get_app_list()
		var options = app_list.keys()
		options.sort()
	#	options.push_front("Settings")
		Global.clear_visible("ANDROID", options)
		clean_options()
	Global.refresh_art()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().filename.to_lower()
		if Global.android_subscreen == null:
			if selected == "settings":
				Global.store_position()
				var result = launcher.launch_action("android.settings.SETTINGS")
				Global.show_message(result, true)
				return
			elif selected == "emulators":
				Global.store_position()
				Global.subscreen = "EMULATORS"
				Global.go_to("emulator_picker")
				return
			elif selected == "files":
				Global.store_position()
				AndroidInterface.launch_package("com.android.documentsui")
				return
			elif selected == "gallery":
				Global.store_position()
				AndroidInterface.launch_package("com.android.gallery3d")
				return
			elif selected == "all":
				Global.setting_subscreen = "all_android"
				view_all()
				return
			elif Global.title.text == "Not found":
				Global.android_subscreen = null
				populate_content()
			else:
				Global.store_position()
				var result = AndroidInterface.launch_default_app("android.intent.category.APP_" + selected.to_upper())
				if result == "NOT_FOUND":
					Global.clear_visible("Not found", [Global.get_selected().filename + " app not found."])
				return
		else:
			selected = Global.get_selected().filename
			AndroidInterface.launch_package(app_list.get(selected))
	if Global.back_pressed():
		#if Global.android_subscreen != null or Global.title.text == "Not found":
			#Global.android_subscreen = null
			#populate_content()
			#return
		Global.go_to_main()
	if Input.is_action_just_pressed("start"):
		if Global.android_subscreen == null:
			return
		if Global.get_selected().clean == "":
			return
		var title = Global.title.text
		Global.store_position()
		Global.toggle_favorite()
		Global.title.text = title
		Global.restore_position()

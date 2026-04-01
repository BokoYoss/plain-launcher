extends Screen

var launcher = null

var ANDROID_LAUNCHER = preload("res://scenes/launcher_android.tscn")

var app_list = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() != "Android":
		Navigator.go_to_main()
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
	Global.title.text = "Android"

func clean_options():
	var hidden = []
	for opt in Global.option_list:
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
	Global.populate_favorites()
	Global.highlight_selection()

func _launch_category(category: String):
	Global.store_position()
	var result = AndroidInterface.launch_default_app("android.intent.category.APP_" + category.to_upper())
	if result == "NOT_FOUND":
		Global.clear_visible("Not found", [option.with_callback(category.capitalize() + " app not found.", populate_content)])

func populate_content(msg_override=null):
	if Global.android_subscreen == null:
		Global.clear_visible("Android", [
			option.with_callback("All", func(): Global.store_position(); view_all()),
			option.with_callback("Settings", func(): Global.store_position(); Global.show_message(launcher.launch_action("android.settings.SETTINGS"), true)),
			option.with_callback("Browser", func(): _launch_category("browser")),
			option.with_callback("Messaging", func(): _launch_category("messaging")),
			option.with_callback("Email", func(): _launch_category("email")),
			option.with_callback("Maps", func(): _launch_category("maps")),
			option.with_callback("Calculator", func(): _launch_category("calculator")),
			option.with_callback("Calendar", func(): _launch_category("calendar")),
			option.with_callback("Market", func(): _launch_category("market")),
			option.with_callback("Files", func(): Global.store_position(); AndroidInterface.launch_package("com.android.documentsui")),
			option.with_callback("Gallery", func(): Global.store_position(); AndroidInterface.launch_package("com.android.gallery3d")),
			option.with_callback("Emulators", func(): Global.store_position(); Global.subscreen = "EMULATORS"; Navigator.push("emulator_picker")),
		])
		clean_options()
	else:
		app_list = AndroidInterface.get_app_list()
		var options = app_list.keys()
		options.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
		Global.clear_visible("ANDROID", options)
		clean_options()
	Global.set_up_slots()
	Global.refresh_art()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected()
		if selected.trigger(Actions.CONFIRM):
			pass
		elif Global.android_subscreen != null:
			var package = app_list.get(selected.filename)
			Global.log_recent(package, "ANDROID", selected.clean)
			AndroidInterface.launch_package(package)
	if Global.back_pressed():
		Navigator.go_to_main()
	if Input.is_action_just_pressed("start"):
		if Global.android_subscreen == null:
			return
		if Global.get_selected().clean == "":
			return
		var title = Global.title.text
		Global.store_position()
		Global.toggle_favorite(Global.get_selected())
		Global.title.text = title
		Global.restore_position()

extends Screen

var app_list = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() != "Android":
		Navigator.go_to_main()
	Global.subscreen = "ANDROID"
	Global.set_prompts([["confirm", "Launch"], ["favorite", "Favorite"], ["select", "App Options"], ["start", "Settings"], ["back", "Back"]])
	populate_content()
	Global.title.text = "Android"
	Global.restore_position()

func clean_options():
	var hidden = []
	for opt in Global.option_list:
		opt.absolute_path = app_list.get(opt.filename)
		opt.system = "ANDROID"
		if Global.HIDDEN_LIST.get(opt.absolute_path, false) and !Global.show_hidden:
			hidden.append(opt)
	for hide in hidden:
		Global.option_list.erase(hide)
	for i in range(0, Global.visible_slots.size()):
		if i >= Global.option_list.size():
			Global.visible_slots[i].text = ""
	Global.populate_favorites()
	Global.highlight_selection()

func populate_content(msg_override=null):
	app_list = AndroidInterface.get_app_list()
	Global.migrate_android_art(app_list)
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
		Launcher.launch_entry(app_list.get(selected.filename, ""), "ANDROID", selected.clean)
	if Global.back_pressed():
		Navigator.go_to_main()
	if Input.is_action_just_pressed("start"):
		Global.open_settings()
		return
	if Input.is_action_just_pressed("favorite"):
		if Global.get_selected().clean == "":
			return
		var title = Global.title.text
		Global.store_position()
		Global.toggle_favorite(Global.get_selected())
		Global.title.text = title
		Global.restore_position()

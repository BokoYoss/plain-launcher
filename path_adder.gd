extends component

var current_dir: DirAccess = null

var additional_paths = []
var pending_path = ""

var start_time = null

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	if OS.get_name() == "Android":
		AndroidInterface.connect("configured_storage", get_storage_selection)
		AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)
		populate_content()
	else:
		Global.go_to_main()
	start_time = Time.get_ticks_msec()
	print(Global.special_item)

func get_storage_selection(string):
	print("Attempting to use " + string)
	pending_path = string.replace(" ", "").replace(":", "/")
	if DirAccess.open(pending_path) == null:
		Global.clear_visible("Sorry, unable to access that.", ["OK"])
		return
	Global.clear_visible("Use " + pending_path + "?", ["Yes", "No"])

func on_storage_config_failure(message):
	print("Failure when setting up storage")
	Global.clear_visible("Unable to access", ["OK"])

func populate_content():
	additional_paths = Global.get_additional_paths()
	
	var options = ["Add a path"]
	options.append_array(additional_paths)

	Global.clear_visible("Add game paths", options)

	Global.list_directory_contents(current_dir)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if start_time != null and Time.get_ticks_msec() - start_time < 500:
		return
	if Global.confirm_pressed():
		var selected = Global.get_selected().filename
		if selected == "Add a path":
			AndroidInterface.choose_storage_directory()
			return
		elif selected == "OK" or selected == "No" or selected == "Back":
			populate_content()
			return
		elif selected == "Yes":
			additional_paths.append(pending_path)
			Global.store_additional_paths(additional_paths)
			populate_content()
			return
		elif selected == "Remove":
			Global.remove_additional_path(pending_path)
			populate_content()
			return
		else:
			pending_path = selected
			Global.clear_visible(pending_path, ["Remove", "Back"])
			return
	elif Global.back_pressed():
		Global.back_to_previous_screen()

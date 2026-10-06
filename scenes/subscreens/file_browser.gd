extends Screen

const StorageSetup = preload("res://scenes/storage_setup.gd")

var current_dir: DirAccess = null

var external_card_path = null

var start_time = null

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() == "Android":
		storage_select()
	else:
		populate_files("/", true)
	start_time = Time.get_ticks_msec()

func request_permissions():
	Global.clear_visible("Permissions needed", ["Grant file permissions", "Please ensure file access is allowed."])

func get_storage_selection(string):
	var problem = StorageSetup.use_selection(string)
	if problem != "":
		storage_select(problem)
	else:
		Navigator.go_to_main()

func on_storage_config_failure(message):
	print("Failure when setting up storage")
	request_permissions()

func populate_files(root, dir_only=false):
	var new_dir = DirAccess.open(root)

	if not new_dir:
		return

	current_dir = new_dir

	#Global.show_message(current_dir.get_current_dir().replace("//", "/"), true)

	#Global.clear_visible("START to use current directory")

	Global.list_directory_contents(current_dir, true, [], true, false)

func set_up_root():
	if not StorageSetup.set_up_root(current_dir):
		return false
	Navigator.go_to_main()
	return true

func storage_select(title_override=null):
	Global.clear_visible("Select primary storage", ["Grant file permissions", "Use on-device storage", "Use removable storage", "Open storage selector"])
	if (title_override != null):
		Global.title.text = title_override
	Global.show_message("")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if start_time != null and Time.get_ticks_msec() - start_time < 500:
		return
	if Global.confirm_pressed():
		if Global.confirming:
			Global.confirming = false
			if Global.get_selected().clean.to_lower() == "no":
				storage_select()
			elif Global.get_selected().clean.to_lower() == "grant file permissions":
				AndroidInterface.request_permissions()
				storage_select()
			elif Global.get_selected().clean.to_lower() == "yes":
				if current_dir == null:
					storage_select("Failure during storage init.")
				else:
					if not set_up_root():
						storage_select("Failure during storage init.")
						return
					Global.clear_visible("Set up Plain Launcher directory.", ["OK"])
					#Global.show_message(str(current_dir.get_current_dir()).replace("//", "/"), true)
			elif Global.get_selected().clean.to_lower() == "ok":
				Navigator.go_to_main()
			elif "selector" in Global.get_selected().clean.to_lower():
				AndroidInterface.choose_storage_directory(get_storage_selection, on_storage_config_failure)
			elif "on-device" in Global.get_selected().clean.to_lower():
				Global.clear_visible("Configuring...")
				AndroidInterface.create_internal_storage(get_storage_selection, on_storage_config_failure)
			elif "removable" in Global.get_selected().clean.to_lower():
				Global.clear_visible("Configuring...")
				AndroidInterface.create_external_storage(get_storage_selection, on_storage_config_failure)
			return
		Global.store_position()
		var selected_dir = Global.get_selected().clean
		if current_dir != null and current_dir.dir_exists(selected_dir):
			populate_files(current_dir.get_current_dir() + "/" + selected_dir, true)
	elif Global.back_pressed():
		if Global.title.text.to_lower() == "select primary storage":
			Navigator.pop()
			return
		storage_select()
	elif Input.is_action_just_pressed("start"):
		if OS.get_name() != "Android":
			Global.store_position()
			current_dir = DirAccess.open(current_dir.get_current_dir() + "/PlainLauncher")

			Global.clear_visible("Create Plain Launcher directory?", ["Yes", "No"])
			#Global.show_message(str(current_dir.get_current_dir() + "/PlainLauncher/").replace("//", "/"), true)

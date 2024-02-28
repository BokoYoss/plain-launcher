extends component

var current_dir: DirAccess = null

var external_card_path = null

var start_time = null

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	if OS.get_name() == "Android":
		storage_select()
		AndroidInterface.connect("configured_storage", get_storage_selection)
		AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)
	else:
		populate_files("/", true)
	start_time = Time.get_ticks_msec()

func get_storage_selection(string):
	print("Attempting to use " + string)
	string = string.replace(" ", "")
	current_dir = DirAccess.open(string)
	if current_dir:
		if not set_up_root():
			storage_select("Failure during setup.")
	else:
		if "PlainLauncher" in string:
			string = string.replace("/PlainLauncher", "")
		current_dir = DirAccess.open(string)
		if current_dir == null:
			print("Failed to open " + string)
			if string.begins_with("/storage/"):
				string = string.replace("/storage/", "/mnt/media_rw/")
				current_dir = DirAccess.open(string)
				if current_dir == null:
					print("Failed to open " + string)
					string = string + "/PlainLauncher"
					current_dir = DirAccess.open(string)
					if current_dir == null:
						print("Failed to open " + string)
						storage_select("Missing permissions.")
						return
		var result = current_dir.make_dir_recursive("PlainLauncher")
		if result != 0:
			print("Failed to make dir in " + current_dir.get_current_dir())
			storage_select("Missing permissions.")
		else:
			current_dir = DirAccess.open(current_dir.get_current_dir() + "/PlainLauncher")
			if not set_up_root():
				storage_select("Failure during setup.")

func on_storage_config_failure(message):
	print("Failure when setting up storage")
	storage_select("Failed to set storage: " + message)

func populate_files(root, dir_only=false):
	var new_dir = DirAccess.open(root)

	if not new_dir:
		return

	current_dir = new_dir

	Global.show_message(current_dir.get_current_dir().replace("//", "/"), true)

	Global.clear_visible("START to use current directory")

	Global.list_directory_contents(current_dir)

func copy_builtin_contents(relative_dir):
	var config_dir = DirAccess.open("res://launcher_configs/" + relative_dir)
	config_dir.list_dir_begin()
	# For some reason, Godot exports these with .import, but they are the real files
	var config_file = config_dir.get_next()
	while config_file != "":
		# Copy built-in files to working directory
		if OS.get_name() == "Android" and config_file.get_extension() == "import":
			config_file = config_dir.get_next()
			continue
		var builtin = config_dir.get_current_dir() + "/" + config_file
		var dest = current_dir.get_current_dir() + Global.PATH_CONFIG + relative_dir + "/" + config_file
		if config_dir.dir_exists(config_file):
			current_dir.make_dir_recursive(dest)
			copy_builtin_contents(relative_dir + "/" + config_file)
		else:
			if FileAccess.file_exists(dest):
				current_dir.remove(relative_dir + "/" + config_file)
			print("Copying built-in config from " + builtin + " to " + dest)
			var builtin_contents = FileAccess.get_file_as_string(builtin)
			var dest_file = FileAccess.open(dest, FileAccess.WRITE)
			dest_file.store_string(builtin_contents)
			dest_file.close()
		config_file = config_dir.get_next()
	config_dir.list_dir_end()

func set_up_root():
	var game_sets = []
	var builtin_config_dir = DirAccess.open("res://launcher_configs/")
	builtin_config_dir.list_dir_begin()
	var system_name = builtin_config_dir.get_next()
	while system_name != "":
		game_sets.append(system_name)
		system_name = builtin_config_dir.get_next()
	if current_dir == null:
		print("Missing permissions to " + current_dir.get_current_dir())
		return false
	else:
		print("Able to access " + current_dir.get_current_dir())
	print("Setting up PlainLauncher directories in " + current_dir.get_current_dir())
	builtin_config_dir.list_dir_end()
	var mkdir_result
	print("Creating Games directory at " + current_dir.get_current_dir() + Global.PATH_GAMES)
	mkdir_result = current_dir.make_dir(Global.PATH_GAMES.replace("/", ""))
	if mkdir_result != 0 and mkdir_result != 32:
		print("Failed to make directory (error " + str(mkdir_result) + ") at " + current_dir.get_current_dir() + Global.PATH_GAMES)
		return false
	mkdir_result = current_dir.make_dir(Global.PATH_CONFIG.replace("/", ""))
	if mkdir_result != 0 and mkdir_result != 32:
		print("Failed to make directory (error " + str(mkdir_result) + ") at " + current_dir.get_current_dir() + Global.PATH_CONFIG)
		return false
	print("Creating Imgs directory at " + current_dir.get_current_dir() + Global.PATH_IMAGES)
	mkdir_result = current_dir.make_dir(Global.PATH_IMAGES.replace("/", ""))
	if mkdir_result != 0 and mkdir_result != 32:
		print("Failed to make directory (error " + str(mkdir_result) + ") at " + current_dir.get_current_dir() + Global.PATH_IMAGES)
		return false
	for game_set in game_sets:
		print("Configuring " + game_set + " directory..")
		if game_set.to_lower() != "common":
			# common is a special, config-only dir
			mkdir_result = current_dir.make_dir_recursive(current_dir.get_current_dir() + Global.PATH_GAMES + game_set)
			if mkdir_result != 0 and mkdir_result != 32:
				print("Failed to make directory (error " + str(mkdir_result) + ") at " + current_dir.get_current_dir() + Global.PATH_GAMES + game_set + " ERROR: " + str(mkdir_result))
				return false
		current_dir.make_dir_recursive(current_dir.get_current_dir() + Global.PATH_IMAGES + game_set)
		if mkdir_result != 0 and mkdir_result != 32:
			print("Failed to make directory (error " + str(mkdir_result) + ") at " + current_dir.get_current_dir() + Global.PATH_IMAGES  + game_set + " ERROR: " + str(mkdir_result))
			return false
		current_dir.make_dir_recursive(current_dir.get_current_dir() + Global.PATH_CONFIG + game_set)
		if mkdir_result != 0 and mkdir_result != 32:
			print("Failed to make directory (error " + str(mkdir_result) + ") at "+ current_dir.get_current_dir() + Global.PATH_CONFIG  + game_set + " ERROR: " + str(mkdir_result))
			return false
		copy_builtin_contents(game_set)

		var system_image_path = "res://launcher_configs/" + game_set + "/image.png"
		#var image = Image.new()
		var system_image = ResourceLoader.load(system_image_path, "png")
		var dest_image = current_dir.get_current_dir() + Global.PATH_IMAGES + game_set + ".png"
		if system_image == null or FileAccess.file_exists(dest_image):
			print("Missing art or art already exists, not overwriting")
			continue
		print("Copying image from " + system_image_path + " to " + dest_image)

		var result = system_image.get_image().save_png(dest_image)
		if result != 0:
			print("Failed to copy image at " + system_image_path)
		#config_dir.list_dir_begin()
		#var config_file = config_dir.get_next()
		#while config_file != "":
			## Copy built-in files to working directory
			#var builtin = "res://launcher_configs/" + game_set + "/" + config_file
			#if not FileAccess.file_exists(builtin):
				#print("Couldn't find file at " + builtin)
				#continue
			#var dest = current_dir.get_current_dir() + "/" + Global.PATH_CONFIG + "/" + game_set + "/" + config_file
			#if FileAccess.file_exists(dest):
				#current_dir.remove(Global.PATH_CONFIG + "/"  + game_set + "/" + config_file)
			#print("Copying built-in config from " + builtin + " to " + dest)
			#var builtin_contents = FileAccess.get_file_as_string(builtin)
			#var dest_file = FileAccess.open(dest, FileAccess.WRITE)
			#dest_file.store_string(builtin_contents)
			#dest_file.close()
#
			#config_file = config_dir.get_next()
		#config_dir.list_dir_end()
	Global.set_root_path(current_dir.get_current_dir())
	Global.go_to_main()
	Font
	return true

func storage_select(title_override=null):
	Global.clear_visible("Select primary storage", ["Use on-device storage", "Use removable storage", "Open storage selector"])
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
			elif Global.get_selected().clean.to_lower() == "yes":
				if current_dir == null:
					storage_select("Failure during storage init.")
				else:
					if not set_up_root():
						storage_select("Failure during storage init.")
						return
					Global.clear_visible("Set up Plain Launcher directory.", ["OK"])
					Global.show_message(str(current_dir.get_current_dir()).replace("//", "/"), true)
			elif Global.get_selected().clean.to_lower() == "ok":
				Global.go_to("system_browser")
			elif "selector" in Global.get_selected().clean.to_lower():
				AndroidInterface.choose_storage_directory()
			elif "on-device" in Global.get_selected().clean.to_lower():
				Global.clear_visible("Configuring...")
				AndroidInterface.create_internal_storage()
				#current_dir = DirAccess.open("/mnt/sdcard")
				#if current_dir:
					#var result = current_dir.make_dir("PlainLauncher")
					#if result == 0 or result == 32:
						#current_dir = DirAccess.open(current_dir.get_current_dir() + "/PlainLauncher/")
						#if not set_up_root():
							#Global.clear_visible("Failure during setup.", ["Try internal again", "Open storage selector"])
						#return
					#else:
						#print("Failed to make directory at /mnt/sdcard/PlainLauncher. Error: " + str(result))
						##Global.show_message(str(current_dir.get_current_dir() + "/PlainLauncher/").replace("//", "/"), true)
				#else:
					#print("Cannot access /mnt/sdcard/")
				#Global.clear_visible("Failure during setup.", ["Try internal again", "Open storage selector"])
				#Global.show_message("Check permissions", true)
			elif "removable" in Global.get_selected().clean.to_lower():
				Global.clear_visible("Configuring...")
				AndroidInterface.create_external_storage()
				#external_card_path = AndroidInterface.get_external_card_path()
				#if external_card_path:
					#print("Found external storage path at " + external_card_path)
					#var external_storage = DirAccess.open(external_card_path)
					#if external_storage:
						#print("Was able to open external storage at " + external_card_path)
						#current_dir = external_storage
						#Global.clear_visible("Create external storage directory?", ["YES", "NO"])
						#Global.show_message(str(current_dir.get_current_dir() + "/PlainLauncher/").replace("//", "/"), true)
					#else:
						#Global.clear_visible("Failed to access external", ["TRY INTERNAL", "TRY EXTERNAL AGAIN"])
						#Global.show_message("Check permissions", true)
				#else:
					#Global.clear_visible("Failed to access external storage.", ["TRY INTERNAL", "TRY EXTERNAL AGAIN"])
			return
		Global.store_position()
		var selected_dir = Global.get_selected().clean
		if current_dir != null and current_dir.dir_exists(selected_dir):
			populate_files(current_dir.get_current_dir() + "/" + selected_dir, true)
	elif Global.back_pressed():
		if (Global.title.text.to_lower() == "select storage"):
			Global.go_to_main()
			return
		storage_select()
	elif Input.is_action_just_pressed("start"):
		if OS.get_name() != "Android":
			Global.store_position()
			current_dir = DirAccess.open(current_dir.get_current_dir() + "/PlainLauncher")

			Global.clear_visible("Create Plain Launcher directory?", ["Yes", "No"])
			Global.show_message(str(current_dir.get_current_dir() + "/PlainLauncher/").replace("//", "/"), true)

extends RefCounted

static func open_selection(selection: String) -> DirAccess:
	var path = selection.replace(" ", "")
	var dir = DirAccess.open(path)
	if dir:
		return dir
	if "PlainLauncher" in path:
		path = path.replace("/PlainLauncher", "")
	dir = DirAccess.open(path)
	if dir == null and path.begins_with("/storage/"):
		path = path.replace("/storage/", "/mnt/media_rw/")
		dir = DirAccess.open(path)
		if dir == null:
			dir = DirAccess.open(path + "/PlainLauncher")
			return dir
	if dir == null:
		return null
	if dir.make_dir_recursive("PlainLauncher") != OK:
		print("Failed to make dir in " + dir.get_current_dir())
		return null
	return DirAccess.open(dir.get_current_dir() + "/PlainLauncher")

static func use_selection(selection: String) -> String:
	print("Attempting to use " + selection)
	var dir = open_selection(selection)
	if dir == null:
		return "Missing permissions."
	if not set_up_root(dir):
		return "Failure during setup."
	return ""

static func copy_builtin_contents(root: DirAccess, relative_dir: String):
	var config_dir = DirAccess.open("res://launcher_configs/" + relative_dir)
	for config_file in config_dir.get_files() + config_dir.get_directories():
		if OS.get_name() == "Android" and config_file.get_extension() == "import":
			continue
		var builtin = config_dir.get_current_dir() + "/" + config_file
		var dest = root.get_current_dir() + Global.PATH_CONFIG + relative_dir + "/" + config_file
		if config_dir.dir_exists(config_file):
			if relative_dir + "/" + config_file != "COMMON/intents":
				root.make_dir_recursive(dest)
				copy_builtin_contents(root, relative_dir + "/" + config_file)
		elif FileAccess.file_exists(dest):
			print("Keeping existing config " + dest)
		else:
			print("Copying built-in config from " + builtin + " to " + dest)
			var dest_file = FileAccess.open(dest, FileAccess.WRITE)
			dest_file.store_string(FileAccess.get_file_as_string(builtin))
			dest_file.close()

static func _make(root: DirAccess, path: String) -> bool:
	var result = root.make_dir_recursive(path)
	if result != OK and result != ERR_ALREADY_EXISTS:
		print("Failed to make directory (error " + str(result) + ") at " + path)
		return false
	return true

static func add_system(root: DirAccess, game_set: String) -> bool:
	var base = root.get_current_dir()
	if game_set.to_lower() != "common" and not _make(root, base + Global.PATH_GAMES + game_set):
		return false
	if not _make(root, base + Global.PATH_IMAGES + game_set) or not _make(root, base + Global.PATH_CONFIG + game_set):
		return false
	copy_builtin_contents(root, game_set)
	var system_image = ResourceLoader.load("res://launcher_configs/" + game_set + "/image.png", "png")
	var dest_image = base + Global.PATH_IMAGES + game_set + ".png"
	if system_image != null and not FileAccess.file_exists(dest_image):
		if system_image.get_image().save_png(dest_image) != OK:
			print("Failed to copy image for " + game_set)
	return true

static func add_missing_systems(root: DirAccess) -> Array:
	var added = []
	if root == null:
		return added
	for game_set in DirAccess.get_directories_at("res://launcher_configs/"):
		if game_set.to_lower() == "common" or DirAccess.dir_exists_absolute(root.get_current_dir() + Global.PATH_CONFIG + game_set):
			continue
		if add_system(root, game_set):
			added.append(game_set)
	return added

static func set_up_root(root: DirAccess) -> bool:
	if root == null:
		return false
	var base = root.get_current_dir()
	print("Setting up PlainLauncher directories in " + base)
	for path in [Global.PATH_GAMES, Global.PATH_CONFIG, Global.PATH_IMAGES]:
		if not _make(root, base + path):
			return false
	for game_set in DirAccess.get_directories_at("res://launcher_configs/"):
		if not add_system(root, game_set):
			return false
	Global.set_root_path(base)
	Global.store_version()
	return true

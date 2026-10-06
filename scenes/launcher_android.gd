extends Node

const BUNDLED_INTENTS_DIR = "res://launcher_configs/COMMON/intents"
const CUSTOM_SUFFIX = "_custom"

var _intents = null
var _intents_root = null
var _custom_files = {}

func custom_intents_dir() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents_custom"

func legacy_intents_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"

static func read_intent_dir(dir: String) -> Dictionary:
	var intents = {}
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "json":
			var intent = Global.read_json_dict(dir + "/" + file)
			if not intent.is_empty():
				intents[file.get_basename()] = intent
	return intents

static func intent_id(name: String) -> String:
	var id = ""
	for c in name.strip_edges().to_lower():
		id += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-" else "_"
	return id

func bundled_intents() -> Dictionary:
	return read_intent_dir(BUNDLED_INTENTS_DIR)

func load_intents() -> Dictionary:
	if _intents == null or _intents_root != Global.root_path:
		_intents_root = Global.root_path
		_intents = bundled_intents()
		_custom_files = {}
		if Global.root_path:
			remove_legacy_intents()
			var custom = read_intent_dir(custom_intents_dir())
			var names = custom.keys()
			names.sort()
			for name in names:
				var id = name
				while _intents.has(id):
					id += CUSTOM_SUFFIX
				_intents[id] = custom[name]
				_custom_files[id] = custom_intents_dir() + "/" + name + ".json"
	return _intents

func forget_intents():
	_intents = null

func is_custom_intent(id: String) -> bool:
	load_intents()
	return _custom_files.has(id)

func is_bundled_intent(id: String) -> bool:
	return load_intents().has(id) and not is_custom_intent(id)

func unused_intent_id(name: String) -> String:
	var base = intent_id(name)
	var id = base
	var n = 1
	while load_intents().has(id) or FileAccess.file_exists(custom_intents_dir() + "/" + id + ".json"):
		id = base + CUSTOM_SUFFIX + ("" if n == 1 else str(n))
		n += 1
	return id

func save_custom_intent(id: String, intent: Dictionary):
	if is_bundled_intent(id):
		return
	Global.write_json(_custom_files.get(id, custom_intents_dir() + "/" + id + ".json"), intent)
	forget_intents()

func remove_custom_intent(id: String):
	if is_custom_intent(id):
		DirAccess.remove_absolute(_custom_files[id])
		forget_intents()

func copy_as_custom(id: String) -> String:
	var new_id = unused_intent_id(id)
	save_custom_intent(new_id, load_intents().get(id, {}).duplicate(true))
	return new_id

func emulators_for_system(system: String) -> Array:
	var intents = load_intents()
	var result = []
	for id in intents:
		if system in intents[id].get("systems", []):
			result.append(id)
	result.sort()
	return result

func remove_legacy_intents():
	if FileAccess.file_exists(legacy_intents_path()):
		print("Removing old intents.json")
		DirAccess.remove_absolute(legacy_intents_path())

const GAME_CONTENTS_MAX_BYTES = 4096

static func expand_tokens(value, tokens: Dictionary):
	if value is Dictionary:
		var expanded = {}
		for key in value:
			expanded[key] = expand_tokens(value[key], tokens)
		return expanded
	if value is Array:
		return value.map(func(v): return expand_tokens(v, tokens))
	if value is float and value == floorf(value):
		return int(value)
	if not value is String:
		return value
	for token in tokens:
		value = value.replace(token, tokens[token])
	return value

static func user_id_from_path(path: String) -> int:
	var regex = RegEx.create_from_string("/data/user/(\\d+)/")
	var found = regex.search(path)
	return found.get_string(1).to_int() if found else 0

static func read_game_contents(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents = file.get_buffer(mini(file.get_length(), GAME_CONTENTS_MAX_BYTES)).get_string_from_utf8()
	file.close()
	return contents.strip_edges()

static func saf_encode(text: String) -> String:
	var encoded = ""
	for c in text:
		if c.unicode_at(0) < 128 and ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in "-_.!~*'()"):
			encoded += c
		else:
			for byte in c.to_utf8_buffer():
				encoded += "%%%02X" % byte
	return encoded

static func saf_uri(path: String) -> String:
	var volume = ""
	var relative = ""
	var emulated = RegEx.create_from_string("^/storage/emulated/\\d+/(.*)$").search(path)
	var removable = RegEx.create_from_string("^/storage/([^/]+)/(.*)$").search(path)
	if emulated:
		volume = "primary"
		relative = emulated.get_string(1)
	elif removable:
		volume = removable.get_string(1)
		relative = removable.get_string(2)
	else:
		return ""
	var tree = volume + ":" + relative.get_base_dir()
	return "content://com.android.externalstorage.documents/tree/" + saf_encode(tree) + "/document/" + saf_encode(volume + ":" + relative)

func token_values(intent: Dictionary, game_path: String, core: String, package: String) -> Dictionary:
	var user_id = user_id_from_path(OS.get_user_data_dir())
	var tokens = {
		"{game}": game_path,
		"{core}": core,
		"{package}": package,
		"{data_dir}": "/data/user/%d/%s" % [user_id, package],
		"{external_storage}": "/storage/emulated/%d" % user_id,
		"{basename}": game_path.get_file().get_basename(),
		"{filename}": game_path.get_file(),
		"{game_dir}": game_path.get_base_dir(),
		"{game_saf}": saf_uri(game_path),
		"<GAME>": game_path,
		"<CORE>": core,
	}
	if JSON.stringify(intent).contains("{game_contents}"):
		tokens["{game_contents}"] = read_game_contents(game_path)
	return tokens

const RETRY_WINDOW_MS = 1000
var _retry_intent = ""
var _retry_deadline = 0

static func should_retry(intent: String, now: int, deadline: int) -> bool:
	return intent != "" and now <= deadline

func _notification(what):
	if what != NOTIFICATION_APPLICATION_RESUMED:
		return
	if should_retry(_retry_intent, Time.get_ticks_msec(), _retry_deadline):
		print("Emulator closed right after launch, launching again")
		AndroidInterface.launch_intent(_retry_intent)
	_retry_intent = ""

func launch_entry(path: String, system: String, display_name: String) -> String:
	Global.last_launch = {"path": path, "system": system, "name": display_name}
	var err: String
	if system == "ANDROID":
		err = AndroidInterface.launch_package(path)
		if err != "":
			Global.pending_intent = path
			Global.pending_game = ""
			Global.pending_launch = {}
	elif not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
		err = "File not found: " + path
		Global.pending_intent = ""
		Global.pending_game = path
	else:
		var settings = Global.get_system_settings(system, path.get_file(), display_name)
		print("Launching [game] " + path + " with [settings] " + str(settings))
		err = launch_with_settings(settings, path)
	if err != "":
		Global.show_launch_failure(err)
	else:
		Global.log_recent(path, system, display_name)
	return err

func launch_with_settings(settings: Dictionary, game_path: String = ""):
	var core = settings.get("CORE", "NULL")
	var emulator = settings.get("EMULATOR")

	var launch_configs = load_intents()
	var launch_config = launch_configs.get(emulator) if emulator != null else null
	if not launch_config is Dictionary:
		return "No intent configured for: " + str(emulator)
	launch_config = launch_config.duplicate(true)
	launch_config.erase("systems")

	if game_path == "":
		return AndroidInterface.launch_package(launch_config.get("componentPackage", ""))

	Global.pending_intent = launch_config.get("componentPackage", "")
	Global.pending_game = game_path
	Global.pending_launch = settings

	var package = launch_config.get("componentPackage", "")
	var intent = expand_tokens(launch_config, token_values(launch_config, game_path, core, package))
	if package.begins_with("com.retroarch") and Settings.get_setting(Settings.CFG_RETROARCH_QUIT_ON_LEAVE):
		var extras = intent.get("extras", {})
		extras["QUITFOCUS"] = ""
		intent["extras"] = extras
	intent["gamePath"] = game_path
	var intent_str = JSON.stringify(intent)
	print("PLAIN LAUNCH: " + intent_str)

	# HACK: AETHERSX2 sometimes takes two tries to work. Don't know why
	if emulator.to_lower() == "aethersx2":
		AndroidInterface.launch_intent(intent_str)
	var result = AndroidInterface.launch_intent(intent_str)
	_retry_intent = intent_str if result == "" and package.begins_with("com.retroarch") else ""
	_retry_deadline = Time.get_ticks_msec() + RETRY_WINDOW_MS
	return result

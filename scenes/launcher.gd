extends Node

const BUNDLED_INTENTS_DIR = "res://launcher_configs/COMMON/intents"
const BUNDLED_COMMANDS_DIR = "res://launcher_configs/COMMON/commands"
const CUSTOM_SUFFIX = "_custom"

var _intents = null
var _intents_root = null
var _custom_files = {}

static func uses_commands() -> bool:
	if OS.get_name() == "Android":
		return false
	return OS.get_environment("PLAIN_LAUNCHER_COMMANDS") != "0"

func custom_intents_dir() -> String:
	return Global.root_path + Global.PATH_CONFIG + ("COMMON/commands_custom" if uses_commands() else "COMMON/intents_custom")

func legacy_intents_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"

static func read_intent_dir(dir: String) -> Dictionary:
	var intents = {}
	if not DirAccess.dir_exists_absolute(dir):
		return intents
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
	if not uses_commands():
		return read_intent_dir(BUNDLED_INTENTS_DIR)
	var commands = platform_commands(Platform.tags())
	if commands.has("retroarch_flatpak") and not native_retroarch_installed() and flatpak_retroarch_installed():
		commands["retroarch"] = commands["retroarch_flatpak"]
	var installed = {}
	for id in commands:
		var found = installed_command(commands[id])
		if not found.is_empty():
			installed[id] = found
	return installed

static func installed_command(config: Dictionary) -> Dictionary:
	var programs = config.get("programs", [])
	if programs.is_empty():
		return config if command_available(config) else {}
	for program in [config.get("command", [""])[0]] + programs:
		var found = config.duplicate(true)
		found.erase("programs")
		if found.get("command", []).is_empty():
			return {}
		found.command[0] = expand_env(str(program)).replace("\\", "/")
		if command_available(found):
			return found
	return {}

static func platform_commands(tags: Array) -> Dictionary:
	var commands = {}
	for tag in tags:
		commands.merge(read_intent_dir(BUNDLED_COMMANDS_DIR + "/" + tag), true)
	return commands

static func flatpak_installed(app: String) -> bool:
	var path = "flatpak/app/" + app
	return DirAccess.dir_exists_absolute("/var/lib/" + path) or DirAccess.dir_exists_absolute(Platform.home_dir().path_join(".local/share/" + path))

static func flatpak_app(command: Array) -> String:
	for i in range(2, command.size()):
		if not str(command[i]).begins_with("-"):
			return str(command[i])
	return ""

static func on_path(program: String) -> bool:
	var separator = ";" if OS.get_name() == "Windows" else ":"
	for dir in OS.get_environment("PATH").split(separator, false):
		if FileAccess.file_exists(dir.path_join(program)) or FileAccess.file_exists(dir.path_join(program + ".exe")):
			return true
	return false

static func command_available(config: Dictionary) -> bool:
	var command = config.get("command", [])
	if command.is_empty():
		return false
	var program = expand_env(str(command[0]))
	if program == "":
		return false
	if program == "flatpak":
		var app = flatpak_app(command)
		return app != "" and flatpak_installed(app)
	if program.is_absolute_path():
		return FileAccess.file_exists(program)
	return on_path(program)

static func native_retroarch_installed() -> bool:
	return ["/usr/bin/retroarch", "/usr/local/bin/retroarch"].any(func(p): return FileAccess.file_exists(p))

static func flatpak_retroarch_installed() -> bool:
	return flatpak_installed("org.libretro.RetroArch")

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
		Platform.launch_intent(_retry_intent)
	_retry_intent = ""

func launch_entry(path: String, system: String, display_name: String) -> String:
	Global.last_launch = {"path": path, "system": system, "name": display_name}
	var err: String
	if system == "ANDROID":
		err = Platform.launch_package(path)
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
	if launch_config.has("command"):
		return launch_command(launch_config, game_path, core)

	if game_path == "":
		return Platform.launch_package(launch_config.get("componentPackage", ""))

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
		Platform.launch_intent(intent_str)
	var result = Platform.launch_intent(intent_str)
	_retry_intent = intent_str if result == "" and package.begins_with("com.retroarch") else ""
	_retry_deadline = Time.get_ticks_msec() + RETRY_WINDOW_MS
	return result

static func expand_env(text: String) -> String:
	var regex = RegEx.create_from_string("\\{env:([A-Za-z0-9_]+)\\}")
	for found in regex.search_all(text):
		text = text.replace(found.get_string(), OS.get_environment(found.get_string(1)))
	return text

const HOST_ENV = ["-u", "LD_PRELOAD", "-u", "LD_LIBRARY_PATH"]

static func host_script(script: String, name: String) -> Array:
	var path = ProjectSettings.globalize_path("user://" + name + ".sh")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return []
	file.store_string(script + "\n")
	file.close()
	return HOST_ENV + ["sh", path]

static func run_host(script: String) -> String:
	var out = ProjectSettings.globalize_path("user://host_output.txt")
	DirAccess.remove_absolute(out)
	var args = host_script("{ " + script + "\n} >" + shell_quote(out) + " 2>/dev/null", "host_command")
	if args.is_empty():
		return ""
	var code = OS.execute("env", args)
	var text = FileAccess.get_file_as_string(out) if FileAccess.file_exists(out) else ""
	DirAccess.remove_absolute(out)
	return text.strip_edges() if code == 0 else ""

static func shell_quote(arg: String) -> String:
	return "'" + arg.replace("'", "'\\''") + "'"

static func shell_command(command: Array) -> String:
	return " ".join(command.map(func(arg): return shell_quote(str(arg))))

func own_retroarch_config() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/retroarch.cfg"

static func choose_retroarch_config(system_config: String, own_config: String, use_own: bool) -> String:
	if not use_own or own_config == "":
		return system_config
	if not FileAccess.file_exists(own_config) and system_config != "" and FileAccess.file_exists(system_config):
		DirAccess.make_dir_recursive_absolute(own_config.get_base_dir())
		DirAccess.copy_absolute(system_config, own_config)
	return own_config

func retroarch_config() -> String:
	return choose_retroarch_config(OS.get_environment("RETROARCH_CONFIG"), own_retroarch_config(), Settings.get_setting(Settings.CFG_RETROARCH_OWN_CONFIG))

func command_for(config: Dictionary, game_path: String, core: String) -> Array:
	var tokens = token_values(config, game_path, core, "")
	if JSON.stringify(config).contains("{retroarch_config}"):
		tokens["{retroarch_config}"] = retroarch_config()
	var command = expand_tokens(config.get("command", []), tokens)
	return matching_retroarch(command.map(func(arg): return expand_env(str(arg))))

static func elf_is_32bit(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 5:
		return false
	var header = file.get_buffer(5)
	return header[0] == 0x7f and header[1] == 0x45 and header[2] == 0x4c and header[3] == 0x46 and header[4] == 1

static func matching_retroarch(command: Array) -> Array:
	if command.is_empty() or str(command[0]).get_file() != "retroarch":
		return command
	var alternate = str(command[0]) + "32"
	if not (FileAccess.file_exists(alternate) if alternate.is_absolute_path() else on_path(alternate)):
		return command
	for arg in command.slice(1):
		if str(arg).ends_with("_libretro.so") and elf_is_32bit(str(arg)):
			var result = command.duplicate()
			result[0] = alternate
			return result
	return command

func launch_command(config: Dictionary, game_path: String, core: String) -> String:
	var command = command_for(config, game_path, core)
	if command.is_empty():
		return "No command configured"
	Global.store_positions_files()
	print("PLAIN COMMAND: " + shell_command(command))
	var handoff = OS.get_environment("PLAIN_LAUNCHER_LAUNCH_FILE")
	if handoff == "":
		var pid = OS.create_process(command[0], command.slice(1))
		if pid == -1:
			return "Couldn't start " + command[0]
		_running_pid = pid
		get_tree().paused = true
		return ""
	var file = FileAccess.open(handoff, FileAccess.WRITE)
	if file == null:
		return "Couldn't write " + handoff
	file.store_string(shell_command(command) + "\n")
	file.close()
	get_tree().quit.call_deferred()
	return ""

var _running_pid = -1

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta):
	if _running_pid > 0 and not OS.is_process_running(_running_pid):
		print("Emulator closed")
		_running_pid = -1
		get_tree().paused = false

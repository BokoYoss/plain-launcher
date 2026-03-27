extends Node2D

const BUNDLED_INTENTS_PATH = "res://launcher_configs/COMMON/intents.json"

func get_intents_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"

func load_intents() -> Dictionary:
	var user_path = get_intents_path()
	if FileAccess.file_exists(user_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(user_path))
		if parsed != null:
			return parsed
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUNDLED_INTENTS_PATH))
	if parsed != null:
		return parsed
	return {}

func expand_tokens(intent_str: String, game_path: String, core: String, package: String) -> String:
	var data_dir = "/data/data/" + package
	# New-style tokens
	intent_str = intent_str.replace("{game}", game_path)
	intent_str = intent_str.replace("{core}", core)
	intent_str = intent_str.replace("{package}", package)
	intent_str = intent_str.replace("{data_dir}", data_dir)
	# Legacy tokens
	intent_str = intent_str.replace("<GAME>", game_path)
	intent_str = intent_str.replace("<CORE>", core)
	return intent_str

func launch_action(action):
	var intent = JSON.stringify({"action": action})
	return AndroidInterface.launch_intent(intent)

func launch_with_settings(settings: Dictionary, game_path: String = ""):
	var core = settings.get("CORE", "NULL")
	var emulator = settings.get("EMULATOR")

	var launch_configs = load_intents()
	var launch_config: Dictionary = launch_configs.get(emulator)
	if launch_config == null:
		return "No intent configured for: " + str(emulator)

	if game_path == "":
		AndroidInterface.launch_package(launch_config.get("componentPackage", ""))
		return ""

	Global.pending_intent = launch_config.get("componentPackage", "")
	Global.pending_game = game_path
	Global.pending_launch = settings

	var package = launch_config.get("componentPackage", "")
	var intent_str = expand_tokens(JSON.stringify(launch_config), game_path, core, package)
	print("PLAIN LAUNCH: " + intent_str)

	# HACK: AETHERSX2 sometimes takes two tries to work. Don't know why
	if emulator.to_lower() == "aethersx2":
		AndroidInterface.launch_intent(intent_str)
	return AndroidInterface.launch_intent(intent_str)

extends Node2D

func launch_action(action):
	var intent = JSON.stringify({"action": action})
	return AndroidInterface.launch_intent(intent)

func launch_with_settings(settings: Dictionary, game_path: String = ""):
	# Get intent configuration for the given settings
	var core = settings.get("CORE", "NULL")
	var emulator = settings.get("EMULATOR")

	print("Fetching launch configs at " + Global.root_path + "/" + Global.PATH_CONFIG + "/COMMON/intents.json")

	var launch_configs = JSON.parse_string(FileAccess.get_file_as_string(Global.root_path + "/" + Global.PATH_CONFIG +  "COMMON/intents.json"))

	var launch_config: Dictionary = launch_configs.get(emulator)
	if game_path == "":
		if "<GAME>" in launch_config.get("data", ""):
			launch_config.erase("data")
		for extra_key in launch_config.get("extras", {}):
			var value = launch_config.get("extras").get(extra_key)
			if "<GAME>" in value:
				launch_config.get("extras").erase(extra_key)

	var intent = JSON.stringify(launch_config).replace("<GAME>", game_path).replace("<CORE>", core)
	print("PLAIN LAUNCH: " + intent)

	# HACK: AETHERSX2 sometimes takes two tries to work. Don't know why
	if emulator.to_lower() == "aethersx2":
		AndroidInterface.launch_intent(intent)
	return AndroidInterface.launch_intent(intent)

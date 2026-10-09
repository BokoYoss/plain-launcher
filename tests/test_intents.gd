extends "res://tests/test_case.gd"

const StorageSetup = preload("res://scenes/storage_setup.gd")

const FakePlugin = preload("res://tests/fakes/fake_plugin.gd")

var root: String
var saved_root

func before_each():
	saved_root = Global.root_path
	root = ProjectSettings.globalize_path("user://intents_root")
	_remove_recursive(root)
	DirAccess.make_dir_recursive_absolute(root + "/Config/COMMON")
	Global.root_path = root
	Global.subscreen = ""
	Launcher.forget_intents()

func after_each():
	Global.root_path = saved_root
	Launcher.forget_intents()

func _remove_recursive(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_recursive(path + "/" + d)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)

func _custom(id: String) -> String:
	return root + "/Config/COMMON/intents_custom/" + id + ".json"

func test_bundled_intents_load_from_individual_files():
	var intents = Launcher.load_intents()
	assert_true(intents.has("retroarch"), "retroarch bundled")
	assert_eq(intents.get("melonds", {}).get("systems"), ["NDS"], "melonds declares NDS")

func test_custom_file_with_builtin_name_never_replaces_builtin():
	var stock = Launcher.load_intents()["melonds"].duplicate(true)
	write_json(_custom("melonds"), {"componentPackage": "my.melonds", "systems": ["NDS"]})
	Launcher.forget_intents()
	var intents = Launcher.load_intents()
	assert_eq(intents["melonds"], stock, "built-in untouched")
	assert_eq(intents.get("melonds_custom", {}).get("componentPackage"), "my.melonds", "custom shows up alongside")
	assert_true(Launcher.is_custom_intent("melonds_custom"), "custom id maps to the custom file")
	Launcher.remove_custom_intent("melonds_custom")
	assert_false(FileAccess.file_exists(_custom("melonds")), "deleting removes the custom file")

func test_builtin_cannot_be_saved_over():
	var stock = Launcher.load_intents()["melonds"].duplicate(true)
	Launcher.save_custom_intent("melonds", {"componentPackage": "hijack"})
	assert_eq(Launcher.load_intents()["melonds"], stock, "built-in unchanged")
	assert_false(DirAccess.dir_exists_absolute(root + "/Config/COMMON/intents_custom"), "nothing written")

func test_copy_of_builtin_is_a_separate_custom_intent():
	var id = Launcher.copy_as_custom("melonds")
	assert_eq(id, "melonds_custom", "copy id")
	assert_true(FileAccess.file_exists(_custom("melonds_custom")), "copy saved in custom folder")
	assert_eq(Launcher.copy_as_custom("melonds"), "melonds_custom2", "second copy gets a new id")
	var copy = Launcher.load_intents()["melonds_custom"]
	copy = copy.duplicate(true)
	copy["componentClass"] = "edited"
	Launcher.save_custom_intent("melonds_custom", copy)
	assert_eq(Launcher.load_intents()["melonds_custom"].componentClass, "edited", "copy editable")
	assert_true(Launcher.load_intents()["melonds"].componentClass != "edited", "built-in unaffected")

func test_new_intent_names_never_collide():
	assert_eq(Launcher.unused_intent_id("RetroArch"), "retroarch_custom", "built-in name gets suffix")
	assert_eq(Launcher.unused_intent_id("Brand New"), "brand_new", "free name kept")

func test_user_only_intent_is_added_and_deleted():
	Launcher.save_custom_intent("newemu", {"action": "android.intent.action.VIEW", "componentPackage": "com.new", "systems": ["GBA"]})
	assert_true(Launcher.load_intents().has("newemu"), "user intent loaded")
	assert_true(Launcher.is_custom_intent("newemu"), "marked custom")
	Launcher.remove_custom_intent("newemu")
	assert_false(Launcher.load_intents().has("newemu"), "deleted")

func test_dropped_in_file_is_picked_up_after_refresh():
	Launcher.load_intents()
	write_json(_custom("dropped"), {"componentPackage": "com.dropped", "systems": ["SNES"]})
	Global.clear_dir_cache()
	assert_true(Launcher.load_intents().has("dropped"), "refresh rereads intent files")

func test_systems_field_adds_emulator_to_system_options():
	write_json(root + "/Config/GBA/choices.json", {"EMULATOR": ["first"], "CORE": ["mgba"]})
	Launcher.save_custom_intent("newemu", {"componentPackage": "com.new", "systems": ["GBA"]})
	var emulators = Global.get_system_settings_options("GBA").EMULATOR
	assert_eq(emulators[0], "first", "choices.json order kept, default unchanged")
	assert_true("newemu" in emulators, "declared emulator offered")

func test_hidden_emulator_is_not_offered():
	write_json(root + "/Config/GBA/choices.json", {"EMULATOR": ["first"], "EMULATOR_HIDDEN": ["newemu"]})
	Launcher.save_custom_intent("newemu", {"componentPackage": "com.new", "systems": ["GBA"]})
	var options = Global.get_system_settings_options("GBA")
	assert_false("newemu" in options.EMULATOR, "hidden emulator left out")
	assert_false(options.has("EMULATOR_HIDDEN"), "hidden list is not a setting")

func test_system_known_only_from_intents_gets_options():
	Launcher.save_custom_intent("newemu", {"componentPackage": "com.new", "systems": ["NEWSYS"]})
	assert_eq(Global.get_system_settings_options("NEWSYS").get("EMULATOR"), ["newemu"], "new system usable from one file")

func test_old_intents_file_is_removed():
	write_json(root + "/Config/COMMON/intents.json", {
		"retroarch": {"componentPackage": "old.retroarch"},
		"mine": {"componentPackage": "com.mine"},
	})
	var intents = Launcher.load_intents()
	assert_false(FileAccess.file_exists(root + "/Config/COMMON/intents.json"), "old file deleted")
	assert_true(intents["retroarch"].componentPackage != "old.retroarch", "built-in used")
	assert_false(intents.has("mine"), "old entries not carried over")
	assert_false(DirAccess.dir_exists_absolute(root + "/Config/COMMON/intents_custom"), "nothing copied")

func test_intent_ids_are_file_safe():
	assert_eq(Launcher.intent_id(" My Emu/2.0 "), "my_emu_2_0", "sanitized id")

func test_systems_field_not_sent_to_android():
	var plugin = FakePlugin.new()
	Platform._android_plugin = plugin
	Launcher.save_custom_intent("newemu", {"componentPackage": "com.new", "componentClass": "A", "systems": ["GBA"]})
	Launcher.launch_with_settings({"EMULATOR": "newemu"}, root + "/game.gba")
	var sent = JSON.parse_string(plugin.calls_to("launchIntent").back())
	assert_false(sent.has("systems"), "systems stripped")
	assert_eq(sent.get("componentPackage"), "com.new", "intent sent")

func test_setup_does_not_copy_bundled_intents():
	DirAccess.make_dir_recursive_absolute(root + "/Config/COMMON")
	StorageSetup.copy_builtin_contents(DirAccess.open(root), "COMMON")
	assert_false(DirAccess.dir_exists_absolute(root + "/Config/COMMON/intents"), "bundled intents stay in the app")

func test_nethersx2_turnip_offered_for_ps2():
	write_json(root + "/Config/PS2/choices.json", {"EMULATOR": ["aethersx2"], "EXTENSIONS": ["iso", "chd"]})
	var emulators = Global.get_system_settings_options("PS2").EMULATOR
	assert_eq(emulators[0], "aethersx2", "default unchanged")
	assert_true("nethersx2_turnip" in emulators, "turnip build offered for PS2")
	assert_eq(Launcher.load_intents()["nethersx2_turnip"].componentPackage, "xyz.aethersx2.cturnip", "turnip package")

func test_every_builtin_intent_is_complete():
	var problems = []
	for id in Launcher.bundled_intents():
		var intent = Launcher.bundled_intents()[id]
		if intent.get("componentPackage", "") == "" or intent.get("componentClass", "") == "":
			problems.append(id + " missing component")
	assert_eq(problems, [], "all built-ins launchable")

func test_gamenative_offered_for_steam():
	var emulators = Global.get_system_settings_options("STEAM").get("EMULATOR", [])
	assert_true("gamenative" in emulators, "gamenative offered")
	assert_eq(Launcher.load_intents()["gamenative"].extras.app_id, {"type": "int", "value": "{game_contents}"}, "app id read from the .steam file as an int")

func test_gamenative_store_systems_send_matching_source():
	for pair in [["STEAM", "STEAM"], ["EPIC", "EPIC"], ["GOG", "GOG"], ["AMAZON", "AMAZON"], ["PCGAMES", "CUSTOM_GAME"]]:
		var choices = JSON.parse_string(FileAccess.get_file_as_string("res://launcher_configs/" + pair[0] + "/choices.json"))
		var intent = Launcher.load_intents()[choices.EMULATOR[0]]
		assert_eq(intent.extras.game_source, pair[1], pair[0] + " launches with its store")
		assert_true(pair[0] in intent.systems, pair[0] + " listed in intent systems")

func test_bundled_aliases_fill_in_under_user_aliases():
	var saved_aliases = Global.ALIAS_MAP
	write_json(root + "/Config/COMMON/alias.json", {"gba": "My GBA"})
	Global.refresh_alias()
	var steam = Global.ALIAS_MAP.get("steam")
	var gba = Global.ALIAS_MAP.get("gba")
	Global.set_active_alias_map(saved_aliases)
	assert_eq(steam, "Steam", "new bundled alias shows for existing users")
	assert_eq(gba, "My GBA", "user alias wins")

func test_custom_names_saved_as_aliases():
	var saved_aliases = Global.ALIAS_MAP
	var game = option.new_option("Metal Slug (USA).zip")
	game.system = "NEOGEO"
	Global.set_custom_name(game, "  Metal Slug 1 ")
	var saved = read_json(root + "/Config/NEOGEO/alias.json")
	var system = option.new_option("STEAM")
	system.is_dir = true
	system.system = "STEAM"
	Global.set_custom_name(system, "PC")
	var system_alias = Global.custom_name(system)
	Global.set_custom_name(game, "")
	var cleared = read_json(root + "/Config/NEOGEO/alias.json")
	Global.set_active_alias_map(saved_aliases)
	assert_eq(saved, {"Metal Slug": "Metal Slug 1"}, "game alias keyed by cleaned name")
	assert_eq(system_alias, "PC", "system alias in COMMON")
	assert_eq(cleared, {}, "empty name removes the alias")

func test_resetting_game_emulator_clears_old_style_settings():
	const OptionsMenu = preload("res://scenes/options_menu.gd")
	write_json(root + "/Config/NDS/config.json", {"EMULATOR": "melonds"})
	write_json(root + "/Config/NDS/Dawn of Sorrow.json", {"EMULATOR": "retroarch"})
	var game = option.new_option("Dawn of Sorrow (USA).nds")
	game.clean = "Dawn of Sorrow"
	game.system = "NDS"
	var menu = OptionsMenu.new(null)
	menu.item = game
	menu.settings = menu.load_settings()
	assert_eq(menu.settings.EMULATOR, "retroarch", "old override found")
	menu._reset_setting_values("EMULATOR")
	assert_false(FileAccess.file_exists(root + "/Config/NDS/Dawn of Sorrow.json"), "old file removed")
	assert_eq(Global.get_system_settings("NDS", game.filename, game.clean).EMULATOR, "melonds", "system default used again")

func test_default_name_is_what_launcher_would_show():
	var game = option.new_option("Metal Slug (USA).zip")
	game.system = "NEOGEO"
	assert_eq(Global.default_name(game), "Metal Slug", "cleaned file name")
	var system = option.new_option("GENESIS")
	system.is_dir = true
	system.system = "GENESIS"
	assert_eq(Global.default_name(system), "Sega Genesis", "built-in system name")

extends "res://tests/test_case.gd"

const FakePlugin = preload("res://tests/fakes/fake_plugin.gd")
const FakeNavigator = preload("res://tests/fakes/fake_navigator.gd")

class TextInputPlugin:
	func showTextInput(_prompt, _value, _is_password):
		pass

var root: String
var plugin

func before_each():
	root = ProjectSettings.globalize_path("user://test_root")
	_remove_recursive(root)
	DirAccess.make_dir_recursive_absolute(root + "/Config/COMMON")
	Global.root_path = root
	Global.special_item = null
	Global.subscreen = ""
	Global.last_launch = {}
	Global.failure_message = ""

	plugin = FakePlugin.new()
	Platform._android_plugin = plugin
	var nav = _nav()
	if nav.get_script() != FakeNavigator:
		nav.set_script(FakeNavigator)
	nav.pushed = []

	write_json(root + "/Config/COMMON/intents_custom/emu_a.json", {"action": "android.intent.action.VIEW", "componentPackage": "com.emu.a", "componentClass": "A", "extras": {"ROM": "{game}"}})
	write_json(root + "/Config/COMMON/intents_custom/emu_b.json", {"action": "android.intent.action.VIEW", "componentPackage": "com.emu.b", "componentClass": "B", "extras": {"ROM": "{game}"}})
	Launcher.forget_intents()
	write_json(root + "/Config/GBA/choices.json", {"EMULATOR": ["emu_a", "emu_b"], "CORE": ["mgba"], "EXTENSIONS": ["gba"]})

func _assert_failure_panel():
	assert_true(Global.failure_message != "", "failure reported")
	assert_eq(_nav().pushed, [], "no screen pushed")

func _nav():
	return tree.root.get_node("Navigator")

func _remove_recursive(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_recursive(path + "/" + d)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)

func _recent() -> Array:
	var r = read_json(root + "/Config/COMMON/recent.json")
	return r if r is Array else []

func _rom(name: String, system: String = "GBA") -> String:
	var path = root + "/Games/" + system + "/" + name
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).close()
	return path

func _launched_package() -> String:
	var intents = plugin.calls_to("launchIntent")
	if intents.is_empty():
		return "<none>"
	return JSON.parse_string(intents.back()).get("componentPackage", "")

func test_android_app_launches_package_and_logs_recent():
	var err = Launcher.launch_entry("com.example.app", "ANDROID", "Example")
	assert_eq(err, "", "launch result")
	assert_eq(plugin.calls_to("launchPackage"), ["com.example.app"], "packages launched")
	assert_eq(plugin.calls_to("launchIntent"), [], "should not go through intent/emulator path")
	assert_eq(_recent().size(), 1, "recent entries")
	assert_eq(_recent()[0].get("system"), "ANDROID", "recent system")

func test_android_app_from_recent_relaunches_as_package():
	Launcher.launch_entry("com.example.app", "ANDROID", "Example")
	var entry = _recent()[0]
	plugin.calls = []
	Launcher.launch_entry(entry.path, entry.system, entry.name)
	assert_eq(plugin.calls_to("launchPackage"), ["com.example.app"], "relaunch from recent")
	assert_eq(_nav().pushed, [], "no failure screen")

func test_android_app_failure_shows_failure_panel_and_skips_recent():
	plugin.launch_package_result = "com.gone not installed."
	var err = Launcher.launch_entry("com.gone", "ANDROID", "Gone")
	assert_eq(err, "com.gone not installed.", "launch result")
	_assert_failure_panel()
	assert_eq(Global.failure_message, "com.gone not installed.", "failure message")
	assert_eq(_recent().size(), 0, "failed launch should not be logged")
	assert_eq(Global.last_launch, {"path": "com.gone", "system": "ANDROID", "name": "Gone"}, "retry info")

func test_old_plugin_returning_nothing_counts_as_success():
	plugin.launch_package_result = null
	assert_eq(Launcher.launch_entry("com.example.app", "ANDROID", "Example"), "", "launch result")
	assert_eq(_nav().pushed, [], "no failure screen")

func test_rom_uses_system_default_emulator():
	var err = Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(err, "", "launch result")
	assert_eq(_launched_package(), "com.emu.a", "first choice is the default")
	assert_eq(_recent()[0].get("path"), _rom("Apotris (USA).gba"), "recent path")

func test_rom_uses_per_game_settings():
	write_json(Global.get_game_settings_path("GBA", "Apotris (USA).gba"), {"EMULATOR": "emu_b"})
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_launched_package(), "com.emu.b", "per-game emulator")

func test_rom_falls_back_to_legacy_display_name_settings():
	write_json(Global.get_legacy_game_settings_path("GBA", "Apotris"), {"EMULATOR": "emu_b"})
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_launched_package(), "com.emu.b", "legacy per-game emulator")

func test_filename_settings_win_over_legacy():
	write_json(Global.get_legacy_game_settings_path("GBA", "Apotris"), {"EMULATOR": "emu_a"})
	write_json(Global.get_game_settings_path("GBA", "Apotris (USA).gba"), {"EMULATOR": "emu_b"})
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_launched_package(), "com.emu.b", "filename-keyed settings")

func test_regional_versions_do_not_share_settings():
	write_json(Global.get_game_settings_path("GBA", "Game (Japan).gba"), {"EMULATOR": "emu_b"})
	Launcher.launch_entry(_rom("Game (USA).gba"), "GBA", "Game")
	assert_eq(_launched_package(), "com.emu.a", "USA version uses default")

func test_stale_special_item_does_not_leak_into_launch():
	write_json(Global.get_legacy_game_settings_path("GBA", "Other"), {"EMULATOR": "emu_b"})
	var stale = option.new()
	stale.clean = "Other"
	stale.filename = "Other.gba"
	stale.system = "GBA"
	Global.special_item = stale
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_launched_package(), "com.emu.a", "unrelated game's settings ignored")

func test_missing_emulator_shows_failure_instead_of_crashing():
	write_json(root + "/Config/GBA/config.json", {"EMULATOR": "deleted_emu"})
	var err = Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(err, "No intent configured for: deleted_emu", "launch result")
	_assert_failure_panel()
	assert_eq(_recent().size(), 0, "failed launch should not be logged")

func test_system_with_no_emulator_configured_shows_failure():
	var err = Launcher.launch_entry(_rom("thing.bin", "CUSTOM"), "CUSTOM", "Thing")
	assert_eq(err, "No intent configured for: <null>", "launch result")
	_assert_failure_panel()

func test_malformed_config_falls_back_to_choices():
	write_json(root + "/Config/GBA/config.json", "{not json")
	assert_eq(Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris"), "", "launch result")
	assert_eq(_launched_package(), "com.emu.a", "default from choices.json")

func test_emulator_launch_error_is_reported():
	plugin.launch_intent_result = "com.emu.a not found."
	var err = Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(err, "com.emu.a not found.", "launch result")
	_assert_failure_panel()
	assert_eq(_recent().size(), 0, "failed launch should not be logged")

func test_missing_rom_shows_file_not_found():
	var path = root + "/Games/GBA/Moved Away.gba"
	var err = Launcher.launch_entry(path, "GBA", "Moved Away")
	assert_eq(err, "File not found: " + path, "launch result")
	assert_eq(plugin.calls_to("launchIntent"), [], "emulator not launched")
	_assert_failure_panel()
	assert_eq(_recent().size(), 0, "failed launch should not be logged")

func test_rom_folder_counts_as_existing():
	var path = root + "/Games/GBA/Folder Game"
	DirAccess.make_dir_recursive_absolute(path)
	assert_eq(Launcher.launch_entry(path, "GBA", "Folder Game"), "", "launch result")
	assert_eq(_launched_package(), "com.emu.a", "emulator launched")

func test_rom_path_with_quotes_and_backslashes_survives_intent():
	var path = _rom("Say \"Hi\" \\ Ünïcode.gba")
	assert_eq(Launcher.launch_entry(path, "GBA", "Say Hi"), "", "launch result")
	var intent = JSON.parse_string(plugin.calls_to("launchIntent").back())
	assert_true(intent is Dictionary, "intent is valid JSON")
	if intent is Dictionary:
		assert_eq(intent.extras.ROM, path, "ROM extra")

func test_restore_all_settings_clears_game_settings_only():
	write_json(root + "/Config/GBA/config.json", {"EMULATOR": "emu_b"})
	write_json(Global.get_game_settings_path("GBA", "Apotris (USA).gba"), {"EMULATOR": "emu_b"})
	write_json(Global.get_legacy_game_settings_path("GBA", "Apotris"), {"EMULATOR": "emu_b"})
	write_json(root + "/Config/GBA/alias.json", {"a.gba": "A"})
	write_json(root + "/Config/COMMON/recent.json", [])
	Global.clear_all_settings()
	assert_false(FileAccess.file_exists(root + "/Config/GBA/config.json"), "config.json removed")
	assert_false(DirAccess.dir_exists_absolute(root + "/Config/GBA/games"), "games/ removed")
	assert_false(FileAccess.file_exists(Global.get_legacy_game_settings_path("GBA", "Apotris")), "legacy file removed")
	assert_true(FileAccess.file_exists(root + "/Config/GBA/choices.json"), "choices.json kept")
	assert_true(FileAccess.file_exists(root + "/Config/GBA/alias.json"), "alias.json kept")
	assert_true(FileAccess.file_exists(root + "/Config/COMMON/intents_custom/emu_a.json"), "COMMON intents kept")
	assert_true(FileAccess.file_exists(root + "/Config/COMMON/recent.json"), "COMMON recent kept")
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_launched_package(), "com.emu.a", "back to default emulator")

func test_cancelled_storage_picker_reports_failure():
	var got = {"configured": [], "failed": []}
	var on_ok = func(p): got.configured.append(p)
	var on_fail = func(m): got.failed.append(m)
	for selection in ["FAILURE", null, "", "NOT_FOUND", "/tree/primary:Roms"]:
		Platform.request_storage(on_ok, on_fail)
		Platform.storage_selection(selection)
	assert_eq(got.failed.size(), 4, "cancel/empty results reported as failures")
	assert_eq(got.configured, ["/storage/emulated/0/Roms"], "only the real path is configured")

func test_storage_result_only_reaches_latest_requester():
	var got = {"art": [], "games": []}
	Platform.request_storage(func(p): got.art.append(p), Callable())
	Platform.request_storage(func(p): got.games.append(p), Callable())
	Platform.storage_selection("/tree/primary:Roms")
	Platform.storage_selection("/tree/primary:Other")
	assert_eq(got.art, [], "earlier screen not notified")
	assert_eq(got.games, ["/storage/emulated/0/Roms"], "requester notified once")

func test_text_input_only_reaches_requester():
	var got = {"browser": [], "editor": []}
	Platform._android_plugin = TextInputPlugin.new()
	Platform.show_text_input("Name", "", false, func(t): got.browser.append(t))
	Platform.show_text_input("Field", "", false, func(t): got.editor.append(t))
	Platform._on_text_input_complete("value")
	Platform._on_text_input_complete("stray")
	assert_eq(got.browser, [], "earlier screen not notified")
	assert_eq(got.editor, ["value"], "requester notified once")

func test_malformed_recent_and_favorites_read_as_empty():
	write_json(root + "/Config/COMMON/recent.json", "{oops")
	write_json(root + "/Games/FAVORITES/favorites.json", {"not": "a list"})
	assert_eq(Global.get_recent_list(), [], "recent")
	assert_eq(Global.get_favorites_entries(), [], "favorites")
	Launcher.launch_entry(_rom("Apotris (USA).gba"), "GBA", "Apotris")
	assert_eq(_recent().size(), 1, "recent rewritten after a launch")

func test_favorites_list_row_is_recognised_as_favorite():
	var item = option.new()
	item.clean = "Apotris"
	item.filename = "Apotris (USA).gba"
	item.absolute_path = _rom("Apotris (USA).gba")
	item.system = "GBA"
	Global.add_favorite(item)
	assert_eq(Global.get_favorites_entries().size(), 1, "added")
	var row = option.new()
	var entry = Global.get_favorites_entries()[0]
	row.clean = entry.name
	row.filename = entry.filename
	row.absolute_path = entry.path
	row.system = entry.system
	assert_true(Global.favorites_list.has(row.absolute_path), "favorites row recognised as a favorite")

func test_additional_paths_use_given_system_not_special_item():
	var stale = option.new()
	stale.system = "NES"
	Global.special_item = stale
	Global.store_additional_paths("GBA", ["/mnt/roms/gba"])
	assert_eq(Global.get_additional_paths("GBA"), ["/mnt/roms/gba"], "GBA paths")
	assert_eq(Global.get_additional_paths("NES"), [], "NES untouched")

func test_user_paths_exclude_blank_lines():
	Global.store_additional_paths("GBA", ["/mnt/a", "", "/mnt/b"])
	assert_eq(Global.get_user_paths("GBA"), ["/mnt/a", "/mnt/b"], "blank lines dropped")
	Global.remove_additional_path("GBA", "/mnt/a")
	assert_eq(Global.get_user_paths("GBA"), ["/mnt/b"], "removed")

func test_retroarch_exits_on_leave_when_enabled():
	write_json(root + "/Config/COMMON/intents_custom/ra.json", {"action": "android.intent.action.MAIN", "componentPackage": "com.retroarch", "componentClass": "X", "extras": {"ROM": "{game}"}})
	Launcher.forget_intents()
	FileAccess.open(root + "/a.gba", FileAccess.WRITE).close()
	var saved = Settings._data.get(Settings.CFG_RETROARCH_QUIT_ON_LEAVE)
	Settings._data[Settings.CFG_RETROARCH_QUIT_ON_LEAVE] = false
	Launcher.launch_with_settings({"EMULATOR": "ra"}, root + "/a.gba")
	var normal = JSON.parse_string(plugin.calls_to("launchIntent").back())
	Settings._data[Settings.CFG_RETROARCH_QUIT_ON_LEAVE] = true
	Launcher.launch_with_settings({"EMULATOR": "ra"}, root + "/a.gba")
	var quitting = JSON.parse_string(plugin.calls_to("launchIntent").back())
	Launcher.launch_with_settings({"EMULATOR": "emu_a"}, root + "/a.gba")
	var other = JSON.parse_string(plugin.calls_to("launchIntent").back())
	if saved == null:
		Settings._data.erase(Settings.CFG_RETROARCH_QUIT_ON_LEAVE)
	else:
		Settings._data[Settings.CFG_RETROARCH_QUIT_ON_LEAVE] = saved
	assert_false(normal.extras.has("QUITFOCUS"), "off by default")
	assert_true(quitting.extras.has("QUITFOCUS"), "RetroArch told to exit on leave")
	assert_false(other.extras.has("QUITFOCUS"), "other emulators untouched")

func test_retroarch_relaunched_once_if_it_closes_right_away():
	write_json(root + "/Config/COMMON/intents_custom/ra.json", {"action": "android.intent.action.MAIN", "componentPackage": "com.retroarch", "componentClass": "X", "extras": {"ROM": "{game}"}})
	Launcher.forget_intents()
	FileAccess.open(root + "/a.gba", FileAccess.WRITE).close()
	Launcher.launch_with_settings({"EMULATOR": "ra"}, root + "/a.gba")
	assert_true(Launcher._retry_intent != "", "RetroArch launch armed for one retry")
	Launcher._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(plugin.calls_to("launchIntent").size(), 2, "launched again after closing right away")
	Launcher._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(plugin.calls_to("launchIntent").size(), 2, "only one retry")
	Launcher.launch_with_settings({"EMULATOR": "emu_a"}, root + "/a.gba")
	assert_eq(Launcher._retry_intent, "", "other emulators never retried")
	assert_false(Launcher.should_retry("x", 2000, 1000), "too late counts as a normal return")

func test_select_by_path_keeps_place_after_reload():
	var saved = Global.option_list
	var rows = []
	for name in ["007.gba", "a.gba", "b.gba", "c.gba"]:
		var opt = option.new_option(name)
		opt.absolute_path = "/roms/" + name
		rows.append(opt)
	Global.option_list = rows
	Global.select_by_path("/roms/b.gba", 0)
	var found = Global.option_selection
	Global.select_by_path("/roms/gone.gba", 9)
	var clamped = Global.option_selection
	Global.option_list = saved
	assert_eq(found, 2, "same game selected again")
	assert_eq(clamped, 3, "missing game keeps a nearby row")

func test_positions_keyed_by_list_not_title():
	assert_eq(Global.list_key("game_browser", "GBA", ""), "game_browser:GBA", "stable key for a system's games")
	assert_eq(Global.list_key("system_browser", "", ""), "system_browser", "systems list key ignores the home title")
	assert_eq(Global.list_key("system_browser", "GBA", ""), "system_browser", "systems list key ignores the last system opened")
	assert_eq(Global.list_key("android_apps", "ANDROID", ""), "android_apps", "one key for the app list")
	assert_eq(Global.list_key("file_browser", "", "/Storage"), "/storage", "file browser keeps its folder key")

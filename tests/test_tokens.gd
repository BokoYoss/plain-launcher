extends "res://tests/test_case.gd"

const FakePlugin = preload("res://tests/fakes/fake_plugin.gd")

var root: String
var saved_root
var plugin

func before_each():
	saved_root = Global.root_path
	root = ProjectSettings.globalize_path("user://tokens_root")
	DirAccess.make_dir_recursive_absolute(root + "/Roms")
	Global.root_path = root
	Global.subscreen = ""
	Launcher.forget_intents()
	plugin = FakePlugin.new()
	Platform._android_plugin = plugin

func after_each():
	Global.root_path = saved_root
	Launcher.forget_intents()

func _rom(name: String, contents: String = "") -> String:
	var path = root + "/Roms/" + name
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(contents)
	f.close()
	return path

func _launch(intent: Dictionary, game: String) -> Dictionary:
	Launcher.save_custom_intent("testemu", intent)
	Launcher.launch_with_settings({"EMULATOR": "testemu", "CORE": "mgba"}, game)
	return JSON.parse_string(plugin.calls_to("launchIntent").back())

func test_tokens_expand_inside_nested_values():
	var tokens = {"{game}": "/r/a.gba", "{core}": "mgba"}
	var expanded = Launcher.expand_tokens({"data": "{game}", "extras": {"list": ["-r", "{core}"], "flag": true}}, tokens)
	assert_eq(expanded, {"data": "/r/a.gba", "extras": {"list": ["-r", "mgba"], "flag": true}}, "expanded")

func test_whole_numbers_stay_integers():
	var expanded = Launcher.expand_tokens({"n": 5.0, "f": 1.5}, {})
	assert_eq(typeof(expanded.n), TYPE_INT, "whole number becomes int")
	assert_eq(JSON.stringify(expanded), '{"f":1.5,"n":5}', "sent without .0")

func test_user_id_comes_from_data_path():
	assert_eq(Launcher.user_id_from_path("/data/user/10/org.plain.launcher/files"), 10, "secondary user")
	assert_eq(Launcher.user_id_from_path("/home/me/.local/share/godot"), 0, "defaults to 0")

func test_name_and_folder_tokens():
	var game = _rom("Deus Ex (USA).iso")
	var sent = _launch({"componentPackage": "com.emu", "extras": {"b": "{basename}", "f": "{filename}", "d": "{game_dir}"}}, game)
	assert_eq(sent.extras, {"b": "Deus Ex (USA)", "f": "Deus Ex (USA).iso", "d": root + "/Roms"}, "file tokens")
	assert_eq(sent.get("gamePath"), game, "game path passed for {game_uri}")

func test_data_tokens_use_user_paths():
	var sent = _launch({"componentPackage": "com.emu", "extras": {"core": "{data_dir}/cores", "cfg": "{external_storage}/x.cfg"}}, _rom("a.gba"))
	assert_eq(sent.extras.core, "/data/user/0/com.emu/cores", "data dir")
	assert_eq(sent.extras.cfg, "/storage/emulated/0/x.cfg", "external storage")

func test_game_contents_read_only_when_used():
	var game = _rom("Portal 2.steam", "  620\n")
	var tokens = Launcher.token_values({"extras": {"id": "{game}"}}, game, "", "com.emu")
	assert_false(tokens.has("{game_contents}"), "not read when unused")
	var sent = _launch({"componentPackage": "com.emu", "extras": {"app_id": {"type": "int", "value": "{game_contents}"}}}, game)
	assert_eq(sent.extras.app_id, {"type": "int", "value": "620"}, "contents trimmed, typed for the plugin")

func test_game_contents_is_capped():
	var game = _rom("big.bin", "a".repeat(Launcher.GAME_CONTENTS_MAX_BYTES * 3))
	assert_eq(Launcher.read_game_contents(game).length(), Launcher.GAME_CONTENTS_MAX_BYTES, "read is capped")

func test_typed_extras_reach_plugin_with_json_types():
	var sent = _launch({"componentPackage": "com.emu", "type": "application/zip", "categories": ["a.b"], "extras": {"resumeState": false, "count": 3, "params": ["-r", "{basename}"]}}, _rom("PCSB00001.vpk"))
	assert_eq(typeof(sent.extras.resumeState), TYPE_BOOL, "bool kept")
	assert_true(plugin.calls_to("launchIntent").back().contains('"count":3,'), "int sent without .0")
	assert_eq(sent.extras.params, ["-r", "PCSB00001"], "array expanded")
	assert_eq(sent.type, "application/zip", "mime passed")
	assert_eq(sent.categories, ["a.b"], "categories passed")

func test_saf_uri_for_sd_card_and_internal_storage():
	assert_eq(Launcher.saf_uri("/storage/9A7C-056B/Roms/PS2/Deus Ex - The Conspiracy (USA).iso"), "content://com.android.externalstorage.documents/tree/9A7C-056B%3ARoms%2FPS2/document/9A7C-056B%3ARoms%2FPS2%2FDeus%20Ex%20-%20The%20Conspiracy%20(USA).iso", "sd card")
	assert_eq(Launcher.saf_uri("/storage/emulated/0/ROMs/nds/Pokémon & Co.nds"), "content://com.android.externalstorage.documents/tree/primary%3AROMs%2Fnds/document/primary%3AROMs%2Fnds%2FPok%C3%A9mon%20%26%20Co.nds", "internal storage, utf-8 and reserved chars")
	assert_eq(Launcher.saf_uri("/data/local/game.iso"), "", "not shared storage")

func test_shell_command_quotes_every_argument():
	assert_eq(Launcher.shell_command(["retroarch", "-L", "/cores/mgba_libretro.so", "/ROMS/Game Boy/Link's Awakening.gb"]), "'retroarch' '-L' '/cores/mgba_libretro.so' '/ROMS/Game Boy/Link'\\''s Awakening.gb'", "spaces and quotes survive the shell")

func test_env_tokens_read_the_environment():
	OS.set_environment("PLAIN_TEST_CORES", "/mnt/cores")
	assert_eq(Launcher.expand_env("{env:PLAIN_TEST_CORES}/mgba_libretro.so"), "/mnt/cores/mgba_libretro.so", "env value filled in")
	assert_eq(Launcher.expand_env("{env:PLAIN_TEST_MISSING}x"), "x", "missing env is empty")

func test_command_fills_game_and_core():
	OS.set_environment("PLAIN_TEST_CORES", "/mnt/cores")
	var game = _rom("Metroid.gba")
	var command = Launcher.command_for({"command": ["retroarch", "-L", "{env:PLAIN_TEST_CORES}/{core}_libretro.so", "{game}"]}, game, "mgba")
	assert_eq(command, ["retroarch", "-L", "/mnt/cores/mgba_libretro.so", game], "command expanded")

func _commands_for(platform: String) -> Dictionary:
	return Launcher.platform_commands([platform])

func test_each_platform_gets_its_own_retroarch():
	assert_eq(_commands_for("steamdeck").retroarch.command[0], "flatpak", "Steam Deck uses the Flatpak")
	assert_eq(_commands_for("windows").retroarch.command[0], "C:/RetroArch-Win64/retroarch.exe", "Windows uses the standalone exe")
	assert_eq(_commands_for("portmaster").retroarch.command[3], "{retroarch_config}", "PortMaster picks its RetroArch config")
	assert_false(_commands_for("portmaster").has("retroarch_flatpak"), "PortMaster skips desktop launchers")
	assert_true(_commands_for("linux").has("retroarch_flatpak"), "Linux offers the Flatpak too")

func test_own_retroarch_config_starts_as_a_copy():
	var system_config = root + "/system_retroarch.cfg"
	var f = FileAccess.open(system_config, FileAccess.WRITE)
	f.store_string("input_driver = \"udev\"\n")
	f.close()
	var own = root + "/Config/COMMON/retroarch.cfg"
	DirAccess.remove_absolute(own)
	assert_eq(Launcher.choose_retroarch_config(system_config, own, false), system_config, "handheld's config by default")
	assert_eq(Launcher.choose_retroarch_config(system_config, own, true), own, "own config when chosen")
	assert_eq(FileAccess.get_file_as_string(own), "input_driver = \"udev\"\n", "first use copies the handheld's settings")
	f = FileAccess.open(own, FileAccess.WRITE)
	f.store_string("changed\n")
	f.close()
	Launcher.choose_retroarch_config(system_config, own, true)
	assert_eq(FileAccess.get_file_as_string(own), "changed\n", "existing own config is kept")

func test_uninstalled_programs_are_hidden():
	assert_true(Launcher.command_available({"command": ["bash", "{game}"]}), "programs on PATH are available")
	assert_false(Launcher.command_available({"command": ["/no/such/emulator", "{game}"]}), "missing paths are hidden")
	assert_false(Launcher.command_available({"command": ["flatpak", "run", "org.example.NotInstalled", "{game}"]}), "missing flatpaks are hidden")
	assert_false(Launcher.command_available({"command": ["{env:PLAIN_TEST_UNSET_BIN}", "{game}"]}), "unset program is hidden")
	assert_false(Launcher.command_available({"command": []}), "empty command is hidden")

func test_launchers_find_the_first_installed_location():
	var installed = root + "/Emulators/emu.exe"
	DirAccess.make_dir_recursive_absolute(installed.get_base_dir())
	var f = FileAccess.open(installed, FileAccess.WRITE)
	f.store_string("")
	f.close()
	OS.set_environment("PLAIN_TEST_EMULATORS", root + "/Emulators")
	var found = Launcher.installed_command({"command": ["/no/such/emu.exe", "-f", "{game}"], "programs": ["/also/missing/emu.exe", "{env:PLAIN_TEST_EMULATORS}/emu.exe"], "systems": ["PS"]})
	OS.set_environment("PLAIN_TEST_EMULATORS", "")
	assert_eq(found.get("command", []), [installed, "-f", "{game}"], "uses the location that exists")
	assert_false(found.has("programs"), "editing shows just the found path")
	assert_true(Launcher.installed_command({"command": ["/no/such/emu.exe", "{game}"], "programs": ["/also/missing/emu.exe"]}).is_empty(), "hidden when none are installed")
	assert_eq(Launcher.installed_command({"command": ["bash", "{game}"]}).get("command", []), ["bash", "{game}"], "launchers without fallbacks work as before")

func test_windows_has_standalone_emulators():
	var commands = _commands_for("windows")
	for id in ["duckstation", "melonds", "azahar", "ryujinx", "mame", "flycast", "rmg", "gzdoom", "eden"]:
		assert_true(commands.has(id), id + " offered on Windows")
		assert_false(commands.get(id, {}).get("programs", []).is_empty(), id + " checks other install locations")

func test_every_platform_launcher_names_a_program():
	for platform in ["linux", "steamdeck", "windows", "portmaster"]:
		for id in Launcher.platform_commands([platform]):
			var command = Launcher.platform_commands([platform])[id].command
			assert_true(command.size() >= 2 and str(command[0]) != "", platform + "/" + id + " has a program and arguments")

func test_flatpak_launchers_can_reach_the_game():
	assert_eq(Launcher.flatpak_app(["flatpak", "run", "--filesystem=/run/media", "--filesystem={game_dir}", "net.pcsx2.PCSX2", "{game}"]), "net.pcsx2.PCSX2", "app id found after the options")
	for platform in ["linux", "steamdeck"]:
		var commands = Launcher.platform_commands([platform])
		for id in commands:
			var command = commands[id].command
			if command[0] == "flatpak":
				assert_true("--filesystem={game_dir}" in command and "--filesystem=/run/media" in command, platform + "/" + id + " shares the game folder and SD cards")

func test_32bit_cores_use_32bit_retroarch():
	var bin = root + "/bin"
	DirAccess.make_dir_recursive_absolute(bin)
	for name in ["retroarch", "retroarch32"]:
		var f = FileAccess.open(bin + "/" + name, FileAccess.WRITE)
		f.store_string("")
		f.close()
	var cores = {"arm32": 1, "arm64": 2}
	for name in cores:
		var f = FileAccess.open(root + "/" + name + "_libretro.so", FileAccess.WRITE)
		f.store_buffer(PackedByteArray([0x7f, 0x45, 0x4c, 0x46, cores[name], 1, 1, 0]))
		f.close()
	var game = root + "/game.gba"
	assert_eq(Launcher.matching_retroarch([bin + "/retroarch", "-f", "-L", root + "/arm32_libretro.so", game])[0], bin + "/retroarch32", "32-bit core runs in 32-bit RetroArch")
	assert_eq(Launcher.matching_retroarch([bin + "/retroarch", "-f", "-L", root + "/arm64_libretro.so", game])[0], bin + "/retroarch", "64-bit core unchanged")
	assert_eq(Launcher.matching_retroarch(["/usr/bin/mgba", root + "/arm32_libretro.so"])[0], "/usr/bin/mgba", "other programs unchanged")
	DirAccess.remove_absolute(bin + "/retroarch32")
	assert_eq(Launcher.matching_retroarch([bin + "/retroarch", "-L", root + "/arm32_libretro.so", game])[0], bin + "/retroarch", "no 32-bit RetroArch, nothing to switch to")

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
	AndroidInterface._android_plugin = plugin

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

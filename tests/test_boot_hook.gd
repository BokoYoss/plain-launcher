extends "res://tests/test_case.gd"

var dir = ""
var saved_env = {}

func before_each():
	dir = OS.get_user_data_dir().path_join("fake_boot")
	DirAccess.make_dir_recursive_absolute(dir.path_join("config/settings/general"))
	var func_sh = FileAccess.open(dir.path_join("func.sh"), FileAccess.WRITE)
	func_sh.store_string("BASE=\"" + dir.path_join("config") + "\"\nGET_VAR() { [ -r \"$BASE/$2\" ] && cat \"$BASE/$2\"; return 0; }\n")
	func_sh.close()
	BootHook.muos_func = dir.path_join("func.sh")
	BootHook.root = dir.path_join("root")
	for name in ["PLAIN_LAUNCHER_PLATFORM", "PLAIN_LAUNCHER_CFW"]:
		saved_env[name] = OS.get_environment(name)
	OS.set_environment("PLAIN_LAUNCHER_PLATFORM", "portmaster")

func after_each():
	BootHook.muos_func = BootHook.MUOS_FUNC
	BootHook.root = ""
	for name in saved_env:
		OS.set_environment(name, saved_env[name])
	OS.execute("rm", ["-rf", dir])

func _write(path: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path

func _root(path: String, text: String):
	_write(BootHook.root + path, text)

func test_muos_reads_device_startup():
	OS.set_environment("PLAIN_LAUNCHER_CFW", "muOS")
	assert_eq(BootHook.kind(), "muos", "muOS found")
	assert_false(BootHook.enabled(), "off until Device Startup is Last Game")
	var startup = _write(dir.path_join("config/" + BootHook.STARTUP_VAR), "last")
	assert_false(BootHook.enabled(), "still off until Plain Launcher was the last thing opened")
	var entry = _write(dir.path_join("Plain Launcher.cfg"), "Plain Launcher\nexternal\nports\n")
	_write(dir.path_join("config/" + BootHook.LAST_PLAY_VAR), entry)
	assert_true(BootHook.enabled(), "on once both are")
	_write(entry, "Kerners\nexternal\nports\n")
	assert_false(BootHook.enabled(), "another port would boot")
	assert_eq(FileAccess.get_file_as_string(startup), "last", "only read")
	assert_eq(BootHook.steps()[1], "Set Device Startup to Last Game", "explains the muOS setting")

func test_older_muos_reads_device_startup():
	OS.set_environment("PLAIN_LAUNCHER_CFW", "muOS")
	BootHook.muos_func = dir.path_join("missing.sh")
	_root(BootHook.LEGACY_LAST_PLAY, "")
	_root(BootHook.LEGACY_STARTUP, "launcher\n")
	assert_eq(BootHook.kind(), "muos", "2410 layout found")
	assert_false(BootHook.enabled(), "launcher startup")
	_root(BootHook.LEGACY_STARTUP, "last\n")
	assert_false(BootHook.enabled(), "Last Game, but nothing opened yet")
	_root(BootHook.LEGACY_LAST_PLAY, "Plain Launcher\nexternal\nExternal - Ports\n")
	assert_true(BootHook.enabled(), "Last Game and Plain Launcher last opened")
	assert_eq(FileAccess.get_file_as_string(BootHook.root + BootHook.LEGACY_LAST_PLAY), "Plain Launcher\nexternal\nExternal - Ports\n", "last-played only read")

func test_rocknix_reads_the_boot_game():
	OS.set_environment("PLAIN_LAUNCHER_CFW", "ROCKNIX")
	assert_eq(BootHook.kind(), "rocknix", "ROCKNIX found")
	assert_false(BootHook.enabled(), "no config yet")
	_root(BootHook.ROCKNIX_CONFIG, "audio.volume=80\nglobal.bootgame.path=/storage/roms/gb/Tetris.gb\n")
	assert_false(BootHook.enabled(), "another game boots")
	_root(BootHook.ROCKNIX_CONFIG, "audio.volume=80\nglobal.bootgame.path=/storage/roms/ports/Plain Launcher.sh\nglobal.bootgame.cmd=x\n")
	assert_true(BootHook.enabled(), "Plain Launcher boots")
	assert_eq(BootHook.steps()[2], "Choose Launch this game at startup", "explains EmulationStation's option")

func test_knulli_reads_the_boot_game():
	OS.set_environment("PLAIN_LAUNCHER_CFW", "knulli")
	assert_eq(BootHook.kind(), "knulli", "Knulli found")
	_root(BootHook.KNULLI_CONFIG, "global.bootgame.path=/userdata/roms/ports/Plain Launcher.sh\n")
	assert_true(BootHook.enabled(), "Plain Launcher boots")

func test_boot_game_parsing():
	assert_eq(BootHook.boot_game("a=1\n  global.bootgame.path = /roms/ports/Plain Launcher.sh \n"), "/roms/ports/Plain Launcher.sh", "found among other settings")
	assert_eq(BootHook.boot_game("#global.bootgame.path=/x\n"), "", "commented out")
	assert_false(BootHook.launches_us(""), "nothing set")

func test_only_offered_where_it_works():
	OS.set_environment("PLAIN_LAUNCHER_CFW", "dArkOS")
	assert_false(BootHook.supported(), "dArkOS has no clean hook")
	OS.set_environment("PLAIN_LAUNCHER_CFW", "knulli")
	OS.set_environment("PLAIN_LAUNCHER_PLATFORM", "")
	assert_false(BootHook.supported(), "PortMaster only")

func test_host_commands_drop_preloaded_libraries():
	var saved = OS.get_environment("LD_PRELOAD")
	OS.set_environment("LD_PRELOAD", "/nonexistent/crusty.so")
	var seen = Launcher.run_host("echo \"${LD_PRELOAD:-clean} $1\"")
	OS.set_environment("LD_PRELOAD", saved)
	assert_eq(seen, "clean", "muOS scripts never run with PortMaster's graphics libraries, and nothing expands early")

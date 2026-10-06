extends "res://tests/test_case.gd"

const StorageSetup = preload("res://scenes/storage_setup.gd")

const FakeNavigator = preload("res://tests/fakes/fake_navigator.gd")

var root: String

func before_each():
	root = ProjectSettings.globalize_path("user://startup_root")
	_remove_recursive(root)
	Global.subscreen = ""
	Global.root_path = null
	Global.waiting_root_path = ""
	Global.HIDDEN_LIST.clear()
	var nav = _nav()
	if nav.get_script() != FakeNavigator:
		nav.set_script(FakeNavigator)
	nav.pushed = []

func after_each():
	Global.root_path = root
	Global.waiting_root_path = ""

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

func test_missing_saved_root_waits_instead_of_setup():
	Global.waiting_root_path = root
	Navigator.go_to_main()
	assert_eq(_nav().pushed, ["storage_wait"], "screens pushed")

func test_no_saved_root_goes_to_setup():
	Navigator.go_to_main()
	assert_eq(_nav().pushed, ["confirm_set"], "screens pushed")

func test_storage_wait_continues_once_root_appears():
	Global.waiting_root_path = root
	var screen = load("res://scenes/subscreens/storage_wait.gd").new()
	assert_false(screen.check_storage(), "not ready while missing")
	assert_eq(_nav().pushed, [], "nothing pushed while waiting")
	write_json(root + "/Config/COMMON/lists.json", {"hidden": ["/roms/hidden.gba"]})
	DirAccess.make_dir_recursive_absolute(root + "/Games")
	assert_true(screen.check_storage(), "ready once mounted")
	screen.free()
	assert_eq(Global.root_path, root, "root restored")
	assert_eq(Global.waiting_root_path, "", "no longer waiting")
	assert_true(Global.HIDDEN_LIST.has("/roms/hidden.gba"), "hidden list loaded from storage")
	assert_eq(_nav().pushed, ["system_browser"], "screens pushed")

func test_setup_keeps_existing_configs():
	write_json(root + "/Config/GBA/choices.json", {"EMULATOR": ["my_custom_emu"]})
	StorageSetup.copy_builtin_contents(DirAccess.open(root), "GBA")
	assert_eq(read_json(root + "/Config/GBA/choices.json"), {"EMULATOR": ["my_custom_emu"]}, "existing choices.json untouched")
	assert_true(FileAccess.file_exists(root + "/Config/GBA/compatibility_paths.txt"), "missing bundled file copied")

func test_storage_wait_dots_cycle():
	var screen = load("res://scenes/subscreens/storage_wait.gd").new()
	screen.start_time = 1000
	var titles = [0, 400, 800, 1200, 1600].map(func(t): return screen.waiting_title(1000 + t))
	screen.free()
	assert_eq(titles, ["Waiting for storage.", "Waiting for storage..", "Waiting for storage...", "Waiting for storage.", "Waiting for storage.."], "dot cycle")

func test_storage_wait_countdown():
	var screen = load("res://scenes/subscreens/storage_wait.gd").new()
	screen.hold_start = 1000
	var counts = [0, 999, 1000, 4000, 4999, 5000].map(func(t): return screen.countdown_remaining(1000 + t))
	screen.free()
	assert_eq(counts, [5, 5, 4, 1, 1, 0], "countdown")

func test_reconfigure_goes_to_storage_select():
	Global.waiting_root_path = root
	var screen = load("res://scenes/subscreens/storage_wait.gd").new()
	screen.reconfigure()
	screen.free()
	assert_eq(Global.waiting_root_path, "", "no longer waiting")
	assert_eq(_nav().pushed, ["confirm_set"], "screens pushed")

func test_new_bundled_systems_added_for_existing_users():
	DirAccess.make_dir_recursive_absolute(root + "/Config/GBA")
	var added = StorageSetup.add_missing_systems(DirAccess.open(root))
	assert_true("STEAM" in added, "steam system created")
	assert_false("GBA" in added, "existing system left alone")
	assert_true(DirAccess.dir_exists_absolute(root + "/Games/STEAM"), "steam games folder")
	assert_true(FileAccess.file_exists(root + "/Config/STEAM/choices.json"), "steam choices copied")
	assert_eq(StorageSetup.add_missing_systems(DirAccess.open(root)), [], "nothing to add the second time")

extends "res://tests/test_case.gd"

var root: String

func before_each():
	root = ProjectSettings.globalize_path("user://dirs_root")
	DirAccess.make_dir_recursive_absolute(root + "/GBA")
	for f in DirAccess.get_files_at(root + "/GBA"):
		DirAccess.remove_absolute(root + "/GBA/" + f)
	for name in ["a.gba", "b.gba"]:
		FileAccess.open(root + "/GBA/" + name, FileAccess.WRITE).close()
	Global.clear_dir_cache()

func test_listings_read_for_existing_and_missing_dirs():
	var listings = Global.read_dir_listings([root + "/GBA", root + "/missing"])
	assert_eq(Array(listings[root + "/GBA"].files), ["a.gba", "b.gba"], "files listed")
	assert_eq(listings[root + "/missing"], null, "missing dir marked")

func test_prewarmed_listing_is_served_from_cache():
	Global.merge_dir_listings(Global.read_dir_listings([root + "/GBA"]))
	DirAccess.remove_absolute(root + "/GBA/b.gba")
	var files = Global._read_dir_cached(DirAccess.open(root + "/GBA"), false)
	assert_eq(Array(files), ["a.gba", "b.gba"], "listing came from the prewarmed cache")

func test_prewarm_does_not_replace_existing_listing():
	var dir = DirAccess.open(root + "/GBA")
	Global._read_dir_cached(dir, false)
	var stale = Global.read_dir_listings([root + "/GBA"])
	stale[root + "/GBA"].files = PackedStringArray(["old.gba"])
	Global.merge_dir_listings(stale)
	assert_eq(Array(Global._read_dir_cached(dir, false)), ["a.gba", "b.gba"], "listing read by the screen wins")

func test_missing_dirs_are_remembered_until_refresh():
	assert_false(Global._dir_has_files(root + "/missing"), "missing dir has no files")
	assert_true(Global._missing_dirs.has(root + "/missing"), "remembered as missing")
	Global.merge_dir_listings(Global.read_dir_listings([root + "/other_missing"]))
	assert_true(Global._missing_dirs.has(root + "/other_missing"), "prewarm records missing dirs")
	Global._prewarm_done = true
	Global.clear_dir_cache()
	assert_true(Global._missing_dirs.is_empty(), "refresh forgets missing dirs")
	assert_false(Global._prewarm_done, "refresh allows another prewarm")

func test_placeholder_files_do_not_count_as_games():
	DirAccess.make_dir_recursive_absolute(root + "/PLACEHOLDER")
	FileAccess.open(root + "/PLACEHOLDER/systeminfo.txt", FileAccess.WRITE).close()
	assert_false(Global._dir_has_files(root + "/PLACEHOLDER", ["gba"]), "only systeminfo.txt")
	assert_true(Global._dir_has_files(root + "/GBA", ["gba"]), "real games")
	assert_true(Global._dir_has_files(root + "/PLACEHOLDER"), "no extension list counts any file")
	assert_false(Global.is_game_file("systeminfo.txt", ["gba", "zip"]), "txt not a game")

func test_neo_geo_arcade_folder_not_scanned_for_pocket():
	var pocket = FileAccess.get_file_as_string(Global.get_compat_paths_filepath("NGP")).split("\n")
	assert_false("/ROMs/neogeo" in pocket, "arcade sets stay out of Neo Geo Pocket")
	assert_true("/ROMs/ngpc" in pocket, "ES-DE pocket color folder scanned")
	assert_true(Global.get_compat_paths_filepath("NGP").begins_with("res://"), "built-in list used so fixes reach existing setups")

func _named(filename: String, clean: String) -> option:
	var opt = option.new_option(filename)
	opt.clean = clean
	return opt

func test_lists_sort_by_display_name_after_specials():
	var sorted = Global.sort_after_specials([_named("NES", "Nintendo Entertainment System"), _named("GENESIS", "Sega Genesis"), _named("RECENT", "Recent"), _named("GB", "Game Boy")], ["RECENT"])
	assert_eq(sorted.map(func(o): return o.clean), ["Recent", "Game Boy", "Nintendo Entertainment System", "Sega Genesis"], "specials first, then by shown name")

func test_retroarch_not_relaunched_into_its_running_process():
	var intents = Launcher.load_intents()
	for name in ["retroarch", "retroarch64", "retroarch32"]:
		assert_false("FLAG_ACTIVITY_CLEAR_TASK" in intents[name].get("flags", []), name + " would hang on its splash screen")

func test_systems_sort_by_alias_shown_on_screen():
	var saved = Global.ALIAS_MAP
	Global.set_active_alias_map({"genesis": "Sega Genesis", "gb": "Game Boy", "nes": "Nintendo Entertainment System"})
	var sorted = Global.sort_after_specials([_named("NES", "NES"), _named("GENESIS", "GENESIS"), _named("GB", "GB")], [])
	Global.set_active_alias_map(saved)
	assert_eq(sorted.map(func(o): return o.filename), ["GB", "NES", "GENESIS"], "Sega Genesis sorts under S")

func test_stick_scroll_has_a_speed_limit():
	assert_eq(Global.stick_repeat_ms(0.1), Global.STICK_REPEAT_FAST_MS, "full tilt capped so covers can keep up")
	assert_eq(Global.stick_repeat_ms(1.0), Global.STICK_REPEAT_SLOW_MS, "light tilt is slow")
	assert_true(Global.stick_repeat_ms(0.5) < Global.STICK_REPEAT_SLOW_MS and Global.stick_repeat_ms(0.5) > Global.STICK_REPEAT_FAST_MS, "speeds up with tilt")

func test_same_game_from_two_folders_is_listed_once():
	var first = option.new()
	first.filename = "Golden Sun (USA).gba"
	var same = option.new()
	same.filename = "golden sun (usa).GBA"
	var other = option.new()
	other.filename = "Metroid Fusion (USA).gba"
	var unique = Global.unique_by_filename([first, same, other])
	assert_eq(unique.size(), 2, "duplicate dropped")
	assert_eq(unique[0], first, "first folder wins")

func test_desktop_setup_always_uses_a_plainlauncher_folder():
	var Setup = preload("res://scenes/storage_setup.gd")
	assert_eq(Setup.desktop_root("/home/me"), "/home/me/PlainLauncher", "home folder gets its own PlainLauncher folder")
	assert_eq(Setup.desktop_root("/home/me/PlainLauncher"), "/home/me/PlainLauncher", "picking the folder itself is kept")
	assert_eq(Setup.desktop_root("D:/Games"), "D:/Games/PlainLauncher", "Windows drives too")

func test_found_paths_lists_existing_automatic_folders():
	var base = ProjectSettings.globalize_path("user://found_paths")
	DirAccess.make_dir_recursive_absolute(base + "/es/zztest")
	DirAccess.make_dir_recursive_absolute(base + "/mine")
	var saved_env = OS.get_environment("PLAIN_LAUNCHER_ZZTEST_PATHS")
	var saved_root = Global.root_path
	Global.root_path = base + "/root"
	DirAccess.make_dir_recursive_absolute(base + "/root/Config/ZZTEST")
	var paths = FileAccess.open(base + "/root/Config/ZZTEST/paths.txt", FileAccess.WRITE)
	paths.store_string(base + "/mine")
	paths.close()
	OS.set_environment("PLAIN_LAUNCHER_ZZTEST_PATHS", base + "/es/zztest:" + base + "/missing:" + base + "/mine")
	var found = Global.found_paths("ZZTEST")
	OS.set_environment("PLAIN_LAUNCHER_ZZTEST_PATHS", saved_env)
	Global.root_path = saved_root
	OS.execute("rm", ["-rf", base])
	assert_eq(found, [base + "/es/zztest"], "only folders that exist, without the ones you added yourself")

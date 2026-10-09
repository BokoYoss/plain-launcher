extends "res://tests/test_case.gd"

const ArtScraper = preload("res://scenes/art_scraper.gd")

var root: String

func before_each():
	root = ProjectSettings.globalize_path("user://art_root")
	DirAccess.make_dir_recursive_absolute(root)
	for f in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root + "/" + f)
	for f in DirAccess.get_files_at(root + "/thumbs"):
		DirAccess.remove_absolute(root + "/thumbs/" + f)
	if Global.cover_art == null:
		Global.cover_art = Sprite2D.new()
		Global.drop_shadow = Sprite2D.new()
		Global.border = Sprite2D.new()
	Global.cover_art.texture = null
	Global.img_texture_override = null
	Global.option_list = []
	Global.option_selection = 0
	Global.clear_art_cache()
	Global._art_wanted_path = ""

func after_each():
	if Global._art_loading_task >= 0:
		WorkerThreadPool.wait_for_task_completion(Global._art_loading_task)
	Global._art_loading_path = ""
	Global._art_loading_task = -1
	Global.option_list = []

func _png(name: String, size: int = 4) -> String:
	var path = root + "/" + name + ".png"
	Image.create(size, size, false, Image.FORMAT_RGBA8).save_png(path)
	return path

func _image(size: int = 4) -> Image:
	return Image.create(size, size, false, Image.FORMAT_RGBA8)

func _texture(size: int = 4) -> ImageTexture:
	return ImageTexture.create_from_image(_image(size))

func test_cached_cover_is_shown_without_loading():
	var path = _png("a")
	var texture = _texture()
	Global.cache_art(path, texture)
	Global.refresh_art(path)
	assert_true(Global.cover_art.texture == texture, "cached texture applied")
	assert_true(Global.cover.visible, "cover visible")
	assert_eq(Global._art_loading_path, "", "no background load")

func test_uncached_cover_loads_while_previous_stays_visible():
	var previous = _texture()
	Global.apply_cover_texture(previous)
	var path = _png("a")
	Global.refresh_art(path)
	assert_eq(Global._art_loading_path, path, "background load started")
	assert_true(Global.cover_art.texture == previous, "previous cover kept until new one is ready")

func test_only_newest_selection_loads_after_busy():
	var a = _png("a")
	var b = _png("b")
	var c = _png("c")
	Global._art_loading_path = a
	Global.refresh_art(b)
	Global.refresh_art(c)
	assert_eq(Global._art_loading_path, a, "one load at a time")
	Global._on_art_loaded(a, _image())
	assert_eq(Global._art_loading_path, c, "skips to the newest selection")
	assert_false(Global.art_known(b), "scrolled-past cover not loaded")

func test_stale_load_result_is_cached_but_not_shown():
	var old_path = _png("old")
	var new_path = _png("new")
	Global._art_wanted_path = new_path
	Global._on_art_loaded(old_path, _image())
	assert_true(Global.cover_art.texture == null, "stale result not shown")
	assert_true(Global.cached_art(old_path) != null, "stale result kept for later")

func test_wanted_load_result_is_shown():
	var path = _png("a", 8)
	Global._art_wanted_path = path
	Global._on_art_loaded(path, _image(8))
	assert_true(Global.cover_art.texture != null, "texture applied")
	assert_eq(Global.cover_art.texture.get_size(), Vector2(8, 8), "loaded image used")

func test_failed_image_is_not_retried_until_changed():
	var path = _png("broken")
	Global.apply_cover_texture(_texture())
	Global._art_wanted_path = path
	Global._on_art_loaded(path, null)
	assert_true(Global.cover_art.texture == null, "cover cleared for broken image")
	assert_eq(Global.next_art_to_load(), "", "broken image not retried")
	Global._art_failed[path] -= 10
	assert_eq(Global.next_art_to_load(), path, "retried once the file changes")

func test_cache_evicts_least_recently_used():
	var paths = []
	for i in range(Global.ART_CACHE_SIZE + 1):
		paths.append(_png("p%d" % i))
		Global.cache_art(paths[i], _texture())
		if i == 1:
			Global.cached_art(paths[0])
	assert_true(Global.cached_art(paths[0]) != null, "recently used entry kept")
	assert_eq(Global.cached_art(paths[1]), null, "least recently used entry evicted")
	assert_eq(Global._art_cache.size(), Global.ART_CACHE_SIZE, "cache size capped")

func test_replaced_image_is_reloaded():
	var path = _png("a")
	Global.cache_art(path, _texture())
	Global._art_cache[path].mtime -= 10
	assert_eq(Global.cached_art(path), null, "changed file invalidates cache")

func test_neighbors_load_after_selection():
	var saved_root = Global.root_path
	Global.root_path = root
	DirAccess.make_dir_recursive_absolute(root + "/Imgs/GBA")
	var items = []
	for name in ["zero", "one", "two", "three", "four"]:
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(root + "/Imgs/GBA/" + name + ".png")
		var opt = option.new()
		opt.filename = name + ".gba"
		opt.system = "GBA"
		items.append(opt)
	Global.option_list = items
	Global.option_selection = 1
	var paths = items.map(func(o): return Global.get_image_path(o))
	Global._art_wanted_path = paths[1]
	var order = []
	for i in range(4):
		var next = Global.next_art_to_load()
		order.append(paths.find(next))
		Global.cache_art(next, _texture())
	Global.root_path = saved_root
	assert_eq(order, [1, 2, 0, 3], "selection first, then +1, -1, +2")

func test_large_cover_is_shrunk_to_box_and_saved_as_thumbnail():
	var path = _png("big", 400)
	var thumb = root + "/thumbs/big.webp"
	var image = Global.load_cover_image(path, thumb, Vector2i(100, 50))
	assert_eq(image.get_size(), Vector2i(50, 50), "fits inside the box")
	assert_true(FileAccess.file_exists(thumb), "thumbnail written")

func test_saved_thumbnail_is_used_instead_of_source():
	var path = _png("big", 400)
	var thumb = root + "/thumbs/big.webp"
	Global.load_cover_image(path, thumb, Vector2i(50, 50))
	DirAccess.remove_absolute(path)
	var image = Global.load_cover_image(path, thumb, Vector2i(50, 50))
	assert_true(image != null, "loaded without the source file")
	if image != null:
		assert_eq(image.get_size(), Vector2i(50, 50), "thumbnail size")

func test_small_cover_is_not_thumbnailed():
	var path = _png("small", 20)
	var thumb = root + "/thumbs/small.webp"
	var image = Global.load_cover_image(path, thumb, Vector2i(100, 100))
	assert_eq(image.get_size(), Vector2i(20, 20), "original size kept")
	assert_false(FileAccess.file_exists(thumb), "no thumbnail written")

func test_thumbnail_name_changes_with_art_and_size():
	var path = _png("a")
	var first = Global.thumbnail_path(path, Vector2i(100, 100))
	assert_true(first != Global.thumbnail_path(path, Vector2i(200, 100)), "cover size change makes a new thumbnail")
	assert_true(first != Global.thumbnail_path(root + "/other.png", Vector2i(100, 100)), "different art, different thumbnail")

func test_art_box_follows_cover_size():
	var saved = [Global.window_width, Global.window_height]
	Global.window_width = 1920
	Global.window_height = 1080
	var cover_size = Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE)
	var box = Global.art_box_size()
	Global.window_width = saved[0]
	Global.window_height = saved[1]
	if cover_size.x < 1.0:
		assert_eq(box, Vector2i(Vector2(1920, 1080) * cover_size), "box is the cover area")
	else:
		assert_true(box.x >= 1920, "full-screen covers use at least the screen")

func test_missing_cover_is_not_rechecked_until_forgotten():
	var path = root + "/later.png"
	assert_false(Global.art_exists(path), "missing at first")
	_png("later")
	assert_false(Global.art_exists(path), "remembered as missing")
	Global.forget_missing_art(path)
	assert_true(Global.art_exists(path), "found once forgotten")

func test_missing_cover_is_rechecked_after_ttl():
	var path = root + "/later.png"
	Global.art_exists(path)
	_png("later")
	Global._art_missing[path] -= Global.ART_MISSING_TTL_MS + 1
	assert_true(Global.art_exists(path), "rechecked after the TTL")

func test_neighbor_without_cover_is_skipped():
	var saved_root = Global.root_path
	Global.root_path = root
	DirAccess.make_dir_recursive_absolute(root + "/Imgs/NOCOVER")
	var items = []
	for name in ["zero", "one", "two", "three"]:
		if name != "two":
			Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(root + "/Imgs/NOCOVER/" + name + ".png")
		var opt = option.new()
		opt.filename = name + ".gba"
		opt.system = "NOCOVER"
		items.append(opt)
	Global.option_list = items
	Global.option_selection = 1
	var paths = items.map(func(o): return Global.get_image_path(o))
	Global._art_wanted_path = paths[1]
	Global.cache_art(paths[1], _texture())
	var next = Global.next_art_to_load()
	Global.root_path = saved_root
	assert_eq(paths.find(next), 0, "coverless +1 neighbor skipped, -1 loaded")
	assert_true(Global._art_missing.has(paths[2]), "coverless neighbor remembered")

func _system_item(system: String) -> option:
	var item = option.new_option(system)
	item.system = system
	return item

func test_custom_system_art_wins_and_toggle_hides():
	var saved = Settings._data.get(Settings.CFG_VISUAL_SYSTEM_ART)
	var saved_root = Global.root_path
	Global.root_path = root
	var item = _system_item("ZZTEST")
	var builtin = str(Global.root_path + Global.PATH_IMAGES + "ZZTEST.png").replace("//", "/")
	var custom = Global.custom_art_path(item)
	DirAccess.make_dir_recursive_absolute(custom.get_base_dir())
	Settings._data[Settings.CFG_VISUAL_SYSTEM_ART] = true
	assert_eq(Global.get_image_path(item), builtin, "built-in without custom art")
	FileAccess.open(custom, FileAccess.WRITE).store_string("x")
	Global.forget_missing_art(custom)
	assert_eq(Global.get_image_path(item), custom, "custom art takes precedence")
	Settings._data[Settings.CFG_VISUAL_SYSTEM_ART] = false
	assert_eq(Global.get_image_path(item), "", "system art off")
	Global.force_cover = true
	assert_eq(Global.get_image_path(item), custom, "system options always show art")
	Global.force_cover = false
	DirAccess.remove_absolute(custom)
	Global.root_path = saved_root
	if saved == null:
		Settings._data.erase(Settings.CFG_VISUAL_SYSTEM_ART)
	else:
		Settings._data[Settings.CFG_VISUAL_SYSTEM_ART] = saved

func test_app_art_uses_package_names():
	var saved_root = Global.root_path
	Global.root_path = root
	var app = option.new_option("Syncthing")
	app.system = "ANDROID"
	app.absolute_path = "com.github.syncthing"
	assert_true(Global.get_image_path(app).ends_with("/ANDROID/com.github.syncthing.png"), "art named after the package")
	var art_dir = root + "/ANDROIDTEST"
	DirAccess.make_dir_recursive_absolute(art_dir)
	FileAccess.open(art_dir + "/Syncthing.png", FileAccess.WRITE).close()
	assert_eq(Global.move_app_art(art_dir, {"Syncthing": "com.github.syncthing", "Missing": "com.x"}), 1, "existing label art moved")
	assert_true(FileAccess.file_exists(art_dir + "/com.github.syncthing.png"), "renamed to package")
	DirAccess.remove_absolute(art_dir + "/com.github.syncthing.png")
	Global.root_path = saved_root

func test_whole_system_scrape_finds_roms_in_extra_folders():
	var saved_root = Global.root_path
	Global.root_path = root
	var extra = root + "/es_roms/zztest"
	DirAccess.make_dir_recursive_absolute(extra)
	DirAccess.make_dir_recursive_absolute(root + "/Games/ZZTEST")
	DirAccess.make_dir_recursive_absolute(root + "/Config/ZZTEST")
	for file in [extra + "/Metroid.gba", extra + "/gamelist.xml", root + "/Games/ZZTEST/Zelda.gba"]:
		FileAccess.open(file, FileAccess.WRITE).close()
	var paths = FileAccess.open(root + "/Config/ZZTEST/paths.txt", FileAccess.WRITE)
	paths.store_string(extra + "\n" + extra)
	paths.close()
	write_json(root + "/Config/ZZTEST/config.json", {"EXTENSIONS": ["gba"]})
	var system = option.new()
	system.is_dir = true
	system.system = "ZZTEST"
	if Global.clean_regex == null:
		Global.clean_regex = RegEx.create_from_string(Global.CLEAN_PATTERN)
	var names = ArtScraper.games_for(system).map(func(o): return o.filename)
	names.sort()
	Global.root_path = saved_root
	OS.execute("rm", ["-rf", root + "/es_roms", root + "/Games", root + "/Config"])
	assert_eq(names, ["Metroid.gba", "Zelda.gba"], "ROMs from every folder, once each, without other files")

func test_skip_games_with_art_counts_other_art_folders():
	var saved_root = Global.root_path
	Global.root_path = root
	var media = root + "/downloaded_media/zztest/covers"
	DirAccess.make_dir_recursive_absolute(media)
	DirAccess.make_dir_recursive_absolute(root + "/Imgs/ZZTEST")
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(media + "/Metroid.png")
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(root + "/Imgs/ZZTEST/Zelda.png")
	Global._compat_art_dirs["ZZTEST"] = [media]
	var results = {}
	for name in ["Metroid", "Zelda", "Kirby"]:
		var game = option.new()
		game.filename = name + ".gba"
		game.system = "ZZTEST"
		results[name] = ArtScraper.already_has_art(game)
	Global._compat_art_dirs.erase("ZZTEST")
	Global.root_path = saved_root
	OS.execute("rm", ["-rf", root + "/downloaded_media", root + "/Imgs"])
	assert_eq(results, {"Metroid": true, "Zelda": true, "Kirby": false}, "art from ES-DE or EmuDeck media counts as having art")

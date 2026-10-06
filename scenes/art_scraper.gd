extends RefCounted

const SS_API_BASE = "https://jk7vbrz6o4.execute-api.us-west-2.amazonaws.com/prod/screenscraper"
const SGDB_SEARCH_BASE = "https://www.steamgriddb.com/api/v2/search/autocomplete/"
const SGDB_GRIDS_BASE = "https://www.steamgriddb.com/api/v2/grids/game/"
const STEP_SECONDS = 0.5

const SYSTEM_IDS: Dictionary = {
	"NES": 3, "SNES": 4, "N64": 14, "GB": 9, "GBC": 10, "GBA": 12,
	"NDS": 15, "N3DS": 17, "PS": 57, "PS2": 58, "PSP": 61,
	"GENESIS": 1, "SEGACD": 20, "SATURN": 22, "DREAMCAST": 23,
	"GAMECUBE": 13, "WII": 16, "NEOGEO": 142, "PCE": 31,
	"ARCADE": 75, "MASTERSYSTEM": 2, "NGP": 25, "SWITCH": 225,
}

var panel
var item
var game_list: Array = []
var found_count = 0
var skipped_count = 0
var failed_count = 0
var current_index = 0
var current_name = ""
var status = ""
var scraping = false
var done = false
var http_search: HTTPRequest
var http_image: HTTPRequest
var http_extra: HTTPRequest

func _init(slide_panel, scraped_item):
	panel = slide_panel
	item = scraped_item
	game_list = games_for(item)

static func games_for(target) -> Array:
	if not target.is_dir:
		return [target]
	var games = []
	var system_dir_path = Global.root_path + "/" + Global.PATH_GAMES + "/" + target.system
	for file in DirAccess.get_files_at(system_dir_path):
		var opt = option.new()
		opt.filename = file
		opt.absolute_path = system_dir_path + "/" + file
		opt.system = target.system
		opt.clean = Global.clean_regex.sub(file.get_basename(), "", true)
		games.append(opt)
	return games

static func backends() -> Array:
	var names = []
	if Settings.get_setting(Settings.CFG_SCREENSCRAPER_URL) != "":
		names.append("ScreenScraper")
	names.append("SteamGridDB")
	return names

static func missing_credentials(backend: String, system: String) -> String:
	if backend == "screenscraper":
		if SYSTEM_IDS.get(system.to_upper(), 0) == 0:
			return system + " is not on ScreenScraper"
		if Settings.get_setting(Settings.CFG_SS_USER) == "":
			return "No ScreenScraper login set"
	elif Settings.get_setting(Settings.CFG_SGDB_KEY) == "":
		return "No SteamGridDB key set"
	return ""

func target_name() -> String:
	return game_list[0].clean if game_list.size() == 1 and not item.is_dir else str(game_list.size()) + " games"

func backend_menu() -> Dictionary:
	if game_list.is_empty():
		return {"title": "Scrape", "items": [option.new_option("No games found")]}
	var items = []
	for name in backends():
		items.append(option.with_callback(name, func():
			var backend = name.to_lower()
			Settings.store(Settings.CFG_SCRAPER_BACKEND, backend)
			var problem = missing_credentials(backend, item.system)
			if problem != "":
				panel.push_menu(func(): return {"title": problem, "items": [
					option.with_callback("Scraper settings", func(): panel.push_menu(Global.settings_menu.scraper_menu)),
				]})
			elif item.is_dir:
				panel.push_menu(scope_menu)
			else:
				start(false)))
	return {"title": "Scrape " + target_name() + " with", "items": items}

func scope_menu() -> Dictionary:
	return {"title": "Scrape " + target_name(), "items": [
		option.with_callback("Skip games with art", func(): start(true)),
		option.with_callback("Replace all art", func(): start(false)),
	]}

func progress_menu() -> Dictionary:
	var items = []
	if current_name != "":
		items.append(option.new_option(current_name))
		items.append(option.new_option(status))
	for row in [["Saved", found_count], ["Skipped", skipped_count], ["Failed", failed_count]]:
		var count = option.new_option(row[0])
		count.set_meta("value", str(row[1]))
		items.append(count)
	items.append(option.with_callback("Done" if done else "Stop", func(): panel.back()))
	var title = "Finished" if done else "Scraping " + str(mini(current_index + 1, game_list.size())) + " / " + str(game_list.size())
	return {"title": title, "items": items, "selection": items.size() - 1, "locked": true, "choices": true, "on_cancel": func():
		scraping = false
		Global.img_texture_override = null
		Global.refresh_art()}

func _show(name: String, text: String):
	current_name = name
	status = text
	if panel.is_open and not panel.menus.is_empty() and panel.menus.back() == progress_menu:
		panel.show_menu(true)

func _wait():
	await panel.get_tree().create_timer(STEP_SECONDS).timeout

func _fail(game, text: String) -> String:
	_show(game.clean, text)
	failed_count += 1
	return ""

func start(skip_existing: bool):
	if http_search == null:
		http_search = HTTPRequest.new()
		http_image = HTTPRequest.new()
		http_extra = HTTPRequest.new()
		for request in [http_search, http_image, http_extra]:
			panel.add_child(request)
	scraping = true
	done = false
	panel.push_menu(progress_menu)
	current_index = 0
	while current_index < game_list.size() and scraping:
		var game = game_list[current_index]
		_show(game.clean, "Searching...")
		var save_path = Global.get_image_path(game)
		if skip_existing and FileAccess.file_exists(save_path):
			skipped_count += 1
			current_index += 1
			continue
		var art_url = await find_art_url(game)
		if art_url != "" and scraping:
			await download(game, art_url, save_path)
		current_index += 1
		if scraping:
			await _wait()
	scraping = false
	done = true
	_show("", "")
	for request in [http_search, http_image, http_extra]:
		request.queue_free()
	http_search = null

func download(game, art_url: String, save_path: String):
	_show(game.clean, "Downloading image...")
	if http_image.request(art_url) != OK:
		_fail(game, "Download failed")
		return
	var args = await http_image.request_completed
	if args[0] != HTTPRequest.RESULT_SUCCESS or args[1] != 200:
		_fail(game, "Image download error (HTTP " + str(args[1]) + ")")
		return
	var image = load_image_from_buffer(args[3], args[2])
	if image == null:
		_fail(game, "Could not decode image")
		return
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	Global.forget_missing_art(save_path)
	if image.save_png(save_path) != OK:
		_fail(game, "Failed to save file")
		return
	found_count += 1
	_show(game.clean, "Saved")
	if panel.is_open:
		Global.img_texture_override = ImageTexture.create_from_image(image)
		Global.refresh_art()

static func load_image_from_buffer(body: PackedByteArray, headers: PackedStringArray) -> Image:
	var content_type = ""
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			content_type = header.to_lower()
			break
	var image = Image.new()
	if "jpeg" in content_type or "jpg" in content_type:
		return image if image.load_jpg_from_buffer(body) == OK else null
	if image.load_png_from_buffer(body) == OK or image.load_jpg_from_buffer(body) == OK:
		return image
	return null

func find_art_url(game) -> String:
	if Settings.get_setting(Settings.CFG_SCRAPER_BACKEND) == "steamgriddb":
		return await find_art_url_sgdb(game)
	return await find_art_url_ss(game)

func find_art_url_ss(game) -> String:
	var url = (SS_API_BASE
		+ "?ssid=" + Settings.get_setting(Settings.CFG_SS_USER).uri_encode()
		+ "&sspassword=" + Settings.get_setting(Settings.CFG_SS_PASS).uri_encode()
		+ "&systemeid=" + str(SYSTEM_IDS.get(game.system.to_upper(), 0))
		+ "&romnom=" + game.filename.uri_encode())
	while scraping:
		if http_search.request(url) != OK:
			return _fail(game, "Request failed")
		var args = await http_search.request_completed
		var code = args[1]
		if code == 430 or code == 431:
			_show(game.clean, "Rate limited, waiting 10s")
			await panel.get_tree().create_timer(10.0).timeout
			continue
		if code == 401 or code == 403:
			return _fail(game, "Bad credentials (HTTP " + str(code) + ")")
		if args[0] != HTTPRequest.RESULT_SUCCESS:
			return _fail(game, "Network error (" + str(args[0]) + ")")
		if code != 200:
			return _fail(game, "HTTP " + str(code))
		var json = JSON.parse_string(args[3].get_string_from_utf8())
		if json == null:
			return _fail(game, "Invalid response from server")
		var jeu = json.get("response", {}).get("jeu", null)
		if jeu == null:
			return _fail(game, "Not found in database")
		var art_url = pick_ss_art_url(jeu.get("medias", []))
		if art_url == "":
			return _fail(game, "No box art available")
		return art_url
	return ""

static func pick_ss_art_url(medias: Array) -> String:
	for region in ["wor", "us", "eu", "jp", "ss"]:
		for media in medias:
			if media.get("type") == "box-2D" and media.get("region") == region:
				return media.get("url", "")
	for media in medias:
		if media.get("type") == "box-2D":
			return media.get("url", "")
	return ""

func find_art_url_sgdb(game) -> String:
	var headers = ["Authorization: Bearer " + Settings.get_setting(Settings.CFG_SGDB_KEY)]
	if http_search.request(SGDB_SEARCH_BASE + game.clean.uri_encode(), headers) != OK:
		return _fail(game, "SteamGridDB search failed")
	var search = await http_search.request_completed
	if search[0] != HTTPRequest.RESULT_SUCCESS:
		return _fail(game, "SteamGridDB network error (" + str(search[0]) + ")")
	if search[1] == 401 or search[1] == 403:
		return _fail(game, "Invalid API key (HTTP " + str(search[1]) + ")")
	if search[1] != 200:
		return _fail(game, "SteamGridDB HTTP " + str(search[1]))
	var search_json = JSON.parse_string(search[3].get_string_from_utf8())
	if search_json == null or not search_json.get("success", false) or search_json.get("data", []).is_empty():
		return _fail(game, "Not found on SteamGridDB")
	var game_id = search_json.data[0].get("id", 0)
	if http_extra.request(SGDB_GRIDS_BASE + str(game_id) + "?dimensions=600x900,342x482,660x930", headers) != OK:
		return _fail(game, "SteamGridDB grids request failed")
	var grids = await http_extra.request_completed
	if grids[0] != HTTPRequest.RESULT_SUCCESS or grids[1] != 200:
		return _fail(game, "SteamGridDB grids error (HTTP " + str(grids[1]) + ")")
	var grids_json = JSON.parse_string(grids[3].get_string_from_utf8())
	if grids_json == null or not grids_json.get("success", false) or grids_json.get("data", []).is_empty():
		return _fail(game, "No box art on SteamGridDB")
	return grids_json.data[0].get("url", "")

extends RefCounted

const SECRETS_FILE = "res://secrets.json"
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
var search_override = ""

func _init(slide_panel, scraped_item):
	panel = slide_panel
	item = scraped_item
	game_list = games_for(item)

static func already_has_art(game) -> bool:
	var path = Global.get_image_path(game)
	return path != "" and FileAccess.file_exists(path)

static func games_for(target) -> Array:
	if not target.is_dir:
		return [target]
	var games = []
	var seen = {}
	var extensions = Global.get_system_settings(target.system).get("EXTENSIONS")
	for system_dir_path in Global._get_all_system_paths(target.system):
		if not DirAccess.dir_exists_absolute(system_dir_path):
			continue
		for file in DirAccess.get_files_at(system_dir_path):
			var path = system_dir_path.path_join(file)
			if not Global.is_game_file(file, extensions) or seen.has(path):
				continue
			seen[path] = true
			var opt = option.new()
			opt.filename = file
			opt.absolute_path = path
			opt.system = target.system
			opt.clean = Global.clean_regex.sub(file.get_basename(), "", true)
			games.append(opt)
	return games

static func response_text(body: PackedByteArray) -> String:
	if body.size() > 2 and body[0] == 0x1f and body[1] == 0x8b:
		var unpacked = body.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		if not unpacked.is_empty():
			return unpacked.get_string_from_utf8()
	return body.get_string_from_utf8()

const FINGERPRINT_MAX_BYTES = 64 * 1024 * 1024

static func rom_fingerprint(path: String) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return ""
	var size = FileAccess.get_size(path)
	var params = "&romtaille=" + str(size)
	if size <= FINGERPRINT_MAX_BYTES:
		params += "&md5=" + FileAccess.get_md5(path)
	return params

static func masked_url(url: String) -> String:
	return RegEx.create_from_string("(ssid|sspassword)=[^&]*").sub(url, "$1=***", true)

static func screenscraper_url() -> String:
	if not FileAccess.file_exists(SECRETS_FILE):
		return ""
	var secrets = JSON.parse_string(FileAccess.get_file_as_string(SECRETS_FILE))
	return str(secrets.get("SCREENSCRAPER_URL", "")) if secrets is Dictionary else ""

static func backends() -> Array:
	return ["ScreenScraper", "SteamGridDB"] if screenscraper_url() != "" else ["SteamGridDB"]

static func missing_credentials(backend: String, system: String) -> String:
	if backend == "screenscraper":
		if SYSTEM_IDS.get(system.to_upper(), 0) == 0:
			return system + " is not on ScreenScraper"
		if Settings.get_setting(Settings.CFG_SS_USER) == "":
			return "No ScreenScraper login set"
	elif Settings.get_setting(Settings.CFG_SGDB_KEY) == "":
		return "No SteamGridDB key set"
	return ""

const SGDB_CANDIDATES = 3
const ROMAN_NUMERALS = {"ii": "2", "iii": "3", "iv": "4", "v": "5", "vi": "6", "vii": "7", "viii": "8", "ix": "9"}

static func name_tokens(text: String) -> Array:
	var cleaned = RegEx.create_from_string("[^a-z0-9]+").sub(text.to_lower(), " ", true).strip_edges()
	var tokens = []
	for token in cleaned.split(" ", false):
		tokens.append(ROMAN_NUMERALS.get(token, token))
	return tokens

static func match_score(name: String, query: String) -> float:
	var name_tokens_list = name_tokens(name)
	var query_tokens = name_tokens(query)
	if name_tokens_list == query_tokens:
		return 1000.0
	var score = 0.0
	for token in query_tokens:
		if token in name_tokens_list:
			score += 10.0
		elif token.is_valid_int():
			score -= 100.0
	for token in name_tokens_list:
		if not token in query_tokens:
			score -= 30.0 if token.is_valid_int() else 2.0
	if not name_tokens_list.is_empty() and not query_tokens.is_empty() and name_tokens_list[0] == query_tokens[0]:
		score += 5.0
	return score

static func numbers_in(text: String) -> Array:
	return name_tokens(text).filter(func(token): return token.is_valid_int())

static func names_agree(names: Array, query: String) -> bool:
	var wanted = numbers_in(query)
	if wanted.is_empty():
		return true
	for name in names:
		var found = numbers_in(name)
		if wanted.all(func(number): return number in found):
			return true
	return false

static func ranked_matches(results: Array, query: String) -> Array:
	var ranked = []
	for i in range(results.size()):
		ranked.append([match_score(str(results[i].get("name", "")), query), i, results[i]])
	ranked.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return ranked.map(func(entry): return entry[2])

static func default_search(game, backend: String) -> String:
	return game.clean if backend == "steamgriddb" else game.filename

func search_term(game) -> String:
	return search_override if search_override != "" else default_search(game, Settings.get_setting(Settings.CFG_SCRAPER_BACKEND))

func can_edit_search() -> bool:
	return done and not item.is_dir and game_list.size() == 1

func edit_search():
	panel.text_input("Search for", search_term(game_list[0]), false, func(text: String):
		if text.strip_edges() == "":
			return
		search_override = text.strip_edges()
		panel.back()
		start(false))

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
	var actions = []
	if can_edit_search():
		actions.append(items.size())
		items.append(option.with_callback("Edit Search", edit_search))
	actions.append(items.size())
	items.append(option.with_callback("Done" if done else "Stop", func(): panel.back()))
	var title = "Finished" if done else "Scraping " + str(mini(current_index + 1, game_list.size())) + " / " + str(game_list.size())
	return {"title": title, "items": items, "selection": items.size() - 1, "selectable": actions, "choices": true, "on_cancel": func():
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
	found_count = 0
	skipped_count = 0
	failed_count = 0
	panel.push_menu(progress_menu)
	current_index = 0
	while current_index < game_list.size() and scraping:
		var game = game_list[current_index]
		_show(game.clean, "Searching...")
		var save_path = Global.own_image_path(game)
		if skip_existing and already_has_art(game):
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
	var url = (screenscraper_url()
		+ "?ssid=" + Settings.get_setting(Settings.CFG_SS_USER).uri_encode()
		+ "&sspassword=" + Settings.get_setting(Settings.CFG_SS_PASS).uri_encode()
		+ "&systemeid=" + str(SYSTEM_IDS.get(game.system.to_upper(), 0))
		+ "&romnom=" + search_term(game).uri_encode()
		+ rom_fingerprint(game.absolute_path))
	print("SCRAPE " + masked_url(url))
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
		if code == 404:
			return _fail(game, "Not found on ScreenScraper")
		if code != 200:
			return _fail(game, "HTTP " + str(code))
		var json = JSON.parse_string(response_text(args[3]))
		if json == null:
			return _fail(game, "Invalid response from server")
		var jeu = json.get("response", {}).get("jeu", null)
		if jeu == null:
			return _fail(game, "Not found in database")
		var names = jeu.get("noms", []).map(func(n): return str(n.get("text", "")))
		if search_override != "" and not names_agree(names, search_override):
			return _fail(game, "ScreenScraper matched \"" + (names[0] if not names.is_empty() else "another game") + "\" instead")
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
	if http_search.request(SGDB_SEARCH_BASE + search_term(game).uri_encode(), headers) != OK:
		return _fail(game, "SteamGridDB search failed")
	var search = await http_search.request_completed
	if search[0] != HTTPRequest.RESULT_SUCCESS:
		return _fail(game, "SteamGridDB network error (" + str(search[0]) + ")")
	if search[1] == 401 or search[1] == 403:
		return _fail(game, "Invalid API key (HTTP " + str(search[1]) + ")")
	if search[1] != 200:
		return _fail(game, "SteamGridDB HTTP " + str(search[1]))
	var search_json = JSON.parse_string(response_text(search[3]))
	if search_json == null or not search_json.get("success", false) or search_json.get("data", []).is_empty():
		return _fail(game, "Not found on SteamGridDB")
	var candidates = ranked_matches(search_json.data, search_term(game))
	print("SGDB matches for " + search_term(game) + ": " + str(candidates.slice(0, SGDB_CANDIDATES).map(func(c): return c.get("name", ""))))
	for candidate in candidates.slice(0, SGDB_CANDIDATES):
		if not scraping:
			return ""
		if http_extra.request(SGDB_GRIDS_BASE + str(candidate.get("id", 0)) + "?dimensions=600x900,342x482,660x930", headers) != OK:
			return _fail(game, "SteamGridDB grids request failed")
		var grids = await http_extra.request_completed
		if grids[0] != HTTPRequest.RESULT_SUCCESS or grids[1] != 200:
			return _fail(game, "SteamGridDB grids error (HTTP " + str(grids[1]) + ")")
		var grids_json = JSON.parse_string(response_text(grids[3]))
		if grids_json != null and grids_json.get("success", false) and not grids_json.get("data", []).is_empty():
			return grids_json.data[0].get("url", "")
	return _fail(game, "No box art on SteamGridDB")

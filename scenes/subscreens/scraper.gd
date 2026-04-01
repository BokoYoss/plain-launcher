extends Screen

const SS_API_BASE = "https://www.screenscraper.fr/api2/jeuInfos.php"
const SGDB_SEARCH_BASE = "https://www.steamgriddb.com/api/v2/search/autocomplete/"
const SGDB_GRIDS_BASE = "https://www.steamgriddb.com/api/v2/grids/game/"

# Map PlainLauncher system folder names to ScreenScraper system IDs
const SYSTEM_IDS: Dictionary = {
	"NES": 3, "SNES": 4, "N64": 14, "GB": 9, "GBC": 10, "GBA": 12,
	"NDS": 15, "N3DS": 17, "PS": 57, "PS2": 58, "PSP": 61,
	"GENESIS": 1, "SEGACD": 20, "SATURN": 22, "DREAMCAST": 23,
	"GAMECUBE": 13, "WII": 16, "NEOGEO": 142, "PCE": 31,
	"ARCADE": 75, "MASTERSYSTEM": 2, "NGP": 25, "SWITCH": 225,
}

var game_list: Array = []
var found_count: int = 0
var skipped_count: int = 0
var failed_count: int = 0
var skip_existing: bool = false
var scraping: bool = false
var done: bool = false
var single_game: bool = false
var system_id: int = 0
var system: String = ""
var choosing_backend: bool = false

var http_search: HTTPRequest
var http_image: HTTPRequest
var http_extra: HTTPRequest

func _ready():
	http_search = HTTPRequest.new()
	http_image = HTTPRequest.new()
	http_extra = HTTPRequest.new()
	add_child(http_search)
	add_child(http_image)
	add_child(http_extra)

	system = Global.special_item.system if Global.special_item != null else Global.subscreen
	if Global.special_item != null and not Global.special_item.is_dir:
		system = Global.special_item.system
		single_game = true
		game_list.append(Global.special_item)
	else:
		var system_dir_path = Global.root_path + "/" + Global.PATH_GAMES + "/" + system
		var dir = DirAccess.open(system_dir_path)
		if dir == null:
			Global.clear_visible("Cannot open game directory.", ["OK"])
			return
		for file in dir.get_files():
			var opt = option.new()
			opt.filename = file
			opt.absolute_path = system_dir_path + "/" + file
			opt.system = system
			opt.clean = Global.clean_regex.sub(file.get_basename(), "", true)
			game_list.append(opt)
		if game_list.is_empty():
			Global.clear_visible("No games found in " + system + ".", ["OK"])
			return

	_show_backend_choice()

func _show_backend_choice():
	var ss_available = Settings.get_setting(Settings.CFG_SS_DEVID) != "" and Settings.get_setting(Settings.CFG_SS_SOFT_NAME) != ""
	var title = "Scrape " + (game_list[0].clean if single_game else str(game_list.size()) + " games") + " with..."
	var options = []
	if ss_available:
		options.append("ScreenScraper")
	options.append("SteamGridDB")
	options.append("Cancel")
	choosing_backend = true
	Global.clear_visible(title, options)

func _confirm_scrape(backend: String):
	if backend == "screenscraper":
		system_id = SYSTEM_IDS.get(system.to_upper(), 0)
		if system_id == 0:
			Global.clear_visible("'" + system + "' is not supported on ScreenScraper.", ["OK"])
			return
		if Settings.get_setting(Settings.CFG_SS_USER) == "":
			Global.clear_visible("No ScreenScraper credentials set.", ["Update Scraper Settings", "Cancel"])
			return
	elif backend == "steamgriddb":
		if Settings.get_setting(Settings.CFG_SGDB_KEY) == "":
			Global.clear_visible("No SteamGridDB API key set.", ["Update Scraper Settings", "Cancel"])
			return

	if single_game:
		Global.clear_visible("Scrape " + game_list[0].clean + "?", ["Yes", "No"])
	else:
		Global.clear_visible("Scrape " + str(game_list.size()) + " games?", ["Scrape all", "Skip existing art", "Cancel"])

func show_progress(index: int, game_name: String, status: String):
	Global.clear_visible("Scraping " + str(index + 1) + " / " + str(game_list.size())
		+ "  -  " + str(found_count) + " saved  " + str(failed_count) + " failed", [game_name, status])
	print("Scraping: " + game_name + ": " + status)
	Global.message.text = game_name + "  -  " + status

func start_scraping():
	scraping = true
	var current_index: int = 0

	if single_game:
		system_id = SYSTEM_IDS.get(game_list[0].system.to_upper(), 0)

	Global.clear_visible("", ["Cancel"])

	while current_index < game_list.size():
		Global.disable_scroll = true
		if not scraping:
			done = true
			Global.disable_scroll = false
			Global.clear_visible("Scraping cancelled.", [
				"Saved: " + str(found_count),
				"Skipped: " + str(skipped_count),
				"Failed: " + str(failed_count),
				"OK"
			])
			break

		var game = game_list[current_index]
		show_progress(current_index, game.clean, "Searching...")

		var save_path = Global.get_image_path(game)
		if skip_existing and FileAccess.file_exists(save_path):
			skipped_count += 1
			current_index += 1
			continue

		var art_url = await find_art_url(game)

		if art_url == "":
			current_index += 1
			await get_tree().create_timer(0.5).timeout
			continue

		show_progress(current_index, game.clean, "Downloading image...")

		var img_err = http_image.request(art_url)
		if img_err != OK:
			show_progress(current_index, game.clean, "Download failed (err " + str(img_err) + ")")
			failed_count += 1
			current_index += 1
			await get_tree().create_timer(0.5).timeout
			continue

		var img_args = await http_image.request_completed
		var img_result = img_args[0]
		var img_code = img_args[1]
		var img_headers: PackedStringArray = img_args[2]
		var img_body: PackedByteArray = img_args[3]

		if img_result != HTTPRequest.RESULT_SUCCESS:
			show_progress(current_index, game.clean, "Download network error (" + str(img_result) + ")")
			failed_count += 1
			current_index += 1
			await get_tree().create_timer(0.5).timeout
			continue

		if img_code != 200:
			show_progress(current_index, game.clean, "Image server HTTP " + str(img_code))
			failed_count += 1
			current_index += 1
			await get_tree().create_timer(0.5).timeout
			continue

		var image = load_image_from_buffer(img_body, img_headers)
		if image == null:
			show_progress(current_index, game.clean, "Could not decode image")
			failed_count += 1
			current_index += 1
			await get_tree().create_timer(0.5).timeout
			continue

		DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
		if image.save_png(save_path) == OK:
			show_progress(current_index, game.clean, "Saved!")
			found_count += 1
			Global.img_texture_override = ImageTexture.create_from_image(image)
			Global.refresh_art(save_path)
		else:
			show_progress(current_index, game.clean, "Failed to save file")
			failed_count += 1

		current_index += 1
		await get_tree().create_timer(0.5).timeout

	scraping = false
	if not done:
		done = true
		if single_game:
			var result_msg = "Saved!" if found_count == 1 else "Not found."
			Global.clear_visible(result_msg, ["OK"])
		else:
			Global.clear_visible("Done — " + Global.subscreen, [
				"Saved: " + str(found_count),
				"Skipped: " + str(skipped_count),
				"Failed: " + str(failed_count),
				"OK"
			])

func load_image_from_buffer(body: PackedByteArray, headers: PackedStringArray) -> Image:
	var content_type = ""
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			content_type = header.to_lower()
			break
	var image = Image.new()
	if "jpeg" in content_type or "jpg" in content_type:
		if image.load_jpg_from_buffer(body) == OK:
			return image
	else:
		if image.load_png_from_buffer(body) == OK:
			return image
		if image.load_jpg_from_buffer(body) == OK:
			return image
	return null

func find_art_url(game) -> String:
	var backend = Settings.get_setting(Settings.CFG_SCRAPER_BACKEND)
	if backend == "steamgriddb":
		return await find_art_url_sgdb(game)
	return await find_art_url_ss(game)

func find_art_url_ss(game) -> String:
	var ss_user = Settings.get_setting(Settings.CFG_SS_USER)
	var ss_pass = Settings.get_setting(Settings.CFG_SS_PASS)
	var ss_devid = Settings.get_setting(Settings.CFG_SS_DEVID)
	var ss_devpass = Settings.get_setting(Settings.CFG_SS_DEVPASS)
	var ss_soft_name = Settings.get_setting(Settings.CFG_SS_SOFT_NAME)

	while true:
		var url = (SS_API_BASE
			+ "?devid=" + ss_devid.uri_encode()
			+ "&softname=" + ss_soft_name.uri_encode()
			+ "&output=json"
			+ "&ssid=" + ss_user.uri_encode()
			+ "&sspassword=" + ss_pass.uri_encode()
			+ "&systemeid=" + str(system_id)
			+ "&romnom=" + game.filename.uri_encode())
		if ss_devpass != "":
			url += "&devpassword=" + ss_devpass.uri_encode()

		var err = http_search.request(url)
		if err != OK:
			show_progress(game_list.find(game), game.clean, "Request failed (err " + str(err) + ")")
			failed_count += 1
			return ""

		var args = await http_search.request_completed
		var result = args[0]
		var response_code = args[1]
		var body: PackedByteArray = args[3]

		if response_code == 430 or response_code == 431:
			show_progress(game_list.find(game), game.clean, "Rate limited — waiting 10s")
			await get_tree().create_timer(10.0).timeout
			continue

		if response_code == 401 or response_code == 403:
			show_progress(game_list.find(game), game.clean, "Bad credentials (HTTP " + str(response_code) + ")")
			failed_count += 1
			return ""

		if result != HTTPRequest.RESULT_SUCCESS:
			show_progress(game_list.find(game), game.clean, "Network error (" + str(result) + ")")
			failed_count += 1
			return ""

		if response_code != 200:
			show_progress(game_list.find(game), game.clean, "HTTP " + str(response_code))
			failed_count += 1
			return ""

		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null:
			show_progress(game_list.find(game), game.clean, "Invalid response from server")
			failed_count += 1
			return ""

		var jeu = json.get("response", {}).get("jeu", null)
		if jeu == null:
			show_progress(game_list.find(game), game.clean, "Not found in database")
			failed_count += 1
			return ""

		var art_url = pick_ss_art_url(jeu.get("medias", []))
		if art_url == "":
			show_progress(game_list.find(game), game.clean, "No box art available")
			failed_count += 1
			return ""

		return art_url

	return ""

func pick_ss_art_url(medias: Array) -> String:
	var region_priority = ["wor", "us", "eu", "jp", "ss"]
	for region in region_priority:
		for media in medias:
			if media.get("type") == "box-2D" and media.get("region") == region:
				return media.get("url", "")
	for media in medias:
		if media.get("type") == "box-2D":
			return media.get("url", "")
	return ""

func find_art_url_sgdb(game) -> String:
	var sgdb_key = Settings.get_setting(Settings.CFG_SGDB_KEY)
	var headers = ["Authorization: Bearer " + sgdb_key]
	var search_term = game.clean.uri_encode()

	var search_err = http_search.request(SGDB_SEARCH_BASE + search_term, headers)
	if search_err != OK:
		show_progress(game_list.find(game), game.clean, "SGDB search failed (err " + str(search_err) + ")")
		failed_count += 1
		return ""

	var search_args = await http_search.request_completed
	var search_result = search_args[0]
	var search_code = search_args[1]
	var search_body: PackedByteArray = search_args[3]

	if search_result != HTTPRequest.RESULT_SUCCESS:
		show_progress(game_list.find(game), game.clean, "SGDB network error (" + str(search_result) + ")")
		failed_count += 1
		return ""

	if search_code == 401 or search_code == 403:
		show_progress(game_list.find(game), game.clean, "Invalid API key (HTTP " + str(search_code) + ")")
		failed_count += 1
		return ""

	if search_code != 200:
		show_progress(game_list.find(game), game.clean, "SGDB HTTP " + str(search_code))
		failed_count += 1
		return ""

	var search_json = JSON.parse_string(search_body.get_string_from_utf8())
	if search_json == null or not search_json.get("success", false):
		show_progress(game_list.find(game), game.clean, "Not found on SteamGridDB")
		failed_count += 1
		return ""

	var results = search_json.get("data", [])
	if results.is_empty():
		show_progress(game_list.find(game), game.clean, "Not found on SteamGridDB")
		failed_count += 1
		return ""

	var game_id = results[0].get("id", 0)

	var grids_err = http_extra.request(SGDB_GRIDS_BASE + str(game_id) + "?dimensions=600x900,342x482,660x930", headers)
	if grids_err != OK:
		show_progress(game_list.find(game), game.clean, "SGDB grids request failed (err " + str(grids_err) + ")")
		failed_count += 1
		return ""

	var grids_args = await http_extra.request_completed
	var grids_result = grids_args[0]
	var grids_code = grids_args[1]
	var grids_body: PackedByteArray = grids_args[3]

	if grids_result != HTTPRequest.RESULT_SUCCESS or grids_code != 200:
		show_progress(game_list.find(game), game.clean, "SGDB grids error (HTTP " + str(grids_code) + ")")
		failed_count += 1
		return ""

	var grids_json = JSON.parse_string(grids_body.get_string_from_utf8())
	if grids_json == null or not grids_json.get("success", false):
		show_progress(game_list.find(game), game.clean, "No grids on SteamGridDB")
		failed_count += 1
		return ""

	var grids = grids_json.get("data", [])
	if grids.is_empty():
		show_progress(game_list.find(game), game.clean, "No box art on SteamGridDB")
		failed_count += 1
		return ""

	return grids[0].get("url", "")

func _process(_delta):
	if scraping:
		if Global.back_pressed() or Global.confirm_pressed():
			scraping = false
		return

	if Global.confirm_pressed():
		var selected = Global.get_selected().clean.to_lower()

		if choosing_backend:
			choosing_backend = false
			if "cancel" in selected:
				Navigator.pop()
				return
			var backend = "screenscraper" if selected == "screenscraper" else "steamgriddb"
			Settings.store(Settings.CFG_SCRAPER_BACKEND, backend)
			_confirm_scrape(backend)
			return

		if done or "ok" in selected:
			Global.disable_scroll = false
			Navigator.pop()
			return
		if selected == "yes" or selected == "scrape all":
			skip_existing = false
			start_scraping()
			return
		if "skip existing" in selected:
			skip_existing = true
			start_scraping()
			return
		if "scraper settings" in selected:
			Navigator.push("scraper_credentials")
			return
		if selected == "no" or "cancel" in selected:
			Navigator.pop()
			return

	if Global.back_pressed():
		if choosing_backend:
			choosing_backend = false
		Navigator.pop()

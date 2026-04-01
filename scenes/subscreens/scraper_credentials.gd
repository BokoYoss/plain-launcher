extends Screen

const SGDB_VALIDATE_URL = "https://www.steamgriddb.com/api/v2/search/autocomplete/test"

var pending_field = ""
var http: HTTPRequest

func _ready():
	http = HTTPRequest.new()
	add_child(http)
	AndroidInterface.connect("text_input_complete", _on_text_input)
	populate_content()

func populate_content():
	var ss_available = Settings.get_setting(Settings.CFG_SCREENSCRAPER_URL) != ""
	var items = []

	if ss_available:
		var user = Settings.get_setting(Settings.CFG_SS_USER)
		items.append(option.with_callback("ScreenScraper Username: " + (user if user != "" else "(not set)"), func():
			pending_field = "username"
			AndroidInterface.show_text_input("ScreenScraper Username", Settings.get_setting(Settings.CFG_SS_USER), false)
		))
		items.append(option.with_callback("ScreenScraper Password: " + ("(set)" if Settings.get_setting(Settings.CFG_SS_PASS) != "" else "(not set)"), func():
			pending_field = "password"
			AndroidInterface.show_text_input("ScreenScraper Password", "", true)
		))
	else:
		items.append("ScreenScraper: (unavailable in this build)")

	items.append(option.with_callback("SteamGridDB API Key: " + ("(set)" if Settings.get_setting(Settings.CFG_SGDB_KEY) != "" else "(not set)"), func():
		pending_field = "sgdb_key"
		AndroidInterface.show_text_input("SteamGridDB API Key", "", true)
	))
	items.append(option.with_callback("Done", func(): Navigator.pop()))
	Global.clear_visible("Scraper Settings", items)

func _on_text_input(text: String):
	if text != "":
		if pending_field == "username":
			Settings.store(Settings.CFG_SS_USER, text)
		elif pending_field == "password":
			Settings.store(Settings.CFG_SS_PASS, text)
		elif pending_field == "sgdb_key":
			Settings.store(Settings.CFG_SGDB_KEY, text)
			validate_sgdb_key(text)
			return
	pending_field = ""
	populate_content()

func validate_sgdb_key(key: String):
	Global.clear_visible("Validating API key...", [])
	var err = http.request(SGDB_VALIDATE_URL, ["Authorization: Bearer " + key])
	if err != OK:
		pending_field = ""
		Global.clear_visible("Could not reach SteamGridDB.", [option.with_callback("OK", populate_content)])
		return
	var args = await http.request_completed
	var response_code = args[1]
	pending_field = ""
	if response_code == 200:
		Global.clear_visible("API key is valid!", [option.with_callback("OK", populate_content)])
	elif response_code == 401 or response_code == 403:
		Settings.store(Settings.CFG_SGDB_KEY, "")
		Global.clear_visible("Invalid API key — not saved.", [option.with_callback("OK", populate_content)])
	else:
		Global.clear_visible("Unexpected response (HTTP " + str(response_code) + ").", [option.with_callback("OK", populate_content)])

func _process(_delta):
	if Global.confirm_pressed():
		Global.get_selected().trigger(Actions.CONFIRM)
	if Global.back_pressed():
		Navigator.pop()

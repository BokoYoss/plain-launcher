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
	var ss_available = Settings.get_setting(Settings.CFG_SS_DEVID) != ""
	var items = []

	if ss_available:
		var user = Settings.get_setting(Settings.CFG_SS_USER)
		items.append("ScreenScraper Username: " + (user if user != "" else "(not set)"))
		items.append("ScreenScraper Password: " + ("(set)" if Settings.get_setting(Settings.CFG_SS_PASS) != "" else "(not set)"))
	else:
		items.append("ScreenScraper: (unavailable in this build)")

	var key = Settings.get_setting(Settings.CFG_SGDB_KEY)
	items.append("SteamGridDB API Key: " + ("(set)" if key != "" else "(not set)"))

	items.append("Done")
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
		Global.clear_visible("Could not reach SteamGridDB.", ["OK"])
		return
	var args = await http.request_completed
	var response_code = args[1]
	pending_field = ""
	if response_code == 200:
		Global.clear_visible("API key is valid!", ["OK"])
	elif response_code == 401 or response_code == 403:
		Settings.store(Settings.CFG_SGDB_KEY, "")
		Global.clear_visible("Invalid API key — not saved.", ["OK"])
	else:
		Global.clear_visible("Unexpected response (HTTP " + str(response_code) + ").", ["OK"])

func _process(_delta):
	if Global.confirm_pressed():
		var selected = Global.get_selected().clean.to_lower()
		if "ss username" in selected:
			pending_field = "username"
			AndroidInterface.show_text_input("ScreenScraper Username", Settings.get_setting(Settings.CFG_SS_USER), false)
		elif "ss password" in selected:
			pending_field = "password"
			AndroidInterface.show_text_input("ScreenScraper Password", "", true)
		elif "sgdb api key" in selected:
			pending_field = "sgdb_key"
			AndroidInterface.show_text_input("SteamGridDB API Key", "", true)
		elif "ok" in selected:
			populate_content()
		elif selected == "done":
			Navigator.pop()
	if Global.back_pressed():
		Navigator.pop()

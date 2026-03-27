extends Screen

const BUNDLED_INTENTS_PATH = "res://launcher_configs/COMMON/intents.json"

var pending_new_name: bool = false

func _ready():
	AndroidInterface.connect("text_input_complete", _on_text_input)
	ensure_user_intents_exist()
	populate_content()

func get_intents_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"

func ensure_user_intents_exist():
	var path = get_intents_path()
	if FileAccess.file_exists(path):
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var bundled = FileAccess.get_file_as_string(BUNDLED_INTENTS_PATH)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(bundled)
		f.close()

func load_intents() -> Dictionary:
	var path = get_intents_path()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed != null else {}

func save_intents(intents: Dictionary):
	var f = FileAccess.open(get_intents_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(intents, "\t"))
		f.close()

func _on_resume():
	populate_content()

func populate_content():
	var intents = load_intents()
	var keys = intents.keys()
	keys.sort()
	var items = ["Add new intent"]
	items.append_array(keys)
	Global.clear_visible("Launch Intents", items)

func _on_text_input(text: String):
	if not pending_new_name:
		populate_content()
		return
	pending_new_name = false
	if text == "":
		populate_content()
		return
	var intents = load_intents()
	if not intents.has(text):
		intents[text] = {
			"action": "android.intent.action.VIEW",
			"componentPackage": "",
			"componentClass": "",
		}
		save_intents(intents)
	Global.special_item = option.new_option(text)
	Navigator.push("intent_editor")

func _process(_delta):
	if Global.confirm_pressed():
		var selected = Global.get_selected().clean
		if selected == "Add new intent":
			pending_new_name = true
			AndroidInterface.show_text_input("Intent name (e.g. myemulator)", "", false)
			return
		if selected.begins_with("Tokens:"):
			return
		var intents = load_intents()
		if intents.has(selected):
			Global.special_item = option.new_option(selected)
			Navigator.push("intent_editor")
	if Global.back_pressed():
		Navigator.pop()

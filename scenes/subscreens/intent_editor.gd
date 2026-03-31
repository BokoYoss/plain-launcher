extends Screen

var intent_name: String = ""
var intent: Dictionary = {}

# Text input state
var editing_field: String = ""   # "action" | "package" | "class" | "data" | "file" | "flags" | "extra_KEY"
var pending_extra_key: String = ""  # set during two-step "add extra" flow

func _ready():
	if Global.special_item == null:
		Navigator.pop()
		return
	intent_name = Global.special_item.filename
	AndroidInterface.connect("text_input_complete", _on_text_input)
	load_intent()
	populate_content()

func get_intents_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"

func load_intent():
	var path = get_intents_path()
	if not FileAccess.file_exists(path):
		return
	var all_intents = JSON.parse_string(FileAccess.get_file_as_string(path))
	if all_intents != null and all_intents.has(intent_name):
		intent = all_intents[intent_name].duplicate(true)

func save_intent():
	var path = get_intents_path()
	if not FileAccess.file_exists(path):
		return
	var all_intents = JSON.parse_string(FileAccess.get_file_as_string(path))
	if all_intents == null:
		all_intents = {}
	all_intents[intent_name] = intent
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all_intents, "\t"))
		f.close()

func delete_intent():
	var path = get_intents_path()
	if not FileAccess.file_exists(path):
		return
	var all_intents = JSON.parse_string(FileAccess.get_file_as_string(path))
	if all_intents != null:
		all_intents.erase(intent_name)
		var f = FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(all_intents, "\t"))
			f.close()

func _on_resume():
	populate_content()

func populate_content():
	var items = []
	items.append("Action: " + intent.get("action", ""))
	items.append("Package: " + intent.get("componentPackage", ""))
	items.append("Class: " + intent.get("componentClass", ""))
	if intent.has("data"):
		items.append("Data: " + intent.get("data", ""))
	else:
		items.append("Add data field")
	if intent.has("providedFile"):
		items.append("File: " + intent.get("providedFile", ""))
	else:
		items.append("Add file field")
	var flags = intent.get("flags", [])
	if flags.is_empty():
		items.append("Flags: (default)")
	else:
		items.append("Flags: " + ", ".join(flags))
	var extras = intent.get("extras", {})
	for key in extras:
		items.append(key + " = " + str(extras.get(key, "")))
	items.append("Add extra")
	items.append("Delete intent")
	items.append("Done")
	Global.clear_visible(intent_name, items)

func _on_text_input(text: String):
	# Two-step add-extra: first the key, then the value
	if pending_extra_key != "":
		if text != "":
			var extras = intent.get("extras", {})
			extras[pending_extra_key] = text
			intent["extras"] = extras
			save_intent()
		pending_extra_key = ""
		editing_field = ""
		populate_content()
		return

	if editing_field == "add_extra_key":
		if text != "":
			pending_extra_key = text
			AndroidInterface.show_text_input("Value for " + text + " (use {game}, {core}, etc.)", "", false)
		else:
			editing_field = ""
			populate_content()
		return

	if editing_field != "" and text != "":
		match editing_field:
			"action":
				intent["action"] = text
			"package":
				intent["componentPackage"] = text
			"class":
				intent["componentClass"] = text
			"data":
				if text == "":
					intent.erase("data")
				else:
					intent["data"] = text
			"file":
				if text == "":
					intent.erase("providedFile")
				else:
					intent["providedFile"] = text
			"flags":
				if text == "":
					intent.erase("flags")
				else:
					var parts: Array = Array(text.split(","))
					intent["flags"] = parts.map(func(s): return s.strip_edges()).filter(func(s): return s != "")
			_:
				if editing_field.begins_with("extra_"):
					var extra_key = editing_field.substr(6)
					if text == "":
						intent.get("extras", {}).erase(extra_key)
					else:
						intent.get("extras", {})[extra_key] = text
		save_intent()

	editing_field = ""
	populate_content()

func _process(_delta):
	if Global.confirm_pressed():
		var sel = Global.get_selected().clean
		var sel_lower = sel.to_lower()

		if sel_lower.begins_with("action: "):
			editing_field = "action"
			AndroidInterface.show_text_input("Action", intent.get("action", ""), false)
		elif sel_lower.begins_with("package: "):
			editing_field = "package"
			AndroidInterface.show_text_input("Package", intent.get("componentPackage", ""), false)
		elif sel_lower.begins_with("class: "):
			editing_field = "class"
			AndroidInterface.show_text_input("Activity class", intent.get("componentClass", ""), false)
		elif sel_lower.begins_with("data: "):
			editing_field = "data"
			AndroidInterface.show_text_input("Data URI (empty to remove)", intent.get("data", ""), false)
		elif sel_lower == "add data field":
			editing_field = "data"
			AndroidInterface.show_text_input("Data URI", "{game}", false)
		elif sel_lower.begins_with("file: "):
			editing_field = "file"
			AndroidInterface.show_text_input("File path (empty to remove)", intent.get("providedFile", ""), false)
		elif sel_lower == "add file field":
			editing_field = "file"
			AndroidInterface.show_text_input("File path", "{game}", false)
		elif sel_lower.begins_with("flags: "):
			editing_field = "flags"
			var current = ", ".join(intent.get("flags", []))
			AndroidInterface.show_text_input("Flags (comma-separated, empty for default)", current, false)
		elif " = " in sel:
			# Use raw sel so extras key preserves its original case (e.g. "ROM", "LIBRETRO")
			var eq_pos = sel.find(" = ")
			var extra_key = sel.left(eq_pos)
			editing_field = "extra_" + extra_key
			AndroidInterface.show_text_input(extra_key + " (empty to remove)", intent.get("extras", {}).get(extra_key, ""), false)
		elif sel_lower == "add extra":
			editing_field = "add_extra_key"
			AndroidInterface.show_text_input("Extra key name", "", false)
		elif sel_lower == "delete intent":
			Global.clear_visible("Delete " + intent_name + "?", ["Yes", "Cancel"])
		elif sel_lower == "yes":
			delete_intent()
			Navigator.pop()
		elif sel_lower == "cancel":
			populate_content()
		elif sel_lower == "done":
			Navigator.pop()

	if Global.back_pressed():
		Navigator.pop()

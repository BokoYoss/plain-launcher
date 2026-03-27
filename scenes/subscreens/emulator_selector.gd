extends Screen

const BUNDLED_INTENTS_PATH = "res://launcher_configs/COMMON/intents.json"
const BUNDLED_CHOICES_BASE = "res://launcher_configs/"

func _ready():
	if Global.special_item == null:
		Navigator.pop()
		return
	Global.post_draw_callback = Callable(self, "show_indicators")
	ensure_choices_exist()
	populate_content()

func get_choices_path() -> String:
	return Global.root_path + Global.PATH_CONFIG + Global.special_item.system + "/choices.json"

func ensure_choices_exist():
	var path = get_choices_path()
	if FileAccess.file_exists(path):
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var bundled_path = BUNDLED_CHOICES_BASE + Global.special_item.system + "/choices.json"
	var content = FileAccess.get_file_as_string(bundled_path) if FileAccess.file_exists(bundled_path) else "{}"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()

func load_all_intent_keys() -> Array:
	var user_path = Global.root_path + Global.PATH_CONFIG + "COMMON/intents.json"
	var parsed = null
	if FileAccess.file_exists(user_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(user_path))
	if parsed == null:
		parsed = JSON.parse_string(FileAccess.get_file_as_string(BUNDLED_INTENTS_PATH))
	if parsed == null:
		return []
	var keys = parsed.keys()
	keys.sort()
	return keys

func load_choices() -> Dictionary:
	var path = get_choices_path()
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed != null else {}

func save_choices(choices: Dictionary):
	var f = FileAccess.open(get_choices_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(choices, "\t"))
		f.close()

func populate_content():
	var keys = load_all_intent_keys()
	Global.clear_visible(Global.special_item.system + " emulators", keys)
	show_indicators()

func show_indicators():
	var emulator_list = load_choices().get("EMULATOR", [])
	for i in range(Global.visible_slots.size()):
		if i >= Global.option_list.size():
			break
		Global.fav_indicators[i].visible = Global.option_list[Global.scroll_offset + i].clean in emulator_list

func _process(_delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean
		var choices = load_choices()
		var emulator_list: Array = choices.get("EMULATOR", [])
		if selected in emulator_list:
			emulator_list.erase(selected)
		else:
			emulator_list.append(selected)
		choices["EMULATOR"] = emulator_list
		save_choices(choices)
		show_indicators()
	if Global.back_pressed():
		Navigator.pop()

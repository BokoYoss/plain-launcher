extends Node

const SETTINGS_FILE = "user://settings.json"
const SETTINGS_FILE_LEGACY = "user://settings.bin"

const CFG_ROOT = "ROOT"
const CFG_LAST_SCREEN = "LAST_SCREEN"
const CFG_CONFIRM_SWAP = "SWAP"
const CFG_BG_COLOR = "COLOR_BG"
const CFG_FG_COLOR = "COLOR_FG"
const CFG_CAPS_LOCK = "CAPS_LOCK"
const CFG_SCALER = "SCALER"
const CFG_VIBRATE = "VIBRATE"
const CFG_FONT = "FONT"
const CFG_SHOW_ART = "SHOW_ART"
const CFG_VISUAL_ALT_ART_PATH = "VISUAL_ALT_ART_PATH"
const CFG_VISUAL_BORDER = "VISUAL_BORDER"
const CFG_VISUAL_SYSTEM_BORDER = "VISUAL_SYSTEM_BORDER_ENABLED"
const CFG_VISUAL_BUILTIN_SYSTEM_ART = "VISUAL_BUILTIN_SYSTEM_ART_ENABLED"
const CFG_VISUAL_DROP_SHOW = "VISUAL_DROP_SHADOW"
const CFG_VISUAL_COVER_SIZE = "VISUAL_COVER_SIZE"
const CFG_VISUAL_COVER_OPACITY = "VISUAL_COVER_OPACITY"
const CFG_VISUAL_TITLE_ORIENTATION = "VISUAL_TITLE_ORIENTATION"
const CFG_VISUAL_BODY_ORIENTATION = "VISUAL_BODY_ORIENTATION"
const CFG_VISUAL_ART_ORIENTATION = "VISUAL_ART_ORIENTATION"
const CFG_VISUAL_ART_POSITION_X = "VISUAL_ART_POS_X"
const CFG_VISUAL_ART_POSITION_Y = "VISUAL_ART_POS_Y"
const CFG_VISUAL_LETTER_OUTLINES = "VISUAL_LETTER_OUTLINES"
const CFG_LEFT_MARGIN = "TEXT_LEFT_MARGIN"
const CFG_TOP_MARGIN = "TEXT_TOP_MARGIN"
const CFG_TITLE_SIZE = "TITLE_SIZE"
const CFG_SYSTEM_TITLE = "TITLE_SYSTEM"
const CFG_TEXT_LENGTH = "TEXT_LENGTH"
const CFG_SHOW_FAVS_FIRST = "SHOW_FAVS_FIRST"
const CFG_SS_USER = "SS_USER"
const CFG_SS_PASS = "SS_PASS"
const CFG_SS_DEVID = "SS_DEVID"
const CFG_SS_DEVPASS = "SS_DEVPASS"
const CFG_SS_SOFT_NAME = "SS_SOFT_NAME"
const CFG_SGDB_KEY = "SGDB_KEY"
const CFG_SCRAPER_BACKEND = "SCRAPER_BACKEND"
const CFG_TOUCH_INVERT_SCROLL = "TOUCH_INVERT_SCROLL"

var DEFAULT_SETTINGS = {
	CFG_CONFIRM_SWAP: false,
	CFG_BG_COLOR: Color.BLACK,
	CFG_FG_COLOR: Color("#f5f7fa"),
	CFG_CAPS_LOCK: false,
	CFG_LAST_SCREEN: "",
	CFG_SCALER: 0.25,
	CFG_VIBRATE: true,
	CFG_VISUAL_ALT_ART_PATH: "",
	CFG_VISUAL_BORDER: Vector2(8, 8),
	CFG_VISUAL_BUILTIN_SYSTEM_ART: false,
	CFG_VISUAL_SYSTEM_BORDER: false,
	CFG_VISUAL_DROP_SHOW: Vector2.ZERO,
	CFG_VISUAL_COVER_SIZE: Vector2(0.4, 0.6),
	CFG_VISUAL_COVER_OPACITY: 1.0,
	CFG_VISUAL_TITLE_ORIENTATION: HORIZONTAL_ALIGNMENT_LEFT,
	CFG_VISUAL_BODY_ORIENTATION: HORIZONTAL_ALIGNMENT_LEFT,
	CFG_VISUAL_ART_ORIENTATION: 0.75,
	CFG_VISUAL_ART_POSITION_X: 0.75,
	CFG_VISUAL_ART_POSITION_Y: 0.5,
	CFG_VISUAL_LETTER_OUTLINES: 0,
	CFG_LEFT_MARGIN: 16.0,
	CFG_TOP_MARGIN: 8.0,
	CFG_TEXT_LENGTH: 0.5,
	CFG_TITLE_SIZE: 0.25,
	CFG_SYSTEM_TITLE: "SYSTEMS",
	CFG_SHOW_FAVS_FIRST: false,
	CFG_SS_USER: "",
	CFG_SS_PASS: "",
	CFG_SS_DEVID: "",
	CFG_SS_DEVPASS: "",
	CFG_SS_SOFT_NAME: "",
	CFG_SGDB_KEY: "",
	CFG_SCRAPER_BACKEND: "screenscraper",
	CFG_TOUCH_INVERT_SCROLL: false,
}

var _data = null

func get_setting(key):
	if _data == null:
		_load()
	return _data.get(key, DEFAULT_SETTINGS.get(key))

func store(key, value):
	print("STORE SETTING " + key + ": " + str(value))
	if _data == null:
		_data = {}
	_data[key] = value
	_save()

func reset():
	_data = null

func _load():
	if FileAccess.file_exists(SETTINGS_FILE):
		var f = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed != null:
			_data = _deserialize(parsed)
			print("LOAD SETTINGS (JSON): " + str(_data))
		else:
			print("LOAD SETTINGS: failed to parse JSON, using defaults")
			_data = {}
	elif FileAccess.file_exists(SETTINGS_FILE_LEGACY):
		print("LOAD SETTINGS: migrating from binary format")
		var f = FileAccess.open(SETTINGS_FILE_LEGACY, FileAccess.READ)
		_data = f.get_var()
		f.close()
		if _data == null:
			_data = {}
		_save()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE_LEGACY))
		print("LOAD SETTINGS: migration complete")
	else:
		_data = {}
	_load_secrets()

func _load_secrets():
	const SECRETS_FILE = "res://secrets.json"
	if not FileAccess.file_exists(SECRETS_FILE):
		return
	var f = FileAccess.open(SECRETS_FILE, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		return
	for key in [CFG_SS_DEVID, CFG_SS_DEVPASS, CFG_SS_SOFT_NAME]:
		if key in parsed and _data.get(key, "") == "":
			_data[key] = parsed[key]

func _save():
	var f = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(_serialize(_data), "\t"))
	f.close()

func _serialize(data: Dictionary) -> Dictionary:
	var result = {}
	for key in data:
		var val = data[key]
		if val is Color:
			result[key] = {"__type": "Color", "value": val.to_html(true)}
		elif val is Vector2:
			result[key] = {"__type": "Vector2", "x": val.x, "y": val.y}
		else:
			result[key] = val
	return result

func _deserialize(data: Dictionary) -> Dictionary:
	var result = {}
	for key in data:
		var val = data[key]
		if val is Dictionary and val.has("__type"):
			if val["__type"] == "Color":
				result[key] = Color(val["value"])
			elif val["__type"] == "Vector2":
				result[key] = Vector2(val["x"], val["y"])
			else:
				result[key] = val
		else:
			result[key] = val
	return result

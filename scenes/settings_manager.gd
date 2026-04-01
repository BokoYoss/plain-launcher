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
const CFG_SCREENSCRAPER_URL = "SCREENSCRAPER_URL"
const CFG_SGDB_KEY = "SGDB_KEY"
const CFG_SCRAPER_BACKEND = "SCRAPER_BACKEND"
const CFG_TOUCH_INVERT_SCROLL = "TOUCH_INVERT_SCROLL"

const LAYOUT_SIZES = [0.25, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0]
const COVER_SIZES = [Vector2.ZERO, Vector2(0.2, 0.3), Vector2(0.4, 0.6), Vector2(0.5, 0.8)]
const BORDER_SIZES = [Vector2.ZERO, Vector2(4, 4), Vector2(8, 8), Vector2(16, 16), Vector2(32, 32), Vector2(64, 64)]
const OPACITY_LEVELS = [0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
const SHADOW_LOCATIONS = [Vector2.ZERO, Vector2(32, 32), Vector2(-32, 32), Vector2(-32, -32), Vector2(32, -32)]
const TITLE_ORIENTATIONS = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT]
const TITLE_SIZES = [0.1, 0.15, 0.25, 0.35, 0.5, 0.75, 1.0]
const LINE_LENGTHS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75, 0.85, 1.0]
const MARGINS = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0, 48.0, 64.0]

var DEFAULT_SETTINGS = {
	CFG_CONFIRM_SWAP: false,
	CFG_BG_COLOR: Color.BLACK,
	CFG_FG_COLOR: Color("#f5f7fa"),
	CFG_CAPS_LOCK: false,
	CFG_LAST_SCREEN: "",
	CFG_SCALER: 0.0,
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
	CFG_TEXT_LENGTH: 1.0,
	CFG_TITLE_SIZE: 0.25,
	CFG_SYSTEM_TITLE: "SYSTEMS",
	CFG_SHOW_FAVS_FIRST: false,
	CFG_SS_USER: "",
	CFG_SS_PASS: "",
	CFG_SCREENSCRAPER_URL: "",
	CFG_SGDB_KEY: "",
	CFG_SCRAPER_BACKEND: "screenscraper",
	CFG_TOUCH_INVERT_SCROLL: false,
}

var _data = null

func _compute_default_scaler() -> float:
	var window_height = DisplayServer.window_get_size().y
	var raw = clampf(window_height / 960.0, LAYOUT_SIZES[0], LAYOUT_SIZES[-1])
	var best = LAYOUT_SIZES[0]
	for size in LAYOUT_SIZES:
		if abs(size - raw) < abs(best - raw):
			best = size
	return best

func get_setting(key):
	if _data == null:
		_load()
	var val = _data.get(key, DEFAULT_SETTINGS.get(key))
	if key == CFG_SCALER and val == 0.0:
		val = _compute_default_scaler()
		_data[key] = val
		_save()
	return val

func store(key, value):
	print("STORE SETTING " + key + ": " + str(value))
	if _data == null:
		_data = {}
	_data[key] = value
	_save()

const VISUAL_KEYS = [
	CFG_BG_COLOR, CFG_FG_COLOR, CFG_CAPS_LOCK, CFG_SCALER, CFG_FONT,
	CFG_VISUAL_ALT_ART_PATH, CFG_VISUAL_BORDER, CFG_VISUAL_SYSTEM_BORDER,
	CFG_VISUAL_BUILTIN_SYSTEM_ART, CFG_VISUAL_DROP_SHOW, CFG_VISUAL_COVER_SIZE,
	CFG_VISUAL_COVER_OPACITY, CFG_VISUAL_TITLE_ORIENTATION, CFG_VISUAL_BODY_ORIENTATION,
	CFG_VISUAL_ART_ORIENTATION, CFG_VISUAL_ART_POSITION_X, CFG_VISUAL_ART_POSITION_Y,
	CFG_VISUAL_LETTER_OUTLINES, CFG_LEFT_MARGIN, CFG_TOP_MARGIN, CFG_TITLE_SIZE,
	CFG_SYSTEM_TITLE, CFG_TEXT_LENGTH,
]

func reset_visual():
	if _data == null:
		_load()
	for key in VISUAL_KEYS:
		if DEFAULT_SETTINGS.has(key):
			_data[key] = DEFAULT_SETTINGS[key]
		else:
			_data.erase(key)
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
	for key in [CFG_SCREENSCRAPER_URL]:
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

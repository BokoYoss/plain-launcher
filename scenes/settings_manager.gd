extends Node

const SETTINGS_FILE = "user://settings.json"
const SETTINGS_FILE_LEGACY = "user://settings.bin"

const CFG_ROOT = "ROOT"
const CFG_LAST_SCREEN = "LAST_SCREEN"
const CFG_CONFIRM_SWAP = "SWAP"
const CFG_CONFIRM_SET = "CONFIRM_SET"
const CFG_BG_COLOR = "COLOR_BG"
const CFG_FG_COLOR = "COLOR_FG"
const CFG_BAR_COLOR = "COLOR_BAR"
const CFG_COVER_AREA_COLOR = "COLOR_COVER_AREA"
const CFG_CAPS_LOCK = "CAPS_LOCK"
const CFG_SCALER = "SCALER"
const CFG_TEXT_FACTOR = "TEXT_FACTOR"
const CFG_VIBRATE = "VIBRATE"
const CFG_FONT = "FONT"
const CFG_SHOW_ART = "SHOW_ART"
const CFG_VISUAL_BORDER = "VISUAL_BORDER"
const CFG_VISUAL_SYSTEM_BORDER = "VISUAL_SYSTEM_BORDER_ENABLED"
const CFG_VISUAL_SYSTEM_ART = "VISUAL_SYSTEM_ART"
const CFG_VISUAL_DROP_SHOW = "VISUAL_DROP_SHADOW"
const CFG_VISUAL_COVER_SIZE = "VISUAL_COVER_SIZE"
const CFG_VISUAL_COVER_OPACITY = "VISUAL_COVER_OPACITY"
const CFG_VISUAL_TITLE_ORIENTATION = "VISUAL_TITLE_ORIENTATION"
const CFG_VISUAL_BODY_ORIENTATION = "VISUAL_BODY_ORIENTATION"
const CFG_VISUAL_ART_ORIENTATION = "VISUAL_ART_ORIENTATION"
const CFG_VISUAL_ART_POSITION_X = "VISUAL_ART_POS_X"
const CFG_VISUAL_ART_POSITION_Y = "VISUAL_ART_POS_Y"
const CFG_VISUAL_LETTER_OUTLINES = "VISUAL_LETTER_OUTLINES"
const CFG_VISUAL_PROMPT_BAR = "VISUAL_PROMPT_BAR_ENABLED"
const CFG_EFFECTS = "EFFECTS"
const CFG_VOLUME_MASTER = "VOLUME_MASTER"
const CFG_VOLUME_SCROLL = "VOLUME_SCROLL"
const CFG_VOLUME_SELECT = "VOLUME_SELECT"
const CFG_VOLUME_BACK = "VOLUME_BACK"
const SOUND_VOLUME_KEYS = {"move": CFG_VOLUME_SCROLL, "accept": CFG_VOLUME_SELECT, "back": CFG_VOLUME_BACK}
const CFG_LAUNCH_VIEW = "LAUNCH_VIEW"
const LAUNCH_VIEWS = ["cover_info", "cover", "info", "none"]
const CFG_LEFT_MARGIN = "TEXT_LEFT_MARGIN"
const CFG_TOP_MARGIN = "TEXT_TOP_MARGIN"
const CFG_TITLE_SIZE = "TITLE_SIZE"
const CFG_SYSTEM_TITLE = "TITLE_SYSTEM"
const CFG_TEXT_LENGTH = "TEXT_LENGTH"
const CFG_SHOW_FAVS_FIRST = "SHOW_FAVS_FIRST"
const CFG_SS_USER = "SS_USER"
const CFG_SS_PASS = "SS_PASS"
const CFG_SGDB_KEY = "SGDB_KEY"
const CFG_SCRAPER_BACKEND = "SCRAPER_BACKEND"
const CFG_TOUCH_INVERT_SCROLL = "TOUCH_INVERT_SCROLL"
const CFG_TOUCH_ENABLED = "TOUCH_ENABLED"
const CFG_RETROARCH_QUIT_ON_LEAVE = "RETROARCH_QUIT_ON_LEAVE"
const CFG_RETROARCH_OWN_CONFIG = "RETROARCH_OWN_CONFIG"
const CFG_COVER_SIDE = "COVER_SIDE"
const CFG_NEARBY_COVERS = "NEARBY_COVERS"
const CFG_COVER_STYLE = "COVER_STYLE"
const CFG_LAUNCH_ON_BOOT = "LAUNCH_ON_BOOT"
const CFG_BOOT_HOOK = "BOOT_HOOK"
const COVER_STYLES = ["single", "stacked", "wheel", "inline"]
const CFG_ROW_STRIPES = "ROW_STRIPES"

const LAYOUT_SIZES = [0.25, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0]
const INLINE_COVER = Vector2(-1, -1)
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
	CFG_CONFIRM_SET: false,
	CFG_BG_COLOR: Color.BLACK,
	CFG_FG_COLOR: Color("#f5f7fa"),
	CFG_BAR_COLOR: null,
	CFG_COVER_AREA_COLOR: null,
	CFG_CAPS_LOCK: false,
	CFG_LAST_SCREEN: "",
	CFG_SCALER: 0.0,
	CFG_TEXT_FACTOR: 1.0,
	CFG_VIBRATE: true,
	CFG_VISUAL_BORDER: Vector2(8, 8),
	CFG_VISUAL_SYSTEM_ART: false,
	CFG_VISUAL_SYSTEM_BORDER: false,
	CFG_VISUAL_PROMPT_BAR: true,
	CFG_EFFECTS: true,
	CFG_VOLUME_MASTER: 100,
	CFG_VOLUME_SCROLL: 15,
	CFG_VOLUME_SELECT: 35,
	CFG_VOLUME_BACK: 35,
	CFG_LAUNCH_VIEW: "cover_info",
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
	CFG_SGDB_KEY: "",
	CFG_SCRAPER_BACKEND: "screenscraper",
	CFG_TOUCH_INVERT_SCROLL: false,
	CFG_TOUCH_ENABLED: true,
	CFG_RETROARCH_QUIT_ON_LEAVE: false,
	CFG_RETROARCH_OWN_CONFIG: false,
	CFG_COVER_SIDE: "right",
	CFG_COVER_STYLE: "single",
	CFG_ROW_STRIPES: false,
}

var _data = null

static func window_scaler(window: Vector2i) -> float:
	return clampf(mini(window.x, window.y) / 960.0, LAYOUT_SIZES[0], LAYOUT_SIZES[-1])

static func follows_window() -> bool:
	return OS.get_name() != "Android"

func text_scaler() -> float:
	if not follows_window():
		return get_setting(CFG_SCALER)
	return window_scaler(DisplayServer.window_get_size()) * get_setting(CFG_TEXT_FACTOR)

func migrate_text_factor(factors: Array):
	if not follows_window() or has_setting(CFG_TEXT_FACTOR) or not has_setting(CFG_SCALER):
		return
	var ratio = get_setting(CFG_SCALER) / _compute_default_scaler()
	var best = factors[0]
	for factor in factors:
		if absf(factor - ratio) < absf(best - ratio):
			best = factor
	store(CFG_TEXT_FACTOR, best)

func _compute_default_scaler() -> float:
	var window = DisplayServer.window_get_size()
	var raw = clampf(mini(window.x, window.y) / 960.0, LAYOUT_SIZES[0], LAYOUT_SIZES[-1])
	var best = LAYOUT_SIZES[0]
	for size in LAYOUT_SIZES:
		if abs(size - raw) < abs(best - raw):
			best = size
	return best

const RETIRED_KEYS = [
	CFG_VISUAL_COVER_OPACITY, CFG_VISUAL_DROP_SHOW, CFG_VISUAL_SYSTEM_BORDER, CFG_VISUAL_LETTER_OUTLINES,
	CFG_LEFT_MARGIN, CFG_TOP_MARGIN, CFG_TITLE_SIZE, CFG_TEXT_LENGTH,
	CFG_VISUAL_ART_POSITION_X, CFG_VISUAL_ART_POSITION_Y, CFG_NEARBY_COVERS,
	CFG_LAUNCH_ON_BOOT, CFG_BOOT_HOOK,
]

const SECRET_KEYS = [CFG_SS_PASS, CFG_SGDB_KEY]

static func loggable(data: Dictionary) -> Dictionary:
	var shown = data.duplicate()
	for key in SECRET_KEYS:
		if shown.get(key, "") != "":
			shown[key] = "***"
	return shown

func has_setting(key) -> bool:
	if _data == null:
		_load()
	return _data.has(key)

func get_setting(key):
	if _data == null:
		_load()
	if key in RETIRED_KEYS:
		return DEFAULT_SETTINGS.get(key)
	var val = _data.get(key, DEFAULT_SETTINGS.get(key))
	if key == CFG_VISUAL_BORDER and val != Vector2.ZERO:
		return DEFAULT_SETTINGS[CFG_VISUAL_BORDER]
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
	CFG_VISUAL_PROMPT_BAR, CFG_EFFECTS, CFG_LAUNCH_VIEW,
	CFG_BG_COLOR, CFG_FG_COLOR, CFG_BAR_COLOR, CFG_COVER_AREA_COLOR, CFG_COVER_SIDE, CFG_COVER_STYLE, CFG_ROW_STRIPES, CFG_CAPS_LOCK, CFG_SCALER, CFG_TEXT_FACTOR, CFG_FONT,
	CFG_VISUAL_BORDER, CFG_VISUAL_SYSTEM_BORDER,
	CFG_VISUAL_SYSTEM_ART, CFG_VISUAL_DROP_SHOW, CFG_VISUAL_COVER_SIZE,
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
			print("LOAD SETTINGS (JSON): " + str(loggable(_data)))
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
	var migrated = migrated_cover_style(_data)
	if migrated != _data:
		_data = migrated
		_save()

static func migrated_cover_style(data: Dictionary) -> Dictionary:
	var result = data.duplicate()
	if result.get(CFG_VISUAL_COVER_SIZE) == INLINE_COVER:
		result[CFG_VISUAL_COVER_SIZE] = COVER_SIZES[2]
		if not result.has(CFG_COVER_STYLE):
			result[CFG_COVER_STYLE] = "inline"
	if not result.has(CFG_COVER_STYLE) and result.get(CFG_NEARBY_COVERS, false):
		result[CFG_COVER_STYLE] = "stacked"
	result.erase(CFG_NEARBY_COVERS)
	return result

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

static func supported_font(path):
	if path == null or path == "" or ResourceLoader.exists(path):
		return path
	var family = str(path).get_base_dir().get_file()
	var single = str(path).get_base_dir() + "/" + family + ".ttf"
	if ResourceLoader.exists(single):
		return single
	return null

extends Node2D

var window_height = 0
var window_width = 0
var title_offset = 0

var root_path = ""
var waiting_root_path = ""

const PATH_CONFIG = "/Config/"
const PATH_GAMES = "/Games/"
const PATH_IMAGES = "/Imgs/"

var option_list = []
var visible_slots = []
var option_selection = 0
var scroll_offset = 0

var current_screen = null
var current_directory = ""

var pending_intent = ""
var pending_game = ""
var pending_launch = ""
var last_launch = {}
var last_subscreen = ""
var can_scroll = true
var failure_message = ""

var title: Label = null
var message: Label = null
@onready var fade = $FarFade
@onready var slot_holder = $SlotHolder
var message_queue = []
var cursor_positions = {}
var cursor_indices = {}
var scroll_offsets = {}

var confirming = false

var default_text_height = 128
var scaled_text_height = 0
var text_height = default_text_height
var left_bound = 0.0
var special_orientation_leftward = 23
var special_orientation_rightward = 24
var slot_offset = left_bound
var slot_size = Vector2.ZERO

const SCREEN_TEENY = 0.25
const SCREEN_TINY = 0.5
const SCREEN_SMALL = 0.75
const SCREEN_MED = 1.0
const SCREEN_MED_BIG = 1.25
const SCREEN_BIG = 1.5
const SCREEN_HUGE = 2.0

var subscreen = null
var show_hidden = false
var title_can_be_blank = false
var title_collapsed = false

var disable_scroll := false

var held_time = -1
var frame = 0
var _analog_left_just: bool = false
var _analog_right_just: bool = false

var null_option = option.new()
var clean_regex = null
var normalize_regex = null

@onready var BACKDROP = $ColorRect

var current_msg = ""

var ALIAS_MAP = {}
var HIDDEN_LIST = {}

var favorites_list = {}
var fav_indicators = []

var no_alias = false
var confirm_swapped = false
var special_item = null

# For touch controls
var touch_enabled = true
var touch_position = null
var touch_start_position = null
var touch_start_time = -1
var touch_check_time = -1
var touch_velocity: float = 0.0
var touch_scroll_accum: float = 0.0
var touch_is_scrolling: bool = false
var touch_momentum: float = 0.0
var previous_touch_position = null
var pending_special = false
var pending_back = false

# Generic checkbox selector state
var waiting_for_confirm_release: bool = false
var control_tilt: Vector2 = Vector2.ZERO
var tilt_ratio = 0
@onready var TOUCH_POINTS = $TouchPoints
@onready var TOUCH_START = $TouchPoints/TouchStart
@onready var TOUCH_CURRENT = $TouchPoints/TouchCurrent
@onready var TOUCH_BRIDGE = $TouchPoints/TouchBridge

var confirm_hold_time = null

# screen callbacks
var post_draw_callback = null
var post_scroll_callback = null
var on_leave_screen = null
var populate_filter = null

# Directory listing cache: { "path|dirs_only" -> PackedStringArray }
var _dir_cache: Dictionary = {}
var _missing_dirs: Dictionary = {}
var _prewarm_task = -1
var _prewarm_done = false

func clear_dir_cache():
	print("DIR CACHE: cleared (" + str(_dir_cache.size()) + " entries)")
	_dir_cache.clear()
	_missing_dirs.clear()
	_prewarm_done = false
	_art_missing.clear()
	Launcher.forget_intents()

func _read_dir_uncached(directory: DirAccess, dirs_only: bool) -> PackedStringArray:
	var file_names: PackedStringArray = []
	if dirs_only:
		directory.list_dir_begin()
		var file_name = directory.get_next()
		while file_name != "":
			if directory.dir_exists(file_name):
				file_names.append(file_name)
			file_name = directory.get_next()
		directory.list_dir_end()
		file_names.sort()
	else:
		for f in directory.get_files():
			file_names.append(f)
	return file_names

func _read_dir_cached(directory: DirAccess, dirs_only: bool) -> PackedStringArray:
	var cache_key = directory.get_current_dir() + "|" + str(dirs_only)
	if _dir_cache.has(cache_key):
		return _dir_cache[cache_key]
	var result = _read_dir_uncached(directory, dirs_only)
	_dir_cache[cache_key] = result
	return result

static func is_game_file(filename: String, extensions) -> bool:
	return extensions == null or filename.get_extension() in extensions

func _dir_has_files(path: String, extensions = null) -> bool:
	if _missing_dirs.has(path):
		return false
	var dir = DirAccess.open(path)
	if dir == null:
		_missing_dirs[path] = true
		return false
	dir.list_dir_begin()
	var found = false
	var entry = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and is_game_file(entry, extensions):
			found = true
			break
		entry = dir.get_next()
	dir.list_dir_end()
	return found

func found_paths(system_name: String) -> Array:
	var own = [root_path + PATH_GAMES + "/" + system_name] + get_user_paths(system_name)
	var found = []
	for path in compat_paths(system_name):
		if DirAccess.dir_exists_absolute(path) and path not in found and path not in own:
			found.append(path)
	return found

func _get_all_system_paths(system_name: String) -> Array:
	var paths = [root_path + PATH_GAMES + "/" + system_name]
	var paths_file = root_path + PATH_CONFIG + system_name + "/paths.txt"
	if FileAccess.file_exists(paths_file):
		for path in FileAccess.get_file_as_string(paths_file).split("\n"):
			path = path.strip_edges()
			if path != "":
				paths.append(path)
	paths.append_array(compat_paths(system_name))
	return paths

func _system_has_games(system_name: String) -> bool:
	var extensions = get_system_settings(system_name).get("EXTENSIONS")
	for path in _get_all_system_paths(system_name):
		if _dir_has_files(path, extensions):
			return true
	return false

func prewarm_dir_cache(systems: PackedStringArray):
	if _prewarm_task >= 0 or _prewarm_done:
		return
	var paths = []
	for system in systems:
		paths.append_array(_get_all_system_paths(system))
	if sync_loading:
		_prewarm_done = true
		merge_dir_listings(read_dir_listings(paths))
		return
	_prewarm_task = WorkerThreadPool.add_task(_read_dirs.bind(paths))

static func read_dir_listings(paths: Array) -> Dictionary:
	var listings = {}
	for path in paths:
		var dir = DirAccess.open(path)
		listings[path] = null if dir == null else {"key": dir.get_current_dir() + "|false", "files": dir.get_files()}
	return listings

func _read_dirs(paths: Array):
	_on_dirs_read.call_deferred(read_dir_listings(paths))

func _on_dirs_read(listings: Dictionary):
	if _prewarm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_prewarm_task)
		_prewarm_task = -1
	_prewarm_done = true
	merge_dir_listings(listings)

func merge_dir_listings(listings: Dictionary):
	for path in listings:
		var entry = listings[path]
		if entry == null:
			_missing_dirs[path] = true
		elif not _dir_cache.has(entry.key):
			_dir_cache[entry.key] = entry.files

func get_nonempty_systems() -> PackedStringArray:
	var cache_key = "_nonempty_systems"
	if _dir_cache.has(cache_key):
		return _dir_cache[cache_key]
	var games_dir = DirAccess.open(root_path + PATH_GAMES)
	if games_dir == null:
		return PackedStringArray()
	var all_dirs = _read_dir_cached(games_dir, true)
	var result: PackedStringArray = []
	for dir_name in all_dirs:
		if _system_has_games(dir_name):
			result.append(dir_name)
		else:
			print("Skipping empty system: " + dir_name)
	_dir_cache[cache_key] = result
	return result

var font = null

const PromptBar = preload("res://scenes/prompt_bar.gd")
const SettingsMenu = preload("res://scenes/settings_menu.gd")
const OptionsMenu = preload("res://scenes/options_menu.gd")
const FavoriteStarScript = preload("res://scenes/favorite_star.gd")
const CoverHalo = preload("res://scenes/cover_halo.gd")
const StorageSetup = preload("res://scenes/storage_setup.gd")
const CLEAN_PATTERN = "\\s*\\(.+\\)\\s*|\\s*\\[.+\\]\\s*|T.Eng+\\$|\\.nkit"
const COVER_FADE = 0.3
var cover_halo = null
const TouchButtons = preload("res://scenes/touch_buttons.gd")
var touch_buttons = null
const LetterScroller = preload("res://scenes/letter_scroller.gd")
var letter_scroller = null
const RowStripes = preload("res://scenes/row_stripes.gd")
var row_stripes = null
const InlineCovers = preload("res://scenes/inline_covers.gd")
var inline_layer = null
var settings_panel = null
var settings_menu = null
var options_menu = null
var settings_reopen_section = null
var force_cover = false
var header_bar: ColorRect = null

func panel_open() -> bool:
	return settings_panel != null and settings_panel.is_open

func open_settings(section: String = ""):
	if settings_menu != null and not panel_open():
		settings_menu.open(section)

func show_launch_failure(message: String):
	failure_message = message
	if settings_menu == null:
		return
	if panel_open():
		settings_panel.close()
	settings_menu.open_failure()

func open_options(item):
	if options_menu != null and not panel_open() and item != null:
		options_menu.open(item)

func resume_settings_panel():
	if settings_reopen_section != null:
		var section = settings_reopen_section
		settings_reopen_section = null
		open_settings(section)

static func bar_color_for(bar, background: Color) -> Color:
	return bar if bar is Color else background

func bar_color() -> Color:
	return bar_color_for(Settings.get_setting(Settings.CFG_BAR_COLOR), Settings.get_setting(Settings.CFG_BG_COLOR))

var cover_area: ColorRect = null

static func cover_area_span(screen_width: float, left: float, box: float, gap: float, cover_left: bool, inline: bool) -> Vector2:
	if inline:
		return Vector2(0.0, left * 2.0 + box) if cover_left else Vector2(screen_width - left * 2.0 - box, screen_width)
	if cover_left:
		return Vector2(0.0, left + box + gap / 2.0)
	return Vector2(screen_width - left - box - gap / 2.0, screen_width)

func cover_area_color():
	var color = Settings.get_setting(Settings.CFG_COVER_AREA_COLOR)
	return color if color is Color else null

func layout_cover_area():
	if cover_area == null or title == null:
		return
	var color = cover_area_color()
	cover_area.visible = color != null and (inline_covers() or (cover != null and not force_cover and art_enabled_here()))
	if not cover_area.visible:
		return
	cover_area.color = color
	var gap = scaled_text_height * 0.3
	var box = inline_box().x if inline_covers() else window_width * cover_size().x
	var span = cover_area_span(window_width, left_bound, box, gap, cover_on_left(), inline_covers())
	cover_area.position = Vector2(span.x, 0.0)
	cover_area.size = Vector2(span.y - span.x, window_height + title_offset)

func layout_header():
	if header_bar == null or title == null:
		return
	header_bar.color = bar_color()
	header_bar.visible = true
	header_bar.position = Vector2.ZERO
	header_bar.size = Vector2(window_width, maxf(0.0, title.position.y + title.size.y))

func apply_visual_change():
	BACKDROP.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)
	set_up_slots()
	title.position.x = left_bound
	show_options(scroll_offset)
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	highlight_selection(option_selection)
	refresh_art()
	refresh_prompt_bar()
	layout_message()

var peek_rows = 0
const PEEK_MIN_PIXELS = 1.0

static func peek_rows_for(first_middle: float, rows: int, step: float, bottom_edge: float) -> int:
	return 1 if first_middle + (rows - 0.5) * step < bottom_edge - PEEK_MIN_PIXELS else 0

static func text_fits(text_bottom: float, limit: float) -> bool:
	return text_bottom <= limit

func show_peek_text():
	if peek_rows == 0 or visible_slots.is_empty():
		return
	var slot: Label = visible_slots.back()
	var bottom = slot.global_position.y + slot_text_middle(slot) + slot.get_theme_font("font").get_height(slot.get_theme_font_size("font_size")) / 2.0
	slot.visible = text_fits(bottom, list_bottom())

func list_bottom() -> float:
	return window_height - prompt_bar_height()

func focus_rows() -> int:
	return maxi(1, visible_slots.size() - peek_rows)

func select_by_path(path: String, fallback_row: int, previous_offset: int = -1):
	var index = option_list.find_custom(func(o): return o.absolute_path == path)
	if index < 0:
		index = clampi(fallback_row, 0, maxi(0, option_list.size() - 1))
	if option_list.is_empty():
		return
	option_selection = index
	var offset = previous_offset if previous_offset >= 0 and index >= previous_offset and index < previous_offset + focus_rows() else index - focus_rows() / 2
	scroll_offset = clampi(offset, 0, maxi(0, option_list.size() - focus_rows()))
	show_options(scroll_offset)
	highlight_selection()
	refresh_art()

func select_by_filename(filename: String) -> bool:
	for i in range(option_list.size()):
		if option_list[i].filename == filename:
			option_selection = i
			scroll_offset = clampi(i - focus_rows() / 2, 0, maxi(0, option_list.size() - focus_rows()))
			show_options(scroll_offset)
			highlight_selection(i)
			refresh_art()
			return true
	return false

static func kept_position(selection: int, offset: int, count: int, rows: int) -> Vector2i:
	var row = clampi(selection, 0, maxi(0, count - 1))
	return Vector2i(row, clampi(offset, 0, maxi(0, count - rows)))

func refresh_file_cache():
	var selected = get_selected().filename if not option_list.is_empty() else ""
	var previous = Vector2i(option_selection, scroll_offset)
	clear_dir_cache()
	var top = Navigator._stack.back() if not Navigator._stack.is_empty() else null
	if top != null and top.node.has_method("populate_content"):
		top.node.populate_content()
		if not select_by_filename(selected):
			var kept = kept_position(previous.x, previous.y, option_list.size(), focus_rows())
			option_selection = kept.x
			scroll_offset = kept.y
			show_options(scroll_offset)
			highlight_selection()
			refresh_art()

func list_text_width() -> float:
	return window_width - left_bound * 2.0
const DEFAULT_PROMPTS = [["confirm", "Select"], ["back", "Back"]]
var prompt_bar = null
var prompts: Array = DEFAULT_PROMPTS

const MESSAGE_SCROLL_PAUSE = 1.0
var message_clip: Control = null
var message_overflow = 0.0
var message_scroll_time = 0.0
var message_scroll_passes = 0

func prompt_text_size() -> int:
	return text_size_for_scale(prompt_scale)

func title_bar_height() -> float:
	return prompt_text_size() * 2.0

func text_size_for_scale(scale: float) -> int:
	return maxi(12, int(scaled_text_height * 0.5 * scale))

static func message_scroll_x(time: float, overflow: float, speed: float, pause: float) -> float:
	return -clampf((time - pause) * speed, 0.0, overflow)

func layout_message():
	if message == null or message_clip == null:
		return
	var size = prompt_text_size()
	var row = prompt_bar_height() if prompt_bar_enabled() else scaled_text_height * 0.5
	var left = left_bound
	if prompt_bar != null and prompt_bar_enabled() and not prompts.is_empty():
		left = prompt_bar.content_end() + size
	var right = window_width - maxf(left_bound, 2.0)
	message_clip.position = Vector2(left, window_height - row)
	message_clip.size = Vector2(maxf(0.0, right - left), row)
	message.set("theme_override_font_sizes/font_size", size)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_OFF
	message.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var shown = message.text.to_upper() if message.uppercase else message.text
	var text_width = message.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	message.size = Vector2(text_width + 1.0, row)
	message.position.y = 0.0
	message_overflow = maxf(0.0, text_width - message_clip.size.x)
	message_scroll_time = 0.0
	message_scroll_passes = 0
	message.position.x = 0.0 if message_overflow > 0.0 else message_clip.size.x - text_width

func prompt_bar_enabled() -> bool:
	return Settings.get_setting(Settings.CFG_VISUAL_PROMPT_BAR)

func prompt_bar_height() -> float:
	return prompt_text_size() * 2.0 if prompt_bar_enabled() else 0.0

func set_prompts(list: Array):
	prompts = list
	if prompt_bar != null:
		prompt_bar.set_prompts(list)
	layout_message()

func refresh_prompt_bar():
	if prompt_bar != null:
		prompt_bar.queue_redraw()

var VERSION = "30"

# Cover art
@onready var cover := $BoxContainer
var cover_art: Sprite2D = null
var drop_shadow: Sprite2D = null
var border: Sprite2D = null
var reload_art = false
var border_thickness_text = ""
var cover_size_text = ""
var drop_shadow_text = ""
var img_texture_override = null

var clean_names = {}

func dir_walker(root):
	var dir = DirAccess.open(root)
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		print(dir.get_current_dir() + item)
		var maybe_dir = DirAccess.open(dir.get_current_dir() + item)
		if maybe_dir != null:
			print("FOUND DIR " + maybe_dir.get_current_dir())
			dir_walker(maybe_dir.get_current_dir())
		item = dir.get_next()

var pad_debug = OS.get_environment("PLAIN_LAUNCHER_PAD_DEBUG") != ""
var _pad_log: FileAccess = null

func pad_note(text: String):
	print(text)
	if not pad_debug:
		return
	if _pad_log == null:
		_pad_log = FileAccess.open("user://pad_debug.log", FileAccess.WRITE)
	if _pad_log != null:
		_pad_log.store_line(text)
		_pad_log.flush()

func log_pads():
	for pad in Input.get_connected_joypads():
		pad_note("PAD %d name=%s guid=%s known=%s" % [pad, Input.get_joy_name(pad), Input.get_joy_guid(pad), Input.is_joy_known(pad)])

func _ready():
	if pad_debug:
		log_pads.call_deferred()
	if Platform.is_desktop_build() and DisplayServer.get_name() != "headless" and OS.get_environment("PLAIN_LAUNCHER_WINDOWED") != "1":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	window_width = display_size().x
	window_height = display_size().y
	if window_height / window_width >= 2.0:
		title_offset = text_height
		window_height -= title_offset
	else:
		title_offset = 0
	BACKDROP.size = Vector2(window_width, window_height)
	root_path = Settings.get_setting(Settings.CFG_ROOT)
	if root_path != null and !DirAccess.dir_exists_absolute(root_path):
		waiting_root_path = root_path
		root_path = null
	if (root_path == null or root_path == "") and waiting_root_path == "":
		_use_environment_root()

	BACKDROP.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)

	clean_regex = RegEx.create_from_string(CLEAN_PATTERN)

	normalize_regex = RegEx.new()
	normalize_regex.compile("[^a-z0-9]")

	get_tree().get_root().size_changed.connect(resize)

	set_up_slots()

	for pad in Input.get_connected_joypads():
		print("Joy {0}: {1} ({2}) {3}".format([Input.get_joy_guid(pad), pad, Input.get_joy_name(pad)]))

	cover_art = Sprite2D.new()
	drop_shadow = cover_art.duplicate()
	drop_shadow.modulate = Color.BLACK
	border = $Pixel.duplicate()
	border.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)
	cover.size = Vector2(Global.window_width * 0.25, Global.window_height * 0.75)
	cover.add_child.call_deferred(drop_shadow)
	cover.add_child.call_deferred(border)
	cover.add_child.call_deferred(cover_art)
	cover.position = Vector2(window_width, window_height) * cover_anchor()

	load_hidden_list()

	Input.joy_connection_changed.connect(func(_device, connected):
		if connected:
			ask_for_confirm_button.call_deferred())
	Settings.migrate_text_factor(SettingsMenu.TEXT_SIZE_FACTORS)
	if Settings.get_setting(Settings.CFG_CONFIRM_SWAP):
		swap_confirm_key()
	using_keyboard = Platform.is_desktop_build() and Input.get_connected_joypads().is_empty()

	OS.request_permissions()

	get_positions_files()

	cover_area = ColorRect.new()
	cover_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover_area)
	move_child(cover_area, BACKDROP.get_index() + 1)
	header_bar = ColorRect.new()
	header_bar.z_index = BAR_Z
	add_child(header_bar)
	move_child(header_bar, BACKDROP.get_index() + 2)
	layout_header()
	layout_cover_area()
	row_stripes = RowStripes.new()
	slot_holder.add_child(row_stripes)
	slot_holder.move_child(row_stripes, 0)
	inline_layer = InlineCovers.new()
	slot_holder.add_child(inline_layer)
	slot_holder.move_child(inline_layer, 1)
	letter_scroller = LetterScroller.new()
	letter_scroller.z_index = 4004
	letter_scroller.size = Vector2(window_width, window_height)
	add_child(letter_scroller)
	touch_buttons = TouchButtons.new()
	touch_buttons.z_index = 4004
	touch_buttons.size = Vector2(window_width, window_height)
	add_child(touch_buttons)
	prompt_bar = PromptBar.new()
	prompt_bar.z_index = 4001
	add_child(prompt_bar)
	settings_panel = SlidePanel.new()
	settings_panel.z_index = 4002
	add_child(settings_panel)
	settings_menu = SettingsMenu.new(settings_panel)
	options_menu = OptionsMenu.new(settings_panel)
	prompt_bar.set_prompts(prompts)
	show_message("Welcome to PlainLauncher!")
	Navigator.go_to_main()

func _use_environment_root():
	var env_root = OS.get_environment("PLAIN_LAUNCHER_ROOT")
	if env_root == "":
		return
	DirAccess.make_dir_recursive_absolute(env_root)
	if StorageSetup.set_up_root(DirAccess.open(env_root)):
		root_path = Settings.get_setting(Settings.CFG_ROOT)

static func existing_dirs(candidates: Array) -> Array:
	return candidates.filter(func(c): return c != "" and DirAccess.dir_exists_absolute(c))

static func media_mounts(suffix: String) -> Array:
	var mounts = []
	for base in existing_dirs(["/run/media", "/run/media/deck", "/media/" + OS.get_environment("USER")]):
		for child in DirAccess.get_directories_at(base):
			mounts.append(base.path_join(child).path_join(suffix))
	return mounts

var _compat_prefixes = null

func compat_prefixes() -> Array:
	if OS.get_name() == "Android":
		var external = Platform.get_external_storage_path()
		return [external] if external != null else []
	if _compat_prefixes == null:
		var home = Platform.home_dir()
		_compat_prefixes = existing_dirs(Array(OS.get_environment("PLAIN_LAUNCHER_ROMS").split(":")) + [home.path_join("Emulation/roms"), home.path_join("ROMs")] + media_mounts("Emulation/roms"))
	return _compat_prefixes

func compat_paths(system: String) -> Array:
	var compat_file = get_compat_paths_filepath(system)
	if not FileAccess.file_exists(compat_file):
		return existing_dirs(Array(OS.get_environment("PLAIN_LAUNCHER_" + system + "_PATHS").split(":", false)))
	var lines = Array(FileAccess.get_file_as_string(compat_file).split("\n")).map(func(l): return l.strip_edges()).filter(func(l): return l != "")
	var paths = []
	for prefix in compat_prefixes():
		for line in lines:
			paths.append(prefix + line)
	paths.append_array(existing_dirs(Array(OS.get_environment("PLAIN_LAUNCHER_" + system + "_PATHS").split(":", false))))
	return paths

func load_hidden_list():
	HIDDEN_LIST.clear()
	for item in get_list_file_contents().get("hidden", []):
		HIDDEN_LIST[item] = true

func storage_ready():
	print("Storage available at " + waiting_root_path)
	root_path = waiting_root_path
	waiting_root_path = ""
	load_hidden_list()
	Navigator.go_to_main()

func version_matches():
	var version_file = FileAccess.get_file_as_string("user://version.txt")
	return VERSION == version_file

func store_version():
	var version_file = FileAccess.open("user://version.txt", FileAccess.WRITE)
	if version_file == null:
		return
	version_file.store_string(VERSION)

func reimport_all_configs():
	if root_path == "" or root_path == null:
		return
	const BUNDLED_BASE = "res://launcher_configs/"
	const SKIP_EXTENSIONS = [".png", ".import", ".ttf", ".otf"]
	var base_dir = DirAccess.open(BUNDLED_BASE)
	if base_dir == null:
		return
	for system in base_dir.get_directories():
		var system_dir = DirAccess.open(BUNDLED_BASE + system)
		if system_dir == null:
			continue
		system_dir.list_dir_begin()
		var file = system_dir.get_next()
		while file != "":
			if not system_dir.current_is_dir():
				var skip = false
				for ext in SKIP_EXTENSIONS:
					if file.ends_with(ext):
						skip = true
						break
				if not skip:
					var src = BUNDLED_BASE + system + "/" + file
					var dst_dir = root_path + PATH_CONFIG + system + "/"
					var dst = dst_dir + file
					DirAccess.make_dir_recursive_absolute(dst_dir)
					var content = FileAccess.get_file_as_string(src)
					var f = FileAccess.open(dst, FileAccess.WRITE)
					if f:
						f.store_string(content)
						f.close()
			file = system_dir.get_next()
	# Copy COMMON files (intents.json, alias.json, lists.json)
	var common_dir = DirAccess.open(BUNDLED_BASE + "COMMON")
	if common_dir:
		common_dir.list_dir_begin()
		var file = common_dir.get_next()
		while file != "":
			if not common_dir.current_is_dir():
				var skip = false
				for ext in SKIP_EXTENSIONS:
					if file.ends_with(ext):
						skip = true
						break
				if not skip:
					var src = BUNDLED_BASE + "COMMON/" + file
					var dst_dir = root_path + PATH_CONFIG + "COMMON/"
					DirAccess.make_dir_recursive_absolute(dst_dir)
					var content = FileAccess.get_file_as_string(src)
					var f = FileAccess.open(dst_dir + file, FileAccess.WRITE)
					if f:
						f.store_string(content)
						f.close()
			file = common_dir.get_next()
	print("reimport_all_configs: done")

func migrate_configs():
	if root_path == "" or root_path == null:
		return
	_migrate_choices()

func _migrate_choices():
	var bundled_base = "res://launcher_configs/"
	var dir = DirAccess.open(bundled_base)
	if dir == null:
		return
	for system in dir.get_directories():
		var bundled_path = bundled_base + system + "/choices.json"
		if not FileAccess.file_exists(bundled_path):
			continue
		var user_path = root_path + PATH_CONFIG + system + "/choices.json"
		var bundled = read_json_dict(bundled_path)
		if bundled.is_empty():
			continue
		var user_choices = read_json_dict(user_path)
		var changed = not FileAccess.file_exists(user_path)
		for key in bundled.keys():
			if key.to_upper() == "EXTENSIONS":
				continue  # user manages extensions manually
			var bundled_arr: Array = bundled[key]
			var user_arr: Array = user_choices.get(key, [])
			for item in bundled_arr:
				if item not in user_arr:
					user_arr.append(item)
					changed = true
			user_choices[key] = user_arr
		if changed:
			write_json(user_path, user_choices)

func read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func write_json(path: String, data, indent: String = "\t"):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, indent))
		f.close()

const RECENT_MAX = 50

func get_recent_list() -> Array:
	if root_path == null:
		return []
	return read_json_array(root_path + "/Config/COMMON/recent.json")

func log_recent(game_path: String, system: String, display_name: String):
	if root_path == null:
		return
	var recent = get_recent_list()
	for i in range(recent.size() - 1, -1, -1):
		if recent[i].get("path") == game_path:
			recent.remove_at(i)
	recent.push_front({
		"path": game_path,
		"system": system,
		"name": display_name,
		"timestamp": Time.get_unix_time_from_system(),
	})
	while recent.size() > RECENT_MAX:
		recent.pop_back()
	write_json(root_path + "/Config/COMMON/recent.json", recent)

func get_list_file_contents():
	if root_path == null:
		return {}
	return read_json_dict(root_path + "/Config/COMMON/lists.json")

func get_positions_files():
	var last_screen = "user://last_screen.txt"
	var cursor_position_file = "user://cursor_positions.json"
	var scroll_offset_file = "user://scroll_offsets.json"
	if FileAccess.file_exists(last_screen):
		last_subscreen = FileAccess.get_file_as_string(last_screen)
	cursor_positions = read_json_dict(cursor_position_file)
	scroll_offsets = read_json_dict(scroll_offset_file)

func store_positions_files():
	var file = FileAccess.open("user://last_screen.txt", FileAccess.WRITE)
	file.store_string(Global.subscreen)
	print("Storing last subscreen as " + Global.subscreen)
	store_list_positions()

func store_list_positions():
	write_json("user://cursor_positions.json", cursor_positions, "   ")
	write_json("user://scroll_offsets.json", scroll_offsets, "   ")

func update_list_file_contents(key, new_list):
	var list_file_contents = get_list_file_contents()
	list_file_contents[key] = new_list
	write_json(root_path + "/Config/COMMON/lists.json", list_file_contents, "   ")

func display_size() -> Vector2i:
	if OS.get_name() != "Android":
		return DisplayServer.window_get_size()
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

func resize():
	window_width = display_size().x
	window_height = display_size().y
	if window_height / window_width >= 2.0:
		title_offset = text_height * 5
		window_height -= title_offset
	else:
		title_offset = 0
	BACKDROP.size = Vector2(window_width, window_height)
	for layer in [letter_scroller, touch_buttons]:
		if layer != null:
			layer.size = Vector2(window_width, window_height)
	set_up_slots()
	show_options(scroll_offset)
	highlight_selection(option_selection)
	if settings_panel != null:
		settings_panel.relayout()
	refresh_art()

func load_external_texture(path):
	var image = Image.new()
	image.load(path)

	var image_texture = ImageTexture.new()
	image_texture.set_image(image)

	return image_texture

const CAP_HEIGHT = 0.7
const PROMPT_BASELINE = 0.35
const PROMPT_SCALE_MAX = 0.5
const PROMPT_SCALE_MIN = 0.4
const PROMPT_SCALE_STEPS = 5
const LIST_SHRINK_MAX = 0.12
const LIST_SHRINK_STEPS = 6
const TOP_GAP = 0.12
const BOTTOM_GAP = 0.15
var prompt_scale = PROMPT_SCALE_MAX

static func hug_layout(top_edge: float, bottom_edge: float, step: float, ascent: float, cap: float, below: float, top_gap: float, bottom_gap: float) -> Array:
	var first_top = top_edge + top_gap - (ascent - cap)
	var rows = int(floor((bottom_edge - bottom_gap - (first_top + ascent + below)) / step)) + 1
	return [maxi(1, rows), first_top]

static func better_layout(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	if not is_equal_approx(a[1], b[1]):
		return a[1] > b[1]
	return a[2] > b[2]

func list_layout(text_height: float, scale: float) -> Array:
	var size = maxi(12, int(text_height * 0.5 * scale))
	var bar_height = size * 2.0 if prompt_bar_enabled() else 0.0
	var body_font: Font = font if font != null else $SlotHolder/Body.get_theme_font("font")
	var list_size = int(text_height / 2.0)
	var title_height = 0.0 if title_collapsed else size * 2.0
	var top_edge = 0.0
	if not title_collapsed:
		top_edge = Settings.get_setting(Settings.CFG_TOP_MARGIN) + title_height
	var bottom_edge = window_height
	if prompt_bar_enabled():
		bottom_edge = window_height - bar_height
	var pad = maxf(0.0, (inline_box().y - list_size * CAP_HEIGHT) / 2.0) if inline_covers() else 0.0
	var step = inline_row_step(text_height * 0.5, inline_box().y) if inline_covers() else text_height * 0.5
	var layout = hug_layout(top_edge, bottom_edge, step, body_font.get_ascent(list_size), list_size * CAP_HEIGHT, body_font.get_descent(list_size), text_height * TOP_GAP + pad, text_height * BOTTOM_GAP + pad)
	var peek = 0
	if pad > 0.0:
		peek = peek_rows_for(layout[1] + body_font.get_ascent(list_size) - list_size * CAP_HEIGHT / 2.0, layout[0], step, bottom_edge)
	return [layout[0], layout[1], peek]

func choose_text_sizes(base_height: float) -> Array:
	var best = []
	for shrink_index in range(LIST_SHRINK_STEPS + 1):
		var factor = 1.0 - LIST_SHRINK_MAX * shrink_index / float(LIST_SHRINK_STEPS)
		for scale_index in range(PROMPT_SCALE_STEPS + 1):
			var scale = PROMPT_SCALE_MAX - (PROMPT_SCALE_MAX - PROMPT_SCALE_MIN) * scale_index / float(PROMPT_SCALE_STEPS)
			var layout = list_layout(base_height * factor, scale)
			var candidate = [layout[0], factor, scale, layout[1], layout[2]]
			if best.is_empty() or better_layout(candidate, best):
				best = candidate
	return best

func set_up_slots():
	scaled_text_height = default_text_height * Settings.text_scaler()

	var outline_thickness = Settings.get_setting(Settings.CFG_VISUAL_LETTER_OUTLINES)
	left_bound = Settings.get_setting(Settings.CFG_LEFT_MARGIN)
	title = $SlotHolder/Title
	title.z_index = BAR_Z
	title.size.x = Global.window_width - left_bound * 2
	title.size.y = title_bar_height()
	title.horizontal_alignment = Settings.get_setting(Settings.CFG_VISUAL_TITLE_ORIENTATION)
	title.add_theme_constant_override("outline_size", outline_thickness)
	title.position.y = Settings.get_setting(Settings.CFG_TOP_MARGIN)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position.x = 0
	title.uppercase = true
	title_collapsed = title_can_be_blank and title.text == ""
	var sizes = choose_text_sizes(scaled_text_height)
	scaled_text_height *= sizes[1]
	prompt_scale = sizes[2]
	title.set("theme_override_font_sizes/font_size", prompt_text_size())
	title.size.y = title_bar_height()
	if title_collapsed:
		title.position.y = Settings.get_setting(Settings.CFG_TOP_MARGIN) - title.size.y

	#print("TITLE TEXT: " + title.text + "TITLE SIZE: " + str(title.size.y * title.scale.y) + " SLOT START: " + str(slot_start))

	if message != null:
		message.queue_free()
	message = $SlotHolder/Body.duplicate()
	if message_clip == null:
		message_clip = Control.new()
		message_clip.clip_contents = true
		message_clip.z_index = 4001
		add_child.call_deferred(message_clip)
	message_clip.add_child.call_deferred(message)
	message.position.y = Global.window_height - scaled_text_height / 4.0
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.size.x = list_text_width()
	message.position.x = Global.window_width - 2.0 - message.size.x
	message.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	message.set("theme_override_font_sizes/font_size", scaled_text_height / 2.0)
	$Pixel.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	$Pixel.scale = Vector2.ONE * 16 * Settings.text_scaler()
	$Pixel.visible = false

	for i in range(visible_slots.size()):
		var slot = visible_slots[i]
		slot.queue_free()
		#fav_indicators[i].queue_free()
	visible_slots.clear()
	fav_indicators.clear()

	var body_alignment = Settings.get_setting(Settings.CFG_VISUAL_BODY_ORIENTATION)
	var row_step = row_step()
	peek_rows = sizes[4] if sizes.size() > 4 else 0
	var layout = [sizes[0] + peek_rows, sizes[3]]
	for i in range(1, layout[0] + 1):
		var new_slot: Label = message.duplicate()
		slot_offset = left_bound + list_shift

		new_slot.horizontal_alignment = body_alignment
		slot_holder.add_child.call_deferred(new_slot)
		visible_slots.append(new_slot)
		new_slot.add_theme_constant_override("outline_size", outline_thickness)
		new_slot.position.y = layout[1] + (i - 1) * row_step
		#var fav_indicator = $Indicator.duplicate()
		#fav_indicator.visible = true
		#new_slot.add_child.call_deferred(fav_indicator)
		#fav_indicator.position.x = -scaled_text_height / 4.0
		#if new_slot.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		#	fav_indicator.position.x = new_slot.size.x + left_bound / 2.0
		slot_size = new_slot.size
		#fav_indicator.scale = Vector2.ONE * Settings.get_setting(Settings.CFG_SCALER)
		#fav_indicator.position.y = scaled_text_height / 4.0 - 2.0
		#fav_indicators.append(fav_indicator)

	message.set("theme_override_font_sizes/font_size", prompt_text_size())
	set_list_shift(list_shift)
	#message.visible = false
	var custom_font = Settings.supported_font(Settings.get_setting(Settings.CFG_FONT))
	if custom_font != Settings.get_setting(Settings.CFG_FONT):
		Settings.store(Settings.CFG_FONT, custom_font)
	if custom_font != null and ResourceLoader.exists(custom_font):
		font = ResourceLoader.load(custom_font)
	refresh_fonts()
	layout_message()
	layout_header()
	if prompt_bar != null:
		prompt_bar.queue_redraw()

func refresh_alias(system="COMMON"):
	var bundled_path = "res://launcher_configs/" + system + "/alias.json"
	var user_path = str(root_path) + "/" + Global.PATH_CONFIG + "/" + system + "/alias.json"
	if root_path == null or not (FileAccess.file_exists(bundled_path) or FileAccess.file_exists(user_path)):
		return
	var aliases = read_json_dict(bundled_path) if FileAccess.file_exists(bundled_path) else {}
	aliases.merge(read_json_dict(user_path), true)
	set_active_alias_map(aliases)

func set_active_alias_map(aliases):
	if not aliases:
		ALIAS_MAP = {}
	else:
		ALIAS_MAP = aliases

func refresh_fonts():
	if font == null:
		return
	title.add_theme_font_override("font", font)
	for slot in visible_slots:
		slot.add_theme_font_override("font", font)

func _nearest_index(value, options_list) -> int:
	var best = 0
	var best_dist = abs(float(options_list[0]) - float(value))
	for i in range(1, options_list.size()):
		var dist = abs(float(options_list[i]) - float(value))
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

func _scroll_horizontal(direction: int):
	if not get_selected().trigger(Actions.DIRECTION, [direction]):
		if direction > 0:
			for i in range(0, min(5, option_list.size() - option_selection)):
				if option_selection < option_list.size() - 1:
					move_down()
		else:
			for i in range(0, 5):
				if option_selection > 0:
					move_up()
		on_scroll()

func cycle_options(cfg_key, options_list, direction: int = 1):
	print("SETTING OPTION " + cfg_key + " with list " + str(options_list))
	var current = Settings.get_setting(cfg_key)
	var idx = options_list.find(current)
	if idx < 0:
		if current is float or current is int:
			idx = _nearest_index(current, options_list)
		else:
			Settings.store(cfg_key, options_list[0])
			return
	var next = (idx + direction) % options_list.size()
	if next < 0:
		next += options_list.size()
	Settings.store(cfg_key, options_list[next])

func get_cycle_index(cfg_key, options_list) -> int:
	var current = Settings.get_setting(cfg_key)
	var idx = options_list.find(current)
	if idx >= 0:
		return idx + 1
	if current is float or current is int:
		return _nearest_index(current, options_list) + 1
	return 1

func cycle_sizes(direction: int = 1):
	cycle_options(Settings.CFG_SCALER, Settings.LAYOUT_SIZES, direction)
	set_up_slots()
	show_options(scroll_offset)
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	highlight_selection(option_selection)
	refresh_art()

func cycle_cover_sizes(direction: int = 1):
	cycle_options(Settings.CFG_VISUAL_COVER_SIZE, Settings.COVER_SIZES, direction)
	set_up_slots()
	refresh_art()
	show_options(scroll_offset)
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	highlight_selection(option_selection)

func cycle_title_allignment(direction: int = 1):
	cycle_options(Settings.CFG_VISUAL_TITLE_ORIENTATION, Settings.TITLE_ORIENTATIONS, direction)
	set_up_slots()

func cycle_body_allignment(direction: int = 1):
	cycle_options(Settings.CFG_VISUAL_BODY_ORIENTATION, Settings.TITLE_ORIENTATIONS, direction)
	set_up_slots()
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))

func cycle_art_alignment(direction: int = 1):
	cycle_options(Settings.CFG_VISUAL_ART_ORIENTATION, [0.25, 0.5, 0.75], direction)
	refresh_art()

func cycle_system_title(direction: int = 1):
	cycle_options(Settings.CFG_SYSTEM_TITLE, ["SYSTEMS", "", "PLAIN LAUNCHER", "MAIN", "ALL"], direction)
	refresh_home_title()

func refresh_home_title():
	if Navigator.current_screen == "system_browser":
		update_title(Settings.get_setting(Settings.CFG_SYSTEM_TITLE))
	apply_visual_change()

func show_message(msg, priority=false):
	"""
	if msg == "" or msg == null:
		message_queue.clear()
		message.text = ""
		return
	if priority:
		show_message("")
	if message.text != "" and message.modulate.a > 0.05:
		message_queue.append(msg)
		return
	if message.text.to_lower() == msg.to_lower():
		return
	"""
	if msg == "" or msg == null:
		message_queue.clear()
		message.text = ""
		message.modulate.a = 0.0
		return
	print("showing message: " + msg)
	message.text = ALIAS_MAP.get(msg, msg)
	message.uppercase = Settings.get_setting(Settings.CFG_CAPS_LOCK)
	message.visible = true
	message.modulate.a = 1.0
	layout_message()

func update_title(new_title):
	if no_alias:
		title.text = new_title
	else:
		title.text = ALIAS_MAP.get(new_title.to_lower(), new_title)

func set_slot(index, value):
	if no_alias:
		visible_slots[index].text = value
	else:
		visible_slots[index].text = ALIAS_MAP.get(value.to_lower(), value)
	visible_slots[index].uppercase = Settings.get_setting(Settings.CFG_CAPS_LOCK)

const SYSTEM_CONFIG_FILES = ["choices.json", "alias.json", "unique_paths.json"]

func clear_system_game_settings(system_config_path: String):
	DirAccess.remove_absolute(system_config_path + "/config.json")
	var games_path = system_config_path + "/games"
	for file in DirAccess.get_files_at(games_path):
		DirAccess.remove_absolute(games_path + "/" + file)
	DirAccess.remove_absolute(games_path)
	for file in DirAccess.get_files_at(system_config_path):
		if file.ends_with(".json") and file not in SYSTEM_CONFIG_FILES:
			print("Removing legacy game settings " + file)
			DirAccess.remove_absolute(system_config_path + "/" + file)

func clear_all_settings():
	var config_dir = DirAccess.open(root_path + "/" + Global.PATH_CONFIG)
	config_dir.list_dir_begin()
	var system_name = config_dir.get_next()
	while system_name != "":
		print("Clearing settings for " + system_name + " directory..")
		var system_config_dir = DirAccess.open(config_dir.get_current_dir() + "/" + system_name)
		if not system_config_dir:
			system_name = config_dir.get_next()
			continue
		if system_name != "COMMON":
			clear_system_game_settings(system_config_dir.get_current_dir())
		system_name = config_dir.get_next()
	config_dir.list_dir_end()

func set_root_path(path):
	root_path = path
	Settings.store(Settings.CFG_ROOT, path)

func caps_lock():
	Settings.store(Settings.CFG_CAPS_LOCK, !Settings.get_setting(Settings.CFG_CAPS_LOCK))
	update_title(title.text)
	show_message(message.text)
	show_options(scroll_offset)

func set_all_text_color(new_color):
	title.modulate = new_color
	for slot in visible_slots:
		slot.modulate = new_color
	message.modulate = new_color

func set_for_all_text(key, value, title_included=true):
	for text in slot_holder.get_children():
		if !title_included and text == title:
			continue
		text.set(key, value)

func special_allowed():
	if panel_open() or launching:
		return false
	return Navigator.current_screen == "system_browser" or Navigator.current_screen == "game_browser" or Navigator.current_screen == "android_apps"

func clear_visible(title_text="", custom_options=[]):
	option_list.clear()
	scroll_offset = 0
	for i in range(visible_slots.size()):
		var visible_slot = visible_slots[i]
		visible_slot.text = ""
		#fav_indicators[i].visible = false
	update_title(title_text)

	if not custom_options.is_empty():
		confirming = true
		option_selection = 0
		for custom_option in custom_options:
			if custom_option is option:
				option_list.append(custom_option)
			else:
				option_list.append(option.new_option(custom_option))
		for i in range(0, min(visible_slots.size(), option_list.size())):
			set_slot(i, option_list[i].clean)
		restore_position()
		highlight_selection()

const ART_CACHE_SIZE = 20
const THUMB_DIR = "user://thumbs"
const ART_MISSING_TTL_MS = 60000

var _art_cache = {}
var _art_cache_order = []
var _art_failed = {}
var _art_missing = {}
var _art_loading_path = ""
var _art_loading_task = -1
var _art_wanted_path = ""
var _art_wanted_since = 0
var _queued_move = 0
const ART_WAIT_MAX_MS = 600

static func art_wait_over(wanted: String, known: bool, waited_ms: int) -> bool:
	return wanted == "" or known or waited_ms >= ART_WAIT_MAX_MS

func waiting_for_art() -> bool:
	return not art_wait_over(_art_wanted_path, _art_wanted_path == "" or art_known(_art_wanted_path), Time.get_ticks_msec() - _art_wanted_since)

func step_when_art_ready(direction: int) -> bool:
	if waiting_for_art():
		_queued_move = direction
		return false
	_queued_move = 0
	if direction > 0:
		move_down()
	else:
		move_up()
	on_scroll()
	return true

func refresh_art(image_path=Global.get_image_path()):
	if img_texture_override != null:
		_art_wanted_path = ""
		apply_cover_texture(img_texture_override)
		return
	if !art_exists(image_path):
		_art_wanted_path = ""
		apply_cover_texture(null)
		return
	if cover_size() == Vector2.ZERO and not inline_covers():
		_art_wanted_path = ""
		apply_cover_texture(null)
		return
	if inline_covers():
		apply_cover_texture(null)
		if inline_layer != null:
			inline_layer.queue_redraw()
	if image_path != _art_wanted_path:
		_art_wanted_since = Time.get_ticks_msec()
	_art_wanted_path = image_path
	var cached = cached_art(image_path)
	if cached != null:
		apply_cover_texture(cached)
	elif art_failed(image_path):
		apply_cover_texture(null)
	load_next_art()

func cached_art(path: String):
	var entry = _art_cache.get(path)
	if entry == null:
		return null
	if entry.mtime != FileAccess.get_modified_time(path):
		_art_cache.erase(path)
		_art_cache_order.erase(path)
		return null
	_art_cache_order.erase(path)
	_art_cache_order.append(path)
	return entry.texture

func cache_art(path: String, texture: Texture2D):
	_art_cache[path] = {"texture": texture, "mtime": FileAccess.get_modified_time(path)}
	_art_cache_order.erase(path)
	_art_cache_order.append(path)
	while _art_cache_order.size() > ART_CACHE_SIZE:
		_art_cache.erase(_art_cache_order.pop_front())

func clear_art_cache():
	_art_cache.clear()
	_art_cache_order.clear()
	_art_failed.clear()
	_art_missing.clear()

func art_exists(path: String) -> bool:
	var checked = _art_missing.get(path, -1)
	if checked >= 0 and Time.get_ticks_msec() - checked < ART_MISSING_TTL_MS:
		return false
	if FileAccess.file_exists(path):
		_art_missing.erase(path)
		return true
	_art_missing[path] = Time.get_ticks_msec()
	return false

func forget_missing_art(path: String):
	_art_missing.erase(path)

func art_failed(path: String) -> bool:
	return _art_failed.get(path, -1) == FileAccess.get_modified_time(path)

func art_known(path: String) -> bool:
	return _art_cache.has(path) or art_failed(path)

func next_art_to_load() -> String:
	if _art_wanted_path != "" and not art_known(_art_wanted_path):
		return _art_wanted_path
	if inline_covers():
		for i in range(visible_slots.size() + 2):
			var row = shown_offset + i - 1
			if row < 0 or row >= option_list.size():
				continue
			var row_path = get_image_path(option_list[row])
			if art_exists(row_path) and not art_known(row_path):
				return row_path
	var offsets = [1, -1, 2]
	for reach in range(2, nearby_reach + 1):
		offsets.append_array([reach, -reach])
	for offset in offsets:
		var i = option_selection + offset
		if i < 0 or i >= option_list.size():
			continue
		var path = get_image_path(option_list[i])
		if art_exists(path) and not art_known(path):
			return path
	return ""

func load_next_art():
	if _art_loading_path != "":
		return
	var path = next_art_to_load()
	if path == "":
		return
	var box = art_box_size()
	var thumb = thumbnail_path(path, box) if box.x > 0 and box.y > 0 else ""
	_art_loading_path = path
	if sync_loading:
		_load_art_image(path, thumb, box)
		return
	_art_loading_task = WorkerThreadPool.add_task(_load_art_image.bind(path, thumb, box))

func art_box_size() -> Vector2i:
	if inline_covers():
		return Vector2i(inline_box() * 2.0)
	var size = cover_size()
	var box = Vector2(window_width, window_height)
	if size.x > 1.0:
		box *= 2
	elif size.x < 1.0:
		box *= size
	return Vector2i(box)

func thumbnail_path(path: String, box: Vector2i) -> String:
	return THUMB_DIR + "/%s_%d_%dx%d.webp" % [path.md5_text(), FileAccess.get_modified_time(path), box.x, box.y]

static func load_cover_image(path: String, thumb: String, box: Vector2i) -> Image:
	if thumb != "" and FileAccess.file_exists(thumb):
		var thumb_image = Image.load_from_file(thumb)
		if thumb_image != null:
			return thumb_image
	var image = Image.load_from_file(path)
	if image == null or thumb == "":
		return image
	var fit = min(box.x / float(image.get_width()), box.y / float(image.get_height()))
	if fit < 1.0:
		image.resize(maxi(1, int(image.get_width() * fit)), maxi(1, int(image.get_height() * fit)), Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(thumb.get_base_dir())
		image.save_webp(thumb, true, 0.9)
	return image

func _load_art_image(path: String, thumb: String, box: Vector2i):
	var image = load_cover_image(path, thumb, box)
	if image != null:
		image.convert(Image.FORMAT_RGBA8)
	_on_art_loaded.call_deferred(path, image)

func _on_art_loaded(path: String, image):
	if path == _art_loading_path:
		if _art_loading_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_art_loading_task)
		_art_loading_path = ""
		_art_loading_task = -1
	if image == null:
		_art_failed[path] = FileAccess.get_modified_time(path)
		if inline_covers():
			for i in range(visible_slots.size()):
				place_slot(i)
		if path == _art_wanted_path:
			apply_cover_texture(null)
	else:
		var texture = ImageTexture.create_from_image(image)
		cache_art(path, texture)
		if inline_layer != null:
			inline_layer.queue_redraw()
		if path == _art_wanted_path:
			apply_cover_texture(texture)
		else:
			update_nearby_covers()
	load_next_art()

func cover_size() -> Vector2:
	var size = Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE)
	if force_cover and (size == Vector2.ZERO or size.x >= 1.0):
		return Settings.COVER_SIZES[2]
	if inline_covers():
		return Vector2.ZERO
	return size

const INLINE_SIZE_SHARE = 0.3
const INLINE_COVER_ASPECT = 0.75
const INLINE_ROW_GAP = 0.12

func cover_style() -> String:
	return "single" if force_cover else str(Settings.get_setting(Settings.CFG_COVER_STYLE))

func inline_covers() -> bool:
	return cover_style() == "inline" and art_enabled_here()

static func inline_row_step(text_step: float, box_height: float) -> float:
	return maxf(text_step, box_height * (1.0 + INLINE_ROW_GAP))

func row_step() -> float:
	var step = scaled_text_height * 0.5
	return inline_row_step(step, inline_box().y) if inline_covers() else step

static func inline_box_for(screen_height: float, cover: Vector2) -> Vector2:
	var height = screen_height * cover.y * INLINE_SIZE_SHARE
	return Vector2(height * INLINE_COVER_ASPECT, height)

func inline_box() -> Vector2:
	return inline_box_for(window_height, Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE))

func inline_reserve() -> float:
	return inline_box().x + left_bound + scaled_text_height * 0.3

static func inline_slot_frame(left: float, width: float, reserve: float, cover_left: bool, has_art: bool) -> Vector2:
	if cover_left:
		return Vector2(left + reserve, width - reserve)
	return Vector2(left, width - reserve if has_art else width)

func inline_row_has_art(i: int) -> bool:
	var row = shown_offset + i
	if row < 0 or row >= option_list.size():
		return false
	var path = get_image_path(option_list[row])
	return path != "" and art_exists(path) and not art_failed(path)

func inline_box_rect(i: int) -> Rect2:
	var box_size = inline_box()
	var slot: Label = visible_slots[i]
	var middle = slot.global_position.y + slot_text_middle(slot)
	var left = left_bound if cover_on_left() else window_width - left_bound - box_size.x
	return Rect2(Vector2(left, middle - box_size.y / 2.0), box_size)

func lift_inline_cover() -> bool:
	if not inline_covers() or option_list.is_empty():
		return false
	var i = option_selection - shown_offset
	if i < 0 or i >= visible_slots.size():
		return false
	var path = get_image_path(get_selected())
	var texture = cached_art(path) if path != "" else null
	if texture == null:
		return false
	var box = Vector2(window_width, window_height) * Settings.COVER_SIZES[2]
	var ratio = minf(box.x / texture.get_size().x, box.y / texture.get_size().y)
	var thumb = InlineCovers.fit_rect(texture.get_size(), inline_box_rect(i))
	cover_art.texture = texture
	cover_art.scale = Vector2(ratio, ratio)
	border.visible = false
	drop_shadow.visible = false
	if cover_halo != null:
		cover_halo.visible = false
	cover.modulate.a = 1.0
	cover.position = thumb.get_center()
	cover.scale = Vector2.ONE * (thumb.size.y / (texture.get_size().y * ratio))
	cover.visible = true
	inline_layer.hidden_row = option_selection
	inline_layer.queue_redraw()
	return true

func drop_inline_cover():
	cover.scale = Vector2.ONE
	cover_art.texture = null
	cover.visible = false
	inline_layer.hidden_row = -1
	inline_layer.queue_redraw()

func place_slot(i: int, animate: bool = false):
	if i < 0 or i >= visible_slots.size():
		return
	var slot: Label = visible_slots[i]
	var x = slot_offset
	var width = slot_size.x
	if inline_covers():
		var frame = inline_slot_frame(left_bound, list_text_width(), inline_reserve(), cover_on_left(), inline_row_has_art(i))
		x = frame.x
		width = frame.y
	elif text_to_cover():
		width = minf(width, text_limit_x() - x)
	slot.size.x = width / slot.scale.x
	if animate and effects_on() and not is_equal_approx(slot.position.x, x):
		create_tween().tween_property(slot, "position:x", x, LIST_SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		slot.position.x = x

const COVER_ANCHOR = Vector2(0.75, 0.5)
const LEFT_COVER_ANCHOR = Vector2(0.25, 0.5)
const PORTRAIT_COVER_ANCHOR = Vector2(0.5, 0.22)
const LIST_SLIDE_SECONDS = 0.18
var list_shift = 0.0
var _list_tween: Tween = null

static func art_enabled_for(screen: String, cover: Vector2, system_art: bool) -> bool:
	return cover != Vector2.ZERO and (screen != "system_browser" or system_art)

func art_enabled_here() -> bool:
	return art_enabled_for(Navigator.current_screen, Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE), Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_ART))

func text_to_cover() -> bool:
	var size = cover_size()
	return cover_area_color() != null and not cover_on_left() and not inline_covers() and size != Vector2.ZERO and size.x < 1.0 and art_enabled_here()

static func cover_text_limit(screen_width: float, anchor_x: float, cover_share: float, gap: float) -> float:
	return screen_width * anchor_x - screen_width * cover_share / 2.0 - gap

func text_limit_x() -> float:
	return cover_text_limit(window_width, right_cover_anchor_x(window_width, left_bound, window_width * cover_size().x), cover_size().x, scaled_text_height * 0.3)

func cover_on_left() -> bool:
	return Settings.get_setting(Settings.CFG_COVER_SIDE) == "left" and not force_cover

func cover_anchor() -> Vector2:
	if force_cover and window_height > window_width:
		return PORTRAIT_COVER_ANCHOR
	var anchor = Vector2(right_cover_anchor_x(window_width, left_bound, window_width * cover_size().x), COVER_ANCHOR.y) if not cover_on_left() else Vector2(left_cover_anchor_x(window_width, left_bound, window_width * cover_size().x), LEFT_COVER_ANCHOR.y)
	if not force_cover and not inline_covers() and window_width > 0:
		var span = cover_area_span(window_width, left_bound, window_width * cover_size().x, scaled_text_height * 0.3, cover_on_left(), false)
		anchor.x = (span.x + span.y) / 2.0 / window_width
	return anchor

static func right_cover_anchor_x(width: float, right: float, box: float) -> float:
	if width <= 0.0:
		return COVER_ANCHOR.x
	return (width - right - box / 2.0) / width

static func left_cover_anchor_x(width: float, left: float, box: float) -> float:
	return (left + box / 2.0) / maxf(1.0, width)

static func left_cover_shift(cover_width: float, gap: float) -> float:
	return maxf(0.0, cover_width + gap)

func slide_list_for_cover():
	var target = 0.0
	if inline_covers():
		target = 0.0
	elif cover_on_left() and art_enabled_here():
		target = left_cover_shift(window_width * cover_size().x, scaled_text_height * 0.3)
	if is_equal_approx(target, list_shift) and (_list_tween == null or not _list_tween.is_running()):
		return
	if _list_tween != null:
		_list_tween.kill()
	_list_tween = create_tween()
	_list_tween.tween_method(set_list_shift, list_shift, target, LIST_SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_list_shift(value: float):
	list_shift = value
	slot_offset = left_bound + list_shift
	slot_size.x = list_text_width() - list_shift
	for i in range(visible_slots.size()):
		place_slot(i)
	if row_stripes != null:
		row_stripes.queue_redraw()

const NEARBY_SCALE = 0.5
const NEARBY_ALPHA = 0.55
const NEARBY_FADE_STEP = 0.12
const NEARBY_MIN_ALPHA = 0.2
var nearby_art: Array = []
var nearby_reach = 0

static func nearby_crop(center_y: float, height: float, top_limit: float, bottom_limit: float) -> Vector2:
	var top = center_y - height / 2.0
	var bottom = center_y + height / 2.0
	return Vector2(clampf(top_limit - top, 0.0, height), clampf(bottom - bottom_limit, 0.0, height))

static func nearby_offset(main_height: float, small_height: float, gap: float) -> float:
	return main_height / 2.0 + gap + small_height / 2.0

func nearby_slots(direction: int, top_limit: float, bottom_limit: float, gap: float, nominal: float) -> Array:
	var slots = []
	var main_half = main_cover_height() / 2.0
	var center = cover.position.y + cover_art.position.y
	var edge = center + direction * (main_half + gap)
	var step = 1
	while (direction < 0 and edge > top_limit) or (direction > 0 and edge < bottom_limit):
		var index = option_selection + direction * step
		if index < 0 or index >= option_list.size():
			break
		var path = get_image_path(option_list[index])
		slots.append({"step": step, "path": path, "edge": edge})
		var texture = cached_art(path) if path != "" else null
		var height = nominal
		if texture != null:
			height = texture.get_size().y * minf(nearby_box().x / texture.get_size().x, nearby_box().y / texture.get_size().y)
		edge += direction * (height + gap)
		step += 1
	return slots

func nearby_box() -> Vector2:
	return Vector2(window_width, window_height) * cover_size() * NEARBY_SCALE

const WHEEL_ANGLE = 0.5
const WHEEL_REACH = 3
const WHEEL_SECONDS = 0.16
var wheel_phase = 0.0
var _wheel_selection = -1
var _wheel_tween: Tween = null

static func wheel_place(u: float, main_height: float, gap: float, side: float) -> Dictionary:
	var a = absf(u)
	var radius = (main_height * (0.5 + NEARBY_SCALE * 0.5) + gap) / sin(WHEEL_ANGLE)
	var angle = clampf(u * WHEEL_ANGLE, -PI / 2.0, PI / 2.0)
	var scale = lerpf(1.0, NEARBY_SCALE, minf(a, 1.0)) * pow(0.85, maxf(0.0, a - 1.0))
	var alpha = maxf(NEARBY_MIN_ALPHA, lerpf(1.0, NEARBY_ALPHA, minf(a, 1.0)) - NEARBY_FADE_STEP * maxf(0.0, a - 1.0))
	return {"offset": Vector2(side * radius * (1.0 - cos(angle)), radius * sin(angle)), "scale": scale, "alpha": alpha}

func set_wheel_phase(value: float):
	wheel_phase = value
	update_wheel()

func update_wheel():
	if launching:
		return
	if _wheel_selection != option_selection:
		var delta = option_selection - _wheel_selection
		if _wheel_selection >= 0 and absi(delta) == 1 and effects_on():
			if _wheel_tween != null:
				_wheel_tween.kill()
			wheel_phase = delta
			_wheel_selection = option_selection
			_wheel_tween = create_tween()
			_wheel_tween.tween_method(set_wheel_phase, float(delta), 0.0, WHEEL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			return
		_wheel_selection = option_selection
		wheel_phase = 0.0
	nearby_reach = WHEEL_REACH
	var home = cover_home()
	var main_height = main_cover_height()
	var gap = scaled_text_height * 0.2
	var side = -1.0 if cover_on_left() else 1.0
	var limits = Vector2(title.position.y + title.size.y if not title_collapsed else 0.0, window_height - prompt_bar_height())
	var main = wheel_place(wheel_phase, main_height, gap, side)
	cover.position = home + main.offset
	cover.scale = Vector2.ONE * main.scale
	cover_art.modulate.a = main.alpha
	var box = Vector2(window_width, window_height) * cover_size()
	var shown = 0
	for direction in [-1, 1]:
		for k in range(1, WHEEL_REACH + 1):
			var index = option_selection + direction * k
			if index < 0 or index >= option_list.size():
				break
			var path = get_image_path(option_list[index])
			var texture = cached_art(path) if path != "" else null
			if texture == null:
				continue
			var place = wheel_place(direction * k + wheel_phase, main_height, gap, side)
			var ratio = minf(box.x / texture.get_size().x, box.y / texture.get_size().y) * place.scale
			var center = home + place.offset
			var height = texture.get_size().y * ratio
			if center.y + height / 2.0 < limits.x or center.y - height / 2.0 > limits.y:
				continue
			var crop = nearby_crop(center.y, height, limits.x, limits.y) / ratio
			var sprite = _nearby_sprite(shown)
			shown += 1
			sprite.texture = texture
			sprite.scale = Vector2.ONE * ratio / main.scale
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, crop.x, texture.get_size().x, texture.get_size().y - crop.x - crop.y)
			sprite.position = (center - cover.position) / main.scale + Vector2(0, (crop.x - crop.y) * ratio / 2.0 / main.scale)
			sprite.modulate = Color(1, 1, 1, place.alpha)
			sprite.visible = sprite.region_rect.size.y > 0
	for k in range(shown, nearby_art.size()):
		nearby_art[k].visible = false
	load_next_art()

var stack_phase = 0.0
var _stack_selection = -1
var _stack_tween: Tween = null

func set_stack_phase(value: float):
	stack_phase = value
	update_nearby_covers()

static func stack_pitch(main_height: float, gap: float) -> float:
	return main_height * (0.5 + NEARBY_SCALE * 0.5) + gap

func follow_stack_selection() -> bool:
	if _stack_selection == option_selection:
		return false
	var delta = option_selection - _stack_selection
	var animate = _stack_selection >= 0 and absi(delta) == 1 and effects_on()
	_stack_selection = option_selection
	if _stack_tween != null:
		_stack_tween.kill()
	stack_phase = 0.0
	if animate:
		_stack_tween = create_tween()
		_stack_tween.tween_method(set_stack_phase, float(delta), 0.0, WHEEL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return animate

func update_nearby_covers():
	if cover == null or cover_art == null or launching:
		return
	nearby_reach = 0
	var enabled = cover_style() in ["stacked", "wheel"] and cover.visible
	if enabled and cover_style() == "wheel":
		update_wheel()
		return
	if enabled and follow_stack_selection():
		return
	var shown = 0
	if enabled:
		cover.position.y = cover_home().y + stack_phase * stack_pitch(main_cover_height(), scaled_text_height * 0.2)
		var limits = Vector2(title.position.y + title.size.y if not title_collapsed else 0.0, window_height - prompt_bar_height())
		var gap = scaled_text_height * 0.2
		for direction in [-1, 1]:
			for slot in nearby_slots(direction, limits.x, limits.y, gap, nearby_box().y):
				nearby_reach = maxi(nearby_reach, slot.step)
				var texture = cached_art(slot.path) if slot.path != "" else null
				if texture == null:
					continue
				var sprite = _nearby_sprite(shown)
				shown += 1
				var ratio = minf(nearby_box().x / texture.get_size().x, nearby_box().y / texture.get_size().y)
				var height = texture.get_size().y * ratio
				var center_y = slot.edge + direction * height / 2.0
				var crop = nearby_crop(center_y, height, limits.x, limits.y) / ratio
				sprite.texture = texture
				sprite.scale = Vector2(ratio, ratio)
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0, crop.x, texture.get_size().x, texture.get_size().y - crop.x - crop.y)
				sprite.position = Vector2(cover_art.position.x, center_y - cover.position.y + (crop.x - crop.y) * ratio / 2.0)
				sprite.modulate = Color(1, 1, 1, maxf(NEARBY_MIN_ALPHA, NEARBY_ALPHA - NEARBY_FADE_STEP * (slot.step - 1)))
				sprite.visible = sprite.region_rect.size.y > 0
	for k in range(shown, nearby_art.size()):
		nearby_art[k].visible = false
	if enabled:
		load_next_art()

func hide_nearby_art():
	for sprite in nearby_art:
		sprite.visible = false

func _nearby_sprite(k: int) -> Sprite2D:
	while nearby_art.size() <= k:
		var sprite = Sprite2D.new()
		cover.add_child(sprite)
		cover.move_child(sprite, maxi(0, border.get_index()))
		nearby_art.append(sprite)
	return nearby_art[k]

func fit_text_to_cover():
	slide_list_for_cover()
	layout_cover_area()
	update_nearby_covers()
	if cover_halo == null:
		cover_halo = CoverHalo.new()
		cover.add_child(cover_halo)
		cover.move_child(cover_halo, 0)
	var framed = cover.visible and cover_art.texture != null and not force_cover and not cover_on_left()
	cover_halo.visible = framed and Navigator.current_screen != "system_browser"
	if not framed:
		return
	var border_size = Settings.get_setting(Settings.CFG_VISUAL_BORDER) if border.visible else Vector2.ZERO
	cover_halo.half_size = (cover_art.texture.get_size() * cover_art.scale + border_size) / 2.0
	cover_halo.feather = scaled_text_height * COVER_FADE
	cover_halo.color = cover_area_color() if cover_area_color() != null else Settings.get_setting(Settings.CFG_BG_COLOR)
	cover_halo.queue_redraw()

const BAR_Z = 4001

func cover_z() -> int:
	var wide_panel = settings_panel != null and settings_panel.panel_ratio() > SlidePanel.WIDTH_RATIO + 0.001
	return 4003 if force_cover and not wide_panel else 4000

static func letter_shifted_x(home_x: float, slide: float, shift: float) -> float:
	return home_x - slide * shift

func cover_home() -> Vector2:
	var home = Vector2(window_width, window_height) * cover_anchor()
	if letter_scroller != null and not cover_on_left() and letter_scroller.slide > 0.0:
		home.x = letter_shifted_x(home.x, letter_scroller.slide, letter_scroller.cover_shift())
	return home

func main_cover_height() -> float:
	if cover_art.texture != null:
		return cover_art.texture.get_size().y * cover_art.scale.y
	return window_height * cover_size().y

static func keeps_empty_slot(style: String, size: Vector2, forced: bool, enabled_here: bool) -> bool:
	return style in ["stacked", "wheel"] and size != Vector2.ZERO and not forced and enabled_here

func apply_cover_texture(texture):
	if texture == null or cover_size() == Vector2.ZERO:
		cover_art.texture = null
		cover.visible = keeps_empty_slot(cover_style(), cover_size(), force_cover, art_enabled_here()) and not inline_covers()
		if cover.visible:
			border.visible = false
			drop_shadow.visible = false
			cover.position = cover_home()
			if cover_style() != "wheel" and not launching:
				cover.scale = Vector2.ONE
		fit_text_to_cover()
		return
	cover.modulate.a = Settings.get_setting(Settings.CFG_VISUAL_COVER_OPACITY)
	var size = cover_size()
	if cover_style() != "wheel" and not launching:
		cover.scale = Vector2.ONE
		cover_art.modulate.a = 1.0
	if effects_on() and texture != _last_cover_texture and not launching and cover_style() != "wheel":
		pop_cover()
	_last_cover_texture = texture
	cover_art.texture = texture
	var scale_ratio_x = ((Global.window_width) * size.x) / (cover_art.texture.get_size().x + Settings.get_setting(Settings.CFG_VISUAL_BORDER).x)
	var scale_ratio_y = (Global.window_height * size.y) / (cover_art.texture.get_size().y + Settings.get_setting(Settings.CFG_VISUAL_BORDER).y)
	if size.x == 1.0:
		scale_ratio_x = Global.window_width / cover_art.texture.get_size().x
		scale_ratio_y = Global.window_height / cover_art.texture.get_size().y
	if size.x > 1.0:
		scale_ratio_x = 2 * Global.window_width / cover_art.texture.get_size().x
		scale_ratio_y = 2 * Global.window_height / cover_art.texture.get_size().y
	var scale_ratio = min(scale_ratio_x, scale_ratio_y)

	cover_art.scale = Vector2(scale_ratio, scale_ratio)
	cover.position = cover_home()
	cover.z_index = cover_z()

	if Settings.get_setting(Settings.CFG_VISUAL_BORDER) != Vector2.ZERO:
		border.visible = true
		border.scale = cover_art.texture.get_size() * cover_art.scale + Settings.get_setting(Settings.CFG_VISUAL_BORDER)
		border.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	else:
		border.visible = false
	if !Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER) and (Navigator.current_screen == "system_browser" or (force_cover and special_item != null and special_item.is_dir)):
		border.visible = false

	if Settings.get_setting(Settings.CFG_VISUAL_DROP_SHOW) != Vector2.ZERO:
		drop_shadow.visible = true
		drop_shadow.modulate.v = 0
		drop_shadow.position = cover_art.position + Settings.get_setting(Settings.CFG_VISUAL_DROP_SHOW)
		if border.visible:
			drop_shadow.texture = border.texture
			drop_shadow.scale = border.scale
		else:
			drop_shadow.texture = cover_art.texture
			drop_shadow.scale = cover_art.scale
			drop_shadow.position = cover_art.position + Settings.get_setting(Settings.CFG_VISUAL_DROP_SHOW)
	else:
		drop_shadow.visible = false

	cover.visible = true
	fit_text_to_cover()

func highlight_selection(next_selection=option_selection):
	slot_holder.position.x = 0
	for i in range(0, visible_slots.size()):
		var slot = visible_slots[i]
		slot.modulate.a = 0.3
		var list_idx = scroll_offset + i
		"""
		var slot_is_fav = list_idx < option_list.size() and favorites_list.has(option_list[list_idx].absolute_path)
		if slot_is_fav:
			slot.text = "•" + slot.text
		"""
		slot.size = slot_size
		place_slot(i)
		if scroll_offset + i < option_list.size() and HIDDEN_LIST.get(option_list[scroll_offset + i].absolute_path, false):
			slot.modulate.a = 0.1
		slot.scale = Vector2(1.0, 1.0)
	option_selection = next_selection
	if option_list.size() < focus_rows():
		scroll_offset = 0
	elif option_list.is_empty():
		scroll_offset = 0
		return
	elif visible_slots.is_empty():
		scroll_offset = 0
		return
	elif option_selection - scroll_offset >= focus_rows():
		print("OPTION SELECTION: " + str(option_selection) + " SCROLL OFFSET " + str(scroll_offset) + " VISIBLE_SLOT SIZE " + str(visible_slots.size()))
		scroll_offset = option_selection - focus_rows() + 1
		print("NEW SCROLL OFFSET " + str(scroll_offset))
		show_options(scroll_offset)
		highlight_selection()
		return
	if option_selection - scroll_offset < visible_slots.size():
		var selected_slot = visible_slots[option_selection-scroll_offset]
		selected_slot.modulate.a = 1.0
		if _highlight_tween != null:
			_highlight_tween.kill()
		if effects_on() and option_selection != _last_highlighted:
			selected_slot.modulate.a = HIGHLIGHT_FADE_FROM
			_highlight_tween = create_tween()
			_highlight_tween.tween_property(selected_slot, "modulate:a", 1.0, HIGHLIGHT_FADE_SECONDS).set_ease(Tween.EASE_OUT)
		_last_highlighted = option_selection
		if inline_layer != null:
			inline_layer.queue_redraw()
		#fav_indicators[option_selection-scroll_offset].modulate.a = 1.0
	else:
		show_options(option_selection - focus_rows())
	if post_draw_callback != null:
		post_draw_callback.call()

const HIGHLIGHT_FADE_FROM = 0.45
const HIGHLIGHT_FADE_SECONDS = 0.12
const COVER_POP_FROM = 0.93
const COVER_POP_SECONDS = 0.22
const LAUNCH_DIM = 0.88
const LAUNCH_SECONDS = 0.3
const LAUNCH_HOLD_SECONDS = 1.0
const LAUNCH_VIEW_MIN_SECONDS = 0.5
const LAUNCH_COVER_SHARE = 0.55
const LAUNCH_COVER_MAX_SCALE = 1.8
const LAUNCH_MARGIN = 0.5
const SETTLE_SECONDS = 0.35
const OPEN_SECONDS = 0.3
const OPEN_HOLD_SECONDS = 0.12
const FLASH_BRIGHTNESS = 1.8
const FLASH_OUT_SECONDS = 0.14
const COVER_PRESS_SCALE = 0.93
const COVER_PRESS_SECONDS = 0.06
const PRESS_SCALE = 0.93
const PRESS_SECONDS = 0.06
const RELEASE_SECONDS = 0.2
var _highlight_tween: Tween = null
var _last_highlighted = -1
var _cover_pop: Tween = null
var _last_cover_texture = null
var _launch_flash: ColorRect = null
var launching = false

func effects_on() -> bool:
	return Settings.get_setting(Settings.CFG_EFFECTS)

func pop_cover():
	if _cover_pop != null:
		_cover_pop.kill()
	cover.scale = Vector2.ONE * COVER_POP_FROM
	_cover_pop = create_tween()
	_cover_pop.tween_property(cover, "scale", Vector2.ONE, COVER_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func launcher_label(emulator: String, core) -> String:
	if emulator.to_lower().begins_with("retroarch") and core != null and str(core) not in ["", "NULL"]:
		return "%s (%s)" % [emulator, core]
	return emulator

static func launch_lines(game_name: String, launcher_name: String) -> Array:
	return [["Launching", false], [game_name, true], ["with launcher config", false], [launcher_name, true]]

static func launch_cover_scale(cover_height: float, window_height: float) -> float:
	if cover_height <= 0.0:
		return 1.0
	return clampf(window_height * LAUNCH_COVER_SHARE / cover_height, 1.0, LAUNCH_COVER_MAX_SCALE)

func _launch_text(lines: Array) -> Control:
	var holder = Control.new()
	holder.z_index = 4006
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg: Color = Settings.get_setting(Settings.CFG_FG_COLOR)
	var y = 0.0
	for line in lines:
		var label = Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var size = int(scaled_text_height * (0.5 if line[1] else 0.3))
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_font_override("font", font if font != null else title.get_theme_font("font"))
		label.modulate = Color(fg, 1.0 if line[1] else 0.6)
		label.position = Vector2(-window_width * 0.45, y)
		label.size = Vector2(window_width * 0.9, size * 1.4)
		holder.add_child(label)
		y += size * 1.4
	holder.set_meta("height", y)
	return holder

static func launch_parts(view: String, has_cover: bool) -> Dictionary:
	return {"cover": has_cover and view in ["cover_info", "cover"], "info": view in ["cover_info", "info"]}

const SOUNDS = {"accept": "res://sounds/accept.mp3", "back": "res://sounds/back.mp3", "move": "res://sounds/move.mp3"}
const SOUND_PITCH_VARIATION = {"accept": 1.05, "back": 1.05, "move": 1.12}
var _sound_players = {}
var _sound_frames = {}
var _press_tween: Tween = null

const SOUND_BASE_DB = -10.0

static func sound_db(master: int, volume: int) -> float:
	var linear = clampf(master / 100.0, 0.0, 1.0) * clampf(volume / 100.0, 0.0, 1.0)
	return SOUND_BASE_DB + linear_to_db(linear) if linear > 0.0 else -80.0

func play_sound(sound: String):
	var db = sound_db(int(Settings.get_setting(Settings.CFG_VOLUME_MASTER)), int(Settings.get_setting(Settings.SOUND_VOLUME_KEYS[sound])))
	if db <= -80.0 or _sound_frames.get(sound, -1) == Engine.get_process_frames():
		return
	_sound_frames[sound] = Engine.get_process_frames()
	if not _sound_players.has(sound):
		var randomizer = AudioStreamRandomizer.new()
		randomizer.random_pitch = SOUND_PITCH_VARIATION.get(sound, 1.05)
		randomizer.add_stream(0, load(SOUNDS[sound]))
		var player = AudioStreamPlayer.new()
		player.stream = randomizer
		add_child(player)
		_sound_players[sound] = player
	_sound_players[sound].volume_db = db
	_sound_players[sound].play()

func play_click():
	play_sound("accept")

func back_just_pressed() -> bool:
	return Input.is_action_just_pressed("key_back") or Input.is_action_just_pressed("select" if confirm_swapped else "back")

func confirm_just_released() -> bool:
	return Input.is_action_just_released("key_confirm") or Input.is_action_just_released("back" if confirm_swapped else "select")

static func text_start(text_width: float, slot_width: float, alignment: HorizontalAlignment) -> float:
	var width = minf(text_width, slot_width)
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return (slot_width - width) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			return slot_width - width
	return 0.0

func press_pivot(slot: Label):
	var text_width = slot.get_theme_font("font").get_string_size(slot.text, HORIZONTAL_ALIGNMENT_LEFT, -1, slot.get_theme_font_size("font_size")).x
	slot.pivot_offset = Vector2(text_start(text_width, slot.size.x, slot.horizontal_alignment), slot.size.y / 2.0)

func press_feedback(pressed: bool):
	if visible_slots.is_empty() or option_selection - scroll_offset >= visible_slots.size() or option_selection < scroll_offset:
		return
	var slot = visible_slots[option_selection - scroll_offset]
	press_pivot(slot)
	if _press_tween != null:
		_press_tween.kill()
	_press_tween = create_tween()
	if pressed:
		_press_tween.tween_property(slot, "scale", Vector2.ONE * PRESS_SCALE, PRESS_SECONDS).set_ease(Tween.EASE_OUT)
	else:
		_press_tween.tween_property(slot, "scale", Vector2.ONE, RELEASE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_power_screen(text: String):
	launching = true
	if prompt_bar != null:
		prompt_bar.visible = false
	if touch_buttons != null:
		touch_buttons.hide_now()
	if cover != null:
		cover.visible = false
	var screen = _overlay(4100)
	screen.size = Vector2(window_width, window_height + title_offset)
	screen.color = Color(Settings.get_setting(Settings.CFG_BG_COLOR), 0.0)
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = screen.size
	label.add_theme_font_size_override("font_size", int(scaled_text_height * 0.5))
	label.add_theme_font_override("font", font if font != null else title.get_theme_font("font"))
	label.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	screen.add_child(label)
	create_tween().tween_property(screen, "color:a", 1.0, 0.2)

func _overlay(z: int) -> ColorRect:
	var rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = z
	add_child(rect)
	return rect

var shown_offset = 0

func selected_slot() -> Label:
	var i = option_selection - shown_offset
	return visible_slots[i] if i >= 0 and i < visible_slots.size() else null

static func slot_text_middle(slot: Label) -> float:
	if slot.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		return slot.size.y / 2.0
	return slot.get_theme_font("font").get_height(slot.get_theme_font_size("font_size")) / 2.0

static func centered_left(text_width: float, width: float) -> float:
	return (width - text_width) / 2.0

func _text_flyer(slot: Label) -> Label:
	var slot_font = slot.get_theme_font("font")
	var font_size = slot.get_theme_font_size("font_size")
	var measure = func(t: String) -> float:
		return slot_font.get_string_size(t.to_upper() if slot.uppercase else t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var shown = slot.text.strip_edges()
	var full_width = measure.call(slot.text)
	var width = minf(measure.call(shown), window_width * 0.9)
	var flyer = Label.new()
	flyer.text = shown
	flyer.uppercase = slot.uppercase
	flyer.autowrap_mode = TextServer.AUTOWRAP_OFF
	flyer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	flyer.clip_text = true
	flyer.vertical_alignment = slot.vertical_alignment
	flyer.add_theme_font_override("font", slot_font)
	flyer.add_theme_font_size_override("font_size", font_size)
	flyer.add_theme_constant_override("outline_size", slot.get_theme_constant("outline_size"))
	flyer.add_theme_color_override("font_outline_color", slot.get_theme_color("font_outline_color"))
	flyer.modulate = Color(Settings.get_setting(Settings.CFG_FG_COLOR), 1.0)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.z_index = 4006
	flyer.size = Vector2(width, slot.size.y)
	var start = text_start(full_width, slot.size.x, slot.horizontal_alignment) + maxf(0.0, full_width - measure.call(shown))
	flyer.position = slot.global_position - global_position + Vector2(start, 0.0)
	flyer.set_meta("middle", slot_text_middle(slot))
	flyer.set_meta("height", slot_font.get_height(font_size))
	add_child(flyer)
	return flyer

func open_with_effect(go: Callable):
	if launching:
		return
	var slot = selected_slot()
	if not effects_on() or slot == null or slot.text.strip_edges() == "":
		go.call()
		return
	launching = true
	hide_nearby_art()
	vibrate(40)
	play_click()
	if _cover_pop != null:
		_cover_pop.kill()
	if _launch_flash == null:
		_launch_flash = _overlay(3999)
	_launch_flash.size = Vector2(window_width, window_height + title_offset)
	_launch_flash.color = Color(Settings.get_setting(Settings.CFG_BG_COLOR), 0.0)
	var flyer = _text_flyer(slot)
	slot.self_modulate.a = 0.0
	var lifted = lift_inline_cover()
	var has_art = cover.visible and cover_art.texture != null
	var art_height = cover_art.texture.get_size().y * cover_art.scale.y * (1.0 if lifted else cover.scale.y) if has_art else 0.0
	var gap = scaled_text_height * 0.2 if has_art else 0.0
	var text_height: float = flyer.get_meta("height")
	var top = (window_height - art_height - gap - text_height) / 2.0
	var home_position = cover.position
	var home_z = cover.z_index
	var tween = create_tween().set_parallel()
	tween.tween_property(_launch_flash, "color:a", 1.0, OPEN_SECONDS)
	tween.tween_property(flyer, "position", Vector2(centered_left(flyer.size.x, window_width), top + art_height + gap + text_height / 2.0 - flyer.get_meta("middle")), OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if prompt_bar != null:
		tween.tween_property(prompt_bar, "modulate:a", 0.0, OPEN_SECONDS)
	if has_art:
		cover.z_index = 4004
		tween.tween_property(cover, "position", Vector2(window_width / 2.0, top + art_height / 2.0), OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if lifted:
			tween.tween_property(cover, "scale", Vector2.ONE, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(OPEN_HOLD_SECONDS)
	var ghost = Sprite2D.new()
	ghost.z_index = 4004
	tween.chain().tween_callback(func():
		if has_art:
			ghost.texture = cover_art.texture
			ghost.centered = cover_art.centered
			ghost.offset = cover_art.offset
			add_child(ghost)
			ghost.global_transform = cover_art.global_transform
			cover.visible = false
		if lifted:
			drop_inline_cover()
		cover.position = home_position
		cover.z_index = home_z
		if is_instance_valid(slot):
			slot.self_modulate.a = 1.0
		go.call())
	tween.chain().tween_property(_launch_flash, "color:a", 0.0, SETTLE_SECONDS)
	tween.parallel().tween_property(flyer, "position:x", window_width + scaled_text_height, SETTLE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if has_art:
		var art_width = cover_art.texture.get_size().x * cover_art.scale.x * cover.scale.x
		tween.parallel().tween_property(ghost, "position:x", -art_width, SETTLE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if prompt_bar != null:
		tween.parallel().tween_property(prompt_bar, "modulate:a", 1.0, SETTLE_SECONDS)
	tween.chain().tween_callback(func():
		flyer.queue_free()
		if ghost.is_inside_tree():
			ghost.queue_free()
		else:
			ghost.free()
		launching = false
		update_nearby_covers())

func launch_with_effect(launch: Callable, game_name: String = "", launcher_name: String = ""):
	if launching:
		return
	var effects = effects_on()
	var view = Settings.get_setting(Settings.CFG_LAUNCH_VIEW)
	var lifted = view in ["cover_info", "cover"] and lift_inline_cover()
	var has_cover = cover.visible and cover_art.texture != null
	var parts = launch_parts(view, has_cover)
	if not effects and not parts.cover and not parts.info:
		launch.call()
		return
	launching = true
	hide_nearby_art()
	var seconds = LAUNCH_SECONDS if effects else 0.01
	if _launch_flash == null:
		_launch_flash = _overlay(3999)
	_launch_flash.size = Vector2(window_width, window_height + title_offset)
	_launch_flash.color = Color(Settings.get_setting(Settings.CFG_BG_COLOR), 0.0)
	if _cover_pop != null:
		_cover_pop.kill()
	var lines = launch_lines(game_name, launcher_name) if parts.info else ([[game_name, true]] if parts.cover and game_name != "" else [])
	var text = _launch_text(lines) if not lines.is_empty() else null
	if text != null:
		add_child(text)
	var slot = selected_slot() if effects and text != null else null
	var flyer = _text_flyer(slot) if slot != null and slot.text.strip_edges() != "" else null
	var title_line = text.get_child(lines.find_custom(func(l): return l[1])) if flyer != null else null
	if flyer != null:
		title_line.self_modulate.a = 0.0
		slot.self_modulate.a = 0.0
	var text_height: float = text.get_meta("height") if text != null else 0.0
	var home_position = cover.position
	var home_scale = cover.scale
	var home_z = cover.z_index
	var center = cover.position
	var cover_scale = 1.0
	if parts.cover:
		var cover_height = cover_art.texture.get_size().y * cover_art.scale.y
		var gap = scaled_text_height * 0.2 if text != null else 0.0
		var margin = scaled_text_height * LAUNCH_MARGIN
		cover_scale = minf(launch_cover_scale(cover_height, window_height), (window_height - margin * 2.0 - gap - text_height) / cover_height)
		var shown_height = cover_height * cover_scale
		var top = maxf(margin, (window_height - shown_height - gap - text_height) / 2.0)
		center = Vector2(window_width / 2.0, top + shown_height / 2.0)
		if text != null:
			text.position = Vector2(window_width / 2.0, top + shown_height + gap)
		cover.z_index = 4004
	elif text != null:
		text.position = Vector2(window_width / 2.0, (window_height - text_height) / 2.0)
	if text != null:
		text.modulate.a = 0.0
	if flyer != null:
		var line_size = title_line.get_theme_font_size("font_size")
		var line_middle = text.position.y + title_line.position.y + title_line.get_theme_font("font").get_height(line_size) / 2.0
		flyer.set_meta("target", Vector2(centered_left(flyer.size.x, window_width), line_middle - flyer.get_meta("middle")))
	if effects:
		vibrate(40)
		play_click()
		if has_cover:
			cover_art.self_modulate = Color(FLASH_BRIGHTNESS, FLASH_BRIGHTNESS, FLASH_BRIGHTNESS)
			var flash = create_tween()
			flash.tween_property(cover_art, "self_modulate", Color.WHITE, FLASH_OUT_SECONDS)
			var press = create_tween()
			if not lifted:
				press.tween_property(cover, "scale", Vector2.ONE * COVER_PRESS_SCALE, COVER_PRESS_SECONDS).set_ease(Tween.EASE_OUT)
			press.tween_property(cover, "scale", Vector2.ONE * cover_scale, seconds).set_trans(Tween.TRANS_BACK if not lifted else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var shows_view = parts.cover or parts.info
	var tween = create_tween().set_parallel()
	tween.tween_property(_launch_flash, "color:a", LAUNCH_DIM if shows_view else 0.0, seconds)
	if text != null:
		tween.tween_property(text, "modulate:a", 1.0, seconds)
	if flyer != null:
		tween.tween_property(flyer, "position", flyer.get_meta("target"), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if shows_view and prompt_bar != null:
		tween.tween_property(prompt_bar, "modulate:a", 0.0, seconds)
	if parts.cover:
		tween.tween_property(cover, "position", center, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if not effects:
			tween.tween_property(cover, "scale", Vector2.ONE * cover_scale, seconds)
	if shows_view:
		tween.chain().tween_interval(LAUNCH_VIEW_MIN_SECONDS)
	tween.chain().tween_callback(launch)
	tween.chain().tween_interval(LAUNCH_HOLD_SECONDS if shows_view else 0.0)
	tween.chain().tween_property(_launch_flash, "color:a", 0.0, SETTLE_SECONDS if effects else 0.01)
	if text != null:
		tween.parallel().tween_property(text, "modulate:a", 0.0, SETTLE_SECONDS if effects else 0.01)
	if flyer != null:
		tween.parallel().tween_property(flyer, "modulate:a", 0.0, SETTLE_SECONDS)
	if prompt_bar != null:
		tween.parallel().tween_property(prompt_bar, "modulate:a", 1.0, SETTLE_SECONDS if effects else 0.01)
	if parts.cover:
		tween.parallel().tween_property(cover, "position", home_position, SETTLE_SECONDS if effects else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cover, "scale", home_scale, SETTLE_SECONDS if effects else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		if text != null:
			text.queue_free()
		if flyer != null:
			flyer.queue_free()
			if is_instance_valid(slot):
				slot.self_modulate.a = 1.0
		cover.z_index = home_z
		if lifted:
			drop_inline_cover()
		launching = false
		update_nearby_covers())

func refresh_option_text():
	show_options(scroll_offset)

func show_options(offset=0):
	if offset == null:
		offset = 0
		scroll_offset = 0
	if option_list.size() < focus_rows():
		scroll_offset = 0
		offset = 0
	if option_selection - scroll_offset > focus_rows():
		scroll_offset = option_selection - focus_rows() + 1
		offset = scroll_offset
	# Clamp so the last page is always full — no empty slots at the bottom
	var max_offset = max(0, option_list.size() - focus_rows())
	if offset > max_offset:
		offset = max_offset
		scroll_offset = offset
	shown_offset = offset
	for i in range(0, Global.visible_slots.size()):
		if i+offset >= option_list.size():
			set_slot(i, "")
			show_favorite_star(visible_slots[i], false)
			continue
		set_slot(i, option_list[i+offset].clean)
		var is_favorite = favorites_list.has(option_list[i+offset].absolute_path)
		if is_favorite:
			visible_slots[i].text = favorite_indent(visible_slots[i]) + visible_slots[i].text
		show_favorite_star(visible_slots[i], is_favorite)
		place_slot(i)
	show_peek_text()
	if row_stripes != null:
		row_stripes.queue_redraw()
	if inline_layer != null:
		inline_layer.queue_redraw()
	if post_draw_callback != null:
		post_draw_callback.call()

func favorite_star_space() -> float:
	return scaled_text_height * 0.3

func favorite_indent(slot: Label) -> String:
	var font_size = slot.get_theme_font_size("font_size")
	var space_width = slot.get_theme_font("font").get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return " ".repeat(ceili(favorite_star_space() / maxf(1.0, space_width)))

func show_favorite_star(slot: Label, shown: bool):
	var star = slot.get_node_or_null("FavoriteStar")
	if star == null:
		if not shown:
			return
		star = FavoriteStarScript.new()
		star.name = "FavoriteStar"
		slot.add_child(star)
	star.visible = shown
	var star_size = scaled_text_height * 0.2
	star.size = Vector2(star_size, star_size)
	var font_size = slot.get_theme_font_size("font_size")
	var letters_middle = slot.get_theme_font("font").get_ascent(font_size) * 0.62
	if slot.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		letters_middle += (slot.size.y - slot.get_theme_font("font").get_height(font_size)) / 2.0
	star.position = Vector2((favorite_star_space() - star_size) / 2.0, letters_middle - star_size / 2.0)
	star.queue_redraw()

func _favorites_json_path() -> String:
	return root_path + PATH_GAMES + "FAVORITES/favorites.json"

func _load_favorites_json() -> Array:
	return read_json_array(_favorites_json_path())

func _save_favorites_json(entries: Array):
	write_json(_favorites_json_path(), entries)

func get_favorites_entries() -> Array:
	return _load_favorites_json()

func populate_favorites():
	favorites_list.clear()
	for entry in _load_favorites_json():
		favorites_list[entry.get("path", "")] = true
	Global.show_options(Global.scroll_offset)

func add_favorite(item):
	if Global.favorites_list.has(item.absolute_path):
		return
	var entries = _load_favorites_json()
	entries.append({
		"name": item.clean,
		"system": item.system,
		"path": item.absolute_path,
		"filename": item.filename,
	})
	_save_favorites_json(entries)
	print("ADDING FAVORITE " + item.clean)
	Global.populate_favorites()

func clear_all_favorites():
	var path = _favorites_json_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	favorites_list.clear()
	print("Cleared all favorites")

func clear_recent_history():
	var recent_path = root_path + "/Config/COMMON/recent.json"
	if FileAccess.file_exists(recent_path):
		DirAccess.remove_absolute(recent_path)
	print("Cleared recent history")

func remove_favorite(item):
	var target_path = item.absolute_path
	var entries = _load_favorites_json()
	entries = entries.filter(func(e): return e.get("path", "") != target_path)
	_save_favorites_json(entries)
	print("REMOVING FAVORITE " + target_path)
	Global.store_position()
	Global.populate_favorites()

func toggle_favorite(item):
	if item.clean == "":
		return
	if Global.favorites_list.has(item.absolute_path):
		remove_favorite(item)
		Global.show_message("Removed from favorites", true)
	else:
		add_favorite(item)
		Global.show_message("Added to favorites", true)
	highlight_selection()
	show_options(scroll_offset)

func hide_item():
	var item = Global.get_selected()
	if Global.special_item != null:
		item = Global.special_item
	if item.filename.to_lower() == "settings":
		return
	print("HIDE " + item.absolute_path)
	HIDDEN_LIST[item.absolute_path] = true
	update_list_file_contents("hidden", HIDDEN_LIST.keys())
	show_options(scroll_offset)

func unhide_item():
	var item = Global.get_selected()
	if Global.special_item != null:
		item = Global.special_item
	if not HIDDEN_LIST.has(item.absolute_path):
		return
	print("UNHIDE " + item.absolute_path)
	HIDDEN_LIST.erase(item.absolute_path)
	update_list_file_contents("hidden", HIDDEN_LIST.keys())
	show_options(scroll_offset)

func toggle_hidden():
	Global.store_position()
	if Navigator.current_screen == "settings":
		return
	var item = Global.get_selected()
	if Global.special_item != null:
		item = Global.special_item
	if HIDDEN_LIST.get(item.absolute_path, false):
		unhide_item()
	else:
		hide_item()

const SELF_LAUNCH_SCRIPTS = ["Plain Launcher.sh", "PlainLauncher.sh"]

static func unique_by_filename(options: Array) -> Array:
	var seen = {}
	var unique = []
	for opt in options:
		var key = opt.filename.to_lower()
		if not seen.has(key):
			seen[key] = true
			unique.append(opt)
	return unique

func list_multiple_paths_combined(paths):
	var listed = {}
	for path in paths:
		if _missing_dirs.has(path) or listed.has(path.to_lower()):
			continue
		listed[path.to_lower()] = true
		var dir = DirAccess.open(path)
		if dir == null:
			print("FAILED TO ACCESS " + path)
			_missing_dirs[path] = true
			continue
		list_directory_contents(dir, false, [], false)
	Global.option_list = unique_by_filename(Global.option_list).filter(func(opt): return not opt.filename in SELF_LAUNCH_SCRIPTS)
	Global.option_list.sort_custom(by_display_name)
	restore_position()

static func shown_title(opt) -> String:
	return str(Global.ALIAS_MAP.get(opt.clean.to_lower(), opt.clean))

static func shown_name(opt) -> String:
	return str(Global.ALIAS_MAP.get(opt.clean.to_lower(), opt.clean)).to_lower()

static func by_display_name(a, b) -> bool:
	var first = shown_name(a)
	var second = shown_name(b)
	if first != second:
		return first < second
	return a.filename.to_lower() < b.filename.to_lower()

static func sort_after_specials(options: Array, special: Array) -> Array:
	var pinned = options.filter(func(o): return o.filename in special)
	var rest = options.filter(func(o): return o.filename not in special)
	rest.sort_custom(by_display_name)
	return pinned + rest

func list_directory_contents(directory: DirAccess, dirs_only=true, special=[], refresh_at_end=true, use_cache=true):
	if directory == null:
		return
	print("LIST CONTENTS " + directory.get_current_dir() + " DIRS_ONLY: " + str(dirs_only))
	current_directory = directory.get_current_dir()
	var cached = _read_dir_cached(directory, dirs_only) if use_cache else _read_dir_uncached(directory, dirs_only)
	var file_names = []
	var system = ""
	if dirs_only:
		for f in cached:
			if not special.has(f):
				file_names.append(f)
		file_names.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	else:
		file_names = Array(cached)
		system = Global.subscreen
	var unique_paths = get_system_unique_paths()
	for path in unique_paths.keys():
		if FileAccess.file_exists(directory.get_current_dir() + "/" + path):
			file_names.append(path)
			ALIAS_MAP[clean_regex.sub(path.get_basename(), "", true)] = unique_paths[path]
	for special_file in special:
		file_names.push_front(special_file)
	var added = []
	for file in file_names:
		var opt = option.new()
		opt.filename = file
		opt.absolute_path = directory.get_current_dir() + "/" + file
		if !clean_names.has(file):
			var cleaned = clean_regex.sub(file.get_basename(), "", true)
			clean_names[file] = ALIAS_MAP.get(cleaned, cleaned)
		opt.clean = clean_names.get(file)

		var use_system = system
		if dirs_only:
			opt.is_dir = true
			use_system = file
		opt.system = use_system
		if populate_filter != null:
			var populate_filter_callback: Callable = populate_filter
			if populate_filter_callback.call(opt):
				continue
		if filter_out_hidden(opt):
			continue
		added.append(opt)
	Global.option_list.append_array(sort_after_specials(added, special))
	option_selection = 0
	if refresh_at_end:
		restore_position()
		highlight_selection()

func move_down():
	if not can_scroll:
		return
	play_sound("move")
	if option_selection >= option_list.size() - 1:
		scroll_offset = 0
		option_selection = -1
		vibrate(50)
		show_options(0)
	elif option_selection == scroll_offset + focus_rows() - 1:
		scroll_offset += 1
		show_options(scroll_offset)
	if confirm_hold_time != null:
		confirm_hold_time = Time.get_ticks_msec()
	highlight_selection(option_selection+1)

func move_up():
	if not can_scroll:
		return
	play_sound("move")
	if option_selection <= 0:
		if option_list.size() >= focus_rows():
			scroll_offset = option_list.size() - focus_rows()
			show_options(scroll_offset)
		option_selection = option_list.size()
		vibrate(50)
	elif scroll_offset > 0 and option_selection == scroll_offset:
		scroll_offset -= 1
		show_options(scroll_offset)
	if confirm_hold_time != null:
		confirm_hold_time = Time.get_ticks_msec()
	highlight_selection(option_selection-1)

func build_system_settings_from_options(system_for_settings=Global.subscreen):
	var system_settings_options = get_system_settings_options(system_for_settings)
	if system_settings_options == null or system_settings_options.is_empty():
		return {}
	var system_settings = {}
	for key in system_settings_options.keys():
		if key.to_lower() == "extensions":
			system_settings[key] = system_settings_options[key]
		else:
			system_settings[key] = system_settings_options[key][0]
	return system_settings

func get_system_settings_options(system_for_settings=Global.subscreen):
	var options_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/choices.json"
	print("GET SETTINGS OPTIONS AT " + options_path)
	var options = read_json_dict(options_path)
	var hidden = options.get("EMULATOR_HIDDEN", [])
	options.erase("EMULATOR_HIDDEN")
	var emulators: Array = options.get("EMULATOR", []).duplicate()
	for id in Launcher.emulators_for_system(system_for_settings):
		if id not in emulators and id not in hidden:
			emulators.append(id)
	if Launcher.uses_commands():
		var available = Launcher.load_intents()
		emulators = emulators.filter(func(id): return available.has(id))
	if not emulators.is_empty():
		options["EMULATOR"] = emulators
	return options

func get_system_unique_paths(system_for_settings=Global.subscreen):
	var uniques_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/unique_paths.json"
	print("GET UNIQUE PATHS AT " + uniques_path)
	return read_json_dict(uniques_path)

func get_systemwide_settings(for_system):
	var current_settings_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + for_system + "/config.json"
	var current_settings = read_json_dict(current_settings_path)
	if current_settings.is_empty():
		return build_system_settings_from_options(for_system)
	return current_settings

func get_game_settings_path(system: String, filename: String) -> String:
	return Global.root_path + "/" + Global.PATH_CONFIG + "/" + system + "/games/" + filename + ".json"

func get_legacy_game_settings_path(system: String, clean: String) -> String:
	return Global.root_path + "/" + Global.PATH_CONFIG + "/" + system + "/" + clean + ".json"

func get_system_settings(system_for_settings=Global.subscreen, filename: String = "", clean: String = ""):
	if system_for_settings == "" or system_for_settings == null:
		return {}
	if filename != "":
		var game_settings = read_json_dict(get_game_settings_path(system_for_settings, filename))
		if game_settings.is_empty() and clean != "":
			game_settings = read_json_dict(get_legacy_game_settings_path(system_for_settings, clean))
		if not game_settings.is_empty():
			print("GET SETTINGS for game " + filename)
			return game_settings
	var current_settings_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/config.json"
	print("GET SETTINGS " + current_settings_path)
	var system_settings = read_json_dict(current_settings_path)
	if system_settings.is_empty():
		system_settings = build_system_settings_from_options(system_for_settings)
	return system_settings

func get_paths_filepath(system: String, prefix=""):
	return Global.root_path + Global.PATH_CONFIG + system + "/" + prefix + "paths.txt"

func get_compat_paths_filepath(system: String):
	var bundled = "res://launcher_configs/" + system + "/compatibility_paths.txt"
	if FileAccess.file_exists(bundled):
		return bundled
	return Global.root_path + Global.PATH_CONFIG + system + "/compatibility_paths.txt"

func store_additional_paths(system: String, paths):
	var paths_file = get_paths_filepath(system)
	var paths_file_write = FileAccess.open(paths_file, FileAccess.WRITE)
	print("STORE ADDITIONAL PATHS " + str(paths) + " TO " + paths_file)
	paths_file_write.store_string("\n".join(paths))

func remove_additional_path(system: String, path):
	var paths_file = get_paths_filepath(system)
	if not FileAccess.file_exists(paths_file):
		return
	var paths: Array = FileAccess.get_file_as_string(paths_file).split("\n")
	paths.erase(path)
	var paths_file_write = FileAccess.open(paths_file, FileAccess.WRITE)
	paths_file_write.store_string("\n".join(paths))

func get_user_paths(system: String) -> Array:
	var paths_file = get_paths_filepath(system)
	if not FileAccess.file_exists(paths_file):
		return []
	return Array(FileAccess.get_file_as_string(paths_file).split("\n")).filter(func(p): return p != "")

func get_additional_paths(system: String):
	var paths_file = get_paths_filepath(system)
	var paths = []
	if FileAccess.file_exists(paths_file):
		for path in FileAccess.get_file_as_string(paths_file).split("\n"):
			if path != "":
				paths.append(path)
	paths.append_array(compat_paths(system))
	print("GOT ADDITIONAL PATHS " + str(paths) + " FROM " + paths_file)
	return paths

func get_selected():
	if option_list.is_empty() or option_selection > option_list.size():
		return null_option
	return option_list[option_selection]

static func list_key(screen: String, list: String, file_browser_label: String) -> String:
	if screen == "file_browser":
		return file_browser_label.to_lower()
	if screen == "game_browser":
		return screen + ":" + list
	return screen

func position_key() -> String:
	return list_key(Navigator.current_screen, str(subscreen), message.text if message != null else "")

func get_stored_scroll_offset():
	return scroll_offsets.get(position_key())

func get_stored_cursor_position():
	return cursor_positions.get(position_key())

func store_position():
	var key = position_key()
	cursor_positions[key] = option_selection if Navigator.current_screen == "file_browser" else Global.get_selected().absolute_path
	cursor_indices[key] = option_selection
	scroll_offsets[key] = scroll_offset

func restore_position():
	option_selection = 0
	scroll_offset = 0

	if get_stored_cursor_position() != null:
		while option_selection < option_list.size():
			if get_selected().absolute_path == get_stored_cursor_position():
				var stored_scroll = get_stored_scroll_offset()
				scroll_offset = min(stored_scroll, option_selection) if stored_scroll != null else option_selection
				break
			option_selection += 1
			scroll_offset = max(0, option_selection - focus_rows())
		if option_selection == option_list.size():
			# Path match failed — fall back to stored numeric index
			var title_key = position_key()
			var stored_idx = cursor_indices.get(title_key, 0)
			option_selection = min(stored_idx, option_list.size() - 1)
			var stored_scroll = scroll_offsets.get(title_key, 0)
			scroll_offset = min(stored_scroll, max(0, option_list.size() - focus_rows()))

		if not option_list.is_empty() and option_selection >= option_list.size():
			option_selection = option_list.size() - 1
	show_options(scroll_offset)
	highlight_selection()

func filter_out_hidden(item):
	if show_hidden:
		return false
	return HIDDEN_LIST.get(item.absolute_path, false)

func on_scroll():
	if post_scroll_callback != null:
		post_scroll_callback.call()
	refresh_art()

func cursor_locked():
	if launching:
		return true
	if disable_scroll or letter_scroller == null:
		return disable_scroll
	if Input.is_action_pressed("trigger_r") and letters_allowed():
		return true
	return letter_scroller.active

func letters_allowed() -> bool:
	return special_allowed() and not option_list.is_empty()

func jump_to_row(index: int):
	option_selection = clampi(index, 0, option_list.size() - 1)
	scroll_offset = clampi(option_selection, 0, maxi(0, option_list.size() - focus_rows()))
	show_options(scroll_offset)
	highlight_selection()
	refresh_art()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if message == null:
		return
	if letter_scroller != null:
		if Input.is_action_pressed("trigger_r") and letters_allowed():
			if not letter_scroller.active or letter_scroller.peeking:
				letter_scroller.begin()
			else:
				letter_scroller.handle_held_input()
		elif letter_scroller.active and not letter_scroller.by_touch and not letter_scroller.peeking:
			letter_scroller.finish()
	if Input.is_action_just_pressed("options") and special_allowed():
		Navigator.go_to_special()
	if confirm_just_released():
		play_sound("accept")
	elif back_just_pressed():
		play_sound("back")
	if effects_on() and not cursor_locked() and not panel_open() and not launching:
		if confirm_just_pressed():
			press_feedback(true)
		elif confirm_just_released():
			press_feedback(false)
	if message_overflow > 0.0 and message.modulate.a > 0:
		var speed = prompt_text_size() * 3.0
		message_scroll_time += delta
		if message_scroll_time > MESSAGE_SCROLL_PAUSE * 2.0 + message_overflow / speed:
			message_scroll_time = 0.0
			message_scroll_passes += 1
		message.position.x = message_scroll_x(message_scroll_time, message_overflow, speed, MESSAGE_SCROLL_PAUSE)
	if message.modulate.a > 0:
		if message_overflow <= 0.0 or message_scroll_passes > 0:
			message.modulate.a -= delta / 2.0
	elif !message_queue.is_empty():
		show_message(message_queue.pop_front())
	if !cursor_locked():
		if _queued_move != 0 and not waiting_for_art():
			step_when_art_ready(_queued_move)
		if Global.up_just_pressed():
			step_when_art_ready(-1)
			held_time = Time.get_ticks_msec() + 500
		if Global.up_held():
			if Time.get_ticks_msec() - held_time > 50 and step_when_art_ready(-1):
				held_time = Time.get_ticks_msec()
		if Global.down_just_pressed():
			step_when_art_ready(1)
			held_time = Time.get_ticks_msec() + 500
		if Global.down_held():
			if Time.get_ticks_msec() - held_time > 50 and step_when_art_ready(1):
				held_time = Time.get_ticks_msec()
		if Global.right_just_pressed():
			_scroll_horizontal(1)
			held_time = Time.get_ticks_msec() + 500
		if Global.right_held():
			if Time.get_ticks_msec() - held_time > 20:
				_scroll_horizontal(1)
				held_time = Time.get_ticks_msec()
		if Global.left_just_pressed():
			_scroll_horizontal(-1)
			held_time = Time.get_ticks_msec() + 500
		if Global.left_held():
			if Time.get_ticks_msec() - held_time > 20:
				_scroll_horizontal(-1)
				held_time = Time.get_ticks_msec()
		if Input.is_action_just_pressed("special") and special_allowed():
			Navigator.go_to_special()
	else:
		_queued_move = 0

func _physics_process(delta):
	if title != null and title_collapsed != (title_can_be_blank and title.text == ""):
		apply_visual_change()
	if touch_position == null or touch_start_position == null:
		control_tilt = Vector2(Input.get_action_strength("left_stick_right") - Input.get_action_strength("left_stick_left"), Input.get_action_strength("left_stick_down") - Input.get_action_strength("left_stick_up"))
		var new_tilt_ratio = max(0.1, (1.0 - control_tilt.length()) / 1.0)
		if !cursor_locked():
			if tilt_ratio >= 0.95 and new_tilt_ratio < 0.95:
				touch_check_time = Time.get_ticks_msec() + 300
				var flick_angle = control_tilt.angle()
				if flick_angle > PI / 4.0 and flick_angle < 3 * PI / 4.0:
					vibrate(30)
					move_down()
					on_scroll()
				elif flick_angle < -PI / 4.0 and flick_angle > -3 * PI / 4.0:
					vibrate(30)
					move_up()
					on_scroll()
				elif abs(flick_angle) < PI / 4.0:
					vibrate(30)
					_analog_right_just = true
				elif abs(flick_angle) > 3 * PI / 4.0:
					vibrate(30)
					_analog_left_just = true
		tilt_ratio = new_tilt_ratio

	if cursor_locked():
		return

	if confirm_just_pressed():
		confirm_hold_time = Time.get_ticks_msec()
	if !confirm_held() and touch_position == null and confirm_hold_time != null:
		if pending_special:
			Navigator.go_to_special()
			return
		confirm_hold_time = null

	if option_selection - scroll_offset >= focus_rows():
		print("OPTION SELECTION: " + str(option_selection) + " SCROLL OFFSET " + str(scroll_offset) + " VISIBLE_SLOT SIZE " + str(visible_slots.size()))
		scroll_offset = option_selection - focus_rows() + 1
	if visible_slots.is_empty():
		return
	if option_selection == 0 and scroll_offset != 0:
		scroll_offset = 0
	var curr_slot = visible_slots[option_selection - scroll_offset]
	if special_allowed() and (confirm_hold_time != null and Time.get_ticks_msec() - confirm_hold_time > 500):
		press_pivot(curr_slot)
		if curr_slot.scale.x < 1.2:
			curr_slot.scale *= 1.1
			curr_slot.size /= 1.1
		if curr_slot.scale.x > 1.2:
			curr_slot.scale = Vector2(1.2,1.2)
			curr_slot.size = slot_size / 1.2
		if curr_slot.scale.x < 1.1:
			pending_special = false
			vibrate(20)
		else:
			if !pending_special:
				vibrate(100)
			pending_special = true
	elif curr_slot.scale.x > 1.0:
		curr_slot.scale *= 0.9
		curr_slot.size /= 0.9
		if curr_slot.scale.x < 1.0:
			curr_slot.scale = Vector2(1,1)
			curr_slot.size = slot_size
			place_slot(visible_slots.find(curr_slot))
	else:
		pending_special = false
	if pending_special and (Input.is_action_just_released("key_confirm") or (confirm_swapped and Input.is_action_just_released("back")) or (!confirm_swapped and Input.is_action_just_released("select"))):
		touch_check_time = Time.get_ticks_msec() + 1000
		Navigator.go_to_special()
		return

	if touch_position == null and not _shaking:
		if title.position.x < left_bound - 1:
			title.position.x = lerp(float(title.position.x), left_bound, 0.2)
		else:
			title.position.x = left_bound

	if touch_position == null:
		if abs(touch_momentum) > 0.5 and not cursor_locked():
			var scroll_dir = -1.0 if Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL) else 1.0
			touch_scroll_accum += touch_momentum * scroll_dir
			var scrolled = false
			while touch_scroll_accum > text_height:
				move_down()
				vibrate(20)
				touch_scroll_accum -= text_height
				scrolled = true
			while touch_scroll_accum < -text_height:
				move_up()
				vibrate(20)
				touch_scroll_accum += text_height
				scrolled = true
			if scrolled:
				on_scroll()
			touch_momentum *= 0.82
			if abs(touch_momentum) < 1.0:
				touch_momentum = 0.0
				touch_scroll_accum = 0.0
		if Time.get_ticks_msec() > touch_check_time:
			if not pending_back and not pending_special and not waiting_for_art():
				var moving = false
				if control_tilt.y < -0.1:
					moving = true
					vibrate(40)
					move_up()
				if control_tilt.y > 0.1:
					moving = true
					vibrate(40)
					move_down()
				if moving:
					on_scroll()
					pending_special = false
					touch_check_time = Time.get_ticks_msec() + stick_repeat_ms(tilt_ratio)

###############################################################
#
# Controller stuff
#
###############################################################
const STICK_REPEAT_FAST_MS = 70.0
const STICK_REPEAT_SLOW_MS = 250.0

static func stick_repeat_ms(ratio: float) -> float:
	var push = clampf((1.0 - ratio) / 0.9, 0.0, 1.0)
	return lerpf(STICK_REPEAT_SLOW_MS, STICK_REPEAT_FAST_MS, push)

const SHAKE_STEPS = [1.0, -1.0, 0.7, -0.7, 0.4, -0.4, 0.0]
const SHAKE_STEP_SECONDS = 0.045
var _shaking = false

static func shake_offsets(amplitude: float) -> Array:
	return SHAKE_STEPS.map(func(f): return f * amplitude)

func shake_refresh():
	vibrate(120)
	title.position.x = left_bound
	if not effects_on():
		return
	_shaking = true
	var amplitude = scaled_text_height * 0.12
	var tween = create_tween().set_parallel()
	var targets = [[title, left_bound]]
	if cover != null and cover.visible:
		targets.append([cover, cover.position.x])
	for target in targets:
		var steps = create_tween()
		for offset in shake_offsets(amplitude):
			steps.tween_property(target[0], "position:x", target[1] + offset, SHAKE_STEP_SECONDS)
		tween.tween_subtween(steps)
	tween.chain().tween_callback(func(): _shaking = false)

func vibrate(duration):
	if !Settings.get_setting(Settings.CFG_VIBRATE):
		return
	Input.vibrate_handheld(duration)

static func needs_confirm_button(already_set: bool, pads: int) -> bool:
	return not already_set and pads > 0

func ask_for_confirm_button():
	if not needs_confirm_button(Settings.get_setting(Settings.CFG_CONFIRM_SET), Input.get_connected_joypads().size()):
		return
	if root_path == "" or panel_open() or launching or Navigator.current_screen in ["", "confirm_set"]:
		return
	Navigator.push("confirm_set")

func swap_confirm_key():
	confirm_swapped = !confirm_swapped
	Settings.store(Settings.CFG_CONFIRM_SWAP, confirm_swapped)
	apply_face_swap(confirm_swapped)

static func face_buttons(swapped: bool) -> Dictionary:
	return {"favorite": JOY_BUTTON_X if swapped else JOY_BUTTON_Y, "special": JOY_BUTTON_Y if swapped else JOY_BUTTON_X}

static func apply_face_swap(swapped: bool):
	var buttons = face_buttons(swapped)
	for action in buttons:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
		var pad = InputEventJoypadButton.new()
		pad.button_index = buttons[action]
		pad.device = -1
		InputMap.action_add_event(action, pad)

var _confirm_blocked_until = -1
const CONFIRM_BLOCK_FRAMES = 2

func block_confirm():
	waiting_for_confirm_release = confirm_held()
	_confirm_blocked_until = Engine.get_process_frames() + CONFIRM_BLOCK_FRAMES

static func confirm_blocked(frame: int, blocked_until: int) -> bool:
	return frame <= blocked_until

func confirm_pressed():
	if confirm_blocked(Engine.get_process_frames(), _confirm_blocked_until):
		return false
	if pending_special or pending_back:
		return false
	if waiting_for_confirm_release:
		if confirm_held():
			return false
		waiting_for_confirm_release = false
		return false
	if Input.is_action_just_released("key_confirm"):
		return true
	if confirm_swapped:
		return Input.is_action_just_released("back")
	return Input.is_action_just_released("select")

func confirm_just_pressed() -> bool:
	if Input.is_action_just_pressed("key_confirm"):
		return true
	return Input.is_action_just_pressed("back" if confirm_swapped else "select")

func confirm_held():
	if Input.is_action_pressed("key_confirm"):
		return true
	if confirm_swapped:
		return Input.is_action_pressed("back")
	return Input.is_action_pressed("select")

func back_pressed():
	if Input.is_action_just_pressed("key_back"):
		return true
	if confirm_swapped:
		return Input.is_action_just_pressed("select")
	return Input.is_action_just_pressed("back")

var using_keyboard = false

func xbox_labels() -> bool:
	return Platform.uses_xbox_layout()

func note_input_device(event: InputEvent):
	var keyboard = using_keyboard
	if event is InputEventKey and event.pressed:
		keyboard = true
	elif (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		keyboard = false
	if keyboard != using_keyboard:
		using_keyboard = keyboard
		if prompt_bar != null:
			prompt_bar.queue_redraw()

func up_just_pressed():
	if Input.is_action_just_pressed("up"):
		return true
	return false

func up_held():
	if Input.is_action_pressed("up"):
		return true
	return false

func down_just_pressed():
	if Input.is_action_just_pressed("down"):
		return true
	return false

func down_held():
	if Input.is_action_pressed("down"):
		return true
	return false

func left_just_pressed():
	if Input.is_action_just_pressed("left"):
		return true
	if _analog_left_just:
		_analog_left_just = false
		return true
	return false

func left_held():
	if Input.is_action_pressed("left"):
		return true
	var x = Input.get_action_strength("left_stick_left") - Input.get_action_strength("left_stick_right")
	var y_abs = maxf(Input.get_action_strength("left_stick_up"), Input.get_action_strength("left_stick_down"))
	return x > 0.5 and x > y_abs

func right_just_pressed():
	if Input.is_action_just_pressed("right"):
		return true
	if _analog_right_just:
		_analog_right_just = false
		return true
	return false

func right_held():
	if Input.is_action_pressed("right"):
		return true
	var x = Input.get_action_strength("left_stick_right") - Input.get_action_strength("left_stick_left")
	var y_abs = maxf(Input.get_action_strength("left_stick_up"), Input.get_action_strength("left_stick_down"))
	return x > 0.5 and x > y_abs

func toggle_vibrate():
	Settings.store(Settings.CFG_VIBRATE, !Settings.get_setting(Settings.CFG_VIBRATE))
	if Settings.get_setting(Settings.CFG_VIBRATE):
		vibrate(400)

func touch_checkin():
	if touch_position == null or previous_touch_position == null:
		return
	previous_touch_position = touch_position

func get_es_de_system(selected=Global.get_selected()):
	var curr_sys = selected.system.to_lower()
	if curr_sys == "gamecube":
		return "gc"
	elif curr_sys == "pce":
		return "pcengine"
	elif curr_sys == "ps":
		return "psx"
	return curr_sys

func alias_location(item) -> Array:
	if clean_regex == null:
		clean_regex = RegEx.create_from_string(CLEAN_PATTERN)
	if item.is_dir:
		return [root_path + PATH_CONFIG + "COMMON/alias.json", item.filename.to_lower()]
	return [root_path + PATH_CONFIG + item.system + "/alias.json", clean_regex.sub(item.filename.get_basename(), "", true)]

func default_name(item) -> String:
	var location = alias_location(item)
	var bundled = read_json_dict("res://launcher_configs/" + ("COMMON" if item.is_dir else item.system) + "/alias.json")
	var fallback = item.filename if item.is_dir else location[1]
	return str(bundled.get(location[1], bundled.get(location[1].to_lower(), fallback)))

func custom_name(item) -> String:
	var location = alias_location(item)
	return str(read_json_dict(location[0]).get(location[1], ""))

func set_custom_name(item, name: String):
	var location = alias_location(item)
	var aliases = read_json_dict(location[0])
	if name.strip_edges() == "":
		aliases.erase(location[1])
	else:
		aliases[location[1]] = name.strip_edges()
	DirAccess.make_dir_recursive_absolute(location[0].get_base_dir())
	write_json(location[0], aliases)
	clean_names.erase(item.filename)
	refresh_alias("COMMON" if item.is_dir else item.system)

static func is_system_item(selected) -> bool:
	return selected.filename.get_basename() == selected.system

func custom_art_path(selected) -> String:
	if is_system_item(selected):
		return str(Global.root_path + Global.PATH_IMAGES + selected.system + "_custom.png").replace("//", "/")
	return own_image_path(selected)

var _compat_art_dirs = {}
var sync_loading = OS.get_environment("PLAIN_LAUNCHER_SYNC_LOADING") == "1"

func compat_art_dirs(system: String) -> Array:
	if not _compat_art_dirs.has(system):
		var dirs = []
		var list_file = "res://launcher_configs/" + system + "/compatibility_art_paths.txt"
		if FileAccess.file_exists(list_file):
			var home = Platform.home_dir()
			var prefixes = existing_dirs([OS.get_environment("PLAIN_LAUNCHER_ART"), home.path_join("ES-DE/downloaded_media"), home.path_join("Emulation/tools/downloaded_media")] + media_mounts("Emulation/tools/downloaded_media"))
			for prefix in prefixes:
				for line in FileAccess.get_file_as_string(list_file).split("\n"):
					var dir = prefix + line.strip_edges()
					if line.strip_edges() != "" and DirAccess.dir_exists_absolute(dir):
						dirs.append(dir)
		_compat_art_dirs[system] = dirs
	return _compat_art_dirs[system]

func get_image_path(selected=Global.get_selected()):
	var own = own_image_path(selected)
	if own == "" or selected.system == "ANDROID" or is_system_item(selected) or art_exists(own):
		return own
	for dir in compat_art_dirs(selected.system):
		var candidate = dir + "/" + selected.filename.get_basename() + ".png"
		if art_exists(candidate):
			return candidate
	return own

func own_image_path(selected=Global.get_selected()):
	var system_in_question = selected.system
	var game_title = selected.filename.get_basename()
	if game_title == system_in_question:
		if not force_cover and not Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_ART):
			return ""
		var custom = custom_art_path(selected)
		if art_exists(custom):
			return custom
		return str(Global.root_path + Global.PATH_IMAGES + system_in_question + ".png").replace("//", "/")
	if system_in_question == "ANDROID" and not selected.is_dir and selected.absolute_path != "":
		game_title = selected.absolute_path
	return str(str(Global.root_path) + str(Global.PATH_IMAGES) + str(system_in_question) + "/" + str(game_title) + ".png").replace("//", "/")

static func move_app_art(art_dir: String, apps: Dictionary) -> int:
	var moved = 0
	for label in apps:
		var old_path = art_dir + "/" + str(label).get_basename() + ".png"
		var new_path = art_dir + "/" + str(apps[label]) + ".png"
		if old_path != new_path and FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
			if DirAccess.rename_absolute(old_path, new_path) == OK:
				moved += 1
	return moved

func migrate_android_art(apps: Dictionary):
	var art_dir = str(root_path + PATH_IMAGES + "ANDROID").replace("//", "/")
	var marker = art_dir + "/.package_names"
	if FileAccess.file_exists(marker):
		return
	DirAccess.make_dir_recursive_absolute(art_dir)
	print("Moved " + str(move_app_art(art_dir, apps)) + " app covers to package names")
	FileAccess.open(marker, FileAccess.WRITE).store_string("1")

func press_confirm():
	if confirm_swapped:
		Input.action_press("back")
		Input.action_release("back")
	else:
		Input.action_press("select")
		Input.action_release("select")

func press_back():
	if confirm_swapped:
		Input.action_press("select")
		Input.action_release("select")
	else:
		Input.action_press("back")
		Input.action_release("back")

func disallow_scroll():
	disable_scroll = true

func handle_touch_buttons(event) -> bool:
	if letter_scroller != null and letter_scroller.active:
		return false
	if event is InputEventScreenTouch and event.pressed:
		var action = touch_buttons.button_at(event.position) if touch_buttons.visible else ""
		touch_buttons.poke()
		if action == "":
			return false
		vibrate(BUTTON_BUZZ_MS)
		touch_buttons.press(action)
		return true
	if event is InputEventScreenTouch and touch_buttons.pressed != "":
		var action = touch_buttons.pressed
		touch_buttons.release()
		if touch_buttons.button_at(event.position) == action:
			match action:
				"confirm":
					press_confirm()
				"back":
					press_back()
				_:
					press_action(action)
		return true
	return event is InputEventScreenDrag and touch_buttons.pressed != ""

func handle_letter_touch(event) -> bool:
	if event is InputEventScreenTouch and event.pressed:
		if not letters_allowed() or not letter_scroller.in_band(event.position):
			return false
		if touch_buttons != null and touch_buttons.visible and touch_buttons.button_at(event.position) != "":
			return false
		letter_scroller.begin(true)
		letter_scroller.follow(event.position.y)
		return letter_scroller.active
	if not letter_scroller.active or not letter_scroller.by_touch:
		return false
	if event is InputEventScreenDrag:
		letter_scroller.follow(event.position.y)
		return true
	if event is InputEventScreenTouch:
		letter_scroller.finish()
		return true
	return false

func press_action(action: String):
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED and message != null and not option_list.is_empty():
		store_position()
		store_list_positions()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		press_back()

const BUTTON_ACTIONS = ["select", "back", "favorite", "start", "options"]
const BUTTON_BUZZ_MS = 25

static func is_button_press(event) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.pressed or event.is_echo():
		return false
	return BUTTON_ACTIONS.any(func(action): return event.is_action(action))

func _input(event):
	note_input_device(event)
	if pad_debug and not (event is InputEventMouseMotion):
		pad_note("PAD %s %d %s pressed=%s" % [event.get_class(), event.device, event.as_text(), event.is_pressed()])
	if is_button_press(event):
		vibrate(BUTTON_BUZZ_MS)
	if touch_buttons != null and (event is InputEventKey or event is InputEventJoypadButton) and event.pressed:
		touch_buttons.dismiss()
	if event.is_action_pressed("ui_cancel"):
		vibrate(40)
		press_back()
		get_viewport().set_input_as_handled()
		return
	if !touch_enabled or not Settings.get_setting(Settings.CFG_TOUCH_ENABLED):
		return
	if letter_scroller != null and handle_letter_touch(event):
		get_viewport().set_input_as_handled()
		return
	if touch_buttons != null and handle_touch_buttons(event):
		get_viewport().set_input_as_handled()
		return
	if panel_open() and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		touch_position = null
		touch_start_position = null
		confirm_hold_time = null
		settings_panel.touch(event)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if Time.get_ticks_msec() - touch_start_time < 200:
				return
			touch_start_time = Time.get_ticks_msec()
			touch_start_position = event.position
			touch_position = event.position
			touch_velocity = 0.0
			touch_scroll_accum = 0.0
			touch_is_scrolling = false
			touch_momentum = 0.0
			pending_special = false
			pending_back = false
			if Navigator.current_screen == "storage_wait":
				confirm_hold_time = Time.get_ticks_msec()
		else:
			if touch_position == null or touch_start_position == null:
				touch_position = null
				touch_start_position = null
				confirm_hold_time = null
				return
			confirm_hold_time = null
			if touch_is_scrolling:
				touch_momentum = touch_velocity
			touch_position = null
	if event is InputEventScreenDrag:
		if touch_position == null or touch_start_position == null:
			return
		var dy = event.position.y - touch_position.y
		touch_velocity = touch_velocity * 0.6 + dy * 0.4
		touch_position = event.position
		var diff = touch_position - touch_start_position
		if not touch_is_scrolling and abs(diff.y) > text_height * 0.4 and abs(diff.y) > abs(diff.x):
			touch_is_scrolling = true
			confirm_hold_time = null
		if touch_is_scrolling and not cursor_locked():
			var scroll_dir = -1.0 if Settings.get_setting(Settings.CFG_TOUCH_INVERT_SCROLL) else 1.0
			touch_scroll_accum += dy * scroll_dir * (1.3 + abs(dy) / text_height)
			while touch_scroll_accum > text_height:
				move_down()
				vibrate(30)
				touch_scroll_accum -= text_height
				on_scroll()
			while touch_scroll_accum < -text_height:
				move_up()
				vibrate(30)
				touch_scroll_accum += text_height
				on_scroll()

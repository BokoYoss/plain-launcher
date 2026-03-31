extends Node2D

var window_height = 0
var window_width = 0
var title_offset = 0

var root_path = ""

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
var last_subscreen = ""
var can_scroll = true
var failure_message = ""
var alt_art_path = ""

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

var disable_scroll := false

var held_time = -1
var frame = 0

const OPTIONS_MAKER = preload("res://scenes/option.tscn")
@onready var null_option = OPTIONS_MAKER.instantiate()
var clean_regex = null
var normalize_regex = null

var color_picker = "background"
@onready var BACKDROP = $ColorRect

var current_msg = ""

var ALIAS_MAP = {}
var HIDDEN_LIST = {}

var favorites_list = {}
var fav_indicators = []

var no_alias = false
var confirm_swapped = false
var setting_subscreen = ""
var android_subscreen = null
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
var selector_title: String = ""
var selector_items: Array = []
var selector_active: Array = []
var selector_multi: bool = true
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

var font = null

var VERSION = "25"

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

func _ready():
	window_width = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).x
	window_height = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).y
	if window_height / window_width >= 2.0:
		title_offset = text_height
		window_height -= title_offset
	else:
		title_offset = 0
	BACKDROP.size = Vector2(window_width, window_height)
	root_path = Settings.get_setting(Settings.CFG_ROOT)
	if root_path != null and !DirAccess.dir_exists_absolute(root_path):
		root_path = null

	BACKDROP.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)

	clean_regex = RegEx.new()
	clean_regex.compile("\\s*\\(.+\\)\\s*|\\s*\\[.+\\]\\s*|T.Eng+\\$|\\.nkit")

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
	cover.position.y = window_height * Settings.get_setting(Settings.CFG_VISUAL_ART_POSITION_Y)
	cover.position.x = window_width * Settings.get_setting(Settings.CFG_VISUAL_ART_POSITION_X)

	var list_file_contents = get_list_file_contents()
	if not list_file_contents.has("hidden"):
		list_file_contents["hidden"] = []
	for item in list_file_contents.get("hidden", []):
		HIDDEN_LIST[item] = true

	if Settings.get_setting(Settings.CFG_CONFIRM_SWAP):
		swap_confirm_key()

	OS.request_permissions()

	get_positions_files()

	show_message("Welcome to PlainLauncher!")
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
	_migrate_intents()
	_migrate_choices()

func _migrate_intents():
	var bundled_path = "res://launcher_configs/COMMON/intents.json"
	var user_path = root_path + PATH_CONFIG + "COMMON/intents.json"
	var bundled = JSON.parse_string(FileAccess.get_file_as_string(bundled_path))
	if bundled == null:
		return
	var user_intents = {}
	if FileAccess.file_exists(user_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(user_path))
		if parsed != null:
			user_intents = parsed
	var changed = not FileAccess.file_exists(user_path)
	for key in bundled.keys():
		if not user_intents.has(key):
			user_intents[key] = bundled[key]
			changed = true
	if changed:
		DirAccess.make_dir_recursive_absolute(user_path.get_base_dir())
		var f = FileAccess.open(user_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(user_intents, "\t"))
			f.close()

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
		var bundled = JSON.parse_string(FileAccess.get_file_as_string(bundled_path))
		if bundled == null:
			continue
		var user_choices = {}
		if FileAccess.file_exists(user_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(user_path))
			if parsed != null:
				user_choices = parsed
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
			DirAccess.make_dir_recursive_absolute(user_path.get_base_dir())
			var f = FileAccess.open(user_path, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(user_choices, "\t"))
				f.close()

const RECENT_MAX = 50

func get_recent_list() -> Array:
	if root_path == null:
		return []
	var recent_path = root_path + "/Config/COMMON/recent.json"
	if not FileAccess.file_exists(recent_path):
		return []
	var content = JSON.parse_string(FileAccess.get_file_as_string(recent_path))
	if content == null or not content is Array:
		return []
	return content

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
	var f = FileAccess.open(root_path + "/Config/COMMON/recent.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(recent, "\t"))
		f.close()

func get_list_file_contents():
	if root_path == null:
		return {}
	var list_file = root_path + "/Config/COMMON/lists.json"
	if FileAccess.file_exists(list_file):
		var list_file_contents = JSON.parse_string(FileAccess.get_file_as_string(list_file))
		if list_file_contents != null:
			return list_file_contents
	return {}

func get_positions_files():
	var last_screen = "user://last_screen.txt"
	var cursor_position_file = "user://cursor_positions.json"
	var scroll_offset_file = "user://scroll_offsets.json"
	if FileAccess.file_exists(last_screen):
		last_subscreen = FileAccess.get_file_as_string(last_screen)
	if FileAccess.file_exists(cursor_position_file):
		cursor_positions = JSON.parse_string(FileAccess.get_file_as_string(cursor_position_file))
	if FileAccess.file_exists(scroll_offset_file):
		scroll_offset = JSON.parse_string(FileAccess.get_file_as_string(scroll_offset_file))

func store_positions_files():
	var last_screen = "user://last_screen.txt"
	var cursor_position_file = "user://cursor_positions.json"
	var scroll_offset_file = "user://scroll_offsets.json"
	var file = FileAccess.open(last_screen, FileAccess.WRITE)
	file.store_string(Global.subscreen)
	print("Storing last subscreen as " + Global.subscreen)
	file = FileAccess.open(cursor_position_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(cursor_positions, "   "))
	file = FileAccess.open(scroll_offset_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(scroll_offset, "   "))

func update_list_file_contents(key, new_list):
	var list_file_contents = get_list_file_contents()
	list_file_contents[key] = new_list
	var list_file = FileAccess.open(root_path + "/Config/COMMON/lists.json", FileAccess.WRITE)
	if list_file == null:
		return
	list_file.store_string(JSON.stringify(list_file_contents, "   "))

func resize():
	window_width = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).x
	window_height = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).y
	if window_height / window_width >= 2.0:
		title_offset = text_height * 5
		window_height -= title_offset
	else:
		title_offset = 0
	set_up_slots()
	show_options(scroll_offset)
	highlight_selection(option_selection)

func load_external_texture(path):
	var image = Image.new()
	image.load(path)

	var image_texture = ImageTexture.new()
	image_texture.set_image(image)

	return image_texture

func set_up_slots():
	scaled_text_height = default_text_height * Settings.get_setting(Settings.CFG_SCALER)

	var outline_thickness = Settings.get_setting(Settings.CFG_VISUAL_LETTER_OUTLINES)
	left_bound = Settings.get_setting(Settings.CFG_LEFT_MARGIN)
	title = $SlotHolder/Title
	title.size.x = Global.window_width - left_bound * 2
	title.size.y = 0
	title.horizontal_alignment = Settings.get_setting(Settings.CFG_VISUAL_TITLE_ORIENTATION)
	title.add_theme_constant_override("outline_size", outline_thickness)
	title.position.y = Settings.get_setting(Settings.CFG_TOP_MARGIN)
	title.position.x = 0
	title.uppercase = true
	title.set("theme_override_font_sizes/font_size", scaled_text_height * Settings.get_setting(Settings.CFG_TITLE_SIZE))
	title.size.y = 0
	if title_can_be_blank and title.text == "":
		title.position.y -= title.size.y

	var slot_start = title.position.y + (title.size.y * title.scale.y) - scaled_text_height / 2.0

	#print("TITLE TEXT: " + title.text + "TITLE SIZE: " + str(title.size.y * title.scale.y) + " SLOT START: " + str(slot_start))

	message = $SlotHolder/Body.duplicate()
	add_child.call_deferred(message)
	message.position.y = Global.window_height - text_height
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.size.x = Global.window_width * Settings.get_setting(Settings.CFG_TEXT_LENGTH)
	message.position.x = Global.window_width - 2.0
	message.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	message.set("theme_override_font_sizes/font_size", scaled_text_height / 2.0)
	$Pixel.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
	$Pixel.scale = Vector2(16 * Settings.get_setting(Settings.CFG_SCALER), 16 * Settings.get_setting(Settings.CFG_SCALER))
	$Pixel.visible = false

	for i in range(visible_slots.size()):
		var slot = visible_slots[i]
		slot.queue_free()
		#fav_indicators[i].queue_free()
	visible_slots.clear()
	fav_indicators.clear()

	var body_alignment = Settings.get_setting(Settings.CFG_VISUAL_BODY_ORIENTATION)
	for i in range(1, (Global.window_height - title.size.y) / (scaled_text_height / 2.0) + 1):
		var new_slot: Label = message.duplicate()
		slot_offset = left_bound

		new_slot.horizontal_alignment = body_alignment
		message.set("theme_override_font_sizes/font_size", scaled_text_height / 2.0)
		slot_holder.add_child.call_deferred(new_slot)
		visible_slots.append(new_slot)
		new_slot.add_theme_constant_override("outline_size", outline_thickness)
		new_slot.position.y = (slot_start) + i * (scaled_text_height * 0.5)
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

	message.visible = false
	var custom_font = Settings.get_setting(Settings.CFG_FONT)
	if custom_font != null and ResourceLoader.exists(custom_font):
		font = ResourceLoader.load(custom_font)
	refresh_fonts()

func refresh_alias(system="COMMON"):
	if root_path != null and FileAccess.file_exists(root_path + "/" + Global.PATH_CONFIG + "/" + system + "/alias.json"):
		ALIAS_MAP = JSON.parse_string(FileAccess.get_file_as_string(root_path + "/" + Global.PATH_CONFIG + "/" + system + "/alias.json"))
		set_active_alias_map(ALIAS_MAP)

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

func cycle_options(cfg_key, options_list):
	print("SETTING OPTION " + cfg_key + " with list " + str(options_list))
	if Settings.get_setting(cfg_key) not in options_list:
		Settings.store(cfg_key, options_list[0])
		return
	for i in range(0, options_list.size()):
		var opt = options_list[i]
		var next = i+1
		if i == options_list.size() - 1:
			next = 0
		if Settings.get_setting(cfg_key) == opt:
			Settings.store(cfg_key, options_list[next])
			break

func cycle_sizes():
	cycle_options(Settings.CFG_SCALER, [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
	set_up_slots()
	show_options(scroll_offset)
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	highlight_selection(option_selection)
	refresh_art()

func cycle_cover_sizes():
	cycle_options(Settings.CFG_VISUAL_COVER_SIZE, [Vector2.ZERO, Vector2(0.2, 0.3), Vector2(0.4, 0.6), Vector2(0.5, 0.8)])
	set_up_slots()
	refresh_art()
	show_options(scroll_offset)
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	highlight_selection(option_selection)

func cycle_drop_shadow_locations():
	cycle_options(Settings.CFG_VISUAL_DROP_SHOW, [Vector2.ZERO, Vector2(32, 32), Vector2(-32, 32), Vector2(-32, -32), Vector2(32, -32)])
	refresh_art()

func cycle_border_thickness():
	cycle_options(Settings.CFG_VISUAL_BORDER, [Vector2.ZERO, Vector2(4, 4), Vector2(8, 8), Vector2(16, 16), Vector2(32, 32), Vector2(64, 64)])
	if Navigator.current_screen == "system_browser" and Settings.get_setting(Settings.CFG_VISUAL_BORDER) == Vector2.ZERO:
		Settings.store(Settings.CFG_VISUAL_SYSTEM_BORDER, false)
	refresh_art()

func cycle_title_allignment():
	cycle_options(Settings.CFG_VISUAL_TITLE_ORIENTATION, [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT])
	set_up_slots()

func cycle_body_allignment():
	cycle_options(Settings.CFG_VISUAL_BODY_ORIENTATION, [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT])
	set_up_slots()
	set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))

func cycle_art_alignment():
	cycle_options(Settings.CFG_VISUAL_ART_ORIENTATION, [0.25, 0.5, 0.75])
	refresh_art()

func cycle_art_opacity():
	cycle_options(Settings.CFG_VISUAL_COVER_OPACITY, [0.1, 0.25, 0.5, 0.75, 0.9, 1.0])
	refresh_art()

func cycle_left_margin():
	cycle_options(Settings.CFG_LEFT_MARGIN, [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0])
	set_up_slots()

func cycle_top_margin():
	cycle_options(Settings.CFG_TOP_MARGIN, [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0])
	set_up_slots()

func cycle_title_size():
	cycle_options(Settings.CFG_TITLE_SIZE, [0.1, 0.25, 0.5, 0.75, 1.0])
	set_up_slots()

func cycle_system_title():
	print("HERE")
	cycle_options(Settings.CFG_SYSTEM_TITLE, ["SYSTEMS", "", "PLAIN LAUNCHER", "MAIN", "ALL"])
	set_up_slots()

func cycle_line_length():
	cycle_options(Settings.CFG_TEXT_LENGTH, [0.25, 0.4, 0.5, 0.6, 0.75, 1.0])
	set_up_slots()


func toggle_text_outline():
	var outline_thickness = 8
	if title.get_theme_constant("outline_size") != 0:
		outline_thickness = 0
	for child in slot_holder.get_children():
		child.add_theme_constant_override("outline_size", outline_thickness)
	Settings.store(Settings.CFG_VISUAL_LETTER_OUTLINES, outline_thickness)

func show_message(msg, priority=false):
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
	print("showing message: " + msg)
	message.text = ALIAS_MAP.get(msg, msg)
	message.uppercase = Settings.get_setting(Settings.CFG_CAPS_LOCK)
	message.visible = true
	message.modulate.a = 1.0

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
		system_config_dir.remove("config.json")
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
	return Navigator.current_screen == "system_browser" or Navigator.current_screen == "game_browser" or Navigator.current_screen == "android_apps"  or Navigator.current_screen == "scraper"

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
			option_list.append(option.new_option(custom_option))
		for i in range(0, min(visible_slots.size(), option_list.size())):
			set_slot(i, option_list[i].clean)
		restore_position()
		highlight_selection()

func refresh_art(image_path=Global.get_image_path(), alt=false):
	if !FileAccess.file_exists(image_path) and img_texture_override == null:
		cover_art.texture = null
		cover.visible = false
		if not alt and Global.alt_art_path != "":
			var altPath = Global.alt_art_path + "/" + Global.get_selected().filename.get_basename() + ".png"
			return refresh_art(altPath, true)
		return
	var art_file = FileAccess.open(image_path, FileAccess.READ)
	cover.modulate.a = Settings.get_setting(Settings.CFG_VISUAL_COVER_OPACITY)
	cover.position.y = window_height * Settings.get_setting(Settings.CFG_VISUAL_ART_POSITION_Y)
	cover.position.x = window_width * Settings.get_setting(Settings.CFG_VISUAL_ART_POSITION_X)
	if Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE) != Vector2.ZERO:
		if img_texture_override != null:
			cover_art.texture = img_texture_override
		else:
			var image = Image.load_from_file(image_path)
			if image == null:
				cover.visible = false
				return
			image.convert(Image.FORMAT_RGBA8)
			cover_art.texture = ImageTexture.create_from_image(image)
		var scale_ratio_x = ((Global.window_width) * Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE).x) / (cover_art.texture.get_size().x + Settings.get_setting(Settings.CFG_VISUAL_BORDER).x)
		var scale_ratio_y = (Global.window_height * Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE).y) / (cover_art.texture.get_size().y + Settings.get_setting(Settings.CFG_VISUAL_BORDER).y)
		if Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE).x == 1.0:
			scale_ratio_x = Global.window_width / cover_art.texture.get_size().x
			scale_ratio_y = Global.window_height / cover_art.texture.get_size().y
		if Settings.get_setting(Settings.CFG_VISUAL_COVER_SIZE).x > 1.0:
			scale_ratio_x = 2 * Global.window_width / cover_art.texture.get_size().x
			scale_ratio_y = 2 * Global.window_height / cover_art.texture.get_size().y
		var scale_ratio = min(scale_ratio_x, scale_ratio_y)

		cover_art.scale = Vector2(scale_ratio, scale_ratio)
		cover.z_index = 4000

		if Settings.get_setting(Settings.CFG_VISUAL_BORDER) != Vector2.ZERO:
			border.visible = true
			border.scale = cover_art.texture.get_size() * cover_art.scale + Settings.get_setting(Settings.CFG_VISUAL_BORDER)
			border.modulate = Settings.get_setting(Settings.CFG_FG_COLOR)
		else:
			border.visible = false
		if !Settings.get_setting(Settings.CFG_VISUAL_SYSTEM_BORDER) and (Navigator.current_screen == "system_browser" or Navigator.current_screen == "special"):
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
	else:
		cover_art.texture = null
		cover.visible = false


func highlight_selection(next_selection=option_selection):
	slot_holder.position.x = 0
	for i in range(0, visible_slots.size()):
		var slot = visible_slots[i]
		slot.modulate.a = 0.3
		var list_idx = scroll_offset + i
		"""
		var slot_is_fav = list_idx < option_list.size() and favorites_list.has(option_list[list_idx].absolute_path)
		var slot_is_checked = list_idx < option_list.size() and option_list[list_idx].clean in selector_active
		if slot_is_fav or slot_is_checked:
			slot.text = "•" + slot.text
		"""
		slot.size = slot_size
		if scroll_offset + i < option_list.size() and HIDDEN_LIST.get(option_list[scroll_offset + i].absolute_path, false):
			slot.modulate.a = 0.1
		slot.scale = Vector2(1.0, 1.0)
	option_selection = next_selection
	if option_list.size() < visible_slots.size():
		scroll_offset = 0
	elif option_list.is_empty():
		scroll_offset = 0
		return
	elif visible_slots.is_empty():
		scroll_offset = 0
		return
	elif option_selection - scroll_offset >= visible_slots.size():
		print("OPTION SELECTION: " + str(option_selection) + " SCROLL OFFSET " + str(scroll_offset) + " VISIBLE_SLOT SIZE " + str(visible_slots.size()))
		scroll_offset = option_selection - visible_slots.size() + 1
		print("NEW SCROLL OFFSET " + str(scroll_offset))
		show_options(scroll_offset)
		highlight_selection()
		return
	if option_selection - scroll_offset < visible_slots.size():
		visible_slots[option_selection-scroll_offset].modulate.a = 1.0
		#fav_indicators[option_selection-scroll_offset].modulate.a = 1.0
	else:
		show_options(option_selection - visible_slots.size())
	if post_draw_callback != null:
		post_draw_callback.call()

func show_options(offset=0):
	if offset == null:
		offset = 0
		scroll_offset = 0
	if option_list.size() < visible_slots.size():
		scroll_offset = 0
		offset = 0
	if option_selection - scroll_offset > visible_slots.size():
		scroll_offset = option_selection - visible_slots.size() + 1
		offset = scroll_offset
	# Clamp so the last page is always full — no empty slots at the bottom
	var max_offset = max(0, option_list.size() - visible_slots.size())
	if offset > max_offset:
		offset = max_offset
		scroll_offset = offset
	for i in range(0, Global.visible_slots.size()):
		if i+offset >= option_list.size():
			set_slot(i, "")
			#fav_indicators[i].visible = false
			continue
		set_slot(i, option_list[i+offset].clean)
		var is_fav = favorites_list.has(option_list[i+offset].absolute_path)
		var slot_is_checked = option_list[i+offset].clean in selector_active
		if is_fav or slot_is_checked:
			visible_slots[i].text = "•" + visible_slots[i].text
		visible_slots[i].position.x = slot_offset
	if post_draw_callback != null:
		post_draw_callback.call()

func _favorites_json_path() -> String:
	return root_path + PATH_GAMES + "FAVORITES/favorites.json"

func _load_favorites_json() -> Array:
	var path = _favorites_json_path()
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func _save_favorites_json(entries: Array):
	var fav_dir_path = root_path + PATH_GAMES + "FAVORITES"
	if not DirAccess.dir_exists_absolute(fav_dir_path):
		DirAccess.make_dir_recursive_absolute(fav_dir_path)
	var f = FileAccess.open(_favorites_json_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(entries, "\t"))
		f.close()

func get_favorites_entries() -> Array:
	return _load_favorites_json()

func populate_favorites():
	favorites_list.clear()
	for entry in _load_favorites_json():
		favorites_list[entry.get("path", "")] = true
	Global.show_options(Global.scroll_offset)

func add_favorite(item):
	if item.favorite_dir or Global.favorites_list.has(item.absolute_path):
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
	if item.favorite_dir or Global.favorites_list.has(item.absolute_path):
		remove_favorite(item)
		Global.show_message("Removed from FAVORITES", true)
	else:
		add_favorite(item)
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

func list_multiple_paths_combined(paths):
	for path in paths:
		var dir = DirAccess.open(path)
		if dir == null:
			print("FAILED TO ACCESS " + path)
			continue
		list_directory_contents(dir, false, [], false, false)
	Global.option_list.sort_custom(func(a,b): return a.filename.to_lower() < b.filename.to_lower())
	restore_position()

func list_directory_contents(directory: DirAccess, dirs_only=true, special=[], skip_empty_dirs=false, refresh_at_end=true):
	if directory == null:
		return
	print("LIST CONTENTS " + directory.get_current_dir() + " DIRS_ONLY: " + str(dirs_only))
	var file_names = []
	var system = ""
	if dirs_only:
		directory.list_dir_begin()
		current_directory = directory.get_current_dir()
		var file_name = directory.get_next()
		while file_name != "":
			if special.has(file_name):
				pass
			elif dirs_only:
				if directory.dir_exists(file_name):
					if skip_empty_dirs and directory.get_files_at(directory.get_current_dir() + "/" + file_name).is_empty() and directory.get_directories_at(directory.get_current_dir() + "/" + file_name).is_empty():
						print("Skipping empty directory " + directory.get_current_dir() + "/" + file_name)
					else:
						file_names.append(file_name)
			else:
				if not directory.dir_exists(file_name):
					file_names.append(file_name)
			file_name = directory.get_next()
		directory.list_dir_end()
		file_names.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	else:
		file_names = directory.get_files()
		system = Global.subscreen
	var unique_paths = get_system_unique_paths()
	for path in unique_paths.keys():
		if FileAccess.file_exists(directory.get_current_dir() + "/" + path):
			file_names.append(path)
			ALIAS_MAP[clean_regex.sub(path.get_basename(), "", true)] = unique_paths[path]
	for special_file in special:
		file_names.push_front(special_file)
	for file in file_names:
		var opt = OPTIONS_MAKER.instantiate()
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
		if system == "FAVORITES":
			opt.favorite_dir = true
			use_system = file.split("]")[0].replace("[", "")
		opt.system = use_system
		if populate_filter != null:
			var populate_filter_callback: Callable = populate_filter
			if populate_filter_callback.call(opt):
				continue
		if filter_out_hidden(opt):
			continue
		Global.option_list.append(opt)
	option_selection = 0
	if refresh_at_end:
		restore_position()
		highlight_selection()

func move_down():
	if not can_scroll:
		return
	if option_selection >= option_list.size() - 1:
		scroll_offset = 0
		option_selection = -1
		vibrate(50)
		show_options(0)
	elif option_selection >= visible_slots.size() - 1:
		if option_selection == scroll_offset + visible_slots.size()-1:
			scroll_offset += 1
		show_options(scroll_offset)
	if confirm_hold_time != null:
		confirm_hold_time = Time.get_ticks_msec()
	highlight_selection(option_selection+1)

func move_up():
	if not can_scroll:
		return
	if option_selection <= 0:
		if option_list.size() >= visible_slots.size():
			scroll_offset = option_list.size() - visible_slots.size()
			show_options(scroll_offset)
		option_selection = option_list.size()
		vibrate(50)
	else:
		if scroll_offset > 0:
			if option_selection == scroll_offset:
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
	if not FileAccess.file_exists(options_path):
		return {}
	var options_string = FileAccess.get_file_as_string(options_path)
	if options_string == null or options_string == "":
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(options_path))

func get_system_unique_paths(system_for_settings=Global.subscreen):
	var uniques_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/unique_paths.json"
	print("GET UNIQUE PATHS AT " + uniques_path)
	if not FileAccess.file_exists(uniques_path):
		return {}
	var uniques_string = FileAccess.get_file_as_string(uniques_path)
	if uniques_string == null or uniques_string == "":
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(uniques_path))

func get_systemwide_settings(for_system):
	var current_settings_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + for_system + "/config.json"
	var current_settings = JSON.parse_string(FileAccess.get_file_as_string(current_settings_path))
	if current_settings == null:
		return build_system_settings_from_options(for_system)
	return current_settings

func get_system_settings(system_for_settings=Global.subscreen):
	var system_settings = {}
	var current_settings_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/config.json"

	if Global.special_item != null and !Global.special_item.is_dir:
		var game_settings_path = Global.root_path + "/" + Global.PATH_CONFIG + "/" + system_for_settings + "/" + Global.special_item.clean + ".json"
		if FileAccess.file_exists(game_settings_path) and not JSON.parse_string(FileAccess.get_file_as_string(game_settings_path)).is_empty():
			current_settings_path = game_settings_path
	if system_for_settings == "" or system_for_settings == null:
		return {}
	print("GET SETTINGS " + current_settings_path)
	if FileAccess.file_exists(current_settings_path):
		system_settings = JSON.parse_string(FileAccess.get_file_as_string(current_settings_path))
	else:
		system_settings = build_system_settings_from_options(system_for_settings)
	return system_settings

func get_paths_filepath(prefix=""):
	var system = Global.subscreen
	if Global.special_item != null:
		system = Global.special_item.system
	return Global.root_path + Global.PATH_CONFIG + system + "/" + prefix + "paths.txt"

func get_compat_paths_filepath():
	var system = Global.subscreen
	if Global.special_item != null:
		system = Global.special_item.system
	return Global.root_path + Global.PATH_CONFIG + system + "/compatibility_paths.txt"

func store_additional_art_path(path):
	var paths_file = get_paths_filepath("art_")
	var paths_file_write = FileAccess.open(paths_file, FileAccess.WRITE)
	print("STORE ADDITIONAL ART PATHS " + str(path) + " TO " + paths_file)
	paths_file_write.store_string(path)

func get_additional_art_path():
	var paths_file = get_paths_filepath("art_")
	if FileAccess.file_exists(paths_file):
		return FileAccess.get_file_as_string(paths_file)
	return ""

func store_additional_paths(paths):
	var paths_file = get_paths_filepath()
	var paths_file_write = FileAccess.open(paths_file, FileAccess.WRITE)
	print("STORE ADDITIONAL PATHS " + str(paths) + " TO " + paths_file)
	paths_file_write.store_string("\n".join(paths))

func remove_additional_path(path):
	var paths_file = get_paths_filepath()
	if not FileAccess.file_exists(paths_file):
		return
	var paths: Array = FileAccess.get_file_as_string(paths_file).split("\n")
	paths.erase(path)
	var paths_file_write = FileAccess.open(paths_file, FileAccess.WRITE)
	paths_file_write.store_string("\n".join(paths))

func get_additional_paths():
	var paths_file = get_paths_filepath()
	var compat_file = get_compat_paths_filepath()
	var paths = []
	if FileAccess.file_exists(paths_file):
		for path in FileAccess.get_file_as_string(paths_file).split("\n"):
			if path != "":
				paths.append(path)
	if FileAccess.file_exists(compat_file) and OS.get_name() == "Android":
		var external_path = AndroidInterface.get_external_storage_path()
		print(external_path)
		if external_path != null:
			var compat_paths = FileAccess.get_file_as_string(compat_file).split("\n")
			for path in compat_paths:
				if path != null and path != "":
					paths.append(external_path + path)
	print("GOT ADDITIONAL PATHS " + str(paths) + " FROM " + paths_file)
	return paths

func get_selected():
	if option_list.is_empty() or option_selection > option_list.size():
		return null_option
	return option_list[option_selection]

func get_stored_scroll_offset():
	if Navigator.current_screen == "file_browser":
		return scroll_offsets.get(message.text.to_lower())
	else:
		return scroll_offsets.get(title.text.to_lower())

func get_stored_cursor_position():
	if Navigator.current_screen == "file_browser":
		return cursor_positions.get(message.text.to_lower())
	else:
		return cursor_positions.get(title.text.to_lower())

func store_position():
	if Navigator.current_screen == "file_browser":
		cursor_positions[message.text.to_lower()] = option_selection
		cursor_indices[message.text.to_lower()] = option_selection
		scroll_offsets[message.text.to_lower()] = scroll_offset
	else:
		cursor_positions[title.text.to_lower()] = Global.get_selected().absolute_path
		cursor_indices[title.text.to_lower()] = option_selection
		scroll_offsets[title.text.to_lower()] = scroll_offset

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
			scroll_offset = max(0, option_selection - visible_slots.size())
		if option_selection == option_list.size():
			# Path match failed — fall back to stored numeric index
			var title_key = message.text.to_lower() if Navigator.current_screen == "file_browser" else title.text.to_lower()
			var stored_idx = cursor_indices.get(title_key, 0)
			option_selection = min(stored_idx, option_list.size() - 1)
			var stored_scroll = scroll_offsets.get(title_key, 0)
			scroll_offset = min(stored_scroll, max(0, option_list.size() - visible_slots.size()))

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
	return Navigator.current_screen == "color_picker" or Navigator.current_screen == "art_placer" or disable_scroll

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if message == null:
		return
	if message.modulate.a > 0:
		message.modulate.a -= delta / 2.0
	elif !message_queue.is_empty():
		show_message(message_queue.pop_front())
	if Input.is_action_just_pressed("select") or Input.is_action_just_pressed("back"):
		vibrate(50)
	if !cursor_locked():
		if Global.up_just_pressed():
			move_up()
			held_time = Time.get_ticks_msec() + 500
			on_scroll()
		if Global.up_held():
			if Time.get_ticks_msec() - held_time > 50:
				move_up()
				held_time = Time.get_ticks_msec()
				on_scroll()
		if Global.down_just_pressed():
			move_down()
			held_time = Time.get_ticks_msec() + 500
			on_scroll()
		if Global.down_held():
			if Time.get_ticks_msec() - held_time > 50:
				move_down()
				held_time = Time.get_ticks_msec()
				on_scroll()
		if Global.right_just_pressed():
			for i in range(0, min(5, option_list.size()-option_selection)):
				if option_selection < option_list.size()-1:
					move_down()
			held_time = Time.get_ticks_msec() + 500
			on_scroll()
		if Global.right_held():
			if Time.get_ticks_msec() - held_time > 20:
				for i in range(0, min(5, option_list.size()-option_selection)):
					if option_selection < option_list.size()-1:
						move_down()
				held_time = Time.get_ticks_msec()
				on_scroll()
		if Global.left_just_pressed():
			for i in range(0, 5):
				if option_selection > 0:
					move_up()
			held_time = Time.get_ticks_msec() + 500
			on_scroll()
		if Global.left_held():
			if Time.get_ticks_msec() - held_time > 20:
				for i in range(0, 5):
					if option_selection > 0:
						move_up()
				held_time = Time.get_ticks_msec()
				on_scroll()
		if Input.is_action_just_pressed("special"):
			Navigator.go_to_special()

func _physics_process(delta):
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
				elif flick_angle < - PI / 4.0 and flick_angle > -3 * PI / 4.0:
					vibrate(30)
					move_up()
					on_scroll()
		tilt_ratio = new_tilt_ratio

	if cursor_locked():
		return

	if (confirm_swapped and Input.is_action_just_pressed("back")) or (!confirm_swapped and Input.is_action_just_pressed("select")):
		confirm_hold_time = Time.get_ticks_msec()
	if !confirm_held() and touch_position == null and confirm_hold_time != null:
		if pending_special:
			Navigator.go_to_special()
			return
		confirm_hold_time = null

	if option_selection - scroll_offset >= visible_slots.size():
		print("OPTION SELECTION: " + str(option_selection) + " SCROLL OFFSET " + str(scroll_offset) + " VISIBLE_SLOT SIZE " + str(visible_slots.size()))
		scroll_offset = option_selection - visible_slots.size() + 1
	if visible_slots.is_empty():
		return
	if option_selection == 0 and scroll_offset != 0:
		scroll_offset = 0
	var curr_slot = visible_slots[option_selection - scroll_offset]
	if special_allowed() and ((touch_position == null and control_tilt.x > 0.5) or (confirm_hold_time != null and Time.get_ticks_msec() - confirm_hold_time > 500)):
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
	else:
		pending_special = false
	if pending_special and ((confirm_swapped and Input.is_action_just_released("back")) or (!confirm_swapped and Input.is_action_just_released("select"))):
		touch_check_time = Time.get_ticks_msec() + 1000
		Navigator.go_to_special()
		return

	if touch_position == null:
		if control_tilt.x < -0.5:
			if title.position.x > 0:
				title.position.x = lerp(float(title.position.x), 0.0, 0.3)
				if title.position.x > left_bound / 2.0:
					pending_back = false
				else:
					if !pending_back:
						vibrate(100)
					pending_back = true
		elif title.position.x < left_bound - 1:
			title.position.x = lerp(float(title.position.x), left_bound, 0.2)
		else:
			title.position.x = left_bound
			pending_back = false
		if pending_back and ((confirm_swapped and Input.is_action_just_released("back") or !confirm_swapped and Input.is_action_just_released("select"))):
			touch_check_time = Time.get_ticks_msec() + 1000
			press_back()
			return

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
			touch_momentum *= 0.88
			if abs(touch_momentum) < 1.0:
				touch_momentum = 0.0
				touch_scroll_accum = 0.0
		if Time.get_ticks_msec() > touch_check_time:
			if not pending_back and not pending_special:
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
					touch_check_time = Time.get_ticks_msec() + tilt_ratio * 200

###############################################################
#
# Controller stuff
#
###############################################################
func vibrate(duration):
	if !Settings.get_setting(Settings.CFG_VIBRATE):
		return
	Input.vibrate_handheld(duration)

func swap_confirm_key():
	confirm_swapped = !confirm_swapped
	Settings.store(Settings.CFG_CONFIRM_SWAP, confirm_swapped)

func confirm_pressed():
	if pending_special or pending_back:
		return false
	if waiting_for_confirm_release:
		if confirm_held():
			return false
		waiting_for_confirm_release = false
		return false
	if confirm_swapped:
		return Input.is_action_just_released("back")
	return Input.is_action_just_released("select")

func confirm_held():
	if confirm_swapped:
		return Input.is_action_pressed("back")
	return Input.is_action_pressed("select")

func back_pressed():
	if confirm_swapped:
		return Input.is_action_just_pressed("select")
	return Input.is_action_just_pressed("back")

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
	return false

func left_held():
	if Input.is_action_pressed("left"):
		return true
	return false

func right_just_pressed():
	if Input.is_action_just_pressed("right"):
		return true
	return false

func right_held():
	if Input.is_action_pressed("right"):
		return true
	return false

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

func get_image_path(selected=Global.get_selected()):
	var system_in_question = selected.system
	var game_title = selected.filename.get_basename()
	if game_title == system_in_question:
		if not Settings.get_setting(Settings.CFG_VISUAL_BUILTIN_SYSTEM_ART):
			return str(Global.root_path + Global.PATH_IMAGES + system_in_question + "_custom.png").replace("//", "/")
		return str(Global.root_path + Global.PATH_IMAGES + system_in_question + ".png").replace("//", "/")
	return str(str(Global.root_path) + str(Global.PATH_IMAGES) + str(system_in_question) + "/" + str(game_title) + ".png").replace("//", "/")

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


func _input(event):
	if !touch_enabled:
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
			confirm_hold_time = Time.get_ticks_msec()
		else:
			if touch_position == null or touch_start_position == null:
				touch_position = null
				touch_start_position = null
				confirm_hold_time = null
				return
			var diff = touch_position - touch_start_position
			var elapsed = Time.get_ticks_msec() - touch_start_time
			confirm_hold_time = null
			if touch_is_scrolling:
				touch_momentum = touch_velocity
			elif diff.x < -window_width / 5.0 and abs(diff.x) > abs(diff.y) * 1.5:
				press_back()
			elif pending_special:
				Navigator.go_to_special()
			elif elapsed < 400 and diff.length() < text_height:
				press_confirm()
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
			touch_scroll_accum += dy * scroll_dir * (1.0 + abs(dy) / text_height)
			while touch_scroll_accum > text_height:
				move_down()
				touch_scroll_accum -= text_height
				on_scroll()
			while touch_scroll_accum < -text_height:
				move_up()
				touch_scroll_accum += text_height
				on_scroll()

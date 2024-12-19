extends Node2D

var window_height = 0
var window_width = 0
var title_offset = 0

var root_path = ""

const SETTINGS_FILE = "user://settings.bin"
var global_settings = null

const CFG_ROOT = "ROOT"
const CFG_CONFIRM_SWAP = "SWAP"
const CFG_BG_COLOR = "COLOR_BG"
const CFG_FG_COLOR = "COLOR_FG"
const CFG_CAPS_LOCK = "CAPS_LOCK"
const CFG_SCALER = "SCALER"
const CFG_VIBRATE = "VIBRATE"
const CFG_FONT = "FONT"
const CFG_SHOW_ART = "SHOW_ART"
const CFG_VISUAL_BORDER = "VISUAL_BORDER"
const CFG_VISUAL_SYSTEM_BORDER = "VISUAL_SYSTEM_BORDER_ENABLED"
const CFG_VISUAL_DROP_SHOW = "VISUAL_DROP_SHADOW"
const CFG_VISUAL_COVER_SIZE = "VISUAL_COVER_SIZE"
const CFG_VISUAL_COVER_OPACITY = "VISUAL_COVER_OPACITY"
const CFG_VISUAL_TITLE_ORIENTATION = "VISUAL_TITLE_ORIENTATION"
const CFG_VISUAL_BODY_ORIENTATION = "VISUAL_BODY_ORIENTATION"
const CFG_VISUAL_ART_ORIENTATION = "VISUAL_ART_ORIENTATION"
const CFG_VISUAL_ART_POSITION_X = "VISUAL_ART_POS_X"
const CFG_VISUAL_ART_POSITION_Y = "VISUAL_ART_POS_Y"
const CFG_VISUAL_LETTER_OUTLINES = "VISUAL_LETTER_OUTLINES"
const CFG_TOUCH_VISIBLE = "TOUCH_VISIBLE"
const CFG_LEFT_MARGIN = "TEXT_LEFT_MARGIN"
const CFG_TOP_MARGIN = "TEXT_TOP_MARGIN"
const CFG_TEXT_LENGTH = "TEXT_LENGTH"

var DEFAULT_SETTINGS = {
	CFG_CONFIRM_SWAP: false,
	CFG_BG_COLOR: Color.BLACK,
	CFG_FG_COLOR: Color("#f5f7fa"),
	CFG_CAPS_LOCK: false,
	CFG_SCALER: 0.25,
	CFG_VIBRATE: true,
	CFG_VISUAL_BORDER: Vector2(8, 8),
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
	CFG_TOUCH_VISIBLE: true,
	CFG_LEFT_MARGIN: 16.0,
	CFG_TOP_MARGIN: 8.0,
	CFG_TEXT_LENGTH: 0.5,
}

const PATH_CONFIG = "/Config/"
const PATH_GAMES = "/Games/"
const PATH_IMAGES = "/Imgs/"

var option_list = []
var visible_slots = []
var option_selection = 0
var scroll_offset = 0

var current_component = null
var current_directory = ""
var previous_screen = ""
var current_screen = ""

var title: Label = null
var message: Label = null
@onready var fade = $FarFade
@onready var slot_holder = $SlotHolder
var message_queue = []
var cursor_positions = {}
var scroll_offsets = {}

var confirming = false

var default_text_height = 128
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

var held_time = -1
var frame = 0

const OPTIONS_MAKER = preload("res://option.tscn")
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
var previous_touch_position = null
var touch_start_time = -1
var touch_check_time = -1
var pending_special = false
var pending_back = false
var control_tilt: Vector2 = Vector2.ZERO
var tilt_ratio = 0
@onready var TOUCH_POINTS = $TouchPoints
@onready var TOUCH_START = $TouchPoints/TouchStart
@onready var TOUCH_CURRENT = $TouchPoints/TouchCurrent
@onready var TOUCH_BRIDGE = $TouchPoints/TouchBridge

var confirm_hold_time = null

# Component callbacks
var post_draw_callback = null
var post_scroll_callback = null
var on_leave_component = null
var populate_filter = null

var font = null

var free_version = false

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

# Called when the node enters the scene tree for the first time.
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
	root_path = get_setting(CFG_ROOT)
	if root_path != null and !DirAccess.dir_exists_absolute(root_path):
		root_path = null

	BACKDROP.modulate = get_setting(CFG_BG_COLOR)

	clean_regex = RegEx.new()
	clean_regex.compile("\\s*\\(.+\\)\\s*|\\s*\\[.+\\]\\s*|T.Eng+\\$|\\.nkit")

	normalize_regex = RegEx.new()
	normalize_regex.compile("[^a-z0-9]")

	get_tree().get_root().size_changed.connect(resize)

	set_up_slots()

	cover_art = Sprite2D.new()
	drop_shadow = cover_art.duplicate()
	drop_shadow.modulate = Color.BLACK
	border = $Pixel.duplicate()
	border.modulate = Global.get_setting(Global.CFG_BG_COLOR)
	#border.scale = Vector2(0.99, 0.99)
	#cover_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	#cover_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	cover.size = Vector2(Global.window_width * 0.25, Global.window_height * 0.75)
	cover.add_child.call_deferred(drop_shadow)
	cover.add_child.call_deferred(border)
	cover.add_child.call_deferred(cover_art)
	cover.position.y = window_height * get_setting(CFG_VISUAL_ART_POSITION_Y)
	cover.position.x = window_width * get_setting(CFG_VISUAL_ART_POSITION_X)

	var list_file_contents = get_list_file_contents()
	if not list_file_contents.has("hidden"):
		list_file_contents["hidden"] = []
	for item in list_file_contents.get("hidden", []):
		HIDDEN_LIST[item] = true

	if get_setting(CFG_CONFIRM_SWAP):
		Global.swap_confirm_key()

	OS.request_permissions()

	show_message("Welcome to PlainLauncher!")
	go_to_main()

func get_list_file_contents():
	if root_path == null:
		return {}
	var list_file = root_path + "/Config/COMMON/lists.json"
	if FileAccess.file_exists(list_file):
		var list_file_contents = JSON.parse_string(FileAccess.get_file_as_string(list_file))
		if list_file_contents != null:
			return list_file_contents
	return {}

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

	var scaled_text_height = default_text_height * get_setting(CFG_SCALER)

	var outline_thickness = get_setting(CFG_VISUAL_LETTER_OUTLINES)
	left_bound = get_setting(CFG_LEFT_MARGIN)
	title = $SlotHolder/Title
	title.size.x = Global.window_width - left_bound * 2
	title.size.y = 0
	title.horizontal_alignment = get_setting(CFG_VISUAL_TITLE_ORIENTATION)
	title.add_theme_constant_override("outline_size", outline_thickness)
	title.position.y = get_setting(CFG_TOP_MARGIN)
	title.position.x = left_bound
	title.uppercase = true
	title.set("theme_override_font_sizes/font_size", scaled_text_height)

	message = $SlotHolder/Body.duplicate()
	add_child.call_deferred(message)
	message.position.y = Global.window_height - text_height
	#message.size.x = Global.window_width / 2.0
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.size.x = Global.window_width * get_setting(CFG_TEXT_LENGTH)
	message.position.x = left_bound
	if get_setting(CFG_VISUAL_BODY_ORIENTATION) == HORIZONTAL_ALIGNMENT_RIGHT:
		message.position.x = -2 * left_bound
	message.modulate = get_setting(CFG_FG_COLOR)
	message.set("theme_override_font_sizes/font_size", scaled_text_height / 2.0)
	$Pixel.modulate = get_setting(CFG_FG_COLOR)
	$Pixel.scale = Vector2(16 * get_setting(CFG_SCALER), 16 * get_setting(CFG_SCALER))
	$Pixel.visible = false

	for i in range(visible_slots.size()):
		var slot = visible_slots[i]
		slot.queue_free()
		fav_indicators[i].queue_free()
	visible_slots.clear()
	fav_indicators.clear()

	var body_alignment = get_setting(CFG_VISUAL_BODY_ORIENTATION)
	for i in range(1, Global.window_height / (scaled_text_height * 0.5) -1):
		var new_slot: Label = message.duplicate()
		#new_slot.size.x = Global.window_width / 2.0
		slot_offset = left_bound

		new_slot.horizontal_alignment = body_alignment
		message.set("theme_override_font_sizes/font_size", scaled_text_height / 2.0)
		slot_holder.add_child.call_deferred(new_slot)
		visible_slots.append(new_slot)
		new_slot.add_theme_constant_override("outline_size", outline_thickness)
		new_slot.position.y = (title.position.y + scaled_text_height / 2.0) + i * (scaled_text_height * 0.5)
		var fav_indicator = $Pixel.duplicate()
		new_slot.add_child.call_deferred(fav_indicator)
		fav_indicator.position.x = -left_bound / 2.0
		if new_slot.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			fav_indicator.position.x = new_slot.size.x + left_bound / 2.0
		slot_size = new_slot.size
		fav_indicator.position.y = text_height * get_setting(CFG_SCALER) / 4.0
		fav_indicators.append(fav_indicator)

	message.visible = false
	var custom_font = get_setting(CFG_FONT)
	if custom_font != null and ResourceLoader.exists(custom_font):
		font = ResourceLoader.load(custom_font)
	refresh_fonts()
	#show_options(0)

func go_to_main():
	if not root_path:
		go_to("confirm_set")
	else:
		go_to("system_browser")

func refresh_alias(system="COMMON"):
	if root_path != null and FileAccess.file_exists(root_path + "/" + Global.PATH_CONFIG + "/" + system + "/alias.json"):
		ALIAS_MAP = JSON.parse_string(FileAccess.get_file_as_string(root_path + "/" + Global.PATH_CONFIG + "/" + system + "/alias.json"))
		if not ALIAS_MAP:
			ALIAS_MAP = {}

func refresh_fonts():
	if font == null:
		return
	title.add_theme_font_override("font", font)
	for slot in visible_slots:
		slot.add_theme_font_override("font", font)

func cycle_options(cfg_key, options_list):
	print("SETTING OPTION " + cfg_key + " with list " + str(options_list))
	if get_setting(cfg_key) not in options_list:
		store_setting(cfg_key, options_list[0])
		return
	for i in range(0, options_list.size()):
		var opt = options_list[i]
		var next = i+1
		if i == options_list.size() - 1:
			next = 0
		if get_setting(cfg_key) == opt:
			store_setting(cfg_key, options_list[next])
			break

func cycle_sizes():
	cycle_options(CFG_SCALER, [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
	set_up_slots()
	show_options(scroll_offset)
	set_all_text_color(get_setting(CFG_FG_COLOR))
	highlight_selection(option_selection)
	refresh_art()

func cycle_cover_sizes():
	cycle_options(CFG_VISUAL_COVER_SIZE, [Vector2.ZERO, Vector2(0.2, 0.3), Vector2(0.4, 0.6), Vector2(0.5, 0.8)])
	set_up_slots()
	refresh_art()
	show_options(scroll_offset)
	set_all_text_color(get_setting(CFG_FG_COLOR))
	highlight_selection(option_selection)

func cycle_drop_shadow_locations():
	cycle_options(CFG_VISUAL_DROP_SHOW, [Vector2.ZERO, Vector2(32, 32), Vector2(-32, 32), Vector2(-32, -32), Vector2(32, -32)])
	refresh_art()

func cycle_border_thickness():
	cycle_options(CFG_VISUAL_BORDER, [Vector2.ZERO, Vector2(4, 4), Vector2(8, 8), Vector2(16, 16), Vector2(32, 32), Vector2(64, 64)])
	if current_screen == "system_browser" and get_setting(CFG_VISUAL_BORDER) == Vector2.ZERO:
		store_setting(CFG_VISUAL_SYSTEM_BORDER, false)
	refresh_art()

func cycle_title_allignment():
	cycle_options(CFG_VISUAL_TITLE_ORIENTATION, [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT])
	set_up_slots()

func cycle_body_allignment():
	cycle_options(CFG_VISUAL_BODY_ORIENTATION, [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT])
	set_up_slots()
	set_all_text_color(get_setting(CFG_FG_COLOR))

func cycle_art_alignment():
	cycle_options(CFG_VISUAL_ART_ORIENTATION, [0.25, 0.5, 0.75])
	refresh_art()

func cycle_art_opacity():
	cycle_options(CFG_VISUAL_COVER_OPACITY, [0.1, 0.25, 0.5, 0.75, 0.9, 1.0])
	refresh_art()

func cycle_left_margin():
	cycle_options(CFG_LEFT_MARGIN, [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0])
	set_up_slots()

func cycle_top_margin():
	cycle_options(CFG_TOP_MARGIN, [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0])
	set_up_slots()

func cycle_line_length():
	cycle_options(CFG_TEXT_LENGTH, [0.25, 0.4, 0.5, 0.6, 0.75, 1.0])
	set_up_slots()

func toggle_touch_visible():
	store_setting(CFG_TOUCH_VISIBLE, !get_setting(CFG_TOUCH_VISIBLE))

func toggle_text_outline():
	var outline_thickness = 8
	if title.get_theme_constant("outline_size") != 0:
		outline_thickness = 0
	for child in slot_holder.get_children():
		child.add_theme_constant_override("outline_size", outline_thickness)
	store_setting(CFG_VISUAL_LETTER_OUTLINES, outline_thickness)

func show_message(msg, priority=false):
	if msg == "" or msg == null:
		message_queue.clear()
		message.text = ""
		return
	if priority:
		show_message("")
	if message.text != "" and message.modulate.a > 0.05:
		# Queue up multiple messages in a row
		message_queue.append(msg)
		return
	if message.text.to_lower() == msg.to_lower():
		return
	message.text = ALIAS_MAP.get(msg, msg)
	message.uppercase = get_setting(CFG_CAPS_LOCK)
	message.position.x = Global.window_width - text_height - (message.size.x * get_setting(CFG_SCALER))
	message.modulate.a = 1.0

func update_title(new_title):
	if no_alias:
		title.text = new_title
	else:
		title.text = ALIAS_MAP.get(new_title.to_lower(), new_title)
	#title.uppercase = capitalized

func set_slot(index, value):
	if no_alias:
		visible_slots[index].text = value
	else:
		visible_slots[index].text = ALIAS_MAP.get(value.to_lower(), value)
	visible_slots[index].uppercase = get_setting(CFG_CAPS_LOCK)

func get_setting(key):
	if global_settings == null:
		if !FileAccess.file_exists(SETTINGS_FILE):
			return DEFAULT_SETTINGS.get(key)
		var settings_file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		global_settings = settings_file.get_var()
		print("LOAD SETTINGS " + key + ": " + str(global_settings))
	var setting = global_settings.get(key, DEFAULT_SETTINGS.get(key))
	return setting

func store_setting(key, value):
	print("STORE SETTING " + key + ": " + str(value) + " TO " + SETTINGS_FILE)
	if global_settings == null:
		global_settings = {}
	global_settings[key] = value
	var update_settings: FileAccess = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	print(global_settings)
	update_settings.store_var(global_settings)
	update_settings.close()

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
	store_setting(CFG_ROOT, path)

func caps_lock():
	store_setting(CFG_CAPS_LOCK, !get_setting(CFG_CAPS_LOCK))
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
	return current_screen == "system_browser" or current_screen == "game_browser" or current_screen == "android_apps"

func go_to(target, new_message="", force=false):
	store_position()
	var refresh = target == current_screen
	if !force and !refresh and target == "special" and !special_allowed():
		print("Cannot go to special from " + current_screen)
		highlight_selection()
		return
	if on_leave_component != null:
		on_leave_component.call()
		on_leave_component = null
	BACKDROP.modulate = get_setting(CFG_BG_COLOR)
	set_all_text_color(get_setting(CFG_FG_COLOR))
	print("GOTO " + target)
	if current_screen != target:
		previous_screen = current_screen
	current_screen = target
	message.text = new_message
	populate_filter = null
	post_draw_callback = null
	post_scroll_callback = null
	no_alias = false
	img_texture_override = null
	get_tree().change_scene_to_file.call_deferred("res://" + target + ".tscn")

func back_to_previous_screen():
	go_to(previous_screen, "", true)

func clear_visible(title_text="", custom_options=[]):
	option_list.clear()
	scroll_offset = 0
	for i in range(visible_slots.size()):
		var visible_slot = visible_slots[i]
		visible_slot.text = ""
		fav_indicators[i].visible = false
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

func refresh_art(image_path=Global.get_image_path()):
	#var err = image.load(Global.root_path + PATH_IMGS + selected_system + "/" + Global.visible_slots[Global.selected].text + ".png")
	#print("Image load result: " + str(err))
	if !FileAccess.file_exists(image_path) and img_texture_override == null:
		cover_art.texture = null
		cover.visible = false
		return
	var art_file = FileAccess.open(image_path, FileAccess.READ)
	cover.modulate.a = get_setting(CFG_VISUAL_COVER_OPACITY)
	cover.position.y = window_height * get_setting(CFG_VISUAL_ART_POSITION_Y)
	cover.position.x = window_width * get_setting(CFG_VISUAL_ART_POSITION_X)
	if get_setting(CFG_VISUAL_COVER_SIZE) != Vector2.ZERO:
		if img_texture_override != null:
			cover_art.texture = img_texture_override
		else:
			var image = Image.load_from_file(image_path)
			if image == null:
				cover.visible = false
				return
			cover_art.texture = ImageTexture.create_from_image(image)
		#var effective_height_offset = title.size.y
		#if get_setting(CFG_SCALER) <= 0.5 or get_setting(CFG_VISUAL_COVER_SIZE).x >= 1.0:
			#effective_height_offset = 0
		#var effective_height = (Global.window_height - effective_height_offset) # height with title
		var scale_ratio_x = ((Global.window_width) * get_setting(CFG_VISUAL_COVER_SIZE).x) / (cover_art.texture.get_size().x + get_setting(CFG_VISUAL_BORDER).x)
		var scale_ratio_y = (Global.window_height * get_setting(CFG_VISUAL_COVER_SIZE).y) / (cover_art.texture.get_size().y + + get_setting(CFG_VISUAL_BORDER).y)
		if get_setting(CFG_VISUAL_COVER_SIZE).x == 1.0:
			scale_ratio_x = Global.window_width / cover_art.texture.get_size().x
			scale_ratio_y = Global.window_height / cover_art.texture.get_size().y
		if get_setting(CFG_VISUAL_COVER_SIZE).x > 1.0:
			scale_ratio_x = 2 * Global.window_width / cover_art.texture.get_size().x
			scale_ratio_y = 2 * Global.window_height / cover_art.texture.get_size().y
		var scale_ratio = min(scale_ratio_x, scale_ratio_y)

		cover_art.scale = Vector2(scale_ratio, scale_ratio)
		cover.z_index = 4000

		if get_setting(CFG_VISUAL_BORDER) != Vector2.ZERO:
			border.visible = true
			border.scale = cover_art.texture.get_size() * cover_art.scale + get_setting(CFG_VISUAL_BORDER)
			border.modulate = get_setting(CFG_FG_COLOR)
		else:
			border.visible = false
		if !get_setting(CFG_VISUAL_SYSTEM_BORDER) and (current_screen == "system_browser" or current_screen == "special"):
			border.visible = false

		if get_setting(CFG_VISUAL_DROP_SHOW) != Vector2.ZERO:
			drop_shadow.visible = true
			drop_shadow.modulate.v = 0
			drop_shadow.position = cover_art.position + get_setting(CFG_VISUAL_DROP_SHOW)
			if border.visible:
				drop_shadow.texture = border.texture
				drop_shadow.scale = border.scale
			else:
				drop_shadow.texture = cover_art.texture
				drop_shadow.scale = cover_art.scale
				drop_shadow.position = cover_art.position + get_setting(CFG_VISUAL_DROP_SHOW)
		else:
			drop_shadow.visible = false

		cover.visible = true
		#$BoxContainer.position = Vector2(Global.window_width * 0.75, Global.window_height / 2.0) - cover_art.size / 2.0
	else:
		cover_art.texture = null
		cover.visible = false


func highlight_selection(next_selection=option_selection):
	slot_holder.position.x = 0
	for i in range(0, visible_slots.size()):
		var slot = visible_slots[i]
		slot.modulate.a = 0.3
		slot.position.x = slot_offset
		slot.size = slot_size
		if scroll_offset + i < option_list.size() and HIDDEN_LIST.get(option_list[scroll_offset + i].absolute_path, false):
			slot.modulate.a = 0.1
		slot.scale = Vector2(1.0, 1.0)
	option_selection = next_selection
	#visible_slots[option_selection-scroll_offset].position.x = 64
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
		fav_indicators[option_selection-scroll_offset].modulate.a = 1.0
	else:
		show_options(option_selection - visible_slots.size())
	#visible_slots[option_selection-scroll_offset].scale = Vector2(1.2, 1.1)
	if post_draw_callback != null:
		post_draw_callback.call()

func show_options(offset=0):
	if option_list.size() < visible_slots.size():
		scroll_offset = 0
		offset = 0
	if option_selection - scroll_offset > visible_slots.size():
		scroll_offset = option_selection - visible_slots.size() + 1
		offset = scroll_offset
	for i in range(0, Global.visible_slots.size()):
		if i >= option_list.size():
			break
		set_slot(i, option_list[i+offset].clean)
		fav_indicators[i].visible = false
		if favorites_list.has(option_list[i+offset].absolute_path):
			fav_indicators[i].visible = true
	if post_draw_callback != null:
		post_draw_callback.call()

func populate_favorites():
	var fav_dir_path = Global.root_path + Global.PATH_GAMES + "FAVORITES"
	var fav_dir = DirAccess.open(fav_dir_path)
	if not fav_dir:
		return
	favorites_list.clear()
	fav_dir.list_dir_begin()
	var fave = fav_dir.get_next()
	while fave != "":
		var fave_contents = FileAccess.get_file_as_string(fav_dir.get_current_dir() + "/" + fave)
		favorites_list[fave_contents] = true
		fave = fav_dir.get_next()
	Global.show_options(Global.scroll_offset)

func favorite_name(system, selected_name):
	return "[" + system + "] " + selected_name + ".favorite"

func add_favorite():
	var item = Global.get_selected()
	if current_screen == "special":
		item = Global.special_item
	Global.populate_favorites()
	if item.favorite_dir or Global.favorites_list.has(item.absolute_path) or Global.subscreen == "favorites":
		return
	var fav_dir_path = Global.root_path + Global.PATH_GAMES + "FAVORITES"
	var fav_dir = DirAccess.open(fav_dir_path)
	if not fav_dir:
		DirAccess.make_dir_recursive_absolute(fav_dir_path)
		fav_dir = DirAccess.open(fav_dir_path)
	var selected = item.clean
	var fav_file = FileAccess.open(fav_dir.get_current_dir() + "/" + favorite_name(Global.subscreen, selected), FileAccess.WRITE)
	print("ADDING FAVORITE " + fav_file.get_path_absolute().get_basename())
	fav_file.store_string(item.absolute_path)
	fav_file.close()
	Global.populate_favorites()

func remove_favorite():
	Global.populate_favorites()
	var item = Global.get_selected()
	if current_screen == "special":
		item = Global.special_item
	var fav_dir_path = Global.root_path + Global.PATH_GAMES + "FAVORITES"
	var fav_dir = DirAccess.open(fav_dir_path)
	if not fav_dir:
		return
	var fav_system = Global.subscreen
	var removed_from_favorite_list = item.favorite_dir
	if removed_from_favorite_list:
		print("REMOVING FAVORITE " + item.filename)
		fav_dir.remove(item.filename)
	else:
		var fav_name = favorite_name(fav_system, item.clean)
		print("REMOVING FAVORITE " + fav_name)
		fav_dir.remove(fav_name)
	Global.store_position()
	Global.populate_favorites()
	if removed_from_favorite_list:
		Global.go_to_main()

func toggle_favorite():
	var item = Global.get_selected()
	if current_screen == "special":
		item = Global.special_item
	if item.clean == "":
		return
	if Global.subscreen == "FAVORITES" or Global.favorites_list.has(item.absolute_path):
		remove_favorite()
		Global.show_message("Removed from FAVORITES", true)
	else:
		add_favorite()
	highlight_selection(0)
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
	#print(get_list_file_contents())
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
	if current_screen == "settings":
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
		list_directory_contents(dir, false)
	Global.option_list.sort_custom(func(a,b): return a.filename < b.filename)
	restore_position()
	highlight_selection()

func list_directory_contents(directory: DirAccess, dirs_only=true, special=[], skip_empty_dirs=false):
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
					# Only include directories with something in them
					#var try_dir = DirAccess.open(current_directory + "/" + file_name)
					#if not try_dir.get_files().is_empty():
						#file_names_unsorted.append(file_name)
					else:
						file_names.append(file_name)
			else:
				if not directory.dir_exists(file_name):
					file_names.append(file_name)
			file_name = directory.get_next()
		directory.list_dir_end()
		file_names.sort()
	else:
		file_names = directory.get_files()
		system = Global.subscreen
	var unique_paths = get_system_unique_paths()
	for path in unique_paths.keys():
		if FileAccess.file_exists(directory.get_current_dir() + "/" + path):
			file_names.append(path)
			ALIAS_MAP[clean_regex.sub(path.get_basename(), "", true)] = unique_paths[path]
			#print("Adding unique path [" + clean_regex.sub(path.get_basename(), "") + "=" + unique_paths[path] + "]")
	for special_file in special:
		file_names.push_front(special_file)
	for file in file_names:
		var option = OPTIONS_MAKER.instantiate()
		option.filename = file
		option.absolute_path = directory.get_current_dir() + "/" + file
		if !clean_names.has(file):
			var cleaned = clean_regex.sub(file.get_basename(), "", true)
			clean_names[file] = ALIAS_MAP.get(cleaned, cleaned)
		option.clean = clean_names.get(file)

		var use_system = system
		if dirs_only:
			option.is_dir = true
			use_system = file
		if system == "FAVORITES":
			option.favorite_dir = true
			use_system = file.split("]")[0].replace("[", "")
		option.system = use_system
		if populate_filter != null:
			var populate_filter_callback: Callable = populate_filter
			if populate_filter_callback.call(option):
				continue
		if filter_out_hidden(option):
			continue
		Global.option_list.append(option)
	option_selection = 0
	restore_position()
	highlight_selection()

func move_down():
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
	# No settings saved, use the first option from the options lists
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
		return JSON.parse_string(FileAccess.get_file_as_string(current_settings_path))
	else:
		# No settings saved, use the first option from the options lists
		return build_system_settings_from_options()

func get_paths_filepath():
	var system = Global.subscreen
	if Global.special_item != null:
		system = Global.special_item.system
	return Global.root_path + Global.PATH_CONFIG + system + "/paths.txt"

func get_compat_paths_filepath():
	var system = Global.subscreen
	if Global.special_item != null:
		system = Global.special_item.system
	return Global.root_path + Global.PATH_CONFIG + system + "/compatibility_paths.txt"

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
	if current_screen == "file_browser":
		return scroll_offsets.get(message.text.to_lower())
	else:
		return scroll_offsets.get(title.text.to_lower())

func get_stored_cursor_position():
	if current_screen == "file_browser":
		return cursor_positions.get(message.text.to_lower())
	else:
		return cursor_positions.get(title.text.to_lower())

func store_position():
	if current_screen == "file_browser":
		cursor_positions[message.text.to_lower()] = option_selection
		scroll_offsets[message.text.to_lower()] = scroll_offset
	else:
		cursor_positions[title.text.to_lower()] = option_selection
		scroll_offsets[title.text.to_lower()] = scroll_offset

func restore_position():
	if get_stored_cursor_position() != null:
		option_selection = get_stored_cursor_position()
		scroll_offset = get_stored_scroll_offset()
		show_options(scroll_offset)
		if not option_list.is_empty() and option_selection >= option_list.size():
			option_selection = option_list.size() - 1
	else:
		show_options(0)
	highlight_selection(option_selection)

func filter_out_hidden(item):
	if show_hidden:
		return false
	return HIDDEN_LIST.get(item.absolute_path, false)

func go_to_special():
	special_item = Global.get_selected()
	if current_screen == "system_browser":
		Global.subscreen = special_item.filename
	go_to("special")
	pending_special = false

func on_scroll():
	if post_scroll_callback != null:
		post_scroll_callback.call()
	refresh_art()

func cursor_locked():
	return current_screen == "color_picker" or current_screen == "art_placer"

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
		if Input.is_action_just_pressed("shoulder_l"):
			#if !capitalized:
				#caps_lock()
			#else:
				#caps_lock()
				#cycle_sizes()
			cycle_sizes()
		if Input.is_action_just_pressed("shoulder_r"):
			#if !capitalized:
				#caps_lock()
			#else:
				#caps_lock()
				#cycle_sizes()
			if cover.visible or get_setting(CFG_VISUAL_COVER_SIZE) == Vector2.ZERO:
				cycle_cover_sizes()
		if Input.is_action_just_pressed("r3"):
			if cover.visible:
				cycle_drop_shadow_locations()
		if Input.is_action_just_pressed("l3"):
			if cover.visible:
				cycle_border_thickness()
		if Input.is_action_just_pressed("hide"):
			Global.store_position()
			toggle_hidden()
			go_to(current_screen)
			Global.restore_position()
		if Input.is_action_just_pressed("special"):
			go_to_special()
		if Input.is_action_just_pressed("body_orient"):
			cycle_body_allignment()
			Global.go_to(current_screen)
		if Input.is_action_just_pressed("title_orient"):
			cycle_title_allignment()
			Global.go_to(current_screen)
		if Input.is_action_just_pressed("art_orient"):
			cycle_art_alignment()
			Global.go_to(current_screen)

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
	else:
		var touch_diff = touch_position - touch_start_position
		var diff_y = (touch_position.y - touch_start_position.y)

		control_tilt = Vector2(touch_diff.x / (window_width / 8.0), touch_diff.y / (window_height / 8.0))
		tilt_ratio = max(0.1, (Vector2(window_width / 4.0, window_height / 4.0).length() - touch_diff.length()) / Vector2(window_width / 4.0, window_height / 4.0).length())
		TOUCH_CURRENT.global_position = touch_position
		TOUCH_BRIDGE.global_position = (TOUCH_CURRENT.global_position + TOUCH_START.global_position) / 2.0
		TOUCH_BRIDGE.scale = Vector2(touch_diff.length(), (tilt_ratio * TOUCH_START.scale.x))
		TOUCH_BRIDGE.look_at(TOUCH_CURRENT.global_position)

	if cursor_locked():
		return

	if (confirm_swapped and Input.is_action_just_pressed("back")) or (!confirm_swapped and Input.is_action_just_pressed("select")):
		confirm_hold_time = Time.get_ticks_msec()
	if !confirm_held() and confirm_hold_time != null:
		if pending_special:
			go_to_special()
			return
		confirm_hold_time = null

	if option_selection - scroll_offset >= visible_slots.size():
		print("OPTION SELECTION: " + str(option_selection) + " SCROLL OFFSET " + str(scroll_offset) + " VISIBLE_SLOT SIZE " + str(visible_slots.size()))
		scroll_offset = option_selection - visible_slots.size() + 1
	# Touch controls for options
	if visible_slots.is_empty():
		return
	var curr_slot = visible_slots[option_selection - scroll_offset]
	if special_allowed() and (control_tilt.x > 0.5 or (confirm_hold_time != null and Time.get_ticks_msec() - confirm_hold_time > 500)):
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
		go_to_special()
		return

	# Touch controls to go back
	if control_tilt.x < -0.5:
		# could be held
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

	if Time.get_ticks_msec() > touch_check_time:
		var control_angle = control_tilt.angle()

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
				var drag_str_y = (8.0 - abs(control_tilt.y)) / (8.0)
				touch_check_time = Time.get_ticks_msec() + tilt_ratio * 200
	else:
		TOUCH_POINTS.modulate = TOUCH_POINTS.modulate.lerp(get_setting(CFG_FG_COLOR), 0.05)

###############################################################
#
# Controller stuff
#
###############################################################
func vibrate(duration):
	if !get_setting(CFG_VIBRATE):
		return
	Input.vibrate_handheld(duration)

func swap_confirm_key():
	confirm_swapped = !confirm_swapped
	store_setting(CFG_CONFIRM_SWAP, confirm_swapped)

func confirm_pressed():
	if pending_special or pending_back:
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
	#if touch_controls.visible and up_button.button_pressed:
		#return up_button.button_pressed
	return false

func down_just_pressed():
	if Input.is_action_just_pressed("down"):
		return true
	return false

func down_held():
	if Input.is_action_pressed("down"):
		return true
	#if touch_controls.visible and down_button.button_pressed:
		#down_button.modulate.a = 0.5
		#return down_button.button_pressed
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
	store_setting(CFG_VIBRATE, !get_setting(CFG_VIBRATE))
	if get_setting(CFG_VIBRATE):
		vibrate(400)

func touch_checkin():
	if touch_position == null or previous_touch_position == null:
		return
	var touch_diff = touch_position - previous_touch_position
	previous_touch_position = touch_position
	# Get the difference between touch checkins

func get_image_path(selected=Global.get_selected()):
	var system_in_question = selected.system
	var game_title = selected.filename.get_basename()
	if selected.favorite_dir:
		var game_path = FileAccess.get_file_as_string(Global.root_path + "/" + Global.PATH_GAMES + "/FAVORITES/" + selected.filename)
		#var system_in_question = game_path.replace(Global.root_path + Global.PATH_GAMES, "").split("/")[0]
		game_title = game_path.split("/")[-1].get_basename()
		system_in_question = Global.get_selected().filename.split("] ")[0].replace("[", "")
	if game_title == system_in_question:
		return str(Global.root_path + Global.PATH_IMAGES + system_in_question + ".png").replace("//", "/")
	return str(Global.root_path + Global.PATH_IMAGES + system_in_question + "/" + game_title + ".png").replace("//", "/")

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

func _input(event):
	if !touch_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if Time.get_ticks_msec() - touch_start_time < 200:
				return
			if touch_position == null:
				touch_start_time = Time.get_ticks_msec()
				touch_check_time = touch_start_time + 800
				previous_touch_position = event.position
				touch_start_position = event.position
				if get_setting(CFG_TOUCH_VISIBLE):
					TOUCH_POINTS.visible = true
				TOUCH_POINTS.modulate = get_setting(CFG_BG_COLOR)
				TOUCH_START.global_position = touch_start_position
				TOUCH_START.scale = Vector2(text_height / 4.0,text_height / 4.0)
				TOUCH_CURRENT.scale = Vector2(text_height / 2.0,text_height / 2.0)
				pending_special = false
				pending_back = false
			touch_position = event.position
		else:
			TOUCH_POINTS.visible = false
			if touch_position == null or touch_start_position == null:
				touch_position = null
				touch_start_position = null
				return
			var diff = touch_position - touch_start_position
			if Time.get_ticks_msec() - touch_start_time < 800:
				if diff.y < -window_height / 8.0:
					vibrate(20)
					move_up()
					refresh_art()
				elif diff.y > window_height / 8.0:
					vibrate(20)
					move_down()
					refresh_art()
				elif diff.length() < text_height:
					press_confirm()
			if pending_back or diff.x < -window_width / 8.0:
				press_back()
				pending_back = false
				touch_check_time = Time.get_ticks_msec() + 1000
			if pending_special:
				go_to_special()
				touch_check_time = Time.get_ticks_msec() + 1000
			touch_position = null
	if event is InputEventScreenDrag:
		#if Time.get_ticks_msec() > touch_check_time:
			#if event.relative.y < -0:
				#move_up()
			#elif event.relative.y > 0:
				#move_down()
			#if abs(event.relative.y) < 8:
				#touch_check_time = Time.get_ticks_msec() + 500
		touch_position = event.position

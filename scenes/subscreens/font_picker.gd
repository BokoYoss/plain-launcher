extends component

var launcher = null

var font_list = {}
var current_font_subdir = null

# Called when the node enters the scene tree for the first time.
func _ready():

	Global.post_draw_callback = Callable(self, "apply_fonts")
	preload("res://launcher_configs/COMMON/fonts/Montserrat/Montserrat-Regular.ttf")
	font_list = {
		"Default": {"Medium": "res://launcher_configs/COMMON/fonts/Rubik/Rubik-Medium.ttf"},
	}
	var font_dir = DirAccess.open("res://launcher_configs/COMMON/fonts")
	if font_dir:
		font_dir.list_dir_begin()
		var font_subdir = font_dir.get_next()
		while font_subdir != "":
			font_subdir = font_subdir.replace(".import", "")
			var subdir_for_font = DirAccess.open("res://launcher_configs/COMMON/fonts/" + font_subdir)
			if not subdir_for_font:
				#if font_subdir.get_extension() == "ttf":
					#var font_name = font_subdir.get_basename().replace(".ttf", "")
					#font_list[font_name] = "res://launcher_configs/COMMON/fonts/" + font_subdir
				font_subdir = font_dir.get_next()
				continue
			font_list[font_subdir] = {
				"Light": "res://launcher_configs/COMMON/fonts/" + font_subdir + "/" + font_subdir + "-Light.ttf",
				"Regular": "res://launcher_configs/COMMON/fonts/" + font_subdir + "/" + font_subdir + "-Regular.ttf",
				"Medium": "res://launcher_configs/COMMON/fonts/" + font_subdir + "/" + font_subdir + "-Medium.ttf",
				"Bold": "res://launcher_configs/COMMON/fonts/" + font_subdir + "/" + font_subdir + "-Bold.ttf",
				"ExtraBold": "res://launcher_configs/COMMON/fonts/" + font_subdir + "/" + font_subdir + "-ExtraBold.ttf"
			}
			font_subdir = font_dir.get_next()
			#var files_in_font_dir = subdir_for_font.get_files()
			#for font in files_in_font_dir:
				#if font.get_extension() != "ttf":
					#continue
				#var font_name = font.get_basename().replace(".ttf", "")
				#font_list[font_name] = subdir_for_font.get_current_dir() + "/" + font
			#font_subdir = font_dir.get_next()
		font_dir.list_dir_end()
	populate_content()

func apply_fonts():
	if current_font_subdir == null:
		for i in range(0, Global.visible_slots.size()):
			var slot = Global.visible_slots[i]
			if i >= Global.option_list.size():
				break
			var opt = Global.option_list[i + Global.scroll_offset]
			if font_list.has(opt.filename):
				slot.add_theme_font_override("font", ResourceLoader.load(font_list.get(opt.filename, {}).get("Medium")))
	else:
		for i in range(0, Global.visible_slots.size()):
			var slot = Global.visible_slots[i]
			if i >= Global.option_list.size():
				break
			var opt = Global.option_list[i + Global.scroll_offset]
			if font_list.get(current_font_subdir, {}).has(opt.filename):
				slot.add_theme_font_override("font", ResourceLoader.load(font_list.get(current_font_subdir, {}).get(opt.filename)))

func populate_content(msg_override=null):
	if current_font_subdir == null:
		Global.clear_visible("Fonts", font_list.keys())
	else:
		Global.clear_visible(current_font_subdir, font_list.get(current_font_subdir, {}).keys())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		if current_font_subdir == null:
			if Global.get_selected().filename == "Default":
				Global.font = ResourceLoader.load(font_list["Default"].get("Medium"))
				Global.store_setting(Global.CFG_FONT, font_list["Default"].get("Medium"))
				Global.refresh_fonts()
				Global.back_to_previous_screen()
				return
			current_font_subdir = Global.get_selected().filename
			populate_content()
			return
		var selected = Global.get_selected().filename
		if font_list.get(current_font_subdir, {}).get(selected) != null:
			Global.store_setting(Global.CFG_FONT, font_list.get(current_font_subdir).get(selected))
			Global.font = ResourceLoader.load(font_list.get(current_font_subdir).get(selected))
		if Global.font == null:
			Global.store_setting(Global.CFG_FONT, font_list["Default"].get("Medium"))
			Global.font = ResourceLoader.load(font_list["Default"].get("Medium"))
		Global.refresh_fonts()
		Global.back_to_previous_screen()
	elif Global.back_pressed():
		Global.store_position()
		if current_font_subdir != null:
			current_font_subdir = null
			populate_content()
			return
		if Global.font == null:
			Global.store_setting(Global.CFG_FONT, font_list["Default"].get("Medium"))
			Global.font = ResourceLoader.load(font_list["Default"].get("Medium"))
		Global.refresh_fonts()
		Global.back_to_previous_screen()

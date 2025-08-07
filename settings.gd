extends component

var ANDROID_LAUNCHER = preload("res://launcher_android.tscn")
var launcher

# Called when the node enters the scene tree for the first time.
func _ready():
	#title.set_anchors_preset(Control.PRESET_CENTER)
	#var settings = ["Swap confirm button", "Select storage", "Change background color", "Change foreground color", "Change font", "Restore all game settings", "Remove Plain Launcher directory"]
	var settings = ["General", "Visuals", "Controls"]
	settings.append("Credits")
	settings.append("Quit")

	Global.fade.modulate.a = 1.0
	Global.clear_visible("SETTINGS", settings)
	
	Global.post_scroll_callback = Callable(self, "on_scroll")

	if OS.get_name() == "Android":
		AndroidInterface.connect("configured_storage", get_storage_selection)
		AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)

	if Global.setting_subscreen == "visuals":
		show_visual_settings()
		Global.setting_subscreen = null
	if Global.setting_subscreen == "controls":
		show_control_settings()
		Global.setting_subscreen = null
	if Global.setting_subscreen == "system":
		show_system_settings()
		Global.setting_subscreen = null
	Global.refresh_art()

func get_storage_selection(path):
	pass

func on_storage_config_failure(msg):
	pass

const LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum"

func show_visual_settings():
	var line_length_example = ""
	for i in range(0, Global.window_width):
		line_length_example += "0"
	var visual_settings = ["Change size", "Cover size", "Cover position", "Cover border", "Cover opacity", "Drop shadow", "System Art: " + str(Global.get_setting(Global.CFG_VISUAL_BUILTIN_SYSTEM_ART)), "System borders: " + str(Global.get_setting(Global.CFG_VISUAL_SYSTEM_BORDER)), "Title orientation", "Left margin", "Top margin", "Text cutoff: " + LOREM, "Letter outlines", "Change font", "Change background color", "Change foreground color"]
	var hide_toggle = "Show hidden items"
	if Global.show_hidden:
		hide_toggle = "Hide hidden items"
	var touch_visible_toggle = "Disable touch visuals"
	if !Global.get_setting(Global.CFG_TOUCH_VISIBLE):
		touch_visible_toggle = "Enable touch visuals"
	var caps_toggle = "Caps Lock on"
	if Global.get_setting(Global.CFG_CAPS_LOCK):
		caps_toggle = "Caps Lock off"
	visual_settings.push_front(hide_toggle)
	visual_settings.append(caps_toggle)
	visual_settings.append(touch_visible_toggle)
	visual_settings.append("Restore all visual settings")
	Global.clear_visible("Visual Settings", visual_settings)
	show_example_art()

func show_example_art():
	var new_rand_art = randi() % 12
	while (new_rand_art == $ExampleArt.frame):
		new_rand_art = randi() % 12
	Global.img_texture_override = $ExampleArt.get_sprite_frames().get_frame_texture("default",new_rand_art)

func on_scroll():
	if Global.title.text == "Visual Settings":
		show_example_art()
	else:
		Global.img_texture_override = null

func show_control_settings():
	var control_settings = ["Swap confirm button"]
	var vibe_setting = "Disable vibration"
	if !Global.get_setting(Global.CFG_VIBRATE):
		vibe_setting = "Enable vibration"
	control_settings.append(vibe_setting)
	Global.clear_visible("Control Settings", control_settings)

func request_external_storage():
	var external_path = AndroidInterface.get_external_storage_path()

func populate_minui_paths():
	var external_path = AndroidInterface.get_external_storage_path()
	if external_path == null:
		Global.clear_visible("Unable to access external storage", ["OK"])
		return

func show_system_settings():
	Global.clear_visible("General Settings", ["Select storage", "Restore all game settings", "Remove Plain Launcher directory"])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean.to_lower()
		if selected == "quit":
			get_tree().quit()
#"Cover size", "Cover border thickness", "System borders", "Drop shadow",
		elif "cover size" == selected:
			Global.cycle_cover_sizes()
			show_visual_settings()
			return
		elif "cover position" == selected:
			Global.clear_visible("Set cover position.")
			Global.setting_subscreen = "visuals"
			Global.go_to("art_placer")
			return
		elif "cover border" == selected:
			Global.cycle_border_thickness()
			show_visual_settings()
			return
		elif "system borders" in selected:
			Global.store_setting(Global.CFG_VISUAL_SYSTEM_BORDER, !Global.get_setting(Global.CFG_VISUAL_SYSTEM_BORDER))
			show_visual_settings()
			return
		elif "system art" in selected:
			Global.store_setting(Global.CFG_VISUAL_BUILTIN_SYSTEM_ART, !Global.get_setting(Global.CFG_VISUAL_BUILTIN_SYSTEM_ART))
			show_visual_settings()
			return
		elif "drop shadow" == selected:
			Global.cycle_drop_shadow_locations()
			show_visual_settings()
			return
		elif "title orientation" == selected:
			Global.cycle_title_allignment()
			show_visual_settings()
			return
		elif "text orientation" == selected:
			Global.cycle_body_allignment()
			show_visual_settings()
			return
		elif "cover orientation" == selected:
			Global.cycle_art_alignment()
			show_visual_settings()
			Global.refresh_art()
			return
		elif "cover opacity" == selected:
			Global.cycle_art_opacity()
			show_visual_settings()
			Global.refresh_art()
			return
		elif "left margin" == selected:
			Global.cycle_left_margin()
			show_visual_settings()
			return
		elif "top margin" == selected:
			Global.cycle_top_margin()
			show_visual_settings()
			return
		elif "letter outlines" == selected:
			Global.toggle_text_outline()
			show_visual_settings()
			return
		elif selected == "general":
			show_system_settings()
			return
		elif selected == "visuals":
			show_visual_settings()
			show_example_art()
			return
		elif selected == "controls":
			show_control_settings()
			return
		elif "touch visuals" in selected:
			Global.toggle_touch_visible()
			show_visual_settings()
			return
		elif "caps lock" in selected:
			Global.caps_lock()
			show_visual_settings()
			return
		elif "text cutoff" in selected:
			Global.cycle_line_length()
			show_visual_settings()
			return
		elif "change size" in selected:
			Global.setting_subscreen = "visuals"
			Global.cycle_sizes()
			return
		elif "hidden" in selected:
			Global.show_hidden = !Global.show_hidden
			show_visual_settings()
			return
		elif "minui" in selected:
			populate_minui_paths()
			return
		elif "artwork" in selected:
			Global.toggle_art()
			show_visual_settings()
			return
		elif "swap" in selected:
			Global.swap_confirm_key()
			Global.clear_visible("Swapped CONFIRM and BACK keys.", ["OK"])
		elif "vibration" in selected:
			Global.toggle_vibrate()
			show_control_settings()
			return
		elif selected == "ok":
			Global.go_to_main()
			return
		elif "storage" in selected:
			Global.go_to("file_browser")
		elif "background" in selected:
			Global.clear_visible("Select BACKGROUND color.", ["START: Default"])
			Global.color_picker = "background"
			Global.setting_subscreen = "visuals"
			Global.go_to("color_picker")
		elif "foreground" in selected:
			Global.clear_visible("Select TEXT color.", ["START: Default"])
			Global.color_picker = "foreground"
			Global.setting_subscreen = "visuals"
			Global.go_to("color_picker")
		elif "font" in selected:
			Global.setting_subscreen = "visuals"
			Global.go_to("font_picker")
			return
		elif "restore all game settings" in selected:
			Global.clear_all_settings()
			Global.clear_visible("Restored settings to default.", ["OK"])
			return
		elif "restore all visual settings" in selected:
			Global.global_settings = null
			Global.store_setting(Global.CFG_ROOT, Global.root_path)
			Global.set_up_slots()
			Global.show_options(Global.scroll_offset)
			Global.set_all_text_color(Global.get_setting(Global.CFG_FG_COLOR))
			Global.highlight_selection(Global.option_selection)
			Global.refresh_art()
			Global.clear_visible("Restored visual settings", ["OK"])
			return
		elif "remove" in selected:
			Global.clear_visible("Delete everything in " + Global.root_path + "?", ["Delete it", "Nevermind"])
			return
		elif "delete it" in selected:
			var root = DirAccess.open(Global.root_path)
			if root:
				root.rename_absolute(Global.root_path, Global.root_path + "-" + str(Time.get_unix_time_from_system()))
				Global.go_to("file_browser")
				return
		elif "credits" in selected:
			Global.go_to("credits")
		return
	if Global.back_pressed():
		if Global.title.text.to_lower() != "settings":
			Global.go_to("settings")
			Global.img_texture_override = null
			return
		if Global.get_selected().clean.to_lower() == "ok":
			return
		Global.go_to_main()
		return
	if Input.is_action_just_pressed("exit"):
		Global.go_to_main()

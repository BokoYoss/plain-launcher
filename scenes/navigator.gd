extends Node

const MAX_HISTORY = 20

var history: Array[String] = []
var current_screen = ""

var previous_screen: String:
	get:
		return history.back() if not history.is_empty() else ""

func go_to(target, new_message="", force=false):
	Global.store_position()
	var refresh = target == current_screen
	if !force and !refresh and target == "special" and !Global.special_allowed():
		print("Cannot go to special from " + current_screen)
		Global.highlight_selection()
		return
	if not refresh and current_screen != "":
		history.push_back(current_screen)
		if history.size() > MAX_HISTORY:
			history.pop_front()
	current_screen = target
	_perform_navigate(target, new_message)

func back_to_previous_screen():
	if history.is_empty():
		return
	var target = history.pop_back()
	current_screen = target
	_perform_navigate(target)

func _perform_navigate(target, new_message=""):
	if Global.on_leave_component != null:
		Global.on_leave_component.call()
		Global.on_leave_component = null
	Global.BACKDROP.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)
	Global.set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	print("GOTO " + target + " | history: " + str(history))
	Global.message.text = new_message
	Global.populate_filter = null
	Global.post_draw_callback = null
	Global.post_scroll_callback = null
	Global.no_alias = false
	Global.img_texture_override = null
	Global.get_tree().change_scene_to_file.call_deferred("res://scenes/subscreens/" + target + ".tscn")

func go_to_main():
	history.clear()
	if not Global.root_path or not Global.version_matches():
		go_to("confirm_set")
	else:
		go_to("system_browser")

func go_to_special():
	Global.special_item = Global.get_selected()
	if current_screen == "system_browser":
		Global.subscreen = Global.special_item.filename
	go_to("special")
	Global.pending_special = false

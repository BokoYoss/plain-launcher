extends Node

const StorageSetup = preload("res://scenes/storage_setup.gd")

var _stack: Array = []
# Each entry: {name, node, option_list, scroll_offset, option_selection, title, aliases}

var _scenes: Dictionary = {}

var current_screen: String:
	get: return _stack.back().name if not _stack.is_empty() else ""

var previous_screen: String:
	get: return _stack[-2].name if _stack.size() >= 2 else ""

func _ready():
	var dir = DirAccess.open("res://scenes/subscreens/")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tscn"):
				_scenes[file.get_basename()] = load("res://scenes/subscreens/" + file)

func push(target: String, new_message: String = ""):
	_save_current_state()
	_on_navigate(current_screen, target, new_message)
	if not _stack.is_empty():
		_stack.back().node.process_mode = Node.PROCESS_MODE_DISABLED
	var node = _instantiate(target)
	_stack.push_back({name = target, node = node, option_list = [], scroll_offset = 0, option_selection = 0, title = "", aliases={}, prompts = Global.DEFAULT_PROMPTS})
	get_tree().root.add_child.call_deferred(node)

func pop(new_message: String = ""):
	if _stack.size() <= 1:
		go_to_main()
		return
	Global.store_position()
	Global.store_list_positions()
	var top = _stack.pop_back()
	top.node.queue_free()
	var prev = _stack.back()
	_on_navigate(top.name, prev.name, new_message)
	_restore_state(prev)
	prev.node.process_mode = Node.PROCESS_MODE_INHERIT
	if prev.node.has_method("_on_resume"):
		prev.node._on_resume()
	Global.resume_settings_panel()

func replace(target: String, new_message: String = ""):
	if not _stack.is_empty():
		Global.store_position()
		Global.store_list_positions()
		_stack.pop_back().node.queue_free()
	push(target, new_message)

func go_to_main():
	if not _stack.is_empty() and Global.message != null and not Global.option_list.is_empty():
		Global.store_position()
		Global.store_list_positions()
	for entry in _stack:
		entry.node.queue_free()
	_stack.clear()
	if not Global.root_path:
		push("storage_wait" if Global.waiting_root_path != "" else "confirm_set")
	else:
		if not Global.version_matches():
			Global.migrate_configs()
			Global.store_version()
		StorageSetup.add_missing_systems(DirAccess.open(Global.root_path))
		push("system_browser")
		Global.ask_for_confirm_button.call_deferred()

func go_to_special():
	Global.special_item = Global.get_selected()
	if current_screen == "system_browser":
		Global.subscreen = Global.special_item.filename
	Global.pending_special = false
	Global.open_options(Global.special_item)

func _save_current_state():
	if _stack.is_empty():
		return
	var top = _stack.back()
	top.option_list = Global.option_list.duplicate()
	top.scroll_offset = Global.scroll_offset
	top.option_selection = Global.option_selection
	top.title = Global.title.text
	top.aliases = Global.ALIAS_MAP.duplicate()
	top.prompts = Global.prompts

func _restore_state(entry: Dictionary):
	Global.option_list = entry.option_list.duplicate()
	Global.scroll_offset = entry.scroll_offset
	Global.option_selection = entry.option_selection
	Global.title.text = entry.get("title", "")
	Global.set_active_alias_map(entry.aliases)
	Global.set_prompts(entry.get("prompts", Global.DEFAULT_PROMPTS))

func _on_navigate(current: String, new: String, new_message: String = ""):
	if Global.on_leave_screen != null:
		Global.on_leave_screen.call()
		Global.on_leave_screen = null
	if current != "" and current == current_screen:
		Global.store_position()
		Global.store_list_positions()
	Global.disable_scroll = false
	Global.title_can_be_blank = false
	Global.BACKDROP.modulate = Settings.get_setting(Settings.CFG_BG_COLOR)
	Global.set_all_text_color(Settings.get_setting(Settings.CFG_FG_COLOR))
	print("NAV " + current + " -> " + new + " | stack depth: " + str(_stack.size()))
	Global.message.text = new_message
	Global.populate_filter = null
	Global.post_draw_callback = null
	Global.post_scroll_callback = null
	Global.no_alias = true
	Global.waiting_for_confirm_release = true
	Global.img_texture_override = null
	Global.set_prompts(Global.DEFAULT_PROMPTS)

func _instantiate(target: String) -> Node:
	if not _scenes.has(target):
		_scenes[target] = load("res://scenes/subscreens/" + target + ".tscn")
	var node = _scenes[target].instantiate()
	node.name = target
	return node

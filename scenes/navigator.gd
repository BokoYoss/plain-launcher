extends Node

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
	_stack.push_back({name = target, node = node, option_list = [], scroll_offset = 0, option_selection = 0, title = "", aliases={}})
	get_tree().root.add_child.call_deferred(node)

func pop(new_message: String = ""):
	if _stack.size() <= 1:
		go_to_main()
		return
	var top = _stack.pop_back()
	top.node.queue_free()
	var prev = _stack.back()
	_on_navigate(top.name, prev.name, new_message)
	_restore_state(prev)
	prev.node.process_mode = Node.PROCESS_MODE_INHERIT
	if prev.node.has_method("_on_resume"):
		prev.node._on_resume()

func replace(target: String, new_message: String = ""):
	if not _stack.is_empty():
		_stack.pop_back().node.queue_free()
	push(target, new_message)

func go_to_main():
	for entry in _stack:
		entry.node.queue_free()
	_stack.clear()
	if not Global.root_path:
		push("confirm_set")
	else:
		if not Global.version_matches():
			Global.migrate_configs()
			Global.store_version()
		push("system_browser")

func go_to_special():
	Global.special_item = Global.get_selected()
	if current_screen == "system_browser":
		Global.subscreen = Global.special_item.filename
	push("special")
	Global.pending_special = false

func _save_current_state():
	if _stack.is_empty():
		return
	var top = _stack.back()
	top.option_list = Global.option_list.duplicate()
	top.scroll_offset = Global.scroll_offset
	top.option_selection = Global.option_selection
	top.title = Global.title.text
	top.aliases = Global.ALIAS_MAP.duplicate()

func _restore_state(entry: Dictionary):
	Global.option_list = entry.option_list.duplicate()
	Global.scroll_offset = entry.scroll_offset
	Global.option_selection = entry.option_selection
	Global.title.text = entry.get("title", "")
	Global.set_active_alias_map(entry.aliases)

func _on_navigate(current: String, new: String, new_message: String = ""):
	if Global.on_leave_screen != null:
		Global.on_leave_screen.call()
		Global.on_leave_screen = null
	Global.store_position()
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

func _instantiate(target: String) -> Node:
	if not _scenes.has(target):
		_scenes[target] = load("res://scenes/subscreens/" + target + ".tscn")
	var node = _scenes[target].instantiate()
	node.name = target
	return node

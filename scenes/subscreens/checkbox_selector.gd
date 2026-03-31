extends Screen

func _ready():
	Global.post_draw_callback = Callable(self, "show_indicators")
	Global.no_alias = true
	Global.clear_visible(Global.selector_title, Global.selector_items.duplicate())
	show_indicators()

func show_indicators():
	for i in range(Global.visible_slots.size()):
		if i >= Global.option_list.size():
			break
		var item = Global.option_list[Global.scroll_offset + i].clean
		Global.fav_indicators[i].visible = item in Global.selector_active

func _process(_delta):
	if Global.confirm_pressed():
		Global.store_position()
		var selected = Global.get_selected().clean
		if Global.selector_multi:
			if selected in Global.selector_active:
				Global.selector_active.erase(selected)
			else:
				Global.selector_active.append(selected)
		else:
			Global.selector_active = [selected]
		show_indicators()
	if Global.back_pressed():
		Navigator.pop()
	if Input.is_action_just_pressed("exit"):
		Navigator.go_to_main()

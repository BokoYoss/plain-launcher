extends Screen

func _ready():
	Global.no_alias = true
	Global.clear_visible(Global.selector_title, Global.selector_items.duplicate())

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
		Global.refresh_option_text()
	if Global.back_pressed():
		Navigator.pop()
	if Input.is_action_just_pressed("exit"):
		Navigator.go_to_main()

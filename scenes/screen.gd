class_name Screen extends Node

func _ready():
	pass

func _process(delta):
	pass

func _on_resume():
	Global.show_options(Global.scroll_offset)
	Global.highlight_selection()

extends "res://scenes/navigator.gd"

var pushed: Array = []

func push(target: String, new_message: String = ""):
	pushed.append(target)

func pop(new_message: String = ""):
	pushed.append("<pop>")

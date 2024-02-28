class_name option extends Node

var clean: String = ""
var filename: String = ""
var absolute_path: String = ""
var system: String = ""
var image_path: String = ""
var favorite_dir = false
var is_dir = false

static func new_option(value):
	var new = option.new()
	new.clean = value
	new.filename = value
	new.absolute_path = value
	return new

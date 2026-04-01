class_name option extends Node

var clean: String = ""
var filename: String = ""
var absolute_path: String = ""
var system: String = ""
var image_path: String = ""
var favorite_dir = false
var is_dir = false
var callbacks: Dictionary = {}

func handles(event: String) -> bool:
	return callbacks.has(event) and callbacks[event].is_valid()

func trigger(event: String, args: Array = []) -> bool:
	if not handles(event):
		return false
	if args.is_empty():
		callbacks[event].call()
	else:
		callbacks[event].callv(args)
	return true

static func new_option(value):
	var new = option.new()
	new.clean = value
	new.filename = value
	new.absolute_path = value
	return new

static func with_callback(label: String, cb: Callable) -> option:
	var opt = option.new()
	opt.clean = label
	opt.filename = label
	opt.absolute_path = label
	opt.callbacks[Actions.CONFIRM] = cb
	return opt

extends Screen

var current_dir: DirAccess = null

var additional_paths = []
var pending_path = ""

var start_time = null

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.get_name() == "Android":
		AndroidInterface.connect("configured_storage", get_storage_selection)
		AndroidInterface.connect("configure_storage_failure", on_storage_config_failure)
		populate_content()
	else:
		Navigator.go_to_main()
	start_time = Time.get_ticks_msec()
	print(Global.special_item)

func get_storage_selection(string):
	print("Attempting to use " + string)
	pending_path = string.replace(" ", "").replace(":", "/")
	if DirAccess.open(pending_path) == null:
		Global.clear_visible("Sorry, unable to access that.", [option.with_callback("OK", populate_content)])
		return
	var path = pending_path
	Global.clear_visible("Use " + path + "?", [
		option.with_callback("Yes", func():
			additional_paths.append(path)
			Global.store_additional_paths(additional_paths)
			populate_content()
		),
		option.with_callback("No", populate_content),
	])

func on_storage_config_failure(message):
	print("Failure when setting up storage")
	Global.clear_visible("Unable to access", [option.with_callback("OK", populate_content)])

func populate_content():
	additional_paths = Global.get_additional_paths()

	var items = [option.with_callback("Add a path", func(): AndroidInterface.choose_storage_directory())]
	for path in additional_paths:
		var p = path
		items.append(option.with_callback(p, func():
			pending_path = p
			Global.clear_visible(p, [
				option.with_callback("Remove", func():
					Global.remove_additional_path(p)
					populate_content()
				),
				option.with_callback("Back", populate_content),
			])
		))

	Global.clear_visible("Add game paths", items)
	Global.list_directory_contents(current_dir, true, [], true, false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if start_time != null and Time.get_ticks_msec() - start_time < 500:
		return
	if Global.confirm_pressed():
		var selected = Global.get_selected()
		selected.trigger(Actions.CONFIRM)
	elif Global.back_pressed():
		Navigator.pop()

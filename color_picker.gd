extends Node2D

@onready var CURSOR = $Sprite2D/Cursor

var held_time = -1
var sprite_height = 0
var sprite_width = 0
var cursor_bound_top = 0
var cursor_bound_bottom = 0
var cursor_bound_left = 0
var cursor_bound_right = 0

var start_time = 0
var update_example_time = 0

var cursor_speed = 300

var scolding = false

# Called when the node enters the scene tree for the first time.
func _ready():

	$Sprite2D.position = Vector2(Global.window_width, Global.window_height) / 2.0
	sprite_height = $Sprite2D.texture.get_size().y
	sprite_width = $Sprite2D.texture.get_size().x

	var scale_ratio_y = (Global.window_width * 0.8) / $Sprite2D.texture.get_size().x
	var scale_ratio_x = (Global.window_height * 0.8) / $Sprite2D.texture.get_size().y
	var scale_ratio = min(scale_ratio_x, scale_ratio_y)
	$Sprite2D.scale = Vector2(scale_ratio, scale_ratio)

	cursor_bound_top = Global.window_height / 2.0 - sprite_height / 2.0
	cursor_bound_bottom = Global.window_height / 2.0 + sprite_height / 2.0
	cursor_bound_left = Global.window_width / 2.0 - sprite_width / 2.0
	cursor_bound_right = Global.window_width / 2.0 + sprite_width / 2.0

	Global.fade.modulate.a = 0.0
	Global.show_message("START: Restore Default", true)
	start_time = Time.get_ticks_msec()
	Global.cover.visible = false

func set_color(new_color):
	if Global.color_picker == "background":
		Global.store_setting(Global.CFG_BG_COLOR, new_color)
	else:
		Global.store_setting(Global.CFG_FG_COLOR, new_color)
	Global.back_to_previous_screen()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if Input.is_action_pressed("up"):
		CURSOR.position.y = CURSOR.position.y - cursor_speed * delta
	if Input.is_action_pressed("down"):
		CURSOR.position.y = CURSOR.position.y + cursor_speed * delta
	if Input.is_action_pressed("right"):
		CURSOR.position.x = CURSOR.position.x + cursor_speed * delta
	if Input.is_action_pressed("left"):
		CURSOR.position.x = CURSOR.position.x - cursor_speed * delta
	if Global.control_tilt.length() > 0.1:
		CURSOR.position += Global.control_tilt * 8.0
	CURSOR.position.x = clamp(CURSOR.position.x, -sprite_width / 2.0 + 2, sprite_width / 2.0 - 2)
	CURSOR.position.y = clamp(CURSOR.position.y, -sprite_height / 2.0 + 2, sprite_height / 2.0 - 2)
	if Input.is_action_pressed("start"):
		if Global.color_picker == "background":
			set_color(Global.DEFAULT_SETTINGS.get(Global.CFG_BG_COLOR))
			return
		else:
			set_color(Global.DEFAULT_SETTINGS.get(Global.CFG_FG_COLOR))
			return
	if Time.get_ticks_msec() - update_example_time > 100:
		if scolding:
			Global.BACKDROP.modulate = Global.get_setting(Global.CFG_BG_COLOR)
			Global.title.modulate = Global.get_setting(Global.CFG_FG_COLOR)
		else:
			var offset_position = Vector2i(CURSOR.position.x + sprite_width / 2.0, CURSOR.position.y + sprite_height / 2.0)
			var new_color = $Sprite2D.texture.get_image().get_pixelv(offset_position)
			update_example_time = Time.get_ticks_msec()
			if Global.color_picker == "background":
				Global.BACKDROP.modulate = new_color
			else:
				Global.title.modulate = new_color
				Global.message.modulate = new_color
	if Time.get_ticks_msec() - start_time > 500:
		if Global.confirm_pressed():
			if scolding:
				scolding = false
				Global.clear_visible("Choose another")
				return
			var offset_position = Vector2i(CURSOR.position.x + sprite_width / 2.0, CURSOR.position.y + sprite_height / 2.0)
			var new_color = $Sprite2D.texture.get_image().get_pixelv(offset_position)
			if Global.color_picker == "background" and Global.get_setting(Global.CFG_BG_COLOR).is_equal_approx(new_color):
				Global.clear_visible("Sorry, too similar", ["OK"])
				scolding = true
				return
			if Global.color_picker == "foreground" and Global.get_setting(Global.CFG_FG_COLOR).is_equal_approx(new_color):
				Global.clear_visible("Sorry, too similar", ["OK"])
				scolding = true
				return
			set_color(new_color)
		if Global.back_pressed():
			Global.go_to("settings")

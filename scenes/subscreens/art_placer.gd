extends Node2D

@onready var CURSOR = $Cursor

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

# Called when the node enters the scene tree for the first time.
func _ready():

	CURSOR.position = Vector2(Global.window_width * Global.get_setting(Global.CFG_VISUAL_ART_POSITION_X), Global.window_height * Global.get_setting(Global.CFG_VISUAL_ART_POSITION_Y))

	cursor_bound_top = 0
	cursor_bound_bottom = Global.window_height
	cursor_bound_left = 0
	cursor_bound_right = Global.window_width

	Global.fade.modulate.a = 0.0
	Global.clear_visible("Set cover position.", ["START: Default"])
	start_time = Time.get_ticks_msec()
	Global.cover.visible = false

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
	CURSOR.position.x = clamp(CURSOR.position.x, 0, Global.window_width)
	CURSOR.position.y = clamp(CURSOR.position.y, 0, Global.window_height)
	if Input.is_action_pressed("start"):
		Global.store_setting(Global.CFG_VISUAL_ART_POSITION_X, Global.DEFAULT_SETTINGS[Global.CFG_VISUAL_ART_POSITION_X])
		Global.store_setting(Global.CFG_VISUAL_ART_POSITION_Y, Global.DEFAULT_SETTINGS[Global.CFG_VISUAL_ART_POSITION_Y])
		Global.go_to("settings")
	if Time.get_ticks_msec() - start_time > 500:
		if Global.confirm_pressed():
			var relative_x = CURSOR.position.x / Global.window_width
			var relative_y = CURSOR.position.y / Global.window_height
			Global.store_setting(Global.CFG_VISUAL_ART_POSITION_X, relative_x)
			Global.store_setting(Global.CFG_VISUAL_ART_POSITION_Y, relative_y)
			Global.go_to("settings")
		if Global.back_pressed():
			Global.go_to("settings")

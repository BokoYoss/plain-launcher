extends Screen

var prompt: PressGlyph = null
var done = false

func _ready():
	if not changing() and not Global.needs_confirm_button(Settings.get_setting(Settings.CFG_CONFIRM_SET), Input.get_connected_joypads().size()):
		Navigator.push("file_browser")
		return
	Global.clear_visible("", [])
	Global.set_prompts([])
	prompt = PressGlyph.new()
	prompt.z_index = 4005
	add_child(prompt)

func changing() -> bool:
	return Global.root_path != ""

func _process(_delta):
	if done:
		return
	if Global.confirm_pressed():
		_done(false)
	elif Global.back_pressed():
		_done(true)

func _done(swap: bool):
	done = true
	if swap:
		Global.swap_confirm_key()
	Settings.store(Settings.CFG_CONFIRM_SET, true)
	Global.vibrate(30)
	if prompt != null and Global.effects_on():
		prompt.press()
		await get_tree().create_timer(PressGlyph.PRESS_SECONDS).timeout
	Global.block_confirm()
	if prompt != null:
		prompt.queue_free()
		prompt = null
	Global.refresh_prompt_bar()
	if changing():
		Navigator.pop()
	else:
		Navigator.push("file_browser")

extends Screen

const DOT_INTERVAL_MS = 400
const COUNTDOWN_SECONDS = 5

var start_time = 0
var next_check = 0
var hold_start = null

func _ready():
	start_time = Time.get_ticks_msec()
	Global.set_prompts([])
	Global.clear_visible(waiting_title(start_time))
	Global.show_message("Hold accept to reconfigure storage")

func check_storage() -> bool:
	if DirAccess.dir_exists_absolute(Global.waiting_root_path):
		Global.storage_ready()
		return true
	return false

func waiting_title(now: int) -> String:
	var step = int((now - start_time) / float(DOT_INTERVAL_MS)) % 3
	return "Waiting for storage" + ".".repeat(step + 1)

func countdown_remaining(now: int) -> int:
	return COUNTDOWN_SECONDS - int((now - hold_start) / 1000.0)

func reconfigure():
	Global.waiting_root_path = ""
	Navigator.go_to_main()

func _process(delta):
	Global.message.modulate.a = 1.0
	var now = Time.get_ticks_msec()
	if now >= next_check:
		next_check = now + 1000
		if check_storage():
			return
	if Global.confirm_hold_time == null:
		hold_start = null
		Global.title.text = waiting_title(now)
		return
	if hold_start == null:
		hold_start = now
	var remaining = countdown_remaining(now)
	if remaining <= 0:
		reconfigure()
		return
	Global.title.text = "Reconfiguring storage in " + str(remaining)

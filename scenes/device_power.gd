class_name DevicePower extends RefCounted

const MUOS_HALT = "/opt/muos/script/system/halt.sh"
const LOG = "user://power.log"

static var root = ""

static func elevated(command: Array) -> Array:
	var esudo = OS.get_environment("PLAIN_LAUNCHER_ESUDO").strip_edges()
	return ([esudo] if esudo != "" else []) + command

static func command(action: String) -> Array:
	if FileAccess.file_exists(root + MUOS_HALT):
		return elevated([root + MUOS_HALT, action])
	if Launcher.on_path("systemctl"):
		return elevated(["systemctl", action])
	return elevated([action])

static func script(action: String, log_path: String) -> String:
	var primary = Launcher.shell_command(command(action))
	var fallback = Launcher.shell_command(elevated([action]))
	var run = primary if primary == fallback else primary + " || " + fallback
	return "{ date; echo " + Launcher.shell_quote(run) + "; sync; " + run + "; echo \"exit $?\"; } >>" + Launcher.shell_quote(log_path) + " 2>&1"

static func run(action: String):
	var shell = script(action, ProjectSettings.globalize_path(LOG))
	print("Device " + action + ": " + shell)
	var args = Launcher.host_script(shell, "power_command")
	if not args.is_empty():
		OS.create_process("env", args)

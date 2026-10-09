class_name BootHook extends RefCounted

const MUOS_FUNC = "/opt/muos/script/var/func.sh"
const STARTUP_VAR = "settings/general/startup"
const LAST_PLAY_VAR = "boot/last_play"
const LEGACY_LAST_PLAY = "/opt/muos/config/lastplay.txt"
const LEGACY_STARTUP = "/run/muos/global/settings/general/startup"
const ROCKNIX_CONFIG = "/storage/.config/system/configs/system.cfg"
const KNULLI_CONFIG = "/userdata/system/batocera.conf"
const BOOT_GAME_KEY = "global.bootgame.path"
const LAUNCH_NAME = "plain launcher"

const STEPS = {
	"muos": ["In muOS, go to Configuration > General Settings", "Set Device Startup to Last Game", "Open Plain Launcher from Ports once"],
	"emulationstation": ["In EmulationStation, open Ports", "Highlight Plain Launcher and open its game options", "Choose Launch this game at startup"],
}

static var muos_func = MUOS_FUNC
static var root = ""

static func cfw() -> String:
	return OS.get_environment("PLAIN_LAUNCHER_CFW").to_lower()

static func kind() -> String:
	if not "portmaster" in Platform.tags():
		return ""
	match cfw():
		"muos":
			return "muos" if legacy() or FileAccess.file_exists(muos_func) else ""
		"rocknix", "knulli":
			return cfw()
	return ""

static func supported() -> bool:
	return kind() != ""

static func steps() -> Array:
	return STEPS.get("muos" if kind() == "muos" else "emulationstation", [])

static func legacy() -> bool:
	return FileAccess.file_exists(root + LEGACY_LAST_PLAY)

static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(root + path) if FileAccess.file_exists(root + path) else ""

static func _muos_var(path: String) -> String:
	return Launcher.run_host(". " + Launcher.shell_quote(muos_func) + " >/dev/null 2>&1; GET_VAR config " + Launcher.shell_quote(path))

static func muos_startup() -> String:
	return _read(LEGACY_STARTUP).strip_edges() if legacy() else _muos_var(STARTUP_VAR)

static func muos_last_play() -> String:
	if legacy():
		return _read(LEGACY_LAST_PLAY)
	var entry = _muos_var(LAST_PLAY_VAR)
	return FileAccess.get_file_as_string(entry) if entry != "" and FileAccess.file_exists(entry) else ""

static func boot_game(config_text: String) -> String:
	for line in config_text.split("\n"):
		var parts = line.split("=", true, 1)
		if parts.size() == 2 and parts[0].strip_edges() == BOOT_GAME_KEY:
			return parts[1].strip_edges()
	return ""

static func launches_us(path: String) -> bool:
	return path.get_file().to_lower().contains(LAUNCH_NAME)

static func enabled() -> bool:
	match kind():
		"muos":
			return muos_startup() == "last" and muos_last_play().to_lower().contains(LAUNCH_NAME)
		"rocknix":
			return launches_us(boot_game(_read(ROCKNIX_CONFIG)))
		"knulli":
			return launches_us(boot_game(_read(KNULLI_CONFIG)))
	return false

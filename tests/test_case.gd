extends RefCounted

var failures: Array = []
var tree: SceneTree

func before_each():
	pass

func after_each():
	pass

func fail(msg: String):
	failures.append(msg)

func assert_true(cond, msg: String = ""):
	if not cond:
		fail("expected true: " + msg)

func assert_false(cond, msg: String = ""):
	if cond:
		fail("expected false: " + msg)

func assert_eq(actual, expected, msg: String = ""):
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s\n      expected: %s\n      actual:   %s" % [msg, var_to_str(expected), var_to_str(actual)])

func write_json(path: String, data):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(data if data is String else JSON.stringify(data))
	f.close()

func read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

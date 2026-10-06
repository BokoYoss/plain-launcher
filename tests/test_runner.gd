extends SceneTree

var _started = false

func _process(_delta):
	if _started:
		return false
	_started = true
	print("=== TESTS START ===")
	var failed = _check_scripts_parse("res://scenes") + _run_test_files()
	print("=== %s ===" % ("FAILED" if failed > 0 else "ALL PASSED"))
	quit(1 if failed > 0 else 0)
	return false

func _check_scripts_parse(dir_path: String) -> int:
	var failed = 0
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			var script = ResourceLoader.load(dir_path + "/" + file, "", ResourceLoader.CACHE_MODE_IGNORE)
			if script == null or not script.can_instantiate():
				print("  PARSE FAIL " + dir_path + "/" + file)
				failed += 1
	for sub in DirAccess.get_directories_at(dir_path):
		failed += _check_scripts_parse(dir_path + "/" + sub)
	return failed

func _run_test_files() -> int:
	var failed = 0
	var passed = 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_runner.gd" or file == "test_case.gd":
			continue
		print(file)
		var script = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			print("  FAIL could not load " + file)
			failed += 1
			continue
		var suite = script.new()
		suite.tree = self
		for method in suite.get_method_list():
			if not method.name.begins_with("test_"):
				continue
			suite.failures = []
			suite.before_each()
			suite.call(method.name)
			suite.after_each()
			if suite.failures.is_empty():
				passed += 1
				print("  ok   " + method.name)
			else:
				failed += 1
				print("  FAIL " + method.name)
				for f in suite.failures:
					print("      " + f)
	print("%d passed, %d failed" % [passed, failed])
	return failed

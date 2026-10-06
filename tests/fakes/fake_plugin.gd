extends RefCounted

var calls: Array = []
var launch_package_result = ""
var launch_intent_result = ""

func launchPackage(pkg):
	calls.append(["launchPackage", pkg])
	return launch_package_result

func launchIntent(serialized_intent):
	calls.append(["launchIntent", serialized_intent])
	return launch_intent_result

func calls_to(method: String) -> Array:
	return calls.filter(func(c): return c[0] == method).map(func(c): return c[1])

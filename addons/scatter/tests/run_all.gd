extends SceneTree

const TESTS := [
	"res://addons/scatter/tests/unit/test_registry.gd",
	"res://addons/scatter/tests/unit/test_graph_evaluation.gd",
	"res://addons/scatter/tests/unit/test_node_services.gd",
	"res://addons/scatter/tests/unit/test_architecture_rules.gd",
	"res://addons/scatter/tests/unit/test_editor_architecture.gd",
	"res://addons/scatter/tests/unit/test_path_extrude.gd",
]


func _init() -> void:
	var executable := OS.get_executable_path()
	for test_path in TESTS:
		var output: Array[String] = []
		var exit_code := OS.execute(executable, ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", test_path], output, true)
		for line in output:
			print(line)
		if exit_code != 0:
			push_error("Scatter test failed: %s" % test_path)
			quit(exit_code)
			return
	print("All Scatter tests passed")
	quit()

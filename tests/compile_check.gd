extends SceneTree
## Loads every script under res://src and fails if any does not compile.
## The smoke and network tests only load what a match uses, and a broken UI
## script can slip past them; this catches it in the quick run.
##   godot --headless --path . -s res://tests/compile_check.gd
## Runs in the first frame so autoloads (GameManager, ...) exist.

var _started := false

func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	var scripts: Array[String] = []
	_collect("res://src", scripts)
	var broken: Array[String] = []
	for path in scripts:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)
	for path in broken:
		printerr("FAIL does not compile: ", path)
	print("COMPILE: %d scripts, %d broken" % [scripts.size(), broken.size()])
	quit(1 if not broken.is_empty() else 0)
	return false

func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))

extends SceneTree
## Headless test runner for the pure gameplay rules. No plugin needed:
##   godot --headless --path . -s res://tests/run_tests.gd
## Exits with code 1 when any check fails.

const SUITES := [
	"res://tests/test_weapon_rules.gd",
	"res://tests/test_loadout_rules.gd",
	"res://tests/test_damage_rules.gd",
	"res://tests/test_powerup_rules.gd",
	"res://tests/test_team_rules.gd",
	"res://tests/test_hand_layout.gd",
]

func _init() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
		# A suite that does not compile must fail the run, not hang it.
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL ", path.get_file(), " does not compile")
			failed += 1
			continue
		var suite = script.new()
		var count: int = suite.run_all()
		total += count
		for failure in suite.failures:
			printerr("FAIL ", path.get_file(), " ", failure)
		failed += suite.failures.size()
		print("%s: %d tests, %d failures" % [path.get_file(), count, suite.failures.size()])
	print("TOTAL: %d tests, %d failures" % [total, failed])
	quit(1 if failed > 0 else 0)

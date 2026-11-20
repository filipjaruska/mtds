extends CanvasLayer

@onready var _results_list: ItemList = $MarginContainer/Panel/Padding/VBoxContainer/ResultsList


func _ready() -> void:
	layer = 80
	visible = false
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_results(results: Array) -> void:
	if _results_list == null:
		return
	if results.is_empty():
		_results_list.clear()
		_results_list.add_item("No match stats yet")
		return
	ResultsFormat.fill(_results_list, results, GameManager.is_team_mode())

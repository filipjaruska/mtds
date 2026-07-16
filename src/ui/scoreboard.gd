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
	_results_list.clear()
	if results.is_empty():
		_results_list.add_item("No match stats yet")
		return
	for entry in results:
		var line := "%s  ||  %d kills  |  %d deaths  |  %d dmg" % [
			entry.get("name", "Unknown"),
			entry.get("kills", 0),
			entry.get("deaths", 0),
			int(entry.get("damage_dealt", 0.0)),
		]
		_results_list.add_item(line)

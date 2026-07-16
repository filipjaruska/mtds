extends Control

const SAMPLE_MATCHES := [
	{"result": "Victory", "mode": "deathmatch", "kills": 12, "deaths": 4, "date": "2026-07-14"},
	{"result": "Defeat", "mode": "deathmatch+shuffle", "kills": 7, "deaths": 9, "date": "2026-07-13"},
	{"result": "Victory", "mode": "deathmatch", "kills": 15, "deaths": 6, "date": "2026-07-12"},
	{"result": "Defeat", "mode": "deathmatch+poker", "kills": 3, "deaths": 11, "date": "2026-07-10"},
	{"result": "Victory", "mode": "deathmatch+shuffle", "kills": 10, "deaths": 5, "date": "2026-07-08"},
]

@onready var _match_list: ItemList = $MarginContainer/ContentPanel/VBoxContainer/MatchHistoryPanel/Padding/MatchList


func _ready() -> void:
	_populate_match_history()


func _populate_match_history() -> void:
	_match_list.clear()
	for match_data: Dictionary in SAMPLE_MATCHES:
		var line := "%s  |  %s  |  %d / %d  |  %s" % [
			match_data["result"],
			match_data["mode"],
			match_data["kills"],
			match_data["deaths"],
			match_data["date"],
		]
		_match_list.add_item(line)

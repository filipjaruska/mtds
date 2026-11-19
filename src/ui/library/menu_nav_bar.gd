class_name MenuNavBar
extends Control

enum NavItem { CUSTOMIZE, TUTORIAL, PLAY, OPTIONS, PROFILE }

const SCENES: Dictionary = {
	NavItem.CUSTOMIZE: "res://src/ui/menus/main.tscn",
	NavItem.TUTORIAL: "uid://ce1oauidq2qpa",
	NavItem.PLAY: "res://src/ui/menus/game_browser.tscn",
	NavItem.OPTIONS: "uid://b6j40ehxmqs5w",
	NavItem.PROFILE: "res://src/ui/menus/profile.tscn",
}

@export var active_item: NavItem = NavItem.CUSTOMIZE

@onready var _customize: Button = $HBoxContainer/Customize
@onready var _tutorial: Button = $HBoxContainer/Tutorial
@onready var _play: Button = $HBoxContainer/Play
@onready var _profile: Button = $HBoxContainer/Profile
@onready var _options: Button = $HBoxContainer/Options
@onready var _exit: Button = $HBoxContainer/Exit


func _ready() -> void:
	_customize.pressed.connect(func() -> void: _navigate(NavItem.CUSTOMIZE))
	_tutorial.pressed.connect(func() -> void: _navigate(NavItem.TUTORIAL))
	_play.pressed.connect(func() -> void: _navigate(NavItem.PLAY))
	_profile.pressed.connect(func() -> void: _navigate(NavItem.PROFILE))
	_options.pressed.connect(func() -> void: _navigate(NavItem.OPTIONS))
	_exit.pressed.connect(_on_exit_pressed)
	_apply_active_item()


func set_navigation_enabled(enabled: bool) -> void:
	if not enabled:
		for button: BaseButton in [_customize, _tutorial, _play, _profile, _options, _exit]:
			button.disabled = true
		return

	_apply_active_item()
	_exit.disabled = false


func _navigate(item: NavItem) -> void:
	if item == active_item:
		return
	# While hosting/joined, the lobby must stay alive (it receives the host's
	# RPCs), so other tabs open on top of it and PLAY ("LOBBY") returns to it.
	var lobby := _active_lobby()
	if lobby:
		if item == NavItem.TUTORIAL:
			return # the tutorial is its own game session
		if item == NavItem.PLAY:
			lobby.close_menu_overlay()
		elif SCENES.has(item):
			lobby.open_menu_overlay(SCENES[item])
		return
	if not SCENES.has(item):
		return
	get_tree().change_scene_to_file(SCENES[item])


func _active_lobby() -> Node:
	return get_tree().get_first_node_in_group("Lobby") if is_inside_tree() else null


func _on_exit_pressed() -> void:
	get_tree().quit()


func _apply_active_item() -> void:
	var items: Dictionary = {
		NavItem.CUSTOMIZE: _customize,
		NavItem.TUTORIAL: _tutorial,
		NavItem.PLAY: _play,
		NavItem.PROFILE: _profile,
		NavItem.OPTIONS: _options,
	}
	for item: NavItem in items:
		var button: Button = items[item]
		button.disabled = item == active_item
	var in_lobby := _active_lobby() != null
	_play.text = "LOBBY" if in_lobby else "PLAY"
	if in_lobby:
		_tutorial.disabled = true

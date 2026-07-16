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
	if not SCENES.has(item):
		return
	get_tree().change_scene_to_file(SCENES[item])


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

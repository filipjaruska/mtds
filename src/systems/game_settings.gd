extends Node

const SECTION := "game"

var skip_splash: bool = true
var _settings_path: String = ""


func _ready() -> void:
	_settings_path = _resolve_settings_path()
	load_settings()


func _resolve_settings_path() -> String:
	if OS.has_environment("APPDATA"):
		var app_name: String = ProjectSettings.get_setting("application/config/name", "Multiplayer Top-down Shooter")
		var config_dir := OS.get_environment("APPDATA").path_join(app_name)
		DirAccess.make_dir_recursive_absolute(config_dir)
		return config_dir.path_join("settings.cfg")

	return "user://settings.cfg"


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_settings_path) != OK:
		save_settings()
		return

	skip_splash = config.get_value(SECTION, "skip_splash", false)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(_settings_path)
	config.set_value(SECTION, "skip_splash", skip_splash)
	config.save(_settings_path)


func set_skip_splash(enabled: bool) -> void:
	skip_splash = enabled
	save_settings()

extends SceneTree
func _initialize() -> void:
	print("USERTMP | user:// -> ", ProjectSettings.globalize_path("user://x.json"))
	print("USERTMP | project name -> ", ProjectSettings.get_setting("application/config/name"))
	quit(0)

extends SceneTree
func _initialize() -> void:
	print("DT | ",OS.get_datetime_string_from_system(false,true))
	quit(0)

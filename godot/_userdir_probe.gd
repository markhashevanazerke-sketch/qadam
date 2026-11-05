extends SceneTree
func _initialize() -> void:
	print("USERDIR | ",ProjectSettings.globalize_path("user://"))
	var d:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://probe_test"))
	var f:=FileAccess.open(ProjectSettings.globalize_path("user://probe_test/hello.txt"),FileAccess.WRITE)
	if f!=null:f.store_string("ok");f.close()
	print("WRITE | ",FileAccess.file_exists(ProjectSettings.globalize_path("user://probe_test/hello.txt")))
	quit(0)

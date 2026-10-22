extends RefCounted
# Exported builds keep speech models and Python beside the executable.
static func root_dir() -> String:
	return OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("res://../")

static func python() -> String:
	var root:=root_dir()
	var bundled:=root.path_join("runtime/windows/python.exe" if OS.get_name()=="Windows" else "runtime/linux/bin/python3")
	if FileAccess.file_exists(bundled):return bundled
	return root.path_join(".voice-venv/Scripts/python.exe" if OS.get_name()=="Windows" else ".voice-venv/bin/python")

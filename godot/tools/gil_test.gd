extends SceneTree
func _init() -> void:
	var ok:bool=true
	var names:=["GiLight3D","OmniLight3D","SpotLight3D"]
	for n in names:
		var c:=ClassDB.class_exists(n)
		print("CLASS ", n, " exists=", c)
		ok = ok and c
	print("DONE")
	quit()

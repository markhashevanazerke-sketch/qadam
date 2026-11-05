extends SceneTree
func run() -> void:
	var model:Node=load("res://assets/characters/girl_natural.glb").instantiate()
	root.add_child(model)
	await process_frame
	var sk:Array=model.find_children("*","Skeleton3D",true,false)
	if sk.is_empty():
		print("BONEK | no skeleton")
		quit(0)
	var s:Skeleton3D=sk[0]
	print("BONEK | count=",s.get_bone_count())
	var n:int=s.get_bone_count()
	for i in n:
		var bn:String=s.get_bone_name(i)
		var pi:int=s.get_bone_parent(i)
		print("BONEK | %d %s parent=%d"%[i,bn,pi])
	quit(0)
func _initialize() -> void:
	call_deferred("run")

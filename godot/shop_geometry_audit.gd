extends SceneTree
func _initialize():
	var result={}
	for id in ["shelf","counter"]:
		var mesh=load("res://assets/cartoon/prepared/"+id+".res")
		var surfaces=[]
		for i in mesh.get_surface_count():
			var a=mesh.surface_get_arrays(i)
			var vertices=[]
			for v in a[Mesh.ARRAY_VERTEX]:vertices.append([v.x,v.y,v.z])
			surfaces.append({"vertices":vertices,"indices":Array(a[Mesh.ARRAY_INDEX])})
		result[id]=surfaces
	var groceries={}
	for i in 29:
		var id="grocery_%02d"%i
		var b=load("res://assets/cartoon/prepared/"+id+".res").get_aabb()
		groceries[id]=[b.size.x,b.size.y,b.size.z]
	result["groceries"]=groceries
	FileAccess.open("/tmp/shop_geometry.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	quit()

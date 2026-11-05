extends SceneTree
func _initialize():
	for id in ["shelf","counter","grocery_00","grocery_01","grocery_02"]:
		var mesh=load("res://assets/cartoon/prepared/"+id+".res")
		print(id," ",mesh.get_aabb())
	var shop=load("res://assets/shops/shop.res")
	for i in shop.get_surface_count():
		var vertices=shop.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		var bounds=AABB(vertices[0],Vector3.ZERO)
		for v in vertices:bounds=bounds.expand(v)
		print(i," ",shop.surface_get_material(i).resource_name," ",bounds)
	quit()

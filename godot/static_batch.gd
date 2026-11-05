extends RefCounted
# Render identical static geometry in one instanced draw per material and spatial cell.
# Original mesh nodes and physics stay intact for door bounds and asset audits.
static func build(root:Node3D,sources:Array,cell_size:float=0) -> void:
	if "--no-static-batching" in OS.get_cmdline_user_args():return
	var groups:Dictionary={}
	var cube:=BoxMesh.new();cube.size=Vector3.ONE
	var inverse:=root.global_transform.affine_inverse()
	for source in sources:
		var node:=source as MeshInstance3D
		if not node or not node.mesh or node.has_meta("render_batched") or node.skin:continue
		var mesh:Mesh=node.mesh
		var transform:Transform3D=inverse*node.global_transform
		if mesh is BoxMesh:
			transform.basis=transform.basis*Basis.from_scale(mesh.size)
			mesh=cube
		var key:=str(mesh.get_instance_id())+":"+str(node.material_override.get_instance_id() if node.material_override else 0)+":"+str(node.cast_shadow)
		for i in mesh.get_surface_count():
			var override:Material=node.get_surface_override_material(i)
			key+=":"+str(override.get_instance_id() if override else 0)
		if cell_size>0:key+=":%d:%d"%[floori(transform.origin.x/cell_size),floori(transform.origin.z/cell_size)]
		if not groups.has(key):groups[key]={"mesh":mesh,"nodes":[],"transforms":[]}
		groups[key].nodes.append(node);groups[key].transforms.append(transform)
	var total:=0;var batches:=0
	for data in groups.values():
		if data.nodes.size()<2:continue
		var original:MeshInstance3D=data.nodes[0]
		var mesh:Mesh=data.mesh
		var needs_copy:=false
		for i in mesh.get_surface_count():
			if original.get_surface_override_material(i):needs_copy=true;break
		if needs_copy:
			mesh=mesh.duplicate()
			for i in mesh.get_surface_count():
				if original.get_surface_override_material(i):mesh.surface_set_material(i,original.get_surface_override_material(i))
		var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=mesh
		instances.instance_count=data.nodes.size()
		for i in data.nodes.size():instances.set_instance_transform(i,data.transforms[i])
		var batch:=MultiMeshInstance3D.new();batch.name="StaticBatch_%03d"%batches
		batch.multimesh=instances;batch.material_override=original.material_override;batch.cast_shadow=original.cast_shadow
		root.add_child(batch)
		for node in data.nodes:
			node.layers=0;node.set_meta("render_batched",batch)
		total+=data.nodes.size();batches+=1
	root.set_meta("batch_source_count",total);root.set_meta("batch_count",batches)
	print("STATIC_BATCH | ",root.name," | objects=",total," | batches=",batches)

extends SceneTree
const Layout=preload("res://district_layout.gd")
func vec(a:Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func arr(v:Vector3) -> Array:return [snappedf(v.x,.001),snappedf(v.y,.001),snappedf(v.z,.001)]
func within(p:Vector3) -> bool:return absf(p.x)<Layout.HALF_WIDTH-.55 and absf(p.z)<Layout.HALF_DEPTH-.55
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.set_physics_process(false);game.town.set_physics_process(false)
	var town=game.town
	var space=town.get_world_3d().direct_space_state
	var templates=JSON.parse_string(FileAccess.get_file_as_string("res://door_templates.json"))
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.75
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	var cells:Dictionary={}
	# Full playable district, not just the smaller NPC route network.
	for x in range(-53,54):
		for z in range(-69,70):
			var p:Vector3=town.to_global(Vector3(x,.08,z))
			query.transform.origin=p+Vector3(0,.89,0)
			if space.intersect_shape(query,1).is_empty():cells[Vector2i(x,z)]=true
	var seen:Dictionary={};var frontier:Array[Vector2i]=[Vector2i(0,38)];seen[frontier[0]]=true
	while not frontier.is_empty():
		var cell:Vector2i=frontier.pop_back()
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if seen.has(next) or not cells.has(next):continue
			query.transform.origin=town.to_global(Vector3(cell.x,.08,cell.y))+Vector3(0,.89,0)
			query.motion=town.global_basis*Vector3(offset.x,0,offset.y)
			if space.cast_motion(query)[0]>.99:seen[next]=true;frontier.append(next)
	query.motion=Vector3.ZERO
	var doors:Array=[];var per_model:Dictionary={};var outside:=0;var reachable:=0
	for i in town.buildings.size():
		var building:Node3D=town.buildings[i]
		var source:String=building.get_meta("source_model","")
		var model:String="cartoon_shop" if building in town.shops else source.get_slice(" / ",1)
		if not templates.has(model):continue
		for template in templates[model]:
			var point:Vector3=building.to_global(vec(template.center))
			var local_point:Vector3=town.to_local(point)
			if not within(local_point):outside+=1;continue
			var normal:Vector3=building.global_basis*vec(template.normal);normal.y=0;normal=normal.normalized()
			var landing:Vector3=point+normal*.85
			var clear:=false
			var connected:=false
			for distance in [.85,1.2,1.6,2.1,2.8]:
				var candidate:Vector3=point+normal*distance;candidate.y=.10
				var floor_ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3(0,1.6,0),candidate-Vector3(0,1,0),1)
				var floor_hit:Dictionary=space.intersect_ray(floor_ray)
				if floor_hit.is_empty():continue
				candidate.y=floor_hit.position.y+.08
				query.transform.origin=candidate+Vector3(0,.89,0);query.motion=Vector3.ZERO
				if not within(town.to_local(candidate)) or not space.intersect_shape(query,1).is_empty():continue
				landing=candidate;clear=true
				var p:Vector3=town.to_local(landing)
				for dx in range(-2,3):
					for dz in range(-2,3):
						var cell:=Vector2i(roundi(p.x)+dx,roundi(p.z)+dz)
						if not seen.has(cell):continue
						var destination:Vector3=town.to_global(Vector3(cell.x,.08,cell.y))
						query.motion=destination-landing
						if space.cast_motion(query)[0]>.99:connected=true;break
					if connected:break
				if connected:break
			query.motion=Vector3.ZERO
			var status:="accessible" if connected else ("landing_clear_route_unconfirmed" if clear else "blocked_approach")
			if connected:reachable+=1
			var label:String=building.get_meta("shop_title",model)
			doors.append({"id":"B%03d_%s"%[i,template.id],"building_index":i,"building":label,"model":model,"template":template.id,"position_world":arr(point),"position_town":arr(local_point),"outward_world":arr(normal),"landing_world":arr(landing),"status":status,"interaction_exists":building in town.shops})
			per_model[model]=per_model.get(model,0)+1
	var report:Dictionary={"scope":"Ground-floor pedestrian door panels physically within the closed playable district. Windows, garage shutters, roof/balcony access and doors beyond the boundary excluded.","method":"Six authored building types visually reviewed on all four sides; door-panel components extracted from source geometry. Approaches checked with player-sized capsule and a connected full-district grid. Unconfirmed/blocked approaches retained for review, never silently discarded.","doors_total":doors.size(),"accessible":reachable,"excluded_beyond_boundary":outside,"reachable_grid_cells":seen.size(),"by_model":per_model,"doors":doors}
	FileAccess.open("res://door_inventory.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DOOR_INVENTORY_READY | total=",doors.size()," | accessible=",reachable," | outside excluded=",outside," | types=",per_model)
	quit()

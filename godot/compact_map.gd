extends Node3D
# Buildings and vehicles are extracted from POLYGON Mini in this project.
# Traffic uses authored Kenney signal models (CC0).
# Baiterek, cartoon citizens and Shop Cartoon are borrowed from astana3d.
const Layout=preload("res://district_layout.gd")
const KIT := "res://assets/nazerke_kit/"
var assets := {}
var static_visuals:Array[MeshInstance3D]=[]
var surface_materials:Dictionary={}
var buildings: Array[Node3D] = []
var vehicles: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var player: Node3D
var landmark: Node3D
var time := 0.0
var traffic:Node
var population:Node
var footprints:Array[AABB]=[]
var paused:=false
var shops:Array[Node3D]=[]
var shop_approaches:Array[Vector3]=[]
var parked_vehicles:Array[Node3D]=[]

func asset(id:String, at:Vector3, scale_by:float=1, angle:float=0, solid:bool=false) -> Node3D:
	if not assets.has(id): assets[id]=load(KIT+id+".glb")
	var n:Node3D=assets[id].instantiate()
	n.name=id
	n.set_meta("source_model","polygon_mini_free.glb / "+id)
	add_child(n)
	n.position=at
	n.scale=Vector3.ONE*scale_by
	n.rotation.y=angle
	if id=="blue_car":
		for child in n.get_children():
			if child is Node3D:child.rotation.y+=.68658856+PI
	if id not in ["blue_car","bus"]:
		for mesh in n.find_children("*","MeshInstance3D",true,false):static_visuals.append(mesh)
	if solid:
		for m in n.find_children("*","MeshInstance3D",true,false): m.create_trimesh_collision()
	return n

func collision(at:Vector3,size:Vector3,label:String="Solid",layer:int=1) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=label
	body.position=at
	body.collision_layer=layer
	var cs:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	cs.shape=shape
	body.add_child(cs)
	add_child(body)
	return body

func surface(at:Vector3,size:Vector2,color:String="") -> Node3D:
	var n:=asset("road_tile",at)
	n.scale=Vector3(size.x/4.327,1,size.y/5.373)
	if color!="":
		if not surface_materials.has(color):
			var shared:=StandardMaterial3D.new();shared.albedo_color=Color(color);shared.roughness=1
			surface_materials[color]=shared
		var material:StandardMaterial3D=surface_materials[color]
		for m in n.find_children("*","MeshInstance3D",true,false):m.material_override=material
	return n

func building(id:String,x:float,z:float,angle:float=0,scale_by:float=1) -> void:
	var n:=asset(id,Vector3(x,.03,z),scale_by,angle,true)
	buildings.append(n)
	var box:=AABB()
	var first:=true
	for mesh in n.find_children("*","MeshInstance3D",true,false):
		var b:AABB=(global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		box=b if first else box.merge(b)
		first=false
	footprints.append(box)

func cartoon_shop(title:String,at:Vector3,angle:float) -> void:
	var root:=Node3D.new();root.name="Shop_"+title;add_child(root)
	root.position=at;root.rotation.y=angle
	root.set_meta("shop_title",title)
	root.set_meta("source_model","astana3d / Shop Cartoon by Saar Designer")
	var mesh:=MeshInstance3D.new();mesh.mesh=preload("res://assets/shops/shop.res");root.add_child(mesh)
	mesh.create_trimesh_collision();static_visuals.append(mesh)
	buildings.append(root);shops.append(root)
	footprints.append((global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb())
	# Original frontage faces +X; leave a clear public approach outside the model.
	shop_approaches.append(to_local(root.to_global(Vector3(4.1,0,0))))
	var label:=Label3D.new();label.text=title;label.font_size=64;label.pixel_size=.009
	label.modulate=Color("fff1ce");label.outline_size=4;label.outline_modulate=Color("263d43")
	label.position=Vector3(1.95,2.8,0);label.rotation.y=PI/2;root.add_child(label)

func road(a:Vector3,b:Vector3,width:float=8) -> void:
	var length:=a.distance_to(b)
	var count:=ceili(length/8)
	for i in count:
		var p:=a.lerp(b,(float(i)+.5)/count)
		p.y=.021
		var n:=surface(p,Vector2(width,length/count+.015))
		n.rotation.y=0 if absf(a.x-b.x)<.1 else PI/2

func _ready() -> void:
	scale=Vector3.ONE*Layout.ENVIRONMENT_SCALE
	# The same original paving mesh spans the horizon: no exposed edge or void.
	surface(Vector3(0,-.012,-22),Vector2(1600,1600),"596461")
	surface(Vector3(0,0,0),Vector2(130,170),"8a8c82")
	collision(Vector3(0,-.5,0),Vector3(180,1,220),"ContinuousGround")
	for x in [-27.0,27.0]:road(Vector3(x,0,-Layout.ROAD_END),Vector3(x,0,Layout.ROAD_END),7.4)
	for z in [-Layout.ROAD_END,0.0,Layout.ROAD_END]:road(Vector3(-30.7,0,z),Vector3(30.7,0,z),7.4)
	for x in [-27.0,27.0]:
		for z in [-Layout.ROAD_END,0.0,Layout.ROAD_END]:surface(Vector3(x,.026,z),Vector2(7.4,7.4),"343d44")
	# Narrow inner courtyards; their passages are connected to the sidewalks.
	for x in [-11.7,11.7]:
		for z in [-24.0,24.0]:surface(Vector3(x,.008,z),Vector2(19.5,33),"718269")
	building("townhouse",-11.7,-30,0,.94)
	building("solar_house",11.7,-30,PI,1.02)
	building("apartment",-11.7,30,PI,.96)
	building("shops",11.7,30,0,1.13)
	building("shops",-11.7,-12,0,1.10)
	building("townhouse",11.7,-12,PI,.94)
	building("solar_house",-11.7,13,0,1.0)
	building("apartment",11.7,13,PI,.96)
	for site in Layout.SHOP_SITES:cartoon_shop(site[0],site[1],site[2])
	# Closely spaced frontages, with a second row closing the view between them.
	for side in [-1,1]:
		for i in 7:
			if side==-1 and i==3:continue # Central-west plot belongs to the cartoon shop.
			var id:String=["round_tower","apartment","shops","townhouse","apartment","shops","square_tower"][i]
			# Open a fitted northwest shop gap, then close the central frontage around DÜKEN.
			var frontage_z:float=[-58,-32,-13.5,0,15.5,36,54][i] if side==-1 else -54+i*18
			building(id,side*41.5,frontage_z,PI/2 if i in [1,2,3,4] else 0,1.0)
		for i in 15:
			building("square_tower",side*58,-84+i*12,0,1.25)
			buildings.back().scale.y*=.83+(i%4)*.12
		for i in 9:
			building("round_tower" if i%3==0 else "apartment",side*74,-84+i*21,PI/2,1.2)
	for z in [-68.0,68.0]:
		for i in 7:
			var x:float=-45+i*15
			building("shops" if i==3 else "apartment",x,z,PI if z>0 else 0,1.05)
		for i in 8:
			building("townhouse",-53+i*15,z+signf(z)*15,0,1.1)
	# A familiar silhouette above the northern rooftops, outside the playable district.
	landmark=load("res://assets/models/baiterek.glb").instantiate()
	landmark.name="Baiterek_Backdrop"
	add_child(landmark)
	var bounds:=AABB()
	var first:=true
	for m in landmark.find_children("*","MeshInstance3D",true,false):
		var box:AABB=(global_transform.affine_inverse()*m.global_transform)*m.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	var factor:=48.0/bounds.size.y
	landmark.scale=Vector3.ONE*factor
	landmark.position=Vector3(0,0,-98)-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	landmark.set_meta("source_model","astana3d/assets/models/baiterek.glb")
	for z in [-Layout.HALF_DEPTH,Layout.HALF_DEPTH]:collision(Vector3(0,15,z),Vector3(112,30,1),"DistrictBoundary")
	for x in [-Layout.HALF_WIDTH,Layout.HALF_WIDTH]:collision(Vector3(x,15,0),Vector3(1,30,Layout.HALF_DEPTH*2),"DistrictBoundary")
	for x in [-4.0,4.0]:
		for z in [-40.0,-22.0,22.0,40.0]:asset("tree",Vector3(x,0,z),.8,float(z))
	for x in [-22.0,22.0,-32.5,32.5]:
		for z in [-47.0,-29.0,-14.0,14.0,29.0,47.0]:
			var lamp_z:float=-50.5 if x==-32.5 and z==-47 else z
			asset("lamp",Vector3(x,0,lamp_z),1,PI if x<0 else 0,true)
			var light:=OmniLight3D.new()
			light.position=Vector3(x,4.0,lamp_z)
			light.light_color=Color("ffcc87")
			light.light_energy=.8
			light.omni_range=8
			add_child(light)
	for x in [-34.0,34.0]:
		for z in [-58.0,-33.0,33.0,58.0]:asset("small_tree",Vector3(x,0,z),1.1)
	# Markings are flat instances of the project's existing road surface.
	for x in [-27.0,27.0]:
		for z in [-8.0,8.0]:
			for stripe in 7:surface(Vector3(x-3+stripe,.035,z),Vector2(.5,2.0),"c9c6ad")
	for stripe in 7:surface(Vector3(0,.035,-3+stripe),Vector2(2,.5),"c9c6ad")
	# Real source cars in parking pockets; their fronts use the same corrected axis.
	park_car(Vector3(-21.8,.035,41.5),0)
	park_car(Vector3(21.8,.035,-41.5),PI)
	# Appended after existing buildings so saved residential IDs remain stable.
	cartoon_shop("",Vector3(-40,.035,28.35),PI/2)
	shops.back().set_meta("shop_title","Бос дүкен")
	traffic=Node.new()
	traffic.set_script(preload("res://district_traffic.gd"))
	add_child(traffic)
	population=Node.new()
	population.set_script(preload("res://district_population.gd"))
	add_child(population)
	preload("res://static_batch.gd").build(self,static_visuals,28.0)
	print("DENSE_DISTRICT_READY | buildings=",buildings.size()," | authored Nazerke models | cartoon citizens")

func sample(points:Array[Vector3],distance:float) -> Dictionary:
	for i in points.size():
		var a:Vector3=points[i]
		var b:Vector3=points[(i+1)%points.size()]
		var length:=a.distance_to(b)
		if distance<=length:return {"at":a.lerp(b,distance/length),"dir":(b-a).normalized()}
		distance-=length
	return {"at":points[0],"dir":Vector3.FORWARD}

func _physics_process(delta:float) -> void:
	if paused:return
	time+=delta
	traffic.tick(delta)
	population.tick(delta)

func park_car(at:Vector3,angle:float) -> void:
	# Authored road mesh makes a marked pocket outside the moving lanes.
	surface(Vector3(at.x,.028,at.z),Vector2(2.3,5.2),"626b6b")
	for side in [-1,1]:
		surface(Vector3(at.x+side*1.1,.036,at.z),Vector2(.07,5.1),"c9c6ad")
		surface(Vector3(at.x,.036,at.z+side*2.55),Vector2(2.2,.07),"c9c6ad")
	var car:=asset("blue_car",at,1/Layout.ENVIRONMENT_SCALE,angle,true)
	car.name="ParkedCar_%d"%parked_vehicles.size()
	parked_vehicles.append(car)
	# Use transformed vertices: rotating a precomputed source AABB overestimates width.
	var bounds:=AABB();var first:=true
	for mesh in car.find_children("*","MeshInstance3D",true,false):
		var transform:Transform3D=global_transform.affine_inverse()*mesh.global_transform
		for surface_id in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface_id)[Mesh.ARRAY_VERTEX]:
				var point:Vector3=transform*vertex
				if first:bounds=AABB(point,Vector3.ZERO);first=false
				else:bounds=bounds.expand(point)
	car.set_meta("local_bounds",bounds)
	footprints.append(bounds)

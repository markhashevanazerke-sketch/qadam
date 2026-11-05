extends Node3D
# Separate, human-scale room furnished with the artist-made astana3d assets.
const ASSETS="res://assets/cartoon/prepared/"
const ENTRY=Vector3(0,.08,4.5)
const EXIT=Vector3(0,1.2,5.82)
var title:=""
var sale_sign:Label3D
var props:Array[MeshInstance3D]=[]
var interior_environment:Environment
var cashier:Node3D
var cashier_body:StaticBody3D
var checkout:MeshInstance3D
var checkout_approach:=Vector3.ZERO
var layout_id:=0

func block(label:String,at:Vector3,size:Vector3,color:Color,solid:bool=true) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=label
	var box:=BoxMesh.new();box.size=size;mesh.mesh=box
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.85
	mesh.material_override=material;add_child(mesh);mesh.position=at
	if solid:mesh.create_trimesh_collision()
	return mesh

func text_label(words:String,at:Vector3,size:int=52,angle:float=0,color:Color=Color("fff3d6")) -> Label3D:
	var label:=Label3D.new();label.text=words;label.font_size=size;label.pixel_size=.008
	label.modulate=color;label.outline_size=0;add_child(label);label.position=at;label.rotation.y=angle
	return label

func prop(id:String,at:Vector3,angle:float=0,factor:float=1,solid:bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.mesh=load(ASSETS+id+".res");mesh.name=id;mesh.set_meta("asset_id",id)
	add_child(mesh);mesh.position=at;mesh.rotation.y=angle;mesh.scale=Vector3.ONE*factor
	if solid:mesh.create_trimesh_collision()
	props.append(mesh)
	return mesh

func stocked_shelf(at:Vector3,angle:float,seed_id:int) -> void:
	var shelf:=prop("shelf",at,angle)
	shelf.scale=Vector3(1.4,1.2,1.6)
	shelf.create_trimesh_collision()
	# Actual upper faces of the four boards in the authored shelf mesh.
	var levels:=[.0929,.5609,.9451,1.34,1.7413]
	for tier in 4:
		var floor_y:float=levels[tier]*shelf.scale.y
		var clearance:float=(levels[tier+1]-levels[tier])*shelf.scale.y-.07
		for col in 3:
			var id:="grocery_%02d"%((seed_id+tier*3+col)%29)
			var product:=prop(id,Vector3.ZERO)
			var bounds: AABB=product.mesh.get_aabb()
			# Fit all three dimensions, including broad egg cartons and multipacks.
			var factor:float=minf(1.15,minf(.46/bounds.size.x,minf(.54/bounds.size.z,clearance/bounds.size.y)))
			var slot:=Vector3(-.52+col*.52,floor_y+.008,.0416)
			var offset:=slot-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
			product.position=at+Basis(Vector3.UP,angle)*offset
			product.rotation.y=angle;product.scale=Vector3.ONE*factor
			product.set_meta("shelf",shelf)
			product.set_meta("board_y",floor_y)

func build(shop_title:String,index:int) -> void:
	title=shop_title
	var accent:Color=[Color("356965"),Color("ac684c"),Color("52688b")][mini(index,2)]
	block("Floor",Vector3(0,-.12,0),Vector3(10.4,.24,12.4),Color("d8c9ae"))
	# Solid walls and ceiling completely enclose the off-map room.
	block("WestWall",Vector3(-5.1,1.8,0),Vector3(.2,3.6,12.4),Color("efe2c7"))
	block("EastWall",Vector3(5.1,1.8,0),Vector3(.2,3.6,12.4),Color("efe2c7"))
	block("BackWall",Vector3(0,1.8,-6.1),Vector3(10.4,3.6,.2),Color("efe2c7"))
	block("FrontWall",Vector3(0,1.8,6.1),Vector3(10.4,3.6,.2),Color("efe2c7"))
	block("Ceiling",Vector3(0,3.7,0),Vector3(10.4,.2,12.4),Color("e6dac0"))
	for x in [-4.985,4.985]:block("WallTrim",Vector3(x,.53,0),Vector3(.025,1.06,12),accent,false)
	for z in [-5.985,5.985]:block("WallTrim",Vector3(0,.53,z),Vector3(10,1.06,.025),accent,false)
	# Tile joints and ceiling fixtures are architectural details, not replacement props.
	for x in range(-4,5,2):block("FloorJoint",Vector3(x,.002,0),Vector3(.012,.003,12),Color("b8a98f"),false)
	for z in range(-4,6,2):block("FloorJoint",Vector3(0,.002,z),Vector3(10,.003,.012),Color("b8a98f"),false)
	block("DoorFrame",Vector3(0,1.32,5.92),Vector3(1.7,2.64,.13),accent)
	block("ExitDoor",Vector3(0,1.23,5.83),Vector3(1.38,2.46,.08),Color("ab8a60"))
	block("DoorGlass",Vector3(0,1.67,5.775),Vector3(1.08,1.05,.025),Color("a9d6d4"),false)
	block("DoorHandle",Vector3(-.48,1.0,5.70),Vector3(.07,.3,.1),Color("e6d9b3"),false)
	text_label("ШЫҒУ",Vector3(0,2.95,5.8),36,PI,accent)
	if index<3:
		block("BackSign",Vector3(0,2.85,-5.88),Vector3(6.2,.76,.08),accent,false)
		text_label(title+"  /  АЗЫҚ-ТҮЛІК",Vector3(0,2.86,-5.81),50)
		text_label("КҮН САЙЫН БАЛҒЫН",Vector3(0,2.25,-5.80),28,0,accent)
	layout_id=index
	match index:
		0: # BEREKE: two long rows; checkout at the front right.
			for x in [-3.3,-1.1,1.1,3.3]:stocked_shelf(Vector3(x,0,-5.5),0,7+int(absf(x)*3))
			for z in [-2.9,-.65]:
				stocked_shelf(Vector3(-4.55,0,z),PI/2,4)
				stocked_shelf(Vector3(4.55,0,z),-PI/2,10)
				stocked_shelf(Vector3(-1.8,0,z),PI/2,3)
				stocked_shelf(Vector3(1.8,0,z),-PI/2,14)
			add_checkout(Vector3(2.8,0,2.8),-PI/6,Vector3(3.52,0,2.12),PI/2,"erlan",2,Vector3(1.0,.08,2.7))
			text_label("КАССА",Vector3(4.97,2.45,2.5),40,-PI/2,accent)
		1: # DÜKEN: crosswise displays; checkout on the opposite side.
			for x in [-3.3,-1.1,1.1,3.3]:stocked_shelf(Vector3(x,0,-5.5),0,18+int(absf(x)*2))
			for z in [-3.0,-.65]:
				stocked_shelf(Vector3(-4.55,0,z),PI/2,9)
				stocked_shelf(Vector3(4.55,0,z),-PI/2,21)
				stocked_shelf(Vector3(-2.0,0,z),0,17)
				stocked_shelf(Vector3(2.0,0,z),0,24)
			add_checkout(Vector3(-2.8,0,2.8),5*PI/6,Vector3(-3.52,0,3.48),-PI/2,"erlan",4,Vector3(-1.0,.08,2.7))
			text_label("КАССА",Vector3(-4.97,2.45,2.5),40,PI/2,accent)
		2: # KÖRŞI: an open front area, staggered wall display and rear checkout.
			for x in [-3.3,-1.1,1.1]:stocked_shelf(Vector3(x,0,-5.5),0,5+int(absf(x)*3))
			for z in [-3.1,-.75,1.6]:stocked_shelf(Vector3(-4.55,0,z),PI/2,12)
			for z in [-.5,1.85]:stocked_shelf(Vector3(4.55,0,z),-PI/2,19)
			for z in [-1.8,.4]:
				stocked_shelf(Vector3(-1.65,0,z),0,6)
				stocked_shelf(Vector3(1.65,0,z),0,22)
			add_checkout(Vector3(2.8,0,-3.4),-PI/6,Vector3(3.52,0,-4.08),PI/2,"asel",6,Vector3(1.0,.08,-3.5))
			text_label("КАССА",Vector3(4.97,2.45,-3.5),40,-PI/2,accent)
		3:
			add_cashier(Vector3(1.3,0,.0),PI,"erlan",7)
			sale_sign=text_label("САТЫЛАДЫ · 1 000 000 ₸",Vector3(0,2.6,-5.80),35,0,accent)
	for x in [-2.5,2.5]:
		for z in [-3.5,2.0]:
			var fixture:=block("CeilingLight",Vector3(x,3.54,z),Vector3(1.45,.09,.45),Color("fff3cf"),false)
			var mat:StandardMaterial3D=fixture.material_override
			mat.emission_enabled=true;mat.emission=Color("ffecc0");mat.emission_energy_multiplier=1.5
			var light:=OmniLight3D.new();add_child(light);light.position=Vector3(x,3.22,z)
			light.light_color=Color("ffe4ba");light.light_energy=1.05;light.omni_range=9
	interior_environment=Environment.new()
	interior_environment.background_mode=Environment.BG_COLOR
	interior_environment.background_color=Color("262e31")
	interior_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	interior_environment.ambient_light_color=Color("fff0d4")
	interior_environment.ambient_light_energy=.65
	interior_environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	# The cashier is animated; only static artist props join the instancing batches.
	preload("res://static_batch.gd").build(self,props)
	visible=false

func add_checkout(at:Vector3,angle:float,clerk_at:Vector3,clerk_angle:float,character:String,outfit:int,approach:Vector3) -> void:
	# Preserve the artist's counter and the original human scale.
	checkout=prop("counter",at,angle,1,true)
	checkout_approach=approach
	add_cashier(clerk_at,clerk_angle,character,outfit)

func add_cashier(clerk_at:Vector3,clerk_angle:float,character:String,outfit:int) -> void:
	cashier=Node3D.new();cashier.name="Cashier";cashier.set_script(preload("res://citizen_visual.gd"))
	cashier.character_id=character;cashier.outfit_variant=outfit;cashier.initial_motion="idle"
	add_child(cashier);cashier.position=clerk_at;cashier.rotation.y=clerk_angle
	cashier.animation.active=false
	cashier_body=StaticBody3D.new();cashier_body.name="CashierBody";cashier_body.collision_layer=1
	cashier.add_child(cashier_body)
	var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.3;capsule.height=1.75;collider.shape=capsule;collider.position.y=.875
	cashier_body.add_child(collider)

func update_cashier(camera:Camera3D,delta:float,active:bool) -> void:
	if not active:
		cashier.animation.active=false
		return
	cashier.update_detail(camera,delta)
	cashier.play_motion("idle")

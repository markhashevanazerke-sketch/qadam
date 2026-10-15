extends Node3D
# Human-scale homes: original low-poly furniture plus credited astana3d props.
const TITLES=["ЖАЙЛЫ ҮЙ", "ОТБАСЫ ҮЙІ", "Пәтер · Жылы кеш", "Шағын пәтер · Қала көрінісі", "Пәтер · Ымырт"]
const SIZES=[Vector2(8,9),Vector2(10,11),Vector2(8,9),Vector2(7,8),Vector2(10,10)]
var title:String
var variant:int
var size:Vector2
var entry:Vector3
var exit_point:Vector3
var interior_environment:Environment
var walk_targets:Array[Vector3]=[]
var materials:Dictionary={}
var accent:Color
var wood:=Color("956747")

func material(color:Color) -> StandardMaterial3D:
	if not materials.has(color):
		var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9
		materials[color]=m
	return materials[color]

func box(parent:Node3D,label:String,at:Vector3,dimensions:Vector3,color:Color,solid:bool=true) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label
	var mesh:=BoxMesh.new();mesh.size=dimensions;node.mesh=mesh;node.material_override=material(color)
	parent.add_child(node);node.position=at
	if solid:
		var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new()
		bounds.size=dimensions;shape.shape=bounds;body.add_child(shape);node.add_child(body)
	return node

func group(label:String,at:Vector3,angle:float=0) -> Node3D:
	var node:=Node3D.new();node.name=label;add_child(node);node.position=at;node.rotation.y=angle
	return node

func label_at(words:String,at:Vector3,angle:float=0) -> void:
	var label:=Label3D.new();label.text=words;label.font_size=32;label.pixel_size=.004
	label.modulate=Color("f3dfb8");label.outline_size=0;add_child(label);label.position=at;label.rotation.y=angle

func art_prop(parent:Node3D,id:String,at:Vector3,fit:Vector3) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=load("res://assets/cartoon/prepared/"+id+".res")
	node.set_meta("asset_id",id);parent.add_child(node)
	var bounds:=node.mesh.get_aabb()
	var factor:=minf(fit.x/bounds.size.x,minf(fit.y/bounds.size.y,fit.z/bounds.size.z))
	node.scale=Vector3.ONE*factor
	node.position=at-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	return node

func shelf(at:Vector3,angle:float=0) -> void:
	var node:=group("AstanaBookshelf",at,angle)
	var mesh:=art_prop(node,"shelf",Vector3.ZERO,Vector3(1.5,1.85,.48));mesh.create_trimesh_collision()
	for tier in 4:
		var y:float=[.095,.564,.949,1.343][tier]
		for i in 5:
			box(node,"Book",Vector3(-.43+i*.19,y+.13,.04),Vector3(.125,.26+(i%2)*.07,.22),[accent,Color("c27b54"),Color("ede0bb")][(tier+i)%3],false)
	art_prop(node,"grocery_03",Vector3(0,1.75,0),Vector3(.3,.22,.3))

func sofa(at:Vector3,angle:float=0) -> void:
	var node:=group("Sofa",at,angle)
	box(node,"Base",Vector3(0,.26,0),Vector3(2.18,.3,.85),wood)
	box(node,"Back",Vector3(0,.71,-.34),Vector3(2.2,.78,.2),accent)
	for x in [-1.03,1.03]:box(node,"Arm",Vector3(x,.55,0),Vector3(.2,.5,.9),accent)
	for x in [-.49,.49]:
		box(node,"Seat",Vector3(x,.46,.04),Vector3(.94,.2,.73),accent.lightened(.14))
		var cushion:=box(node,"Cushion",Vector3(x,.77,-.12),Vector3(.5,.42,.14),Color("e6cf9e"),false);cushion.rotation.z=x*.2
	for x in [-.87,.87]:
		for z in [-.29,.29]:box(node,"Foot",Vector3(x,.1,z),Vector3(.1,.2,.1),wood,false)

func table(at:Vector3,angle:float=0,dining:bool=false) -> void:
	var node:=group("DiningTable" if dining else "CoffeeTable",at,angle)
	var h:=.76 if dining else .43
	box(node,"Top",Vector3(0,h,0),Vector3(1.25,.09,.7),wood)
	for x in [-.51,.51]:
		for z in [-.23,.23]:box(node,"Leg",Vector3(x,h/2,z),Vector3(.08,h,.08),wood)
	if dining:
		for x in [-.9,.9]:
			box(node,"ChairSeat",Vector3(x,.46,0),Vector3(.48,.1,.5),accent)
			box(node,"ChairBack",Vector3(x+signf(x)*.21,.77,0),Vector3(.08,.64,.5),accent)
			for z in [-.18,.18]:box(node,"ChairLeg",Vector3(x,.23,z),Vector3(.36,.46,.06),wood)
		art_prop(node,"grocery_03",Vector3(.2,h+.05,0),Vector3(.23,.25,.23))
		art_prop(node,"grocery_14",Vector3(-.2,h+.05,0),Vector3(.22,.18,.22))
	else:
		box(node,"Book",Vector3(-.2,h+.07,0),Vector3(.36,.05,.25),accent,false)
		art_prop(node,"grocery_03",Vector3(.3,h+.05,0),Vector3(.2,.22,.2))

func bed(at:Vector3,angle:float=0,single:bool=false) -> void:
	var node:=group("SingleBed" if single else "DoubleBed",at,angle)
	var w:=1.05 if single else 1.65
	box(node,"Frame",Vector3(0,.23,0),Vector3(w+.12,.38,2.16),wood)
	box(node,"Headboard",Vector3(0,.61,-1.06),Vector3(w+.18,1.1,.12),wood)
	box(node,"Mattress",Vector3(0,.5,0),Vector3(w,.22,2.04),Color("f4e8d3"))
	box(node,"Blanket",Vector3(0,.625,.35),Vector3(w+.025,.05,1.25),accent,false)
	for z in [.03,.1,.66,.73]:box(node,"WovenStripe",Vector3(0,.654,z),Vector3(w+.03,.009,.028),Color("e5c794"),false)
	if single:box(node,"Pillow",Vector3(0,.65,-.68),Vector3(.7,.17,.42),Color("fff0d7"),false)
	else:
		for x in [-.43,.43]:box(node,"Pillow",Vector3(x,.65,-.68),Vector3(.65,.17,.42),Color("fff0d7"),false)

func kitchen(at:Vector3,angle:float=0) -> void:
	var node:=group("Kitchen",at,angle)
	for x in [-.87,0,.87]:
		box(node,"Cabinet",Vector3(x,.43,0),Vector3(.83,.86,.64),accent)
		box(node,"Front",Vector3(x,.44,.332),Vector3(.75,.72,.035),accent.lightened(.12),false)
		box(node,"Handle",Vector3(x,.74,.37),Vector3(.25,.035,.05),Color("e1c69a"),false)
		box(node,"WallCupboard",Vector3(x,1.93,-.13),Vector3(.82,.68,.35),Color("dac5a0"))
		box(node,"CupboardSeam",Vector3(x,1.93,.051),Vector3(.012,.62,.01),wood,false)
	box(node,"Countertop",Vector3(0,.91,0),Vector3(2.65,.1,.71),Color("e9dfc8"))
	box(node,"SinkRim",Vector3(.85,.97,0),Vector3(.57,.018,.43),Color("aab8b4"),false)
	box(node,"SinkBowl",Vector3(.85,.982,0),Vector3(.43,.01,.31),Color("4e777d"),false)
	box(node,"Tap",Vector3(.85,1.12,-.24),Vector3(.04,.3,.04),Color("b8c5c0"),false)
	box(node,"TapSpout",Vector3(.85,1.26,-.15),Vector3(.04,.04,.2),Color("b8c5c0"),false)
	box(node,"Cooktop",Vector3(-.88,.972,0),Vector3(.67,.025,.53),Color("263c45"),false)
	for x in [-1.04,-.73]:
		for z in [-.14,.14]:box(node,"Burner",Vector3(x,.99,z),Vector3(.21,.015,.19),Color("596875"),false)
	box(node,"Oven",Vector3(-.87,.43,.36),Vector3(.63,.43,.035),Color("293b45"),false)
	art_prop(node,"grocery_14",Vector3(0,.97,.04),Vector3(.27,.22,.3))

func fridge(at:Vector3,angle:float=0) -> void:
	var node:=group("Fridge",at,angle)
	box(node,"Body",Vector3(0,.93,0),Vector3(.69,1.86,.68),Color("ece6d5"))
	box(node,"DoorSeam",Vector3(0,1.32,.345),Vector3(.65,.018,.015),Color("a5aaa0"),false)
	for y in [.95,1.52]:box(node,"Handle",Vector3(-.23,y,.39),Vector3(.04,.26,.06),accent,false)
	box(node,"Note",Vector3(.1,1.65,.353),Vector3(.22,.16,.012),Color("d9a45f"),false)

func rug(at:Vector3,dimensions:Vector2) -> void:
	box(self,"Carpet",at+Vector3(0,.012,0),Vector3(dimensions.x,.018,dimensions.y),accent.darkened(.1),false)
	for x in [-1,1]:
		box(self,"CarpetBorder",at+Vector3(x*(dimensions.x/2-.12),.024,0),Vector3(.035,.008,dimensions.y-.15),Color("ddbf8b"),false)
	for z in [-1,1]:box(self,"CarpetBorder",at+Vector3(0,.024,z*(dimensions.y/2-.12)),Vector3(dimensions.x-.15,.008,.035),Color("ddbf8b"),false)

func window_at(at:Vector3,angle:float=0) -> void:
	var node:=group("EveningWindow",at,angle)
	box(node,"Frame",Vector3.ZERO,Vector3(2.2,1.55,.11),wood,false)
	box(node,"Sky",Vector3(0,0,.065),Vector3(2.02,1.38,.02),Color("869fa9"),false)
	box(node,"Sunset",Vector3(0,-.46,.08),Vector3(2.02,.4,.012),Color("d9b997"),false)
	for i in 7:
		var h:float=.15+(i%3)*.13
		box(node,"DistantRoof",Vector3(-.87+i*.29,-.65+h/2,.094),Vector3(.24,h,.012),Color("687d8a"),false)
	box(node,"Mullion",Vector3(0,0,.12),Vector3(.055,1.48,.035),Color("eee1c8"),false)
	box(node,"Sill",Vector3(0,-.79,.16),Vector3(2.3,.07,.36),Color("eee1c8"),false)
	for x in [-1.16,1.16]:box(node,"Curtain",Vector3(x,.0,.18),Vector3(.22,1.82,.06),accent.lightened(.32),false)

func picture(at:Vector3,angle:float=0) -> void:
	var node:=group("SteppePrint",at,angle)
	box(node,"Frame",Vector3.ZERO,Vector3(1.25,.8,.06),wood,false)
	box(node,"Canvas",Vector3(0,0,.038),Vector3(1.13,.68,.018),Color("dabb89"),false)
	box(node,"Horizon",Vector3(0,-.19,.052),Vector3(1.13,.29,.012),accent,false)
	var sun:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.14;mesh.bottom_radius=.14;mesh.height=.012;mesh.radial_segments=12
	sun.mesh=mesh;sun.material_override=material(Color("f8df9e"));node.add_child(sun);sun.position=Vector3(.28,.13,.066);sun.rotation.x=PI/2

func plant(at:Vector3) -> void:
	var node:=group("Plant",at)
	box(node,"Pot",Vector3(0,.16,0),Vector3(.32,.32,.32),Color("be825f"))
	box(node,"Stem",Vector3(0,.53,0),Vector3(.045,.62,.045),wood,false)
	for i in 3:
		var leaf:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.23;mesh.height=.43;mesh.radial_segments=6;mesh.rings=3
		leaf.mesh=mesh;leaf.material_override=material(Color("658c67").lightened(i*.08));node.add_child(leaf)
		leaf.position=Vector3(sin(i*2.1)*.17,.53+i*.15,cos(i*2.1)*.12)

func bathroom(at:Vector3,angle:float=0) -> void:
	# 2.7 x 2.4 m pod, front entrance is a clear 1.2 m opening.
	var n:=group("Bathroom",at,angle)
	box(n,"TileFloor",Vector3(0,.008,0),Vector3(2.7,.016,2.4),Color("b3c3bd"),false)
	for x in [-1.35,1.35]:box(n,"Wall",Vector3(x,1.5,0),Vector3(.12,3,2.4),Color("d5ddd0"))
	box(n,"Back",Vector3(0,1.5,-1.2),Vector3(2.82,3,.12),Color("d5ddd0"))
	for x in [-.99,.99]:box(n,"DoorSide",Vector3(x,1.5,1.2),Vector3(.72,3,.12),Color("e5dcc3"))
	box(n,"Lintel",Vector3(0,2.65,1.2),Vector3(1.26,.7,.12),Color("e5dcc3"))
	box(n,"ToiletBase",Vector3(-.65,.22,-.5),Vector3(.4,.44,.62),Color("f6edda"))
	box(n,"ToiletSeat",Vector3(-.65,.46,-.44),Vector3(.48,.08,.58),Color("fff7e9"))
	box(n,"Cistern",Vector3(-.65,.62,-.89),Vector3(.5,.6,.2),Color("f6edda"))
	box(n,"Vanity",Vector3(.65,.4,-.79),Vector3(.8,.8,.64),wood)
	box(n,"Basin",Vector3(.65,.85,-.79),Vector3(.85,.1,.7),Color("f3edda"))
	box(n,"Tap",Vector3(.65,1.02,-1.03),Vector3(.04,.25,.04),Color("b8c5c0"),false)
	box(n,"TapSpout",Vector3(.65,1.14,-.89),Vector3(.04,.04,.3),Color("b8c5c0"),false)
	box(n,"BasinInset",Vector3(.65,.91,-.74),Vector3(.55,.015,.4),Color("86aaa8"),false)
	box(n,"MirrorFrame",Vector3(.65,1.65,-1.12),Vector3(.86,.9,.055),wood,false)
	box(n,"Mirror",Vector3(.65,1.65,-1.08),Vector3(.76,.8,.02),Color("b5d2cf"),false)
	box(n,"Towel",Vector3(1.27,1.3,.15),Vector3(.045,.65,.4),accent,false)

func partition_x(x:float,z0:float,z1:float) -> void:
	box(self,"Partition",Vector3(x,1.5,(z0+z1)/2),Vector3(.13,3,z1-z0),Color("e6dac1"))
	box(self,"PartitionTrim",Vector3(x,.065,(z0+z1)/2),Vector3(.16,.13,z1-z0),wood,false)
func partition_z(z:float,x0:float,x1:float) -> void:
	box(self,"Partition",Vector3((x0+x1)/2,1.5,z),Vector3(x1-x0,3,.13),Color("e6dac1"))
	box(self,"PartitionTrim",Vector3((x0+x1)/2,.065,z),Vector3(x1-x0,.13,.16),wood,false)

func build(index:int) -> void:
	variant=index;title=TITLES[index];size=SIZES[index]
	accent=[Color("607d69"),Color("ac7056"),Color("be8750"),Color("527e88"),Color("586f98")][index]
	entry=Vector3(0,.08,size.y/2-1.15);exit_point=Vector3(0,1.2,size.y/2-.1)
	box(self,"Floor",Vector3(0,-.12,0),Vector3(size.x+.4,.24,size.y+.4),Color("c5a57e"))
	box(self,"Ceiling",Vector3(0,3.12,0),Vector3(size.x+.4,.24,size.y+.4),Color("eee6d3"))
	for x in [-size.x/2-.1,size.x/2+.1]:box(self,"OuterWall",Vector3(x,1.5,0),Vector3(.2,3,size.y+.4),Color("ece1c8"))
	for z in [-size.y/2-.1,size.y/2+.1]:box(self,"OuterWall",Vector3(0,1.5,z),Vector3(size.x+.4,3,.2),Color("ece1c8"))
	for x in [-size.x/2+.025,size.x/2-.025]:box(self,"Skirting",Vector3(x,.07,0),Vector3(.05,.14,size.y),wood,false)
	for z in [-size.y/2+.025,size.y/2-.025]:box(self,"Skirting",Vector3(0,.07,z),Vector3(size.x,.14,.05),wood,false)
	for i in int(size.x*2):box(self,"Floorboard",Vector3(-size.x/2+i*.5,.001,0),Vector3(.012,.002,size.y),Color("b3916b"),false)
	box(self,"DoorFrame",Vector3(0,1.16,size.y/2-.045),Vector3(1.3,2.32,.1),wood,false)
	box(self,"ExitDoor",Vector3(0,1.1,size.y/2-.11),Vector3(1.12,2.2,.055),accent,false)
	box(self,"DoorHandle",Vector3(-.39,.98,size.y/2-.18),Vector3(.18,.045,.08),Color("dfbe7f"),false)
	label_at("ШЫҒУ",Vector3(0,2.5,size.y/2-.12),PI)
	box(self,"Doormat",Vector3(0,.012,size.y/2-.6),Vector3(1.3,.018,.6),wood,false)
	match index:
		0:
			bed(Vector3(-2.65,0,-3.1));partition_x(-.65,-4.5,-1.6)
			partition_z(-1.6,-4,-2.45)
			kitchen(Vector3(1.5,0,-4.1));fridge(Vector3(3.45,0,-4.05))
			sofa(Vector3(3.3,0,.25),-PI/2);table(Vector3(1.8,0,.25),PI/2)
			rug(Vector3(2.05,0,.25),Vector2(2.8,3))
			shelf(Vector3(-3.7,0,.0),PI/2);bathroom(Vector3(-2.55,0,3.15),PI)
			window_at(Vector3(-2.3,1.9,-4.47));picture(Vector3(3.96,1.95,1.0),-PI/2)
			plant(Vector3(3.5,0,3.8));walk_targets=[Vector3(-1.25,.08,-2.9),Vector3(1.4,.08,-2.7),Vector3(1,.08,.5),Vector3(-2.55,.08,2.6)]
		1:
			partition_x(0,-5.5,-1.5)
			partition_z(-1.5,-5,-3.3);partition_z(-1.5,-1.9,1.9);partition_z(-1.5,3.3,5)
			bed(Vector3(-3,0,-4));bed(Vector3(3.6,0,-4),0,true);bed(Vector3(1.6,0,-4),0,true)
			shelf(Vector3(-.5,0,-3.9),-PI/2)
			kitchen(Vector3(-4.55,0,.2),PI/2);fridge(Vector3(-4.5,0,2.05),PI/2)
			sofa(Vector3(4.25,0,2.4),-PI/2);table(Vector3(2.65,0,2.4),PI/2)
			rug(Vector3(2.75,0,2.4),Vector2(2.9,3.2));table(Vector3(-1.8,0,.1),0,true)
			bathroom(Vector3(-3.55,0,4.15),PI)
			window_at(Vector3(-3,1.85,-5.47));window_at(Vector3(3,1.85,-5.47));picture(Vector3(4.96,1.95,2.4),-PI/2)
			plant(Vector3(4.4,0,4.8));walk_targets=[Vector3(-2.6,.08,-2.5),Vector3(2.6,.08,-2.5),Vector3(-3.1,.08,1.4),Vector3(1.6,.08,2.5),Vector3(-3.55,.08,3.6)]
		2:
			partition_x(.65,-4.5,-1.2);partition_z(-.1,2.1,4)
			bed(Vector3(2.35,0,-3.15));shelf(Vector3(3.7,0,-.85),-PI/2)
			kitchen(Vector3(-2,0,-4.08));fridge(Vector3(-.15,0,-4.03))
			sofa(Vector3(-3.3,0,-.55),PI/2);table(Vector3(-1.8,0,-.55),PI/2)
			rug(Vector3(-2,0,-.55),Vector2(2.7,3));bathroom(Vector3(2.55,0,3.15),PI)
			table(Vector3(-2.3,0,2.6),0,true)
			window_at(Vector3(2.3,1.85,-4.47));picture(Vector3(-3.96,1.95,-.55),PI/2)
			plant(Vector3(-3.5,0,3.8));walk_targets=[Vector3(1.35,.08,-1.4),Vector3(-1.8,.08,-2.65),Vector3(-.65,.08,.6),Vector3(2.55,.08,2.6)]
		3:
			kitchen(Vector3(-1.65,0,-3.58));fridge(Vector3(.2,0,-3.53))
			bed(Vector3(2.4,0,-2.6),0,true)
			partition_x(1.4,-3.9,-2.0)
			sofa(Vector3(-2.8,0,-.1),PI/2);table(Vector3(-1.3,0,-.1),PI/2)
			rug(Vector3(-1.55,0,-.1),Vector2(2.7,2.6));shelf(Vector3(3.2,0,-.3),-PI/2)
			bathroom(Vector3(2.05,0,2.65),PI)
			window_at(Vector3(3.46,1.85,-2.45),-PI/2);picture(Vector3(-3.46,1.95,.1),PI/2)
			plant(Vector3(-2.9,0,3.2));walk_targets=[Vector3(2.4,.08,-1.15),Vector3(-1.5,.08,-2.2),Vector3(0,.08,0),Vector3(2.05,.08,2.1)]
		4:
			partition_x(-.5,-5,-1.3);partition_z(-1.3,-5,-3.4);partition_z(-1.3,-1.95,-.5)
			bed(Vector3(-3.0,0,-3.6));shelf(Vector3(-.9,0,-3.5),-PI/2)
			# Separate study alcove, furnished desk and wall print.
			partition_z(-1.3,2,5);table(Vector3(3.2,0,-3.8),0,true);shelf(Vector3(1.2,0,-4.7))
			kitchen(Vector3(4.55,0,.35),-PI/2);fridge(Vector3(4.5,0,-1.65),-PI/2)
			sofa(Vector3(-4.25,0,2),PI/2);table(Vector3(-2.65,0,2),PI/2)
			rug(Vector3(-2.75,0,2),Vector2(2.9,3.1));bathroom(Vector3(3.55,0,3.65),PI)
			window_at(Vector3(-3,1.85,-4.97));window_at(Vector3(3.2,1.85,-4.97));picture(Vector3(-4.96,1.95,2),PI/2)
			plant(Vector3(-4.4,0,4.4));walk_targets=[Vector3(-2.7,.08,-2),Vector3(2.5,.08,-2.3),Vector3(3.1,.08,.2),Vector3(-1.5,.08,2),Vector3(3.55,.08,3.1)]
	interior_environment=Environment.new();interior_environment.background_mode=Environment.BG_COLOR
	interior_environment.background_color=Color("d0bf9d");interior_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	interior_environment.ambient_light_color=Color("f4ede0");interior_environment.ambient_light_energy=.20
	interior_environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	for x in [-size.x*.25,size.x*.25]:
		for z in [-size.y*.26,size.y*.26]:
			box(self,"CeilingLamp",Vector3(x,2.94,z),Vector3(.6,.08,.6),Color("fff1c6"),false)
			var light:=OmniLight3D.new();light.position=Vector3(x,2.65,z);light.omni_range=7;light.light_energy=.12;light.light_color=Color("fff3df");light.shadow_enabled=true;add_child(light)
	preload("res://static_batch.gd").build(self,find_children("*","MeshInstance3D",true,false))
	visible=false

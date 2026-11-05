extends Node3D
# ANA BEAUTY — beauty salon (layout id 4).
# Main hall: reception with the admin (Aruzhan, cashier_4) + manicure
# station (table, client chair, stool, lamp, polish palette). The former
# hair-styling corner is sealed off as a separate room behind a CLOSED door
# with a «Шаштараз» sign: visible, unreachable, no interactions inside.
const ASSETS="res://assets/cartoon/prepared/"
const ENTRY=Vector3(0,.08,4.5)
const EXIT=Vector3(0,1.2,5.82)
const WOOD=Color("9c6b3f")
const WALL_UP=Color("f7f0e6")
const WALL_LOW=Color("f3ccd3")
const TRIM=Color("c96a7d")
const CREAM=Color("f9f4eb")
const DARK=Color("3a3540")
var title:=""
var layout_id:=4
var props:Array[MeshInstance3D]=[]
var interior_environment:Environment
var cashier:Node3D
# Present so generic room iteration (daily_life dinner sign) can test it.
var checkout:MeshInstance3D
var checkout_approach:=Vector3(0.0,.08,3.4)
var talkable_actors:Array=[]
var game:Node3D
# Manicure clients: three model nodes, one active at a time (arrival,
# sitting, manicure, thanks, leaving).
var clients:Array[Dictionary]=[]
var next_cycle:=0
var next_arrival:=4.0
var last_polish:Color=Color.WHITE
const POLISH_PALETTE:Array[Color]=[
	Color("c2426b"),Color("e8c33f"),Color("3f9d6f"),
	Color("4a6fd8"),Color("9b59d0"),Color("f2e2d0"),
]
var rng:=RandomNumberGenerator.new()
func build(shop_title:String,index:int) -> void:
	title=shop_title
	layout_id=index
	game=get_parent()
	rng.randomize()
	block("SalonFloor",Vector3(0,0,0),Vector3(10.24,.2,12.2),WOOD,true)
	var ceiling:=block("SalonCeiling",Vector3(0,3.6,0),Vector3(10.24,.18,12.2),Color("fbf6ee"),false)
	block("WallBack",Vector3(0,1.8,-6.0),Vector3(10.24,3.6,.24),WALL_UP,true)
	block("WallBackLow",Vector3(0,.55,-5.86),Vector3(10.24,1.1,.08),WALL_LOW,false)
	block("WallEast",Vector3(5.0,1.8,0),Vector3(.24,3.6,12.2),WALL_UP,true)
	block("WallEastLow",Vector3(4.86,.55,0),Vector3(.08,1.1,12.2),WALL_LOW,false)
	block("WallWest",Vector3(-5.0,1.8,0),Vector3(.24,3.6,12.2),WALL_UP,true)
	block("WallWestLow",Vector3(-4.86,.55,0),Vector3(.08,1.1,12.2),WALL_LOW,false)
	block("WallN",Vector3(0,1.8,6.0),Vector3(10.24,3.6,.24),WALL_UP,true)
	block("WallNLow",Vector3(-3.21,.55,5.86),Vector3(3.82,1.1,.08),WALL_LOW,false)
	block("WallNLowR",Vector3(3.21,.55,5.86),Vector3(3.82,1.1,.08),WALL_LOW,false)
	block("TrimBack",Vector3(0,1.12,-5.86),Vector3(10.24,.06,.05),TRIM,false)
	block("TrimEast",Vector3(4.86,1.12,0),Vector3(.05,.06,12.2),TRIM,false)
	block("TrimWest",Vector3(-4.86,1.12,0),Vector3(.05,.06,12.2),TRIM,false)
	block("TrimN",Vector3(0,1.12,5.86),Vector3(10.24,.06,.05),TRIM,false)
	block("SkirtBack",Vector3(0,.07,-5.88),Vector3(10.24,.14,.06),DARK,false)
	block("SkirtEast",Vector3(4.88,.07,0),Vector3(.06,.14,12.2),DARK,false)
	block("SkirtWest",Vector3(-4.88,.07,0),Vector3(.06,.14,12.2),DARK,false)
	# White pilasters + lintel around the entrance. NOTE: no WOOD frame blocks
	# here — they sat at the exact same positions and z-fought with these.
	block("WallBodyFT",Vector3(0,2.35,5.92),Vector3(2.5,.34,.26),WALL_UP,false,true)
	# The full front wall (WallN, z 5.88..6.12) has no doorway: the door
	# assembly must sit in FRONT of its face (z<5.88) or it is hidden by the wall.
	block("DoorPanel",Vector3(0,1.15,5.80),Vector3(2.3,2.06,.06),Color("6b4226"),false)
	block("DoorWindow",Vector3(0,1.78,5.76),Vector3(1.4,.8,.03),Color("b8d8e8"),false)
	block("DoorHandle",Vector3(0.85,1.05,5.74),Vector3(.12,.4,.12),TRIM,false)
	var exit_sign:=text_label("ШЫҒУ",36,Color("fff3e4"))
	exit_sign.position=Vector3(0,2.65,5.8)
	exit_sign.rotation.y=PI
	add_child(exit_sign)
	block("WallBodyFL",Vector3(-1.3,1.8,5.92),Vector3(.26,3.6,.26),WALL_UP,false,true)
	block("WallBodyFR",Vector3(1.3,1.8,5.92),Vector3(.26,3.6,.26),WALL_UP,false,true)
	block("WelcomeMat",Vector3(0,0.01,4.35),Vector3(1.7,.02,1.0),Color("d9a7b4"),false)
	# --- Hair room (separate, sealed off with a closed door) ---------------
	# Partition x=-1.7 (gap z -3.0..-2.0 = doorway) and z=0.3.
	block("HairWallA1",Vector3(-1.7,1.8,-4.5),Vector3(.14,3.6,3.02),WALL_UP,true)
	block("HairWallA2",Vector3(-1.7,1.8,-0.85),Vector3(.14,3.6,2.32),WALL_UP,true)
	block("HairWallLintel",Vector3(-1.7,2.85,-2.5),Vector3(.14,1.5,1.0),WALL_UP,true)
	block("HairWallB",Vector3(-3.35,1.8,0.3),Vector3(3.34,3.6,.14),WALL_UP,true)
	block("HairTrimA",Vector3(-1.62,1.12,-4.5),Vector3(.04,.06,3.0),TRIM,false)
	block("HairTrimB",Vector3(-3.35,1.12,0.22),Vector3(3.3,.06,.04),TRIM,false)
	# Closed door in the gap: mesh + full collision over the whole opening.
	block("HairDoor",Vector3(-1.7,1.03,-2.5),Vector3(.1,2.06,.96),Color("7a4a33"),false)
	block("HairDoorGlass",Vector3(-1.62,1.55,-2.5),Vector3(.05,.55,.42),Color(.79,.87,.9,0.35),false)
	block("HairDoorHandle",Vector3(-1.62,1.05,-2.18),Vector3(.05,.06,.18),TRIM,false)
	block("HairDoorJamL",Vector3(-1.7,1.28,-3.02),Vector3(.2,2.56,.12),TRIM,false)
	block("HairDoorJamR",Vector3(-1.7,1.28,-1.98),Vector3(.2,2.56,.12),TRIM,false)
	block("HairDoorJamTop",Vector3(-1.7,2.34,-2.5),Vector3(.2,.14,1.0),TRIM,false)
	solid_box("HairDoorBody",Vector3(-1.7,1.05,-2.5),Vector3(.3,2.1,1.06))
	# Sign on the main-room side of the partition.
	block("HairSignPanel",Vector3(-1.58,2.52,-2.5),Vector3(.06,.44,2.0),DARK,false)
	var hair_sign:=text_label("Шаштараз",44,Color("fff3e4"))
	hair_sign.position=Vector3(-1.53,2.52,-2.5)
	hair_sign.rotation.y=PI/2
	add_child(hair_sign)
	# Hair-room furniture (static, no interactions, no NPCs inside).
	block("HairMirror",Vector3(-4.97,1.9,-3.2),Vector3(.05,1.15,2.6),Color(.76,.86,.91),false)
	block("HairMirrorFrame",Vector3(-4.97,1.9,-3.2),Vector3(.07,1.25,2.72),WOOD,false)
	block("HairChairBase",Vector3(-3.3,0.2,-3.2),Vector3(.62,.4,.62),DARK,false)
	block("HairChairSeat",Vector3(-3.3,0.46,-3.2),Vector3(.7,.12,.68),Color("8c3b46"),false)
	block("HairChairBack",Vector3(-3.3,0.82,-3.55),Vector3(.68,.6,.1),DARK,false)
	solid_box("HairChairBody",Vector3(-3.3,0.35,-3.2),Vector3(.85,.7,.85))
	block("HairTableTop",Vector3(-4.35,0.72,-0.9),Vector3(.9,.06,.5),CREAM,false)
	block("HairTableBase",Vector3(-4.35,0.36,-0.9),Vector3(.7,.72,.42),WOOD,false)
	solid_box("HairTableBody",Vector3(-4.35,0.36,-0.9),Vector3(.92,.72,.52))
	for i in 3:
		block("HairBottle%d"%i,Vector3(-4.55+i*.18,0.79,-0.75),Vector3(.07,.12,.07),POLISH_PALETTE[i*2].lightened(.25),false)
	block("HairLampPost",Vector3(-4.55,0.7,-5.45),Vector3(.06,1.4,.06),DARK,false)
	block("HairLampShade",Vector3(-4.55,1.45,-5.45),Vector3(.4,.28,.4),Color("ffe2b8"),false)
	var hair_lamp:OmniLight3D=OmniLight3D.new()
	hair_lamp.position=Vector3(-4.55,1.35,-5.45)
	hair_lamp.light_color=Color(1,.86,.64)
	hair_lamp.light_energy=0.9
	hair_lamp.omni_range=4.0
	add_child(hair_lamp)
	# --- Reception ---------------------------------------------------------
	block("CounterBase",Vector3(-1.2,0.5,2.3),Vector3(2.4,1.0,.8),CREAM,false)
	block("CounterKick",Vector3(-1.2,0.05,2.3),Vector3(2.2,.1,.72),Color("8a6a55"),false)
	block("CounterTop",Vector3(-1.2,1.04,2.3),Vector3(2.6,.08,.84),Color("8a6a55"),false)
	block("CounterLED",Vector3(-1.2,0.98,2.71),Vector3(2.3,.05,.04),Color(1,.62,.72),false,true)
	solid_box("CounterBody",Vector3(-1.2,0.52,2.3),Vector3(2.4,1.04,.84))
	block("MonStand",Vector3(-2.0,1.12,2.15),Vector3(.12,.1,.12),DARK,false)
	block("MonScreen",Vector3(-2.02,1.35,2.15),Vector3(.05,.34,.5),Color("9adfe8"),false,true)
	block("CounterTray",Vector3(-0.5,1.1,2.4),Vector3(.4,.03,.28),Color("e8c33f"),false)
	block("CounterPlantPot",Vector3(0.2,1.18,2.3),Vector3(.18,.16,.18),Color("b0714f"),false)
	block("CounterPlantLeaf",Vector3(0.2,1.42,2.3),Vector3(.3,.34,.3),Color("5e9c56"),false)
	# --- Manicure zone -------------------------------------------------------
	block("ManiRug",Vector3(2.4,0.012,0.3),Vector3(3.2,.02,2.6),Color("e8d9c4"),false)
	block("ManiRugInner",Vector3(2.4,0.02,0.3),Vector3(2.6,.02,2.0),Color("f5ead8"),false)
	block("ManiTableTop",Vector3(2.4,0.72,0.5),Vector3(1.2,.06,.62),Color("fbf6ec"),false)
	block("ManiTableBase",Vector3(2.4,0.36,0.5),Vector3(1.0,.72,.54),Color("d8c5b0"),false)
	solid_box("ManiTableBody",Vector3(2.4,0.36,0.5),Vector3(1.2,.72,.62))
	for i in 6:
		var col:Color=POLISH_PALETTE[i]
		block("Polish%d"%i,Vector3(2.05+i*.15,0.8,0.36),Vector3(.045,.11,.045),col,false)
		block("PolishCap%d"%i,Vector3(2.05+i*.15,0.885,0.36),Vector3(.03,.06,.03),DARK,false)
	block("ManiTray",Vector3(2.3,0.76,0.64),Vector3(.34,.025,.14),Color("c9b7a5"),false)
	block("ManiTool1",Vector3(2.2,0.785,0.64),Vector3(.1,.02,.02),DARK,false)
	block("ManiTool2",Vector3(2.42,0.785,0.64),Vector3(.1,.02,.02),Color("8a6a55"),false)
	# Client chair (seat top y=0.5).
	block("ManiChairBase",Vector3(2.4,0.22,-0.25),Vector3(.5,.44,.5),DARK,false)
	block("ManiChairSeat",Vector3(2.4,0.47,-0.25),Vector3(.58,.08,.56),Color("c96a7d"),false)
	block("ManiChairBack",Vector3(2.4,0.82,-0.55),Vector3(.56,.6,.08),DARK,false)
	block("ManiChairArmL",Vector3(2.12,0.58,-0.3),Vector3(.06,.12,.4),DARK,false)
	block("ManiChairArmR",Vector3(2.68,0.58,-0.3),Vector3(.06,.12,.4),DARK,false)
	solid_box("ManiChairBody",Vector3(2.4,0.3,-0.35),Vector3(.72,.6,.75))
	# Stylist stool (for the player).
	block("ManiStoolBase",Vector3(2.4,0.24,1.35),Vector3(.3,.48,.3),DARK,false)
	block("ManiStoolSeat",Vector3(2.4,0.51,1.35),Vector3(.38,.08,.38),Color("c96a7d"),false)
	solid_box("ManiStoolBody",Vector3(2.4,0.26,1.35),Vector3(.42,.52,.42))
	# Lamp over the table.
	block("ManiLampBase",Vector3(3.02,0.77,0.32),Vector3(.16,.04,.16),DARK,false)
	block("ManiLampPost",Vector3(3.02,1.0,0.32),Vector3(.04,.42,.04),DARK,false)
	block("ManiLampHead",Vector3(2.95,1.24,0.42),Vector3(.24,.12,.18),Color("ffe2b8"),false,true)
	var mani_lamp:OmniLight3D=OmniLight3D.new()
	mani_lamp.position=Vector3(2.95,1.15,0.5)
	mani_lamp.light_color=Color(1,.88,.68)
	mani_lamp.light_energy=1.3
	mani_lamp.omni_range=3.6
	add_child(mani_lamp)
	# Organizer with cosmetics.
	block("OrganizerBase",Vector3(3.4,0.45,0.5),Vector3(.42,.9,.34),Color("e8d9c4"),false)
	for i in 3:
		block("OrganizerShelf%d"%i,Vector3(3.4,0.3+i*.27,0.5),Vector3(.4,.03,.3),Color("c9b7a5"),false)
		for j in 3:
			block("Cosmetic%d_%d"%[i,j],Vector3(3.3+j*.1,0.37+i*.27,0.5),Vector3(.07,.12,.07),POLISH_PALETTE[(i*3+j)%6].lightened(.3),false)
	solid_box("OrganizerBody",Vector3(3.4,0.45,0.5),Vector3(.44,.9,.36))
	# Decorative slat wall + mirror behind the manicure station.
	for i in 9:
		block("Slat%d"%i,Vector3(0.9+i*.42,1.25,-5.9),Vector3(.08,2.4,.06),Color("eec3cb"),false)
	block("ManiMirror",Vector3(2.4,1.55,-5.84),Vector3(1.5,1.05,.05),Color(.76,.86,.91),false)
	block("ManiMirrorLED",Vector3(2.4,1.55,-5.855),Vector3(1.62,1.17,.04),Color("fff0dd"),false,true)
	# --- Waiting area / decor ----------------------------------------------
	block("BenchSeat",Vector3(4.65,0.38,-0.65),Vector3(.62,.09,2.5),Color("c96a7d"),false)
	block("BenchBack",Vector3(4.82,0.72,-0.65),Vector3(.12,.7,2.5),Color("c96a7d"),false)
	block("BenchLegL",Vector3(4.65,0.17,-1.75),Vector3(.5,.34,.12),DARK,false)
	block("BenchLegR",Vector3(4.65,0.17,0.45),Vector3(.5,.34,.12),DARK,false)
	solid_box("BenchBody",Vector3(4.7,0.35,-0.65),Vector3(.6,.7,2.5))
	block("CoffeeTable",Vector3(3.2,0.4,2.7),Vector3(.9,.06,.55),Color("8a6a55"),false)
	block("CoffeeLegL",Vector3(2.85,0.19,2.7),Vector3(.08,.38,.45),DARK,false)
	block("CoffeeLegR",Vector3(3.55,0.19,2.7),Vector3(.08,.38,.45),DARK,false)
	solid_box("CoffeeBody",Vector3(3.2,0.2,2.7),Vector3(.95,.4,.6))
	block("Magazine1",Vector3(3.1,0.44,2.7),Vector3(.24,.02,.17),Color("7fb3d9"),false)
	block("Magazine2",Vector3(3.35,0.44,2.75),Vector3(.24,.02,.17),Color("d99a7f"),false)
	block("Painting1F",Vector3(4.96,1.95,-2.6),Vector3(.06,1.0,1.3),WOOD,false)
	block("Painting1",Vector3(4.94,1.95,-2.6),Vector3(.04,.88,1.18),Color("e8b4c8"),false)
	block("Painting2F",Vector3(4.96,1.95,-1.3),Vector3(.06,.7,.7),WOOD,false)
	block("Painting2",Vector3(4.94,1.95,-1.3),Vector3(.04,.58,.58),Color("a8c8e8"),false)
	block("PlantPot1",Vector3(4.7,0.26,-5.4),Vector3(.42,.52,.42),Color("b0714f"),false)
	block("PlantLeaf1",Vector3(4.7,0.85,-5.4),Vector3(.72,.86,.72),Color("5e9c56"),false)
	solid_box("Plant1Body",Vector3(4.7,0.26,-5.4),Vector3(.46,.52,.46))
	block("PlantPot2",Vector3(-4.7,0.26,5.3),Vector3(.42,.52,.42),Color("b0714f"),false)
	block("PlantLeaf2",Vector3(-4.7,0.85,5.3),Vector3(.72,.86,.72),Color("5e9c56"),false)
	solid_box("Plant2Body",Vector3(-4.7,0.26,5.3),Vector3(.46,.52,.46))
	block("Pendant1Cord",Vector3(2.4,3.25,0.5),Vector3(.03,.4,.03),DARK,false)
	block("Pendant1Shade",Vector3(2.4,3.0,0.5),Vector3(.5,.3,.5),Color("f2c9d0"),false)
	block("Pendant1Bulb",Vector3(2.4,2.86,0.5),Vector3(.16,.1,.16),Color(1,.92,.78),false,true)
	block("Pendant2Cord",Vector3(-1.2,3.25,2.3),Vector3(.03,.4,.03),DARK,false)
	block("Pendant2Shade",Vector3(-1.2,3.0,2.3),Vector3(.5,.3,.5),Color("f2c9d0"),false)
	block("Pendant2Bulb",Vector3(-1.2,2.86,2.3),Vector3(.16,.1,.16),Color(1,.92,.78),false,true)
	var lamp1:=OmniLight3D.new()
	lamp1.position=Vector3(2.4,2.8,0.5)
	lamp1.light_color=Color(1,.9,.76)
	lamp1.light_energy=1.4
	lamp1.omni_range=6.0
	add_child(lamp1)
	var lamp2:=OmniLight3D.new()
	lamp2.position=Vector3(-1.2,2.8,2.3)
	lamp2.light_color=Color(1,.9,.76)
	lamp2.light_energy=1.2
	lamp2.omni_range=5.0
	add_child(lamp2)
	var door_light:=OmniLight3D.new()
	door_light.position=Vector3(0,2.6,5.2)
	door_light.light_color=Color(1,.95,.88)
	door_light.light_energy=1.1
	door_light.omni_range=5.0
	add_child(door_light)
	block("SalonTitlePanel",Vector3(0,3.05,5.88),Vector3(3.2,.5,.08),DARK,false)
	var salon_title:=text_label("ANA BEAUTY",54,Color("f2c9d0"))
	salon_title.position=Vector3(0,3.05,5.83)
	salon_title.rotation.y=PI
	add_child(salon_title)
	# Staff: the admin stands behind the reception.
	cashier=make_npc("cashier_4","aruzhan",3)
	cashier.position=Vector3(-1.2,.02,1.7)
	cashier.rotation.y=PI
	add_child(cashier)
	_register_talkable("cashier_4",cashier)
	# Manicure clients (model nodes only — no tools, no cut animations;
	# the interactive part is the polish palette + the nail colour change).
	var mani_chars:Array=[["asel",2],["dana",5],["asel",6]]
	for i in 3:
		var profile_id:String="salon_mani_%d"%i
		var node:Node3D=make_npc(profile_id,mani_chars[i][0],mani_chars[i][1])
		node.visible=false
		node.collision_layer=0
		node.position=Vector3(0,.02,5.3)
		node.rotation.y=PI
		add_child(node)
		_register_talkable(profile_id,node)
		clients.append({"node":node,"id":profile_id,"state":"away","wp":0})
	_update_environment()

func _update_environment() -> void:
	interior_environment=Environment.new()
	interior_environment.background_mode=Environment.BG_COLOR
	interior_environment.background_color=Color(.12,.12,.16)
	interior_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	interior_environment.ambient_light_color=Color(.92,.86,.78)
	interior_environment.ambient_light_energy=0.55
	interior_environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	interior_environment.ssr_enabled=true
	interior_environment.ssr_max_steps=24
	var spot:=SpotLight3D.new()
	spot.position=Vector3(0,3.35,3.0)
	spot.rotation.x=-.7
	spot.light_color=Color(1,.9,.8)
	spot.light_energy=3.2
	spot.spot_range=9.0
	spot.shadow_enabled=true
	add_child(spot)

func _process(_delta:float) -> void:
	# Kept for parity with shop rooms (the salon sim runs in update_cashier).
	pass

func update_cashier(camera:Camera3D,delta:float,active:bool) -> void:
	if is_instance_valid(cashier):
		if not active:
			cashier.animation.active=false
		else:
			cashier.update_detail(camera,delta)
			cashier.play_motion("idle")
	_sim(camera,delta,active)

func _sim(camera:Camera3D,delta:float,active:bool) -> void:
	if not active:return
	var now:=Time.get_ticks_msec()/1000.0
	for c in clients:
		var node:Node3D=c.node
		match c.state:
			"away":pass
			"entering":
				if c.wp>=ENTER_WAYPOINTS.size():
					c.state="sitting"
					node.rotation.y=PI
					# Hold the sit pose on top of the idle motion (called every frame).
					node.pose_fixer=func(n:Node3D):_apply_sit(n)
					node.play_motion("idle")
					_greet_client(c)
				else:
					var wp:Array=ENTER_WAYPOINTS[c.wp]
					if _move_towards(node,to_global(Vector3(wp[0],0,wp[1])),1.15*delta):c.wp+=1
			"sitting":pass
			"leaving":
				if c.wp>=LEAVE_WAYPOINTS.size():
					c.state="away"
					node.visible=false
					node.collision_layer=0
					if "pose_fixer" in node:node.pose_fixer=Callable()
					next_arrival=now+8.0+rng.randf()*8.0
				else:
					var lw:Array=LEAVE_WAYPOINTS[c.wp]
					if _move_towards(node,to_global(Vector3(lw[0],0,lw[1])),1.15*delta):c.wp+=1
	if next_arrival>0.0 and now>=next_arrival:
		var c2:Dictionary=clients[next_cycle%clients.size()]
		next_cycle+=1
		var node2:Node3D=c2.node
		node2.visible=true
		node2.collision_layer=1
		node2.global_position=to_global(Vector3(0.2,0,5.3))
		node2.rotation.y=PI
		node2.play_motion("idle")
		c2.state="entering"
		c2.wp=0
		if "pose_fixer" in node2:node2.pose_fixer=Callable()
		next_arrival=0.0

func _greet_client(c:Dictionary) -> void:
	if game.automated:return
	# A short arrival line; the full greeting is spoken when the chat opens.
	var lines:=Array(["Сәлем! Маникюрге орын бар ма?","Сәлеметсіз бе! Кезексіз келдім.","Сәлем! Лак таңдап отырмын."])
	var idx:int=clients.find(c)
	if idx<0:idx=0
	game.speech.speak(str(lines[idx%lines.size()]),str(c.id))

# Player picks a polish colour in the chat: paint the nails, pay, thank, leave.
func choose_polish(color:Color,id:String) -> void:
	for c in clients:
		if str(c.id)!=id or c.state!="sitting":continue
		var node:Node3D=c.node
		_apply_nail_color(node,color)
		last_polish=color
		var amount:int=game.story.pay_manicure(str(game.story_ui.profiles.get(id,{}).get("name","Клиент")))
		var ui=game.story_ui
		if ui.modal=="chat" and ui.active_id==id:
			# _message appends in place — do not call _draw_messages here: it
			# clears the history and would erase this line.
			ui._message(str(game.story_ui.profiles.get(id,{}).get("name","Клиент")),"Рақмет, өте әдемі болыпты!")
		ui.status.text="+%d ₸ · Маникюр дайын"%amount
		if not game.automated:
			game.speech.speak("Рақмет, өте әдемі болыпты!",id)
		c.state="leaving"
		c.wp=0
		node.play_motion("walk")
		if "pose_fixer" in node:node.pose_fixer=Callable()
		ui.refresh_manicure()
		return

func mani_client_state(id:String) -> String:
	for c in clients:
		if str(c.id)==id:return str(c.state)
	return "away"

func _apply_nail_color(node:Node3D,color:Color) -> void:
	var acc:Array=[]
	_collect_meshes(node,acc)
	for mi in acc:
		if not (mi is MeshInstance3D):continue
		var mesh:Mesh=(mi as MeshInstance3D).mesh
		if not (mesh is ArrayMesh):continue
		var am:ArrayMesh=mesh
		for s in am.get_surface_count():
			var mat:=am.surface_get_material(s)
			if mat and str(mat.resource_name)=="Std_Nails":
				var copy:StandardMaterial3D=StandardMaterial3D.new()
				copy.albedo_color=color
				copy.metallic=0.15
				copy.roughness=0.3
				(mi as MeshInstance3D).set_surface_override_material(s,copy)
				return

func _collect_meshes(node:Node,acc:Array) -> void:
	if node is MeshInstance3D:acc.append(node)
	for c in node.get_children():_collect_meshes(c,acc)

const SEAT_HIP_Y:=0.53

# Client walking routes: the straight door->chair line crosses the manicure
# table (solid, x 1.8..3.0 / z 0.19..0.81), so detour west of it.
const ENTER_WAYPOINTS:Array=[[1.35,2.9],[1.35,-0.55],[2.4,-0.25]]
const LEAVE_WAYPOINTS:Array=[[1.35,-0.55],[1.35,2.9],[0.2,5.3]]
func _apply_sit(node:Node3D) -> void:
	var sk:Skeleton3D=node.skeleton()
	if not sk:return
	var pelvis:int=node.bone_index("Pelvis_")
	var lth:int=node.bone_index("_L_Thigh_")
	var rth:int=node.bone_index("_R_Thigh_")
	var lsh:int=node.bone_index("_L_Calf_")
	var rsh:int=node.bone_index("_R_Calf_")
	var lfo:int=node.bone_index("_L_Foot_")
	var rfo:int=node.bone_index("_R_Foot_")
	if pelvis<0 or lth<0 or rth<0 or lsh<0 or rsh<0 or lfo<0 or rfo<0:return
	# 1) Drop the hips onto the seat (the node itself stays on the floor).
	var pel_w:Transform3D=node.bone_world(pelvis)
	var floor_y:float=node.global_position.y
	var seat_hip_y:float=floor_y+SEAT_HIP_Y
	var drop:float=pel_w.origin.y-seat_hip_y
	if drop>0.001:
		var parent_w:Transform3D=node.bone_world(sk.get_bone_parent(pelvis))
		var pp:Transform3D=sk.get_bone_pose(pelvis)
		pp.origin+=parent_w.basis.inverse()*Vector3(0,-drop,0)
		sk.set_bone_pose(pelvis,pp)
	# 2) Bend the legs: knees forward-down, feet on the floor.
	var pel2:Transform3D=node.bone_world(pelvis)
	var hip:Vector3=pel2.origin
	var fwd:Vector3=-(node.global_basis.z)
	fwd.y=0.0
	if fwd.length_squared()<0.0001:fwd=Vector3(0,0,1)
	fwd=fwd.normalized()
	var knee_l:Vector3=hip+Vector3(0.17,-0.30,0)+fwd*0.30
	var knee_r:Vector3=hip+Vector3(-0.17,-0.30,0)+fwd*0.30
	var foot_l:Vector3=knee_l+Vector3(0.17,-0.22,0)
	var foot_r:Vector3=knee_r+Vector3(-0.17,-0.22,0)
	_set_bone_to_world(sk,node,lth,knee_l,hip+Vector3(0,0.3,0)+fwd*0.1)
	_set_bone_to_world(sk,node,rth,knee_r,hip+Vector3(0,-0.3,0)+fwd*0.1)
	_set_bone_to_world(sk,node,lsh,foot_l,knee_l+Vector3(0.1,0.1,0))
	_set_bone_to_world(sk,node,rsh,foot_r,knee_r+Vector3(-0.1,0.1,0))
	_set_bone_to_world(sk,node,lfo,foot_l+Vector3(0,-0.02,0),foot_l+fwd*0.06)
	_set_bone_to_world(sk,node,rfo,foot_r+Vector3(0,-0.02,0),foot_r+fwd*0.06)

func _set_bone_to_world(sk:Skeleton3D,node:Node3D,bone:int,target:Vector3,aim:Vector3) -> void:
	var parent_i:int=sk.get_bone_parent(bone)
	if parent_i<0:return
	# The engine global-pose cache is broken for these imported rigs (FBX unit
	# scale), so compute the parent world transform from the local pose chain
	# exactly like bone_world() does.
	var parent_w:Transform3D=node.bone_world(parent_i)
	var local:Vector3=parent_w.basis.inverse()*(target-parent_w.origin)
	var local_aim:Vector3=parent_w.basis.inverse()*aim
	var dir:Vector3=(local_aim-local)
	dir.y=0.0
	if dir.length_squared()>0.0001:
		var yaw:float=atan2(-dir.x,-dir.z)
		var pose:Transform3D=sk.get_bone_pose(bone)
		pose.basis=pose.basis*Basis(Vector3.UP,yaw)
		sk.set_bone_pose(bone,pose)
	var p2:Transform3D=sk.get_bone_pose(bone)
	p2.origin=local
	sk.set_bone_pose(bone,p2)

func _move_towards(node:Node3D,target:Vector3,step:float) -> bool:
	var to:Vector3=(target-node.global_position)
	to.y=0.0
	var dist:float=to.length()
	if dist<=maxf(step,0.06):
		node.global_position.x=target.x
		node.global_position.z=target.z
		return true
	to=to/dist
	node.global_position+=to*step
	node.rotation.y=atan2(-to.x,-to.z)
	node.play_motion("walk")
	return false

func block(name:String,position:Vector3,size:Vector3,albedo:Color,solid:=false,emissive:=false)->MeshInstance3D:
	var m:MeshInstance3D=MeshInstance3D.new()
	m.name=name
	m.position=position
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=albedo
	mat.roughness=0.92
	mat.metallic=0.0
	if emissive:
		mat.emission_enabled=true
		mat.emission=albedo.lightened(0.2)
		mat.emission_energy_multiplier=2.2
	var box:=BoxMesh.new()
	box.size=size
	box.material=mat
	m.mesh=box
	add_child(m)
	props.append(m)
	if solid:
		var body:=StaticBody3D.new()
		body.name=name+"Body"
		body.position=position
		body.collision_layer=1
		body.collision_mask=0
		var shape:=CollisionShape3D.new()
		var boxshape:=BoxShape3D.new()
		boxshape.size=size
		shape.shape=boxshape
		body.add_child(shape)
		add_child(body)
	return m

func solid_box(name:String,position:Vector3,size:Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=name
	body.position=position
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionShape3D.new()
	var boxshape:=BoxShape3D.new()
	boxshape.size=size
	shape.shape=boxshape
	body.add_child(shape)
	add_child(body)
	return body

func text_label(text:String,size:int,color:Color)->Label3D:
	var l:=Label3D.new()
	l.text=text
	l.pixel_size=0.0022*float(size)/30.0
	l.font_size=size
	l.modulate=color
	l.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	l.outline_size=8
	l.outline_modulate=Color(0,0,0,0.75)
	return l

func make_npc(profile_id:String,character:String,outfit:int)->Node3D:
	# The script is a Node3D script; the street citizens run it on a
	# CharacterBody3D so the body carries the collision layer the talk-ray
	# (mask 1|8) and the player collide against.
	var n:=CharacterBody3D.new()
	n.set_script(preload("res://citizen_visual.gd"))
	n.name=profile_id
	n.character_id=character
	n.outfit_variant=outfit
	n.collision_layer=1
	n.collision_mask=0
	n.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.32
	capsule.height=1.75
	shape.shape=capsule
	shape.position=Vector3(0,.875,0)
	n.add_child(shape)
	return n

func _register_talkable(id:String,node:Node3D) -> void:
	node.set_meta("npc_id",id)
	talkable_actors.append({"id":id,"actor":node,"room_id":layout_id})

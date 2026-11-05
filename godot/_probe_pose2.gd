extends SceneTree
var game:Node3D
func shoot(at:Vector3,look:Vector3,path:String) -> void:
	game.player.global_position=at
	game.player.rotation=Vector3.ZERO
	var d:Vector3=look-(game.player.global_position+Vector3(0,1.65,0))
	game.yaw=atan2(-d.x,-d.z)
	game.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("POSE2K | shot ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	game.shop_visits._transition(4)
	var guard:float=0.0
	while game.shop_visits.busy and guard<10.0:
		await create_timer(0.1).timeout;guard+=0.1
	var room:Node3D=game.shop_visits.rooms[4]
	# Variant A: pelvis drop + thigh +70 X, calf -95 X
	var fa:=func(n:Node3D):
		room._apply_sit_drop(n)
		_room_bend(n,70.0,-95.0)
	# Variant B: pelvis drop + thigh -70 X, calf +95 X
	var fb:=func(n:Node3D):
		room._apply_sit_drop(n)
		_room_bend(n,-70.0,95.0)
	# Variant C: pelvis drop + thigh +70 Z, calf -95 Z
	var fc:=func(n:Node3D):
		room._apply_sit_drop(n)
		_room_bend_z(n,70.0,-95.0)
	for i in 3:
		room.clients[i].state="sitting"
	var n0:Node3D=room.clients[0].node
	var n1:Node3D=room.clients[1].node
	var n2:Node3D=room.clients[2].node
	n0.visible=true;n0.global_position=room.to_global(Vector3(1.7,0.02,-0.25));n0.rotation.y=PI;n0.play_motion("idle");n0.pose_fixer=fa
	n1.visible=true;n1.global_position=room.to_global(Vector3(2.4,0.02,-0.25));n1.rotation.y=PI;n1.play_motion("idle");n1.pose_fixer=fb
	n2.visible=true;n2.global_position=room.to_global(Vector3(3.1,0.02,-0.25));n2.rotation.y=PI;n2.play_motion("idle");n2.pose_fixer=fc
	await create_timer(1.5).timeout
	await shoot(room.to_global(Vector3(4.6,1.5,2.6)),room.to_global(Vector3(2.4,0.7,-0.2)),"res://../previews/pose_test2.png")
	quit(0)
func _room_bend(n:Node3D,thigh_deg:float,calf_deg:float) -> void:
	var sk:Skeleton3D=n.skeleton()
	var lth:int=n.bone_index("_L_Thigh_")
	var rth:int=n.bone_index("_R_Thigh_")
	var lsh:int=n.bone_index("_L_Calf_")
	var rsh:int=n.bone_index("_R_Calf_")
	for b in [lth,rth]:
		if b<0:continue
		var p:Transform3D=sk.get_bone_pose(b)
		p.basis=Basis(Vector3(1,0,0),deg_to_rad(thigh_deg))*p.basis
		sk.set_bone_pose(b,p)
	for b in [lsh,rsh]:
		if b<0:continue
		var p:Transform3D=sk.get_bone_pose(b)
		p.basis=Basis(Vector3(1,0,0),deg_to_rad(calf_deg))*p.basis
		sk.set_bone_pose(b,p)
func _room_bend_z(n:Node3D,thigh_deg:float,calf_deg:float) -> void:
	var sk:Skeleton3D=n.skeleton()
	var lth:int=n.bone_index("_L_Thigh_")
	var rth:int=n.bone_index("_R_Thigh_")
	var lsh:int=n.bone_index("_L_Calf_")
	var rsh:int=n.bone_index("_R_Calf_")
	for b in [lth,rth]:
		if b<0:continue
		var p:Transform3D=sk.get_bone_pose(b)
		p.basis=Basis(Vector3(0,0,1),deg_to_rad(thigh_deg))*p.basis
		sk.set_bone_pose(b,p)
	for b in [lsh,rsh]:
		if b<0:continue
		var p:Transform3D=sk.get_bone_pose(b)
		p.basis=Basis(Vector3(0,0,1),deg_to_rad(calf_deg))*p.basis
		sk.set_bone_pose(b,p)
func _initialize() -> void:
	call_deferred("run")

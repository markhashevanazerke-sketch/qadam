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
	print("POSEK | shot ",path)
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
	var fa:=Callable(room,"_apply_sit")
	var fb:=func(n:Node3D):
		room._apply_sit(n)
		var sk:Skeleton3D=n.skeleton()
		var hip:int=n.bone_index("Hip_02")
		if hip<0:return
		var p:Transform3D=sk.get_bone_pose(hip)
		p.basis=Basis(Vector3(1,0,0),deg_to_rad(25.0))*p.basis
		sk.set_bone_pose(hip,p)
	var fc:=func(n:Node3D):
		room._apply_sit(n)
		var sk:Skeleton3D=n.skeleton()
		var hip:int=n.bone_index("Hip_02")
		if hip<0:return
		var p:Transform3D=sk.get_bone_pose(hip)
		p.basis=Basis(Vector3(1,0,0),deg_to_rad(-25.0))*p.basis
		sk.set_bone_pose(hip,p)
	for i in 3:
		room.clients[i].state="sitting"
	var n0:Node3D=room.clients[0].node
	var n1:Node3D=room.clients[1].node
	var n2:Node3D=room.clients[2].node
	n0.visible=true;n0.global_position=room.to_global(Vector3(0.9,0.02,2.2));n0.rotation.y=PI;n0.play_motion("idle");n0.pose_fixer=fa
	n1.visible=true;n1.global_position=room.to_global(Vector3(1.9,0.02,2.2));n1.rotation.y=PI;n1.play_motion("idle");n1.pose_fixer=fb
	n2.visible=true;n2.global_position=room.to_global(Vector3(2.9,0.02,2.2));n2.rotation.y=PI;n2.play_motion("idle");n2.pose_fixer=fc
	await create_timer(1.5).timeout
	await shoot(room.to_global(Vector3(3.6,1.5,4.6)),room.to_global(Vector3(1.9,0.8,2.2)),"res://../previews/pose_test.png")
	quit(0)
func _initialize() -> void:
	call_deferred("run")

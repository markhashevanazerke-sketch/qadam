extends SceneTree
var game:Node3D
func bonep(node:Node3D,name:String) -> Vector3:
	var sk:Skeleton3D=node.skeleton()
	var i:int=node.bone_index(name)
	if i<0:return Vector3(NAN,NAN,NAN)
	return node.bone_world(i).origin
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
	var n0:Node3D=room.clients[0].node
	room.clients[0].state="sitting"
	n0.visible=true
	n0.global_position=room.to_global(Vector3(2.4,0.02,-0.25))
	n0.rotation.y=PI
	n0.play_motion("idle")
	n0.pose_fixer=Callable(room,"_apply_sit")
	await create_timer(1.5).timeout
	# Convert to room-local for readability.
	var inv:Transform3D=room.global_transform.affine_inverse()
	print("LEGB | chair at local (2.4,-0.25); table z 0.19..0.81")
	for bname in ["Pelvis_","_L_Thigh_","_R_Thigh_","_L_Calf_","_R_Calf_","_L_Foot_","_R_Foot_"]:
		var w:Vector3=bonep(n0,bname)
		if is_nan(w.x):
			print("LEGB | ",bname," NOT FOUND");continue
		var local:Vector3=inv*w
		print("LEGB | ",bname," local=",local)
	quit(0)
func _initialize() -> void:
	call_deferred("run")

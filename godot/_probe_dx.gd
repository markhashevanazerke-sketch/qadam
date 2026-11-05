extends SceneTree
var game:Node3D
func head_pelvis(node:Node3D) -> void:
	var sk:Skeleton3D=node.skeleton()
	var pel:int=node.bone_index("Pelvis_")
	var head:int=node.bone_index("Head_")
	if pel<0 or head<0:
		print("DXK | missing bones pel=%d head=%d"%[pel,head]);return
	var pp:Vector3=node.bone_world(pel).origin
	var hp:Vector3=node.bone_world(head).origin
	var d:Vector3=hp-pp
	print("DXK | pelvis=",pp," head=",hp," delta=",d," horiz_len=",Vector2(d.x,d.z).length()," pitch_deg=",rad_to_deg(atan2(Vector2(d.x,d.z).length(),d.y)))
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
	# Standing idle (no sit) at the chair spot.
	n0.visible=true
	n0.global_position=room.to_global(Vector3(2.4,0.02,-0.25))
	n0.rotation.y=PI
	n0.play_motion("idle")
	await create_timer(1.2).timeout
	print("DXK | STANDING idle at chair:")
	head_pelvis(n0)
	# Now apply the current sit pose.
	room._apply_sit(n0)
	n0.pose_fixer=Callable(room,"_apply_sit")
	await create_timer(1.2).timeout
	print("DXK | SITTING (current _apply_sit):")
	head_pelvis(n0)
	quit(0)
func _initialize() -> void:
	call_deferred("run")

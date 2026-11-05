extends SceneTree
var game:Node3D
var calls:int=0
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
	n0.pose_fixer=func(n:Node3D):
		calls+=1
		if calls<=3:print("FXK | pose_fixer called #",calls)
		room._apply_sit(n)
	await create_timer(2.0).timeout
	print("FXK | total calls=",calls)
	var sk:Skeleton3D=n0.skeleton()
	var pel:int=n0.bone_index("Pelvis_")
	print("FXK | pelvis world y=",n0.bone_world(pel).origin.y," node y=",n0.global_position.y)
	quit(0)
func _initialize() -> void:
	call_deferred("run")

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
	print("SITK | shot ",path)
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
	# 3/4 view from the front-right (like the user sees it).
	await shoot(room.to_global(Vector3(4.4,1.7,2.2)),room.to_global(Vector3(2.2,0.7,-0.2)),"res://../previews/sit_34.png")
	# Pure side view.
	await shoot(room.to_global(Vector3(5.2,1.4,0.3)),room.to_global(Vector3(2.3,0.6,0.1)),"res://../previews/sit_side.png")
	# Low angle from the table side (shows the gap between feet and table).
	await shoot(room.to_global(Vector3(3.4,1.0,1.9)),room.to_global(Vector3(2.2,0.5,0.1)),"res://../previews/sit_low.png")
	quit(0)
func _initialize() -> void:
	call_deferred("run")

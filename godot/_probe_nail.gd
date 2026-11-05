extends SceneTree
var game:Node3D
func shoot(at:Vector3,look:Vector3,path:String) -> void:
	game.player.global_position=at
	game.player.rotation=Vector3.ZERO
	var d:Vector3=look-(game.player.global_position+Vector3(0,1.65,0))
	game.yaw=atan2(-d.x,-d.z)
	game.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("NAILK | shot ",path)
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
	# Seat the manicure client (Гүлнәр) in the chair, facing the table.
	var c:Dictionary=room.clients[0]
	var node:Node3D=c.node
	c.state="sitting"
	node.visible=true
	node.global_position=room.to_global(Vector3(2.4,0.02,-0.25))
	node.rotation.y=PI
	node.play_motion("idle")
	# Hold the sit pose every frame, exactly like the game does.
	node.pose_fixer=Callable(room,"_apply_sit")
	await create_timer(1.5).timeout
	# Wide view of the manicure zone (chair + table + stool).
	await shoot(room.to_global(Vector3(4.6,1.7,3.6)),room.to_global(Vector3(2.0,0.6,-0.4)),"res://../previews/nail_zone.png")
	# Side close-up to check leg/table clipping.
	await shoot(room.to_global(Vector3(4.2,1.1,1.4)),room.to_global(Vector3(2.3,0.55,0.1)),"res://../previews/nail_side.png")
	print("NAILK | client pos=",node.global_position)
	quit(0)
func _initialize() -> void:
	call_deferred("run")

extends SceneTree
var game:Node3D
var visits:Node
var capture:bool="--capture" in OS.get_cmdline_user_args()
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error("HOME_CHECK_FAIL: "+message)
func snap(label:String) -> void:
	if not capture:return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/home_"+label+".png"))
func face_door(d:Dictionary) -> void:
	visits.place_player(d.landing,atan2(d.normal.x,d.normal.z))
	game.camera.look_at(d.point)
func test_routes(room:Node3D) -> void:
	var space:=game.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.32
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	query.transform.origin=room.to_global(room.entry)+Vector3.UP*.9
	check(space.intersect_shape(query).is_empty(),"safe spawn %d"%room.variant)
	var free:Dictionary={};var step:=.4
	for x in range(int(-room.size.x/2/step)+1,int(room.size.x/2/step)):
		for z in range(int(-room.size.y/2/step)+1,int(room.size.y/2/step)):
			var cell:=Vector2i(x,z)
			query.transform.origin=room.to_global(Vector3(x*step,.96,z*step))
			if space.intersect_shape(query).is_empty():free[cell]=true
	var start:=Vector2i(roundi(room.entry.x/step),roundi(room.entry.z/step))
	check(free.has(start),"entrance connects to floor grid %d"%room.variant)
	var seen:Dictionary={start:true};var queue:Array[Vector2i]=[start];var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor];cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=cell+direction
			if seen.has(next) or not free.has(next):continue
			query.transform.origin=room.to_global(Vector3(cell.x*step,.96,cell.y*step))
			query.motion=Vector3(direction.x*step,0,direction.y*step)
			if space.cast_motion(query)[0]<.99:continue
			seen[next]=true;queue.append(next)
	query.motion=Vector3.ZERO
	for target in room.walk_targets:
		query.transform.origin=room.to_global(target)+Vector3.UP*.9
		check(space.intersect_shape(query).is_empty(),"target clear %d %s"%[room.variant,target])
		var best:=100.0
		for cell in seen:
			var point:=Vector3(cell.x*step,.08,cell.y*step)
			if point.distance_to(target)>=best:continue
			query.transform.origin=room.to_global(point)+Vector3.UP*.9;query.motion=target-point
			if space.cast_motion(query)[0]>.99:best=point.distance_to(target)
		check(best<.65,"walkable route to room %d target %s nearest %.2f"%[room.variant,target,best])
		query.motion=Vector3.ZERO
	for direction in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var from:Vector3=room.to_global(room.entry+Vector3.UP*1.2)
		var ray:=PhysicsRayQueryParameters3D.create(from,from+direction*20,1)
		check(not space.intersect_ray(ray).is_empty(),"enclosed room %d %s"%[room.variant,direction])
	print("HOME_ROUTES | variant=",room.variant," reachable cells=",seen.size()," targets=",room.walk_targets.size())
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.set_physics_process(false)
	visits=game.home_visits
	check(visits.rooms.size()==5,"five distinct homes")
	check(visits.doors.size()==142,"all accessible residential doors")
	var chosen:Dictionary={}
	for i in visits.doors.size():
		var d:Dictionary=visits.doors[i]
		face_door(d)
		check(visits.nearby_home()==i,"correct exterior door "+d.id)
		if not chosen.has(int(d.variant)):chosen[int(d.variant)]=i
		game.camera.rotation.y+=PI
		check(visits.nearby_home()!=i,"must face door "+d.id)
		visits.place_player(d.point-d.normal*1.2,0)
		check(visits.nearby_home()!=i,"cannot enter from behind "+d.id)
	check(chosen.size()==5,"all five layouts assigned")
	for variant in 5:
		var index:int=chosen[variant];var d:Dictionary=visits.doors[index]
		game.story.home_id=d.id # Each layout is our home for this geometry-only check.
		face_door(d);var street_position:Vector3=game.player.position
		game.set_capture(false);game.interact();check(not visits.busy,"paused E ignored");game.set_capture(true)
		game.interact();check(visits.busy,"E starts home transition")
		game.interact();game.shop_visits.interact()
		await visits.transition_finished
		check(visits.current_home==variant and visits.current_door==index,"correct home")
		check(not game.town.visible and game.town.player==null,"hide street indoors")
		check(not game.shop_visits.inside() and not game.shop_visits.busy,"no competing shop transition")
		var room:Node3D=visits.rooms[variant]
		check(game.player.position.distance_to(room.to_global(room.entry))<.01,"interior spawn")
		check(game.camera.environment==room.interior_environment,"interior lighting")
		test_routes(room)
		var street_clock:float=game.town.time
		game.set_capture(false);game.set_capture(true)
		var walking_start:Vector3=game.player.position
		Input.action_press("forward")
		for tick in 30:
			game._physics_process(1.0/60)
			await physics_frame
		Input.action_release("forward")
		check(is_equal_approx(game.town.time,street_clock),"hidden street stays suspended, including after pause")
		check(game.player.position.distance_to(walking_start)>.8,"normal walking indoors")
		check(absf(game.player.position.y-room.position.y)<.12,"player stays on indoor floor")
		visits.reset_inside()
		game._physics_process(0)
		await snap("%d_entry"%variant)
		for j in room.walk_targets.size():
			if not capture:break
			visits.place_player(room.to_global(room.walk_targets[j]),0)
			game.camera.look_at(room.to_global(room.walk_targets[j]+Vector3(.2,.8,-2.5)))
			await snap("%d_detail_%d"%[variant,j])
		visits.place_player(room.to_global(Vector3(0,.08,0)),PI)
		game.interact();check(not visits.busy,"no exit far from door")
		game.reset();check(game.player.position.distance_to(room.to_global(room.entry))<.01,"R resets inside home")
		game.camera.rotation=Vector3(0,PI,0)
		check(visits.at_exit(),"exit detected")
		game.interact();check(visits.busy,"E starts exit");await visits.transition_finished
		check(not visits.inside() and game.town.visible and game.town.player==game.player,"return to street")
		check(game.town.time>street_clock,"street simulation resumes after exit")
		check(game.player.position.distance_to(street_position)<.01,"exact same exterior door")
		check(game.camera.environment==null and game.player.velocity==Vector3.ZERO,"reset environment and velocity")
		print("HOME_ROUND_TRIP_PASS | ",room.title," | ",d.id)
	print("HOME_INTERIOR_CHECK_", "PASS" if failures.is_empty() else "FAIL", " | doors=",visits.doors.size()," | layouts=5 | failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

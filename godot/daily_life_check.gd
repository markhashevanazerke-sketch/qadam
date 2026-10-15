extends SceneTree
var game:Node3D
var state:Node
var life:Node
var failures:Array[String]=[]
var spots:Dictionary={}
func _initialize() -> void:
	create_timer(180).timeout.connect(func():push_error("DAILY_TIMEOUT");quit(1))
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error("DAILY_FAIL: "+label)
func frames(n:int=2) -> void:
	for i in n:await physics_frame
func reachable(room:Node3D) -> Array[Vector3]:
	var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.32
	query.shape=capsule;query.collision_mask=1;var space:=game.get_world_3d().direct_space_state
	var free:Dictionary={};var step:=.35
	for x in range(int(-room.size.x/2/step)+1,int(room.size.x/2/step)):
		for z in range(int(-room.size.y/2/step)+1,int(room.size.y/2/step)):
			query.transform.origin=room.to_global(Vector3(x*step,.94,z*step))
			if space.intersect_shape(query).is_empty():free[Vector2i(x,z)]=true
	var start:=Vector2i(roundi(room.entry.x/step),roundi(room.entry.z/step));var seen:Dictionary={start:true};var queue:Array[Vector2i]=[start];var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor];cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=cell+direction
			if seen.has(next) or not free.has(next):continue
			query.transform.origin=room.to_global(Vector3(cell.x*step,.94,cell.y*step));query.motion=Vector3(direction.x*step,0,direction.y*step)
			if space.cast_motion(query)[0]<.99:continue
			seen[next]=true;queue.append(next)
	var result:Array[Vector3]=[]
	for cell in seen:result.append(room.to_global(Vector3(cell.x*step,.08,cell.y*step)))
	return result
func discover(room:Node3D) -> void:
	spots={};var points:=reachable(room)
	var targets:={"toilet":room.get_node("Bathroom/ToiletSeat"),"wash":room.get_node("Bathroom/Basin"),"sit":room.get_node("Sofa/Seat")}
	for node in room.get_children():
		if str(node.name).begins_with("DiningTable") or str(node.name).begins_with("CoffeeTable"):targets.eat=node.get_node("Top")
		if str(node.name).begins_with("DoubleBed") or str(node.name).begins_with("SingleBed"):targets.sleep=node.get_node("Mattress")
	for action in targets:
		var aim:Vector3=targets[action].global_position
		points.sort_custom(func(a:Vector3,b:Vector3):return a.distance_squared_to(aim)<b.distance_squared_to(aim))
		for point in points:
			game.player.global_position=point;game.camera.position=Vector3.UP*1.65;game.camera.look_at(aim)
			var found:Dictionary=life.target()
			if found.get("action","")==action:spots[action]={"point":point,"aim":aim};break
		check(spots.has(action),"walkable first-hit interaction layout %d / %s"%[room.variant,action])
	print("DAILY_LAYOUT | ",room.variant," reachable cells=",points.size()," actions=",spots.keys())
func aim(action:String) -> bool:
	if not spots.has(action):return false
	game.player.global_position=spots[action].point;game.camera.position=Vector3.UP*1.65;game.camera.look_at(spots[action].aim)
	return true
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(3).timeout
	game.set_physics_process(false);state=game.story;life=game.daily_life;state.set_process(false)
	state.elapsed=0;check(state.clock_text()=="09:00","morning")
	state.advance(300);check(state.clock_text()=="13:30","half workday")
	state.advance(300);check(state.clock_text()=="18:00" and state.day()==1,"exact 10-minute shift")
	check(not state.collect(0),"no orders after shift")
	state.advance(9000);check(state.day()==1 and state.clock_text()=="23:59","no automatic next day")
	state.elapsed=600
	var speed:=0.0
	for i in 8:speed=state.movement_speed(1,true,true)
	check(state.exhausted and speed==1.85 and state.stamina==0,"sprint exhaustion")
	for i in 4:state.movement_speed(1,false,false)
	check(state.movement_speed(.01,true,true)==5.4,"sprint recovers")
	var chosen:Dictionary={}
	for i in game.home_visits.doors.size():chosen[game.home_visits.doors[i].variant]=i
	for variant in 5:
		var index:int=chosen[variant];state.home_id=game.home_visits.doors[index].id
		game.home_visits._transition(index);await game.home_visits.transition_finished
		discover(game.home_visits.rooms[variant])
		var room:Node3D=game.home_visits.rooms[variant]
		check(not room.has_node("Armchair"),"extra chair removed")
		if aim("sit"):
			var at:Vector3=game.player.position;game.interact();await create_timer(.4).timeout
			var sofa:Node3D=room.get_node("Sofa")
			var eye:Vector3=sofa.to_local(game.camera.global_position)
			check(life.seated and absf(absf(eye.x)-.49)<.01 and absf(eye.y-1.25)<.01 and absf(eye.z-.12)<.01,"E sits on sofa cushion layout %d"%variant)
			check((-game.camera.global_basis.z).dot(sofa.global_basis.z)>.99,"seated view faces room")
			Input.action_press("forward");game._physics_process(.1);Input.action_release("forward")
			check(game.player.position==at,"cannot walk seated")
			game.interact();check(not life.seated and is_equal_approx(game.camera.position.y,1.65) and game.player.position==at,"E returns to clear approach")
		if variant==4:
			check(not state.sleep_ready(),"sleep needs evening routine")
			if aim("toilet"):
				game.interact();await create_timer(2.7).timeout;check(state.toilet_done and not state.hands_clean,"E toilet")
			if aim("wash"):
				game.interact();await create_timer(3.2).timeout;check(state.hands_clean,"E wash")
			if aim("eat"):
				game.interact();check(not life.busy,"no food means no meal")
				state.meals=1;game.interact();await create_timer(4.2).timeout;check(state.dinner_done and state.meals==0,"E eat consumes food")
			var path:="user://daily_test_%d.json"%OS.get_process_id()
			state.meals=2;state.write_progress(path);state.meals=0;state.elapsed=0;state.dinner_done=false
			check(state.load_progress(path) and state.meals==2 and state.dinner_done and state.elapsed==600,"routine save/load")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if aim("sleep"):
				game.interact();check(life.busy,"E starts sleep")
				await create_timer(1.45).timeout;check(life.fade.color.a>.99,"sleep fades black")
				await create_timer(3.6).timeout
				check(not life.busy and state.day()==2 and state.clock_text()=="09:00","wake next day")
				check(not state.dinner_done and not state.toilet_done and state.stamina==100,"morning reset")
		game.home_visits._transition(-1);await game.home_visits.transition_finished
	for i in 3:
		game.shop_visits._transition(i);await game.shop_visits.transition_finished
		var room:Node3D=game.shop_visits.rooms[i]
		game.player.global_position=room.to_global(room.checkout_approach);game.camera.position=Vector3.UP*1.65
		var bounds:AABB=room.checkout.mesh.get_aabb();game.camera.look_at(room.checkout.to_global(bounds.get_center()))
		check(life.target().get("action","")=="buy","E checkout in shop %d"%i)
		state.money=250;state.meals=0;state.food_credit=0;state.dinner_done=false;game.interact()
		check(state.money==50 and state.meals==1,"purchase charges 200 shop %d"%i)
		state.meals=0;check(state.buy_meal() and state.food_credit==200,"one meal on account prevents softlock")
		check(not state.buy_meal(),"cannot repeat free food")
		if i==0:
			state.employer=0;state.pending_payment=900
			check(state.claim_payment(0) and state.money==750 and state.food_credit==0,"food debt repaid from wages")
		game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	print("DAILY_CHECK_DONE | failures=",failures)
	game.soundscape.set_process(false);game.soundscape.set_physics_process(false)
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	for player in game.find_children("*","AudioStreamPlayer3D",true,false):player.stop()
	await create_timer(.15).timeout
	game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)

extends Node
const Layout=preload("res://district_layout.gd")
# Walkable graph is built from actual building footprints and physics colliders.
# Every citizen chooses destinations independently, including courtyards and crossings.
const STEP:=1.4
const BODY_RADIUS:=.36
const BODY_HEIGHT:=1.78
var town:Node3D
var graph:=AStar2D.new()
var cells:Dictionary={}
var destinations:Array[int]=[]
var ready_for_walk:=false
var rng:=RandomNumberGenerator.new()
var trips:=0
var crossings:=0
var characters:={}

func _ready() -> void:
	town=get_parent()
	rng.seed=14571
	_build.call_deferred()

func on_road(p:Vector3) -> bool:
	return (absf(absf(p.x)-27)<3.9 and absf(p.z)<Layout.ROAD_END+4) or (absf(p.z)<3.9 and absf(p.x)<30.8) or (absf(absf(p.z)-Layout.ROAD_END)<3.9 and absf(p.x)<31)

func crossing_cell(p:Vector3) -> bool:
	return (absf(absf(p.z)-8.4)<.75 and absf(absf(p.x)-27)<5.7) or (absf(p.x)<.75 and absf(p.z)<5.7)

func _build() -> void:
	await get_tree().physics_frame
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.38
	capsule.height=1.5
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.collision_mask=1
	var space:=town.get_world_3d().direct_space_state
	var id:=0
	for x in range(-26,27):
		for z in range(-36,37):
			var p:=Vector3(x*STEP,.035,z*STEP)
			if on_road(p) and not crossing_cell(p):continue
			var blocked:=false
			for box in town.footprints:
				if p.x>box.position.x-.48 and p.x<box.end.x+.48 and p.z>box.position.z-.48 and p.z<box.end.z+.48:
					blocked=true;break
			if blocked:continue
			query.transform=Transform3D(Basis.IDENTITY,town.to_global(p)+Vector3(0,.82,0))
			if not space.intersect_shape(query,1).is_empty():continue
			graph.add_point(id,Vector2(p.x,p.z))
			cells[Vector2i(x,z)]=id
			id+=1
	for cell in cells:
		for offset in [Vector2i(1,0),Vector2i(0,1)]:
			if cells.has(cell+offset):
				var from:Vector2=graph.get_point_position(cells[cell])
				var to:Vector2=graph.get_point_position(cells[cell+offset])
				query.transform.origin=town.to_global(Vector3(from.x,.035,from.y))+Vector3(0,.825,0)
				query.motion=town.global_basis*Vector3(to.x-from.x,0,to.y-from.y)
				var cast:PackedFloat32Array=space.cast_motion(query)
				if cast[0]>.99:graph.connect_points(cells[cell],cells[cell+offset])
	# Spawn only in the component connected to the central promenade.
	var start:int=nearest_point(Vector2(0,38))
	var frontier:Array[int]=[start]
	var seen:Dictionary={start:true}
	while not frontier.is_empty():
		var at:int=frontier.pop_back()
		var p:Vector2=graph.get_point_position(at)
		if not on_road(Vector3(p.x,0,p.y)):destinations.append(at)
		for next in graph.get_point_connections(at):
			if not seen.has(next):seen[next]=true;frontier.append(next)
	for i in 32:
		var point:int=destinations[rng.randi_range(0,destinations.size()-1)]
		for attempt in 100:
			point=destinations[rng.randi_range(0,destinations.size()-1)]
			var clear:=true
			var pos:Vector2=graph.get_point_position(point)
			for w in town.walkers:
				if Vector2(w.node.position.x,w.node.position.z).distance_to(pos)<1.8:clear=false;break
			if is_instance_valid(town.player) and town.to_global(Vector3(pos.x,.035,pos.y)).distance_to(town.player.global_position)<1.2:clear=false
			if clear:break
		var n:=CharacterBody3D.new()
		n.name="Citizen_%02d"%i
		n.set_script(preload("res://citizen_visual.gd"))
		n.character_id=["erlan","asel","miras"][i%3]
		n.outfit_variant=i%8
		n.initial_motion="idle"
		n.scale=Vector3.ONE/Layout.ENVIRONMENT_SCALE
		n.collision_layer=8
		n.collision_mask=1|2|4|8
		n.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
		n.safe_margin=.002
		var shape:=CollisionShape3D.new();var body_shape:=CapsuleShape3D.new()
		body_shape.radius=BODY_RADIUS;body_shape.height=BODY_HEIGHT;shape.shape=body_shape
		shape.position.y=BODY_HEIGHT/2;n.add_child(shape)
		town.add_child(n)
		var pos:Vector2=graph.get_point_position(point)
		n.position=Vector3(pos.x,.035,pos.y)
		characters[n.model_id]=true
		var w:Dictionary={"node":n,"point":point,"path":PackedVector2Array(),"index":0,"speed":rng.randf_range(.9,1.35),"wait":rng.randf_range(0,3),"crossing":false,"id":i,"travel":0.0,"trips":0,"waiting_signal":false,"blocked_for":0.0,"avoid_side":1.0}
		town.walkers.append(w)
	ready_for_walk=true
	print("CITIZENS_READY | cartoon models=",characters.keys()," | count=",town.walkers.size()," | connected destinations=",destinations.size())

func nearest_point(at:Vector2) -> int:
	# An occupied rounded grid cell is the exact closest point on this regular grid.
	var cell:=Vector2i(roundi(at.x/STEP),roundi(at.y/STEP))
	if cells.has(cell) and not graph.is_point_disabled(cells[cell]):return cells[cell]
	return graph.get_closest_point(at)

func choose_destination(w:Dictionary) -> void:
	var origin:int=nearest_point(Vector2(w.node.position.x,w.node.position.z))
	var target:int=origin
	for attempt in 30:
		target=destinations[rng.randi_range(0,destinations.size()-1)]
		if graph.get_point_position(origin).distance_to(graph.get_point_position(target))>18:break
	var disabled:Array[int]=[]
	for other in town.walkers:
		if other.id==w.id:continue
		var point:int=nearest_point(Vector2(other.node.position.x,other.node.position.z))
		if point!=origin and point!=target and not graph.is_point_disabled(point):
			graph.set_point_disabled(point,true);disabled.append(point)
	if is_instance_valid(town.player):
		var player_at:Vector3=town.to_local(town.player.global_position)
		var point:int=nearest_point(Vector2(player_at.x,player_at.z))
		if point!=origin and point!=target and not graph.is_point_disabled(point):
			graph.set_point_disabled(point,true);disabled.append(point)
	w.path=graph.get_point_path(origin,target)
	for point in disabled:graph.set_point_disabled(point,false)
	if w.path.is_empty():w.path=graph.get_point_path(origin,target)
	w.index=1
	w.point=target

func _person_ahead(w:Dictionary,direction:Vector3) -> bool:
	var origin:Vector3=w.node.global_position
	var side:=direction.cross(Vector3.UP)
	for other in town.walkers:
		if other.id==w.id:continue
		var diff:Vector3=other.node.global_position-origin
		var along:=diff.dot(direction)
		if along>-.05 and along<1.55 and absf(diff.dot(side))<.82:return true
	if is_instance_valid(town.player):
		var diff:Vector3=town.player.global_position-origin
		var along:=diff.dot(direction)
		if absf(diff.y)<1.6 and along>-.05 and along<1.55 and absf(diff.dot(side))<.82:return true
	return false

func _road_permitted(w:Dictionary,next:Vector3) -> bool:
	if not on_road(next) or w.crossing:return true
	if not town.traffic.pedestrians_allowed():w.waiting_signal=true;return false
	for car in town.vehicles:
		var separation:Vector3=next-car.node.position
		if absf(separation.dot(car.dir))<car.half+1.0 and absf(separation.dot(car.dir.cross(Vector3.UP)))<2.0:return false
	return true

func _step(w:Dictionary,direction:Vector3,distance:float) -> float:
	# Sweep the real capsule against buildings, cars, the player and every citizen.
	# Even an off-camera or waiting citizen remains physically solid.
	var body:CharacterBody3D=w.node
	var local_motion:Vector3=town.global_basis.inverse()*(direction*distance)
	if not _road_permitted(w,body.position+local_motion):return 0.0
	var before:Vector3=body.global_position
	body.move_and_collide(direction*distance,false,.002)
	return before.distance_to(body.global_position)

func tick(delta:float) -> void:
	if not ready_for_walk:return
	var camera:Camera3D=town.get_viewport().get_camera_3d()
	for w in town.walkers:
		w.node.update_detail(camera,delta)
		if w.node.get_meta("in_dialogue",false):w.node.play_motion("idle");continue
		w.waiting_signal=false
		if w.wait>0:
			w.wait-=delta;w.node.play_motion("idle");continue
		if w.index>=w.path.size():
			if not w.path.is_empty():trips+=1;w.trips+=1
			choose_destination(w);w.wait=rng.randf_range(1,4);w.node.play_motion("idle");continue
		var target:Vector2=w.path[w.index]
		var destination:=town.to_global(Vector3(target.x,.035,target.y))
		var diff:Vector3=destination-w.node.global_position;diff.y=0
		if diff.length()<.065:w.index+=1;continue
		var direction:Vector3=diff.normalized()
		var distance:float=minf(diff.length(),w.speed*delta)
		var before:Vector3=w.node.global_position
		var travelled:=0.0
		if _road_permitted(w,w.node.position+town.global_basis.inverse()*(direction*distance)):
			if _person_ahead(w,direction):
				# Both approaching people keep to their own right. Test the alternative
				# only when that side is obstructed; the chosen side persists.
				var side:=direction.cross(Vector3.UP)
				for sign_dir in [w.avoid_side,-w.avoid_side]:
					var steering:Vector3=(direction*.35+side*sign_dir).normalized()
					var body:CharacterBody3D=w.node
					if body.test_move(body.global_transform,steering*.26,null,.002):continue
					if not _road_permitted(w,body.position+town.global_basis.inverse()*(steering*.26)):continue
					travelled=_step(w,steering,distance)
					if travelled>.001:w.avoid_side=sign_dir;break
			if travelled<.001:travelled=_step(w,direction,distance)
		if travelled>.001:
			w.blocked_for=0;w.travel+=travelled
			var actual:Vector3=(w.node.global_position-before).normalized()
			w.node.rotation.y=lerp_angle(w.node.rotation.y,atan2(-actual.x,-actual.z),1-exp(-8*delta))
			w.node.play_motion("walk",minf(w.speed,travelled/maxf(delta,.00001))/w.node.walk_reference_speed)
			var entering:=on_road(w.node.position)
			if entering and not w.crossing:crossings+=1
			w.crossing=entering
			if w.node.global_position.distance_to(destination)<.065:w.index+=1
		else:
			w.node.play_motion("idle")
			if not w.waiting_signal:
				w.blocked_for+=delta
				if w.blocked_for>2.5:
					choose_destination(w);w.blocked_for=0;w.avoid_side=1.0

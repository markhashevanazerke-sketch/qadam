extends SceneTree
class TestTown extends Node3D:
	var vehicles:Array[Dictionary]=[]
	var walkers:Array[Dictionary]=[]
	var player:Node3D
	func asset(_id:String,at:Vector3,_s:float=1,_a:float=0,_solid:bool=false)->Node3D:
		var n:=Node3D.new();add_child(n);n.position=at;return n
	func collision(_at:Vector3,_size:Vector3,_label:String,_layer:int)->StaticBody3D:
		var n:=StaticBody3D.new();add_child(n);return n
	func sample(points:Array[Vector3],distance:float)->Dictionary:
		for i in points.size():
			var a:Vector3=points[i];var b:Vector3=points[(i+1)%points.size()];var length:=a.distance_to(b)
			if distance<=length:return {"at":a.lerp(b,distance/length),"dir":(b-a).normalized()}
			distance-=length
		return {"at":points[0],"dir":Vector3.FORWARD}
func _initialize():call_deferred("run")
func run():
	for scenario in [["60fps",1.0/60,Vector3(0,0,38)],["30fps",1.0/30,Vector3(0,0,38)],["blocked_exit",1.0/60,Vector3(-28.8,0,13)],["junction_player",1.0/60,Vector3(-27,0,0)],["crosswalk_player",1.0/60,Vector3(0,0,1.8)]]:
		var town:=TestTown.new();root.add_child(town);town.player=Node3D.new();town.add_child(town.player);town.player.position=scenario[2]
		var traffic=load("res://district_traffic.gd").new();town.add_child(traffic)
		var dt:float=scenario[1];var frozen:=0.0
		var recovery_start:Array[float]=[]
		for frame in int(660/dt):
			if frame==int(120/dt):
				town.player.position=Vector3(0,0,38)
				for car in traffic.vehicles:recovery_start.append(car.travel)
			traffic.tick(dt)
			var moving:=false
			for car in traffic.vehicles:
				if car.speed>.1:moving=true
			frozen=0 if moving else frozen+dt
			if frame>int(180/dt) and frozen>45:
				print("DEADLOCK ",scenario[0]," time=",frame*dt," phase=",traffic.phase," phase_time=",traffic.phase_time)
				for car in traffic.vehicles:print("CAR ",car.id," route=",car.route," at=",car.node.position," s=",car.s," gate=",car.active_gate," stop=",car.stop_time)
				quit(1);return
		var minimum_recovery:=INF
		for i in traffic.vehicles.size():minimum_recovery=minf(minimum_recovery,traffic.vehicles[i].travel-recovery_start[i])
		if minimum_recovery<100:
			push_error("A vehicle failed to recover: "+str(scenario[0]));quit(1);return
		print("RECOVERY min car travel=",minimum_recovery)
		print("SCENARIO ",scenario[0]," passages=",traffic.gate_passages," cycles=",traffic.cycles," max_phase=",traffic.phase_max_time," max_stop=",traffic.max_stop_time)
		town.free()
	print("TRAFFIC_REGRESSION_PASS");quit()

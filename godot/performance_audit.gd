extends SceneTree
var game:Node3D
var results:Array[Dictionary]=[]
var tag:="baseline"
func _initialize():call_deferred("run")
func measure(label:String) -> void:
	await create_timer(1.5).timeout
	var times:Array[float]=[];var cpu:=0.0;var physics:=0.0;var draws:=0.0;var tris:=0.0
	var begin:=Time.get_ticks_usec();var previous:=begin
	while Time.get_ticks_usec()-begin<2500000:
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
		cpu+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var count:=times.size();var sum:=0.0
	for time in times:sum+=time
	times.sort()
	var r:={"scene":label,"fps":1000.0/(sum/count),"median_ms":times[count/2],"p95_ms":times[mini(count-1,int(count*.95))],"cpu_ms":cpu/count,"physics_ms":physics/count,"draws":draws/count,"primitives":tris/count}
	results.append(r);print("PROFILE ",JSON.stringify(r))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/perf_"+tag+"_"+label+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):tag=arg.trim_prefix("--tag=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	game.set_physics_process(false)
	for pose in [["courtyard",Vector3(0,1.75,38),Vector3(0,5,-30)],["avenue",Vector3(-24,1.75,38),Vector3(-27,2,-30)],["crossing",Vector3(-20,1.75,14),Vector3(-27,2,-7)]]:
		game.player.position=game.Layout.human_position(pose[1])-Vector3.UP*1.65
		game.camera.position=Vector3.UP*1.65;game.camera.look_at(game.town.to_global(pose[2]))
		await measure(pose[0])
	if "--diagnose" in OS.get_cmdline_user_args():
		game.town.paused=true
		for w in game.town.walkers:w.node.visible=false;w.node.animation.active=false
		await measure("no_people")
		var sun:DirectionalLight3D=game.find_children("*","DirectionalLight3D",true,false)[0]
		sun.shadow_enabled=false;await measure("no_shadows");sun.shadow_enabled=true
		var world:WorldEnvironment=game.find_children("*","WorldEnvironment",true,false)[0]
		var sky_material:Material=world.environment.sky.sky_material
		world.environment.sky.sky_material=ProceduralSkyMaterial.new();await measure("simple_sky");world.environment.sky.sky_material=sky_material
		game.town.paused=false
	for i in [0,1]:
		var door:int=-1
		for j in game.home_visits.doors.size():
			if game.home_visits.doors[j].variant==i:door=j;break
		game.story.home_id=game.home_visits.doors[door].id # Authorized interior fixture.
		game.home_visits._transition(door);await game.home_visits.transition_finished
		await measure("home_%d"%i)
		game.home_visits._transition(-1);await game.home_visits.transition_finished
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	await measure("shop")
	var file:=FileAccess.open("res://../previews/performance_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"size":root.size,"vsync":false,"results":results},"  "))
	quit()

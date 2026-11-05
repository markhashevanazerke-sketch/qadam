extends SceneTree
var game:Node3D
func shoot(path:String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT | ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	var ui:Node=game.story_ui;var state:Node=game.story
	# --- 1. Night street with lit lamps ---------------------------------------
	state.elapsed=999.0
	game.daily_life.update_daylight()
	game.player.position=Vector3(2,0.2,30)
	game.yaw=atan2(-20,1);game.pitch=-0.08
	game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await shoot("res://../previews/evening_street.png")
	# --- 2. Wordbook phone page -------------------------------------------------
	for pair in [
		["Ерлан","cashier_0","Сәлеметсіз бе! Менің атым Натан. Мен курьер болып жұмыс іздеймін.","Сәлем! Бізге курьер керек. Жұмыс істегің келе ме? Еңбекақы әр тапсырысқа."],
		["Әсел","citizen_01","Сәлем! Күн қалай өтті? Мен таңертең нан алдым.","Сәлем! Күнім жақсы өтті. Таңертең жаңа піскен нан алдым. Саған да ұсынамын."],
		["Мирас","citizen_02","Сәлем! Сен велосипед жинап жүрген бе? Қанша ақша қажет?","Сәлем! Иә, велосипедке ақша жинап жүрмін. Тағы сәл ақша қажет."],
		["Аружан","cashier_4","Салом... ой, сәлеметсіз бе! Салонға шампунь алып келдім.","Сәлеметсіз бе! Көп рақмет, шампунь дәл керегіміз еді. Сыйақыңызды қолға алыңыз."]
	]:
		game.wordbook.record(str(pair[0]),str(pair[2]),str(pair[3]))
	ui.open_phone();await create_timer(0.4).timeout
	ui._phone_page("words");await create_timer(0.5).timeout
	await shoot("res://../previews/phone_wordbook.png")
	ui.close_modal()
	# --- 3. Evening tea from the neighbour -------------------------------------
	state.elapsed=650.0
	game.daily_life.update_daylight()
	var doors:Array=game.home_visits.doors
	var d:Dictionary=doors[1]
	state.neighbor_favors[d.id]=3;state.favor_done[d.id]=true;state.tea_pending=1
	state.stamina=50
	game.home_visits._transition(state.home_index())
	var guard:float=0.0
	while game.home_visits.busy and guard<10.0:
		await create_timer(0.1).timeout;guard+=0.1
	await create_timer(0.8).timeout
	# Face the table where the cup was placed.
	var room:Node3D=game.home_visits.rooms[game.home_visits.current_home]
	var cup:=room.find_child("NeighborTea",true,false)
	if cup!=null:
		var to:Vector3=cup.global_position
		var from:Vector3=game.player.global_position+Vector3(0,1.65,0)
		game.yaw=atan2(-(to.x-from.x),-(to.z-from.z));game.pitch=atan2(to.y-1.65,Vector2(to.x-from.x,to.z-from.z).length())
		game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await shoot("res://../previews/evening_tea.png")
	print("EVENING_SHOT_DONE | cup=",cup!=null," | stamina=",state.stamina," | xp=",game.wordbook.xp," | words=",game.wordbook.entries.size())
	quit(0)
func _initialize() -> void:
	call_deferred("run")

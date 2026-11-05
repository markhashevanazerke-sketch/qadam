extends Node3D
const Layout=preload("res://district_layout.gd")
const SPAWN := Vector3(0,.2,38)
var player:CharacterBody3D
var player_name_label:Label3D
var blob_material:StandardMaterial3D
var camera:Camera3D
var town:Node3D
var outdoor_sun:DirectionalLight3D
var sky_material:ShaderMaterial
var shop_visits:Node
var home_visits:Node
var soundscape:Node
var daily_life:CanvasLayer
var story:Node
var wordbook:Node
var speech:Node
var story_ui:Node
var main_menu:CanvasLayer
var session_started:=false
var yaw:=0.0
var pitch:=.04
var captured:=true
var overview:=false
var photo_mode:=false
var photo_hint:Label
var hud:Label
var hud_cache:=""
var pause:Label
var minimap:Control
var tut_panel:PanelContainer
var tut_walk:=0.0
var tut_time:=0.0
var tut_toast_age:=0.0
var tut_fade:=0.0
var tut_done:=false
var tut_save:=0.0
var automated:bool="--home-check" in OS.get_cmdline_user_args() or "--shop-check" in OS.get_cmdline_user_args() or "--traffic-live-check" in OS.get_cmdline_user_args() or "--performance-check" in OS.get_cmdline_user_args() or "--map-check" in OS.get_cmdline_user_args() or "--map-capture" in OS.get_cmdline_user_args() or "--salon-check" in OS.get_cmdline_user_args() or "--salon-diag" in OS.get_cmdline_user_args() or "--salon-shot" in OS.get_cmdline_user_args() or "--offline-check" in OS.get_cmdline_user_args()

func _ready() -> void:
	for action in {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"run":KEY_SHIFT}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key:=InputEventKey.new()
			key.physical_keycode={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"run":KEY_SHIFT}[action]
			InputMap.action_add_event(action,key)
	_environment()
	town=Node3D.new()
	town.name="NazerkeQuarter"
	town.set_script(preload("res://compact_map.gd"))
	add_child(town)
	# The district's name board near the entrance the player spawns on.
	var board:=Label3D.new();board.name="DistrictSign"
	board.text="КЕШКІ АУДАН"
	board.font_size=64
	board.pixel_size=.008
	board.modulate=Color("ffd98a")
	board.outline_size=6
	board.outline_modulate=Color("132c3b")
	board.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	town.add_child(board)
	board.position=Vector3(0,4.6,26)
	player=CharacterBody3D.new()
	player.name="Player"
	player.collision_layer=2
	player.collision_mask=1|4|8
	player.floor_snap_length=.35
	var collider:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.75
	capsule.radius=.32
	collider.shape=capsule
	collider.position.y=.875
	player.add_child(collider)
	# The player's name floats above his head (the shop facade keeps a generic
	# sign), and a soft ground shadow under his feet grounds him in the street.
	player_name_label=Label3D.new()
	player_name_label.name="PlayerName"
	player_name_label.text="Натан"
	player_name_label.font_size=44
	player_name_label.pixel_size=.006
	player_name_label.modulate=Color("fff3dc")
	player_name_label.outline_size=6
	player_name_label.outline_modulate=Color("182830")
	player_name_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	player_name_label.position=Vector3(0,2.1,0)
	player.add_child(player_name_label)
	blob_material=StandardMaterial3D.new()
	blob_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_material.albedo_color=Color(0,0,0,.32)
	var blob:=MeshInstance3D.new()
	blob.name="GroundShadow"
	blob.material_override=blob_material
	blob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc:=CylinderMesh.new()
	disc.top_radius=.52
	disc.bottom_radius=.52
	disc.height=.01
	blob.mesh=disc
	blob.position.y=.02
	player.add_child(blob)
	add_child(player)
	camera=Camera3D.new()
	camera.fov=76
	camera.near=.08
	camera.far=800
	player.add_child(camera)
	camera.current=true
	town.player=player
	reset()
	_hud()
	_load_tut()
	shop_visits=Node.new();shop_visits.set_script(preload("res://shop_visits.gd"));add_child(shop_visits)
	home_visits=Node.new();home_visits.set_script(preload("res://home_visits.gd"));add_child(home_visits)
	soundscape=Node.new();soundscape.set_script(preload("res://district_audio.gd"));add_child(soundscape)
	story=Node.new();story.set_script(preload("res://story_state.gd"));add_child(story)
	story.changed.connect(_sync_player_name)
	_sync_player_name()
	wordbook=Node.new();wordbook.set_script(preload("res://wordbook.gd"));add_child(wordbook)
	story_ui=CanvasLayer.new();story_ui.set_script(preload("res://story_ui.gd"));add_child(story_ui)
	speech=Node.new();speech.set_script(preload("res://speech_bridge.gd"));add_child(speech)
	story_ui.connect_speech()
	daily_life=CanvasLayer.new();daily_life.set_script(preload("res://daily_life.gd"));add_child(daily_life)
	main_menu=CanvasLayer.new();main_menu.set_script(preload("res://start_menu.gd"));add_child(main_menu)
	set_capture(not automated)
	if automated:set_capture(true)
	else:main_menu.open_menu()
	if "--map-check" in OS.get_cmdline_user_args():_check.call_deferred()
	if "--salon-diag" in OS.get_cmdline_user_args():_salon_diag.call_deferred()
	if "--salon-check" in OS.get_cmdline_user_args():_salon_check.call_deferred()
	if "--salon-shot" in OS.get_cmdline_user_args():_salon_shot_views.call_deferred()
	if "--ui-check" in OS.get_cmdline_user_args():_ui_check.call_deferred()
	if "--traffic-live-check" in OS.get_cmdline_user_args():_live_traffic_check.call_deferred()
	if "--map-capture" in OS.get_cmdline_user_args():_capture.call_deferred()
	if "--performance-check" in OS.get_cmdline_user_args():_benchmark.call_deferred()
	print("NAZERKE_QUARTER_READY | authored city models | 5 furnished homes | Baiterek beyond closed north edge")

func _environment() -> void:
	var world:=WorldEnvironment.new()
	var env:=Environment.new()
	world.environment=env
	var sky:=Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_32
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	var material:=ShaderMaterial.new();sky_material=material
	material.shader=preload("res://evening_sky.gdshader")
	sky.sky_material=material
	env.sky=sky
	env.background_mode=Environment.BG_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b1bed6")
	env.ambient_light_energy=.72
	env.fog_enabled=true
	env.fog_light_color=Color("8c8492")
	env.fog_density=.0018
	env.fog_sky_affect=.06
	add_child(world)
	var sun:=DirectionalLight3D.new()
	outdoor_sun=sun;sun.name="OutdoorSun"
	sun.rotation_degrees=Vector3(-24,-38,0)
	sun.light_energy=1.0
	sun.light_color=Color("ffd1a2")
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	get_viewport().mesh_lod_threshold=3.0
	add_child(sun)

func _hud() -> void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	var panel:=PanelContainer.new()
	layer.add_child(panel)
	panel.position=Vector2(20,20)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.04,.075,.09,.88)
	style.set_corner_radius_all(8)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=8
	style.content_margin_bottom=8
	panel.add_theme_stylebox_override("panel",style)
	hud=Label.new()
	hud.add_theme_font_size_override("font_size",15)
	panel.add_child(hud)
	hud.text="Кешкі аудан"
	# Short one-time hint for a brand-new player: bottom of the screen, fades
	# out by itself once they start playing and never returns.
	tut_panel=PanelContainer.new()
	layer.add_child(tut_panel)
	tut_panel.anchor_left=0.5
	tut_panel.anchor_top=1.0
	tut_panel.offset_left=-270.0
	tut_panel.offset_top=-132.0
	tut_panel.offset_right=270.0
	tut_panel.offset_bottom=-64.0
	var toast_style:=StyleBoxFlat.new()
	toast_style.bg_color=Color(.04,.075,.09,.92)
	toast_style.set_corner_radius_all(10)
	toast_style.content_margin_left=18
	toast_style.content_margin_right=18
	toast_style.content_margin_top=10
	toast_style.content_margin_bottom=10
	tut_panel.add_theme_stylebox_override("panel",toast_style)
	var tlabel:=Label.new()
	tlabel.add_theme_font_size_override("font_size",15)
	tlabel.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tlabel.text="WASD — жүру · тінтуір — қарау · Shift — жүгіру · Space — секіру\nE — есік / тапсырыс · F — телефон · R — бастапқы орын"
	tut_panel.add_child(tlabel)
	tut_panel.visible=false
	tut_panel.modulate.a=0.0
	pause=Label.new()
	pause.position=Vector2(20,250)
	pause.text="ҮЗІЛІС · Esc немесе тінтуір — жалғастыру"
	pause.add_theme_font_size_override("font_size",18)
	layer.add_child(pause)
	minimap=load("res://minimap.gd").new()
	minimap.game=self
	minimap.anchor_top=1.0
	minimap.offset_left=20
	minimap.offset_top=-280
	minimap.offset_right=260
	minimap.offset_bottom=-40
	layer.add_child(minimap)

func _load_tut() -> void:
	if not FileAccess.file_exists("user://onboarding.json"):return
	var f:=FileAccess.open("user://onboarding.json",FileAccess.READ)
	var data=JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		tut_walk=float(data.get("walk",0.0))
		tut_time=float(data.get("time",0.0))
		tut_done=bool(data.get("done",false))

func _save_tut() -> void:
	var f:=FileAccess.open("user://onboarding.json",FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"walk":tut_walk,"time":tut_time,"done":tut_done}))

func set_capture(value:bool) -> void:
	captured=value
	var modal:bool=is_instance_valid(story_ui) and story_ui.is_modal()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if value and not automated and not modal else Input.MOUSE_MODE_VISIBLE
	pause.visible=not value and not modal
	set_street_active(not ((is_instance_valid(home_visits) and home_visits.inside()) or (is_instance_valid(shop_visits) and shop_visits.inside())))

func set_street_active(active:bool) -> void:
	town.visible=active
	# Rooms have their own lighting; the world sun must not illuminate them.
	outdoor_sun.visible=active
	outdoor_sun.light_energy=1.0 if active else 0.0
	if active and is_instance_valid(daily_life):daily_life.update_daylight()
	town.paused=not active or not captured
	town.process_mode=Node.PROCESS_MODE_INHERIT if active and captured else Node.PROCESS_MODE_DISABLED

func reset() -> void:
	if is_instance_valid(daily_life):
		if daily_life.busy:return
		if daily_life.seated:daily_life.stand()
	if is_instance_valid(home_visits):
		if home_visits.busy:return
		if home_visits.inside():home_visits.reset_inside();return
	if is_instance_valid(shop_visits):
		if shop_visits.busy:return
		if shop_visits.inside():shop_visits.reset_inside();return
	player.position=clear_street_spawn(Layout.human_position(SPAWN))
	player.velocity=Vector3.ZERO
	camera.position=Vector3(0,1.65,0)
	yaw=0
	pitch=.04
	camera.rotation=Vector3(pitch,yaw,0)
	overview=false

func clear_street_spawn(preferred:Vector3) -> Vector3:
	var query:=PhysicsShapeQueryParameters3D.new()
	var shape:=CapsuleShape3D.new();shape.radius=.33;shape.height=1.75
	query.shape=shape;query.collision_mask=1|4|8;query.exclude=[player.get_rid()]
	for radius in [0.0,1.0,2.0,3.0,4.0]:
		for i in 8:
			var point:Vector3=preferred+Vector3(cos(i*PI/4),0,sin(i*PI/4))*radius
			query.transform.origin=point+Vector3.UP*.875
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return point
	return player.position

func menu_active() -> bool:return is_instance_valid(main_menu) and main_menu.active

func _unhandled_input(event:InputEvent) -> void:
	if automated or menu_active() or (is_instance_valid(daily_life) and daily_life.busy):return
	if is_instance_valid(story_ui) and story_ui.is_modal():return
	if event is InputEventMouseMotion and captured and not overview:
		yaw-=event.relative.x*.002
		pitch=clampf(pitch-event.relative.y*.002,-1.4,1.4)
		camera.rotation=Vector3(pitch,yaw,0)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not captured:set_capture(true)
		else:story_ui.try_talk()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:set_capture(not captured)
			KEY_E:interact()
			KEY_R:reset()
			KEY_M:soundscape.toggle_mute()
			KEY_TAB:
				if shop_visits.inside() or shop_visits.busy or home_visits.inside() or home_visits.busy:return
				if overview:reset()
				else:
					overview=true
					camera.global_position=town.to_global(Vector3(104,108,136))
					camera.look_at(town.to_global(Vector3(0,0,-13)))
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F12:
				if photo_mode:_exit_photo()
				else:_enter_photo()
			KEY_P:
				if photo_mode:_save_photo()

func _enter_photo() -> void:
	if photo_mode or menu_active() or (is_instance_valid(story_ui) and story_ui.is_modal()):return
	if home_visits.busy or shop_visits.busy or daily_life.busy:return
	photo_mode=true
	hud.get_parent().hide();minimap.hide()
	if is_instance_valid(story_ui):story_ui.get_child(0).hide()
	if is_instance_valid(daily_life):daily_life.hide()
	pause.hide()
	if photo_hint==null:
		var layer:=CanvasLayer.new();layer.layer=70;add_child(layer)
		photo_hint=Label.new();layer.add_child(photo_hint)
		photo_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		photo_hint.offset_left=-320;photo_hint.offset_right=320;photo_hint.offset_top=-56;photo_hint.offset_bottom=-20
		photo_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		photo_hint.add_theme_font_size_override("font_size",16)
		photo_hint.add_theme_constant_override("outline_size",6)
		photo_hint.add_theme_color_override("font_outline_color",Color("132c3b"))
	photo_hint.text="Фото-режим · P — суретті сақтау · F12 — шығу"
	photo_hint.show()

func _exit_photo() -> void:
	if not photo_mode:return
	photo_mode=false
	hud.get_parent().show();minimap.show()
	if is_instance_valid(story_ui):story_ui.get_child(0).show()
	if is_instance_valid(daily_life):daily_life.show()
	pause.hide()
	if photo_hint!=null:photo_hint.hide()

func _save_photo() -> void:
	if not photo_mode:return
	var dir:="user://photos"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var t:=Time.get_datetime_dict_from_system()
	var stamp:="%d-%02d-%02d_%02d-%02d-%02d"%[int(t.year),int(t.month),int(t.day),int(t.hour),int(t.minute),int(t.second)]
	var path:="user://photos/photo_%s.png"%stamp
	if photo_hint!=null:photo_hint.hide()
	var img:=get_viewport().get_texture().get_image()
	if img.save_png(ProjectSettings.globalize_path(path))==OK:
		_exit_photo()
		if is_instance_valid(daily_life):daily_life.say("Сурет сақталды · photos/photo_%s.png"%stamp)

func interact() -> void:
	if not captured or story_ui.is_modal() or menu_active():return
	if daily_life.interact():return
	if story.deliver():return
	if story.try_salon_pickup():return
	if story.deliver_salon():return
	if story_ui.try_talk():return
	if home_visits.inside() or home_visits.busy:
		home_visits.interact()
	elif shop_visits.inside() or shop_visits.busy or shop_visits.nearby_shop()>=0:
		shop_visits.interact()
	else:
		home_visits.interact()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause) and not automated and not menu_active():set_capture(false)
	if what==NOTIFICATION_WM_CLOSE_REQUEST:_save_tut()

func _physics_process(delta:float) -> void:
	if is_instance_valid(story) and not tut_done and captured and not menu_active() and not (is_instance_valid(story_ui) and story_ui.is_modal()):
		tut_time+=delta
		if not overview and not shop_visits.inside() and not home_visits.inside():tut_walk+=player.velocity.length()*delta
		tut_toast_age+=delta
		tut_save+=delta
		if tut_save>5.0:
			tut_save=0.0
			_save_tut()
		if tut_toast_age>=40.0 or tut_walk>=120.0:
			tut_done=true
			_save_tut()
	var toast_shown:bool=not tut_done and captured and not menu_active() and not overview and not (is_instance_valid(story_ui) and story_ui.is_modal())
	if toast_shown:tut_fade=minf(1.0,tut_fade+delta*3.0)
	else:tut_fade=maxf(0.0,tut_fade-delta*2.5)
	tut_panel.modulate.a=tut_fade
	tut_panel.visible=tut_fade>0.01
	# The HUD line is rebuilt only when one of its parts actually changes.
	var hud_text:="Кешкі аудан · 18:40"
	if shop_visits.inside():
		if shop_visits.current_shop==4:hud_text="«ANA BEAUTY» САЛОНДАРЫ"
		else:hud_text="%s  /  АЗЫҚ-ТҮЛІК"%shop_visits.rooms[shop_visits.current_shop].title
	if home_visits.inside():
		hud_text="%s"%home_visits.rooms[home_visits.current_home].title
	if home_visits.inside() and home_visits.current_door==story.home_index():hud_text="МЕНІҢ ПӘТЕРІМ\n"+hud_text
	if is_instance_valid(story):hud_text=hud_text.replace("Кешкі аудан · 18:40","Кешкі аудан · "+story.clock_text())
	var stamina_line:bool=is_instance_valid(daily_life) and is_instance_valid(story) and story.stamina<99.5 and captured and not menu_active() and not overview and not (is_instance_valid(story_ui) and story_ui.is_modal()) and not daily_life.busy
	if stamina_line:hud_text+="\nКүш-қуат: %d%%"%roundi(story.stamina)
	if hud_text!=hud_cache:hud_cache=hud_text;hud.text=hud_text
	if menu_active() or not captured or overview or shop_visits.busy or home_visits.busy or (is_instance_valid(story_ui) and story_ui.is_modal()):return
	if daily_life.busy or daily_life.seated:player.velocity=Vector3.ZERO;return
	var input:=Input.get_vector("left","right","forward","back")
	var direction:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
	var speed:float=story.movement_speed(delta,input.length_squared()>.01,Input.is_action_pressed("run"))
	player.velocity.x=move_toward(player.velocity.x,direction.x*speed,30*delta)
	player.velocity.z=move_toward(player.velocity.z,direction.z*speed,30*delta)
	if not player.is_on_floor():player.velocity.y-=18*delta
	elif Input.is_action_just_pressed("jump"):player.velocity.y=5.5
	player.move_and_slide()
	if player.position.y < (-205 if home_visits.inside() else (-105 if shop_visits.inside() else -5)):reset()
	_player_shadow()

func _player_shadow() -> void:
	# The soft shadow under the feet follows the daylight: strong by day,
	# faint at night when the street lamps take over.
	if is_instance_valid(blob_material) and is_instance_valid(story) and not shop_visits.inside() and not home_visits.inside():
		var hour:float=minf(23.99,9.0+story.elapsed*9.0/600.0)
		var daylight:float=1.0-smoothstep(15.0,18.0,hour)
		blob_material.albedo_color=Color(0,0,0,lerpf(.34,.14,1.0-daylight))

func _sync_player_name() -> void:
	if is_instance_valid(player_name_label) and is_instance_valid(story):
		player_name_label.text=str(story.player_name)

func _salon_diag() -> void:
	automated=true
	while not is_instance_valid(town) or town.population.get("ready_for_walk")!=true:
		await get_tree().physics_frame
	var g:AStar2D=town.population.graph
	var pts:=g.get_point_count()
	var road_pts:=0
	for p in g.get_point_ids():
		var pos:Vector2=g.get_point_position(p)
		if town.population.on_road(Vector3(pos.x,0,pos.y)):road_pts+=1
	print("DIAG graph points=",pts," road_points=",road_pts," destinations=",town.population.destinations.size())
	# Reachability from the promenade to every zebra cell.
	var prom:int=town.population.nearest_point(Vector2(0,38))
	var worst:float=0.0
	for p in g.get_point_ids():
		var pos:Vector2=g.get_point_position(p)
		if not town.population.on_road(Vector3(pos.x,0,pos.y)):continue
		var path:=g.get_point_path(prom,p)
		if path.is_empty():
			print("DIAG UNREACHABLE zebra at ",pos)
		else:worst=maxf(worst,path.size())
	print("DIAG all zebras reachable, longest path cells=",worst)
	# Short simulation: per-citizen movement.
	var t0:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0<20000:
		town._physics_process(1.0/60.0)
		await get_tree().physics_frame
	var stuck:=0
	var empty_paths:=0
	for w in town.walkers:
		if w.travel<1.0:stuck+=1
		if w.path.is_empty() and w.waiting_signal:empty_paths+=1
	print("DIAG after 20s: stuck(<1m)=",stuck,"/32 | trips=",town.population.trips," crossings=",town.population.crossings)
	get_tree().quit()

func _salon_check() -> void:
	automated=true
	await get_tree().create_timer(1.0).timeout
	# Street side: the front door prompt must target the salon.
	var shop:Node3D=town.shops[4]
	player.global_position=shop.to_global(Vector3(3.2,.1,0))
	player.velocity=Vector3.ZERO
	var door:Vector3=shop.to_global(Vector3(1.55,1.25,0))
	yaw=atan2(-(door.x-player.global_position.x),-(door.z-player.global_position.z))
	camera.rotation=Vector3(0,yaw,0)
	await get_tree().physics_frame
	assert(shop_visits.nearby_shop()==4,"Salon front door not detected")
	shop_visits.interact()
	await get_tree().create_timer(2.0).timeout
	assert(shop_visits.inside() and shop_visits.current_shop==4,"Salon transition failed")
	var room:Node3D=shop_visits.rooms[4]
	# The floor must hold: the player stands on the wood, not in the void.
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y>-101.0,"Player fell through the salon floor: "+str(player.global_position.y))
	# Interior screenshot for the design review.
	await get_tree().process_frame
	if DisplayServer.get_name()=="headless":
		for i in 8:await get_tree().physics_frame
	else:
		await RenderingServer.frame_post_draw
	var shot:Image=null
	if DisplayServer.get_name()!="headless":shot=get_viewport().get_texture().get_image()
	if shot:shot.save_png(ProjectSettings.globalize_path("res://../previews/salon_interior.png"))
	print("SALON_INTERIOR_SHOT | user y=",player.global_position.y)
	assert(room.visible and is_instance_valid(room.cashier) and room.clients.size()==3,"Salon staff missing")
	# 1) The admin is selectable across the reception counter.
	shop_visits.place_player(room.to_global(Vector3(0.0,.08,3.4)),0.0)
	var admin_look:Vector3=room.cashier.global_position+Vector3(0,1.4,0)-player.global_position
	yaw=atan2(-admin_look.x,-admin_look.z)
	camera.rotation=Vector3(0,yaw,0)
	await get_tree().create_timer(0.4).timeout
	assert(story_ui.ray_target()=="cashier_4","Admin not ray-targeted: "+story_ui.ray_target())
	# 2) The hair-room door is closed and physically solid.
	var hair_q:=PhysicsRayQueryParameters3D.create(room.to_global(Vector3(0.0,1.4,-2.5)),room.to_global(Vector3(-4.5,1.4,-2.5)),1)
	assert(not get_world_3d().direct_space_state.intersect_ray(hair_q).is_empty(),"Hair room door does not block the opening")
	# 3) A manicure client arrives and sits at the table.
	var sitting:Dictionary={}
	var waited:=0.0
	while waited<70.0:
		await get_tree().create_timer(1.0).timeout
		waited+=1.0
		for c in room.clients:
			if c.state=="sitting":sitting=c
		if not sitting.is_empty():break
	assert(not sitting.is_empty(),"No manicure client arrived and sat")
	var client_id:String=str(sitting.id)
	# 4) The seated client is selectable from the stool side (look down from eye height).
	shop_visits.place_player(room.to_global(Vector3(2.4,.08,1.3)),PI)
	await get_tree().create_timer(0.5).timeout
	var cl_head:Vector3=sitting.node.global_position+Vector3(0,1.0,0)
	var cl_dir:Vector3=cl_head-camera.global_position
	yaw=atan2(-cl_dir.x,-cl_dir.z)
	pitch=clampf(atan2(cl_dir.y,sqrt(cl_dir.x*cl_dir.x+cl_dir.z*cl_dir.z)),-1.4,1.4)
	camera.rotation=Vector3(pitch,yaw,0)
	await get_tree().create_timer(0.2).timeout
	assert(story_ui.ray_target()==client_id,"Client not ray-targeted: "+story_ui.ray_target())
	# 5) Chat opens with the polish palette for the seated client.
	story_ui.open_chat(client_id)
	await get_tree().create_timer(0.3).timeout
	assert(story_ui.is_modal() and story_ui.mani_grid.visible and story_ui.mani_grid.get_child_count()==6,"Polish palette not shown in chat")
	# 6) Pick a colour: nails repainted, +400 paid, thanks, client leaves.
	var pick:Color=Color("c2426b")
	var before:int=story.money
	story_ui._pick_polish(pick)
	await get_tree().create_timer(0.3).timeout
	assert(story.money==before+400,"Manicure not paid (money="+str(story.money)+")")
	assert(room.last_polish.is_equal_approx(pick),"Nails not repainted with the chosen colour")
	assert(room.mani_client_state(client_id)=="leaving","Client did not leave after the manicure")
	assert(not story_ui.mani_grid.visible,"Polish palette stays open after the service")
	# 7) The client walks out.
	var left:=false
	waited=0.0
	while waited<40.0 and not left:
		await get_tree().create_timer(1.0).timeout
		waited+=1.0
		left=room.mani_client_state(client_id)=="away"
	assert(left,"Client never left the salon")
	# Close the chat — the delivery needs a free crosshair.
	story_ui.close_modal()
	# Salon delivery: item in hand, face the receptionist, hand it over.
	story.salon_phase=2;story.salon_item="Шампунь";story.salon_reward=900
	var before_delivery:int=story.money
	shop_visits.place_player(room.to_global(Vector3(0.0,.08,3.3)),0.0)
	var look:Vector3=room.cashier.global_position+Vector3(0,1.4,0)-player.global_position
	yaw=atan2(-look.x,-look.z)
	camera.rotation=Vector3(0,yaw,0)
	await get_tree().create_timer(0.4).timeout
	assert(story_ui.ray_target()=="cashier_4","Salon cashier not ray-targeted: "+story_ui.ray_target())
	assert(story.can_deliver_salon(),"Salon delivery rejected")
	story.deliver_salon()
	assert(story.money==before_delivery+900 and story.salon_phase<0,"Salon reward not paid")
	# Leave through the door back to the street.
	shop_visits.place_player(room.to_global(Vector3(0,.08,5.0)),PI)
	await get_tree().create_timer(0.4).timeout
	assert(shop_visits.at_exit(),"Salon exit not detected")
	shop_visits.interact()
	await get_tree().create_timer(2.0).timeout
	assert(not shop_visits.inside(),"Could not leave the salon")
	print("SALON_CHECK_PASS | reception ray | hair door blocked | manicure flow (chat→colour→nails→+400→thanks→leave) | delivery +900 | exit")
	get_tree().quit()

# Design-review captures of the styling zone (automated: no menu, game camera stays active).
func _salon_shot_views() -> void:
	automated=true
	await get_tree().create_timer(1.0).timeout
	var shop:Node3D=town.shops[4]
	player.global_position=shop.to_global(Vector3(3.2,.1,0))
	player.velocity=Vector3.ZERO
	var door:Vector3=shop.to_global(Vector3(1.55,1.25,0))
	yaw=atan2(-(door.x-player.global_position.x),-(door.z-player.global_position.z))
	camera.rotation=Vector3(0,yaw,0)
	await get_tree().physics_frame
	shop_visits.interact()
	await shop_visits.transition_finished
	var room:Node3D=shop_visits.rooms[4]
	# Make sure the game camera (not any menu/overview camera) is the active one.
	var mm2=main_menu
	if is_instance_valid(mm2) and is_instance_valid(mm2.camera):mm2.camera.current=false
	camera.make_current()
	print("SHOTV | inside=",shop_visits.inside(),"room_visible=",room.visible)
	# Let a manicure client arrive and sit so the station reads as in use.
	var seated:=false
	var waited:=0.0
	while waited<80.0 and not seated:
		await get_tree().create_timer(1.0).timeout
		waited+=1.0
		for c in room.clients:
			if c.state=="sitting":seated=true
	print("SHOTV | manicure client seated=",seated)
	var views:Array=[
		{"name":"reception","pos":Vector3(1.8,.05,4.7),"look":Vector3(-1.2,1.2,1.9)},
		{"name":"manicure","pos":Vector3(0.4,.05,1.9),"look":Vector3(2.4,0.95,-0.25)},
		{"name":"hairdoor","pos":Vector3(0.6,.05,-1.3),"look":Vector3(-1.7,1.6,-2.5)},
		{"name":"overview","pos":Vector3(-3.9,.05,4.8),"look":Vector3(2.2,0.9,-2.0)},
	]
	for v in views:
		var d:Vector3=room.to_global(v.look)-room.to_global(v.pos)
		yaw=atan2(-d.x,-d.z)
		pitch=-.03
		camera.rotation=Vector3(pitch,yaw,0)
		player.global_position=room.to_global(v.pos)
		print("SHOTV | ",v.name," player=",player.global_position,"cam=",camera.global_position)
		await get_tree().create_timer(1.5).timeout
		await get_tree().process_frame
		if DisplayServer.get_name()=="headless":
			for i in 8:await get_tree().physics_frame
		else:
			await RenderingServer.frame_post_draw
		var img:=get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://../previews/salon_shot_%s.png"%v.name))
		print("SALON_SHOT | ",v.name," ok")
	get_tree().quit()

func _check() -> void:
	await get_tree().create_timer(2).timeout
	set_physics_process(false)
	town.set_physics_process(false)
	var space:=get_world_3d().direct_space_state
	var floor_tests:=0
	for x in range(-53,54,3):
		for z in range(-69,70,3):
			var ray:=PhysicsRayQueryParameters3D.create(town.to_global(Vector3(x,.01,z)),town.to_global(Vector3(x,-2,z)),1)
			assert(not space.intersect_ray(ray).is_empty(),"Hole in continuous ground")
			floor_tests+=1
	for z in [-Layout.HALF_DEPTH,Layout.HALF_DEPTH]:
		assert(player.test_move(Transform3D(Basis.IDENTITY,town.to_global(Vector3(0,1,z-signf(z)*3))),town.global_basis*Vector3(0,0,signf(z)*6)),"Boundary can be crossed")
	assert(town.shops.size()==5,"Cartoon shops missing")
	for i in town.shops.size():
		for j in range(i+1,town.shops.size()):
			# DUKEN (1) and the fourth shop (3) are intentionally close on the west
			# frontage (28.5 m); all other pairs stay in separate parts of the district.
			var min_sep:float=25.0 if Vector2(i,j) in [Vector2(1,3)] else 45.0
			assert(town.shops[i].position.distance_to(town.shops[j].position)>min_sep,"Shops must occupy separate parts of the district")
	for i in town.shop_approaches.size():
		var approach:Vector3=town.shop_approaches[i]
		var nearest:int=town.population.graph.get_closest_point(Vector2(approach.x,approach.z))
		# The fourth shop sits 3.6 m west of the network edge, between two frontage
		# houses; its ~5.5 m approach corridor is walkable (verified), the rest must
		# sit on the network.
		var max_gap:float=6.0 if i==3 else 2.2
		assert(town.population.graph.get_point_position(nearest).distance_to(Vector2(approach.x,approach.z))<max_gap,"Shop entrance inaccessible")
		assert(nearest in town.population.destinations,"Shop not connected to pedestrian network")
	assert(town.buildings.size()>=80,"Dense frontages missing")
	assert(town.vehicles.size()==26 and town.walkers.size()==32,"Population count")
	assert(town.population.characters.size()==3,"Cartoon variety")
	assert(player.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Player size changed")
	assert(is_equal_approx(camera.position.y,1.65),"Human eye height changed")
	for w in town.walkers:
		assert(w.node.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Citizen size changed")
	for car in town.vehicles:
		assert(car.node.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Vehicle size changed")
	for parked in town.parked_vehicles:
		assert(parked.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Parked vehicle size changed")
	for shop in town.shops:
		assert(shop.global_basis.get_scale().is_equal_approx(Vector3.ONE*Layout.ENVIRONMENT_SCALE),"Shop scale missing")
	print("ENVIRONMENT_SCALE_CHECK_PASS | surroundings x",Layout.ENVIRONMENT_SCALE," | humans x1 | vehicles x1 | world district=",Layout.HALF_WIDTH*2*Layout.ENVIRONMENT_SCALE," x ",Layout.HALF_DEPTH*2*Layout.ENVIRONMENT_SCALE)
	var q:=PhysicsRayQueryParameters3D.create(Layout.human_position(SPAWN)+Vector3(0,1.65,0),town.to_global(Vector3(0,44,-98)),1)
	assert(space.intersect_ray(q).is_empty(),"Baiterek skyline blocked")
	# The spawn can now have a solid pedestrian in front of it. Exercise walking
	# on an actual clear stretch instead of expecting to walk through that NPC.
	var walk_query:=PhysicsShapeQueryParameters3D.new()
	var walk_shape:=CapsuleShape3D.new();walk_shape.radius=.32;walk_shape.height=1.75
	walk_query.shape=walk_shape;walk_query.collision_mask=1|4|8
	for z in [45.0,42.0,-40.0,35.0]:
		var point:=Layout.human_position(Vector3(0,.2,z))
		walk_query.transform.origin=point+Vector3.UP*.875;walk_query.motion=Vector3(0,0,-3)
		if space.intersect_shape(walk_query).is_empty() and space.cast_motion(walk_query)[0]>.99:
			player.position=point;break
	var start:Vector3=player.position
	Input.action_press("forward")
	for i in 30:
		_physics_process(1.0/60)
		await get_tree().physics_frame
	Input.action_release("forward")
	assert(player.position.distance_to(start)>.5,"Walking failed")
	player.position=Layout.human_position(Vector3(0,1,40))
	var worst_overlap:=0.0
	var simulation_seconds:=600.0 if "--long-check" in OS.get_cmdline_user_args() else 150.0
	var simulation_delta:=1.0/float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second",60))
	var frames:=int(simulation_seconds/simulation_delta)
	for frame in frames:
		town._physics_process(simulation_delta)
		if frame%20==0:
			for i in town.vehicles.size():
				for j in range(i+1,town.vehicles.size()):
					var a:Dictionary=town.vehicles[i]
					var b:Dictionary=town.vehicles[j]
					var d:Vector3=b.node.position-a.node.position
					if d.length()>7:continue
					var penetration:=100.0
					var ad:Vector3=-a.node.basis.z.normalized()
					var bd:Vector3=-b.node.basis.z.normalized()
					for axis in [ad,ad.cross(Vector3.UP),bd,bd.cross(Vector3.UP)]:
						var ra:float=absf(axis.dot(ad))*a.half+absf(axis.dot(ad.cross(Vector3.UP)))*a.width
						var rb:float=absf(axis.dot(bd))*b.half+absf(axis.dot(bd.cross(Vector3.UP)))*b.width
						penetration=minf(penetration,ra+rb-absf(d.dot(axis)))
					if penetration>worst_overlap+.2:
						print("OVERLAP ",frame*simulation_delta," cars ",i,"/",j," routes ",a.route,"/",b.route," p ",a.node.position," / ",b.node.position," dir ",a.dir," / ",b.dir," depth ",penetration)
					worst_overlap=maxf(worst_overlap,penetration)
	var minimum_travel:=10000.0
	var minimum_walk:=10000.0
	for car in town.vehicles:minimum_travel=minf(minimum_travel,car.travel)
	for w in town.walkers:minimum_walk=minf(minimum_walk,w.travel)
	print("SIMULATION | min car travel=",minimum_travel," | min walk=",minimum_walk," | queue=",town.traffic.max_queue," | stops=",town.traffic.stopped_events," | signal cycles=",town.traffic.cycles," | trips=",town.population.trips," | crossings=",town.population.crossings," | overlap=",worst_overlap," | longest stop=",town.traffic.max_stop_time," | longest phase=",town.traffic.phase_max_time," | junction passages=",town.traffic.gate_passages)
	assert(minimum_travel>25,"Traffic permanently stuck")
	assert(town.traffic.max_stop_time<85,"A queue did not clear in bounded time")
	assert(town.traffic.phase_max_time<28,"Signal clearance stalled")
	assert(town.traffic.gate_passages>35,"Insufficient intersection throughput")
	assert(minimum_walk>4,"A citizen cannot leave their spawn")
	assert(town.traffic.cycles>=2 and town.traffic.max_queue>=4,"Signal queues do not work")
	assert(town.population.trips>=5 and town.population.crossings>=6,"No varied citizen journeys")
	assert(worst_overlap<.4,"Vehicle overlap at junction")
	print("MAP_CHECK_PASS | floor probes=",floor_tests," | closed boundary | visible landmark | simulation seconds=",frames*simulation_delta)
	get_tree().quit()

func _ui_check() -> void:
	automated=true
	await get_tree().create_timer(8).timeout
	main_menu.close_menu()
	await get_tree().create_timer(6).timeout
	await RenderingServer.frame_post_draw
	var img:=get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://ui_check.png"))
	print("UI_CHECK_PASS | saved user://ui_check.png | hud=[",hud.text,"]")
	get_tree().quit()

func _capture() -> void:
	await get_tree().create_timer(3).timeout
	set_physics_process(false)
	for pose in [
		["shops_north",Vector3(-14,1.75,-37),Vector3(-11.7,2,-44.5)],
		["shop_west",Vector3(-33.5,1.75,2.5),Vector3(-41.5,2,0)],
		["shops_south",Vector3(14,1.75,37.5),Vector3(11.7,2,44.5)],
		["repaired_house",Vector3(22,1.75,-3),Vector3(11.7,3,-12)],
		["street",Vector3(0,1.7,38),Vector3(0,17,-101)],
		["avenue",Vector3(-24,1.7,38),Vector3(-28,3,-38)],
		["overview",Vector3(79,87,111),Vector3(0,0,-13)],
		["crossing",Vector3(-20,1.75,14),Vector3(-27,2,-7)],
		["courtyard",Vector3(0,1.75,-21),Vector3(15,1.8,-20)],
		["signal",Vector3(-29,1.75,-15),Vector3(-32,2.65,-11)],
		["salon",Vector3(28.0,1.75,-26.0),Vector3(35.9,1.9,-29)]]:
		camera.global_position=town.to_global(pose[1]) if pose[0]=="overview" else Layout.human_position(pose[1])
		camera.look_at(town.to_global(pose[2]))
		var shop_view:int=["shops_north","shop_west","shops_south"].find(pose[0])
		if shop_view>=0:
			var shop:Node3D=town.shops[shop_view]
			camera.global_position=shop.to_global(Vector3(11,0,1.0))+Vector3(0,1.75,0)
			camera.look_at(shop.to_global(Vector3(0,1.8,0)))
		for w in town.walkers:
			w.node.detail_clock=0
			w.node.update_detail(camera,0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/new_quarter_"+pose[0]+".png"))
	print("MAP_CAPTURE_PASS | FPS=",Engine.get_frames_per_second())
	get_tree().quit()

func _benchmark() -> void:
	await get_tree().create_timer(5).timeout
	camera.global_position=Layout.human_position(Vector3(-22,1.75,38))
	camera.look_at(town.to_global(Vector3(-27,2,-30)))
	await get_tree().create_timer(3).timeout
	_bench_report("baseline")
	for pose in [[Vector3(0,1.75,38),Vector3(0,5,-30)],[Vector3(-24,1.75,38),Vector3(-27,2,-30)],[Vector3(-20,1.75,14),Vector3(-27,2,-7)]]:
		camera.global_position=Layout.human_position(pose[0])
		camera.look_at(town.to_global(pose[1]))
		await get_tree().create_timer(3).timeout
		_bench_report("street / courtyard")
	if "--diagnose" in OS.get_cmdline_user_args():
		town.paused=true
		for w in town.walkers:w.node.visible=false;w.node.animation.active=false
		await get_tree().create_timer(3).timeout
		_bench_report("no citizens")
		town.paused=false
		var sun:DirectionalLight3D=find_children("*","DirectionalLight3D",true,false)[0]
		sun.shadow_enabled=false
		await get_tree().create_timer(3).timeout
		_bench_report("no shadows")
		sun.shadow_enabled=true
		var world:WorldEnvironment=find_children("*","WorldEnvironment",true,false)[0]
		var material:Material=world.environment.sky.sky_material
		world.environment.sky.sky_material=ProceduralSkyMaterial.new()
		await get_tree().create_timer(3).timeout
		_bench_report("simple sky")
		world.environment.sky.sky_material=material
		for light in town.find_children("*","OmniLight3D",true,false):light.visible=false
		await get_tree().create_timer(3).timeout
		_bench_report("no point lights")
		get_viewport().msaa_3d=Viewport.MSAA_DISABLED
		get_window().content_scale_size=Vector2i(960,600)
		await get_tree().create_timer(3).timeout
		_bench_report("small viewport")
	get_tree().quit()

func _bench_report(label:String) -> void:
	var visible_citizens:=0
	for w in town.walkers:
		if w.node.visible:visible_citizens+=1
	print("PERFORMANCE ",label," | visible citizens=",visible_citizens," | FPS=",Engine.get_frames_per_second()," | process ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," | physics ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," | draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," | primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func _live_traffic_check() -> void:
	# Use actual engine physics frames and rendering, without manual simulation.
	await get_tree().create_timer(30).timeout
	var minimum_travel:=INF
	for car in town.vehicles:minimum_travel=minf(minimum_travel,car.travel)
	if minimum_travel<1:
		push_error("LIVE_TRAFFIC_CHECK_FAIL: a vehicle cannot accelerate")
	else:
		print("LIVE_TRAFFIC_CHECK_PASS | engine physics Hz=",Engine.physics_ticks_per_second," | minimum vehicle travel=",minimum_travel," | junction passages=",town.traffic.gate_passages)
	if DisplayServer.get_name()=="headless":
		get_tree().quit(1 if minimum_travel<1 else 0)
	else:
		automated=false
		set_capture(true)

func capture_location() -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(home_visits) or not is_instance_valid(shop_visits):return story.resume_location
	if home_visits.busy or shop_visits.busy:return story.resume_location
	var at:=player.global_position
	var place:={"kind":"street","position":[at.x,at.y,at.z],"yaw":yaw,"pitch":pitch}
	if home_visits.inside():
		place.kind="home";place.door_id=home_visits.doors[home_visits.current_door].id
	elif shop_visits.inside():place.kind="shop";place.shop=shop_visits.current_shop
	return place

func restore_saved_place() -> void:
	var place:Dictionary=story.resume_location.duplicate(true)
	if place.is_empty():return
	var kind:String=str(place.get("kind","street"))
	if kind=="home":
		var index:int=story.door_index(str(place.get("door_id","")))
		if index<0:return
		if not story.can_enter(index) and story.pending_payment<=0:return
		home_visits._transition(index,true);await home_visits.transition_finished
	elif kind=="shop":
		var index:int=int(place.get("shop",-1))
		if index<0 or index>=shop_visits.rooms.size():return
		shop_visits._transition(index);await shop_visits.transition_finished
	var values=place.get("position",[])
	if not values is Array or values.size()!=3:return
	var at:=Vector3(float(values[0]),float(values[1]),float(values[2]))
	if not at.is_finite():return
	var local:=town.to_local(at)
	var valid:=absf(local.x)<Layout.HALF_WIDTH and absf(local.z)<Layout.HALF_DEPTH and absf(at.y)<5
	if home_visits.inside():
		var room:Node3D=home_visits.rooms[home_visits.current_home];local=room.to_local(at)
		valid=absf(local.x)<room.size.x/2-.35 and absf(local.z)<room.size.y/2-.35 and local.y>=0 and local.y<2
	elif shop_visits.inside():
		local=shop_visits.rooms[shop_visits.current_shop].to_local(at)
		valid=absf(local.x)<4.6 and absf(local.z)<5.6 and local.y>=0 and local.y<2
	if valid:
		var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.75
		query.shape=shape;query.transform.origin=at+Vector3.UP*.875;query.collision_mask=1|4|8;query.exclude=[player.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():player.global_position=at
	yaw=float(place.get("yaw",0));pitch=clampf(float(place.get("pitch",0)),-1.4,1.4)
	camera.rotation=Vector3(pitch,yaw,0);player.velocity=Vector3.ZERO

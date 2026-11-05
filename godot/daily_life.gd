extends CanvasLayer
# Home actions use the first physical surface under the reticle, never a radius through walls.
const UI=preload("res://ui_theme.gd")
var game:Node3D
var busy:=false
var seated:=false
var prompt:Label
var notice:Label
var stamina_bar:ProgressBar
var stamina_caption:Label
var fade:ColorRect
var day_label:Label
var notice_time:=0.0
var action_progress:ProgressBar
var seat_tween:Tween
var lighting_tick:=0.0
var shift_was_open:=true
var weather:="clear" # clear | rain | fog — rolled once per day
var weather_day:=0
var rain_particles:Node3D
var we_node:WorldEnvironment

func _ready() -> void:
	game=get_parent();layer=45
	var root:=Control.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=UI.make(false)
	prompt=Label.new();root.add_child(prompt);prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-480;prompt.offset_right=480;prompt.offset_top=-135;prompt.offset_bottom=-92
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt.add_theme_font_size_override("font_size",21)
	prompt.add_theme_constant_override("outline_size",7);prompt.add_theme_color_override("font_outline_color",Color("132c3b"))
	notice=Label.new();root.add_child(notice);notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left=-450;notice.offset_right=450;notice.offset_top=180;notice.offset_bottom=260
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",18)
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;notice.add_theme_constant_override("outline_size",7)
	notice.add_theme_color_override("font_outline_color",Color("132c3b"))
	stamina_bar=ProgressBar.new();root.add_child(stamina_bar);stamina_bar.position=Vector2(24,250);stamina_bar.size=Vector2(210,12);stamina_bar.show_percentage=false
	stamina_caption=Label.new();root.add_child(stamina_caption);stamina_caption.position=Vector2(244,238);stamina_caption.add_theme_constant_override("outline_size",6);stamina_caption.add_theme_color_override("font_outline_color",Color("132c3b"))
	stamina_bar.add_theme_stylebox_override("fill",UI.panel(UI.TEAL,0,6));stamina_bar.tooltip_text="Күш-қуат"
	action_progress=ProgressBar.new();root.add_child(action_progress);action_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_progress.offset_left=-150;action_progress.offset_right=150;action_progress.offset_top=-88;action_progress.offset_bottom=-76;action_progress.show_percentage=false;action_progress.hide()
	fade=ColorRect.new();root.add_child(fade);fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.color=Color(0,0,0,0);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	day_label=Label.new();fade.add_child(day_label);day_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);day_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;day_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size",38);day_label.modulate.a=0
	for room in game.shop_visits.rooms:
		if not is_instance_valid(room.checkout):continue
		var sign:=Label3D.new();room.add_child(sign);sign.text="КЕШКІ АС · 200 ₸
Кассаға қарап E бас";sign.font_size=30;sign.pixel_size=.0025
		sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.outline_size=6;sign.modulate=Color("fff0c9")
		var bounds:AABB=room.checkout.mesh.get_aabb()
		sign.global_position=room.checkout.to_global(Vector3(bounds.get_center().x,bounds.end.y,bounds.get_center().z))+Vector3.UP*.28
	call_deferred("_weather_boot")

# The WorldEnvironment exists only after the parent finishes its own _ready.
func _weather_boot() -> void:
	for n in game.find_children("*","WorldEnvironment",true,false):we_node=n;break
	_build_rain()
	new_day_weather()

# One deterministic weather roll per day: 42% rain, 28% fog, 30% clear.
func new_day_weather() -> void:
	var day:int=game.story.day()
	if day==weather_day and rain_particles!=null:return
	weather_day=day
	var rng:=RandomNumberGenerator.new();rng.seed=day*104729+7
	var pick:float=rng.randf()
	weather="rain" if pick<.42 else ("fog" if pick<.7 else "clear")
	_apply_weather()

func weather_text() -> String:
	match weather:
		"rain":return "Бүгін жаңбыр — жолдар жылы."
		"fog":return "Таңертең тұман."
	return "Ауа райы таза."

func _build_rain() -> void:
	if rain_particles!=null:return
	var rain:=GPUParticles3D.new();rain.name="Rain"
	rain.amount=2600
	rain.lifetime=.75
	var pm:=ParticleProcessMaterial.new()
	pm.direction=Vector3(0,-1,0)
	pm.spread=3
	pm.initial_velocity_min=12;pm.initial_velocity_max=16
	pm.gravity=Vector3(0,0,0)
	pm.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents=Vector3(66,1.5,86)
	rain.process_material=pm
	var quad:=QuadMesh.new()
	quad.size=Vector2(.085,.085)
	var pmat:=StandardMaterial3D.new()
	pmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.cull_mode=BaseMaterial3D.CULL_DISABLED
	pmat.albedo_color=Color(.75,.85,.95,.4)
	quad.material=pmat
	rain.draw_pass_1=quad
	rain.visible=false
	game.town.add_child(rain)
	rain.global_position=game.town.to_global(Vector3(0,13,0))
	rain_particles=rain

func _apply_weather() -> void:
	if rain_particles!=null:rain_particles.visible=(weather=="rain")
	var wet:bool=weather=="rain"
	# Wet roads: darken the shared road/pavement materials and make them glossy.
	for c in ["343d44","8a8c82","626b6b"]:
		var mat=game.town.surface_materials.get(c)
		if mat==null:continue
		if wet:
			if not mat.has_meta("dry_albedo"):mat.set_meta("dry_albedo",mat.albedo_color)
			mat.albedo_color=Color(mat.get_meta("dry_albedo")).lerp(Color("454e56"),.5)
			mat.roughness=.45
		elif mat.has_meta("dry_albedo"):
			mat.albedo_color=Color(mat.get_meta("dry_albedo"));mat.roughness=1.0;mat.remove_meta("dry_albedo")
	if we_node!=null:
		var fog_density:float=.0018
		var sky_affect:float=.06
		if weather=="fog":fog_density=.02;sky_affect=.5
		elif weather=="rain":fog_density=.005
		we_node.environment.fog_density=fog_density
		we_node.environment.fog_sky_affect=sky_affect
	if is_instance_valid(game.town.population):game.town.population.walk_speed_factor=1.35 if wet else 1.0
	if is_instance_valid(game.soundscape):game.soundscape.set_rain(wet)

func own_home() -> bool:
	return game.home_visits.inside() and game.home_visits.current_door==game.story.home_index()

func target() -> Dictionary:
	if game.overview or game.home_visits.busy or game.shop_visits.busy:return {}
	if not own_home() and not game.shop_visits.inside():return {}
	var from:Vector3=game.camera.global_position
	var ray:=PhysicsRayQueryParameters3D.create(from,from-game.camera.global_basis.z*4.5,1|4|8)
	ray.exclude=[game.player.get_rid()]
	var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():return {}
	var node:Node=hit.collider
	while node!=null and node!=game:
		if game.shop_visits.inside():
			if node==game.shop_visits.rooms[game.shop_visits.current_shop].checkout:return {"action":"buy","node":node}
		elif own_home():
			var name_text:=str(node.name)
			var action:=""
			if name_text in ["ToiletBase","ToiletSeat","Cistern"]:action="toilet"
			elif name_text in ["Vanity","Basin"]:action="wash"
			elif name_text.begins_with("DiningTable") or name_text.begins_with("CoffeeTable"):action="eat"
			elif name_text=="Sofa":action="sit"
			elif name_text in ["DoubleBed","SingleBed"]:action="sleep"
			if not action.is_empty():return {"action":action,"node":node}
		node=node.get_parent()
	return {}

func _process(delta:float) -> void:
	lighting_tick-=delta
	if lighting_tick<=0:lighting_tick=1;update_daylight()
	_tea_check()
	if shift_was_open and not game.story.work_open():say("18:00 · Ауысым аяқталды. Қолыңдағы тапсырысты аяқтап, үйге қайт.")
	shift_was_open=game.story.work_open()
	var visible_game:bool=not game.menu_active() and game.captured and not game.story_ui.is_modal()
	stamina_bar.visible=false
	stamina_caption.visible=false
	notice_time=maxf(0,notice_time-delta);notice.visible=visible_game and notice_time>0
	if busy:return
	prompt.text="";prompt.visible=visible_game
	if not visible_game:return
	if seated:prompt.text="E · Диваннан тұру";game.story.stamina=minf(100,game.story.stamina+delta*15);return
	var item:=target()
	if item.is_empty():return
	match item.action:
		"buy":prompt.text="E · Кешкі ас сатып алу — 200 ₸  |  Қорда: %d"%game.story.meals
		"toilet":prompt.text="E · Дәретханаға бару"
		"wash":prompt.text="E · Қолды жуу"
		"eat":prompt.text="E · Үстелде тамақтану  |  Қорда: %d"%game.story.meals
		"sit":prompt.text="E · Диванға отыру"
		"sleep":prompt.text="E · Ұйықтау — таңғы 09:00-ге дейін"

func say(words:String) -> void:
	notice.text=words;notice_time=5
# A neighbour you helped three times brings an evening tea to your flat.
func _tea_check() -> void:
	if not own_home() or game.story.tea_served_day==game.story.day():return
	if game.story.tea_ready_name().is_empty():return
	game.story.stamina=minf(100,game.story.stamina+25)
	var name:="";var nm:="";var best:=-1
	for door_id in game.story.neighbor_favors:
		var d:int=game.story.door_index(str(door_id))
		if d>=0 and int(game.story.neighbor_favors[door_id])>best:best=int(game.story.neighbor_favors[door_id]);nm=game.story.resident_name(d)
	game.story.serve_tea()
	name=nm
	_tea_cup()
	say("Сосед %s шай әкелді! Шай ішіп демал · күш +25."%name)
func _tea_cup() -> void:
	var room:Node3D=game.home_visits.rooms[game.home_visits.current_home]
	var group_node:Node3D=null
	for n in room.find_children("DiningTable*","Node3D",true,false):group_node=n;break
	var top:float=.81
	if group_node==null:
		for n in room.find_children("CoffeeTable*","Node3D",true,false):group_node=n;break
		top=.48
	if group_node==null:return
	var cup:=MeshInstance3D.new();cup.name="NeighborTea"
	var body:=CylinderMesh.new();body.top_radius=.075;body.bottom_radius=.05;body.height=.12
	cup.mesh=body
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("f7f1e3");mat.roughness=.7
	cup.material_override=mat
	room.add_child(cup);cup.global_position=group_node.global_position+Vector3(.42,top+.06,.1)
	var tea:=MeshInstance3D.new();tea.name="TeaSurface"
	var disc:=CylinderMesh.new();disc.top_radius=.065;disc.bottom_radius=.065;disc.height=.02
	tea.mesh=disc
	var tmat:=StandardMaterial3D.new();tmat.albedo_color=Color("8a5a2b");tmat.roughness=.35
	tea.material_override=tmat
	room.add_child(tea);tea.global_position=cup.global_position+Vector3(0,.045,0)

func interact() -> bool:
	if busy:return true
	if seated:stand();return true
	var item:=target()
	if item.is_empty():return false
	match item.action:
		"buy":
			if game.story.buy_meal():say("Кешкі асың сөмкеде. Үйдегі үстелде же." if game.story.food_credit==0 else "Кешкі ас қарызға берілді. 200 ₸ келесі еңбекақыдан ұсталады.")
			else:say("Ақша жеткіліксіз немесе азық қоры толы.")
		"toilet":perform("toilet",item.node)
		"wash":perform("wash",item.node)
		"eat":
			if game.story.meals<=0:say("Алдымен дүкен кассасынан кешкі ас сатып ал · 200 ₸.")
			elif not game.story.hands_clean:say("Тамақтанар алдында қолыңды жу.")
			else:perform("eat",item.node)
		"sit":sit(item.node)
		"sleep":
			if game.story.sleep_ready():sleep_night()
			elif game.story.work_open():say("Қазір жұмыс уақыты. Ұйқы — 18:00-ден кейін.")
			elif not game.story.delivery_id.is_empty():say("Алдымен қолыңдағы тапсырысты жеткіз.")
			else:say(game.story.evening_objective())
	return true

func perform(action:String,node:Node3D) -> void:
	busy=true;game.player.velocity=Vector3.ZERO
	var prop:Node3D
	var duration:=3.0
	match action:
		"toilet":prompt.text="Дәретхана…";duration=2.5
		"wash":
			prompt.text="Қолыңды жуып жатырсың…"
			prop=MeshInstance3D.new();var stream:=CylinderMesh.new();stream.top_radius=.018;stream.bottom_radius=.035;stream.height=.23
			prop.mesh=stream;var water:=StandardMaterial3D.new();water.albedo_color=Color("8ccfdf");prop.material_override=water
			game.home_visits.rooms[game.home_visits.current_home].get_node("Bathroom").add_child(prop);prop.position=Vector3(.65,1.025,-.74)
		"eat":
			prompt.text="Кешкі ас…";duration=4
			var room:Node3D=game.home_visits.rooms[game.home_visits.current_home]
			var h:=.81 if str(node.name).begins_with("Dining") else .48
			prop=room.art_prop(node,"grocery_14",Vector3(0,h,.1),Vector3(.34,.25,.3))
	action_progress.value=0;action_progress.show()
	var tween:=create_tween();tween.tween_property(action_progress,"value",100.0,duration);await tween.finished
	if is_instance_valid(prop):prop.queue_free()
	match action:
		"toilet":game.story.toilet_done=true;game.story.hands_clean=false;say("Енді қолыңды жу.")
		"wash":game.story.hands_clean=true;say("Қолың таза.")
		"eat":game.story.meals-=1;game.story.dinner_done=true;game.story.stamina=100;say("Ас болсын! Енді демалуға болады.")
	action_progress.hide();busy=false;game.story.save();game.story.changed.emit()

func sit(sofa:Node3D) -> void:
	seated=true;game.player.velocity=Vector3.ZERO
	var forward:Vector3=sofa.global_basis.z
	var cushion_x:float=-.49 if sofa.to_local(game.player.global_position).x<0 else .49
	game.yaw=atan2(-forward.x,-forward.z);game.pitch=0;game.camera.rotation=Vector3(0,game.yaw,0)
	seat_tween=create_tween();seat_tween.tween_property(game.camera,"global_position",sofa.to_global(Vector3(cushion_x,1.25,.12)),.35)
	say("Демалып отырсың · E — тұру")

func stand() -> void:
	if seat_tween and seat_tween.is_valid():seat_tween.kill()
	seated=false;game.camera.position=Vector3(0,1.65,0);game.player.velocity=Vector3.ZERO

func sleep_night() -> void:
	busy=true;prompt.text="";game.player.velocity=Vector3.ZERO
	var tween:=create_tween();tween.tween_property(fade,"color:a",1.0,1.3);await tween.finished
	game.story.next_morning()
	new_day_weather()
	game.camera.position=Vector3(0,1.65,0);game.pitch=0;game.camera.rotation.x=0
	update_daylight()
	day_label.text="%d-КҮН\n09:00 · Қайырлы таң!"%game.story.day()
	tween=create_tween();tween.tween_property(day_label,"modulate:a",1.0,.45);tween.tween_interval(1.5);tween.tween_property(day_label,"modulate:a",0.0,.4);await tween.finished
	tween=create_tween();tween.tween_property(fade,"color:a",0.0,1.2);await tween.finished
	busy=false;game.story.save();say("Жаңа күн басталды. Ауысым: 09:00–18:00 · "+weather_text())

func update_daylight() -> void:
	var hour:float=minf(23.99,9+game.story.elapsed*9/600)
	var daylight:float=1.0-smoothstep(15,18,hour)
	var night:float=smoothstep(18,22,hour)
	game.sky_material.set_shader_parameter("daylight",daylight)
	game.sky_material.set_shader_parameter("night",night)
	game.outdoor_sun.rotation_degrees.x=-lerpf(40,12,clampf((hour-9)/9,0,1))
	game.outdoor_sun.light_color=Color("ffd1a2").lerp(Color("fff3df"),daylight)
	if not game.home_visits.inside() and not game.shop_visits.inside():game.outdoor_sun.light_energy=lerpf(1.0,.12,night)
	# Street lamps stay off by day and warm the district at night. A lamp
	# that emits nothing is hidden from the forward light list as well.
	var lamp_energy:float=lerpf(0.0,2.6,night)
	for l in game.town.lamp_lights:
		l.light_energy=lamp_energy
		l.omni_range=10.0
		l.visible=lamp_energy>0.01

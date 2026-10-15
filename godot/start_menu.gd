extends CanvasLayer
const UI=preload("res://ui_theme.gd")
var game:Node3D
var active:=false
var moving:=true
var elapsed:=0.0
var camera:Camera3D
var screen:Control
var play:Button
var help:PanelContainer
var motion:Button
var pause_root:Control
var save_status:Label
var save_button:Button
var started:=false
var opening:=false
var save_path:="user://story_v1.json"
func _ready() -> void:
	game=get_parent();layer=60
	camera=Camera3D.new();game.add_child(camera);camera.fov=62;camera.far=800
	screen=Control.new();add_child(screen);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.theme=UI.make(false)
	var shade:=ColorRect.new();screen.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){ COLOR=vec4(0.025,0.065,0.10,mix(0.94,0.08,smoothstep(0.18,0.9,UV.x))); }"
	var mat:=ShaderMaterial.new();mat.shader=shader;shade.material=mat;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var box:=VBoxContainer.new();screen.add_child(box);box.position=Vector2(72,110);box.size=Vector2(450,680);box.add_theme_constant_override("separation",18)
	label(box,"АСТАНА  /  ҚАЗАҚША СӨЙЛЕ",16,UI.GOLD)
	var title:=label(box,"QADAM",66,Color.WHITE);title.add_theme_font_override("font",load("res://assets/fonts/NotoSerifDisplay-SemiBold.ttf"))
	label(box,"Кешкі аудан",30,Color("b8d9d5"))
	var description:=label(box,"Жаңа қала. Жаңа таныстар.\nӨз дүкеніңе апарар жол — әңгімеден басталады.",19,Color("d2dfdf"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var space:=Control.new();space.custom_minimum_size.y=16;box.add_child(space)
	play=button(box,"Ойынды бастау",close_menu);UI.primary(play)
	button(box,"Басқару",func():help.visible=not help.visible)
	motion=button(box,"Қала көрінісін тоқтату",func():moving=not moving;motion.text="Қала көрінісін жалғастыру" if not moving else "Қала көрінісін тоқтату")
	button(box,"Ойыннан шығу",func():game.story.save();get_tree().quit())
	help=PanelContainer.new();screen.add_child(help);help.position=Vector2(590,300);help.size=Vector2(650,350);help.add_theme_stylebox_override("panel",UI.panel(Color("173844"),26))
	var help_box:=VBoxContainer.new();help.add_child(help_box);help_box.add_theme_constant_override("separation",14)
	label(help_box,"Басқару",27,UI.GOLD)
	label(help_box,"WASD — жүру   ·   Тінтуір — қарау\nShift — жүгіру (күш-қуат шектеулі)  ·  Space — секіру\nE — есік / тапсырыс / үйдегі әрекеттер\nСол жақ батырма — адаммен сөйлесу\nF — телефон   ·   Esc — үзіліс",19,Color.WHITE)
	label(help_box,"Дыбыс деңгейі",16,Color("d2dfdf"))
	var volume:=HSlider.new();volume.min_value=0;volume.max_value=100;volume.value=game.soundscape.volumes.Master*100;volume.custom_minimum_size.y=30;help_box.add_child(volume)
	volume.value_changed.connect(func(value:float):game.soundscape.volumes.Master=value/100;game.soundscape._apply_volumes();game.soundscape._save())
	button(help_box,"Түсінікті",func():help.hide())
	var footer:=label(screen,"Қазақша үйрен. Ауданмен таныс.",17,Color("d3e5e1"));footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);footer.position=Vector2(72,-55)
	screen.hide();help.hide();_build_pause()
func label(parent:Node,words:String,sz:int,color:Color) -> Label:
	var node:=Label.new();node.text=words;node.add_theme_font_size_override("font_size",sz);node.add_theme_color_override("font_color",color);parent.add_child(node);return node
func button(parent:Node,words:String,action:Callable) -> Button:
	var node:=Button.new();node.text=words;node.custom_minimum_size.y=52;node.alignment=HORIZONTAL_ALIGNMENT_LEFT;parent.add_child(node);node.pressed.connect(action);return node
func open_menu() -> void:
	if started:game.story.save()
	active=true;screen.show();help.hide();pause_root.hide()
	play.text="Ойынды жалғастыру" if game.story.loaded or started else "Ойынды бастау"
	game.set_capture(false);game.pause.hide();game.hud.get_parent().hide();game.story_ui.get_child(0).hide()
	game.town.visible=true;game.town.paused=false;game.town.process_mode=Node.PROCESS_MODE_INHERIT
	game.outdoor_sun.visible=true;game.outdoor_sun.light_energy=1.0
	game.town.player=null;camera.current=true;_camera_position();play.grab_focus()
func close_menu() -> void:
	if not active or opening:return
	opening=true;play.disabled=true
	if not started:
		while not game.town.population.ready_for_walk:await get_tree().physics_frame
		await game.restore_saved_place()
	started=true;game.session_started=true;opening=false;play.disabled=false
	active=false;screen.hide();camera.current=false;game.camera.make_current();game.hud.get_parent().show();game.story_ui.get_child(0).show()
	game.town.player=null if game.home_visits.inside() or game.shop_visits.inside() else game.player;game.set_capture(true)
func _camera_position() -> void:
	var angle:=elapsed*.035
	camera.position=game.town.to_global(Vector3(sin(angle)*19,23+sin(angle*.7)*3,cos(angle)*35))
	camera.look_at(game.town.to_global(Vector3(0,4,-12)))
func _process(delta:float) -> void:
	pause_root.visible=not active and not game.captured and not game.story_ui.is_modal()
	if pause_root.visible:game.pause.hide()
	if not active:return
	if moving:elapsed+=minf(delta,.1)
	_camera_position()
func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if active:
			if event.physical_keycode==KEY_ESCAPE:help.hide();get_viewport().set_input_as_handled()
		elif pause_root.visible and event.physical_keycode==KEY_S:
			save_current();get_viewport().set_input_as_handled()

func _build_pause() -> void:
	pause_root=Control.new();add_child(pause_root);pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pause_root.theme=UI.make(true)
	var shade:=ColorRect.new();pause_root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.02,.05,.08,.5);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel:=PanelContainer.new();pause_root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-240;panel.offset_right=240;panel.offset_top=-240;panel.offset_bottom=240;panel.add_theme_stylebox_override("panel",UI.panel(UI.PAPER,28,20))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);panel.add_child(box)
	label(box,"Үзіліс",34,UI.INK)
	label(box,"Ойынды осы жерден жалғастыр",16,UI.MUTED)
	var resume:=button(box,"Жалғастыру · Esc",func():game.set_capture(true));UI.primary(resume)
	save_button=button(box,"Ойынды сақтау · S",save_current)
	button(box,"Басты мәзір",open_menu)
	button(box,"Сақтап шығу",func():
		if save_current():get_tree().quit())
	save_status=label(box,"",16,UI.TEAL);save_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.soundscape.panel.reparent(pause_root);game.soundscape.panel.theme=UI.make(false)
	pause_root.hide()
func save_current() -> bool:
	if active or game.captured or game.story_ui.is_modal() or game.home_visits.busy or game.shop_visits.busy or game.daily_life.busy:return false
	var success:bool=game.story.write_progress(save_path)
	save_status.text="Сақталды · %s · %d-күн"%[game.story.clock_text(),game.story.day()] if success else "Сақтау мүмкін болмады. Қайта басып көр."
	return success

extends Node3D

@export_enum("nathan","erlan","asel","dana","aruzhan","miras") var character_id="nathan"
@export_enum("idle","walk") var initial_motion="idle"
@export var outfit_variant=0
var animation: AnimationPlayer
var model: Node3D
@export var natural_motion:=true
var walk_reference_speed:=1.1
var model_id="man"
var render_meshes:Array[GeometryInstance3D]=[]
var detail_clock:=0.0
var animation_elapsed:=0.0
var camera_distance:=0.0
var last_camera_position:=Vector3(999,999,999)
var last_camera_forward:=Vector3.ZERO
const NAMES={"nathan":"Натан","erlan":"Ерлан","asel":"Әсел","dana":"Дана","aruzhan":"Аружан","miras":"Мирас"}
const MODELS={"nathan":"man","erlan":"man","asel":"girl","dana":"girl","aruzhan":"girl","miras":"boy"}
const PALETTE=[Color("f3ca75"),Color("7abbb8"),Color("dd8ea3"),Color("96addc"),Color("b5ba86"),Color("e5a779"),Color("bc9ed2"),Color("e7ddd1")]
const CLOTH={"man":["lambert3SG"],"girl":["lambert7"],"boy":["lambert20"]}

func _ready():
	model_id=MODELS.get(character_id,"man")
	var asset_name:String=model_id+"_natural" if natural_motion and model_id in ["man","girl"] else model_id
	model=load("res://assets/characters/%s.glb"%asset_name).instantiate()
	if natural_motion and model_id in ["man","girl"]:
		var reports=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/natural_motion.json"))
		for report in reports:
			if report.character==model_id:walk_reference_speed=report.speed_m_s
	add_child(model)
	var first=true;var bounds=AABB()
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if "skate" in str(mesh.name).to_lower():mesh.visible=false;continue
		render_meshes.append(mesh)
		mesh.lod_bias=.65
		var b=(global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		if first:bounds=b;first=false
		else:bounds=bounds.merge(b)
		for i in range(mesh.mesh.get_surface_count()):
			var material=mesh.get_active_material(i)
			if material is StandardMaterial3D and str(material.resource_name) in CLOTH[model_id]:
				var copy=material.duplicate()
				copy.albedo_color=PALETTE[posmod(outfit_variant,PALETTE.size())]
				copy.roughness=0.85
				copy.metallic=0.0
				copy.metallic_specular=0.25
				mesh.set_surface_override_material(i,copy)
				mesh.set_meta("outfit_tinted",true)
	var factor=1.78/(bounds.position.y+bounds.size.y)
	model.scale=Vector3.ONE*factor
	if natural_motion and model_id in ["man","girl"]:walk_reference_speed*=factor
	model.position.y=0
	model.rotation.y=PI
	var players=model.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animation=players[0]
		animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["walk","idle"]:
			if animation.has_animation(clip):animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		play_motion(initial_motion)
	set_meta("model_id",model_id);set_meta("outfit_variant",outfit_variant)

func _process(delta:float) -> void:
	if not animation or not animation.active or not is_visible_in_tree():return
	animation_elapsed+=delta
	# Close characters retain full frame-rate motion; remote rigs need fewer poses.
	var interval:=1.0/15.0 if camera_distance>35 else (1.0/30.0 if camera_distance>15 else 0.0)
	if animation_elapsed>=interval:
		animation.advance(minf(animation_elapsed,.2));animation_elapsed=0.0

func play_motion(motion: String,speed=1.0):
	if not animation or not animation.has_animation(motion):return
	if animation.current_animation!=motion:animation.play(motion,0.22)
	animation.speed_scale=speed

func update_detail(camera:Camera3D,delta:float) -> void:
	detail_clock-=delta
	var forward:Vector3=-camera.global_basis.z
	var camera_changed:bool=camera.global_position.distance_squared_to(last_camera_position)>.6 or forward.dot(last_camera_forward)<.97
	if detail_clock>0 and not camera_changed:return
	detail_clock=.25
	last_camera_position=camera.global_position
	last_camera_forward=forward
	var offset:Vector3=global_position-camera.global_position
	var distance:=offset.length()
	camera_distance=distance
	visible=distance<85 and (distance<8 or offset.normalized().dot(forward)>.05)
	# The source rigs are detailed. Do not skin people hidden behind solid facades.
	# Their simulation and journeys continue independently of visual visibility.
	if visible and distance>8:
		var space:=get_world_3d().direct_space_state
		var chest:=PhysicsRayQueryParameters3D.create(camera.global_position,global_position+Vector3(0,.95,0),1)
		if not space.intersect_ray(chest).is_empty():
			var head:=PhysicsRayQueryParameters3D.create(camera.global_position,global_position+Vector3(0,1.7,0),1)
			visible=space.intersect_ray(head).is_empty()
	if animation:animation.active=visible
	for mesh in render_meshes:
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visible and distance<22 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

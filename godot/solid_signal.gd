extends Node3D
# Kenney's authored housings, visors and pole; indicators live on their lens faces.
const ROOT="res://assets/signals/kenney/"
var main_material:ShaderMaterial
var pedestrian_material:ShaderMaterial
var turn_material:ShaderMaterial

func _model(file:String,at:Vector3,size:float,facing:Vector3,auxiliary:bool=false,turn:bool=false)->ShaderMaterial:
	var model:Node3D=load(ROOT+file).instantiate()
	add_child(model);model.position=at;model.scale=Vector3.ONE*size
	# The original model's front is -X.
	model.rotation.y=atan2(facing.z,-facing.x)
	var material:=ShaderMaterial.new();material.shader=preload("res://solid_signal.gdshader")
	material.set_shader_parameter("auxiliary",auxiliary)
	material.set_shader_parameter("upper_symbol",load("res://assets/signals/left_arrow.svg" if turn else "res://assets/signals/standing.svg"))
	material.set_shader_parameter("lower_symbol",load("res://assets/signals/left_arrow.svg" if turn else "res://assets/signals/walking.svg"))
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		material.set_shader_parameter("source_atlas",mesh.get_active_material(0).albedo_texture)
		mesh.material_override=material
	return material

func configure(facing:Vector3,pedestrian_facing:Vector3=Vector3.ZERO,has_turn:bool=false)->void:
	main_material=_model("traffic-light.glb",Vector3.ZERO,7.0,facing)
	if pedestrian_facing!=Vector3.ZERO:
		pedestrian_material=_model("traffic-light-two.glb",Vector3(0,1.75,0)+pedestrian_facing*.12,5.5,pedestrian_facing,true)
	if has_turn:
		var turn_at:=Basis(Vector3.UP,atan2(facing.z,-facing.x))*Vector3(-.0125,.415,-.060)*7.0
		turn_material=_model("traffic-light-two.glb",turn_at,7.0,facing,true,true)
	var body:=StaticBody3D.new();body.collision_layer=1;add_child(body)
	var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new()
	shape.radius=.22;shape.height=3.6;collider.shape=shape;collider.position.y=1.8;body.add_child(collider)
	set_main(0);set_pedestrian(false);set_turn(false)

func set_main(state:int)->void:main_material.set_shader_parameter("signal_state",state)
func set_pedestrian(go:bool)->void:
	if pedestrian_material:pedestrian_material.set_shader_parameter("signal_state",2 if go else 0)
func set_turn(go:bool)->void:
	if turn_material:turn_material.set_shader_parameter("signal_state",2 if go else 0)

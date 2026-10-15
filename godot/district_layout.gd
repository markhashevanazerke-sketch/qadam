extends RefCounted
# Shared dimensions keep the rendered road, traffic paths, walking area and checks aligned.
# Buildings, greenery and streets grow together; people and vehicles keep their size.
# Navigation coordinates are local; human height and walking speed use world metres.
const ENVIRONMENT_SCALE:=1.3
const HALF_WIDTH:=54.0
const HALF_DEPTH:=70.0
const ROAD_END:=54.0
const SHOP_SITES:=[
	["BEREKE",Vector3(-36.8,.035,-46.5),0.0],
	["DÜKEN",Vector3(-36.8,.035,0),0.0],
	["KÖRŞI",Vector3(35.9,.035,44.73),PI]]

static func human_position(point:Vector3) -> Vector3:
	return Vector3(point.x*ENVIRONMENT_SCALE,point.y,point.z*ENVIRONMENT_SCALE)

extends Node3D
# Crop + upscale key zones of map_top3.png for visual inspection.
# Image 810x506; world->px: px=(wx/228.11+0.5)*810, py=(wz+31.81)/142.5*506

const IMG_PATH := "C:/Users/Леново/map_top3.png"


func _ready() -> void:
	var img := Image.load_from_file(IMG_PATH)
	if img == null:
		get_tree().quit(1)
		return
	var zones := [
		["lot", -10.0, -24.0, 24.0, 4.0],
		["play", -35.0, 24.0, -9.0, 38.0],
		["south", 6.0, 60.0, 28.0, 84.0],
		["mid", -12.0, 34.0, 24.0, 48.0],
	]
	for z in zones:
		var name: String = z[0]
		var x0: float = (float(z[1]) / 228.11 + 0.5) * 810.0
		var y0: float = (float(z[2]) + 31.81) / 142.5 * 506.0
		var x1: float = (float(z[3]) / 228.11 + 0.5) * 810.0
		var y1: float = (float(z[4]) + 31.81) / 142.5 * 506.0
		var r := Rect2i(int(x0), int(y0), int(x1 - x0), int(y1 - y0))
		var crop := Image.create_empty(r.size.x, r.size.y, false, img.get_format())
		for yy in r.size.y:
			for xx in r.size.x:
				crop.set_pixel(xx, yy, img.get_pixel(r.position.x + xx, r.position.y + yy))
		crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
		crop.save_png("C:/Users/Леново/crop_%s.png" % name)
		print("CROP %s %d x %d at %s" % [name, crop.get_width(), crop.get_height(), str(r)])
	get_tree().quit(0)

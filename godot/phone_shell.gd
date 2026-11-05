extends Control
func _draw() -> void:
	var frame:=StyleBoxFlat.new();frame.bg_color=Color("e5d9c5");frame.border_color=Color("ad997b")
	frame.set_border_width_all(2);frame.set_corner_radius_all(42)
	draw_style_box(frame,Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(17,76,size.x-34,size.y-154),Color("f2f6f5"))
	draw_line(Vector2(size.x/2-25,42),Vector2(size.x/2+25,42),Color("444a51"),5,true)
	draw_circle(Vector2(size.x/2-46,42),5,Color("263946"))
	draw_circle(Vector2(size.x/2,size.y-39),23,Color("ac9370"))
	draw_circle(Vector2(size.x/2,size.y-39),20,Color("eee6da"))

extends RefCounted
const INK=Color("173844")
const MUTED=Color("526d78")
const PAPER=Color("f2f6f5")
const TEAL=Color("146b70")
const GOLD=Color("efc785")
const NIGHT=Color("132c3b")
static func panel(color:Color,padding:int=16,radius:int=12) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color;box.set_corner_radius_all(radius)
	box.content_margin_left=padding;box.content_margin_right=padding;box.content_margin_top=padding;box.content_margin_bottom=padding
	return box
static func make(light:bool=true) -> Theme:
	var t:=Theme.new();t.default_font=load("res://assets/fonts/NotoSans-Regular.ttf");t.default_font_size=18
	var ink:=INK if light else Color("eef5f3")
	for kind in ["Label","RichTextLabel","LineEdit","CheckButton"]:t.set_color("font_color",kind,ink)
	t.set_color("default_color","RichTextLabel",ink)
	t.set_font("bold_font","RichTextLabel",load("res://assets/fonts/NotoSans-SemiBold.ttf"))
	t.set_font("font","Button",load("res://assets/fonts/NotoSans-SemiBold.ttf"))
	for state in ["normal","hover","pressed","disabled"]:
		var color:Color={"normal":Color("e1eeeb"),"hover":Color("c5e2dc"),"pressed":Color("a9d2c9"),"disabled":Color("e2e7e6")}[state] if light else {"normal":Color("294b5b"),"hover":Color("386477"),"pressed":Color("477b8e"),"disabled":Color("283d47")}[state]
		t.set_stylebox(state,"Button",panel(color,12,10))
		t.set_color("font_"+state+"_color","Button",Color("677e84") if state=="disabled" else ink)
	t.set_color("font_color","Button",ink)
	var focus:=panel(Color(0,0,0,0),0,10);focus.border_color=Color("d49c45");focus.set_border_width_all(3);t.set_stylebox("focus","Button",focus)
	var field:=panel(Color.WHITE if light else Color("203f4c"),14,10);field.border_color=Color("a4bdb9");field.set_border_width_all(1)
	t.set_stylebox("normal","LineEdit",field);t.set_stylebox("focus","LineEdit",focus)
	t.set_color("font_placeholder_color","LineEdit",MUTED);t.set_color("caret_color","LineEdit",TEAL);t.set_color("selection_color","LineEdit",Color("b2d9d3"))
	t.set_stylebox("normal","RichTextLabel",panel(Color.WHITE if light else NIGHT,18,10))
	t.set_stylebox("scroll","VScrollBar",panel(Color("d9e5e2"),3,4));t.set_stylebox("grabber","VScrollBar",panel(Color("7a9c98"),3,4))
	t.set_stylebox("grabber_highlight","VScrollBar",panel(TEAL,3,4));t.set_stylebox("grabber_pressed","VScrollBar",panel(TEAL,3,4))
	return t
static func primary(button:Button) -> void:
	for state in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,panel({"normal":TEAL,"hover":Color("21868a"),"pressed":Color("105459")}[state],14,10))
		button.add_theme_color_override("font_"+state+"_color",Color.WHITE)
	button.add_theme_color_override("font_color",Color.WHITE)

extends Node3D
# Parse hmap.txt -> ASCII level map + column profiles for key x values.

const HMAP := "C:/Users/Леново/hmap.txt"


func _ready() -> void:
	if not FileAccess.file_exists(HMAP):
		get_tree().quit(1)
		return
	var lines := FileAccess.get_file_as_string(HMAP).strip_edges().split("\n", false)
	var grid := []
	for i in range(1, lines.size()):
		var parts: Array = lines[i].strip_edges().split(" ", false)
		grid.append(parts)
	# ASCII level map (55 cols x x, 71 rows z)
	var out := ["     " + _col_header()]
	for j in grid.size():
		var row := "z%3d " % j
		for i in grid[j].size():
			var v := float(grid[j][i])
			var ch := "."
			if v < 0:
				ch = "."
			elif v < 12:
				ch = "0"
			elif v < 15:
				ch = "1"
			elif v < 20:
				ch = "2"
			elif v < 23:
				ch = "3"
			elif v < 25.2:
				ch = "4"
			elif v < 26.6:
				ch = "5"
			elif v < 30:
				ch = "6"
			elif v < 34:
				ch = "7"
			elif v < 40:
				ch = "8"
			elif v < 46:
				ch = "9"
			else:
				ch = "#"
			row += ch
		out.append(row)
	# column profiles at key x (col index = (x+54.32)/2)
	for xw in [-1.0, 7.0, 16.0, -10.0, 22.0]:
		var ci := int(round((xw + 54.32) / 2.0))
		if ci < 0 or ci >= grid[0].size():
			continue
		var prof := ""
		for j in grid.size():
			var v := float(grid[j][ci])
			var ch := "."
			if v < 0:
				ch = "."
			elif v < 12:
				ch = "0"
			elif v < 15:
				ch = "1"
			elif v < 20:
				ch = "2"
			elif v < 23:
				ch = "3"
			elif v < 25.2:
				ch = "4"
			elif v < 26.6:
				ch = "5"
			elif v < 30:
				ch = "6"
			elif v < 34:
				ch = "7"
			elif v < 40:
				ch = "8"
			elif v < 46:
				ch = "9"
			else:
				ch = "#"
			prof += ch
		var vals := ""
		for j in range(0, grid.size(), 4):
			var v := float(grid[j][ci])
			vals += "%4.0f" % v
		print("COL x=%.1f\n  %s\n  %s" % [xw, prof, vals])
	var f := FileAccess.open("C:/Users/Леново/hmap_ascii.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print("HMAP_ASCII_DONE")
	get_tree().quit(0)


func _col_header() -> String:
	var s := ""
	for i in 55:
		var x := -54.32 + i * 2.0
		if int(x) % 10 == 0:
			s += str(abs(int(x)))
		else:
			s += " "
	return s

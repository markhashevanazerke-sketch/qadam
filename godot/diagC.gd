extends Node3D
# Read map_top3.png, find bright saturated blobs (vehicles / playground equipment),
# print their world bounding boxes. Image: 810x1064 window capture;
# world x span = 142.5 * w/h (camera centered x=0), z: top=-31.81 bottom=+110.69.

const IMG_PATH := "C:/Users/Леново/map_top3.png"


func _ready() -> void:
	var img := Image.load_from_file(IMG_PATH)
	if img == null:
		push_error("cannot load " + IMG_PATH)
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	var span_x: float = 142.5 * float(w) / float(h)
	print("IMAGE %dx%d span_x=%.2f" % [w, h, span_x])
	# candidate mask: saturated bright colors (vehicles, signs, equipment)
	var mask := PackedByteArray()
	mask.resize(w * h)
	var count := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var r := int(c.r * 255.0)
			var g := int(c.g * 255.0)
			var b := int(c.b * 255.0)
			var v := 0
			if r > 205 and g > 205 and b > 195:
				v = 1  # white
			elif r > 190 and g > 150 and b < 130 and (r - b) > 80:
				v = 2  # yellow
			elif r > 150 and g < 110 and b < 110 and (r - g) > 60:
				v = 3  # red
			elif b > 160 and r < 130 and g < 150 and not (r > 30 and r < 60 and g > 70 and g < 110 and b > 140 and b < 190):
				v = 4  # blue (exclude sky 41,89,168)
			elif r < 110 and g < 110 and b < 110 and (r + g + b) > 90:
				v = 5  # dark vehicle body
			mask[y * w + x] = v
			if v > 0:
				count += 1
	print("candidates=%d" % count)
	# connected components (4-neighbor), same class
	var parent := PackedInt32Array()
	parent.resize(w * h)
	for i in w * h:
		parent[i] = i
	var find_root := func(idx: int) -> int:
		while parent[idx] != idx:
			parent[idx] = parent[parent[idx]]
			idx = parent[idx]
		return idx
	for y in h:
		for x in w:
			var idx := y * w + x
			var v: int = mask[idx]
			if v == 0:
				continue
			if x > 0 and mask[idx - 1] == v:
				var ra: int = find_root.call(idx - 1)
				var rb: int = find_root.call(idx)
				if ra != rb:
					parent[rb] = ra
			if y > 0 and mask[idx - w] == v:
				var ra2: int = find_root.call(idx - w)
				var rb2: int = find_root.call(idx)
				if ra2 != rb2:
					parent[rb2] = ra2
	# collect blobs
	var blobs := {}
	for y in h:
		for x in w:
			var idx := y * w + x
			var v: int = mask[idx]
			if v == 0:
				continue
			var r0: int = find_root.call(idx)
			if not blobs.has(r0):
				blobs[r0] = {"minx": x, "miny": y, "maxx": x, "maxy": y, "area": 0, "class": v}
			blobs[r0]["area"] = int(blobs[r0]["area"]) + 1
			blobs[r0]["minx"] = mini(blobs[r0]["minx"], x)
			blobs[r0]["miny"] = mini(blobs[r0]["miny"], y)
			blobs[r0]["maxx"] = maxi(blobs[r0]["maxx"], x)
			blobs[r0]["maxy"] = maxi(blobs[r0]["maxy"], y)
	var results := []
	for b in blobs.values():
		var area: int = b["area"]
		if area < 60 or area > 6000:
			continue
		var bw: float = float(b["maxx"] - b["minx"] + 1)
		var bh: float = float(b["maxy"] - b["miny"] + 1)
		# vehicle-ish aspect: blob spans 0.5m..6m
		if bw < 4.0 or bw > 60.0 or bh < 4.0 or bh > 60.0:
			continue
		var cx := (float(b["minx"]) + float(b["maxx"])) / 2.0
		var cy := (float(b["miny"]) + float(b["maxy"])) / 2.0
		var wx := (cx / float(w) - 0.5) * span_x
		var wz := (cy / float(h) - 0.5) * 142.5 + 39.44
		var names := {1: "white", 2: "yellow", 3: "red", 4: "blue", 5: "dark"}
		results.append({"wx": wx, "wz": wz, "sx": bw * span_x / float(w), "sz": bh * 142.5 / float(h), "area": area, "class": names[b["class"]], "minx": b["minx"], "miny": b["miny"], "maxx": b["maxx"], "maxy": b["maxy"]})
	results.sort_custom(func(a, b2): return float(a["miny"]) < float(b2["miny"]))
	print("BLOBS (world coords):")
	for r in results:
		print("  %-6s center=(%6.2f, %6.2f) size=(%4.1f x %4.1f) area=%d px=(%d..%d,%d..%d)" % [
			r["class"], r["wx"], r["wz"], r["sx"], r["sz"], r["area"], r["minx"], r["maxx"], r["miny"], r["maxy"]])
	get_tree().quit(0)

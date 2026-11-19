extends Node3D
class_name GrayboxBuilder
## 按俯视图：四面房子围院，院内树/钟/锅/井，东屋是地道出口。
## 再往东是没有门的实墙，墙外树洞是瞭望口。可走地道地面在 -3.8 米。

# 院子黄土与地道夯土同族，避免地表塑料灰、洞内另一套色
const GROUND := Color(0.48, 0.38, 0.27)
const HOUSE := Color(0.46, 0.40, 0.34)
const ROOF := Color(0.33, 0.33, 0.31)
const WALLC := Color(0.48, 0.44, 0.38)
const TUNNEL := Color(0.40, 0.32, 0.23)
const TUNNEL_CEIL := Color(0.26, 0.20, 0.15)
const WOOD := Color(0.36, 0.24, 0.13)

const FLOOR_TOP := 0.0
const TUNNEL_FLOOR := -3.8
const TUNNEL_H := 1.6

const LOOKOUT := Vector3(22.0, 0, 0)
const EXIT_HOLE := Vector3(2.6, 0, 0.15)
const WELL := Vector3(-10.0, 0, -3.6)
const STOVE := Vector3(-13.2, 0, 2.4)
const TROUGH := Vector3(-4.2, 0, -4.2)
const NORTH_HOLE := Vector3(-6.2, 0, 7.2)

func build() -> void:
	_build_ground()
	_build_plain_edge()
	_build_houses()
	_build_courtyard_props()
	_build_outer_wall_and_lookout()
	_build_tunnels()
	_build_lighting()
	_build_grass()
	_build_pebbles()
	PropDress.apply(self)
	StructureDress.apply(self)

var _materials := {}
var _rough := preload("res://assets/shaders/rough_surface.gdshader")

func _mat(c: Color) -> ShaderMaterial:
	var kind := _surface_kind(c)
	var key := "%s|%s" % [c.to_html(), kind]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _rough
	m.set_shader_parameter("base_color", c)
	var pit := 0.016
	var grain := 2.4
	if kind == "earth":
		pit = 0.028
		grain = 1.45
		m.set_shader_parameter("soil", 1.0)
		m.set_shader_parameter("damp", 0.22)
	elif kind == "tile":
		pit = 0.006
		grain = 6.0
	elif kind == "wood":
		pit = 0.005
		grain = 5.0
	elif kind == "soil":
		pit = 0.011
		grain = 1.85
		m.set_shader_parameter("soil", 1.0)
		m.set_shader_parameter("damp", 0.55)
	if c.is_equal_approx(TUNNEL_CEIL):
		pit = 0.008
		grain = 1.55
		m.set_shader_parameter("base_color", Color(0.24, 0.19, 0.14))
		m.set_shader_parameter("damp", 0.72)
		m.set_shader_parameter("soil", 1.0)
	m.set_shader_parameter("pit", pit)
	m.set_shader_parameter("grain", grain)
	if kind == "earth" or kind == "soil" or c.is_equal_approx(TUNNEL_CEIL):
		var tex := _surface_tex(kind, c)
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("use_tex", 1.0)
	elif kind == "wood":
		var wood_tex := _file_tex("res://assets/textures/ran_zhuang/plank_wood.png", "res://assets/props/plank_0.png")
		if wood_tex:
			m.set_shader_parameter("albedo_tex", wood_tex)
			m.set_shader_parameter("use_tex", 1.0)
	elif kind == "mottle" and (c.is_equal_approx(HOUSE) or c.is_equal_approx(WALLC)):
		var wall_tex := _file_tex("res://assets/textures/ran_zhuang/adobe_wall.png", "res://assets/props/wall_span_0.png")
		if wall_tex:
			m.set_shader_parameter("albedo_tex", wall_tex)
			m.set_shader_parameter("use_tex", 0.85)
	_materials[key] = m
	return m

func _surface_tex(kind: String, c: Color) -> Texture2D:
	if kind == "earth" or c.is_equal_approx(GROUND):
		var yard := _file_tex("res://assets/textures/ran_zhuang/yard_earth.png", "res://assets/props/tunnel_bay_0.png")
		if yard:
			return yard
	if c.is_equal_approx(TUNNEL_CEIL):
		var ceil_tex := _file_tex("res://assets/textures/ran_zhuang/tunnel_ceil.png", "res://assets/props/tunnel_bay_1.png")
		if ceil_tex:
			return ceil_tex
	var wall := _file_tex("res://assets/textures/ran_zhuang/tunnel_wall.png", "res://assets/props/tunnel_bay_0.png")
	if wall:
		return wall
	return _swatch(c, kind if kind != "mottle" else "soil")

func _file_tex(preferred: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(preferred):
		return load(preferred) as Texture2D
	if ResourceLoader.exists(fallback):
		return load(fallback) as Texture2D
	return null

func _surface_kind(c: Color) -> String:
	if c.is_equal_approx(ROOF):
		return "tile"
	if c.is_equal_approx(WOOD):
		return "wood"
	if c.is_equal_approx(TUNNEL):
		return "soil"
	if c.is_equal_approx(GROUND):
		return "earth"
	return "mottle"

func _swatch(c: Color, kind: String) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c.to_html() + kind)
	for y in 48:
		for x in 48:
			var n := rng.randf_range(-0.045, 0.045)
			var px := Color(clampf(c.r + n, 0.0, 1.0), clampf(c.g + n, 0.0, 1.0), clampf(c.b + n, 0.0, 1.0))
			if kind == "tile" and y % 6 == 0:
				px = px.darkened(0.22)
			elif kind == "wood" and x % 5 == 0:
				px = px.darkened(0.16)
			elif kind == "soil" and (x * 3 + y) % 7 == 0:
				px = px.darkened(0.14)
			elif kind == "earth" and (x + y * 2) % 9 == 0:
				px = px.lightened(0.08)
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)

func _door_leaf(pos: Vector3, yaw: float, inward: float = 1.0) -> void:
	var along_x := absf(yaw) < 45.0
	var tag := "%d_%d" % [int(pos.x * 10.0), int(pos.z * 10.0)]
	if along_x:
		_add_box(Vector3(pos.x, 0.045, pos.z), Vector3(1.28, 0.09, 0.2), WOOD, "Sill" + tag)
		_add_box(Vector3(pos.x - 0.58, 1.12, pos.z), Vector3(0.1, 2.16, 0.16), WOOD, "JambA" + tag)
		_add_box(Vector3(pos.x + 0.58, 1.12, pos.z), Vector3(0.1, 2.16, 0.16), WOOD, "JambB" + tag)
		_add_box(Vector3(pos.x, 2.18, pos.z), Vector3(1.28, 0.1, 0.18), WOOD, "Lintel" + tag)
	else:
		_add_box(Vector3(pos.x, 0.045, pos.z), Vector3(0.2, 0.09, 1.28), WOOD, "Sill" + tag)
		_add_box(Vector3(pos.x, 1.12, pos.z - 0.58), Vector3(0.16, 2.16, 0.1), WOOD, "JambA" + tag)
		_add_box(Vector3(pos.x, 1.12, pos.z + 0.58), Vector3(0.16, 2.16, 0.1), WOOD, "JambB" + tag)
		_add_box(Vector3(pos.x, 2.18, pos.z), Vector3(0.18, 0.1, 1.28), WOOD, "Lintel" + tag)
	# 门扇敞着，靠在门洞一侧的内墙上。门洞本身是空的，扇面有碰撞，不能穿过去。
	var side := 1.0 if inward >= 0.0 else -1.0
	if along_x:
		_add_box(Vector3(pos.x - 1.16, pos.y - 0.06, pos.z + 0.2 * side), Vector3(0.84, 1.9, 0.06), WOOD, "OpenLeaf" + tag)
	else:
		_add_box(Vector3(pos.x + 0.2 * side, pos.y - 0.06, pos.z - 1.16), Vector3(0.06, 1.9, 0.84), WOOD, "OpenLeaf" + tag)

func _add_box(pos: Vector3, size: Vector3, color: Color, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var dug := _is_dug(color)
	var longest := maxf(size.x, maxf(size.y, size.z))
	var thinnest := minf(size.x, minf(size.y, size.z))
	# 薄墙/枪眼/门框/转角不挖凿，避免程序碎块；只给厚土体做拱形起伏
	var skip_carve := (
		"Slit" in node_name or "Plug" in node_name or "Frame" in node_name
		or "Corner" in node_name or "Jamb" in node_name or "Post" in node_name
		or "Seal" in node_name or "Flip" in node_name or "Bridge" in node_name
	)
	var allow_carve := dug and longest >= 1.25 and thinnest >= 0.48 and not skip_carve
	if allow_carve:
		box.subdivide_width = 8 if size.x >= size.z else 5
		box.subdivide_height = 4
		box.subdivide_depth = 8 if size.z > size.x else 5
		mesh.mesh = _carve(box)
	elif node_name.begins_with("G_"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(size.x, size.z)
		plane.subdivide_width = 10
		plane.subdivide_depth = 10
		mesh.mesh = plane
		mesh.position.y = size.y * 0.5
	elif not dug and size.length() > 0.9:
		box.subdivide_width = 3
		box.subdivide_height = 2
		box.subdivide_depth = 3
		mesh.mesh = box
	else:
		mesh.mesh = box
	mesh.material_override = _mat(color)
	if "Top" in node_name or node_name.ends_with("Crown"):
		var wind_mat := _mat(color).duplicate() as ShaderMaterial
		wind_mat.set_shader_parameter("wind", 0.1)
		mesh.material_override = wind_mat
	body.set_meta("dress_kind", _surface_kind(color))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body

func _is_dug(c: Color) -> bool:
	return c.is_equal_approx(TUNNEL) or c.is_equal_approx(TUNNEL_CEIL)

func _carve(box: BoxMesh) -> Mesh:
	var arrays: Array = box.get_mesh_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := MeshDataTool.new()
	if tool.create_from_surface(mesh, 0) != OK:
		return box
	var half := box.size * 0.5
	var across_x := half.x <= half.z
	for i in tool.get_vertex_count():
		var v := tool.get_vertex(i)
		var n := tool.get_vertex_normal(i)
		var nx := v.x / maxf(half.x, 0.001)
		var ny := v.y / maxf(half.y, 0.001)
		var nz := v.z / maxf(half.z, 0.001)
		var across := nx if across_x else nz
		var arch := across * across
		arch = arch * arch * (3.0 - 2.0 * arch)
		if n.y < -0.55:
			v.y -= arch * minf(0.28, half.y * 0.42)
		elif n.y > 0.55:
			v.y += arch * 0.012
		else:
			# 侧壁轻微内收成拱，避免碎块感
			var up := clampf((ny + 1.0) * 0.5, 0.0, 1.0)
			v += n * up * up * 0.035
		tool.set_vertex(i, v)
	tool.commit_to_surface(mesh)
	return mesh

func _hang_rope(a: Vector3, b: Vector3, make_entry: bool = false) -> void:
	var span := b - a
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = span.length()
	rope.mesh = cyl
	rope.material_override = _mat(Color(0.42, 0.32, 0.18))
	rope.position = (a + b) * 0.5
	if span.length_squared() > 0.0001:
		var y := span.normalized()
		var x := y.cross(Vector3.FORWARD)
		if x.length_squared() < 0.001:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		var z := x.cross(y).normalized()
		rope.basis = Basis(x, y, z)
	add_child(rope)
	if make_entry:
		_rope_descent_at(a, b)

func _rope_descent_at(top: Vector3, bottom: Vector3) -> void:
	var drop := Marker3D.new()
	drop.name = "RopeDrop_%d" % int(bottom.x * 10.0)
	drop.position = Vector3(bottom.x, TUNNEL_FLOOR + 0.15, bottom.z)
	add_child(drop)
	var area := Area3D.new()
	area.name = "RopeDescent_%d" % int(top.x * 10.0)
	area.position = top + Vector3(0, -0.35, 0)
	_hitbox(area, Vector3(1.1, 1.4, 1.1))
	var shape_host := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.2, 1.0)
	shape_host.shape = box
	area.add_child(shape_host)
	area.set_script(load("res://scripts/mechanics/rope_descent.gd"))
	area.monitoring = true
	area.collision_mask = 2
	add_child(area)
	area.set("drop_point_path", area.get_path_to(drop))
	_add_label(top + Vector3(0.35, 0.2, 0), "绳降 · 地道口", 18)

func _add_label(pos: Vector3, text: String, size: int = 40, color: Color = Color(1, 0.94, 0.78)) -> void:
	var shown := _purpose_label(text)
	if shown == "":
		return
	text = shown
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 8
	label.modulate = color
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _purpose_label(text: String) -> String:
	if "枪" in text:
		return "枪眼"
	if "地道口" in text or "炕板" in text or "井壁" in text or "槽底板" in text or "夹壁" in text:
		return "地道口"
	if "翻眼" in text or "暗室门" in text:
		return "翻眼"
	if "中间木轴" in text or ("翻板" in text and "中间" in text):
		return "走中"
	if "翻板" in text or "翻口" in text or "贴墙" in text:
		return "翻口"
	if "挡水" in text or "隔板" in text:
		return "关隔板"
	if "拉雷" in text:
		return "拉线"
	if "弹药" in text:
		return "弹药"
	if "卡口" in text:
		return "卡口"
	if "藏身" in text:
		return "藏身"
	if "水井" in text or "辘轳" in text:
		return "水井"
	if "警报" in text or "院树" in text:
		return "警钟"
	if "锅台" in text:
		return "锅台"
	if "驴槽" in text:
		return "驴槽"
	# 房名与陈设短标签保留，避免屋子看起来像空壳
	if "北房" in text or "南房" in text or "西房" in text or "东屋" in text:
		return text.substr(0, mini(4, text.length()))
	if "磨房" in text or "柴房" in text or "影壁" in text or "饭桌" in text or "西炕" in text or "东炕" in text:
		return text.substr(0, mini(3, text.length()))
	return ""

func _build_ground() -> void:
	# 地面铺满。地道口藏在树洞、水井、东屋、驴槽和北房。锅台是射击位，不在地上开可以掉进去的洞。
	for ix in range(-12, 35):
		for iz in range(-9, 10):
			var cx := ix * 2.0 + 1.0
			var cz := iz * 2.0
			_add_box(Vector3(cx, -0.02, cz), Vector3(2.08, 0.04, 2.08), GROUND, "G_%d_%d" % [ix, iz])

func _build_plain_edge() -> void:
	# 冀中平原：麦田、田埂、道边杨树。树列挡住空边界，人从树缝里走出来。
	var field := Color(0.48, 0.37, 0.24)
	var earth := Color(0.48, 0.38, 0.24)
	var trunk := Color(0.32, 0.26, 0.16)
	_add_box(Vector3(48.0, 0.03, 0.0), Vector3(36.0, 0.06, 34.0), field, "FieldEast")
	_add_box(Vector3(92.0, 0.02, 0.0), Vector3(52.0, 0.05, 48.0), field, "FieldFarEast")
	_add_box(Vector3(-6.0, 0.03, 15.2), Vector3(36.0, 0.06, 6.0), field, "FieldNorth")
	_add_box(Vector3(-6.0, 0.02, 24.0), Vector3(80.0, 0.05, 12.0), field, "FieldFarNorth")
	_add_box(Vector3(-6.0, 0.03, -15.2), Vector3(36.0, 0.06, 6.0), field, "FieldSouth")
	_add_box(Vector3(-6.0, 0.02, -24.0), Vector3(80.0, 0.05, 12.0), field, "FieldFarSouth")
	_add_box(Vector3(-20.5, 0.03, 0.0), Vector3(6.0, 0.06, 26.0), field, "FieldWest")
	_add_box(Vector3(-34.0, 0.02, 0.0), Vector3(18.0, 0.05, 40.0), field, "FieldFarWest")
	_add_box(Vector3(-28.0, 0.02, 12.0), Vector3(22.0, 0.05, 16.0), field, "FieldBarn")
	_add_box(Vector3(16.0, 0.02, 12.0), Vector3(18.0, 0.05, 14.0), field, "FieldStore")
	_add_box(Vector3(66.2, 0.22, 0.0), Vector3(0.8, 0.44, 36.0), earth, "RidgeEast")
	_add_box(Vector3(6.0, 0.2, 17.6), Vector3(70.0, 0.4, 0.55), earth, "RidgeNorth")
	_add_box(Vector3(6.0, 0.2, -17.6), Vector3(70.0, 0.4, 0.55), earth, "RidgeSouth")
	_add_box(Vector3(-22.4, 0.2, 0.0), Vector3(0.55, 0.4, 36.0), earth, "RidgeWest")
	var line_z := [-11.0, -9.0, -4.2, 3.4, 5.4, 9.6, 11.6]
	for z in line_z:
		_hide_mesh(_add_box(Vector3(30.0, 5.6, z), Vector3(0.42, 11.2, 0.42), trunk, "Poplar%d" % int(z * 10.0)))
		_hide_mesh(_add_box(Vector3(50.0, 4.2, z), Vector3(0.32, 8.4, 0.32), trunk, "FarPoplar%d" % int(z * 10.0)))
	for x in [-18.5, -16.2, -8.0, 4.0, 14.0]:
		_hide_mesh(_add_box(Vector3(x, 4.0, 14.6), Vector3(0.36, 8.0, 0.36), trunk, "NorthTree%d" % int(x * 10.0)))
		_hide_mesh(_add_box(Vector3(x, 4.0, -14.6), Vector3(0.36, 8.0, 0.36), trunk, "SouthTree%d" % int(x * 10.0)))
	for z in [-14.0, -6.0, 0.0, 7.0, 14.0]:
		_hide_mesh(_add_box(Vector3(78.0, 5.2, z), Vector3(0.38, 10.4, 0.38), trunk, "HorizonTree%d" % int(z * 10.0)))
	_plant_poplars()

func _house(pos: Vector3, size: Vector3, node_name: String) -> void:
	_add_box(Vector3(pos.x, 1.35, pos.z), Vector3(size.x, 2.7, size.z), HOUSE, node_name)
	_add_box(Vector3(pos.x, 2.85, pos.z), Vector3(size.x + 0.4, 0.28, size.z + 0.4), ROOF, node_name + "Roof")

func _shell(prefix: String, c: Vector3, fp: Vector2, door_side: String, doors: Array, gaps: Array = []) -> void:
	var t := 0.34
	var h := 2.7
	var y := 1.35
	var hx := fp.x * 0.5
	var hz := fp.y * 0.5
	var dw := 1.25
	_add_box(Vector3(c.x, 2.9, c.z), Vector3(fp.x + 0.45, 0.28, fp.y + 0.45), ROOF, prefix + "Roof")
	_wall_along_x(prefix + "N", c.x - hx, c.x + hx, c.z + hz - t * 0.5, y, h, t, _cuts("n", door_side, doors, dw, gaps))
	_wall_along_x(prefix + "S", c.x - hx, c.x + hx, c.z - hz + t * 0.5, y, h, t, _cuts("s", door_side, doors, dw, gaps))
	_wall_along_z(prefix + "W", c.z - hz, c.z + hz, c.x - hx + t * 0.5, y, h, t, _cuts("w", door_side, doors, dw, gaps))
	_wall_along_z(prefix + "E", c.z - hz, c.z + hz, c.x + hx - t * 0.5, y, h, t, _cuts("e", door_side, doors, dw, gaps))

func _cuts(side: String, door_side: String, doors: Array, dw: float, gaps: Array) -> Array:
	var cuts: Array = []
	if side == door_side:
		for door_at in doors:
			cuts.append([float(door_at) - dw * 0.5, float(door_at) + dw * 0.5])
	for gap in gaps:
		if str(gap[0]) == side:
			var at := float(gap[1])
			var w := float(gap[2])
			cuts.append([at - w * 0.5, at + w * 0.5])
	return cuts

func _wall_along_x(node_name: String, x0: float, x1: float, z: float, y: float, h: float, t: float, cuts: Array) -> void:
	for seg in _gap_segments(x0, x1, cuts):
		_add_box(Vector3((seg[0] + seg[1]) * 0.5, y, z), Vector3(seg[1] - seg[0], h, t), HOUSE, "%s%.0f" % [node_name, seg[0] * 10.0])

func _wall_along_z(node_name: String, z0: float, z1: float, x: float, y: float, h: float, t: float, cuts: Array) -> void:
	for seg in _gap_segments(z0, z1, cuts):
		_add_box(Vector3(x, y, (seg[0] + seg[1]) * 0.5), Vector3(t, h, seg[1] - seg[0]), HOUSE, "%s%.0f" % [node_name, seg[0] * 10.0])

func _gap_segments(a: float, b: float, cuts: Array) -> Array:
	cuts = cuts.duplicate()
	cuts.sort_custom(func(u, v): return u[0] < v[0])
	var out: Array = []
	var cursor := a
	for cut in cuts:
		if cut[0] > cursor + 0.05:
			out.append([cursor, cut[0]])
		cursor = maxf(cursor, cut[1])
	if b > cursor + 0.05:
		out.append([cursor, b])
	if out.is_empty():
		out.append([a, b])
	return out

func _build_houses() -> void:
	_shell("HouseNorth", Vector3(-6.2, 0, 7.65), Vector2(15.6, 4.5), "s", [-9.5, -2.4])
	_add_label(Vector3(-6.2, 3.3, 8.3), "北房", 36)
	_shell("HouseSouth", Vector3(-6.2, 0, -8.15), Vector2(15.6, 3.5), "n", [-6.2])
	_add_label(Vector3(-6.2, 3.3, -8.15), "南房", 36)
	# 锅台旁的墙缝，不占门洞。人站在灶后，朝院射击。
	_shell("HouseWest", Vector3(-14.15, 0, 0.2), Vector2(3.5, 11.2), "e", [-2.2, 2.6], [["e", 3.85, 0.9]])
	_slit_plug(Vector3(-12.57, 0.0, 3.85), Vector3(0.34, 2.7, 0.9), 1.34, 1.48, "StoveSlit")
	_gun_port("StovePort", Vector3(-13.05, 1.05, 3.85), Vector3.RIGHT)
	_add_label(Vector3(-13.2, 1.7, 3.85), "锅台枪眼", 22)
	_add_label(Vector3(-14.15, 3.3, 0.2), "西房", 36)
	# 门槛枪眼开在门北侧的墙里，门洞照常走人。
	_shell("HouseEast", Vector3(2.7, 0, 0.15), Vector2(4.4, 4.6), "w", [0.15], [["w", 1.2, 0.85]])
	_slit_plug(Vector3(0.67, 0.0, 1.2), Vector3(0.34, 2.7, 0.85), 1.34, 1.48, "DoorSlit")
	_gun_port("ThresholdPort", Vector3(1.16, 1.05, 1.2), Vector3.LEFT)
	_add_label(Vector3(1.35, 1.65, 1.2), "门槛枪眼", 22)
	_add_label(Vector3(3.4, 2.2, 0.9), "东屋内 · 出", 40, Color(1, 0.85, 0.45))
	_house(Vector3(-16.6, 0, 12.9), Vector3(5.6, 2.7, 3.3), "BackWood")
	_add_label(Vector3(-16.6, 3.2, 11.4), "柴房后墙", 22)
	_house(Vector3(6.4, 0, 13.0), Vector3(4.8, 2.7, 3.2), "BackNorthE")
	_add_label(Vector3(6.4, 3.2, 11.5), "邻院后墙", 22)
	_house(Vector3(-16.4, 0, -12.7), Vector3(5.4, 2.7, 3.1), "BackSouthW")
	_add_label(Vector3(-16.4, 3.2, -11.3), "邻院后墙", 22)
	_house(Vector3(6.6, 0, -12.6), Vector3(4.6, 2.7, 3.0), "BackSouthE")
	_add_label(Vector3(6.6, 3.2, -11.2), "仓房后墙", 22)
	_shell("HouseMill", Vector3(4.7, 0, 8.6), Vector2(4.0, 3.2), "s", [4.7])
	_add_label(Vector3(4.7, 3.2, 8.6), "磨房", 28)
	_shell("HouseWood", Vector3(5.9, 0, -5.9), Vector2(3.8, 3.4), "w", [-5.9])
	_add_label(Vector3(5.9, 3.2, -5.9), "柴房", 28)
	# 院外再扩一圈邻院：仓房、牲口棚、菜窖房，入口藏在粮囤和草垛下。
	_shell("HouseBarn", Vector3(-22.4, 0, 0.4), Vector2(5.2, 6.4), "e", [0.4])
	_shell("HouseCellar", Vector3(-6.2, 0, 14.8), Vector2(5.4, 3.4), "s", [-6.2])
	_shell("HouseStable", Vector3(12.6, 0, -8.4), Vector2(4.6, 4.0), "w", [-8.4])
	_shell("HouseStore", Vector3(12.8, 0, 8.8), Vector2(4.4, 3.6), "s", [12.8])
	_add_box(Vector3(-22.0, 0.55, -1.4), Vector3(1.1, 1.1, 1.1), Color(0.55, 0.42, 0.22), "BarnBinCover")
	_add_box(Vector3(-6.2, 0.42, 14.0), Vector3(1.6, 0.75, 1.2), Color(0.62, 0.5, 0.28), "CellarHay")
	_add_box(Vector3(13.4, 0.55, -7.5), Vector3(0.9, 1.0, 0.9), Color(0.48, 0.36, 0.2), "StableTroughCover")
	_add_box(Vector3(-20.6, 1.55, 2.2), Vector3(0.35, 0.7, 0.2), Color(0.55, 0.2, 0.12), "HangChiliA")
	_add_box(Vector3(-13.6, 2.35, -0.4), Vector3(0.45, 0.55, 0.18), Color(0.72, 0.55, 0.2), "HangCornA")
	_add_box(Vector3(1.4, 2.35, 2.0), Vector3(0.4, 0.5, 0.16), Color(0.7, 0.5, 0.18), "HangCornB")
	_add_box(Vector3(-8.2, 0.35, 5.2), Vector3(0.7, 0.12, 0.7), Color(0.45, 0.32, 0.18), "YardSieve")
	_add_box(Vector3(-9.4, 0.28, 4.6), Vector3(0.55, 0.4, 0.55), Color(0.55, 0.42, 0.22), "YardBasket")
	_build_room_furnishings()

func _build_courtyard_props() -> void:
	_add_box(Vector3(-6.4, 2.1, 1.55), Vector3(0.85, 4.2, 0.85), Color(0.32, 0.22, 0.12), "YardTrunk")
	_add_box(Vector3(-6.4, 6.2, 1.55), Vector3(2.6, 1.2, 2.6), Color(0.22, 0.4, 0.16), "YardCrown")
	_add_box(Vector3(-5.15, 2.45, 0.15), Vector3(0.42, 0.48, 0.42), Color(0.55, 0.42, 0.18), "Bell")
	_hang_rope(Vector3(-6.05, 5.8, 0.95), Vector3(-5.15, 2.94, 0.15))
	_add_label(Vector3(-4.35, 3.2, 0.15), "院树 · 警报钟", 46, Color(1, 0.9, 0.4))
	var bell := Area3D.new()
	bell.name = "AlarmBell"
	bell.position = Vector3(-5.15, 1.15, 0.15)
	_hitbox(bell, Vector3(1.6, 2.3, 1.6))
	bell.set_script(load("res://scripts/mechanics/alarm_bell.gd"))
	add_child(bell)

	_add_box(Vector3(STOVE.x, 0.45, STOVE.z), Vector3(1.3, 0.9, 0.8), Color(0.45, 0.38, 0.32), "Stove")
	_add_label(STOVE + Vector3(0, 1.15, 0), "锅台", 28)

	# 井沿保留薄碰撞，避免人直接走进井口体积
	_add_box(Vector3(WELL.x, 0.32, WELL.z), Vector3(1.35, 0.42, 1.35), WALLC, "WellRing")
	_add_label(WELL + Vector3(0, 1.8, 0), "水井", 44)

	_add_box(Vector3(-4.2, 0.32, -4.2), Vector3(2.2, 0.5, 1.1), WOOD, "Trough")
	_add_label(Vector3(-4.2, 1.6, -4.2), "驴槽", 36)
	_build_yard_furnishings()

func _build_outer_wall_and_lookout() -> void:
	# 实墙。只有墙西侧暗堡上一条 0.25 米高的枪缝，人过不去
	_add_box(Vector3(10.2, 1.35, -2.18), Vector3(0.7, 2.7, 6.86), WALLC, "OuterWallS")
	_add_box(Vector3(10.2, 1.35, 3.93), Vector3(0.7, 2.7, 3.76), WALLC, "OuterWallN")
	# 厚墙让开，内侧用薄板留缝。人贴着薄板，左右约 12 度仍能看出去。
	_add_box(Vector3(9.95, 0.66, 1.65), Vector3(0.2, 1.32, 0.86), WALLC, "SlitPanelLow")
	_add_box(Vector3(9.95, 2.13, 1.65), Vector3(0.2, 1.14, 0.86), WALLC, "SlitPanelHigh")
	_add_box(Vector3(9.95, 1.445, 1.36), Vector3(0.2, 0.24, 0.28), WALLC, "SlitPanelS")
	_add_box(Vector3(9.95, 1.445, 1.94), Vector3(0.2, 0.24, 0.28), WALLC, "SlitPanelN")
	_add_box(Vector3(9.15, 1.05, 0.93), Vector3(1.5, 2.1, 0.28), WALLC, "BunkerN")
	_add_box(Vector3(9.15, 1.05, 2.37), Vector3(1.5, 2.1, 0.28), WALLC, "BunkerS")
	_add_box(Vector3(9.15, 2.05, 1.65), Vector3(1.5, 0.22, 1.3), WALLC, "BunkerRoof")
	_add_label(Vector3(10.2, 2.4, 1.65), "枪眼", 22)
	_dress_field_screen()

func _visual_box(pos: Vector3, size: Vector3, color: Color, node_name: String) -> void:
	var body := _add_box(pos, size, color, node_name)
	body.collision_layer = 0
	body.collision_mask = 0

func _dress_field_screen() -> void:
	# 墙仍挡人。朝东这一面改成障子、晾架和禾捆，枪缝那一截留空。
	for wall_name in ["OuterWallS", "OuterWallN"]:
		var wall := get_node_or_null(wall_name)
		if wall:
			_hide_mesh(wall)
	var wood := Color(0.4, 0.28, 0.14)
	var straw := Color(0.72, 0.58, 0.26)
	var sheaf := Color(0.62, 0.46, 0.18)
	# 实墙网格藏起来，换成贴地的秫秸障子。枪缝那一段不铺，人仍得绕南北两端。
	_visual_box(Vector3(10.55, 1.28, -2.18), Vector3(0.08, 2.7, 6.7), straw, "ReedSouth")
	_visual_box(Vector3(10.55, 1.28, 3.93), Vector3(0.08, 2.7, 3.6), straw, "ReedNorth")
	var z := -5.4
	var stalk_i := 0
	while z < 5.7:
		if z < 1.15 or z > 2.15:
			_visual_box(Vector3(10.72, 0.95, z), Vector3(0.035, 1.9, 0.12), straw, "Sorghum%d" % stalk_i)
			if stalk_i % 4 == 0:
				_visual_box(Vector3(10.78, 0.95, z), Vector3(0.05, 1.9, 0.05), wood, "ScreenPost%d" % stalk_i)
			stalk_i += 1
		z += 0.22
	_visual_box(Vector3(10.74, 0.55, -2.2), Vector3(0.04, 0.04, 6.4), wood, "ScreenBindS")
	_visual_box(Vector3(10.74, 1.35, -2.2), Vector3(0.04, 0.04, 6.4), wood, "ScreenBindS2")
	_visual_box(Vector3(10.74, 0.55, 4.0), Vector3(0.04, 0.04, 3.3), wood, "ScreenBindN")
	_visual_box(Vector3(10.74, 1.35, 4.0), Vector3(0.04, 0.04, 3.3), wood, "ScreenBindN2")
	for spot in [Vector3(11.55, 0.0, -3.2), Vector3(11.7, 0.0, 4.1)]:
		_visual_box(spot + Vector3(0, 0.7, 0), Vector3(0.06, 1.4, 0.06), wood, "RackA%s" % str(spot.z))
		_visual_box(spot + Vector3(0.7, 0.7, 0), Vector3(0.06, 1.4, 0.06), wood, "RackB%s" % str(spot.z))
		_visual_box(spot + Vector3(0.35, 1.35, 0), Vector3(0.9, 0.05, 0.05), wood, "RackBar%s" % str(spot.z))
		_visual_box(spot + Vector3(0.15, 1.15, 0), Vector3(0.16, 0.42, 0.16), sheaf, "SheafA%s" % str(spot.z))
		_visual_box(spot + Vector3(0.5, 1.1, 0), Vector3(0.16, 0.38, 0.16), sheaf, "SheafB%s" % str(spot.z))
	for pile_z in [-4.4, -2.4, 3.2, 5.2]:
		_visual_box(Vector3(11.15, 0.28, pile_z), Vector3(0.45, 0.45, 0.28), sheaf, "SheafPile%d" % int((pile_z + 8.0) * 10.0))
	var port := Area3D.new()
	port.name = "FiringPort"
	port.position = Vector3(9.5, 1.15, 1.65)
	var pcol := CollisionShape3D.new()
	var pshape := BoxShape3D.new()
	pshape.size = Vector3(1.3, 1.6, 1.0)
	pcol.shape = pshape
	port.add_child(pcol)
	_hitbox(port, Vector3(1.1, 1.4, 0.9))
	port.set_script(load("res://scripts/mechanics/firing_port.gd"))
	port.set("aim_dir", Vector3.RIGHT)
	port.monitoring = true
	port.collision_mask = 2
	add_child(port)
	var post := Marker3D.new()
	post.position = Vector3(9.15, 0.2, 1.65)
	post.add_to_group("ally_port_post")
	add_child(post)
	_build_hollow_tree()
	_add_label(LOOKOUT + Vector3(0, 4.4, 0), "树缝", 28, Color(0.8, 1, 0.7))
	_add_label(Vector3(30.0, 2.2, 0), "敌军来路 · 向西进村", 40, Color(1, 0.7, 0.45))
	_add_box(Vector3(27.4, 0.42, 4.8), Vector3(1.6, 0.84, 1.1), WOOD, "CoverWoodA")
	_add_box(Vector3(29.2, 0.4, -4.6), Vector3(1.5, 0.8, 1.2), WOOD, "CoverWoodB")
	_add_box(Vector3(31.6, 0.38, 5.6), Vector3(1.8, 0.76, 1.3), WOOD, "CoverWoodC")
	_add_box(Vector3(26.8, 0.32, -5.4), Vector3(2.2, 0.64, 1.0), Color(0.5, 0.38, 0.2), "CoverSheaf")
	_add_label(Vector3(29.0, 1.4, 4.8), "柴垛", 20)
	for cp in [
		Vector3(27.4, 0.22, 4.8), Vector3(29.2, 0.22, -4.6), Vector3(31.6, 0.22, 5.6),
		Vector3(26.8, 0.22, -5.4), Vector3(9.0, 0.22, 1.65), Vector3(9.2, 0.22, -0.6),
		Vector3(-4.7, 0.22, -5.35), Vector3(10.55, 0.22, 3.2),
	]:
		var cover := Marker3D.new()
		cover.position = cp
		cover.add_to_group("cover_points")
		add_child(cover)
	var look_spawn := Marker3D.new()
	look_spawn.position = LOOKOUT + Vector3(0, 0.2, 0)
	look_spawn.add_to_group("lookout_spawn")
	add_child(look_spawn)
	var prisoner := Marker3D.new()
	prisoner.name = "PrisonerRally"
	prisoner.position = LOOKOUT + Vector3(-1.4, 0.15, 1.6)
	prisoner.add_to_group("prisoner_rally")
	add_child(prisoner)
	var look_zone := Area3D.new()
	look_zone.position = LOOKOUT + Vector3(0, 1.2, 0)
	var lz := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(1.0, 2.0, 1.0)
	lz.shape = lshape
	look_zone.add_child(lz)
	look_zone.set_script(load("res://scripts/mechanics/zone_trigger.gd"))
	look_zone.set("mark_observe", true)
	look_zone.monitoring = true
	look_zone.collision_mask = 2
	add_child(look_zone)
	var yard_spawn := Marker3D.new()
	yard_spawn.position = Vector3(-6.6, 0.25, 0.2)
	yard_spawn.add_to_group("explore_spawn")
	add_child(yard_spawn)

	var gate := Marker3D.new()
	gate.position = Vector3(12.5, 0.2, 0)
	gate.add_to_group("village_gate")
	add_child(gate)
	var espawn := Marker3D.new()
	espawn.position = Vector3(30, 0.2, 0)
	espawn.add_to_group("enemy_spawn")
	add_child(espawn)

func _shaft_mouth(hole: Vector3) -> void:
	var dark := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 4.6, 1.3)
	dark.mesh = box
	dark.position = hole + Vector3(0, -2.3, 0)
	dark.material_override = _mat(Color(0.03, 0.02, 0.02))
	add_child(dark)
	_add_box(hole + Vector3(-0.7, 0.4, 0), Vector3(0.12, 0.8, 1.4), WOOD, "FrmL%s" % hole)
	_add_box(hole + Vector3(0.7, 0.4, 0), Vector3(0.12, 0.8, 1.4), WOOD, "FrmR%s" % hole)

func _hitbox(parent: Node3D, size: Vector3) -> void:
	var hit := StaticBody3D.new()
	hit.collision_layer = 32
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	hit.add_child(col)
	parent.add_child(hit)

func _build_tunnels() -> void:
	# 瞭望口 → 东屋出口，从墙下穿过
	# 岔口是带门洞的封闭小室，通道只接到门洞上，尽头有墙，人走不出去。
	_hub(Vector3(8.2, 0, 0), ["west", "east", "south"])
	_hub(Vector3(8.2, 0, -2.2), ["north"])
	_hub(Vector3(2.6, 0, 0.15), ["west", "east", "south", "north"], ["north"])
	_hub(Vector3(-6.2, 0, 0), ["west", "east", "north"])
	_hub(Vector3(-10.0, 0, 0), ["east", "south"])
	_corridor_x(-9.25, -7.6, 0.0)
	_corridor_x_open_south(-7.6, -6.85, 0.0)
	_corridor_x(-6.85, -6.4, 0.0)
	_corridor_x(-6.3, -5.6, 0.15)
	_corridor_x_open_south(-5.6, -4.25, 0.15)
	_corridor_x(-3.3, 1.7, 0.15)
	_spine_firing_room()
	_corridor_x(3.5, 3.65, 0.0)
	_corridor_x_open_north(3.65, 4.85, 0.0)
	_corridor_x(4.85, 6.65, 0.0)
	_corridor_x(7.75, 8.05, 0.0)
	_hatch_gap()
	_corridor_x(9.0, 13.4, 0.0)
	_corridor_x_open_south(13.4, 15.0, 0.0)
	_corridor_x(15.0, 26.2, 0.0)
	_end_wall_x(26.45, 0.0)
	_corridor_z(14.2, -3.55, -0.7)
	_room(Vector3(14.2, TUNNEL_FLOOR, -4.15), Vector3(2.4, TUNNEL_H, 1.8), "EarRoom", &"south", &"west")
	_corridor_x(11.0, 13.15, -4.15)
	_end_wall_x(10.85, -4.15)
	_add_label(Vector3(14.2, TUNNEL_FLOOR + 1.25, -4.15), "耳室", 22)
	_build_choke_gate()
	_corridor_z(2.6, -7.2, -3.15)
	_hub(Vector3(2.6, 0, -2.4), ["north", "south", "west"], ["west"])
	_corridor_z(2.6, -1.55, -0.7)
	_end_wall_z(2.6, -7.35)
	_room(Vector3(0.15, TUNNEL_FLOOR, -2.6), Vector3(2.8, TUNNEL_H, 2.55), "MaskRoom", &"east")
	_room(Vector3(2.35, TUNNEL_FLOOR, 2.35), Vector3(3.0, TUNNEL_H, 2.6), "SideNiche", &"east", &"north")
	_conceal_side_ports()
	_corridor_z(8.2, -1.4, -0.8)
	_corridor_z(-10.0, -3.45, -0.8)
	_junction(-10.0, -4.2)
	# 井下岔口只通东/南/北，西侧必须封死（space_audit「井口西侧」）
	_end_wall_x(-10.85, -4.2)
	_corridor_z(-10.0, -7.2, -4.95)
	_end_wall_z(-10.0, -7.35)
	_corridor_x(-9.25, -3.5, -4.2)
	_end_wall_x(-3.4, -4.2)
	# 拉雷岔口段西墙打开；相邻段西墙不要 pad 叠进岔口
	_corridor_z(-6.2, 0.9, 3.18)
	_corridor_z_open_west(-6.2, 3.12, 4.78)
	_corridor_z(-6.2, 4.72, 6.7)
	_room(Vector3(-6.2, TUNNEL_FLOOR, 7.5), Vector3(2.8, TUNNEL_H, 2.4), "VillagerRoom", &"north")
	# 藏身暗室补角、加厚顶/侧壁，减少孔隙
	var vr_mid := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(-6.2, TUNNEL_FLOOR + TUNNEL_H + 0.22, 7.5), Vector3(3.05, 0.2, 2.7), TUNNEL_CEIL, "VillagerRoomC2")
	_add_box(Vector3(-6.2, TUNNEL_FLOOR + TUNNEL_H + 0.34, 7.5), Vector3(2.95, 0.12, 2.55), TUNNEL_CEIL, "VillagerRoomC3")
	_add_box(Vector3(-7.62, vr_mid, 7.5), Vector3(0.28, TUNNEL_H, 2.55), TUNNEL, "VillagerWallW2")
	_add_box(Vector3(-4.78, vr_mid, 7.5), Vector3(0.28, TUNNEL_H, 2.55), TUNNEL, "VillagerWallE2")
	_add_box(Vector3(-6.2, vr_mid, 8.62), Vector3(2.95, TUNNEL_H, 0.28), TUNNEL, "VillagerWallN2")
	_add_box(Vector3(-7.55, vr_mid, 6.45), Vector3(0.28, TUNNEL_H, 0.42), TUNNEL, "VillagerCornerSW")
	_add_box(Vector3(-4.85, vr_mid, 6.45), Vector3(0.28, TUNNEL_H, 0.42), TUNNEL, "VillagerCornerSE")
	_add_box(Vector3(-7.55, vr_mid, 8.55), Vector3(0.28, TUNNEL_H, 0.42), TUNNEL, "VillagerCornerNW")
	_add_box(Vector3(-4.85, vr_mid, 8.55), Vector3(0.28, TUNNEL_H, 0.42), TUNNEL, "VillagerCornerNE")
	_add_box(Vector3(-6.2, TUNNEL_FLOOR + TUNNEL_H + 0.22, 6.45), Vector3(2.9, 0.16, 0.5), TUNNEL_CEIL, "VillagerMouthC")
	_pair(LOOKOUT, &"lookout", "树洞", Vector3.ZERO, false)
	_pair(EXIT_HOLE, &"east_house", "东屋内", Vector3(0.35, 0, 0.35), false)
	_pair(WELL, &"well", "水井", Vector3(1.2, 0, 0), false)
	_pair(NORTH_HOLE, &"north_house", "北房夹壁", Vector3(0, 0, 0.55), true)
	_pair(TROUGH, &"trough", "驴槽", Vector3(0, 0, 0.8), false)
	_build_flip_mouth()
	_build_seal_door()
	_build_lower_drain()
	_build_loft()
	_build_trip_wire()
	_build_outer_tunnels()
	_seal_tunnel_overburden()

	var barrier := StaticBody3D.new()
	barrier.name = "WaterBarrier"
	barrier.position = Vector3(-10.0, TUNNEL_FLOOR + 1.56, -1.8)
	var bmesh := MeshInstance3D.new()
	bmesh.name = "Visual"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.02, 1.42, 0.08)
	bmesh.mesh = bm
	bmesh.position = Vector3(0, -0.71, 0)
	bmesh.material_override = _mat(WOOD)
	barrier.add_child(bmesh)
	var batten := MeshInstance3D.new()
	var batten_box := BoxMesh.new()
	batten_box.size = Vector3(1.02, 0.08, 0.1)
	batten.mesh = batten_box
	batten.position = Vector3(0, -0.35, 0)
	batten.material_override = _mat(WOOD)
	barrier.add_child(batten)
	var bcol := CollisionShape3D.new()
	bcol.name = "CollisionShape3D"
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(1.02, 1.42, 0.08)
	bcol.shape = bsh
	bcol.position = bmesh.position
	barrier.add_child(bcol)
	barrier.set_script(load("res://scripts/mechanics/water_barrier.gd"))
	add_child(barrier)
	_add_box(Vector3(-10.58, TUNNEL_FLOOR + 0.78, -1.8), Vector3(0.1, 1.56, 0.1), WOOD, "BarrierPostW")
	_add_box(Vector3(-9.42, TUNNEL_FLOOR + 0.78, -1.8), Vector3(0.1, 1.56, 0.1), WOOD, "BarrierPostE")
	_add_box(Vector3(-10.0, TUNNEL_FLOOR + 1.56, -1.8), Vector3(1.26, 0.08, 0.1), WOOD, "BarrierBeam")
	_add_label(Vector3(-10.0, TUNNEL_FLOOR + 1.35, -2.15), "挡水隔板 · 按住三秒", 24)
	var bpost := Marker3D.new()
	bpost.position = Vector3(WELL.x + 1.4, 0.2, WELL.z)
	bpost.add_to_group("ally_barrier_post")
	add_child(bpost)
	var well_m := Marker3D.new()
	well_m.position = WELL + Vector3(0, 0.4, 0)
	well_m.add_to_group("well")
	add_child(well_m)

	# 驴槽口翻板（南北廊）+ 西外廊翻板（东西廊），共两处
	_build_flip_trap_at(
		"FlipTrap",
		&"donkey_trough_trap",
		Vector3(TROUGH.x, TUNNEL_FLOOR + 0.4, TROUGH.z),
		90.0,
		"翻板 · 中间木轴"
	)
	_build_flip_trap_at(
		"FlipTrapWest",
		&"west_corridor_trap",
		Vector3(-18.2, TUNNEL_FLOOR + 0.4, 0.0),
		0.0,
		"翻板 · 西廊木轴"
	)

	var cache := Area3D.new()
	cache.name = "AmmoCache"
	cache.position = Vector3(8.2, TUNNEL_FLOOR + 0.6, -2.3)
	_hitbox(cache, Vector3(1.3, 1.2, 1.3))
	cache.set_script(load("res://scripts/mechanics/ammo_cache.gd"))
	add_child(cache)
	_add_label(Vector3(8.2, TUNNEL_FLOOR + 1.45, -2.3), "弹药暗室", 36, Color(1, 0.82, 0.4))

	var cmd := Marker3D.new()
	cmd.position = Vector3(8.2, TUNNEL_FLOOR + 0.1, -2.2)
	cmd.add_to_group("command_room_spawn")
	add_child(cmd)
	var safe := Marker3D.new()
	safe.position = Vector3(-6.2, TUNNEL_FLOOR + 0.12, 7.5)
	safe.add_to_group("villager_safe_zone")
	add_child(safe)
	_add_label(Vector3(-6.2, TUNNEL_FLOOR + 1.45, 7.5), "村民藏身点", 28, Color(1.0, 0.92, 0.55))
	_add_label(Vector3(10.5, TUNNEL_FLOOR + 1.35, 0), "向西 · 回东屋", 32, Color(1, 0.9, 0.6))
	var stain := Node3D.new()
	stain.name = "WaterStain"
	stain.set_script(load("res://scripts/mechanics/water_stain.gd"))
	add_child(stain)

	var zone := Area3D.new()
	zone.position = Vector3(6.0, -2.15, -1.0)
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(44.0, 4.1, 18.0)
	zc.shape = zs
	zone.add_child(zc)
	zone.set_script(load("res://scripts/mechanics/zone_trigger.gd"))
	zone.set("mark_tunnel", true)
	zone.monitoring = true
	zone.collision_mask = 2
	add_child(zone)

func _mask_ramp() -> void:
	var ramp := StaticBody3D.new()
	ramp.name = "MaskRamp"
	ramp.position = Vector3(0.85, TUNNEL_FLOOR + 0.28, -2.4)
	ramp.rotation_degrees = Vector3(0, 0, 20)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.35, 0.14, 1.15)
	mesh.mesh = box
	mesh.material_override = _mat(WOOD)
	ramp.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	ramp.add_child(col)
	add_child(ramp)
	_add_label(Vector3(0.7, TUNNEL_FLOOR + 1.35, -2.4), "掩身洞", 24)

func _build_choke_gate() -> void:
	# 卡口横在东西走道上，默认掀起。按住三秒才放下，放下后挡路。
	var gate := StaticBody3D.new()
	gate.name = "ChokeGate"
	gate.position = Vector3(20.5, TUNNEL_FLOOR + 1.56, 0.0)
	var gmesh := MeshInstance3D.new()
	gmesh.name = "Visual"
	var gm := BoxMesh.new()
	gm.size = Vector3(0.08, 1.42, 1.02)
	gmesh.mesh = gm
	gmesh.position = Vector3(0, -0.71, 0)
	gmesh.material_override = _mat(WOOD)
	gate.add_child(gmesh)
	var rib := MeshInstance3D.new()
	var rib_box := BoxMesh.new()
	rib_box.size = Vector3(0.1, 0.08, 1.02)
	rib.mesh = rib_box
	rib.position = Vector3(0, -0.35, 0)
	rib.material_override = _mat(WOOD)
	gate.add_child(rib)
	var gcol := CollisionShape3D.new()
	gcol.name = "CollisionShape3D"
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(0.08, 1.42, 1.02)
	gcol.shape = gsh
	gcol.position = gmesh.position
	gate.add_child(gcol)
	gate.set_script(load("res://scripts/mechanics/choke_gate.gd"))
	add_child(gate)
	_add_box(Vector3(20.5, TUNNEL_FLOOR + 0.78, -0.58), Vector3(0.1, 1.56, 0.1), WOOD, "ChokePostS")
	_add_box(Vector3(20.5, TUNNEL_FLOOR + 0.78, 0.58), Vector3(0.1, 1.56, 0.1), WOOD, "ChokePostN")
	_add_box(Vector3(20.5, TUNNEL_FLOOR + 1.56, 0.0), Vector3(0.1, 0.08, 1.26), WOOD, "ChokeBeam")
	_add_label(Vector3(20.5, TUNNEL_FLOOR + 1.3, 0.85), "卡口 · 按住三秒", 22)

func _hatch_gap() -> void:
	var x := 7.2
	var z := 0.0
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	var ceil_y := TUNNEL_FLOOR + TUNNEL_H + 0.1
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, z), Vector3(1.05, 0.2, 1.65), TUNNEL, "HatchFloor")
	_add_box(Vector3(x, mid_y, z - 0.66), Vector3(1.05, TUNNEL_H, 0.22), TUNNEL, "HatchWallS")
	_add_box(Vector3(x, mid_y, z + 0.66), Vector3(1.05, TUNNEL_H, 0.22), TUNNEL, "HatchWallN")
	# 顶上只留一个能落下的口，周围仍是顶板。
	_add_box(Vector3(x, ceil_y, -0.54), Vector3(1.3, 0.2, 0.58), TUNNEL_CEIL, "HatchCeilS")
	_add_box(Vector3(x, ceil_y, 0.78), Vector3(1.3, 0.2, 0.16), TUNNEL_CEIL, "HatchCeilN")
	_add_box(Vector3(6.62, ceil_y, 0.22), Vector3(0.22, 0.2, 0.96), TUNNEL_CEIL, "HatchCeilW")
	_add_box(Vector3(7.78, ceil_y, 0.22), Vector3(0.22, 0.2, 0.96), TUNNEL_CEIL, "HatchCeilE")

func _spine_firing_room() -> void:
	_add_box(Vector3(-4.0, TUNNEL_FLOOR - 0.1, 0.15), Vector3(1.55, 0.2, 1.75), TUNNEL, "PortGapFloor")
	_add_box(Vector3(-4.0, TUNNEL_FLOOR + TUNNEL_H + 0.1, 0.15), Vector3(1.55, 0.22, 1.75), TUNNEL_CEIL, "PortGapCeil")
	_add_box(Vector3(-4.0, TUNNEL_FLOOR + TUNNEL_H + 0.24, 0.15), Vector3(1.6, 0.12, 1.8), TUNNEL_CEIL, "PortGapCeil2")
	_add_box(Vector3(-4.0, TUNNEL_FLOOR + TUNNEL_H * 0.5, 0.15 + 0.7), Vector3(1.55, TUNNEL_H, 0.24), TUNNEL, "PortGapNorth")
	_room(Vector3(-4.45, TUNNEL_FLOOR, -1.55), Vector3(3.0, TUNNEL_H, 2.0), "SpinePortRoom", &"west", &"south")
	_corridor_z(-7.2, -1.7, -0.75)
	_corridor_x(-7.05, -5.75, -1.55)
	# 朝直道只留一条长窄缝，人从西边绕进来。
	_wall_with_slit(Vector3(-4.45, TUNNEL_FLOOR + TUNNEL_H * 0.5, -0.6), Vector3(2.95, TUNNEL_H, 0.22), Vector3(-3.7, TUNNEL_FLOOR + 0.96, -0.6), Vector3(0.85, 0.07, 0.24), "SpineSlit")
	_add_box(Vector3(-5.15, TUNNEL_FLOOR + TUNNEL_H * 0.5, -2.05), Vector3(0.16, TUNNEL_H, 0.75), TUNNEL, "SpineBaffle")
	# 翻口/枪眼转角补实，减少漏缝与碎块感
	_add_box(Vector3(-3.0, TUNNEL_FLOOR + TUNNEL_H * 0.5, -0.55), Vector3(0.28, TUNNEL_H, 0.36), TUNNEL, "SpineCornerE")
	_add_box(Vector3(-5.85, TUNNEL_FLOOR + TUNNEL_H * 0.5, -0.55), Vector3(0.28, TUNNEL_H, 0.36), TUNNEL, "SpineCornerW")
	_add_box(Vector3(-3.0, TUNNEL_FLOOR + TUNNEL_H * 0.5, -1.55), Vector3(0.24, TUNNEL_H, 0.55), TUNNEL, "SpineCornerE2")
	_add_box(Vector3(-5.85, TUNNEL_FLOOR + TUNNEL_H * 0.5, -1.55), Vector3(0.24, TUNNEL_H, 0.55), TUNNEL, "SpineCornerW2")
	_add_box(Vector3(-4.45, TUNNEL_FLOOR + TUNNEL_H + 0.22, -1.55), Vector3(3.2, 0.18, 2.2), TUNNEL_CEIL, "SpinePortRoomC2")
	_gun_port("SpinePort", Vector3(-3.55, TUNNEL_FLOOR + 0.9, -1.15), Vector3(0, 0, 1))
	_add_label(Vector3(-3.7, TUNNEL_FLOOR + 1.2, -1.35), "墙后枪眼", 22)

func _build_loft() -> void:
	var floor_y := -1.78
	var rise := floor_y - TUNNEL_FLOOR
	var run := 3.6
	var angle := rad_to_deg(atan(rise / run))
	var ramp := StaticBody3D.new()
	ramp.name = "LoftRamp"
	ramp.position = Vector3(6.05, (TUNNEL_FLOOR + floor_y) * 0.5, 2.35)
	ramp.rotation_degrees = Vector3(0, 0, angle)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(run + 0.25, 0.16, 1.05)
	mesh.mesh = box
	mesh.material_override = _mat(WOOD)
	ramp.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	ramp.add_child(col)
	add_child(ramp)
	_add_box(Vector3(7.7, floor_y - 0.08, 2.25), Vector3(1.9, 0.16, 1.7), TUNNEL, "LoftFloor")
	_add_box(Vector3(7.7, -0.42, 2.25), Vector3(2.1, 0.14, 1.9), TUNNEL_CEIL, "LoftCeil")
	_add_box(Vector3(8.6, -1.1, 2.25), Vector3(0.14, 1.3, 1.7), TUNNEL, "LoftWallE")
	_add_box(Vector3(7.7, -1.1, 3.05), Vector3(1.9, 1.3, 0.12), TUNNEL, "LoftWallN")
	_add_box(Vector3(7.2, floor_y - 0.08, 1.2), Vector3(1.15, 0.16, 1.9), TUNNEL, "LoftNeck")
	_add_box(Vector3(4.25, TUNNEL_FLOOR - 0.08, 1.2), Vector3(1.3, 0.16, 1.8), TUNNEL, "SideMouthFloor")
	_add_box(Vector3(4.25, TUNNEL_FLOOR + TUNNEL_H + 0.08, 1.2), Vector3(1.4, 0.14, 1.8), TUNNEL_CEIL, "SideMouthCeil")
	_add_box(Vector3(3.58, TUNNEL_FLOOR + TUNNEL_H * 0.5, 0.72), Vector3(0.14, TUNNEL_H, 0.64), TUNNEL, "SideMouthW")
	_add_box(Vector3(4.92, TUNNEL_FLOOR + TUNNEL_H * 0.5, 1.15), Vector3(0.14, TUNNEL_H, 1.5), TUNNEL, "SideMouthE")
	_add_box(Vector3(4.25, TUNNEL_FLOOR + TUNNEL_H * 0.5, 2.08), Vector3(0.7, TUNNEL_H, 0.14), TUNNEL, "SideMouthN")
	_add_box(Vector3(6.15, -1.15, 1.72), Vector3(2.1, 1.5, 0.12), TUNNEL, "RampWallS")
	_add_box(Vector3(6.1, -1.15, 2.98), Vector3(2.6, 1.5, 0.12), TUNNEL, "RampWallN")
	_add_box(Vector3(6.72, -1.15, 1.45), Vector3(0.12, 1.4, 0.5), TUNNEL, "LoftWallW")
	_add_box(Vector3(8.15, -1.15, 1.5), Vector3(0.9, 1.4, 0.12), TUNNEL, "LoftWallS")
	_add_box(Vector3(6.55, -1.2, 0.35), Vector3(0.12, 1.5, 1.7), TUNNEL, "NeckWallW")
	_add_box(Vector3(7.85, -1.2, 0.35), Vector3(0.12, 1.5, 1.7), TUNNEL, "NeckWallE")
	_add_label(Vector3(4.25, TUNNEL_FLOOR + 1.15, 0.75), "侧洞", 22)
	_add_label(Vector3(7.2, floor_y + 0.45, 0.7), "跳口", 20)

func _junction(x: float, z: float) -> void:
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	var ceil_y := TUNNEL_FLOOR + TUNNEL_H + 0.12
	var tag := "%d_%d" % [int(x * 10.0), int(z * 10.0)]
	var door := 1.1
	var along := 1.55
	var wing := (along - door) * 0.5
	var wing_at := door * 0.5 + wing * 0.5
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, z), Vector3(1.8, 0.2, 1.7), TUNNEL, "JxF" + tag)
	_add_box(Vector3(x, ceil_y, z), Vector3(1.9, 0.28, 1.8), TUNNEL_CEIL, "JxC" + tag)
	_add_box(Vector3(x, ceil_y + 0.16, z), Vector3(1.85, 0.12, 1.75), TUNNEL_CEIL, "JxC2" + tag)
	_add_box(Vector3(x - 0.72, mid_y, z - wing_at), Vector3(0.2, TUNNEL_H, wing), TUNNEL, "JxWLo" + tag)
	_add_box(Vector3(x - 0.72, mid_y, z + wing_at), Vector3(0.2, TUNNEL_H, wing), TUNNEL, "JxWHi" + tag)
	_add_box(Vector3(x + 0.72, mid_y, z - wing_at), Vector3(0.2, TUNNEL_H, wing), TUNNEL, "JxELo" + tag)
	_add_box(Vector3(x + 0.72, mid_y, z + wing_at), Vector3(0.2, TUNNEL_H, wing), TUNNEL, "JxEHi" + tag)
	_add_box(Vector3(x - wing_at, mid_y, z - 0.68), Vector3(wing, TUNNEL_H, 0.2), TUNNEL, "JxSLo" + tag)
	_add_box(Vector3(x + wing_at, mid_y, z - 0.68), Vector3(wing, TUNNEL_H, 0.2), TUNNEL, "JxSHi" + tag)
	_add_box(Vector3(x - wing_at, mid_y, z + 0.68), Vector3(wing, TUNNEL_H, 0.2), TUNNEL, "JxNLo" + tag)
	_add_box(Vector3(x + wing_at, mid_y, z + 0.68), Vector3(wing, TUNNEL_H, 0.2), TUNNEL, "JxNHi" + tag)

func _seal_tunnel_overburden() -> void:
	# 从洞顶一直填到地面下沿，挡住「悬浮地表」。仅留必要竖井。
	var y_bot := TUNNEL_FLOOR + TUNNEL_H + 0.05
	var y_top := -0.06
	var h := y_top - y_bot
	var y_mid := (y_bot + y_top) * 0.5
	# 竖井：跳口、树洞、东屋、水井、驴槽、北房（入口可上通，走廊不可透顶）
	var shafts: Array = [
		[6.55, 7.85, -0.65, 0.65],       # 跳口
		[21.35, 22.65, -0.7, 0.7],      # 树洞
		[1.7, 3.1, -0.55, 0.85],        # 东屋口
		[-10.7, -9.3, -4.3, -2.9],      # 水井
		[-4.95, -3.45, -4.9, -3.5],     # 驴槽
		[-7.0, -5.4, 6.6, 8.2],         # 北房夹壁
	]
	var chunk := 6.0
	var bx := -26.0
	var seq := 0
	while bx < 28.0:
		var bz := -12.0
		while bz < 16.0:
			var ex := minf(bx + chunk, 28.0)
			var ez := minf(bz + chunk, 16.0)
			seq = _burden_fill(y_mid, h, bx, bz, ex, ez, shafts, seq)
			bz += chunk
		bx += chunk

func _burden_fill(y_mid: float, h: float, ax: float, az: float, bx: float, bz: float, shafts: Array, seq: int) -> int:
	if bx - ax < 0.08 or bz - az < 0.08:
		return seq
	for s in shafts:
		var hx0: float = s[0]
		var hx1: float = s[1]
		var hz0: float = s[2]
		var hz1: float = s[3]
		if ax >= hx1 or bx <= hx0 or az >= hz1 or bz <= hz0:
			continue
		if ax < hx0:
			seq = _burden_fill(y_mid, h, ax, az, hx0, bz, shafts, seq)
		if bx > hx1:
			seq = _burden_fill(y_mid, h, hx1, az, bx, bz, shafts, seq)
		var ix0 := maxf(ax, hx0)
		var ix1 := minf(bx, hx1)
		if az < hz0:
			seq = _burden_fill(y_mid, h, ix0, az, ix1, hz0, shafts, seq)
		if bz > hz1:
			seq = _burden_fill(y_mid, h, ix0, hz1, ix1, bz, shafts, seq)
		return seq
	_add_burden_slab(y_mid, h, ax, az, bx, bz, seq)
	return seq + 1

func _add_burden_slab(y_mid: float, h: float, ax: float, az: float, bx: float, bz: float, seq: int) -> void:
	var cx := (ax + bx) * 0.5
	var cz := (az + bz) * 0.5
	var sx := bx - ax
	var sz := bz - az
	var body := StaticBody3D.new()
	body.name = "BurdenSeal%d" % seq
	body.collision_layer = 1
	body.position = Vector3(cx, y_mid, cz)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(sx, h, sz)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.11)
	mat.roughness = 0.97
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # 洞内仰视也必须不透
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(sx, h, sz)
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _build_outer_tunnels() -> void:
	# 向西通牲口棚粮囤口，向北通菜窖草垛口。各加一处卡口。
	_hub(Vector3(-14.5, 0, 0), ["east", "west"])
	_corridor_x(-13.7, -10.8, 0.0)
	_corridor_x(-21.5, -15.3, 0.0)
	_hub(Vector3(-22.0, 0, -1.2), ["east", "north"])
	_corridor_z(-22.0, -1.0, 0.0)
	_pair(Vector3(-22.0, 0, -1.4), &"barn_bin", "粮囤底", Vector3(0, 0, 0.4), false)
	_hub(Vector3(-6.2, 0, 11.2), ["south", "north"])
	_corridor_z(-6.2, 8.4, 10.4)
	_corridor_z(-6.2, 11.9, 13.6)
	_pair(Vector3(-6.2, 0, 14.0), &"cellar_hay", "草垛窖口", Vector3(0, 0, -0.35), false)
	var gate := StaticBody3D.new()
	gate.name = "OuterChoke"
	gate.position = Vector3(-14.5, TUNNEL_FLOOR + 1.56, 0.0)
	var gmesh := MeshInstance3D.new()
	gmesh.name = "Visual"
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.08, 1.42, 1.02)
	gmesh.mesh = gbox
	gmesh.position = Vector3(0, -0.71, 0)
	gmesh.material_override = _mat(WOOD)
	gate.add_child(gmesh)
	var gcol := CollisionShape3D.new()
	gcol.name = "CollisionShape3D"
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(0.12, 1.5, 1.1)
	gcol.shape = gsh
	gcol.position = Vector3(0, -0.71, 0)
	gate.add_child(gcol)
	gate.set_script(load("res://scripts/mechanics/choke_gate.gd"))
	add_child(gate)
	_add_label(Vector3(-14.5, TUNNEL_FLOOR + 1.3, 0.85), "卡口", 22)
	_add_label(Vector3(-22.0, TUNNEL_FLOOR + 1.2, -1.4), "地道口", 22)
	_add_label(Vector3(-6.2, TUNNEL_FLOOR + 1.2, 14.0), "地道口", 22)

func _build_trip_wire() -> void:
	# 西岔：南北墙止于主廊西壁外侧，地板桥接主廊；避免南/北墙伸进主廊挡北上
	_corridor_x(-8.1, -6.95, 3.95)
	_add_box(Vector3(-6.55, TUNNEL_FLOOR - 0.1, 3.95), Vector3(0.95, 0.2, 1.7), TUNNEL, "MineBridgeF")
	_tunnel_ceil(Vector3(-6.55, TUNNEL_FLOOR + TUNNEL_H + 0.12, 3.95), Vector3(1.0, 0.26, 1.85), "MineBridgeC")
	_room(Vector3(-8.45, TUNNEL_FLOOR, 3.95), Vector3(2.0, TUNNEL_H, 1.85), "MineNook", &"east")
	_add_box(Vector3(-8.45, TUNNEL_FLOOR + TUNNEL_H + 0.22, 3.95), Vector3(2.15, 0.16, 2.0), TUNNEL_CEIL, "MineNookC2")
	# 雷位：土包 + 木盖 + 草束伪装（矮，不挡走）
	_add_box(Vector3(-8.7, TUNNEL_FLOOR + 0.07, 4.2), Vector3(0.9, 0.14, 0.72), Color(0.3, 0.24, 0.16), "MineMound")
	_add_box(Vector3(-8.7, TUNNEL_FLOOR + 0.16, 4.2), Vector3(1.0, 0.04, 0.8), WOOD, "MinePlank")
	_add_box(Vector3(-8.7, TUNNEL_FLOOR + 0.22, 4.2), Vector3(0.72, 0.08, 0.55), Color(0.4, 0.36, 0.22), "MineSheaf")
	# 龛内侧靠南北壁的木桩 + 横绊线（中线留空可走）
	_add_box(Vector3(-8.15, TUNNEL_FLOOR + 0.55, 3.2), Vector3(0.1, 1.05, 0.1), WOOD, "MinePostS")
	_add_box(Vector3(-8.15, TUNNEL_FLOOR + 0.55, 4.7), Vector3(0.1, 1.05, 0.1), WOOD, "MinePostN")
	_add_box(Vector3(-8.15, TUNNEL_FLOOR + 1.0, 3.95), Vector3(0.025, 0.025, 1.4), Color(0.55, 0.48, 0.34), "MineLine")
	_add_box(Vector3(-8.15, TUNNEL_FLOOR + 0.95, 3.2), Vector3(0.28, 0.05, 0.05), WOOD, "MinePeg")
	var wire := Area3D.new()
	wire.name = "TripWire"
	wire.position = Vector3(-8.15, TUNNEL_FLOOR + 1.0, 3.95)
	var spool := MeshInstance3D.new()
	var spool_mesh := CylinderMesh.new()
	spool_mesh.top_radius = 0.08
	spool_mesh.bottom_radius = 0.08
	spool_mesh.height = 0.22
	spool.mesh = spool_mesh
	spool.position = Vector3(-0.2, -0.05, -0.62)
	spool.rotation_degrees = Vector3(0, 0, 90)
	spool.material_override = _mat(WOOD)
	wire.add_child(spool)
	var handle := MeshInstance3D.new()
	var handle_box := BoxMesh.new()
	handle_box.size = Vector3(0.28, 0.05, 0.05)
	handle.mesh = handle_box
	handle.position = Vector3(-0.05, -0.05, -0.62)
	handle.material_override = _mat(WOOD)
	wire.add_child(handle)
	var blast := Area3D.new()
	blast.name = "Blast"
	blast.position = Vector3(-0.75, -0.3, 0.25)
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.05, 1.0, 0.9)
	bcol.shape = bshape
	blast.add_child(bcol)
	blast.monitoring = true
	blast.collision_mask = 4
	wire.add_child(blast)
	wire.set_script(load("res://scripts/mechanics/trip_wire.gd"))
	wire.monitoring = true
	wire.collision_mask = 2
	add_child(wire)
	_add_label(Vector3(-8.2, TUNNEL_FLOOR + 1.3, 3.95), "拉雷 · 先拉线", 20)

func _gun_port(node_name: String, pos: Vector3, aim: Vector3) -> void:
	var port := Area3D.new()
	port.name = node_name
	port.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# 略放大站位触发盒，方便贴墙进入；不改墙体碰撞
	shape.size = Vector3(1.15, 1.35, 1.15)
	col.shape = shape
	port.add_child(col)
	port.set_script(load("res://scripts/mechanics/firing_port.gd"))
	port.set("port_id", StringName(node_name))
	port.set("aim_dir", aim)
	port.monitoring = true
	port.collision_mask = 2
	add_child(port)

func _build_lower_drain() -> void:
	# 井筒下层。上层地板保持封闭，人不会掉进排水层。
	var floor_y := -5.5
	var h := 1.05
	var mid_y := floor_y + h * 0.5
	var x := -10.0
	var z0 := -4.55
	var z1 := -1.75
	var cz := (z0 + z1) * 0.5
	var length := absf(z1 - z0)
	_add_box(Vector3(x, floor_y - 0.1, cz), Vector3(1.7, 0.2, length), TUNNEL, "DrainFloor")
	_add_box(Vector3(x, floor_y + h + 0.08, cz), Vector3(1.7, 0.16, length), TUNNEL_CEIL, "DrainCeil")
	_add_box(Vector3(x - 0.72, mid_y, cz), Vector3(0.18, h, length), TUNNEL, "DrainWallW")
	_add_box(Vector3(x + 0.72, mid_y, cz), Vector3(0.18, h, length), TUNNEL, "DrainWallE")
	_add_box(Vector3(x, mid_y, z0), Vector3(1.5, h, 0.18), TUNNEL, "DrainWallS")
	_add_box(Vector3(x, mid_y, z1), Vector3(1.5, h, 0.18), TUNNEL, "DrainWallN")
	_add_label(Vector3(x, floor_y + 0.7, -2.4), "下层排水", 22)

func _board(board_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var board := StaticBody3D.new()
	board.name = board_name
	board.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(WOOD)
	board.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	board.add_child(col)
	return board

func _flip_leaf(leaf_name: String, side: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = leaf_name
	hinge.position = Vector3(0, -0.32, side * 0.06)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.25, 0.05, 0.46)
	mesh.mesh = box
	mesh.position = Vector3(0, 0, side * 0.23)
	mesh.material_override = _mat(WOOD)
	hinge.add_child(mesh)
	return hinge

func _build_flip_trap_at(node_name: String, trap_id: StringName, pos: Vector3, yaw_deg: float, label: String) -> void:
	var trap := Area3D.new()
	trap.name = node_name
	trap.position = pos
	var tcol := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(1.6, 1.2, 1.5)
	tcol.shape = tshape
	trap.add_child(tcol)
	var tvis := Node3D.new()
	tvis.name = "Visual"
	tvis.rotation_degrees.y = yaw_deg
	trap.add_child(tvis)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.05
	axle_mesh.bottom_radius = 0.05
	axle_mesh.height = 1.35
	axle.mesh = axle_mesh
	axle.rotation_degrees = Vector3(0, 0, 90)
	axle.position = Vector3(0, -0.32, 0)
	axle.material_override = _mat(WOOD)
	tvis.add_child(axle)
	tvis.add_child(_flip_leaf("BoardL", -1.0))
	tvis.add_child(_flip_leaf("BoardR", 1.0))
	var stick := MeshInstance3D.new()
	stick.name = "Stick"
	var stick_box := BoxMesh.new()
	stick_box.size = Vector3(0.06, 0.42, 0.06)
	stick.mesh = stick_box
	stick.position = Vector3(0.55, -0.12, 0.28)
	stick.material_override = _mat(WOOD)
	tvis.add_child(stick)
	trap.set_script(load("res://scripts/mechanics/flip_trap.gd"))
	trap.set("trap_id", trap_id)
	trap.monitoring = true
	trap.collision_mask = 2 | 4 | 8
	add_child(trap)
	_add_label(pos + Vector3(0, 0.9, 0), label, 22)

func _build_flip_mouth() -> void:
	# 默认 BoardClosed 堵住南死道；翻下后 BoardAlt 挡直道、死道可进
	var mouth := Node3D.new()
	mouth.name = "FlipMouthEast"
	mouth.set_script(load("res://scripts/mechanics/flip_mouth.gd"))
	mouth.set("report_dead_end", true)
	mouth.set("hint_closed", "E 翻下这块板：打开南死道，挡住直道")
	mouth.set("hint_open", "E 翻回这块板：死道重新挡住，直道恢复")
	var closed := _board("BoardClosed", Vector3(2.6, TUNNEL_FLOOR + 0.76, -1.05), Vector3(1.04, 1.42, 0.08))
	closed.set_meta("hinged", true)
	closed.set_meta("shut_yaw", 0.0)
	closed.set_meta("open_yaw", -90.0)
	var cmesh := closed.get_child(0) as MeshInstance3D
	cmesh.position = Vector3(0.52, 0, 0)
	var ccol := closed.get_child(1) as CollisionShape3D
	ccol.position = cmesh.position
	mouth.add_child(closed)
	var flap := _board("BoardAlt", Vector3(3.55, TUNNEL_FLOOR + 0.76, 0.15), Vector3(0.08, 1.42, 1.04))
	flap.rotation_degrees.y = -90.0
	flap.set_meta("hinged", true)
	flap.set_meta("shut_yaw", 0.0)
	flap.set_meta("open_yaw", -90.0)
	var mesh := flap.get_child(0) as MeshInstance3D
	mesh.position = Vector3(0, 0, -0.52)
	var col := flap.get_child(1) as CollisionShape3D
	col.position = mesh.position
	mouth.add_child(flap)
	add_child(mouth)
	_add_box(Vector3(3.55, TUNNEL_FLOOR + 0.78, 0.7), Vector3(0.1, 1.56, 0.1), WOOD, "FlipPost")
	# 翻口门框与转角土塞，减少板边漏缝
	var flip_mid := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(2.05, TUNNEL_FLOOR + 0.78, -1.05), Vector3(0.14, 1.5, 0.14), WOOD, "FlipFrameW")
	_add_box(Vector3(3.15, TUNNEL_FLOOR + 0.78, -1.05), Vector3(0.14, 1.5, 0.14), WOOD, "FlipFrameE")
	_add_box(Vector3(2.6, TUNNEL_FLOOR + 1.5, -1.05), Vector3(1.25, 0.12, 0.16), WOOD, "FlipLintel")
	_add_box(Vector3(2.05, flip_mid, -0.55), Vector3(0.22, TUNNEL_H, 0.55), TUNNEL, "FlipCornerSW")
	_add_box(Vector3(3.15, flip_mid, -0.55), Vector3(0.22, TUNNEL_H, 0.55), TUNNEL, "FlipCornerSE")
	_add_box(Vector3(2.6, TUNNEL_FLOOR + TUNNEL_H + 0.18, -0.7), Vector3(1.35, 0.14, 0.7), TUNNEL_CEIL, "FlipCornerC")
	_add_label(Vector3(3.15, TUNNEL_FLOOR + 1.35, 0.15), "翻口 · 平时挡死道", 22)

func _build_seal_door() -> void:
	# 门板必须在藏身暗室入口（z≈6.4），不能挡北廊中段，否则拉雷龛也进不去
	var seal := Node3D.new()
	seal.name = "VillagerSeal"
	seal.add_to_group("villager_seal")
	seal.set_script(load("res://scripts/mechanics/flip_mouth.gd"))
	seal.set("hint_closed", "E 打开翻眼进暗室")
	seal.set("hint_open", "E 关上翻眼")
	var door := _board("BoardClosed", Vector3(-6.72, TUNNEL_FLOOR + 0.76, 6.45), Vector3(1.04, 1.42, 0.08))
	door.set_meta("hinged", true)
	door.set_meta("shut_yaw", 0.0)
	door.set_meta("open_yaw", 90.0)
	var mesh := door.get_child(0) as MeshInstance3D
	mesh.position = Vector3(0.52, 0, 0)
	var col := door.get_child(1) as CollisionShape3D
	col.position = mesh.position
	seal.add_child(door)
	add_child(seal)
	_add_box(Vector3(-6.72, TUNNEL_FLOOR + 0.78, 6.45), Vector3(0.1, 1.56, 0.1), WOOD, "SealPost")
	_add_box(Vector3(-5.68, TUNNEL_FLOOR + 0.78, 6.45), Vector3(0.1, 1.56, 0.1), WOOD, "SealPostE")
	_add_box(Vector3(-6.2, TUNNEL_FLOOR + 1.52, 6.45), Vector3(1.15, 0.08, 0.12), WOOD, "SealLintel")
	_add_label(Vector3(-6.2, TUNNEL_FLOOR + 1.45, 6.85), "翻眼 · 暗室门", 22)

func _hub(c: Vector3, opens: PackedStringArray, wide: Array = []) -> void:
	var span := 2.0
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	var tag := "%d_%d" % [int(c.x * 10.0), int(c.z * 10.0)]
	_add_box(Vector3(c.x, TUNNEL_FLOOR - 0.1, c.z), Vector3(span, 0.2, span), TUNNEL, "HubF" + tag)
	_add_box(Vector3(c.x, TUNNEL_FLOOR + TUNNEL_H + 0.1, c.z), Vector3(span, 0.2, span), TUNNEL_CEIL, "HubC" + tag)
	var half := span * 0.5
	_hub_face(c, mid_y, half, span, tag + "W", opens.has("west"), wide.has("west"), Vector3(-1, 0, 0))
	_hub_face(c, mid_y, half, span, tag + "E", opens.has("east"), wide.has("east"), Vector3(1, 0, 0))
	_hub_face(c, mid_y, half, span, tag + "S", opens.has("south"), wide.has("south"), Vector3(0, 0, -1))
	_hub_face(c, mid_y, half, span, tag + "N", opens.has("north"), wide.has("north"), Vector3(0, 0, 1))

func _hub_face(c: Vector3, mid_y: float, half: float, span: float, tag: String, open: bool, wide: bool, dir: Vector3) -> void:
	var along_x := absf(dir.x) > 0.5
	var door := 1.75 if wide else 1.1
	var wing := (span - door) * 0.5
	var wing_at := door * 0.5 + wing * 0.5
	if not open:
		var pos := c + dir * half
		pos.y = mid_y
		var size := Vector3(0.18, TUNNEL_H, 2.0) if along_x else Vector3(2.0, TUNNEL_H, 0.18)
		_add_box(pos, size, TUNNEL, "Hub" + tag)
		return
	for sign in [-1.0, 1.0]:
		var pos := c + dir * half
		if along_x:
			pos.z += sign * wing_at
		else:
			pos.x += sign * wing_at
		pos.y = mid_y
		var size := Vector3(0.18, TUNNEL_H, wing) if along_x else Vector3(wing, TUNNEL_H, 0.18)
		_add_box(pos, size, TUNNEL, "Hub%s%d" % [tag, int(sign)])

func _end_wall_x(x: float, z: float) -> void:
	_add_box(Vector3(x, TUNNEL_FLOOR + TUNNEL_H * 0.5, z), Vector3(0.22, TUNNEL_H, 1.7), TUNNEL, "EndX%d" % int(x * 10.0))

func _end_wall_z(x: float, z: float) -> void:
	_add_box(Vector3(x, TUNNEL_FLOOR + TUNNEL_H * 0.5, z), Vector3(1.7, TUNNEL_H, 0.22), TUNNEL, "EndZ%d" % int(z * 10.0))

func _build_hollow_tree() -> void:
	var c := LOOKOUT
	var wood := Color(0.34, 0.24, 0.12)
	# 只留碰撞，外观是树干。朝东一条又长又窄的眼缝。
	_hide_mesh(_add_box(Vector3(c.x, 1.35, c.z - 0.73), Vector3(1.7, 2.7, 0.22), wood, "TreeWallS"))
	_hide_mesh(_add_box(Vector3(c.x, 1.35, c.z + 0.73), Vector3(1.7, 2.7, 0.22), wood, "TreeWallN"))
	_hide_mesh(_add_box(Vector3(c.x - 0.73, 1.35, c.z), Vector3(0.22, 2.7, 1.24), wood, "TreeWallW"))
	_hide_mesh(_add_box(Vector3(c.x + 0.73, 0.68, c.z), Vector3(0.22, 1.36, 1.24), wood, "TreeWallELow"))
	_hide_mesh(_add_box(Vector3(c.x + 0.73, 2.11, c.z), Vector3(0.22, 1.18, 1.24), wood, "TreeWallEHigh"))
	_hide_mesh(_add_box(Vector3(c.x + 0.73, 1.44, c.z - 0.42), Vector3(0.22, 0.2, 0.4), wood, "TreeSlitS"))
	_hide_mesh(_add_box(Vector3(c.x + 0.73, 1.44, c.z + 0.42), Vector3(0.22, 0.2, 0.4), wood, "TreeSlitN"))
	_hide_mesh(_add_box(Vector3(c.x, 2.85, c.z), Vector3(1.8, 0.28, 1.8), wood, "TreeCap"))
	_hide_mesh(_add_box(Vector3(c.x, 4.05, c.z), Vector3(2.8, 1.2, 2.8), Color(0.2, 0.4, 0.16), "LookoutCrown"))
	_gun_port("LookoutPort", c + Vector3(0, 1.05, 0), Vector3.RIGHT)

func _corridor_x_open_south(x0: float, x1: float, z: float) -> void:
	# 去掉较小 Z 一侧的墙。北墙保留。
	_corridor_x_partial(x0, x1, z, true, false)

func _corridor_x_open_north(x0: float, x1: float, z: float) -> void:
	# 去掉较大 Z 一侧的墙。南墙保留。
	_corridor_x_partial(x0, x1, z, false, true)

func _corridor_x_partial(x0: float, x1: float, z: float, north_wall: bool, south_wall: bool) -> void:
	var pad := 0.06
	var a := minf(x0, x1) - pad
	var b := maxf(x0, x1) + pad
	var length := b - a
	var cx := (a + b) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(cx, TUNNEL_FLOOR - 0.1, z), Vector3(length, 0.2, w + 0.45), TUNNEL, "OFx%s" % cx)
	_tunnel_ceil(Vector3(cx, TUNNEL_FLOOR + TUNNEL_H + 0.12, z), Vector3(length, 0.26, w + 0.6), "OCx%s" % cx)
	if south_wall:
		_add_box(Vector3(cx, mid_y, z - w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "OSx%s" % cx)
	if north_wall:
		_add_box(Vector3(cx, mid_y, z + w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "ONx%s" % cx)

func _corridor_z_open_west(x: float, z0: float, z1: float) -> void:
	var pad := 0.06
	var a := minf(z0, z1) - pad
	var b := maxf(z0, z1) + pad
	var length := b - a
	var cz := (a + b) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, cz), Vector3(w + 0.45, 0.2, length), TUNNEL, "OFz%s" % cz)
	_tunnel_ceil(Vector3(x, TUNNEL_FLOOR + TUNNEL_H + 0.12, cz), Vector3(w + 0.6, 0.26, length), "OCz%s" % cz)
	_add_box(Vector3(x + w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "OEz%s" % cz)

func _tunnel_ceil(pos: Vector3, size: Vector3, tag: String) -> void:
	_add_box(pos, size, TUNNEL_CEIL, tag)
	_add_box(Vector3(pos.x, pos.y + 0.17, pos.z), Vector3(size.x, 0.12, size.z * 0.96), TUNNEL_CEIL, tag + "B")

func _corridor_x(x0: float, x1: float, z: float) -> void:
	# 接缝微重叠，避免段与段之间漏地板/侧壁
	var pad := 0.06
	var a := minf(x0, x1) - pad
	var b := maxf(x0, x1) + pad
	var length := b - a
	var cx := (a + b) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(cx, TUNNEL_FLOOR - 0.1, z), Vector3(length, 0.2, w + 0.45), TUNNEL, "CFx%s%s" % [x0, z])
	_tunnel_ceil(Vector3(cx, TUNNEL_FLOOR + TUNNEL_H + 0.12, z), Vector3(length, 0.26, w + 0.6), "CCx%s%s" % [x0, z])
	_add_box(Vector3(cx, mid_y, z - w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "CLx%s%s" % [x0, z])
	_add_box(Vector3(cx, mid_y, z + w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "CRx%s%s" % [x0, z])

func _corridor_z(x: float, z0: float, z1: float) -> void:
	var pad := 0.06
	var a := minf(z0, z1) - pad
	var b := maxf(z0, z1) + pad
	var length := b - a
	var cz := (a + b) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, cz), Vector3(w + 0.45, 0.2, length), TUNNEL, "CFz%s" % z0)
	_tunnel_ceil(Vector3(x, TUNNEL_FLOOR + TUNNEL_H + 0.12, cz), Vector3(w + 0.6, 0.26, length), "CCz%s" % z0)
	_add_box(Vector3(x - w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "CLz%s" % z0)
	_add_box(Vector3(x + w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "CRz%s" % z0)

func _room(floor_center: Vector3, size: Vector3, node_name: String, open_side: StringName, open_side_2: StringName = &"") -> void:
	var mid_y := TUNNEL_FLOOR + size.y * 0.5
	var opens: Array[StringName] = [open_side, open_side_2]
	_add_box(Vector3(floor_center.x, TUNNEL_FLOOR - 0.1, floor_center.z), Vector3(size.x, 0.2, size.z), TUNNEL, node_name + "F")
	_add_box(Vector3(floor_center.x, TUNNEL_FLOOR + size.y + 0.1, floor_center.z), Vector3(size.x, 0.2, size.z), TUNNEL_CEIL, node_name + "C")
	if not opens.has(&"north"):
		_add_box(Vector3(floor_center.x, mid_y, floor_center.z - size.z * 0.5), Vector3(size.x, size.y, 0.18), TUNNEL, node_name + "N")
	if not opens.has(&"south"):
		_add_box(Vector3(floor_center.x, mid_y, floor_center.z + size.z * 0.5), Vector3(size.x, size.y, 0.18), TUNNEL, node_name + "S")
	if not opens.has(&"west"):
		_add_box(Vector3(floor_center.x - size.x * 0.5, mid_y, floor_center.z), Vector3(0.18, size.y, size.z), TUNNEL, node_name + "W")
	if not opens.has(&"east"):
		_add_box(Vector3(floor_center.x + size.x * 0.5, mid_y, floor_center.z), Vector3(0.18, size.y, size.z), TUNNEL, node_name + "E")

func _shaft_room(hole: Vector3, open_dir: Vector3) -> void:
	var height := FLOOR_TOP - TUNNEL_FLOOR
	var mid_y := (FLOOR_TOP + TUNNEL_FLOOR) * 0.5
	_add_box(Vector3(hole.x, TUNNEL_FLOOR - 0.1, hole.z), Vector3(1.4, 0.2, 1.4), TUNNEL, "Sf%s" % hole)
	for i in 4:
		var d: Vector3 = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][i]
		if d.dot(open_dir) > 0.5:
			continue
		var along_x := absf(d.x) > 0.5
		_add_box(Vector3(hole.x, mid_y, hole.z) + d * 0.75, Vector3(0.16, height, 1.45) if along_x else Vector3(1.45, height, 0.16), TUNNEL, "Sw%s%d" % [hole, i])

func _pair(hole: Vector3, id: StringName, hint: String, stand: Vector3, shelter: bool) -> void:
	var up_mark := Marker3D.new()
	up_mark.position = hole + Vector3(stand.x, 0.15, stand.z)
	add_child(up_mark)
	var down_mark := Marker3D.new()
	down_mark.position = Vector3(hole.x, TUNNEL_FLOOR + 0.12, hole.z) + stand * 0.2
	add_child(down_mark)
	var down := _make_entrance("In_%s" % id, hole + Vector3(0, 0.8, 0), id, hint, true, shelter, down_mark)
	var up := _make_entrance("Out_%s" % id, down_mark.position + Vector3(0, 0.8, 0), id, "回到%s" % hint, false, false, up_mark)
	down.set("discoverable", shelter == false and id != &"lookout")
	if id == &"lookout":
		_shrink_mouth(down, Vector3(0.9, 1.45, 0.9))
	up.set("discoverable", false)
	up.set("hint_text", "E 回到地面")
	_dress_mouth(down, id, hole)
	_add_label(down_mark.position + Vector3(0, 1.25, 0), "地道口", 22)
	var sp := Marker3D.new()
	sp.position = up_mark.position
	sp.add_to_group("search_points")
	add_child(sp)

func _dress_mouth(ent: Node, id: StringName, hole: Vector3) -> void:
	match id:
		&"lookout":
			ent.set("hint_text", "E 从树洞下去")
		&"east_house":
			ent.set("hint_text", "E 掀开炕板，下去是地道")
			_lid(ent, Vector3(0.35, -0.55, 0.2), Vector3(0.95, 0.08, 0.7), Vector3(0.8, 0, 0), Vector3.ZERO)
			_add_label(hole + Vector3(0.7, 0.7, 0.55), "炕板 · 地道口", 20)
		&"well":
			ent.set("hint_text", "E 拨开井壁石板，进地道")
			_lid(ent, Vector3(0.55, -0.35, 0.15), Vector3(0.12, 0.7, 0.55), Vector3.ZERO, Vector3(0, 0, -70))
			_add_label(hole + Vector3(0.9, 1.15, 0), "井壁石板 · 地道口", 20)
		&"trough":
			ent.set("hint_text", "E 抽开槽底板，进地道")
			_lid(ent, Vector3(0, -0.55, 0.15), Vector3(0.9, 0.07, 0.5), Vector3(0.7, 0, 0), Vector3.ZERO)
			_add_label(hole + Vector3(0, 0.85, 0.7), "槽底板 · 地道口", 20)
		&"north_house":
			ent.set("hint_text", "E 推开夹壁板，进地道")
			_lid(ent, Vector3(0.15, -0.15, 0.35), Vector3(0.7, 1.1, 0.08), Vector3.ZERO, Vector3(0, 75, 0))
			_add_label(hole + Vector3(0.4, 1.2, 0.2), "夹壁板 · 地道口", 20)
		&"barn_bin":
			ent.set("hint_text", "E 掀开粮囤底板")
			_lid(ent, Vector3(0, -0.45, 0.1), Vector3(0.9, 0.08, 0.7), Vector3(0.75, 0, 0), Vector3.ZERO)
		&"cellar_hay":
			ent.set("hint_text", "E 拨开草垛进窖")
			_lid(ent, Vector3(0, -0.4, 0.1), Vector3(1.1, 0.1, 0.8), Vector3(0.8, 0, 0), Vector3.ZERO)

func _lid(ent: Node, local_pos: Vector3, size: Vector3, slide: Vector3, hinge: Vector3) -> void:
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	var box := BoxMesh.new()
	box.size = size
	lid.mesh = box
	lid.position = local_pos
	lid.material_override = _mat(WOOD if slide != Vector3.ZERO else WALLC)
	if slide != Vector3.ZERO:
		lid.set_meta("slide", slide)
	elif hinge != Vector3.ZERO:
		lid.set_meta("hinge", hinge)
	ent.add_child(lid)

func _make_entrance(node_name: String, pos: Vector3, id: StringName, hint: String, to_tunnel: bool, shelter: bool, linked: Node3D) -> Area3D:
	var ent := Area3D.new()
	ent.name = node_name
	ent.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.6, 1.6)
	col.shape = shape
	ent.add_child(col)
	_hitbox(ent, Vector3(1.2, 1.2, 1.2))
	ent.set_script(load("res://scripts/mechanics/tunnel_entrance.gd"))
	ent.monitoring = true
	ent.collision_mask = 2 | 4 | 16
	add_child(ent)
	ent.set("entrance_id", id)
	ent.set("hint_text", hint)
	ent.set("is_shelter", shelter)
	ent.set("enters_tunnel", to_tunnel)
	ent.set("discoverable", false)
	ent.set("linked_node_path", ent.get_path_to(linked))
	return ent

func _conceal_side_ports() -> void:
	var eye_y := TUNNEL_FLOOR + 0.935
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	# 缝口加高加宽保证站位视线；转角补块避开缝平面，避免挡枪
	_wall_with_slit(Vector3(1.52, mid_y, -2.84), Vector3(0.18, TUNNEL_H, 0.88), Vector3(1.52, eye_y, -2.84), Vector3(0.22, 0.12, 0.72), "DeadSlit")
	_add_box(Vector3(0.15, mid_y, -2.5), Vector3(0.75, TUNNEL_H, 0.16), TUNNEL, "DeadBaffle")
	_gun_port("DeadEndPort", Vector3(1.05, TUNNEL_FLOOR + 0.9, -2.84), Vector3.RIGHT)
	_add_label(Vector3(0.55, TUNNEL_FLOOR + 1.25, -3.15), "死道枪眼", 20)
	_wall_with_slit(Vector3(2.15, mid_y, 1.08), Vector3(0.88, TUNNEL_H, 0.18), Vector3(2.15, eye_y, 1.08), Vector3(0.72, 0.12, 0.22), "NicheSlit")
	_add_box(Vector3(1.28, mid_y, 1.08), Vector3(0.9, TUNNEL_H, 0.18), TUNNEL, "NichePlugW")
	_add_box(Vector3(3.2, mid_y, 1.08), Vector3(1.35, TUNNEL_H, 0.18), TUNNEL, "NichePlugE")
	_add_box(Vector3(3.85, mid_y, 2.9), Vector3(0.2, TUNNEL_H, 1.55), TUNNEL, "NicheDoorN")
	_add_box(Vector3(1.4, mid_y, 1.85), Vector3(0.16, TUNNEL_H, 0.75), TUNNEL, "NicheBaffle")
	_gun_port("NichePort", Vector3(2.4, TUNNEL_FLOOR + 0.9, 1.5), Vector3(0, 0, -1))
	_add_label(Vector3(2.5, TUNNEL_FLOOR + 1.25, 1.85), "侧龛枪眼", 20)

func _wall_with_slit(center: Vector3, full: Vector3, slit_center: Vector3, slit_size: Vector3, tag: String) -> void:
	# 四块整板围出一条扁缝；木框贴缝沿外侧，绝不穿进缝心挡视线
	var a := center - full * 0.5
	var b := center + full * 0.5
	var s0 := slit_center - slit_size * 0.5
	var s1 := slit_center + slit_size * 0.5
	_span_box(Vector3(a.x, a.y, a.z), Vector3(b.x, s0.y, b.z), tag + "Lo")
	_span_box(Vector3(a.x, s1.y, a.z), Vector3(b.x, b.y, b.z), tag + "Hi")
	if full.z <= full.x and full.z <= full.y:
		_span_box(Vector3(a.x, s0.y, a.z), Vector3(s0.x, s1.y, b.z), tag + "L")
		_span_box(Vector3(s1.x, s0.y, a.z), Vector3(b.x, s1.y, b.z), tag + "R")
		var depth := maxf(full.z, 0.18)
		_add_box(Vector3(slit_center.x, s1.y + 0.03, center.z), Vector3(slit_size.x + 0.1, 0.05, depth), WOOD, tag + "FrameHi")
		_add_box(Vector3(slit_center.x, s0.y - 0.03, center.z), Vector3(slit_size.x + 0.1, 0.05, depth), WOOD, tag + "FrameLo")
		_add_box(Vector3(s0.x - 0.03, slit_center.y, center.z), Vector3(0.05, slit_size.y + 0.08, depth), WOOD, tag + "FrameL")
		_add_box(Vector3(s1.x + 0.03, slit_center.y, center.z), Vector3(0.05, slit_size.y + 0.08, depth), WOOD, tag + "FrameR")
	else:
		_span_box(Vector3(a.x, s0.y, a.z), Vector3(b.x, s1.y, s0.z), tag + "L")
		_span_box(Vector3(a.x, s0.y, s1.z), Vector3(b.x, s1.y, b.z), tag + "R")
		var depth2 := maxf(full.x, 0.18)
		_add_box(Vector3(center.x, s1.y + 0.03, slit_center.z), Vector3(depth2, 0.05, slit_size.z + 0.1), WOOD, tag + "FrameHi")
		_add_box(Vector3(center.x, s0.y - 0.03, slit_center.z), Vector3(depth2, 0.05, slit_size.z + 0.1), WOOD, tag + "FrameLo")
		_add_box(Vector3(center.x, slit_center.y, s0.z - 0.03), Vector3(depth2, slit_size.y + 0.08, 0.05), WOOD, tag + "FrameL")
		_add_box(Vector3(center.x, slit_center.y, s1.z + 0.03), Vector3(depth2, slit_size.y + 0.08, 0.05), WOOD, tag + "FrameR")

func _span_box(a: Vector3, b: Vector3, tag: String) -> void:
	var size := b - a
	if size.x < 0.02 or size.y < 0.02 or size.z < 0.02:
		return
	_add_box((a + b) * 0.5, size, TUNNEL, tag)

func _slit_plug(center: Vector3, full: Vector3, y0: float, y1: float, tag: String) -> void:
	_add_box(Vector3(center.x, y0 * 0.5, center.z), Vector3(full.x, y0, full.z), HOUSE, tag + "Lo")
	var above := 2.7 - y1
	_add_box(Vector3(center.x, y1 + above * 0.5, center.z), Vector3(full.x, above, full.z), HOUSE, tag + "Hi")

func _shrink_mouth(ent: Node, sz: Vector3) -> void:
	((ent.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = sz
	var hit := ent.get_child(1) as StaticBody3D
	((hit.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = sz

func _build_yard_furnishings() -> void:
	var stone := Color(0.55, 0.52, 0.46)
	var clay := Color(0.45, 0.48, 0.42)
	var grain := Color(0.72, 0.6, 0.32)
	_add_cyl(Vector3(-2.4, 0.16, -3.15), 0.82, 0.28, stone, "Millstone")
	_add_cyl(Vector3(-2.4, 0.42, -2.7), 0.18, 0.7, stone, "MillRoller")
	_add_label(Vector3(-2.4, 1.15, -3.15), "碾子", 22)
	_add_cyl(Vector3(-3.7, 0.18, -2.85), 0.42, 0.32, stone, "Quern")
	_add_label(Vector3(-3.7, 0.85, -2.85), "磨", 22)
	_add_cyl(Vector3(-11.85, 0.35, -3.35), 0.32, 0.7, clay, "JarA")
	_add_cyl(Vector3(-11.85, 0.35, -4.15), 0.32, 0.7, clay, "JarB")
	_add_label(Vector3(-11.4, 1.05, -3.75), "水缸", 20)
	_add_box(Vector3(-10.9, 0.7, -3.6), Vector3(0.12, 1.4, 0.12), WOOD, "WellPostW")
	_add_box(Vector3(-9.1, 0.7, -3.6), Vector3(0.12, 1.4, 0.12), WOOD, "WellPostE")
	_add_box(Vector3(-10.0, 1.35, -3.6), Vector3(1.9, 0.1, 0.1), WOOD, "WellBeam")
	_hang_rope(Vector3(-10.0, 1.28, -3.6), Vector3(WELL.x, 0.62, WELL.z), true)
	_add_label(Vector3(-10.0, 1.7, -3.15), "辘轳", 20)
	_add_box(Vector3(1.15, 0.4, -5.9), Vector3(1.4, 0.8, 0.9), Color(0.5, 0.38, 0.2), "Woodpile")
	_add_label(Vector3(1.15, 1.15, -5.9), "柴垛", 20)
	_add_box(Vector3(-2.55, 0.55, -4.2), Vector3(0.14, 1.1, 0.14), WOOD, "HitchPost")
	_add_box(Vector3(-4.6, 0.06, 4.85), Vector3(2.6, 0.12, 0.85), Color(0.42, 0.32, 0.2), "VegetableBed")
	_add_label(Vector3(-4.6, 0.45, 4.85), "菜畦", 18)
	_add_box(Vector3(-4.7, 0.95, -5.35), Vector3(1.35, 1.8, 0.16), WALLC, "ScreenWall")
	_door_leaf(Vector3(-10.55, 1.05, 5.42), 0.0, 1.0)
	_door_leaf(Vector3(-3.45, 1.05, 5.42), 0.0, 1.0)
	_door_leaf(Vector3(-6.2, 1.05, -6.42), 0.0, -1.0)
	_door_leaf(Vector3(-12.42, 1.05, -3.05), 90.0, -1.0)
	_door_leaf(Vector3(-12.42, 1.05, 1.75), 90.0, -1.0)
	_door_leaf(Vector3(0.82, 1.05, -0.7), 90.0, 1.0)
	_door_leaf(Vector3(4.7, 1.05, 7.17), 0.0, 1.0)
	_door_leaf(Vector3(4.17, 1.05, -5.9), 90.0, 1.0)
	_add_label(Vector3(-4.7, 2.05, -5.35), "影壁", 20)

func _build_room_furnishings() -> void:
	var brick := Color(0.55, 0.34, 0.24)
	var grain := Color(0.72, 0.6, 0.32)
	var packed := Color(0.58, 0.47, 0.34)
	_add_box(Vector3(-6.2, 0.02, 7.75), Vector3(14.6, 0.04, 3.9), brick, "FloorNorth")
	_add_box(Vector3(-6.2, 0.02, -8.15), Vector3(14.6, 0.04, 3.0), packed, "FloorSouth")
	_add_box(Vector3(-14.15, 0.02, 0.2), Vector3(2.9, 0.04, 10.4), packed, "FloorWest")
	_add_box(Vector3(2.7, 0.02, 0.15), Vector3(3.6, 0.04, 3.8), packed, "FloorEast")
	_add_box(Vector3(4.7, 0.02, 8.6), Vector3(3.4, 0.04, 2.6), packed, "FloorMill")
	_add_box(Vector3(5.9, 0.02, -5.9), Vector3(3.2, 0.04, 2.8), packed, "FloorWood")
	_add_cyl(Vector3(5.5, 0.2, 9.15), 0.42, 0.36, Color(0.55, 0.52, 0.46), "MillRoomStone")
	_add_cyl(Vector3(3.55, 0.28, 9.2), 0.22, 0.5, Color(0.45, 0.48, 0.42), "MillJar")
	_add_box(Vector3(6.7, 0.4, -6.5), Vector3(1.2, 0.8, 0.9), WOOD, "WoodRoomPile")
	_add_cyl(Vector3(6.6, 0.28, -5.05), 0.2, 0.48, Color(0.45, 0.48, 0.42), "WoodJar")
	_add_box(Vector3(-11.2, 0.25, 9.22), Vector3(2.3, 0.5, 1.15), brick, "KangWest")
	_add_box(Vector3(-4.5, 0.25, 9.22), Vector3(2.3, 0.5, 1.15), brick, "KangEast")
	_add_label(Vector3(-11.2, 0.9, 9.22), "西炕", 20)
	_add_label(Vector3(-4.5, 0.9, 9.22), "东炕", 20)
	_add_box(Vector3(-6.2, 0.34, 8.32), Vector3(1.05, 0.68, 0.58), WOOD, "EightTable")
	_add_box(Vector3(-7.05, 0.21, 8.32), Vector3(0.32, 0.42, 0.7), WOOD, "BenchW")
	_add_box(Vector3(-5.35, 0.21, 8.32), Vector3(0.32, 0.42, 0.7), WOOD, "BenchE")
	_add_label(Vector3(-6.2, 1.15, 8.32), "饭桌", 18)
	_add_box(Vector3(-13.15, 0.75, 8.2), Vector3(0.55, 1.5, 0.7), WOOD, "WallCabinet")
	_add_label(Vector3(-13.15, 1.7, 8.2), "柜", 18)
	_add_cyl(Vector3(-12.2, 0.16, 8.15), 0.14, 0.28, Color(0.48, 0.42, 0.32), "KangJarW")
	_add_box(Vector3(-8.6, 0.16, 8.55), Vector3(0.42, 0.28, 0.28), WOOD, "NeedleBox")
	_add_box(Vector3(-11.2, 1.9, 5.82), Vector3(0.7, 0.38, 0.08), Color(0.25, 0.2, 0.14), "WindowN1")
	_add_box(Vector3(-3.6, 1.9, 5.82), Vector3(0.7, 0.38, 0.08), Color(0.25, 0.2, 0.14), "WindowN2")
	_add_box(Vector3(4.05, 0.26, 1.35), Vector3(1.2, 0.5, 1.2), brick, "EastKang")
	_add_box(Vector3(2.9, 0.05, 0.45), Vector3(0.95, 0.07, 0.72), WOOD, "KangBoard")
	_add_label(Vector3(2.9, 0.45, 0.95), "炕板 · 地道口", 18)
	_add_box(Vector3(4.15, 0.22, -1.35), Vector3(0.55, 0.42, 0.4), WOOD, "EastChest")
	_add_cyl(Vector3(4.2, 0.14, -0.55), 0.12, 0.22, Color(0.48, 0.42, 0.32), "EastJar")
	_add_box(Vector3(-14.9, 0.38, 0.55), Vector3(0.85, 0.75, 0.55), WOOD, "ChoppingBoard")
	_add_label(Vector3(-14.9, 1.05, 0.55), "案板", 18)
	_add_box(Vector3(-14.2, 0.48, 1.62), Vector3(0.35, 0.28, 0.5), WOOD, "Bellows")
	_add_label(Vector3(-14.2, 0.85, 1.62), "风箱", 16)
	_add_cyl(Vector3(-14.95, 0.32, -3.8), 0.3, 0.62, Color(0.45, 0.48, 0.42), "KitchenJar")
	_add_cyl(Vector3(-14.55, 0.18, -2.4), 0.16, 0.32, Color(0.48, 0.42, 0.32), "PickleJar")
	_add_cyl(Vector3(-14.95, 0.5, 4.65), 0.42, 1.0, grain, "KitchenBin")
	_add_label(Vector3(-14.95, 1.25, 4.65), "粮囤", 18)
	_add_box(Vector3(-6.4, 0.28, -7.15), Vector3(1.1, 0.52, 0.62), WOOD, "SouthTable")
	_add_box(Vector3(-7.2, 0.2, -7.15), Vector3(0.32, 0.4, 0.55), WOOD, "SouthBench")
	_add_cyl(Vector3(-10.2, 0.5, -9.0), 0.45, 1.0, grain, "SouthBinA")
	_add_cyl(Vector3(-3.2, 0.5, -9.0), 0.45, 1.0, grain, "SouthBinB")
	_add_box(Vector3(-13.25, 0.55, -8.15), Vector3(0.28, 1.05, 1.35), WOOD, "ToolRack")
	_add_label(Vector3(-13.15, 1.25, -8.15), "农具", 18)
	_add_box(Vector3(-9.4, 1.35, -9.7), Vector3(1.4, 0.08, 0.08), WOOD, "SouthPeg")
	# 院外邻院：最低限度陈设，避免空壳
	_add_box(Vector3(-22.4, 0.02, 0.4), Vector3(4.6, 0.04, 5.8), packed, "FloorBarn")
	_add_box(Vector3(-23.4, 0.45, 1.6), Vector3(1.4, 0.9, 0.8), WOOD, "BarnManger")
	_add_cyl(Vector3(-21.2, 0.4, -1.6), 0.35, 0.8, grain, "BarnBin")
	_add_box(Vector3(-23.6, 0.55, -0.8), Vector3(0.7, 1.1, 0.35), WOOD, "BarnRack")
	_add_box(Vector3(-6.2, 0.02, 14.8), Vector3(4.8, 0.04, 2.8), packed, "FloorCellar")
	_add_cyl(Vector3(-7.4, 0.35, 15.2), 0.28, 0.7, Color(0.45, 0.48, 0.42), "CellarJarA")
	_add_cyl(Vector3(-5.0, 0.35, 15.2), 0.28, 0.7, Color(0.45, 0.48, 0.42), "CellarJarB")
	_add_box(Vector3(-6.2, 0.35, 15.6), Vector3(1.2, 0.7, 0.55), WOOD, "CellarCrate")
	_add_box(Vector3(12.6, 0.02, -8.4), Vector3(4.0, 0.04, 3.4), packed, "FloorStable")
	_add_box(Vector3(13.5, 0.4, -9.3), Vector3(1.5, 0.8, 0.55), WOOD, "StableManger")
	_add_box(Vector3(11.6, 0.45, -7.5), Vector3(0.55, 0.9, 0.9), Color(0.5, 0.38, 0.2), "StableHay")
	_add_box(Vector3(12.8, 0.02, 8.8), Vector3(3.8, 0.04, 3.0), packed, "FloorStore")
	_add_cyl(Vector3(13.6, 0.55, 9.4), 0.4, 1.1, grain, "StoreBin")
	_add_box(Vector3(11.9, 0.45, 8.2), Vector3(0.9, 0.9, 0.7), WOOD, "StoreCrate")
	_add_box(Vector3(13.5, 0.55, 7.9), Vector3(0.5, 1.1, 0.35), WOOD, "StoreShelf")
	# 主屋角落再补几处，减少「空旷」感
	_add_box(Vector3(-8.8, 0.12, 6.85), Vector3(0.55, 0.2, 0.55), Color(0.5, 0.4, 0.28), "NorthMat")
	_add_box(Vector3(-2.4, 0.55, 8.9), Vector3(0.35, 1.05, 0.55), WOOD, "NorthShelf")
	_add_cyl(Vector3(-14.4, 0.2, -5.6), 0.18, 0.35, Color(0.48, 0.42, 0.32), "WestBasin")
	_add_box(Vector3(-5.0, 0.55, -8.7), Vector3(0.85, 1.05, 0.28), WOOD, "SouthShelf")

func _add_cyl(pos: Vector3, radius: float, height: float, color: Color, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh.mesh = cyl
	mesh.material_override = _mat(color)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _hide_mesh(body: Node) -> void:
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _plant_poplars() -> void:
	var mesh := _real_plant("res://assets/props/poplar.glb", 12.0, 12000, 0.04, 0.0)
	var mat: Material = null
	if mesh == null:
		mesh = _poplar_mesh()
		var wind := ShaderMaterial.new()
		wind.shader = load("res://assets/shaders/tree_wind.gdshader")
		mat = wind
	var spots: Array[Transform3D] = []
	var line_z := [-11.0, -9.0, -4.2, 3.4, 5.4, 9.6, 11.6]
	for z in line_z:
		spots.append(Transform3D(Basis.IDENTITY, Vector3(30.0, 0.0, z)))
		var far := Basis.IDENTITY.scaled(Vector3(0.72, 0.72, 0.72))
		spots.append(Transform3D(far, Vector3(50.0, 0.0, z)))
	for x in [-18.5, -16.2, -8.0, 4.0, 14.0]:
		var small := Basis.IDENTITY.scaled(Vector3(0.78, 0.78, 0.78))
		spots.append(Transform3D(small, Vector3(x, 0.0, 17.6)))
		spots.append(Transform3D(small, Vector3(x, 0.0, -17.6)))
	for z in [-14.0, -6.0, 0.0, 7.0, 14.0]:
		var far := Basis.IDENTITY.scaled(Vector3(0.9, 0.95, 0.9))
		spots.append(Transform3D(far, Vector3(78.0, 0.0, z)))
		spots.append(Transform3D(far, Vector3(104.0, 0.0, z + 3.0)))
	var broad := Basis.IDENTITY.scaled(Vector3(1.2, 0.58, 1.2))
	spots.append(Transform3D(broad, Vector3(18.8, 0.0, 5.4)))
	var slim := Basis.IDENTITY.scaled(Vector3(0.62, 0.82, 0.62))
	spots.append(Transform3D(slim, Vector3(18.4, 0.0, -5.2)))
	_paint_instances("PoplarLine", mesh, mat, spots, false)


func _poplar_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.38, 0.36, 0.30)
	var leaf := Color(0.36, 0.44, 0.26)
	_cone(st, 0.0, 11.2, 0.18, 0.04, bark, 6)
	for ring in 8:
		var y := 4.8 + float(ring) * 0.75
		var reach := 0.85 - float(ring) * 0.06
		for k in 6:
			var ang := float(k) / 6.0 * TAU + float(ring) * 0.4
			var base := Vector3(cos(ang) * 0.06, y, sin(ang) * 0.06)
			var tip := Vector3(cos(ang) * reach, y + 0.28, sin(ang) * reach)
			_leaf(st, base, tip, leaf)
	st.generate_normals()
	return st.commit()


func _cone(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, color: Color, sides: int, origin: Vector3 = Vector3.ZERO) -> void:
	var shift := Vector3(origin.x, 0.0, origin.z)
	for i in sides:
		var a0 := float(i) / float(sides) * TAU
		var a1 := float(i + 1) / float(sides) * TAU
		var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0) + shift
		var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0) + shift
		var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1) + shift
		var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1) + shift
		_tri(st, p00, p10, p11, color, 0.0, 0.4)
		_tri(st, p00, p11, p01, color, 0.0, 0.4)


func _branch(st: SurfaceTool, y: float, ang: float, length: float, color: Color) -> void:
	var dir := Vector3(cos(ang), 0.55, sin(ang)).normalized()
	var tip := Vector3(0, y, 0) + dir * length
	_cone(st, y, tip.y, 0.045, 0.02, Color(0.34, 0.30, 0.22), 4)
	for k in 4:
		var fan := ang + float(k) * 1.4
		var leaf := tip + Vector3(cos(fan), 0.15, sin(fan)) * 0.55
		_leaf(st, tip, leaf, color)


func _leaf(st: SurfaceTool, root: Vector3, tip: Vector3, color: Color) -> void:
	var side := (tip - root).cross(Vector3.UP).normalized() * 0.16
	if side.length_squared() < 0.001:
		side = Vector3(0.16, 0, 0)
	_tri(st, root, tip, root + side, color, 0.2, 1.0)
	_tri(st, root, root - side, tip, color, 0.2, 1.0)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, uv0: float, uv1: float) -> void:
	st.set_color(color)
	st.set_uv(Vector2(0.0, uv0))
	st.add_vertex(a)
	st.set_color(color)
	st.set_uv(Vector2(1.0, uv1))
	st.add_vertex(b)
	st.set_color(color)
	st.set_uv(Vector2(0.5, uv0))
	st.add_vertex(c)


func _build_grass() -> void:
	var grass := _real_plant("res://assets/props/grass_clump.glb", 0.36, 3200, 0.11, 0.15)
	var wheat := _real_plant("res://assets/props/wheat.glb", 0.9, 5000, 0.07, 0.04)
	var grass_mat: Material = null
	var wheat_mat: Material = null
	if grass == null:
		grass = _grass_clump()
		grass_mat = _flat_foliage(Color(0.34, 0.40, 0.22), Color(0.48, 0.50, 0.28), 0.09)
	if wheat == null:
		wheat = _wheat_clump()
		wheat_mat = _flat_foliage(Color(0.55, 0.48, 0.22), Color(0.78, 0.64, 0.28), 0.06)
	var wheat_spots: Array[Transform3D] = []
	_scatter_crop(wheat_spots, 30.0, 66.0, -16.0, 16.0, 0.72, 0.9, 1.08, 0.06, false, 1.2)
	_scatter_crop(wheat_spots, -24.0, 12.0, 15.6, 18.5, 0.72, 0.9, 1.08, 0.06, false, 1.15)
	_scatter_crop(wheat_spots, -24.0, 12.0, -18.5, -15.4, 0.72, 0.9, 1.08, 0.06, false, 1.15)
	_scatter_crop(wheat_spots, -23.2, -17.8, -12.0, 12.0, 0.72, 0.9, 1.08, 0.06, false, 1.15)
	_paint_instances("FieldWheat", wheat, wheat_mat, wheat_spots, false)
	var grass_spots: Array[Transform3D] = []
	_scatter_crop(grass_spots, -5.9, -3.3, 4.45, 5.25, 0.18, 0.8, 1.15, 0.12)
	_scatter_crop(grass_spots, 28.0, 66.0, -17.2, -15.6, 0.7, 0.85, 1.15, 0.06)
	_scatter_crop(grass_spots, 28.0, 66.0, 15.6, 17.2, 0.7, 0.85, 1.15, 0.06)
	_scatter_tufts(grass_spots)
	_paint_instances("LiveGrass", grass, grass_mat, grass_spots, false)


func _flat_foliage(base_color: Color, tip_color: Color, bend: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/foliage_wind.gdshader")
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("tip_color", tip_color)
	mat.set_shader_parameter("bend", bend)
	return mat


func _real_plant(path: String, height: float, target_tris: int, bend: float, sink: float) -> ArrayMesh:
	var cache_path := "%s_fieldmesh.res" % path.get_basename()
	if ResourceLoader.exists(cache_path):
		var cached := load(cache_path) as ArrayMesh
		if cached != null and int(cached.get_meta("plant_cache", 0)) == 7:
			return cached
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var mesh_node := _first_mesh_node(root)
	if mesh_node == null or mesh_node.mesh == null:
		root.free()
		return null
	var source := mesh_node.mesh
	var fitted := _simplify_mesh(source, target_tris, source.get_aabb(), height, sink)
	var mat := mesh_node.get_active_material(0)
	root.free()
	if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
		var wind := ShaderMaterial.new()
		wind.shader = load("res://assets/shaders/plant_wind.gdshader")
		wind.set_shader_parameter("albedo_tex", (mat as StandardMaterial3D).albedo_texture)
		wind.set_shader_parameter("bend", bend)
		wind.set_shader_parameter("height_ref", height)
		if (sink > 0.08):
			wind.set_shader_parameter("hide_pale", 1.0)
		fitted.surface_set_material(0, wind)
	elif mat != null:
		fitted.surface_set_material(0, mat)
	fitted.set_meta("plant_cache", 7)
	ResourceSaver.save(fitted, cache_path)
	var tris := int(fitted.surface_get_array_index_len(0) / 3)
	print("plant ", path.get_file(), " tris ", tris, " height ", height)
	return fitted


func _first_mesh_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh_node(child)
		if found != null:
			return found
	return null


func _simplify_mesh(mesh: Mesh, target_tris: int, src_aabb: AABB, height: float, sink: float) -> ArrayMesh:
	var original := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	var levels: Array[Dictionary] = []
	var working := original
	if not indices.is_empty() and int(indices.size() / 3) > target_tris:
		for _pass in 6:
			var tris_now := int((working[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
			var step := _coarser_step(working)
			if step.is_empty():
				break
			var next_tris := int(step["tris"])
			if next_tris >= tris_now - 8:
				break
			levels.append(step)
			working = _with_indices(original, step["indices"])
			if next_tris <= int(float(target_tris) * 0.55) and levels.size() >= 2:
				break
	var lod0 := 0
	for i in levels.size():
		if int(levels[i]["tris"]) >= int(float(target_tris) * 0.65):
			lod0 = i
	var lod0_indices: PackedInt32Array = indices if levels.is_empty() else levels[lod0]["indices"]
	var packed := _compact_arrays(original, lod0_indices)
	var scale := height / maxf(src_aabb.size.y, 0.001)
	var shift := Vector3(-src_aabb.get_center().x, -src_aabb.position.y, -src_aabb.get_center().z)
	var verts: PackedVector3Array = packed["arrays"][Mesh.ARRAY_VERTEX]
	var fitted := PackedVector3Array()
	fitted.resize(verts.size())
	for i in verts.size():
		var point := (verts[i] + shift) * scale
		point.y -= sink
		fitted[i] = point
	packed["arrays"][Mesh.ARRAY_VERTEX] = fitted
	var remap: PackedInt32Array = packed["remap"]
	var lods := {}
	for i in range(lod0 + 1, levels.size()):
		var edge := maxf(float(levels[i]["edge"]) * scale, 0.02)
		while lods.has(edge):
			edge += 0.001
		lods[edge] = _remap_indices(levels[i]["indices"], remap)
	var out := ArrayMesh.new()
	if lods.is_empty():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, packed["arrays"])
	else:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, packed["arrays"], [], lods)
	return out


func _with_indices(arrays: Array, indices: PackedInt32Array) -> Array:
	var next := arrays.duplicate()
	next[Mesh.ARRAY_INDEX] = indices
	return next


func _coarser_step(arrays: Array) -> Dictionary:
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var baked := importer.get_mesh()
	var info: Dictionary = RenderingServer.mesh_get_surface(baked.get_rid(), 0)
	var lods: Variant = info.get("lods", [])
	if not (lods is Array) or (lods as Array).is_empty():
		return {}
	var row: Dictionary = (lods as Array)[(lods as Array).size() - 1]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var coarser := _read_indices(row["index_data"], verts.size())
	if coarser.is_empty():
		return {}
	return {"indices": coarser, "edge": float(row["edge_length"]), "tris": int(coarser.size() / 3)}


func _remap_indices(indices: PackedInt32Array, remap: PackedInt32Array) -> PackedInt32Array:
	var clean := PackedInt32Array()
	var cursor := 0
	while cursor + 2 < indices.size():
		var a := remap[indices[cursor]]
		var b := remap[indices[cursor + 1]]
		var c := remap[indices[cursor + 2]]
		if a >= 0 and b >= 0 and c >= 0 and a != b and b != c and c != a:
			clean.append(a)
			clean.append(b)
			clean.append(c)
		cursor += 3
	return clean


func _read_indices(raw: PackedByteArray, vertex_count: int) -> PackedInt32Array:
	var use_wide := not _indices_fit(raw, 2, vertex_count) or vertex_count > 65535
	if use_wide and not _indices_fit(raw, 4, vertex_count):
		use_wide = false
	var stride := 4 if use_wide else 2
	if raw.size() < stride or raw.size() % stride != 0:
		return PackedInt32Array()
	var count := int(raw.size() / stride)
	var out := PackedInt32Array()
	out.resize(count)
	for i in count:
		out[i] = raw.decode_u32(i * 4) if use_wide else raw.decode_u16(i * 2)
	return out


func _indices_fit(raw: PackedByteArray, stride: int, vertex_count: int) -> bool:
	if stride <= 0 or raw.size() < stride or raw.size() % stride != 0:
		return false
	var count := mini(int(raw.size() / stride), 96)
	for i in count:
		var value := raw.decode_u32(i * 4) if stride == 4 else raw.decode_u16(i * 2)
		if value < 0 or value >= vertex_count:
			return false
	return true


func _compact_arrays(arrays: Array, indices: PackedInt32Array) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var has_normals := normals.size() == verts.size()
	var has_uvs := uvs.size() == verts.size()
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var new_verts := PackedVector3Array()
	var new_normals := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var new_indices := PackedInt32Array()
	new_indices.resize(indices.size())
	for i in indices.size():
		var old := indices[i]
		var id := remap[old]
		if id < 0:
			id = new_verts.size()
			remap[old] = id
			new_verts.append(verts[old])
			if has_normals:
				new_normals.append(normals[old])
			if has_uvs:
				new_uvs.append(uvs[old])
		new_indices[i] = id
	var next: Array = []
	next.resize(Mesh.ARRAY_MAX)
	next[Mesh.ARRAY_VERTEX] = new_verts
	next[Mesh.ARRAY_INDEX] = new_indices
	if has_normals:
		next[Mesh.ARRAY_NORMAL] = new_normals
	if has_uvs:
		next[Mesh.ARRAY_TEX_UV] = new_uvs
	return {"arrays": next, "remap": remap}


func _cluster_mesh(arrays: Array, cell: float) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var has_normals := normals.size() == verts.size()
	var has_uvs := uvs.size() == verts.size()
	var clusters := {}
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	var new_verts := PackedVector3Array()
	var new_normals := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var inv := 1.0 / maxf(cell, 0.0001)
	for i in verts.size():
		var point := verts[i]
		var key := Vector3i(int(floor(point.x * inv)), int(floor(point.y * inv)), int(floor(point.z * inv)))
		if clusters.has(key):
			remap[i] = int(clusters[key])
		else:
			var id := new_verts.size()
			clusters[key] = id
			remap[i] = id
			new_verts.append(point)
			if has_normals:
				new_normals.append(normals[i])
			if has_uvs:
				new_uvs.append(uvs[i])
	var new_indices := PackedInt32Array()
	var cursor := 0
	while cursor + 2 < indices.size():
		var a := remap[indices[cursor]]
		var b := remap[indices[cursor + 1]]
		var c := remap[indices[cursor + 2]]
		if a != b and b != c and c != a:
			new_indices.append(a)
			new_indices.append(b)
			new_indices.append(c)
		cursor += 3
	var next: Array = []
	next.resize(Mesh.ARRAY_MAX)
	next[Mesh.ARRAY_VERTEX] = new_verts
	next[Mesh.ARRAY_INDEX] = new_indices
	if has_normals:
		next[Mesh.ARRAY_NORMAL] = new_normals
	if has_uvs:
		next[Mesh.ARRAY_TEX_UV] = new_uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, next)
	return {"mesh": out, "tris": int(new_indices.size() / 3)}


func _fit_mesh(mesh: ArrayMesh, src_aabb: AABB, height: float) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var scale := height / maxf(src_aabb.size.y, 0.001)
	var shift := Vector3(-src_aabb.get_center().x, -src_aabb.position.y, -src_aabb.get_center().z)
	var fitted := PackedVector3Array()
	fitted.resize(verts.size())
	for i in verts.size():
		fitted[i] = (verts[i] + shift) * scale
	arrays[Mesh.ARRAY_VERTEX] = fitted
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.surface_get_material(0) != null:
		out.surface_set_material(0, mesh.surface_get_material(0))
	return out


func _paint_instances(node_name: String, mesh: Mesh, mat: Material, spots: Array[Transform3D], shadows: bool) -> void:
	if spots.is_empty() or mesh == null:
		return
	if spots.size() <= 420:
		_paint_chunk(node_name, mesh, mat, spots, shadows)
		return
	var buckets := {}
	for spot in spots:
		var key := Vector2i(int(floor(spot.origin.x / 16.0)), int(floor(spot.origin.z / 16.0)))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(spot)
	for key in buckets:
		var chunk: Array[Transform3D] = []
		for spot in buckets[key]:
			chunk.append(spot)
		_paint_chunk("%s_%s_%s" % [node_name, key.x, key.y], mesh, mat, chunk, shadows)


func _paint_chunk(node_name: String, mesh: Mesh, mat: Material, spots: Array[Transform3D], shadows: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, spots[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	if mat != null:
		node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _scatter_crop(spots: Array[Transform3D], x0: float, x1: float, z0: float, z1: float, step: float, scale_min: float, scale_max: float, ground_y: float, skip_occupied: bool = false, xz_stretch: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x0 * 17.0 + z0 * 31.0 + step * 100.0))
	var x := x0
	while x < x1:
		var z := z0
		while z < z1:
			if skip_occupied and (_under_roof(x, z) or _in_field(x, z) or _near_work(x, z)):
				z += step
				continue
			var yaw := rng.randf() * TAU
			var s := rng.randf_range(scale_min, scale_max)
			var lean := rng.randf_range(-0.08, 0.08)
			var basis := Basis(Vector3.UP, yaw).rotated(Vector3.RIGHT, lean).scaled(Vector3(s * xz_stretch, s, s * xz_stretch))
			spots.append(Transform3D(basis, Vector3(x + rng.randf_range(-0.08, 0.08), ground_y, z + rng.randf_range(-0.08, 0.08))))
			z += step
		x += step


func _in_field(x: float, z: float) -> bool:
	if x > 29.2 and x < 66.8 and z > -16.6 and z < 16.6:
		return true
	if x > -24.4 and x < 12.4 and z > 12.1 and z < 18.4:
		return true
	if x > -24.4 and x < 12.4 and z > -18.4 and z < -12.1:
		return true
	if x > -23.6 and x < -17.4 and z > -12.4 and z < 12.4:
		return true
	if x > -5.95 and x < -3.25 and z > 4.4 and z < 5.3:
		return true
	return false


func _grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(0.36, 0.42, 0.24)
	for i in 7:
		var ang := float(i) / 7.0 * TAU
		var h := 0.28 + float(i % 3) * 0.05
		_blade(st, ang, h, 0.018, 0.06, color)
	st.generate_normals()
	return st.commit()


func _wheat_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var straw := Color(0.62, 0.52, 0.24)
	var ear := Color(0.78, 0.62, 0.26)
	for i in 4:
		var ang := float(i) * 1.5
		var root := Vector3(cos(ang) * 0.04, 0.0, sin(ang) * 0.04)
		_cone(st, 0.0, 0.7, 0.016, 0.006, straw, 5, root)
		_ear(st, Vector3(root.x, 0.62, root.z), ear)
	st.generate_normals()
	return st.commit()


func _blade(st: SurfaceTool, ang: float, height: float, width: float, curl: float, color: Color) -> void:
	var seg := 5
	for i in seg:
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var p0 := _blade_point(ang, t0, height, width, curl)
		var p1 := _blade_point(ang, t1, height, width, curl)
		_tri(st, p0[0], p1[0], p1[1], color, t0, t1)
		_tri(st, p0[0], p1[1], p0[1], color, t0, t1)
		_tri(st, p0[2], p1[1], p1[0], color, t0, t1)
		_tri(st, p0[2], p0[1], p1[1], color, t0, t1)


func _blade_point(ang: float, t: float, height: float, width: float, curl: float) -> Array:
	var y := height * t
	var bend := sin(t * PI) * curl
	var w := width * (1.0 - t * 0.82)
	var forward := Vector3(cos(ang), 0, sin(ang))
	var side := Vector3(-sin(ang), 0, cos(ang))
	var mid := forward * bend + Vector3(0, y, 0)
	return [mid + side * w, mid - side * w + Vector3(0, -w * 0.35, 0), mid + forward * w * 0.35]


func _ear(st: SurfaceTool, root: Vector3, color: Color) -> void:
	for i in 6:
		var y := root.y + 0.7 + float(i) * 0.04
		var side := 0.018 if i % 2 == 0 else -0.018
		var a := root + Vector3(side, y - root.y, 0.0)
		var b := a + Vector3(side * 1.4, 0.03, 0.008)
		var c := a + Vector3(0.0, 0.012, -0.01)
		_tri(st, a, b, c, color, 0.7, 1.0)
		_tri(st, a, a + Vector3(0, 0.05, 0), b, color, 0.8, 1.0)


func _scatter_tufts(spots: Array[Transform3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1942
	var clusters := [
		Vector3(-7.6, 0.0, 0.6), Vector3(-5.2, 0.0, 2.4), Vector3(-6.9, 0.0, 2.8),
		Vector3(-4.8, 0.0, 0.9), Vector3(-8.1, 0.0, 1.9),
		Vector3(-12.1, 0.0, -4.6), Vector3(-11.6, 0.0, -1.2), Vector3(-12.3, 0.0, 3.4),
		Vector3(-9.2, 0.0, 5.05), Vector3(-4.1, 0.0, 5.1), Vector3(-1.2, 0.0, 5.15),
		Vector3(-10.4, 0.0, -6.05), Vector3(-5.5, 0.0, -6.1), Vector3(-2.2, 0.0, -6.0),
	]
	for at in clusters:
		if _under_roof(at.x, at.z) or _near_work(at.x, at.z):
			continue
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.55, 1.15)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.75, 1.2), s))
		spots.append(Transform3D(basis, Vector3(at.x + rng.randf_range(-0.15, 0.15), 0.0, at.z + rng.randf_range(-0.12, 0.12))))


func _scatter_grass(spots: Array[Transform3D], x0: float, x1: float, z0: float, z1: float) -> void:
	var x := x0
	while x < x1:
		var z := z0
		while z < z1:
			var yaw := randf() * TAU
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * randf_range(0.75, 1.15))
			var at := Vector3(x + randf_range(-0.2, 0.2), 0.16, z + randf_range(-0.2, 0.2))
			spots.append(Transform3D(basis, at))
			z += 0.92
		x += 0.92

func _under_roof(x: float, z: float) -> bool:
	if x > -14.05 and x < 1.65 and z > 5.35 and z < 9.95:
		return true
	if x > -14.05 and x < 1.65 and z > -9.95 and z < -6.35:
		return true
	if x > -15.95 and x < -12.35 and z > -5.45 and z < 5.85:
		return true
	if x > 0.45 and x < 4.95 and z > -2.2 and z < 2.5:
		return true
	return false


func _near_work(x: float, z: float) -> bool:
	if Vector2(x + 10.0, z + 3.6).length() < 1.15:
		return true
	if Vector2(x + 6.4, z - 1.55).length() < 0.7:
		return true
	if Vector2(x + 4.2, z + 4.2).length() < 1.35:
		return true
	if Vector2(x + 2.4, z + 3.15).length() < 1.05:
		return true
	return false


func _build_pebbles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 194208
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.16
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.96
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	var spots: Array[Transform3D] = []
	var colors: PackedColorArray = PackedColorArray()
	for i in 110:
		var x := rng.randf_range(-11.5, 8.8)
		var z := rng.randf_range(-5.9, 5.1)
		if _under_roof(x, z) or _near_work(x, z):
			continue
		_drop_stone(spots, colors, rng, x, z, rng.randf() < 0.14)
	for i in 70:
		var x := rng.randf_range(18.0, 62.0)
		var z := rng.randf_range(-15.0, 15.0)
		_drop_stone(spots, colors, rng, x, z, rng.randf() < 0.2)
	if spots.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = ball
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, spots[i])
		multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = "GroundStones"
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _drop_stone(spots: Array[Transform3D], colors: PackedColorArray, rng: RandomNumberGenerator, x: float, z: float, chunk: bool) -> void:
	var s := rng.randf_range(0.55, 1.35)
	if chunk:
		s = rng.randf_range(1.6, 2.4)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * 0.55, s * rng.randf_range(0.75, 1.2)))
	var sink := 0.08 * basis.y.length() * 0.62
	spots.append(Transform3D(basis, Vector3(x, sink, z)))
	var tone := rng.randf()
	colors.append(Color(0.42, 0.38, 0.32).lerp(Color(0.55, 0.5, 0.42), tone))


func _build_clouds() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/cloud_sheet.gdshader")
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(36.0, 16.0)
	var places := [
		[Vector3(8.0, 34.0, -6.0), 0.2, 0.008],
		[Vector3(28.0, 41.0, 8.0), 1.1, 0.006],
		[Vector3(-12.0, 37.0, 4.0), 2.4, 0.011],
	]
	for i in places.size():
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % i
		cloud.mesh = sheet
		var copy := mat.duplicate() as ShaderMaterial
		copy.set_shader_parameter("drift", places[i][2])
		cloud.material_override = copy
		cloud.position = places[i][0]
		cloud.rotation.y = places[i][1]
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -70, 0)
	sun.light_energy = 0.72
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.8
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky_day.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.68, 0.72, 0.74)
	e.ambient_light_energy = 0.58
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.76, 0.74, 0.66)
	e.fog_density = 0.02
	e.fog_depth_begin = 14.0
	e.fog_depth_end = 58.0
	e.fog_aerial_perspective = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.02
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.04
	e.adjustment_saturation = 0.96
	env.environment = e
	add_child(env)
	var lamp_i := 0
	var lamps: Array[Vector3] = []
	for x in range(-9, 10, 3):
		lamps.append(Vector3(x, TUNNEL_FLOOR + 1.15, 0.42))
	lamps.append(Vector3(-10.0, TUNNEL_FLOOR + 1.05, -2.4))
	lamps.append(Vector3(-6.2, TUNNEL_FLOOR + 1.15, 4.2))
	lamps.append(Vector3(4.2, TUNNEL_FLOOR + 1.1, 1.2))
	lamps.append(Vector3(8.2, TUNNEL_FLOOR + 1.15, -1.6))
	for p in lamps:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(1.0, 0.84, 0.64)
		light.light_energy = 1.15
		light.omni_range = 7.5
		light.set_script(load("res://scripts/world/lamp_flicker.gd"))
		add_child(light)
		var lamp := Node3D.new()
		lamp.name = "OilLamp%d" % lamp_i
		lamp_i += 1
		lamp.position = p + Vector3(0.22, -0.15, 0)
		var bowl := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.07
		mesh.bottom_radius = 0.05
		mesh.height = 0.08
		bowl.mesh = mesh
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.45, 0.28, 0.12)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.62, 0.28)
		glow.emission_energy_multiplier = 0.8
		bowl.material_override = glow
		lamp.add_child(bowl)
		add_child(lamp)

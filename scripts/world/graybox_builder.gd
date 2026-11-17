extends Node3D
class_name GrayboxBuilder
## 按俯视图：四面房子围院，院内树/钟/锅/井，东屋是地道出口。
## 再往东是没有门的实墙，墙外树洞是瞭望口。可走地道地面在 -3.8 米。

const GROUND := Color(0.62, 0.48, 0.3)
const HOUSE := Color(0.58, 0.32, 0.22)
const ROOF := Color(0.42, 0.24, 0.18)
const WALLC := Color(0.5, 0.46, 0.4)
const TUNNEL := Color(0.16, 0.11, 0.08)
const WOOD := Color(0.4, 0.26, 0.12)

const FLOOR_TOP := 0.0
const TUNNEL_FLOOR := -3.8
const TUNNEL_H := 1.6

const LOOKOUT := Vector3(15.2, 0, 0)
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

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m

func _add_box(pos: Vector3, size: Vector3, color: Color, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body

func _add_label(pos: Vector3, text: String, size: int = 40, color: Color = Color(1, 0.94, 0.78)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 8
	label.modulate = color
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _build_ground() -> void:
	# 地面铺满。地道口藏在树洞、水井、东屋、驴槽和北房。锅台是射击位，不在地上开可以掉进去的洞。
	for ix in range(-12, 35):
		for iz in range(-9, 10):
			var cx := ix * 2.0 + 1.0
			var cz := iz * 2.0
			_add_box(Vector3(cx, -0.12, cz), Vector3(2.0, 0.24, 2.0), GROUND, "G_%d_%d" % [ix, iz])

func _build_plain_edge() -> void:
	# 冀中平原：麦田、田埂、道边杨树。树列挡住空边界，人从树缝里走出来。
	var wheat := Color(0.73, 0.64, 0.32)
	var earth := Color(0.5, 0.4, 0.26)
	var trunk := Color(0.34, 0.28, 0.16)
	var leaf := Color(0.33, 0.46, 0.22)
	_add_box(Vector3(48.0, 0.03, 0.0), Vector3(36.0, 0.06, 34.0), wheat, "FieldEast")
	_add_box(Vector3(-6.0, 0.03, 15.2), Vector3(36.0, 0.06, 6.0), wheat, "FieldNorth")
	_add_box(Vector3(-6.0, 0.03, -15.2), Vector3(36.0, 0.06, 6.0), wheat, "FieldSouth")
	_add_box(Vector3(-20.5, 0.03, 0.0), Vector3(6.0, 0.06, 26.0), wheat, "FieldWest")
	_add_box(Vector3(66.2, 0.22, 0.0), Vector3(0.8, 0.44, 36.0), earth, "RidgeEast")
	_add_box(Vector3(6.0, 0.2, 17.6), Vector3(70.0, 0.4, 0.55), earth, "RidgeNorth")
	_add_box(Vector3(6.0, 0.2, -17.6), Vector3(70.0, 0.4, 0.55), earth, "RidgeSouth")
	_add_box(Vector3(-22.4, 0.2, 0.0), Vector3(0.55, 0.4, 36.0), earth, "RidgeWest")
	var line_z := [-11.0, -9.0, -4.2, 3.4, 5.4, 9.6, 11.6]
	for z in line_z:
		_add_box(Vector3(30.0, 2.1, z), Vector3(0.38, 4.2, 0.38), trunk, "Poplar%d" % int(z * 10.0))
		_add_box(Vector3(30.0, 4.3, z), Vector3(1.7, 1.5, 1.7), leaf, "PoplarTop%d" % int(z * 10.0))
		_add_box(Vector3(50.0, 1.5, z), Vector3(0.28, 3.0, 0.28), trunk, "FarPoplar%d" % int(z * 10.0))
		_add_box(Vector3(50.0, 3.1, z), Vector3(1.3, 1.1, 1.3), leaf, "FarTop%d" % int(z * 10.0))
	for x in [-18.5, -16.2, -8.0, 4.0, 14.0]:
		_add_box(Vector3(x, 1.6, 14.6), Vector3(0.32, 3.2, 0.32), trunk, "NorthTree%d" % int(x * 10.0))
		_add_box(Vector3(x, 3.4, 14.6), Vector3(1.5, 1.2, 1.5), leaf, "NorthTop%d" % int(x * 10.0))
		_add_box(Vector3(x, 1.6, -14.6), Vector3(0.32, 3.2, 0.32), trunk, "SouthTree%d" % int(x * 10.0))
		_add_box(Vector3(x, 3.4, -14.6), Vector3(1.5, 1.2, 1.5), leaf, "SouthTop%d" % int(x * 10.0))

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
	_shell("HouseWest", Vector3(-14.15, 0, 0.2), Vector2(3.5, 11.2), "e", [-2.2, 2.6], [["e", 3.85, 0.38]])
	_slit_plug(Vector3(-12.57, 0.0, 3.85), Vector3(0.34, 2.7, 0.38), 1.325, 1.565, "StoveSlit")
	_gun_port("StovePort", Vector3(-13.05, 1.05, 3.85), Vector3.RIGHT)
	_add_label(Vector3(-13.2, 1.7, 3.85), "锅台枪眼", 22)
	_add_label(Vector3(-14.15, 3.3, 0.2), "西房", 36)
	# 门槛枪眼开在门北侧的墙里，门洞照常走人。
	_shell("HouseEast", Vector3(2.7, 0, 0.15), Vector2(4.4, 4.6), "w", [0.15], [["w", 1.2, 0.38]])
	_slit_plug(Vector3(0.67, 0.0, 1.2), Vector3(0.34, 2.7, 0.38), 1.325, 1.565, "DoorSlit")
	_gun_port("ThresholdPort", Vector3(1.16, 1.05, 1.2), Vector3.LEFT)
	_add_label(Vector3(1.35, 1.65, 1.2), "门槛枪眼", 22)
	_add_label(Vector3(3.4, 2.2, 0.9), "东屋内 · 出", 40, Color(1, 0.85, 0.45))
	_build_room_furnishings()

func _build_courtyard_props() -> void:
	_add_box(Vector3(-6.4, 1.8, 2.3), Vector3(0.55, 3.6, 0.55), Color(0.32, 0.22, 0.12), "YardTrunk")
	_add_box(Vector3(-6.4, 3.8, 2.3), Vector3(2.6, 1.2, 2.6), Color(0.22, 0.4, 0.16), "YardCrown")
	_add_box(Vector3(-6.4, 2.3, 1.55), Vector3(0.7, 0.55, 0.7), Color(0.72, 0.55, 0.18), "Bell")
	_add_label(Vector3(-6.4, 4.8, 2.3), "院树 · 警报钟", 46, Color(1, 0.9, 0.4))
	var bell := Area3D.new()
	bell.name = "AlarmBell"
	bell.position = Vector3(-6.4, 1.6, 2.0)
	_hitbox(bell, Vector3(1.4, 2.2, 1.4))
	bell.set_script(load("res://scripts/mechanics/alarm_bell.gd"))
	add_child(bell)

	_add_box(Vector3(STOVE.x, 0.45, STOVE.z), Vector3(1.3, 0.9, 0.8), Color(0.45, 0.38, 0.32), "Stove")
	_add_label(STOVE + Vector3(0, 1.15, 0), "锅台", 28)

	_add_box(Vector3(WELL.x, 0.35, WELL.z + 1.15), Vector3(1.6, 0.55, 0.4), WALLC, "WellRing")
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
	_add_label(Vector3(10.2, 3.3, 0), "实墙 · 枪缝朝东", 36)
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
	_add_label(Vector3(18.5, 2.2, 0), "敌军来路 · 向西进村", 40, Color(1, 0.7, 0.45))
	var look_spawn := Marker3D.new()
	look_spawn.position = LOOKOUT + Vector3(0, 0.2, 0)
	look_spawn.add_to_group("lookout_spawn")
	add_child(look_spawn)
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
	_corridor_x(-9.25, -6.4, 0.0)
	_corridor_x(-6.3, -5.6, 0.15)
	_corridor_x_open_south(-5.6, -4.25, 0.15)
	_corridor_x(-3.3, 1.7, 0.15)
	_spine_firing_room()
	_corridor_x(3.5, 3.65, 0.0)
	_corridor_x_open_north(3.65, 4.85, 0.0)
	_corridor_x(4.85, 6.65, 0.0)
	_corridor_x(7.75, 8.05, 0.0)
	_hatch_gap()
	_corridor_x(9.0, 19.2, 0.0)
	_end_wall_x(19.35, 0.0)
	_corridor_z(2.6, -7.2, -3.15)
	_hub(Vector3(2.6, 0, -2.4), ["north", "south", "west"], ["west"])
	_corridor_z(2.6, -1.55, -0.7)
	_end_wall_z(2.6, -7.35)
	_room(Vector3(0.15, TUNNEL_FLOOR, -2.6), Vector3(2.8, TUNNEL_H, 2.55), "MaskRoom", &"east")
	_room(Vector3(2.25, TUNNEL_FLOOR, 2.45), Vector3(2.6, TUNNEL_H, 2.4), "SideNiche", &"north")
	_conceal_side_ports()
	_corridor_z(8.2, -1.4, -0.8)
	_corridor_z(-10.0, -3.45, -0.8)
	_junction(-10.0, -4.2)
	_corridor_z(-10.0, -7.2, -4.95)
	_end_wall_z(-10.0, -7.35)
	_corridor_x(-9.25, -3.5, -4.2)
	_end_wall_x(-3.4, -4.2)
	_corridor_z(-6.2, 0.9, 3.35)
	_corridor_z_open_west(-6.2, 3.35, 4.55)
	_corridor_z(-6.2, 4.55, 6.7)
	_room(Vector3(-6.2, TUNNEL_FLOOR, 7.5), Vector3(2.6, TUNNEL_H, 2.2), "VillagerRoom", &"north")
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

	var barrier := StaticBody3D.new()
	barrier.name = "WaterBarrier"
	barrier.position = Vector3(-10.0, TUNNEL_FLOOR + 1.48, -1.8)
	var bmesh := MeshInstance3D.new()
	bmesh.name = "Visual"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.05, 1.28, 0.1)
	bmesh.mesh = bm
	bmesh.position = Vector3(0, -0.64, 0)
	bmesh.material_override = _mat(WOOD)
	barrier.add_child(bmesh)
	var bcol := CollisionShape3D.new()
	bcol.name = "CollisionShape3D"
	var bsh := BoxShape3D.new()
	bsh.size = bm.size
	bcol.shape = bsh
	bcol.position = bmesh.position
	barrier.add_child(bcol)
	barrier.set_script(load("res://scripts/mechanics/water_barrier.gd"))
	add_child(barrier)
	_add_label(Vector3(-10.0, TUNNEL_FLOOR + 1.5, -1.8), "挡水隔板", 30)
	var bpost := Marker3D.new()
	bpost.position = Vector3(WELL.x + 1.4, 0.2, WELL.z)
	bpost.add_to_group("ally_barrier_post")
	add_child(bpost)
	var well_m := Marker3D.new()
	well_m.position = WELL + Vector3(0, 0.4, 0)
	well_m.add_to_group("well")
	add_child(well_m)

	var trap := Area3D.new()
	trap.name = "FlipTrap"
	trap.position = Vector3(TROUGH.x, TUNNEL_FLOOR + 0.4, TROUGH.z)
	var tcol := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(1.6, 1.2, 1.5)
	tcol.shape = tshape
	trap.add_child(tcol)
	var tvis := MeshInstance3D.new()
	tvis.name = "Visual"
	var tmesh := BoxMesh.new()
	tmesh.size = Vector3(0.28, 0.08, 1.2)
	tvis.mesh = tmesh
	tvis.material_override = _mat(WOOD)
	trap.add_child(tvis)
	trap.set_script(load("res://scripts/mechanics/flip_trap.gd"))
	trap.monitoring = true
	trap.collision_mask = 2 | 4 | 8
	add_child(trap)
	_add_label(Vector3(TROUGH.x, TUNNEL_FLOOR + 1.3, TROUGH.z), "翻板 · 先抽棍", 28)

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
	_add_label(Vector3(10.5, TUNNEL_FLOOR + 1.35, 0), "向西 · 回东屋", 32, Color(1, 0.9, 0.6))
	var stain := Node3D.new()
	stain.name = "WaterStain"
	stain.set_script(load("res://scripts/mechanics/water_stain.gd"))
	add_child(stain)

	var zone := Area3D.new()
	zone.position = Vector3(3.0, -2.15, -1.0)
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(36.0, 4.1, 18.0)
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

func _hatch_gap() -> void:
	var x := 7.2
	var z := 0.0
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	var ceil_y := TUNNEL_FLOOR + TUNNEL_H + 0.1
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, z), Vector3(1.05, 0.2, 1.65), TUNNEL, "HatchFloor")
	_add_box(Vector3(x, mid_y, z - 0.66), Vector3(1.05, TUNNEL_H, 0.22), TUNNEL, "HatchWallS")
	_add_box(Vector3(x, mid_y, z + 0.66), Vector3(1.05, TUNNEL_H, 0.22), TUNNEL, "HatchWallN")
	# 顶上只留一个能落下的口，周围仍是顶板。
	_add_box(Vector3(x, ceil_y, -0.54), Vector3(1.3, 0.2, 0.58), Color(0.1, 0.07, 0.05), "HatchCeilS")
	_add_box(Vector3(x, ceil_y, 0.78), Vector3(1.3, 0.2, 0.16), Color(0.1, 0.07, 0.05), "HatchCeilN")
	_add_box(Vector3(6.62, ceil_y, 0.22), Vector3(0.22, 0.2, 0.96), Color(0.1, 0.07, 0.05), "HatchCeilW")
	_add_box(Vector3(7.78, ceil_y, 0.22), Vector3(0.22, 0.2, 0.96), Color(0.1, 0.07, 0.05), "HatchCeilE")

func _spine_firing_room() -> void:
	_add_box(Vector3(-4.0, TUNNEL_FLOOR - 0.1, 0.15), Vector3(1.45, 0.2, 1.65), TUNNEL, "PortGapFloor")
	_add_box(Vector3(-4.0, TUNNEL_FLOOR + TUNNEL_H + 0.1, 0.15), Vector3(1.45, 0.2, 1.65), Color(0.1, 0.07, 0.05), "PortGapCeil")
	_add_box(Vector3(-4.0, TUNNEL_FLOOR + TUNNEL_H * 0.5, 0.15 + 0.66), Vector3(1.45, TUNNEL_H, 0.22), TUNNEL, "PortGapNorth")
	_room(Vector3(-4.45, TUNNEL_FLOOR, -1.55), Vector3(2.9, TUNNEL_H, 1.9), "SpinePortRoom", &"south")
	# 朝直道的一面是墙，只留窄缝。人从西边的侧口绕进去。
	_wall_with_slit(Vector3(-3.55, TUNNEL_FLOOR + TUNNEL_H * 0.5, -0.56), Vector3(0.95, TUNNEL_H, 0.16), Vector3(-3.55, TUNNEL_FLOOR + 0.935, -0.56), Vector3(0.26, 0.22, 0.22), "SpineSlit")
	_add_box(Vector3(-4.45, TUNNEL_FLOOR + TUNNEL_H * 0.5, -1.05), Vector3(0.14, TUNNEL_H, 0.7), TUNNEL, "SpineBaffle")
	_gun_port("SpinePort", Vector3(-3.55, TUNNEL_FLOOR + 0.9, -0.96), Vector3(0, 0, 1))
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
	_add_box(Vector3(7.7, -0.42, 2.25), Vector3(2.1, 0.14, 1.9), Color(0.1, 0.07, 0.05), "LoftCeil")
	_add_box(Vector3(8.6, -1.1, 2.25), Vector3(0.14, 1.3, 1.7), TUNNEL, "LoftWallE")
	_add_box(Vector3(7.7, -1.1, 3.05), Vector3(1.9, 1.3, 0.12), TUNNEL, "LoftWallN")
	_add_box(Vector3(7.2, floor_y - 0.08, 1.2), Vector3(1.15, 0.16, 1.9), TUNNEL, "LoftNeck")
	_add_box(Vector3(4.25, TUNNEL_FLOOR - 0.08, 1.2), Vector3(1.3, 0.16, 1.8), TUNNEL, "SideMouthFloor")
	_add_box(Vector3(4.25, TUNNEL_FLOOR + TUNNEL_H + 0.08, 1.2), Vector3(1.4, 0.14, 1.8), Color(0.1, 0.07, 0.05), "SideMouthCeil")
	_add_box(Vector3(3.58, TUNNEL_FLOOR + TUNNEL_H * 0.5, 1.15), Vector3(0.14, TUNNEL_H, 1.5), TUNNEL, "SideMouthW")
	_add_box(Vector3(4.92, TUNNEL_FLOOR + TUNNEL_H * 0.5, 1.15), Vector3(0.14, TUNNEL_H, 1.5), TUNNEL, "SideMouthE")
	_add_box(Vector3(4.0, TUNNEL_FLOOR + TUNNEL_H * 0.5, 2.08), Vector3(1.05, TUNNEL_H, 0.14), TUNNEL, "SideMouthN")
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
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, z), Vector3(1.8, 0.2, 1.7), TUNNEL, "JxF")
	_add_box(Vector3(x, TUNNEL_FLOOR + TUNNEL_H + 0.1, z), Vector3(1.9, 0.2, 1.8), Color(0.1, 0.07, 0.05), "JxC")
	_add_box(Vector3(x - 0.72, mid_y, z), Vector3(0.2, TUNNEL_H, 1.55), TUNNEL, "JxW")

func _build_trip_wire() -> void:
	_room(Vector3(-7.55, TUNNEL_FLOOR, 3.95), Vector3(1.7, TUNNEL_H, 1.6), "MineNook", &"east")
	_add_box(Vector3(-6.2, TUNNEL_FLOOR + 0.06, 4.15), Vector3(0.7, 0.12, 0.7), Color(0.32, 0.26, 0.16), "MineMound")
	_add_box(Vector3(-6.85, TUNNEL_FLOOR + 0.12, 3.95), Vector3(1.2, 0.03, 0.04), Color(0.55, 0.48, 0.3), "MineCord")
	var wire := Area3D.new()
	wire.name = "TripWire"
	wire.position = Vector3(-7.35, TUNNEL_FLOOR + 0.7, 3.95)
	var spool := MeshInstance3D.new()
	var spool_mesh := CylinderMesh.new()
	spool_mesh.top_radius = 0.08
	spool_mesh.bottom_radius = 0.08
	spool_mesh.height = 0.22
	spool.mesh = spool_mesh
	spool.rotation_degrees = Vector3(0, 0, 90)
	spool.material_override = _mat(WOOD)
	wire.add_child(spool)
	var blast := Area3D.new()
	blast.name = "Blast"
	blast.position = Vector3(1.15, -0.15, 0.2)
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.1, 1.15, 0.7)
	bcol.shape = bshape
	blast.add_child(bcol)
	blast.monitoring = true
	blast.collision_mask = 4
	wire.add_child(blast)
	wire.set_script(load("res://scripts/mechanics/trip_wire.gd"))
	wire.monitoring = true
	wire.collision_mask = 2
	add_child(wire)
	_add_label(Vector3(-7.35, TUNNEL_FLOOR + 1.25, 3.95), "拉雷线轴", 20)

func _gun_port(node_name: String, pos: Vector3, aim: Vector3) -> void:
	var port := Area3D.new()
	port.name = node_name
	port.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.2, 0.9)
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
	_add_box(Vector3(x, floor_y + h + 0.08, cz), Vector3(1.7, 0.16, length), Color(0.1, 0.07, 0.05), "DrainCeil")
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

func _build_flip_mouth() -> void:
	var mouth := Node3D.new()
	mouth.name = "FlipMouthEast"
	mouth.set_script(load("res://scripts/mechanics/flip_mouth.gd"))
	mouth.set("report_dead_end", true)
	mouth.add_child(_board("BoardClosed", Vector3(2.6, TUNNEL_FLOOR + 0.8, -0.95), Vector3(1.15, 1.45, 0.16)))
	mouth.add_child(_board("BoardAlt", Vector3(3.55, TUNNEL_FLOOR + 0.8, 0.15), Vector3(0.16, 1.45, 1.15)))
	add_child(mouth)
	_add_label(Vector3(2.6, TUNNEL_FLOOR + 1.45, -1.3), "翻口 · 默认挡死道", 26)

func _build_seal_door() -> void:
	var seal := Node3D.new()
	seal.name = "VillagerSeal"
	seal.set_script(load("res://scripts/mechanics/flip_mouth.gd"))
	seal.set("hint_closed", "E 打开翻眼（村民暗室的门）")
	seal.set("hint_open", "E 关上翻眼")
	seal.add_child(_board("BoardClosed", Vector3(-6.2, TUNNEL_FLOOR + 0.8, 1.15), Vector3(1.15, 1.45, 0.16)))
	add_child(seal)
	_add_label(Vector3(-6.2, TUNNEL_FLOOR + 1.45, 1.7), "翻眼 · 暗室", 26)

func _hub(c: Vector3, opens: PackedStringArray, wide: Array = []) -> void:
	var span := 2.0
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	var tag := "%d_%d" % [int(c.x * 10.0), int(c.z * 10.0)]
	_add_box(Vector3(c.x, TUNNEL_FLOOR - 0.1, c.z), Vector3(span, 0.2, span), TUNNEL, "HubF" + tag)
	_add_box(Vector3(c.x, TUNNEL_FLOOR + TUNNEL_H + 0.1, c.z), Vector3(span, 0.2, span), Color(0.1, 0.07, 0.05), "HubC" + tag)
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
	# 树身封闭。只能从地道上来，朝东一条眼高的窄缝。
	_add_box(Vector3(c.x, 1.35, c.z - 0.73), Vector3(1.7, 2.7, 0.22), wood, "TreeWallS")
	_add_box(Vector3(c.x, 1.35, c.z + 0.73), Vector3(1.7, 2.7, 0.22), wood, "TreeWallN")
	_add_box(Vector3(c.x - 0.73, 1.35, c.z), Vector3(0.22, 2.7, 1.24), wood, "TreeWallW")
	_add_box(Vector3(c.x + 0.73, 0.662, c.z), Vector3(0.22, 1.325, 1.24), wood, "TreeWallELow")
	_add_box(Vector3(c.x + 0.73, 2.13, c.z), Vector3(0.22, 1.14, 1.24), wood, "TreeWallEHigh")
	_add_box(Vector3(c.x + 0.73, 1.445, c.z - 0.39), Vector3(0.22, 0.24, 0.46), wood, "TreeSlitS")
	_add_box(Vector3(c.x + 0.73, 1.445, c.z + 0.39), Vector3(0.22, 0.24, 0.46), wood, "TreeSlitN")
	_add_box(Vector3(c.x, 2.85, c.z), Vector3(1.8, 0.28, 1.8), wood, "TreeCap")
	_add_box(Vector3(c.x, 4.05, c.z), Vector3(2.8, 1.2, 2.8), Color(0.2, 0.4, 0.16), "LookoutCrown")
	_add_box(Vector3(c.x - 0.2, 0.18, c.z - 0.85), Vector3(0.7, 0.36, 0.35), wood, "TreeRootS")
	_add_box(Vector3(c.x - 0.2, 0.18, c.z + 0.85), Vector3(0.7, 0.36, 0.35), wood, "TreeRootN")
	_gun_port("LookoutPort", c + Vector3(0, 1.05, 0), Vector3.RIGHT)

func _corridor_x_open_south(x0: float, x1: float, z: float) -> void:
	# 去掉较小 Z 一侧的墙。北墙保留。
	_corridor_x_partial(x0, x1, z, true, false)

func _corridor_x_open_north(x0: float, x1: float, z: float) -> void:
	# 去掉较大 Z 一侧的墙。南墙保留。
	_corridor_x_partial(x0, x1, z, false, true)

func _corridor_x_partial(x0: float, x1: float, z: float, north_wall: bool, south_wall: bool) -> void:
	var length := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(cx, TUNNEL_FLOOR - 0.1, z), Vector3(length, 0.2, w + 0.45), TUNNEL, "OFx%s" % cx)
	_add_box(Vector3(cx, TUNNEL_FLOOR + TUNNEL_H + 0.1, z), Vector3(length, 0.2, w + 0.6), Color(0.1, 0.07, 0.05), "OCx%s" % cx)
	if south_wall:
		_add_box(Vector3(cx, mid_y, z - w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "OSx%s" % cx)
	if north_wall:
		_add_box(Vector3(cx, mid_y, z + w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "ONx%s" % cx)

func _corridor_z_open_west(x: float, z0: float, z1: float) -> void:
	var length := absf(z1 - z0)
	var cz := (z0 + z1) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, cz), Vector3(w + 0.45, 0.2, length), TUNNEL, "OFz%s" % cz)
	_add_box(Vector3(x, TUNNEL_FLOOR + TUNNEL_H + 0.1, cz), Vector3(w + 0.6, 0.2, length), Color(0.1, 0.07, 0.05), "OCz%s" % cz)
	_add_box(Vector3(x + w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "OEz%s" % cz)

func _corridor_x(x0: float, x1: float, z: float) -> void:
	var length := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(cx, TUNNEL_FLOOR - 0.1, z), Vector3(length, 0.2, w + 0.45), TUNNEL, "CFx%s%s" % [x0, z])
	_add_box(Vector3(cx, TUNNEL_FLOOR + TUNNEL_H + 0.1, z), Vector3(length, 0.2, w + 0.6), Color(0.1, 0.07, 0.05), "CCx%s%s" % [x0, z])
	_add_box(Vector3(cx, mid_y, z - w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "CLx%s%s" % [x0, z])
	_add_box(Vector3(cx, mid_y, z + w * 0.55), Vector3(length, TUNNEL_H, 0.22), TUNNEL, "CRx%s%s" % [x0, z])

func _corridor_z(x: float, z0: float, z1: float) -> void:
	var length := absf(z1 - z0)
	var cz := (z0 + z1) * 0.5
	var w := 1.2
	var mid_y := TUNNEL_FLOOR + TUNNEL_H * 0.5
	_add_box(Vector3(x, TUNNEL_FLOOR - 0.1, cz), Vector3(w + 0.45, 0.2, length), TUNNEL, "CFz%s" % z0)
	_add_box(Vector3(x, TUNNEL_FLOOR + TUNNEL_H + 0.1, cz), Vector3(w + 0.6, 0.2, length), Color(0.1, 0.07, 0.05), "CCz%s" % z0)
	_add_box(Vector3(x - w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "CLz%s" % z0)
	_add_box(Vector3(x + w * 0.55, mid_y, cz), Vector3(0.22, TUNNEL_H, length), TUNNEL, "CRz%s" % z0)

func _room(floor_center: Vector3, size: Vector3, node_name: String, open_side: StringName) -> void:
	var mid_y := TUNNEL_FLOOR + size.y * 0.5
	_add_box(Vector3(floor_center.x, TUNNEL_FLOOR - 0.1, floor_center.z), Vector3(size.x, 0.2, size.z), TUNNEL, node_name + "F")
	_add_box(Vector3(floor_center.x, TUNNEL_FLOOR + size.y + 0.1, floor_center.z), Vector3(size.x, 0.2, size.z), Color(0.1, 0.07, 0.05), node_name + "C")
	if open_side != &"north":
		_add_box(Vector3(floor_center.x, mid_y, floor_center.z - size.z * 0.5), Vector3(size.x, size.y, 0.18), TUNNEL, node_name + "N")
	if open_side != &"south":
		_add_box(Vector3(floor_center.x, mid_y, floor_center.z + size.z * 0.5), Vector3(size.x, size.y, 0.18), TUNNEL, node_name + "S")
	if open_side != &"west":
		_add_box(Vector3(floor_center.x - size.x * 0.5, mid_y, floor_center.z), Vector3(0.18, size.y, size.z), TUNNEL, node_name + "W")
	if open_side != &"east":
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
	_add_label(down_mark.position + Vector3(0, 1.25, 0), "上去", 22)
	var sp := Marker3D.new()
	sp.position = up_mark.position
	sp.add_to_group("search_points")
	add_child(sp)

func _dress_mouth(ent: Node, id: StringName, hole: Vector3) -> void:
	match id:
		&"lookout":
			ent.set("hint_text", "E 从树洞下去")
		&"east_house":
			ent.set("hint_text", "E 掀开炕板下去")
			_lid(ent, Vector3(0.2, -0.72, 0.15), Vector3(0.85, 0.07, 0.62), Vector3(0.75, 0, 0), Vector3.ZERO)
		&"well":
			ent.set("hint_text", "E 拨开井壁的石板")
			_lid(ent, Vector3(0.55, -0.35, 0.15), Vector3(0.12, 0.7, 0.55), Vector3.ZERO, Vector3(0, 0, -70))
		&"trough":
			ent.set("hint_text", "E 抽开槽底板")
			_lid(ent, Vector3(0, -0.55, 0.15), Vector3(0.7, 0.06, 0.45), Vector3(0.6, 0, 0), Vector3.ZERO)
		&"north_house":
			ent.set("hint_text", "E 推开夹壁下去")
			_lid(ent, Vector3(0.15, -0.15, 0.35), Vector3(0.7, 1.1, 0.08), Vector3.ZERO, Vector3(0, 75, 0))

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
	_wall_with_slit(Vector3(1.52, mid_y, -2.84), Vector3(0.16, TUNNEL_H, 0.84), Vector3(1.52, eye_y, -2.84), Vector3(0.22, 0.22, 0.26), "DeadSlit")
	_add_box(Vector3(0.55, mid_y, -2.5), Vector3(0.9, TUNNEL_H, 0.14), TUNNEL, "DeadBaffle")
	_gun_port("DeadEndPort", Vector3(1.12, TUNNEL_FLOOR + 0.9, -2.84), Vector3.RIGHT)
	_add_label(Vector3(0.5, TUNNEL_FLOOR + 1.25, -3.05), "死道枪眼", 20)
	_wall_with_slit(Vector3(2.15, mid_y, 1.22), Vector3(0.85, TUNNEL_H, 0.16), Vector3(2.15, eye_y, 1.22), Vector3(0.26, 0.22, 0.22), "NicheSlit")
	_add_box(Vector3(2.42, mid_y, 1.9), Vector3(0.14, TUNNEL_H, 0.85), TUNNEL, "NicheBaffle")
	_gun_port("NichePort", Vector3(2.15, TUNNEL_FLOOR + 0.9, 1.58), Vector3(0, 0, -1))
	_add_label(Vector3(1.85, TUNNEL_FLOOR + 1.25, 2.15), "侧龛枪眼", 20)

func _wall_with_slit(center: Vector3, full: Vector3, slit_center: Vector3, slit_size: Vector3, tag: String) -> void:
	var a := center - full * 0.5
	var b := center + full * 0.5
	var s0 := slit_center - slit_size * 0.5
	var s1 := slit_center + slit_size * 0.5
	_span_box(Vector3(a.x, a.y, a.z), Vector3(b.x, s0.y, b.z), tag + "Lo")
	_span_box(Vector3(a.x, s1.y, a.z), Vector3(b.x, b.y, b.z), tag + "Hi")
	if full.z <= full.x and full.z <= full.y:
		_span_box(Vector3(a.x, s0.y, a.z), Vector3(s0.x, s1.y, b.z), tag + "L")
		_span_box(Vector3(s1.x, s0.y, a.z), Vector3(b.x, s1.y, b.z), tag + "R")
	else:
		_span_box(Vector3(a.x, s0.y, a.z), Vector3(b.x, s1.y, s0.z), tag + "L")
		_span_box(Vector3(a.x, s0.y, s1.z), Vector3(b.x, s1.y, b.z), tag + "R")

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
	_add_cyl(Vector3(-1.6, 0.16, -2.8), 0.82, 0.28, stone, "Millstone")
	_add_cyl(Vector3(-1.6, 0.42, -2.35), 0.18, 0.7, stone, "MillRoller")
	_add_label(Vector3(-1.6, 1.15, -2.8), "碾子", 22)
	_add_cyl(Vector3(-8.7, 0.18, -5.5), 0.42, 0.32, stone, "Quern")
	_add_label(Vector3(-8.7, 0.8, -5.5), "磨", 22)
	_add_cyl(Vector3(-8.55, 0.35, -2.75), 0.32, 0.7, clay, "JarA")
	_add_cyl(Vector3(-11.25, 0.35, -2.55), 0.32, 0.7, clay, "JarB")
	_add_label(Vector3(-8.55, 1.05, -2.75), "水缸", 20)
	_add_box(Vector3(-10.9, 0.7, -3.6), Vector3(0.12, 1.4, 0.12), WOOD, "WellPostW")
	_add_box(Vector3(-9.1, 0.7, -3.6), Vector3(0.12, 1.4, 0.12), WOOD, "WellPostE")
	_add_box(Vector3(-10.0, 1.35, -3.6), Vector3(1.9, 0.1, 0.1), WOOD, "WellBeam")
	_add_label(Vector3(-10.0, 1.7, -3.15), "辘轳", 20)
	_add_box(Vector3(1.5, 0.4, -5.15), Vector3(1.5, 0.8, 1.0), Color(0.5, 0.38, 0.2), "Woodpile")
	_add_label(Vector3(1.5, 1.15, -5.15), "柴垛", 20)
	_add_box(Vector3(-2.55, 0.55, -4.85), Vector3(0.14, 1.1, 0.14), WOOD, "HitchPost")
	_add_box(Vector3(-4.6, 0.08, 4.7), Vector3(2.0, 0.14, 0.75), Color(0.34, 0.46, 0.22), "VegetableBed")
	_add_label(Vector3(-4.6, 0.45, 4.7), "菜畦", 18)
	_add_box(Vector3(-4.7, 0.95, -5.35), Vector3(1.35, 1.8, 0.16), WALLC, "ScreenWall")
	_add_label(Vector3(-4.7, 2.05, -5.35), "影壁", 20)

func _build_room_furnishings() -> void:
	var brick := Color(0.55, 0.34, 0.24)
	var grain := Color(0.72, 0.6, 0.32)
	_add_box(Vector3(-11.4, 0.28, 8.95), Vector3(2.3, 0.5, 1.15), brick, "KangWest")
	_add_box(Vector3(-4.0, 0.28, 8.95), Vector3(2.3, 0.5, 1.15), brick, "KangEast")
	_add_label(Vector3(-11.4, 0.85, 8.95), "炕", 20)
	_add_box(Vector3(-6.2, 0.36, 8.75), Vector3(1.05, 0.68, 0.58), WOOD, "EightTable")
	_add_box(Vector3(-6.85, 0.22, 8.15), Vector3(0.7, 0.42, 0.28), WOOD, "BenchW")
	_add_box(Vector3(-5.55, 0.22, 8.15), Vector3(0.7, 0.42, 0.28), WOOD, "BenchE")
	_add_label(Vector3(-6.2, 1.05, 8.75), "饭桌", 18)
	_add_box(Vector3(-7.55, 0.8, 7.45), Vector3(0.6, 1.5, 0.75), WOOD, "WallCabinet")
	_add_label(Vector3(-7.55, 1.7, 7.45), "柜", 18)
	_add_box(Vector3(-11.2, 1.9, 5.82), Vector3(0.7, 0.38, 0.08), Color(0.25, 0.2, 0.14), "WindowN1")
	_add_box(Vector3(-3.6, 1.9, 5.82), Vector3(0.7, 0.38, 0.08), Color(0.25, 0.2, 0.14), "WindowN2")
	_add_box(Vector3(3.9, 0.26, 0.9), Vector3(1.15, 0.48, 1.7), brick, "EastKang")
	_add_label(Vector3(3.9, 0.8, 0.9), "炕", 20)
	_add_box(Vector3(3.85, 0.26, -1.4), Vector3(0.6, 0.45, 0.4), WOOD, "EastChest")
	_add_box(Vector3(-14.55, 0.4, -0.15), Vector3(1.05, 0.75, 0.55), WOOD, "ChoppingBoard")
	_add_label(Vector3(-14.55, 1.05, -0.15), "案板", 18)
	_add_box(Vector3(-14.45, 0.22, 1.55), Vector3(0.35, 0.28, 0.5), WOOD, "Bellows")
	_add_label(Vector3(-14.45, 0.6, 1.55), "风箱", 16)
	_add_cyl(Vector3(-14.7, 0.32, -4.15), 0.3, 0.62, Color(0.45, 0.48, 0.42), "KitchenJar")
	_add_cyl(Vector3(-14.55, 0.5, 4.75), 0.42, 1.0, grain, "KitchenBin")
	_add_label(Vector3(-14.55, 1.2, 4.75), "粮囤", 18)
	_add_cyl(Vector3(-10.4, 0.5, -8.25), 0.45, 1.0, grain, "SouthBinA")
	_add_cyl(Vector3(-2.1, 0.5, -8.25), 0.45, 1.0, grain, "SouthBinB")
	_add_box(Vector3(-6.2, 0.55, -9.25), Vector3(1.5, 1.0, 0.28), WOOD, "ToolRack")
	_add_label(Vector3(-6.2, 1.3, -9.25), "农具", 18)

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

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -70, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.58, 0.7, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.42)
	e.ambient_light_energy = 0.42
	env.environment = e
	add_child(env)
	for p in [Vector3(8, TUNNEL_FLOOR + 1.2, 0), Vector3(2.4, TUNNEL_FLOOR + 1.2, 0), Vector3(-8, TUNNEL_FLOOR + 1.1, -1.5), Vector3(8.2, TUNNEL_FLOOR + 1.1, -2.3)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(1.0, 0.72, 0.42)
		light.light_energy = 0.65
		light.omni_range = 5.0
		add_child(light)

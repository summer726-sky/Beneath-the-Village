extends RefCounted
class_name PropDress
## 用地标模型换掉方块外观。碰撞体留在原来的 StaticBody 上。

static func apply(world: Node) -> void:
	var jobs := [
		["Stove", "res://assets/props/stove.glb", Vector3(1.3, 0.9, 0.8)],
		["WellRing", "res://assets/props/well.glb", Vector3(1.5, 0.7, 1.5)],
		["Trough", "res://assets/props/trough.glb", Vector3(2.2, 0.55, 1.1)],
		["Bell", "res://assets/props/bell.glb", Vector3(0.42, 0.48, 0.42)],
		["Millstone", "res://assets/props/mill.glb", Vector3(1.7, 0.7, 1.7)],
		["Quern", "res://assets/props/quern.glb", Vector3(0.9, 0.45, 0.9)],
		["YardTrunk", "res://assets/props/yard_tree.glb", Vector3(7.2, 11.5, 7.2)],
		["JarA", "res://assets/props/jar.glb", Vector3(0.7, 0.75, 0.7)],
		["JarB", "res://assets/props/jar.glb", Vector3(0.7, 0.75, 0.7)],
		["KitchenJar", "res://assets/props/jar.glb", Vector3(0.62, 0.68, 0.62)],
		["Woodpile", "res://assets/props/firewood.glb", Vector3(1.5, 0.85, 1.0)],
		["OilLamp0", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp1", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp2", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp3", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp4", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp5", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp6", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp7", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp8", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp9", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp10", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["OilLamp11", "res://assets/props/oil_lamp.glb", Vector3(0.18, 0.14, 0.18)],
		["CoverSheaf", "res://assets/props/haystack.glb", Vector3(2.2, 0.9, 1.2)],
		["KangWest", "res://assets/props/kang.glb", Vector3(2.3, 0.5, 1.15)],
		["KangEast", "res://assets/props/kang.glb", Vector3(2.3, 0.5, 1.15)],
		["EastKang", "res://assets/props/kang.glb", Vector3(1.2, 0.5, 1.2)],
		["KangJarW", "res://assets/props/jar.glb", Vector3(0.32, 0.3, 0.32)],
		["PickleJar", "res://assets/props/jar.glb", Vector3(0.36, 0.34, 0.36)],
		["EastJar", "res://assets/props/jar.glb", Vector3(0.28, 0.24, 0.28)],
		["SouthTable", "res://assets/props/table.glb", Vector3(1.1, 0.52, 0.62)],
		["WallCabinet", "res://assets/props/cabinet.glb", Vector3(0.6, 1.5, 0.75)],
		["EightTable", "res://assets/props/table.glb", Vector3(1.05, 0.68, 0.58)],
		["Bellows", "res://assets/props/bellows.glb", Vector3(0.35, 0.28, 0.5)],
		["KitchenBin", "res://assets/props/grain_bin.glb", Vector3(0.84, 1.0, 0.84)],
		["SouthBinA", "res://assets/props/grain_bin.glb", Vector3(0.9, 1.0, 0.9)],
		["SouthBinB", "res://assets/props/grain_bin.glb", Vector3(0.9, 1.0, 0.9)],
		["CoverWoodA", "res://assets/props/firewood.glb", Vector3(1.6, 0.84, 1.1)],
		["CoverWoodB", "res://assets/props/firewood.glb", Vector3(1.5, 0.8, 1.2)],
		["CoverWoodC", "res://assets/props/firewood.glb", Vector3(1.8, 0.76, 1.3)],
		["WoodRoomPile", "res://assets/props/firewood.glb", Vector3(1.2, 0.8, 0.9)],
		["MillRoomStone", "res://assets/props/quern.glb", Vector3(0.84, 0.4, 0.84)],
		["MillJar", "res://assets/props/jar.glb", Vector3(0.46, 0.52, 0.46)],
		["WoodJar", "res://assets/props/jar.glb", Vector3(0.42, 0.5, 0.42)],
		["BarnBinCover", "res://assets/props/grain_bin.glb", Vector3(1.15, 1.15, 1.15)],
		["StableTroughCover", "res://assets/props/grain_bin.glb", Vector3(0.95, 1.0, 0.95)],
	]
	for job in jobs:
		var body := world.get_node_or_null(str(job[0])) as Node3D
		if body == null:
			continue
		if _dress(body, str(job[1]), job[2]):
			if str(job[0]) == "Millstone":
				var roller := world.get_node_or_null("MillRoller") as Node3D
				if roller:
					_hide_meshes(roller)
			if str(job[0]) == "YardTrunk":
				var crown := world.get_node_or_null("YardCrown") as Node3D
				if crown:
					_hide_meshes(crown)
				var sway := Node.new()
				sway.set_script(load("res://scripts/world/tree_sway.gd"))
				body.add_child(sway)
			if str(job[0]) == "Bell":
				var sway := Node.new()
				sway.set_script(load("res://scripts/world/bell_sway.gd"))
				body.add_child(sway)

	# Multi-candidate jobs: try paths in order, use first that exists.
	# No-ops gracefully when all candidates are missing.
	var candidate_jobs: Array = [
		["HangChiliA", ["res://assets/props/chili_string.glb",
		                "res://assets/props/hang_chili.glb",
		                "res://assets/props/hang_decor.glb"],        Vector3(0.26, 1.42, 0.26)],
		["HangCornA",  ["res://assets/props/corn_hang.glb",
		                "res://assets/props/hang_decor.glb"],         Vector3(0.26, 1.42, 0.26)],
		["HangCornB",  ["res://assets/props/corn_hang.glb",
		                "res://assets/props/hang_decor.glb"],         Vector3(0.26, 1.42, 0.26)],
		["YardSieve",  ["res://assets/props/sieve.glb",
		                "res://assets/props/bamboo_sieve.glb"],       Vector3(0.64, 0.08, 0.64)],
		["YardBasket", ["res://assets/props/basket.glb"],             Vector3(0.5, 0.42, 0.5)],
		["CellarHay",  ["res://assets/props/haystack.glb",
		                "res://assets/props/hang_decor.glb",
		                "res://assets/props/firewood.glb"],           Vector3(1.6, 0.8, 1.2)],
	]
	for cjob in candidate_jobs:
		var cbody := world.get_node_or_null(str(cjob[0])) as Node3D
		if cbody == null:
			continue
		for cpath in (cjob[1] as Array):
			if ResourceLoader.exists(str(cpath)):
				_dress(cbody, str(cpath), cjob[2])
				break


static func _dress(body: Node3D, glb_path: String, fit: Vector3) -> bool:
	if not ResourceLoader.exists(glb_path):
		return false
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	inst.name = "PropMesh"
	_strip_collision(inst)
	body.add_child(inst)
	var bounds := _bounds(inst)
	var span := bounds.size
	if span.x < 0.01 or span.y < 0.01 or span.z < 0.01:
		inst.queue_free()
		return false
	var base := inst.scale
	var shown := Vector3(span.x * base.x, span.y * base.y, span.z * base.z)
	var scale_v := base * minf(fit.x / shown.x, minf(fit.y / shown.y, fit.z / shown.z))
	if body.name == "YardTrunk":
		scale_v = Vector3(base.x * fit.x / shown.x, base.y * fit.y / shown.y, base.z * fit.z / shown.z)
	inst.scale = scale_v
	var center := bounds.position + bounds.size * 0.5
	var foot := _foot(body)
	# 略沉入地面/台面，避免漂浮接缝
	var sink := 0.025
	var n := str(body.name)
	if n.begins_with("OilLamp") or n == "Bell":
		sink = 0.0
	elif n.begins_with("Jar") or n.begins_with("Kang") or "Bin" in n or n == "Woodpile" or "Cover" in n:
		sink = 0.04
	elif n == "YardTrunk" or n.begins_with("Hang"):
		sink = 0.01
	inst.position = Vector3(-center.x * inst.scale.x, foot - bounds.position.y * inst.scale.y - sink, -center.z * inst.scale.z)
	_hide_meshes(body, inst)
	return true


static func _strip_collision(node: Node) -> void:
	for child in node.get_children():
		_strip_collision(child)
		if child is CollisionObject3D:
			(child as CollisionObject3D).collision_layer = 0
			(child as CollisionObject3D).collision_mask = 0
		elif child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true


static func _foot(body: Node3D) -> float:
	if str(body.name).begins_with("OilLamp") or body.name == "Bell":
		var col := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			return col.position.y - box.size.y * 0.5
		if col and col.shape is CylinderShape3D:
			var cyl := col.shape as CylinderShape3D
			return col.position.y - cyl.height * 0.5
		return 0.0
	var floor_y := -3.8 if body.position.y < -1.0 else 0.0
	return floor_y - body.position.y


static func _hide_meshes(node: Node, except: Node = null) -> void:
	for c in node.get_children():
		if c == except:
			continue
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


static func _bounds(root: Node3D) -> AABB:
	return _accum(root, root, Transform3D.IDENTITY)


static func _accum(root: Node3D, node: Node, parent: Transform3D) -> AABB:
	var here := parent
	if node != root:
		here = parent * (node as Node3D).transform
	var merged := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var ab := (node as MeshInstance3D).get_aabb()
		for i in 8:
			var p: Vector3 = here * ab.get_endpoint(i)
			if not has:
				merged = AABB(p, Vector3.ZERO)
				has = true
			else:
				merged = merged.expand(p)
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var sub := _accum(root, child, here)
		if sub.size == Vector3.ZERO and sub.position == Vector3.ZERO:
			continue
		if not has:
			merged = sub
			has = true
		else:
			merged = merged.merge(sub)
	return merged if has else AABB()

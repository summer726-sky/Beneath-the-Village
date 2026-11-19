extends RefCounted
class_name StructureDress
## 用生成的墙段、屋面、树冠和木板换掉方块外观。碰撞盒保持原位，门洞仍是空隙。

static func apply(world: Node3D) -> void:
	var wall := "res://assets/props/wall_span.glb"
	var roof := "res://assets/props/roof_bay.glb"
	var plank := "res://assets/props/plank.glb"
	var stack: Array[Node] = [world]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is StaticBody3D):
			continue
		var body := node as StaticBody3D
		var kind := str(body.get_meta("dress_kind", ""))
		var mesh := _first_mesh(body)
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var size := (mesh.mesh as BoxMesh).size
		var n := str(body.name)
		# 房墙 + 侦察树旁实墙/围墙：只换外观，碰撞不动
		if kind == "mottle" and size.y > 1.2 and (
			n.begins_with("House") or n.begins_with("Wall") or n.begins_with("Outer")
			or n.begins_with("Reed") or n.begins_with("Back") or n.begins_with("Screen")
		):
			_swap(body, mesh, wall, size, "stretch")
		elif kind == "tile" and size.y < 0.45 and size.x + size.z > 2.0:
			_swap(body, mesh, roof, size, "roof")
		elif kind == "wood" and (
			n.begins_with("Board") or "Board" in n or n.begins_with("Flip")
			or n.begins_with("Seal") or n.begins_with("Barrier") or n.begins_with("Choke")
			or n.begins_with("MinePlank") or n.begins_with("MinePost")
		) and size.y > 0.3:
			_swap(body, mesh, plank, size, "plank")
		elif n.begins_with("TreeWall") or n == "TreeCap" or n.begins_with("TreeRoot"):
			var bark := mesh.material_override
			if bark is ShaderMaterial:
				var copy := (bark as ShaderMaterial).duplicate() as ShaderMaterial
				copy.set_shader_parameter("base_color", Color(0.28, 0.2, 0.12))
				copy.set_shader_parameter("grain", 7.0)
				copy.set_shader_parameter("pit", 0.02)
				mesh.material_override = copy
	_canopy(world)
	_dress_tunnel_pieces(world)
	_dress_port_frames(world)
	_dress_mechanism_leaves(world)


static func _canopy(world: Node3D) -> void:
	var crown := world.get_node_or_null("LookoutCrown") as Node3D
	if crown:
		var crown_mesh := _first_mesh(crown)
		if crown_mesh:
			crown_mesh.visible = false
	var path := "res://assets/props/yard_tree.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return
	inst.name = "LookoutTree"
	_strip_collision(inst)
	world.add_child(inst)
	var bounds := _bounds(inst)
	if bounds.size.y < 0.01:
		inst.queue_free()
		return
	var base := inst.scale
	var shown := Vector3(bounds.size.x * base.x, bounds.size.y * base.y, bounds.size.z * base.z)
	var fit := Vector3(8.6, 12.0, 8.6)
	inst.scale = Vector3(base.x * fit.x / shown.x, base.y * fit.y / shown.y, base.z * fit.z / shown.z)
	var center := bounds.position + bounds.size * 0.5
	inst.position = Vector3(22.0 - center.x * inst.scale.x, -bounds.position.y * inst.scale.y, -center.z * inst.scale.z)
	_open_slit(inst)
	var sway := Node.new()
	sway.set_script(load("res://scripts/world/tree_sway.gd"))
	inst.add_child(sway)


static func _swap(body: Node, visual: MeshInstance3D, glb_path: String, fit: Vector3, mode: String) -> void:
	if not ResourceLoader.exists(glb_path):
		return
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return
	inst.name = "PropMesh"
	_strip_collision(inst)
	body.add_child(inst)
	var bounds := _bounds(inst)
	var span := bounds.size
	if span.x < 0.01 or span.y < 0.01 or span.z < 0.01:
		inst.queue_free()
		return
	var yaw := 0.0
	var scale := Vector3.ONE
	var tiles := 1
	var along_z := false
	if mode == "stretch":
		var long_fit := fit.x
		var short_fit := fit.z
		if fit.z > fit.x:
			yaw = PI * 0.5
			along_z = true
			long_fit = fit.z
			short_fit = fit.x
		if long_fit > 2.4:
			tiles = int(ceil(long_fit / 1.8))
		var tile_len := long_fit / float(tiles)
		if tiles > 1:
			tile_len += 0.1
		scale = Vector3(tile_len / span.x, fit.y / span.y * 1.06, short_fit / span.z)
	elif mode == "roof":
		scale = Vector3(fit.x / span.x, 0.78 / span.y, fit.z / span.z)
	elif mode == "plank":
		# 木板：按包围盒贴合，略厚一点盖住灰盒面
		scale = Vector3(
			fit.x / maxf(span.x, 0.01) * 1.02,
			fit.y / maxf(span.y, 0.01) * 1.02,
			fit.z / maxf(span.z, 0.01) * 1.08
		)
	else:
		var s := minf(fit.x / span.x, minf(fit.y / span.y, fit.z / span.z))
		scale = Vector3.ONE * s
	inst.scale = scale
	inst.rotation.y = yaw
	var center := bounds.position + span * 0.5
	var sink := 0.06 if mode == "stretch" else (0.14 if mode == "roof" else 0.0)
	var local := Vector3(-center.x * scale.x, -center.y * scale.y - sink, -center.z * scale.z)
	var origin := Basis(Vector3.UP, yaw) * local
	var span_len := fit.z if along_z else fit.x
	var placed_len := span_len / float(tiles)
	if tiles > 1:
		placed_len += 0.1
	var step := span_len / float(tiles)
	var start := -span_len * 0.5 + placed_len * 0.5
	inst.position = origin
	if along_z:
		inst.position.z += start
	else:
		inst.position.x += start
	for i in range(1, tiles):
		var extra := inst.duplicate() as Node3D
		body.add_child(extra)
		extra.position = origin
		var along := start + step * float(i)
		if along_z:
			extra.position.z += along
		else:
			extra.position.x += along
	visual.mesh = null


static func _strip_collision(node: Node) -> void:
	for child in node.get_children():
		_strip_collision(child)
		if child is CollisionObject3D:
			(child as CollisionObject3D).collision_layer = 0
			(child as CollisionObject3D).collision_mask = 0
		elif child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true


static func _first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D and str(child.name) != "PropMesh":
			return child
	if node is MeshInstance3D:
		return node
	return null


static func _open_slit(root: Node) -> void:
	var shader: Shader = load("res://assets/shaders/slit_tree.gdshader")
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is MeshInstance3D) or (node as MeshInstance3D).mesh == null:
			continue
		var mi := node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var sh := ShaderMaterial.new()
			sh.shader = shader
			sh.set_shader_parameter("slit_center", Vector3(22.73, 1.48, 0.0))
			sh.set_shader_parameter("slit_half", Vector3(0.85, 0.11, 0.58))
			var src := mi.get_active_material(surface)
			if src is BaseMaterial3D:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				if tex:
					sh.set_shader_parameter("albedo_tex", tex)
					sh.set_shader_parameter("use_tex", true)
				sh.set_shader_parameter("albedo_color", (src as BaseMaterial3D).albedo_color)
			mi.set_surface_override_material(surface, sh)


static func _bounds(root: Node3D) -> AABB:
	return PropDress._bounds(root)


static func _dress_tunnel_pieces(world: Node3D) -> void:
	# 禁止再藏走廊/岔口灰盒：底壁顶一律保留程序几何与碰撞；只叠加无碰撞装饰。
	# 竖井口用 tunnel_bay 薄环装饰（无 collision），不改净空。
	if ResourceLoader.exists("res://assets/props/tunnel_bay.glb"):
		for at in [
			Vector3(22.0, -1.9, 0.0), Vector3(2.4, -1.9, 0.15),
			Vector3(-10.0, -1.9, -3.6), Vector3(-4.2, -1.9, -4.2),
			Vector3(-6.2, -1.9, 7.2), Vector3(-22.0, -1.9, -1.4), Vector3(-6.2, -1.9, 14.0)
		]:
			_plant_piece(world, "res://assets/props/tunnel_bay.glb", at, Vector3(1.35, 3.6, 1.35), 0.0)
	if ResourceLoader.exists("res://assets/props/jump_hatch.glb"):
		_plant_piece(world, "res://assets/props/jump_hatch.glb", Vector3(7.2, -2.05, 0.22), Vector3(1.3, 0.28, 1.3), 0.0)

	# 强制走廊/岔口灰盒网格可见（结构不变）
	for child in world.get_children():
		if not (child is StaticBody3D):
			continue
		var n := str(child.name)
		var tunnel_shell := n.begins_with("CF") or n.begins_with("CC") or n.begins_with("CL") or n.begins_with("CR")
		tunnel_shell = tunnel_shell or n.begins_with("OF") or n.begins_with("OC") or n.begins_with("OS") or n.begins_with("ON") or n.begins_with("OE")
		tunnel_shell = tunnel_shell or n.begins_with("Hub") or n.begins_with("Jx") or n.begins_with("End")
		tunnel_shell = tunnel_shell or n.begins_with("BurdenSeal") or n.begins_with("Hatch") or n.begins_with("PortGap")
		tunnel_shell = tunnel_shell or n.begins_with("SideMouth") or n.begins_with("Drain") or n.begins_with("Loft")
		tunnel_shell = tunnel_shell or n.begins_with("MineBridge") or n.begins_with("Villager")
		tunnel_shell = tunnel_shell or ("Room" in n and (n.ends_with("F") or n.ends_with("C") or n.ends_with("N") or n.ends_with("S") or n.ends_with("W") or n.ends_with("E")))
		if not tunnel_shell:
			continue
		for mesh_child in child.get_children():
			if mesh_child is MeshInstance3D:
				(mesh_child as MeshInstance3D).visible = true


static func _dress_port_frames(world: Node3D) -> void:
	# 仅直道枪眼外侧加框装饰；死道/侧龛缝口较窄，避免装饰误挡视线观感
	if not ResourceLoader.exists("res://assets/props/firing_slit.glb"):
		return
	_plant_piece(world, "res://assets/props/firing_slit.glb", Vector3(-4.45, -3.0, -0.6), Vector3(2.85, 1.55, 0.16), 0.0)


static func _dress_mechanism_leaves(world: Node3D) -> void:
	# 翻板叶面：给 Visual/BoardL|R 加 plank 贴面（无碰撞）
	if not ResourceLoader.exists("res://assets/props/plank.glb"):
		return
	var packed := load("res://assets/props/plank.glb") as PackedScene
	if packed == null:
		return
	var stack: Array[Node] = [world]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if not str(node.name).begins_with("FlipTrap"):
			continue
		var vis := node.get_node_or_null("Visual") as Node3D
		if vis == null:
			continue
		for leaf_name in ["BoardL", "BoardR"]:
			var leaf := vis.get_node_or_null(leaf_name) as Node3D
			if leaf == null or leaf.get_node_or_null("PropMesh") != null:
				continue
			var inst := packed.instantiate() as Node3D
			if inst == null:
				continue
			inst.name = "PropMesh"
			_strip_collision(inst)
			leaf.add_child(inst)
			inst.scale = Vector3(0.55, 0.08, 0.22)
			inst.position = Vector3(0, 0, 0.23 if leaf_name == "BoardR" else -0.23)


static func _plant_piece(world: Node3D, path: String, at: Vector3, fit: Vector3, yaw: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return
	inst.name = "TunnelPiece"
	_strip_collision(inst)
	world.add_child(inst)
	inst.rotation.y = yaw
	_fit_piece(inst, at, fit)


static func _fit_piece(inst: Node3D, at: Vector3, fit: Vector3) -> void:
	var bounds := _bounds(inst)
	var span := bounds.size
	if span.x < 0.01 or span.y < 0.01 or span.z < 0.01:
		inst.queue_free()
		return
	var base := inst.scale
	inst.scale = Vector3(base.x * fit.x / span.x, base.y * fit.y / span.y, base.z * fit.z / span.z)
	var center := bounds.position + span * 0.5
	inst.position = at - Vector3(center.x * inst.scale.x, center.y * inst.scale.y, center.z * inst.scale.z)


static func _hide_mesh_only(body: Node) -> void:
	for child in body.get_children():
		if child is MeshInstance3D and str(child.name) != "PropMesh":
			(child as MeshInstance3D).visible = false


static func _hide_named(world: Node, prefix: String) -> void:
	for child in world.get_children():
		if str(child.name).begins_with(prefix):
			_hide_mesh_only(child)

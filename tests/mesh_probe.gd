extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var enemies := 0
	for e in get_nodes_in_group("enemies"):
		if e.get_node_or_null("BodyMesh"):
			enemies += 1
	var allies := 0
	for a in get_nodes_in_group("allies"):
		if a.get_node_or_null("BodyMesh"):
			allies += 1
	var villagers := 0
	for v in get_nodes_in_group("villagers"):
		if v.get_node_or_null("BodyMesh"):
			villagers += 1
	print("MESH enemies=%d allies=%d villagers=%d" % [enemies, allies, villagers])
	var world := scene.get_node("World")
	for prop_name in ["Stove", "WellRing", "Trough", "Bell", "Millstone", "Quern", "YardTrunk", "JarA", "JarB", "Woodpile", "OilLamp0", "KangWest", "EightTable", "WallCabinet", "Bellows", "KitchenBin", "SouthBinA", "LookoutTree"]:
		var body := world.get_node_or_null(prop_name)
		var mesh := body.get_node_or_null("PropMesh") if body else null
		if prop_name == "LookoutTree":
			mesh = body
		if body == null or mesh == null:
			print("PROP %s missing" % prop_name)
			continue
		var ab := _world_aabb(mesh)
		print("PROP %s y0=%.3f y1=%.3f h=%.2f" % [prop_name, ab.position.y, ab.position.y + ab.size.y, ab.size.y])
	quit()


func _world_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var has := false
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			var ab := mi.get_aabb()
			for i in 8:
				var p: Vector3 = mi.global_transform * ab.get_endpoint(i)
				if not has:
					merged = AABB(p, Vector3.ZERO)
					has = true
				else:
					merged = merged.expand(p)
	return merged

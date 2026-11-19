extends Node

func _process(_delta: float) -> void:
	var tree := get_parent().get_node_or_null("PropMesh") as Node3D
	if tree == null and get_parent() is Node3D and str(get_parent().name) == "LookoutTree":
		tree = get_parent()
	if tree == null:
		return
	var host := get_parent() as Node3D
	var t := Time.get_ticks_msec() * 0.001
	var phase := host.position.x * 0.17 + host.position.z * 0.11
	tree.rotation.z = sin(t * 0.33 + phase) * 0.012
	tree.rotation.x = sin(t * 0.21 + phase + 1.4) * 0.008

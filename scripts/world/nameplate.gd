extends Label3D
## 只有走近、并且中间没有墙时才显示人名。

const RANGE := 8.0

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		visible = false
		return
	var dist := global_position.distance_to(cam.global_position)
	if dist > RANGE:
		visible = false
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		visible = true
		return
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, global_position)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	visible = hit.is_empty() or cam.global_position.distance_to(hit.position) > dist - 0.8

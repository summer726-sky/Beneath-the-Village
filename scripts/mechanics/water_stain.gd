extends Node3D
## 湿痕先铺井下排水层，隔板开着才升到上层并进入指挥室。隔板或工兵停下时进度不再增加。

const _LOWER_Y := -5.42
const _UPPER_Y := -3.72

func _ready() -> void:
	var spots: Array[Vector3] = [
		Vector3(-10.0, _LOWER_Y, -3.5),
		Vector3(-10.0, _LOWER_Y, -2.8),
		Vector3(-10.0, _LOWER_Y, -2.15),
		Vector3(-10.0, _UPPER_Y, -0.45),
		Vector3(-2.0, _UPPER_Y, 0.0),
		Vector3(8.2, _UPPER_Y, -1.2),
	]
	for i in spots.size():
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.3, 0.04, 1.1)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.16, 0.2, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		mesh.position = spots[i]
		mesh.visible = false
		add_child(mesh)

func _process(_delta: float) -> void:
	if not BattleState.water_started:
		return
	var shown := int(ceil(BattleState.water_progress * get_child_count()))
	for i in get_child_count():
		var child := get_child(i) as Node3D
		if child:
			child.visible = i < shown

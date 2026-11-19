extends Node3D
## 沿井下到上层的一条浑水。进度决定水头走到哪，水面自己流动。隔板关上后进度不再增加。

const _LOWER_Y := -5.42
const _UPPER_Y := -3.72

var _mat: ShaderMaterial

func _ready() -> void:
	_build_pool()
	var pts: Array[Vector3] = [
		Vector3(-10.0, _LOWER_Y, -3.5),
		Vector3(-10.0, _LOWER_Y, -2.8),
		Vector3(-10.0, _LOWER_Y, -2.15),
		Vector3(-10.0, _LOWER_Y + 0.4, -1.4),
		Vector3(-10.0, _UPPER_Y, -0.45),
		Vector3(-6.0, _UPPER_Y, -0.2),
		Vector3(-2.0, _UPPER_Y, 0.0),
		Vector3(2.0, _UPPER_Y, -0.4),
		Vector3(8.2, _UPPER_Y, -1.2),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var walked := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var len := a.distance_to(b)
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		side = side.normalized() * 0.42
		var u0 := walked / total
		var u1 := (walked + len) / total
		walked += len
		var steps := maxi(int(ceil(len / 0.35)), 1)
		for s in steps:
			var t0 := float(s) / float(steps)
			var t1 := float(s + 1) / float(steps)
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			var uu0 := lerpf(u0, u1, t0)
			var uu1 := lerpf(u0, u1, t1)
			_quad(st, p0 - side, p0 + side, p1 + side, p1 - side, uu0, uu1)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/water_flow.gdshader")
	_mat.set_shader_parameter("progress", 0.0)
	mesh.material_override = _mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

var _pool: MeshInstance3D
var _pool_mat: StandardMaterial3D

func _build_pool() -> void:
	# 隔板南侧浅池。关上隔板后水停在这里涨一下。
	_pool = MeshInstance3D.new()
	_pool.name = "BarrierPool"
	var box := BoxMesh.new()
	box.size = Vector3(1.35, 0.04, 1.1)
	_pool.mesh = box
	_pool.position = Vector3(-10.0, _LOWER_Y + 0.08, -2.35)
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.28, 0.34, 0.3, 0.0)
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.roughness = 0.2
	_pool.material_override = _pool_mat
	_pool.visible = false
	add_child(_pool)

func _process(_delta: float) -> void:
	if _mat == null:
		return
	var amount := 0.0
	if BattleState.water_started:
		amount = BattleState.water_progress
	if BattleState.water_barrier_closed:
		amount = minf(amount, 0.28)
		if _pool_mat:
			_pool.visible = true
			_pool_mat.albedo_color.a = clampf(0.25 + amount * 1.4, 0.25, 0.75)
			_pool.scale.y = 1.0 + amount * 2.5
	_mat.set_shader_parameter("progress", amount)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	st.set_uv(Vector2(u0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(u0, 1))
	st.add_vertex(b)
	st.set_uv(Vector2(u1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(u0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(u1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(u1, 0))
	st.add_vertex(d)

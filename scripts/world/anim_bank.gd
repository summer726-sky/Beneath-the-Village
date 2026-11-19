extends RefCounted
class_name AnimBank
## 把重定向后的动作 GLB 并进人物 AnimationPlayer，并起短别名供 ActorLife 播放。
## 每个阵营只构建一次 AnimationLibrary，避免 12 人重复 instantiate 动画包导致内存崩。

const PACKS := {
	"ija": "res://assets/animations/ija",
	"militia": "res://assets/animations/militia",
}

const ALIASES := {
	"Idle_Loop": ["Idle", "idle"],
	"Walk_Loop": ["Walk", "walk"],
	"Jog_Fwd_Loop": ["Run", "run", "Jog"],
	"Sprint_Loop": ["Sprint", "run_fast"],
	"Crouch_Idle_Loop": ["Crouch", "crouch", "Cover", "cover"],
	"Crouch_Fwd_Loop": ["CrouchWalk", "crouch_walk"],
	"Jump_Start": ["Jump", "jump"],
	"Jump_Loop": ["JumpLoop"],
	"Jump_Land": ["JumpLand"],
	"Death01": ["Death", "dead", "Die"],
	"Pistol_Aim_Neutral": ["Aim", "aim"],
	"Pistol_Shoot": ["Shoot", "shoot"],
	"Hit_Chest": ["Hit", "hit"],
	"Hit_Knockback": ["Knockback", "hit_back"],
}

static var _lib_cache: Dictionary = {}


static func attach_for_mesh(mesh: Node3D, glb_path: String) -> void:
	var pack := ""
	if "ija_soldier" in glb_path:
		pack = "ija"
	elif "militia" in glb_path:
		pack = "militia"
	if pack == "":
		return
	attach(mesh, pack)


static func attach(mesh: Node3D, pack: String) -> void:
	if not PACKS.has(pack):
		return
	var player := _ensure_player(mesh)
	if player == null:
		return
	var lib := _library_for(pack)
	if lib == null:
		return
	if player.has_animation_library(&""):
		player.remove_animation_library(&"")
	player.add_animation_library(&"", lib.duplicate(true))


static func _library_for(pack: String) -> AnimationLibrary:
	if _lib_cache.has(pack):
		return _lib_cache[pack] as AnimationLibrary
	var folder: String = PACKS[pack]
	var lib := AnimationLibrary.new()
	var dir := DirAccess.open(folder)
	if dir == null:
		_lib_cache[pack] = lib
		return lib
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".glb") or file.ends_with(".gltf"):
			_merge_into_lib(lib, folder.path_join(file), file.get_basename())
		file = dir.get_next()
	dir.list_dir_end()
	_lib_cache[pack] = lib
	return lib


static func _ensure_player(mesh: Node3D) -> AnimationPlayer:
	var existing := _find_player(mesh)
	if existing:
		return existing
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	mesh.add_child(player)
	return player


static func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var found := _find_player(c)
		if found:
			return found
	return null


static func _merge_into_lib(lib: AnimationLibrary, path: String, clip_id: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	if inst == null:
		return
	var src := _find_player(inst)
	if src == null:
		inst.queue_free()
		return
	for anim_name in src.get_animation_list():
		var anim := src.get_animation(anim_name)
		if anim == null:
			continue
		var local := anim.duplicate(true) as Animation
		_retarget_tracks(local)
		var key := StringName(clip_id)
		if lib.has_animation(key):
			lib.remove_animation(key)
		lib.add_animation(key, local)
		if ALIASES.has(clip_id):
			for alias in ALIASES[clip_id]:
				var ak := StringName(alias)
				if lib.has_animation(ak):
					lib.remove_animation(ak)
				lib.add_animation(ak, local.duplicate(true))
	inst.queue_free()


static func _retarget_tracks(anim: Animation) -> void:
	for i in anim.get_track_count():
		var path := String(anim.track_get_path(i))
		if path.is_empty():
			continue
		var skel_idx := path.find("Skeleton3D")
		if skel_idx >= 0:
			anim.track_set_path(i, NodePath(path.substr(skel_idx)))

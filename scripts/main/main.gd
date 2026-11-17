extends Node3D
## 主场景：组装灰盒、玩家、NPC、战斗管理与 HUD。

func _ready() -> void:
	var builder := GrayboxBuilder.new()
	builder.name = "World"
	add_child(builder)
	builder.build()

	var bm := BattleManager.new()
	bm.name = "BattleManager"
	bm.add_to_group("battle_manager")
	add_child(bm)

	_spawn_player()
	_spawn_allies()
	_spawn_villagers()
	_spawn_enemies()
	_spawn_hud()

	# 开局敌军在村口外等待，警报或一段时间后推进
	await get_tree().create_timer(0.1).timeout
	BattleState.phase = BattleState.Phase.INTRO

func _spawn_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector3(-6.6, 0.25, 0.2)
	player.rotation.y = PI

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	player.add_child(col)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.5
	player.add_child(head)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 80.0
	head.add_child(cam)

	var interact_ray := RayCast3D.new()
	interact_ray.name = "InteractRay"
	interact_ray.target_position = Vector3(0, 0, -2.8)
	interact_ray.collision_mask = 1 | 32 | 8 | 4  # world, interactable, ally, enemy
	interact_ray.enabled = true
	cam.add_child(interact_ray)

	var shoot_ray := RayCast3D.new()
	shoot_ray.name = "ShootRay"
	shoot_ray.target_position = Vector3(0, 0, -40)
	shoot_ray.collision_mask = 1 | 4 | 8
	shoot_ray.enabled = true
	cam.add_child(shoot_ray)

	var interaction := Node.new()
	interaction.name = "InteractionSystem"
	interaction.set_script(load("res://scripts/player/interaction_system.gd"))
	player.add_child(interaction)

	player.set_script(load("res://scripts/player/player_controller.gd"))
	add_child(player)

func _spawn_allies() -> void:
	var a1 := CharacterBody3D.new()
	a1.name = "AllyJia"
	a1.collision_layer = 8
	a1.collision_mask = 1
	a1.position = Vector3(-7.2, 0.2, 0.6)
	a1.set_script(load("res://scripts/npc/ally_ai.gd"))
	add_child(a1)
	a1.set("ally_name", &"甲")
	a1.set("default_command", AllyAI.Command.HOLD_PORT)

	var a2 := CharacterBody3D.new()
	a2.name = "AllyYi"
	a2.collision_layer = 8
	a2.collision_mask = 1
	a2.position = Vector3(-8.4, 0.2, -1.6)
	a2.set_script(load("res://scripts/npc/ally_ai.gd"))
	add_child(a2)
	a2.set("ally_name", &"乙")
	a2.set("default_command", AllyAI.Command.CLOSE_BARRIER)

func _spawn_villagers() -> void:
	var positions := [
		Vector3(-5.2, 0.2, -0.4),
		Vector3(-8.6, 0.2, 3.2),
		Vector3(-3.4, 0.2, 3.4)
	]
	for i in positions.size():
		var v := CharacterBody3D.new()
		v.name = "Villager%d" % (i + 1)
		v.collision_layer = 16
		v.collision_mask = 1
		v.position = positions[i]
		v.set_script(load("res://scripts/npc/villager_ai.gd"))
		add_child(v)

func _spawn_enemies() -> void:
	var specs := [
		{"role": &"commander", "pos": Vector3(28.0, 0.25, -1.0), "route": [Vector3(20, 0, -1), Vector3(13, 0, 3), Vector3(12, 0, 8), Vector3(2, 0, 8), Vector3(-6, 0, 3)]},
		{"role": &"rifleman", "pos": Vector3(29.2, 0.25, 0.6), "route": [Vector3(20, 0, 1), Vector3(13, 0, -3), Vector3(12, 0, -8), Vector3(2, 0, -8), Vector3(-6, 0, -2)]},
		{"role": &"rifleman", "pos": Vector3(27.4, 0.25, 1.8), "route": [Vector3(21, 0, 2), Vector3(13.5, 0, 4), Vector3(12, 0, 8), Vector3(0, 0, 7), Vector3(-5, 0, 1)]},
		{"role": &"engineer", "pos": Vector3(30.0, 0.25, -0.2), "route": [Vector3(21, 0, 0), Vector3(13, 0, -2), Vector3(12, 0, -7), Vector3(1, 0, -6), Vector3(-8, 0, -3)]},
	]
	for s in specs:
		var e := CharacterBody3D.new()
		e.name = "Enemy_%s" % s["role"]
		e.collision_layer = 4
		e.collision_mask = 1
		e.position = s["pos"]
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.height = 1.6
		cap.radius = 0.28
		col.shape = cap
		col.position.y = 0.8
		e.add_child(col)
		var agent := NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		e.add_child(agent)
		var vision := RayCast3D.new()
		vision.name = "VisionRay"
		vision.target_position = Vector3(0, 0, -18)
		e.add_child(vision)
		e.set_script(load("res://scripts/npc/enemy_ai.gd"))
		add_child(e)
		e.set("role", s["role"])
		e.setup_route(s["route"])

func _spawn_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/ui/hud.gd"))
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.position = Vector2(16, 16)
	top_left.add_theme_constant_override("separation", 4)
	for n in ["Ammo", "Lives", "Morale", "Villagers", "Allies"]:
		var lb := Label.new()
		lb.name = n
		lb.text = n
		top_left.add_child(lb)
	root.add_child(top_left)

	var top_center := VBoxContainer.new()
	top_center.name = "TopCenter"
	top_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_center.position = Vector2(-200, 12)
	top_center.size = Vector2(400, 60)
	var obj := Label.new()
	obj.name = "Objective"
	obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_center.add_child(obj)
	root.add_child(top_center)

	var bottom := VBoxContainer.new()
	bottom.name = "BottomCenter"
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-240, -90)
	bottom.size = Vector2(480, 80)
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var msg := Label.new()
	msg.name = "Message"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.modulate = Color(1.0, 0.92, 0.7)
	bottom.add_child(hint)
	bottom.add_child(msg)
	root.add_child(bottom)

	# Overview
	var overview := PanelContainer.new()
	overview.name = "Overview"
	overview.visible = false
	overview.set_anchors_preset(Control.PRESET_CENTER)
	overview.position = Vector2(-220, -180)
	overview.size = Vector2(440, 360)
	var om := MarginContainer.new()
	om.name = "Margin"
	om.add_theme_constant_override("margin_left", 16)
	om.add_theme_constant_override("margin_right", 16)
	om.add_theme_constant_override("margin_top", 16)
	om.add_theme_constant_override("margin_bottom", 16)
	var ot := Label.new()
	ot.name = "OverviewText"
	ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	om.add_child(ot)
	overview.add_child(om)
	root.add_child(overview)

	# Result
	var result := PanelContainer.new()
	result.name = "Result"
	result.visible = false
	result.set_anchors_preset(Control.PRESET_CENTER)
	result.position = Vector2(-260, -220)
	result.size = Vector2(520, 440)
	var rm := MarginContainer.new()
	rm.name = "Margin"
	rm.add_theme_constant_override("margin_left", 20)
	rm.add_theme_constant_override("margin_right", 20)
	rm.add_theme_constant_override("margin_top", 20)
	rm.add_theme_constant_override("margin_bottom", 20)
	var rv := VBoxContainer.new()
	rv.name = "VBox"
	rv.add_theme_constant_override("separation", 10)
	var rt := Label.new()
	rt.name = "Title"
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt.add_theme_font_size_override("font_size", 28)
	var rr := Label.new()
	rr.name = "Reason"
	rr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rl := Label.new()
	rl.name = "Log"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rb := Button.new()
	rb.name = "Restart"
	rb.text = "重新开始"
	rv.add_child(rt)
	rv.add_child(rr)
	rv.add_child(rl)
	rv.add_child(rb)
	rm.add_child(rv)
	result.add_child(rm)
	root.add_child(result)

	# Intro
	var intro := PanelContainer.new()
	intro.name = "Intro"
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	var im := MarginContainer.new()
	im.name = "Margin"
	im.add_theme_constant_override("margin_left", 80)
	im.add_theme_constant_override("margin_right", 80)
	im.add_theme_constant_override("margin_top", 60)
	im.add_theme_constant_override("margin_bottom", 60)
	var iv := VBoxContainer.new()
	iv.name = "VBox"
	iv.add_theme_constant_override("separation", 16)
	var it := Label.new()
	it.name = "IntroText"
	it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var modes := HBoxContainer.new()
	modes.name = "Modes"
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 24)
	var ie := Button.new()
	ie.name = "ExploreBtn"
	ie.text = "探索地道"
	ie.custom_minimum_size = Vector2(180, 44)
	var ib := Button.new()
	ib.name = "StartBtn"
	ib.text = "开始警戒"
	ib.custom_minimum_size = Vector2(180, 44)
	modes.add_child(ie)
	modes.add_child(ib)
	iv.add_child(it)
	iv.add_child(modes)
	im.add_child(iv)
	intro.add_child(im)
	root.add_child(intro)

	add_child(hud)

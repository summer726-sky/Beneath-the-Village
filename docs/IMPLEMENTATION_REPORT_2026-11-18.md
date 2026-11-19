# 实施报告（2026-11-19）· 开场命名 + 成片观感推进

## 开场

| 按钮 | 含义 |
|------|------|
| **正式游戏** | 原「进入树洞」→ `begin_play`，树洞开战 |
| **地图探索** | 原「先看这座院子」→ `begin_explore`，院子熟悉地形 |

规则卡与探索提示文案已同步。

## 成片观感（进行中）

| 资产 | 状态 |
|------|------|
| `ija_soldier_rig.glb` / `militia_rig.glb` | 已下载；敌军/战友优先使用 |
| 动作库 `assets/animations/ija|militia/*.glb` | 走跑蹲跳死等已重定向；`AnimBank` 并入播放 |
| 辣椒串 / 玉米挂 / 筛篮 | 已下载并接 `PropDress` |
| 草垛掩护 | 任务 8343527 生成中 |
| 举枪/中弹反应 | 任务 8343662 / 8343668 进行中 |

积分：**不设限**（用户授权）。细节见 `docs/AHOLO_BUDGET.md`。

## 代码入口

- `AnimBank.attach_for_mesh` ← `ActorMesh.place`
- `ActorLife` 优先播短名 Idle/Walk/Run/Crouch/Jump/Death
- 缺 GLB 时回退程序四肢，不崩

## 玩法修正（同日续）

- 敌军 12 人侧向入视野（`SIDE_HOLD→SIDE_ENTER→APPROACH`）；`enemy_reveal_at` 5–10s；进村预算敲钟+隐蔽+3s
- 地道覆土封闭 + 井口西墙补死；`cover_points`；搜掩体不堵死探洞
- HUD「已进洞」；立体步枪挂载；声线 `index % 6`
- 回归：`smoke_test` / `tunnel_seal_test` / `space_audit` 通过
- 成片美术闭环计划：`docs/ART_FILM_LOOP_PLAN.md`

## 验收

`narrative_ui_test`、`smoke_test` 等继续绿；成片观感需实机看绑骨动画与挂饰。

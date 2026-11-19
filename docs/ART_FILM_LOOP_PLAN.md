# 成片美术观感闭环计划

前提：玩法审查通过后执行。目标是「冉庄地道战」从灰盒可读，升到可拍片截图的成片观感；Aholo 配额不限，按质量档位选任务。

## 现状（基线）

| 层 | 状态 |
|---|---|
| 地道/院落空间 | 灰盒几何 + 覆土封闭 + 枪眼/跳口可用 |
| 角色 | 民兵/村民 GLB + AnimBank；程序步枪兜底 |
| 道具 | chili/corn/sieve/basket/haystack 等已进 PropDress |
| 光影/SFX/VFX | 仍偏功能向，需成片级统一 |

## 阶段 0 · 资产盘点（0.5d）

1. 扫 `assets/` 与 `PropDress` / `StructureDress` / `ActorMesh` 引用，列「已用 / 未挂 / 缺」。
2. 定视觉锚：黄土、青砖、干草、井绳、树皮、地道湿土；拒绝塑料灰与过亮 PBR。
3. 输出 `docs/ART_ASSET_INVENTORY.md`（路径、用途、缺口）。

## 阶段 1 · 场景去灰盒（优先）

**地表院落**

- 地面：压实土 + 碎砖拼缝贴图（或分块 Decal），去掉大平铺灰盒色。
- 四面房：墙体贴图/砖缝；门楣、窗纸、烟囱；屋顶瓦或草顶。
- 井/驴槽/柴垛：用已有 Aholo 道具替换盒子；缺则 Lux3D `G1` 图生。
- 侦察树：树干/树冠实模；树缝枪眼保留碰撞与开口尺寸。

**地道（当前优先）**

- 覆土已封；薄墙不再挖凿碎裂；枪眼改整板+木框。
- 下一步：内壁湿土/夯土贴图或更稳的土壤着色，顶缘略不规则但不碎。
- 灯：油灯点光源 + 轻雾；枪眼处冷光漏入。
- 翻板/卡口/隔板：木纹实模，保留机关交互碰撞。
- 拉雷龛：已改为可走通岔道 + 桩线土包形态，可再换成专用小道具。

**工具入口**

- `structure_dress.gd` / `prop_dress.gd` / `graybox_builder.gd` 材质替换钩子。
- 新增贴图放 `assets/textures/ran_zhuang/`。

## 阶段 2 · 角色成片

1. 敌军 12 人：统一 Rig 变体（色差分 2–3 套），挂立体枪（已有 HeldRifle 可换 GLB）。
2. 民兵甲乙、村民：检查 Walk/Run/Aim/Death 轨；缺轨用 Aholo humanoid retarget。
3. 表情/口型不做；重点是跑停不滑步、瞄准有枪、倒地有重量。

Aholo：`lux3d_img_to_3d` / `lux3d_humanoid_auto_rig` / `lux3d_humanoid_animation_retarget`；默认 `taskQuality=normal`，商用截图用 `high`。

## 阶段 3 · 光影与后期

1. 主光：下午偏暖平行光 + 天空散射；地道内以局部灯为主。
2. WorldEnvironment：轻雾、SSA O（Compatibility 下用可代替的 AO/暗角）、色调映射偏胶片。
3. 枪口火/尘土：`combat_fx` 加强；脚步扬尘少量。

## 阶段 4 · 声画同步

1. 钟、翻板、灌水、枪声、地道回声分层。
2. `AudioDirector` / `period_lines`：12 人声线已 `% 6`，补齐缺文件。
3. 环境床：院外风、蝉/鸦（克制）。

## 阶段 5 · 验收截图清单

- 树洞东望：敌军侧向入视野
- 院内掩体交火
- 地道内（看不见上层悬浮地）
- 井口/驴槽机关特写
- HUD「已进洞」与正式游戏/地图探索文案同框

全部通过 → 标 `ART_FILM_LOOP = done` 于本文件文末。

## 执行顺序建议

1. 阶段 0 盘点（脚本扫目录即可）
2. 并行：地表材质（人）+ 道具补齐（Aholo agent）
3. 角色枪/动画核对
4. 光影一次过
5. SFX 扫尾 + 截图验收

## Agent 分派

| Agent | 任务 |
|---|---|
| A | 贴图/材质替换 StructureDress |
| B | Aholo 缺道具/敌军变体 |
| C | 灯光 WorldEnvironment + combat_fx |
| D | SFX 缺口与混音 |

父代理合并后跑 `smoke_test` / `space_audit` / `tunnel_seal_test` 回归。

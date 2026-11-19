# 成片美术 · 资产盘点

日期：2026-11-19  
对照：`docs/ART_FILM_LOOP_PLAN.md`、`docs/ASSET_REGISTER.md`、`docs/AHOLO_BUDGET.md`  
说明：盘点子代理因额度中断，本表由主会话按磁盘实路径补齐。

## 1. 角色

| 路径 | 使用者 | 动画包 | 缺口 |
|---|---|---|---|
| `assets/characters/ija_soldier_rig.glb` | 敌军（优先） | `animations/ija/*` | 12 人仅色差/帽盔变体；钢盔/望远镜未挂 |
| `assets/characters/ija_soldier_apose.glb` / `ija_soldier.glb` | 回退 | 同上 | 无绑骨时靠 ActorLife 程序四肢 |
| `assets/characters/militia_rig.glb` | 战友甲乙（优先） | `animations/militia/*` | 甲乙视觉区分偏弱（tint） |
| `assets/characters/militia_jia.glb` / `militia_young.glb` / `militia_apose.glb` | 回退 | 同上 | — |
| `assets/characters/villager_elder.glb` / `villager_young.glb` / `villager_mid.glb` | 村民 | 民兵包或程序 | 缺专属 Walk/Flee；无 rig 变体 |
| 预览图 `*_0/1/2.png` | 文档/验收 | — | 非运行时 |

动画库已有 Idle/Walk/Jog/Sprint/Crouch/Jump/Death/Aim/Shoot/Hit（ija+militia 各一套）。`ActorLife` 另挂程序步枪兜底。

## 2. 道具（PropDress）

| PropDress 键 / 节点 | GLB | 状态 |
|---|---|---|
| Stove / WellRing / Trough / Bell / Millstone / Quern | 对应 `props/*.glb` | 已挂 |
| YardTrunk / Jar* / Woodpile / OilLamp* | 已挂 | — |
| Kang* / Table / Cabinet / Bellows / GrainBin* | 已挂 | — |
| CoverWood* / CoverSheaf | 暂用 `firewood.glb` | **草垛应用 haystack** |
| HangChili / HangCorn / YardSieve / YardBasket / CellarHay | chili/corn/sieve/basket/haystack | 已挂（候选回退） |
| — | `rifle_arisaka.glb` / `rifle_hanyang.glb` | **未挂到角色骨骼**（现用程序盒枪） |
| — | `jump_hatch` / `firing_slit` / `tunnel_bay` / `plank` | StructureDress / 局部用；机关碰撞仍程序 |
| — | `wheat` / `grass_clump` / `poplar` / `lookout_canopy` | 部分场景用；田埂主几何仍程序 |

## 3. 结构 / 贴图（去灰盒）

| 层 | 已用 | 仍缺 / 灰盒 |
|---|---|---|
| 房墙屋面 | `wall_span.glb` `roof_bay.glb`（StructureDress） | 大面积仍靠色块+mottle；缺砖缝/土墙 albedo 套装 |
| 侦察树 | 程序树缝 + canopy/yard_tree | 树皮/树冠成片级不足 |
| 地道 | 程序 + 覆土封闭 | 缺湿土/夯土/渗水贴图；灯已有油灯模 |
| 地面院落 | 程序黄土色 | 缺压实土+碎砖 Decal |
| 门扇/卡口/翻板 | 程序木方 | 可换 plank/木纹，铰链逻辑保留 |

## 4. 音频

| 类 | 位置 | 缺口 |
|---|---|---|
| 台词 | 设计登记在 `audio/voice/`（本机扫描未见 wav/ogg 于 `audio/` 根） | 需核对实际目录与 `AudioDirector` 引用 |
| 敌军声线 | `period_lines`：`enemy_%d_%s` + `index % 6` | 12 人复用前 6；文件齐性待验 |
| 环境/SFX | 计划见 `docs/AUDIO_PLAN.md` | 钟/翻板/灌水/枪声/地道回声分层未成片化 |

## 5. 优先 Aholo 队列（阶段 1–2，≤12）

| # | 目标 | 建议 | 质量 | 用途 |
|---:|---|---|---|---|
| 1 | 黄土地面贴图套（albedo/rough） | 多模态生图 → 手贴，不必 3D | normal | 去灰盒地面 |
| 2 | 夯土/湿土隧道内壁贴图 | 同上 | normal | 地道观感 |
| 3 | 青砖/土墙缝贴图 | 同上 | normal | 房墙 |
| 4 | 草垛专用（替换 CoverSheaf 柴垛误用） | G1-Turbo 图生 3D | normal | 掩体识别 |
| 5 | 三八式步枪挂点版（或校验现有 arisaka） | G1-Turbo | high | 换掉程序盒枪 |
| 6 | 汉阳造挂点版 | G1-Turbo | high | 民兵 |
| 7 | 钢盔 / 战斗帽小件 | G1-Turbo | normal | 12 敌军变体 |
| 8 | 望远镜小件 | G1-Turbo | normal | 分队长 |
| 9 | 工兵圆锹+水桶 | G1-Turbo | normal | 工程师识别 |
| 10 | 村民 Flee/Walk 短轨（女） | 绑骨+retarget | normal | 减少滑步 |
| 11 | 侦察树树干特写段 | G1 | normal | 树缝外立面 |
| 12 | 翻板木槽外观（非碰撞） | G1-Turbo | normal | 驴槽特写 |

积分：贴图向任务优先多模态；小件 Turbo；角色轨用现有 rig retarget。封顶与账本见 `AHOLO_BUDGET.md`。

## 6. 结论

- **道具地标**：大部分已 Dress，成片瓶颈在**地面/墙/地道材质**与**枪械挂载**。  
- **角色**：rig + 动画库已在；缺变体与真枪挂点。  
- **下一步**：阶段 1 先落地贴图去灰盒（不必等新 3D），并行把 `rifle_*.glb` 接到 `ActorLife`。

# 机关补强 + 美术观感闭环 · 实施计划

日期：2026-11-19

## 0. 地道机关清点（现状）

| 机关 | 节点 | 数量 | 说明 |
|---|---|---:|---|
| 翻板 | `FlipTrap` | 1 | 驴槽口，中间木轴安全 |
| 翻口 | `FlipMouthEast` | 1 | 挡/开南死道 |
| 翻眼/暗室门 | `VillagerSeal` | 1 | 藏身口木板 |
| 拉雷 | `TripWire` | 1 | 北廊西岔，先拉线敌军绊发 |
| 挡水隔板 | `WaterBarrier` | 1 | 井下，按住三秒 |
| 卡口 | `ChokeGate` / `OuterChoke` | 2 | 树洞西侧 + 西外廊 |
| 枪眼/射击位 | `*Port` | 6 | 树缝/锅台/门槛/直道/死道/侧龛 |
| 跳口 | hatch | 1 | 侧洞上到直道 |
| 弹药暗室 | `AmmoCache` | 1 | 指挥室旁 |

**翻板仅 1 处** → 本轮在西外廊（粮囤方向主通道）增补第 2 处。

## 1. 实施顺序

1. **翻板×2**：抽取建造函数；敌军 AI / FX 遍历所有 `flip_trap`；地图标点
2. **地道+院子材质统一**：黄土/湿土同一色系与 shader（`soil`/`damp`/`earth`），庭院地面与洞内同族
3. **精细枪支**：`rifle_arisaka.glb`（敌军）/ `rifle_hanyang.glb`（民兵）替换程序盒枪；人手/胸前挂点
4. **动作+火光**：确保 Walk/Run/Aim/Shoot 轨在播；开火播 Shoot + 可见火光 mesh（不只 OmniLight）
5. **封闭复验**：`tunnel_seal_test`；无挖凿碎块、通道通达

## 2. 验收

- 两处翻板均可触发；触发后敌军踩木轴
- 院内/洞内黄土观感连贯，无塑料灰
- 每名士兵可见实模步枪；抬枪瞄准；开火有火光
- 地道无透顶、无缺地板侧壁、拉雷/北廊可走

## 3. 本轮落地（2026-11-19）

- 西外廊 `FlipTrapWest`（-18.2, 0）；AI/地图/FX 多翻板兼容
- 院子 `GROUND` 与地道 `TUNNEL` 同族 + swatch 贴图混入
- `rifle_arisaka` / `rifle_hanyang` 挂右手骨；`play_fire` + 火光 mesh
- `tunnel_seal_test` PASS

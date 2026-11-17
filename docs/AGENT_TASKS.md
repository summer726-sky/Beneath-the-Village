# Agent 任务分工（主 Agent 协调）

主 Agent 为唯一技术负责人；以下文件归属避免并行冲突。

| Agent | 范围 | 可写路径 | 禁写 |
|-------|------|----------|------|
| 主 Agent | 架构集成、胜负、构建验收、审阅包、预算审批 | `scripts/autoload/**` `scripts/core/**` `scripts/main/**` `project.godot` `docs/**` `PROJECT-STATUS.md` | — |
| A 第一人称与交互 | 移动视角射击生命交互 | `scripts/player/**` | autoload/core |
| B 地图与机关 | 灰盒与机关 | `scripts/world/**` `scripts/mechanics/**` | autoload/core |
| C NPC 战斗 | 敌军村民战友 | `scripts/npc/**` | autoload/core |
| D 视觉声音展示 | 材质光效 UI 叙事展陈 | `scripts/ui/**` `assets/**` | autoload/core |
| E 测试与赛事材料 | 测试用例、介绍文稿 | `tests/**` `docs/delivery/**` | 核心架构 |

当前阶段：主 Agent 已落地 P0 骨架；后续按上表并行补强。Aholo 需求须向主 Agent 提交审批单（见 `docs/AHOLO_BUDGET.md`）。

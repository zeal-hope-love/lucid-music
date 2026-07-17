---
name: fix-arkts-untyped-obj-literals
overview: 修复 8 个 ArkTS 编译错误：MusicApiService.ets 的 import 顺序错误（5个），WyMusicApi.ets 的对象字面量无类型错误（2个），以及 MusicApiUtils.ets 的 EapiData 类型定义需重构。
todos:
  - id: fix-musicapi-utils
    content: 修复 MusicApiUtils.ets：删除 EapiData type 别名，将 eapiEncrypt 参数改为 ESObject
    status: completed
  - id: fix-wymusic-api
    content: 修复 WyMusicApi.ets：移除 EapiData import，变量类型改为 ESObject
    status: completed
    dependencies:
      - fix-musicapi-utils
  - id: fix-musicapi-service
    content: 修复 MusicApiService.ets：将 export { PlayUrlResult } 移到所有 import 之后
    status: completed
---

## 需求
修复 DevEco Studio 构建中的 8 个 ArkTS 编译错误，让项目恢复 BUILD SUCCESS。

### 错误清单
| # | 错误码 | 文件 | 行号 | 描述 |
|---|--------|------|------|------|
| 1-2 | 10605038 | WyMusicApi.ets | 50:68, 112:34 | 对象字面量无显式 interface/class 类型 |
| 3-7 | 10605150 | MusicApiService.ets | 10-14 | import 语句出现在 export 之后 |

### 涉及文件（3 个）
- `MusicApiService.ets` — 修复 import/export 顺序
- `MusicApiUtils.ets` — 将 `eapiEncrypt` 参数从 `EapiData` 改为 `ESObject`，删除 `EapiData` 类型
- `WyMusicApi.ets` — 更新 import 和类型标注


## 技术方案

### 根因分析

| 错误 | 根因 | 修复策略 |
|------|------|----------|
| WyMusicApi:50/112 `arkts-no-untyped-obj-literals` | `EapiData = Record<string, string>` 是 **type 别名**，ArkTS 仅接受 `interface`/`class` 作为对象字面量的显式类型。`eapiEncrypt` 内部只对 data 做 `JSON.stringify(data)`，不需要 `Record<string, string>` 约束 | 将 `eapiEncrypt` 参数类型从 `EapiData` 改为 ArkTS 内置全局类型 `ESObject`，删除 `EapiData` 类型定义 |
| MusicApiService:10-14 `arkts-no-misplaced-imports` | 上一轮修复时 `export { PlayUrlResult }` 被插入在第 9 行（两个 import 块之间），导致后续 5 条 import 违规 | 将 `export { PlayUrlResult } from './MusicApiUtils'` 移到所有 import 语句之后 |

### 为什么不能同时保留 `EapiData` 接口
- `interface EapiData { [key: string]: string }` 触发 `arkts-no-indexed-signatures`
- `type EapiData = Record<string, string>` 触发 `arkts-no-untyped-obj-literals`
- 唯一可行方案：使用 `ESObject`（ArkTS 内置，无需 import），在调用侧也直接标注 `ESObject`

### 修改点汇总

**MusicApiUtils.ets**：2 处改动
1. 删除第 11 行 `export type EapiData = Record<string, string>`
2. 第 95 行 `eapiEncrypt(url: string, data: EapiData)` → `eapiEncrypt(url: string, data: ESObject)`

**WyMusicApi.ets**：2 处改动
1. 第 8 行 import 列表中移除 `EapiData`
2. 第 112 行 `const eapiData: EapiData` → `const eapiData: ESObject`

**MusicApiService.ets**：1 处改动
1. 将第 9 行 `export { PlayUrlResult } from './MusicApiUtils'` 移到第 14 行之后（所有 import 之后）

这些修改确保：
- 无新增依赖，`ESObject` 为 ArkTS 内置全局类型
- `eapiEncrypt` 行为不变（始终只做 `JSON.stringify`）
- `SearchResultViewModel.ets` 的 `import type { PlayUrlResult } from '../service/MusicApiService'` 继续生效
- 所有 8 个编译错误全部消除


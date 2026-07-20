---
name: 修复ArkTS编译语法错误
overview: 修复两处 ArkTS 严格模式语法错误：MusicDbApi.ets 的解构赋值声明和 AudioCacheHelper.ets 的 for...in 循环，使 entry 模块 CompileArkTS 通过。
todos:
  - id: fix-musicdbapi-destructure
    content: 修复 MusicDbApi.ets:176 解构声明，改用 Promise.all 结果索引赋值
    status: completed
  - id: fix-audiocache-forin
    content: 修复 AudioCacheHelper.ets:312 for...in，改用 for...of Object.keys
    status: completed
  - id: verify-build
    content: 重新执行 assembleHap 验证 CompileArkTS 无 ERROR
    status: completed
    dependencies:
      - fix-musicdbapi-destructure
      - fix-audiocache-forin
---

## 用户需求
构建 entry 模块（assembleHap）在 CompileArkTS 阶段失败，需修复 2 个 ArkTS 严格模式语法编译错误，使构建通过。其余 211 个 WARN 为非阻塞项，不在本次范围内。

## Core Features
- 修复 `common/musicbasic/src/main/ets/util/MusicDbApi.ets:176` 的数组解构声明（arkts-no-destruct-decls），改为兼容写法且保持并发加载。
- 修复 `common/musicbasic/src/main/ets/util/AudioCacheHelper.ets:312` 的 `for...in` 循环（arkts-no-for-in），改为 `for...of Object.keys` 兼容写法。
- 不改动任何业务逻辑，仅做语法层修复。

## Tech Stack
- HarmonyOS ArkTS 严格模式（SDK 26.0.0），不支持解构声明与 `for...in`。

## Implementation Approach
两处均为语法不兼容，采用最小改动、零逻辑变更的修复方式：

1. **MusicDbApi.ets `initPlaylists`**：原 `const [a,b,c,d] = await Promise.all([...])` 解构不被支持。改为先 `const results = await Promise.all([...])` 接收元组结果，再用 `results[0]..[3]` 分别赋值给具名 const。这样既规避解构声明，又保留四个 db 查询的并发执行（性能不退化），且索引访问在 ArkTS 中类型安全。

2. **AudioCacheHelper.ets `downloadFile`**：原 `for (const k in headers)` 不被支持。改为 `for (const k of Object.keys(headers)) { reqHeaders[k] = headers[k] }`，`Object.keys` 返回 `string[]`，`for...of` 为 ArkTS 支持的遍历方式，等价语义。

## Implementation Notes
- 仅定向编辑两处，不触碰其余代码，避免引入回归。
- 修复后建议重新执行 `assembleHap` 验证 CompileArkTS 通过（目标：ERROR:0）。
- WARN 项（如 deprecated API、may throw）保持现状，不在此次处理。

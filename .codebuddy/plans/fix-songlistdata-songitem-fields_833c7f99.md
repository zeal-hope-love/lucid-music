---
name: fix-songlistdata-songitem-fields
overview: 修复 entry 模块 CompileArkTS 失败：SongListData.ets 中 10 个 SongItem 对象字面量缺少新增的 platform / remoteSongId 字段，导致 ArkTS 类型检查报错。
todos:
  - id: fix-songlistdata
    content: 为 SongListData.ets 的 10 个 SongItem 字面量补充 platform 与 remoteSongId 字段
    status: completed
  - id: verify-build
    content: 重新执行 assembleHap 确认 CompileArkTS 无 ERROR
    status: completed
    dependencies:
      - fix-songlistdata
---

## 用户需求
消除 DevEco Studio hvigor 构建在 `:entry:default@CompileArkTS` 阶段失败的 11 个 ArkTS 编译错误，使 `assembleHap` 构建通过。

## 问题根因
- `common/musicbasic/src/main/ets/model/SongData.ets` 的 `SongItem` 类（@ObservedV2）新增了两个数据字段：`platform: string = ''`（远程平台）与 `remoteSongId: string = ''`（远程歌曲原始 id），本地歌曲均为空字符串。
- `features/player/src/main/ets/model/SongListData.ets` 用 `const songList: SongItem[]` 的对象字面量数组构造了 10 首本地 demo 歌曲（id 1-10），但每个对象字面量都未包含上述两个字段。
- ArkTS 严格模式要求对象字面量赋值给 class 类型时必须包含该 class 的全部数据字段，否则报 `missing the following properties: platform, remoteSongId`。

## 核心修复内容
- 在 `SongListData.ets` 的 10 个 `SongItem` 对象字面量中，各补充 `platform: ''` 与 `remoteSongId: ''`（与类默认值一致，本地歌曲留空）。

## 非本次处理项（仅 WARN，不阻断构建）
- `types.ets` 第 165-179 行 `MusicPlatform` 类方法字段 `!` 明确赋值触发 `arkts-no-definite-assignment` 警告，属既有设计，不阻断构建。
- 其余 200 条 WARN（异常未捕获、deprecated API）均不阻断构建。

## 技术栈
- HarmonyOS ArkTS（严格模式），项目遵循 ArkTS 对象字面量约束（对象字面量只能对应含数据字段的 class/interface，且必须提供全部数据字段）。

## 实现方案
- 直接修改 `features/player/src/main/ets/model/SongListData.ets`：为 10 个本地 demo 歌曲的对象字面量各补充 `platform: ''` 与 `remoteSongId: ''` 两个字段。
- 这两个字段与 `SongItem` 类中的默认值（空字符串）完全一致，本地歌曲无需赋具体值，仅用于满足 ArkTS 字面量全字段校验。
- 不改动 `SongItem` 类定义、不引入可选字段或新结构，保持最小改动半径，避免影响其他已正确构造 `SongItem` 的调用点（如 `SongDtoMapper`、`MusicMemoryStore` 种子数据等）。

## 实现要点
- 仅新增两个字段赋值，不调整既有字段顺序与值，保证 diff 最小化、零回归风险。
- 修改后重新执行 `assembleHap`，确认 `CompileArkTS` 阶段 11 个 `missing properties` 错误消失、构建通过。

---
name: musicSdk ArkTS 编译错误修复
overview: 修复 musicSdk 模块（common/musicbasic/src/main/ets/util/musicSdk）因使用标准 TS 语法而触发的 ArkTS 严格编译错误，使项目恢复编译。错误分为 7 类固定模式，集中在约 35 个文件。
todos:
  - id: fix-types
    content: 修复 types.ets：删除错误 import，新增 QualityType/MusicInfo/SignatureResult 等共享接口并应用到 SearchResultItem
    status: completed
  - id: fix-root-dispatch
    content: 修复根调度层 api-source-info.ets、api-source.ets（去 unknown 转换）、index.ets、ApiSource.ets
    status: completed
    dependencies:
      - fix-types
  - id: fix-platform-index
    content: "为 wy/tx/kg/kw/mg 五个 index.ets 的聚合对象标注 : MusicPlatform 类型"
    status: completed
    dependencies:
      - fix-root-dispatch
  - id: fix-wy-tx
    content: 修复 wy 与 tx 端点模块：obj-literal-as-type、untyped-obj-literal、spread、destruct、Object.assign
    status: completed
    dependencies:
      - fix-platform-index
  - id: fix-kg-kw
    content: 修复 kg 与 kw 端点模块：同上七类 ArkTS 语法合规转换
    status: completed
    dependencies:
      - fix-platform-index
  - id: fix-mg
    content: 修复 mg 端点模块（utils/crypto、songMap、songList、musicInfo、leaderboard、index）的语法合规问题
    status: completed
    dependencies:
      - fix-platform-index
  - id: build-verify
    content: 运行 assembleHap 增量构建，按编译器报错迭代修复直至 CompileArkTS 0 ERROR
    status: completed
    dependencies:
      - fix-wy-tx
      - fix-kg-kw
      - fix-mg
---

## 用户需求
修复 `common/musicbasic/src/main/ets/util/musicSdk/` 模块（从 lx-music-mobile 风格 JS/TS 移植的音乐 API SDK）导致的 ArkTS 严格编译失败，使 `hvigor assembleHap` 的 `:entry:default@CompileArkTS` 阶段通过、ERROR 归零。

## 核心问题
该目录约 35 个文件大量使用了 ArkTS 严格模式禁止的语法，共约 200 个编译 ERROR（WARNING 如 "Function may throw exceptions"、废弃 API 等不阻断构建，暂忽略）。错误集中在 7 类固定模式，可机械修复。

## 修复范围
- 根文件：`types.ets`、`index.ets`、`api-source.ets`、`api-source-info.ets`、`ApiSource.ets`
- 五平台（wy/tx/kg/kw/mg）的 `index.ets` 及各自端点模块（musicSearch、songList、musicInfo、comment、leaderboard、hotSearch、lyric、tipSearch、utils）


## 技术栈与约束
- 语言：HarmonyOS ArkTS（严格模式，targetSdkVersion 26.0.0 / compatibleSdkVersion 6.1.0）
- 关键事实（已验证）：`@ObservedV2` / `@Trace` 在当前 SDK 为**全局装饰器**，项目内 31 个文件（如 `CurrentTabState.ets`）均直接使用而无需 import；`MusicPlatform` 接口已在 `api-source.ets` 定义；`QQHotKey*`、`PlayUrlResult`、`TagFilterItem`、`TagFilterGroup` 等由 `musicbasic` 模块导出。

## 错误类别与修复策略
1. **错误 import（types.ets:7）**：`import { ObservedV2, Trace } from '@kit.ArkUI'` 报错无此导出。修复：直接删除该行，依赖全局装饰器。
2. **arkts-no-obj-literals-as-types**：把对象字面量当类型注解，如 `Array<{ type: string, size: string }>`、`Record<string, { size: string }>`、`Promise<{ sign: string; deviceId: string }>`、`musicInfo: { name: string; ... }`。修复：在 `types.ets` 定义具名接口（`QualityType`、`MusicInfo`、`SignatureResult` 等）后引用。
3. **arkts-no-untyped-obj-literals**：无类型上下文的对象字面量，如各平台 `const wy = { ... }`、`tx/hotSearch.ets` 的 `QQHotKeyBody` 字面量、`push({ type:'128k', size:'' })`。修复：给平台聚合对象标注 `: MusicPlatform`；质量数组标注 `: QualityType[]`；确保字面量处于已声明接口上下文。
4. **arkts-no-spread**：`{ ...empty, list: filled }`（wy/musicSearch.ets:46）。修复：显式逐字段拷贝 `const r = new SearchResult(); r.list = filled; ...`。
5. **arkts-no-destruct-decls**：`const { types, _types } = buildQualityTypes(item)`。修复：拆为 `const q = buildQualityTypes(item); result.types = q.types; result._types = q._types;`。
6. **arkts-no-any-unknown**：`api-source.ets:38-42` 的 `as unknown as MusicPlatform`。修复：各平台 index 的 `const` 标 `MusicPlatform` 后，`apis()` 直接 `return wy`（无需 unknown 转换；若个别方法缺失则补全实现）。
7. **arkts-limited-stdlib**：`Object.assign(new TagFilterItem(), { id:'0', name:'全部' })`（kg/kw/mg 的 songList.ets 默认标签）。修复：改为 `const it = new TagFilterItem(); it.id='0'; it.name='全部';`。

## 共享类型策略
在 `types.ets` 新增并导出 `interface QualityType { type: string; size: string }`，将 `SearchResultItem.types` 改为 `Array<QualityType>`、`_types` 改为 `Record<string, QualityType>`；各平台 `buildQualityTypes`/质量数组统一复用 `QualityType`，消除重复的对象字面量类型。新增 `MusicInfo`、`SignatureResult` 等接口供 `index.ets` 与 `mg/utils/crypto.ets` 引用。

## 执行要点
- 严格复用现有 `MusicPlatform` 接口与各平台已声明的请求/响应接口，不新增无关抽象。
- 逐文件修改后保留原有加密/请求逻辑与日志，仅做语法合规转换，不改变运行时行为。
- 错误为机械性、可批量处理；按编译器报错迭代直至 0 ERROR。

## 验证
重新运行用户提供的 hvigor 命令，确认 `:entry:default@CompileArkTS` 通过、无 ERROR（WARNING 可暂忽略）。


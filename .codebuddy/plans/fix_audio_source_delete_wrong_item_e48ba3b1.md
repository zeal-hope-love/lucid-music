---
name: fix_audio_source_delete_wrong_item
overview: 修复"我的"页面音源管理左滑删除总是删除最后一个音源的问题：移除共享字段 pendingDeleteId，改为 swipeTrashBuilder 传参精准删除。
todos:
  - id: fix-audio-source-delete
    content: 修改 AudioSourceSection.ets 移除 pendingDeleteId，改为 swipeTrashBuilder 传参精准删除
    status: completed
---

## 用户需求
修复"我的"页面中"音源管理"面板（bindSheet 内）音源列表的左滑删除 bug：当前点击删除按钮时总是删除列表中的最后一个音源，而非用户实际左滑出的对应音源。要求用与歌单删除相同的修复方式解决。

## 产品概述
"音源管理"面板以 Sheet 形式展示已导入的音源列表，每个音源支持左滑删除。删除后应通过 ID 精准移除目标音源并刷新列表。

## 核心功能
- 每个音源项左滑露出删除按钮
- 点击删除按钮删除当前该项对应的音源，而非列表末尾项
- 删除成功后刷新列表并维护选中态

## 技术栈
- HarmonyOS ArkUI（ArkTS 严格模式），@ComponentV2 / @Local / @Builder
- 数据层：AudioSourceManager 单例（deleteSource(id) 已按 id 正确删除，无需改动）

## 实现方案
### 问题根因
`AudioSourceSection.ets` 与已修复的 `PlaylistSection.ets` 存在完全相同的模式——使用共享可变状态 `@Local pendingDeleteId` 记录待删除音源 ID：
- 第 83 行：`@Local pendingDeleteId: string = ''`
- 第 340-348 行 swipeAction 的 builder：`this.pendingDeleteId = item.id; this.swipeTrashBuilder()`
- 第 262 行 trash 按钮 onClick：`this.onDelete(this.pendingDeleteId)`

ArkUI 的 swipeAction builder 在列表初次布局时会对每个 ListItem 调用一次以测量尺寸，导致 `pendingDeleteId` 被逐个覆盖，最终只保留最后一个音源的 ID；删除时读取的是最后写入的值，因此永远删最后一个。

### 修复策略
摒弃共享状态，改为将 `id` 作为 `swipeTrashBuilder` 的参数，由 swipeAction builder 在闭包中直接传入当前项的 `item.id`，删除回调通过参数精准定位目标音源。`AudioSourceManager.deleteSource(id)` 已按 id 正确删除，无需修改。

### 关键决策
- 删除 `@Local pendingDeleteId` 字段，消除竞态与共享可变状态，符合单一数据源与最小状态原则。
- `swipeTrashBuilder(id: string)` 参数化，每个删除回调独立捕获正确的 ID，避免布局期 builder 覆盖问题。
- 完全复用歌单修复的成熟方案，保持两处代码风格一致，降低维护成本。

## 实现细节
- 性能：仅移除一个字段、改为参数传递，无额外渲染开销；ForEach 已使用 `item.id` 作为 key，删除后列表能正确增量更新。
- 兼容性：保持现有 bindSheet 面板、选中态维护（onDelete 内 selectedId 调整逻辑）、Toast 提示与 refreshSourceList() 刷新不变，仅调整 ID 传递链路。

## 架构设计
本次为局部逻辑修复，不涉及架构变更，沿用现有 AudioSourceSection → AudioSourceManager 调用链。

## 目录结构
```
features/mine/src/main/ets/view/
└── AudioSourceSection.ets   # [MODIFY] 移除 @Local pendingDeleteId 字段；将 swipeTrashBuilder 改为接收 id 参数，onClick 直接调用 onDelete(id)；swipeAction builder 改为 this.swipeTrashBuilder(item.id)，删除 pendingDeleteId 赋值。
```

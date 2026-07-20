---
name: fix_playlist_delete_wrong_item
overview: 修复"我的页面"歌单左滑删除总是删除最后一个歌单的 bug：将共享字段 pendingDeleteId 改为通过闭包参数直接传递歌单 id。
todos:
  - id: fix-delete-id
    content: 修改 PlaylistSection.ets 删除共享 pendingDeleteId，改为 swipeTrashBuilder 传参精准删除
    status: completed
---

## 用户需求
修复"我的"页面（features/mine）歌单列表中左滑删除功能：当前点击删除按钮时，总是删除列表中的最后一个歌单，而非用户实际左滑出的对应歌单。

## 产品概述
"我的"页面歌单区域支持自建歌单 / 收藏歌单切换，并对每个歌单提供左滑删除（含取消收藏）操作。删除后应通过 ID 精准移除目标歌单并刷新列表。

## 核心功能
- 每个歌单项左滑露出删除按钮
- 点击删除按钮删除（或取消收藏）当前该项对应的歌单，而非列表末尾项
- 删除成功后弹出 Toast 并刷新列表

## 技术栈
- HarmonyOS ArkUI（ArkTS，严格模式），@ComponentV2 / @Local / @Builder
- 数据层：MusicMemoryStore 单例 + MusicDbApi 封装（已按 id 正确删除，无需改动）

## 实现方案
### 问题根因
`PlaylistSection.ets` 使用共享可变状态 `@Local pendingDeleteId` 记录待删除歌单 ID：
- swipeAction 的 builder 在列表初次布局时会对每个 ListItem 调用一次以测量尺寸，导致 `pendingDeleteId` 被逐个覆盖，最终只保留最后一个歌单的 ID；
- 删除按钮 onClick 读取 `this.pendingDeleteId`，因此永远删除最后一个歌单。

### 修复策略
摒弃共享状态，改为将 `playlistId` 作为 `swipeTrashBuilder` 的参数，由 swipeAction builder 在闭包中直接传入当前项的 `playlist.playlistId`，删除回调通过参数精准定位目标歌单。store 层 `deleteOwnPlaylist` / `removeCollectedPlaylist` 已按 `playlistId + playlistType` 正确 `findIndex` 删除，无需修改。

### 关键决策
- 删除 `@Local pendingDeleteId` 字段，消除竞态与共享可变状态，符合单一数据源与最小状态原则。
- `swipeTrashBuilder(playlistId: number)` 参数化，每个删除回调独立捕获正确的 ID，避免布局期 builder 覆盖问题。

## 实现细节
- 性能：仅移除一个字段、改为参数传递，无额外渲染开销；ForEach 已使用 `playlist.playlistId.toString()` 作为 key，删除后列表能正确增量更新。
- 兼容性：保持现有 Toast 提示、`loadPlaylists()` 刷新与自建/收藏两类删除分支不变，仅调整 ID 传递链路。

## 架构设计
本次为局部逻辑修复，不涉及架构变更，沿用现有 PlaylistSection → MusicDbApi → MusicMemoryStore 调用链。

## 目录结构
```
features/mine/src/main/ets/view/
└── PlaylistSection.ets   # [MODIFY] 移除 @Local pendingDeleteId 字段；将 swipeTrashBuilder 改为接收 playlistId 参数，onClick 直接调用 onDeletePlaylist(playlistId)；swipeAction builder 改为 this.swipeTrashBuilder(playlist.playlistId)，删除 pendingDeleteId 赋值。
```

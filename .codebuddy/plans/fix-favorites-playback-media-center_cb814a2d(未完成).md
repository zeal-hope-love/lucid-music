---
name: fix-favorites-playback-media-center
overview: 修复三个问题：1) 系统媒体中心收藏按钮无法切换内部状态 2) 收藏列表取消收藏后不实时移除 3) 点击正在播放的歌曲从头开始播放
todos:
  - id: add-favorite-version
    content: 在 CurrentTabState 新增 @Trace favoriteVersion 字段
    status: pending
  - id: fix-index-favorite-callback
    content: 修复 Index.ets 系统媒体中心收藏回调：调用 MusicDbApi.toggleFavorite 实现真正切换并递增 favoriteVersion
    status: pending
    dependencies:
      - add-favorite-version
  - id: fix-index-restorebar
    content: Index.ets restoreBarVisibility 中递增 favoriteVersion
    status: pending
    dependencies:
      - add-favorite-version
  - id: fix-musiclist-connect
    content: MusicListPage 改用 AppStorageV2.connect 连接 CurrentTabState，@Monitor favoriteVersion 替代 @Param refreshKey
    status: pending
    dependencies:
      - add-favorite-version
  - id: fix-same-song-tap
    content: MusicListPage.onSongTap 增加同曲判断：播放中不操作，暂停中恢复播放
    status: pending
  - id: remove-refreshkey-prop
    content: Index.ets navDestinationBuilder 移除 MusicListPage 的 refreshKey prop
    status: pending
    dependencies:
      - fix-musiclist-connect
---

## 用户需求

修复三个问题：

1. **系统媒体中心收藏按钮无效**：在系统锁屏/通知栏点击收藏按钮，不会实际切换收藏状态，因为 Index.ets 的回调只更新了 AVSession UI 状态，从未调用 MusicDbApi.toggleFavorite() 修改内存数据。

2. **收藏列表不实时更新**：从收藏列表进入播放页 → 取消收藏 → 返回，列表不刷新。根因是 MusicListPage 使用 `@Param refreshKey` 从 AppStorage 取值，但 NavDestination 构建后 @Param 不再更新。需改用 AppStorageV2.connect 跟踪 CurrentTabState 的响应式字段。

3. **点击当前歌曲从头播放**：在列表中点击正在播放的同一首歌，会从 0 重新开始。期望：播放中不操作，暂停中恢复播放。

## 技术方案

### 核心策略

利用 `AppStorageV2.connect` 的响应式特性：同一 `@ObservedV2` 实例被多个组件 connect 后，对 `@Trace` 字段的修改会触发所有已连接组件的 `@Monitor` 回调。这是在 V2 架构下替代 `@Param` / `@StorageProp` 实现跨组件实时通信的标准模式。

### 改动范围

共 4 个文件：

| 文件 | 改动说明 |
|------|----------|
| `CurrentTabState.ets` | 新增 `@Trace favoriteVersion`，与已有的 `refreshCounter` 区分用途 |
| `Index.ets` | 修复系统媒体中心收藏回调；restoreBarVisibility 递增 favoriteVersion |
| `MusicListPage.ets` | 改用 AppStorageV2.connect + @Monitor 替代 @Param refreshKey；onSongTap 加同曲判断 |
| `MusicInfoComponent.ets` | 不需要改——返回时 restoreBarVisibility 自动触发刷新 |

### 数据流

```
系统媒体中心收藏点击
  → AVSessionController.on('toggleFavorite', assetId)
  → Index.ets onToggleFavoriteRequested
    → MusicDbApi.toggleFavorite(Number(assetId))     // 实际切换
    → AVSessionController.updateFavoriteState(...)    // 更新系统UI
    → currentTabState.favoriteVersion++               // 通知UI刷新

播放器内收藏点击
  → MusicDbApi.toggleFavorite(songId)
  → 用户点返回
  → restoreBarVisibility()
    → currentTabState.favoriteVersion++               // MusicListPage @Monitor 触发 reload
```

### 同曲判断逻辑

`onSongTap` 中获取当前播放的 songId（通过 `appState.playQueueIds[appState.selectIndex]`）与点击歌曲的 id 比较：
- 相同且 `appState.isPlay === true` → 不操作
- 相同且 `appState.isPlay === false` → 调用 `AudioPlayerController.getInstance().play()` 恢复
- 不同 → 原有逻辑（重建队列 + playCurrent）

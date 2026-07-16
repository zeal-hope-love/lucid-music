---
name: fix-favorites-playback-media-center
overview: 修复四个问题：1) 系统媒体中心收藏按钮无法切换内部状态 2) 收藏列表取消收藏后不实时移除 3) 点击正在播放的歌曲从头播放 4) 系统媒体中心播放顺序切换与应用内状态不同步
todos:
  - id: add-favorite-version
    content: CurrentTabState 新增 @Trace favoriteVersion 字段
    status: completed
  - id: fix-index-callbacks
    content: Index.ets 修复 onToggleFavoriteRequested（真实切换收藏）和 onSetLoopModeRequested（枚举比较+同步 playModeIndex）
    status: completed
    dependencies:
      - add-favorite-version
  - id: sync-playmode-index
    content: ControlAreaComponent 在 @StorageLink('playMode') 加 @Watch 联动 playModeIndex
    status: completed
  - id: fix-musiclist-reactive
    content: MusicListPage 连接 CurrentTabState 用 @Monitor favoriteVersion 替代 @Param refreshKey，onSongTap 加同曲判断
    status: completed
    dependencies:
      - add-favorite-version
  - id: remove-refreshkey-prop
    content: Index.ets navDestinationBuilder 移除 MusicListPage 的 refreshKey prop
    status: completed
    dependencies:
      - fix-musiclist-reactive
---

## 用户需求
修复音乐播放器与系统媒体中心对接的三个问题及列表交互优化：

1. **系统媒体中心收藏按钮无效**：在锁屏/通知栏点击收藏按钮后，`Index.ets` 的回调只更新了 AVSession 的 UI 状态（且始终写 `true`，只能收藏不能取消），从未调用 `MusicDbApi.toggleFavorite()` 实际修改内存收藏数据。

2. **系统媒体中心播放顺序切换不协调**：`Index.ets` 使用魔数 `0/1/2` 比较 `avSession.LoopMode` 而非枚举值，代码脆弱；`ControlAreaComponent` 使用本地 `@State playModeIndex` 推进播放模式，系统媒体中心切换后该索引不同步，导致下次应用内点击模式错位。

3. **收藏列表不实时更新**：在收藏列表页取消收藏某首歌后，列表不会立即移除该条目。当前 `MusicListPage` 仅在导航 pop 时通过 `refreshKey` 刷新，不够即时。

4. **点击当前歌曲从头播放**：列表点击正在播放的同一首歌会调用 `playCurrent()` 重新加载从头播放。期望：播放中不响应，暂停中恢复播放。

## 技术方案

### 实现策略

四点改动共享一个核心响应式通道：在 `CurrentTabState`（全局 `@ObservedV2`）新增 `@Trace favoriteVersion` 字段。

- 收藏状态变更 → 任意位置递增 `favoriteVersion` → `MusicListPage` 通过 `AppStorageV2.connect` 监听到变化 → 仅当 `listType === 'favorite'` 时重载
- 播放模式协调 → `ControlAreaComponent` 在 `@StorageLink('playMode')` 上加 `@Watch` 联动 `playModeIndex` + 系统回调改用枚举比较

### 数据流

```
收藏变更路径:
  系统媒体中心 → Index.onToggleFavoriteRequested
    → MusicDbApi.toggleFavorite(id)
    → AVSessionController.updateFavoriteState(id, nowFav)
    → currentTabState.favoriteVersion++

  播放器内收藏按钮 → MusicInfoComponent
    → MusicDbApi.toggleFavorite(id)
    → AVSessionController.updateFavoriteState(id, nowFav)
    → 返回时 restoreBarVisibility → favoriteVersion++

  → MusicListPage.@Monitor('currentTabState.favoriteVersion')
    → if listType==='favorite' → reload → 列表即时更新

播放顺序协调:
  系统媒体中心 → Index.onSetLoopModeRequested
    → player.setPlayMode(mappedMode)  // 用枚举，非魔数
    → AppStorage('playModeIndex') := mappedIndex
    → ControlAreaComponent.@Watch syncPlayModeIndex → playModeIndex 同步

  应用内点击 → ControlAreaComponent.switchPlayMode()
    → playerController.setPlayMode(newMode)
    → AVSessionController.setPlayModeToAVSession() → 系统媒体中心同步
```

### 同曲判断逻辑

```typescript
// MusicListPage.onSongTap
const currentSongId = this.appState.playQueueIds[this.appState.selectIndex]
if (currentSongId === this.songs[index].id) {
  if (this.appState.isPlay) return          // 播放中：不操作
  AudioPlayerController.getInstance().play() // 暂停：恢复
  return
}
// 不同歌曲：原有逻辑
```

## 修改文件清单（共5个文件）

### 项目结构

```
lucid_music/
├── common/musicbasic/src/main/ets/model/
│   └── CurrentTabState.ets    # [MODIFY] 新增 @Trace favoriteVersion
├── entry/src/main/ets/pages/
│   └── Index.ets              # [MODIFY] 修复两个系统回调 + 移除 refreshKey prop
├── features/player/src/main/ets/view/
│   └── ControlAreaComponent.ets # [MODIFY] 加 @Watch 同步 playModeIndex
└── features/mine/src/main/ets/view/
    └── MusicListPage.ets       # [MODIFY] 连接 CurrentTabState + 同曲判断
```

### 详细变更说明

#### 1. CurrentTabState.ets — 新增 @Trace favoriteVersion
- **位置**: 类体，`refreshCounter` 字段之后
- **变更**: `@Trace public favoriteVersion: number = 0`
- **用途**: 作为收藏变更的全局通知通道，任何位置修改后，所有 `AppStorageV2.connect` 该实例的组件通过 `@Monitor` 自动感知

#### 2. Index.ets — 修复系统回调 + 移除 refreshKey
- **导入**: 新增 `MusicDbApi` 导入（已有）
- **onSetLoopModeRequested (L62-69)**: 用 `avSession.LoopMode` 枚举替代魔数 `0/1/2`；额外同步 `AppStorage('playModeIndex')` 到 `PlayModeSwitchList` 中的索引
- **onToggleFavoriteRequested (L71-73)**: 改为调用 `MusicDbApi.getInstance().toggleFavorite(Number(assetId))` 获取真实状态，传给 `updateFavoriteState`，递增 `favoriteVersion`
- **restoreBarVisibility (L102-105)**: 替换 `musicListRefreshKey` 计数器为 `this.currentTabState.favoriteVersion++`
- **navDestinationBuilder (L174-177)**: 移除 `MusicListPage` 的 `refreshKey` prop 传递

#### 3. ControlAreaComponent.ets — playModeIndex 同步
- **声明 (L36)**: `@StorageLink('playMode') @Watch('syncPlayModeIndex') playMode: MusicPlayMode`
- **新增方法**: `syncPlayModeIndex()` — 从 `PlayModeSwitchList` 中查找当前 `playMode` 的索引写入 `this.playModeIndex`

#### 4. MusicListPage.ets — 实时刷新 + 同曲判断
- **新增导入**: `CurrentTabState`
- **新增字段**: `@Local currentTabState: CurrentTabState = AppStorageV2.connect(...)`
- **替换**: 移除 `@Param refreshKey` 和 `@Monitor('refreshKey')`，改为 `@Monitor('currentTabState.favoriteVersion')`
- **@Monitor 逻辑**: 仅当 `this.param.listType === 'favorite'` 时才调用 `loadData()`，避免非收藏页冗余重载
- **onSongTap (L54-59)**: 增加同曲判断：当前曲+播放中→return；当前曲+暂停→play()；不同曲→原逻辑

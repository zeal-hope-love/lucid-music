---
name: direct-avsession-callbacks
overview: 将 AVSessionController 的 setLoopMode 和 toggleFavorite 回调改为类属性箭头函数，直接操作 AudioPlayerController/MusicDbApi，匹配参考项目模式，去除 Index.ets 中间转接层
todos:
  - id: refactor-avsession
    content: AVSessionController 新增 onSetLoopMode/onToggleFavorite 类属性箭头函数，移除两个 public 回调字段，注册改为传函数引用，destroy 补充 off 注销，新增 currentTabState 字段用于 favoriteVersion 递增
    status: completed
  - id: cleanup-index
    content: Index.ets 移除 avSession/MusicPlayMode/PlayModeSwitchList import 及 onSetLoopModeRequested/onToggleFavoriteRequested 接线块
    status: completed
    dependencies:
      - refactor-avsession
---

## 用户需求
参考官方 avplayer-play-formatted-audio-arkts 项目模式，将 AVSession 的 `setLoopMode` 和 `toggleFavorite` 回调从"匿名闭包 + public 回调字段 + Index.ets 中间转接"改为"类属性箭头函数 + 直接调用"，解决系统媒体中心切换播放顺序和收藏不生效的问题。

## 核心改动
1. AVSessionController 新增 `onSetLoopMode` 和 `onToggleFavorite` 两个类属性箭头函数，内部直接调用 `AudioPlayerController.setPlayMode()` 和 `MusicDbApi.toggleFavorite()`
2. 回调注册改为传函数引用 `this.onSetLoopMode`（而非匿名闭包）
3. 移除 `onSetLoopModeRequested` / `onToggleFavoriteRequested` 两个 public 回调字段
4. `destroy()` 补充 `off('setLoopMode')` / `off('toggleFavorite')`
5. Index.ets 移除相关 import 和接线代码
6. onToggleFavorite 中通过 `AppStorageV2.connect` 获取 CurrentTabState 递增 favoriteVersion


## 技术方案

### 改动文件（2个）

**1. features/player/src/main/ets/controller/AVSessionController.ets**

新增 import：`AudioPlayerController`（同模块）、`MusicDbApi`/`CurrentTabState`/`AppStorageKeys`（musicbasic）、`AppStorageV2`（@kit.ArkUI）、`PlayModeSwitchList`（constants）

- 新增字段：`@Local currentTabState: CurrentTabState = AppStorageV2.connect(...)`
- 移除字段：`onSetLoopModeRequested`、`onToggleFavoriteRequested`
- 新增类属性箭头函数：

```typescript
private onSetLoopMode: (loopMode: avSession.LoopMode) => void = (loopMode) => {
  let mappedMode: MusicPlayMode
  if (loopMode === avSession.LoopMode.LOOP_MODE_SINGLE) {
    mappedMode = MusicPlayMode.SINGLE_CYCLE
  } else if (loopMode === avSession.LoopMode.LOOP_MODE_SHUFFLE) {
    mappedMode = MusicPlayMode.RANDOM
  } else {
    mappedMode = MusicPlayMode.ORDER
  }
  AudioPlayerController.getInstance().setPlayMode(mappedMode)
  const idx = PlayModeSwitchList.indexOf(mappedMode)
  if (idx >= 0) {
    AppStorage.setOrCreate('playModeIndex', idx)
  }
}

private onToggleFavorite: (assetId: string) => void = (assetId: string) => {
  const songId = parseInt(assetId)
  if (isNaN(songId)) { return }
  const nowFav = MusicDbApi.getInstance().toggleFavorite(songId)
  this.updateFavoriteState(assetId, nowFav)
  this.currentTabState.favoriteVersion++
}
```

- `setListenerForControllerEvents()`：setLoopMode 改为 `this.avSessionImpl.on('setLoopMode', this.onSetLoopMode)`，toggleFavorite 改为 `this.avSessionImpl.on('toggleFavorite', this.onToggleFavorite)`
- `destroy()`：补充 `this.avSessionImpl.off('setLoopMode')` 和 `this.avSessionImpl.off('toggleFavorite')`

**2. entry/src/main/ets/pages/Index.ets**

- 移除 `import { avSession } from '@kit.AVSessionKit'`
- player import 中移除 `MusicPlayMode, PlayModeSwitchList`
- `wireAVSessionCallbacks()` 移除 `onSetLoopModeRequested` 和 `onToggleFavoriteRequested` 两个接线块（保留 play/pause/next/prev/seek 五个接线不变）

### 影响评估
- `onSetLoopModeRequested` / `onToggleFavoriteRequested` 两个字段仅被 Index.ets 使用，移除后无其他引用方
- `ControlAreaComponent` 已有 `@Watch syncPlayModeIndex`，LoopMode 变化后自动同步 UI
- MusicListPage 已通过 `@Monitor currentTabState.favoriteVersion` 监听收藏变化


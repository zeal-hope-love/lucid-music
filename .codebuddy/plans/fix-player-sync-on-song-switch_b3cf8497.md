---
name: fix-player-sync-on-song-switch
overview: 修复切歌时详细页/媒体中心不同步问题：PlaybackPage 传入的 songList/selectIndex 在切歌后不更新导致详细页显示旧歌曲信息；切歌时进度条不复位；切歌后上一首继续播放。
todos:
  - id: add-sync-method
    content: 在 AudioPlayerController.ets 新增 syncStateForNewSong() 私有方法：归零 progress/currentTime/progressMax/totalTime（V2+V1）、同步 songList 到 V1、同步 isFavorite 到 V1
    status: completed
  - id: update-switch-methods
    content: 修改 playNext/playPrevious/switchToIndex/playSongAt 四个方法：在索引更新后、playCurrent 前调用 syncStateForNewSong()，移除分散的 AppStorage.setOrCreate('selectIndex')
    status: completed
    dependencies:
      - add-sync-method
---

## 问题描述
网易云音乐切歌后，详细页与媒体中心不同步：
- 详细页仍显示旧歌曲封面/歌名
- 媒体中心（AVSession）正确显示新歌曲
- 上一首歌曲的进度条没有归零

## 根因
- V1 AppStorage 的 `songList` 只在 `PlaybackPage.syncCurrentSongToAppStorage()` 中写入，该方法仅 `aboutToAppear()` 时运行。切歌时用户不离开详情页，`songList` 永不更新
- `playNext()`/`playPrevious()`/`switchToIndex()`/`playSongAt()` 只更新 V1 的 `selectIndex`，不更新 `songList`
- `PlayerInfoComponent` 用 `songList[selectIndex]` 渲染 UI → `selectIndex` 变了但 `songList` 不变 → 显示旧数据
- AVSessionController 从 V2 `getCurrentSongItem()` 获取元数据 → 始终正确
- 切歌时 V1/V2 的 `progress`/`currentTime` 没有重置为 0

## 修复方案
在 `AudioPlayerController.ets` 中新增 `syncStateForNewSong()` 私有方法，在每次切歌开始时统一执行：
1. 重置进度：V2 + V1 的 `progress`/`currentTime`/`progressMax`/`totalTime` 归零
2. 同步 songList：从 V2 构建新 songList 数组写入 V1 AppStorage
3. 同步 isFavorite：从 V2 读取写入 V1

在 `playNext()`/`playPrevious()`/`switchToIndex()`/`playSongAt()` 中索引更新后、`playCurrent()` 前调用该方法。

涉及文件：仅 `features/player/src/main/ets/controller/AudioPlayerController.ets`

## 技术栈
- HarmonyOS ArkUI TypeScript
- AppStorageV2 + AppStorage (V1) 双态同步

## 实现方案

### 新增私有方法 `syncStateForNewSong()`
```typescript
private syncStateForNewSong(): void {
    // 1. 重置进度 (V2 + V1)
    this.appState.progress = 0
    this.appState.currentTime = '00:00'
    this.appState.progressMax = 0
    this.appState.totalTime = '00:00'
    AppStorage.setOrCreate('progress', 0)
    AppStorage.setOrCreate('currentTime', '00:00')
    AppStorage.setOrCreate('progressMax', 0)
    AppStorage.setOrCreate('totalTime', '00:00')

    // 2. 同步 songList 到 V1
    const songItem = this.appState.getCurrentSongItem()
    if (songItem) {
        const list: Object[] = [songItem as Object]
        AppStorage.setOrCreate('songList', list)
        AppStorage.setOrCreate('selectIndex', 0)
    }

    // 3. 同步 isFavorite 到 V1
    const item = this.appState.getCurrentSongItem()
    if (item) {
        const fav = MusicDbApi.getInstance().isFavorite(item.id)
        this.appState.isFavorite = fav
        AppStorage.setOrCreate('isFavorite', fav)
    }
}
```

### 修改 4 个切歌方法

**playNext()**：`remoteSongItem = null` 之后、`playCurrent()` 之前调用 `syncStateForNewSong()`
**playPrevious()**：同上
**switchToIndex()**：`selectIndex` 更新后、`playCurrent()` 前调用
**playSongAt()**：`selectIndex` 更新后、`playCurrent()` 前调用

### 设计要点
- `selectIndex` 在 songList 中始终为 0（当前歌曲总在首位）
- `syncStateForNewSong()` 放入 V1 selectIndex 的写入，移除切歌方法中分散的 `AppStorage.setOrCreate('selectIndex', ...)`
- 进度归零必须在 `playCurrent()` → `loadAndPlay()` → `avPlayer.reset()` 之前执行，防止 reset 触发的 timeUpdate 写入旧值

---
name: fix-remote-playback-media-center-sync
overview: 修复网易云远程歌曲播放时媒体中心不触发、详细页不同步、切歌不停播的问题
todos:
  - id: pre-init-avsession
    content: Index.ets 的 aboutToAppear 第 50 行后增加 AVSessionController.getInstance().initAVSession() 提前激活媒体中心
    status: completed
  - id: make-sync-public
    content: AudioPlayerController.ets 中 syncStateForNewSong 访问修饰符从 private 改为 public
    status: completed
  - id: fix-dispatcher
    content: PlaybackIntentDispatcher.ets 中 remoteSongItem 赋值后、playCurrent 前：设置 appState.isPlay=true 并调用 controller.syncStateForNewSong()
    status: completed
    dependencies:
      - make-sync-public
---

## 用户需求
修复网易云远程歌曲播放时的三个问题：
1. 首次播放时媒体中心（系统播控中心）不出现
2. 播放详细页封面/歌名与媒体中心显示不一致
3. 切歌操作（上一首/下一首）后旧歌曲继续播放不暂停，进度条不复位

## 修复范围
三处精确修改，不改动架构：
- Index.ets：aboutToAppear 中提前初始化 AVSession
- AudioPlayerController.ets：syncStateForNewSong 访问修饰符从 private 改为 public
- PlaybackIntentDispatcher.ets：设置 isPlay + 调用 syncStateForNewSong

## 技术栈
- HarmonyOS ArkUI (TypeScript)
- AVSession（avSession.createAVSession + activate — 系统媒体中心）
- AppStorageV1/V2 双态同步

## 根因与修复对照

### 问题 1：首次远程播放媒体中心不出现

**根因**：`AVSessionController.initAVSession()` 创建 + 激活 AVSession 发生在 AVPlayer `'prepared'` 回调中（AudioPlayerController 第 355-360 行），紧接着 `waitPlay=true` 就 `play()`。`createAVSession` + `activate()` 是系统级异步调用，首次调用时注册可能来不及，导致音频已播放但系统媒体中心未识别到 session。第二次播放时 `avSessionImpl` 已存在，`initAVSession()` 直接 return（第 40-42 行判断），所以正常。

**修复**：在 `Index.aboutToAppear()` 第 50 行 `AudioPlayerController.getInstance().initAVPlayer()` 之后，增加 `AVSessionController.getInstance().initAVSession()` 调用，提前激活 AVSession，确保首次播放前媒体中心已就绪。

### 问题 2：详细页与媒体中心不同步

**根因**：远程播放路径 `dispatchShellPlaybackIntent → playCurrent()` 跳过了 `syncStateForNewSong()`。V1 的 `songList` 和 `selectIndex` 不被更新，而 `PlayerInfoComponent` 依赖 `songList[selectIndex]` 渲染封面/歌名。媒体中心通过 AVSession 直接从 V2 获取信息，所以媒体中心正确、详细页错误。

**修复**：`PlaybackIntentDispatcher` 在设置 `remoteSongItem` 后、`playCurrent()` 前，调用 `AudioPlayerController.getInstance().syncStateForNewSong()`（需先改为 public）。

### 问题 3：切歌后旧歌继续播放

**根因**：`syncStateForNewSong()` 未被远程播放路径调用，但更关键的是远程歌曲只有一首时 `playNext()/playPrevious()` 因 `getQueueLength() === 0` 直接 return，不做任何处理。不过此场景下无下一首歌可切换，行为本身合理。真正导致旧歌不停的原因是问题 2 的延伸——状态不一致使错误信号传递。

**修复**：与问题 2 相同，统一远程播放路径的状态同步。

---
name: restore-loopmode-button
overview: 恢复系统媒体中心播放顺序按钮：重新注册 setLoopMode 监听（系统据此决定是否显示按钮），并在 AVSession 初始化时立即同步当前播放模式
todos:
  - id: restore-avsession-listener
    content: AVSessionController 恢复 onSetLoopModeRequested 回调字段和 setLoopMode 监听注册
    status: completed
  - id: restore-index-wiring
    content: Index.ets 恢复 avSession import 和 onSetLoopModeRequested 接线（LoopMode 映射 + playModeIndex 同步）
    status: completed
    dependencies:
      - restore-avsession-listener
  - id: sync-init-playmode
    content: AudioPlayerController.initSessionMetadata 中增加初始 playMode 同步到系统媒体中心
    status: completed
---

## 问题
移除 setLoopMode 监听后，系统媒体中心的播放顺序切换按钮消失。HarmonyOS 通过是否注册 `setLoopMode` 回调来判断是否显示该按钮。

## 修复内容
1. **AVSessionController** — 恢复 `onSetLoopModeRequested` 回调字段声明和 `on('setLoopMode', ...)` 监听注册，使系统识别到 app 支持播放模式切换
2. **Index.ets** — 恢复 `onSetLoopModeRequested` 接线，将系统 `avSession.LoopMode` 映射为 `MusicPlayMode`，并同步 `playModeIndex` 到 AppStorage
3. **AudioPlayerController** — 在 `initSessionMetadata()` 中 AVSession 初始化后立即调用 `setPlayModeToAVSession(this.playMode)`，同步初始播放模式到系统媒体中心

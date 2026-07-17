---
name: fix-background-task-callback
overview: 将后台长时任务的启停从 AudioPlayerController 的 play/pause 方法移到 AVPlayer 状态回调中，确保首次播放（从 idle/initialized 状态）也会正确申请后台保活任务。
todos:
  - id: fix-state-callback
    content: 在 AudioPlayerController 的 stateChangeCallback 中接入 startBgTask/stopBgTask，并用私有辅助方法消除重复
    status: completed
---

## 问题
首次播放时后台长时任务未触发，导致息屏 1 分多钟后进程被杀。

## 根因
`BackgroundUtil.startContinuousTask` 仅在 `play()` 方法 state 检查**通过后**才调用。首次播放流程中 state 为 idle/initialized 时 `play()` 直接 return，随后在 `stateChangeCallback` 的 prepared 分支中通过 `this.avPlayer!.play()` 进入 playing 状态，全程**绕过** `startContinuousTask` 调用。

## 修复
在 `stateChangeCallback` 的状态分支中接入 `startContinuousTask` / `stopContinuousTask`，使后台任务与 **实际播放状态** 绑定而非与 public 方法调用绑定。同时保留 public `play()`/`pause()`/`release()` 中已有的调用作为兜底。

## 修改范围
仅修改 `features/player/src/main/ets/controller/AudioPlayerController.ets` 一个文件。

## 修改方案

### 1. 抽取私有辅助方法
避免 context 获取逻辑重复，封装两个私有方法：

```
private startBgTask(): void — 从 AppStorage 获取 context 并调用 BackgroundUtil.startContinuousTask
private stopBgTask(): void  — 从 AppStorage 获取 context 并调用 BackgroundUtil.stopContinuousTask
```

### 2. stateChangeCallback 接入
在 `stateChangeCallback` 的 switch-case 中添加：

| 状态 | 操作 | 说明 |
|------|------|------|
| `playing` | `startBgTask()` | 实际开始播放时申请后台长时任务（覆盖首次播放和切歌恢复） |
| `paused` | `stopBgTask()` | 暂停时取消后台长时任务 |
| `stopped` | `stopBgTask()` | 停止时取消 |
| `completed` | `stopBgTask()` | 播放完成时取消（playNext 会重新触发 playing 再申请） |

### 3. public 方法保留兜底
`play()`（state 通过时）、`pause()`、`release()` 中已有调用不变，替换为 `startBgTask()`/`stopBgTask()` 以消除重复代码。

### 4. completed 分支顺序
`completed` 先调 `stopBgTask()` 再调 `playNext()`，确保切歌时先取消旧任务，后续新歌 playing 回调重新申请。

## 覆盖的所有播放路径

| 路径 | startBgTask 触发点 |
|------|-------------------|
| 首次播放 (idle → playing) | stateChangeCallback 'playing' |
| 暂停恢复 (paused → playing) | public play() + stateChangeCallback 'playing'（重复调用无副作用） |
| 切歌 (completed → next playing) | playNext → loadAndPlay → 'playing' 回调 |
| 音频中断恢复 (INTERRUPT_SHARE → play) | public play() + stateChangeCallback 'playing' |

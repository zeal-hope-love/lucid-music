---
name: fix-media-center-sync-and-failed-songs
overview: 修复三个问题：失败歌曲进度条跳、切歌后媒体中心不更新、QQ/网易云媒体中心元数据不显示。
todos:
  - id: fix-empty-url
    content: PlaybackIntentDispatcher.ets：songItem.src 为空时主动停止播放 + 清理状态（pause + error status + isPlay=false），不再静默跳过
    status: completed
  - id: fix-timeupdate-guard
    content: AudioPlayerController.ets：timeUpdate 回调加 currentState==='playing' 守卫，防止 stopped/idle 状态时旧回调污染进度
    status: completed
  - id: fix-playcurrent-empty
    content: AudioPlayerController.ets：playCurrent() 中 url 为空时主动停止旧 AVPlayer 播放并重置 isPlay
    status: completed
  - id: fix-initmetadata-log
    content: AudioPlayerController.ets：initSessionMetadata() 改进 catch 日志，从 Logger.warn 改为 Logger.error 并打印异常详情
    status: completed
  - id: fix-avsession-metadata
    content: AVSessionController.ets：updateMetadata() 中封面下载失败时仍调用 setAVMetadata（不含 mediaImage），确保 title/artist/duration 必达媒体中心
    status: completed
---

## 用户需求
修复三个互相关联的播放问题：
1. "获取播放地址失败"的歌曲播放后进度条持续跳动
2. QQ/网易云平台媒体中心元数据（歌名、歌手、封面）不显示，只有酷狗正常
3. 切歌后应用停止播放但媒体中心状态不更新（仍显示旧歌曲）

## 产品概述
确保所有平台（酷狗、QQ、网易云）的媒体中心元数据正常同步，修复获取播放地址失败时的状态异常，保证切歌后媒体中心状态与应用一致。

## 核心功能
- 获取播放地址失败的歌曲：不触发播放、不残留进度跳动
- QQ/网易云媒体中心：元数据（歌名、歌手、封面）正确上传到系统播控中心
- 切歌操作：媒体中心的播放状态、歌曲信息与应用同步更新

## 技术栈
- HarmonyOS ArkUI (TypeScript)
- AVPlayer 状态机 (idle→initialized→prepared→playing)
- AVSession (系统媒体中心)
- AppStorageV1/V2 双态同步

## 实现方案

### 问题1：空URL歌曲进度条跳动

**根因**：`SearchResultViewModel.playSong()` 获取播放地址失败后 `remoteUrl=''`，但仍 `requestVersion++` 触发 `dispatchShellPlaybackIntent`。因 `songItem.src` 为空跳过 `playCurrent()`，但旧 AVPlayer 仍在 running 状态，`timeUpdate` 回调持续更新 `appState.progress`。

**修复**：`PlaybackIntentDispatcher.ets` 中，`songItem.src` 为空时主动清理状态——`syncPlaybackStatus('error', ...)` + 暂停正在播放的音频 + 重置 `isPlay`，不触发新播放。

### 问题2：QQ/网易云媒体中心元数据不显示

**根因**：`initSessionMetadata()` 的 try-catch 静默吞全部异常，无法定位问题。`updateMetadata()` 中 cover HTTP download 超时 5s 后可能抛异常被吞，导致后续 `setAVMetadata()` 不执行。

**修复**：
- `initSessionMetadata()`：将 `Logger.warn('AVSession init skipped')` 改为 `Logger.error` 并打印异常详情
- `updateMetadata()`：封面下载失败后仍确保 `setAVMetadata` 被调用（title/artist/duration 必达）
- `AVSessionController.updateMetadata()`：封面下载失败时用空 mediaImage 而非中断整个 metadata 设置

### 问题3：切歌后媒体中心状态不更新

**根因**：切歌时 `playNext()` → `playCurrent()` → `loadAndPlay()` → `avPlayer.reset()` 触发 'stopped' 回调 → `updateIsPlay(false)` 调用 `setPlayState(false)`。但新歌 'prepared' 回调中 `initSessionMetadata()` 若失败，媒体中心既不更新元数据也不更新播放状态。

**修复**：
- `timeUpdate` 回调加守卫：仅在 `currentState === 'playing'` 时更新进度，防止 stopped/idle 状态下旧回调污染
- `playCurrent()` 中 url 为空时：停止旧播放 + 设置 `isPlay=false` + 媒体中心 `setPlayState(false)`

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `PlaybackIntentDispatcher.ets` | src 为空时回退：`AudioPlayerController.pause()` + `syncPlaybackStatus('error', ...)` + `appState.isPlay = false` |
| `AudioPlayerController.ets` | `timeUpdate` 加状态守卫；`playCurrent` url 空时停止旧播放；`initSessionMetadata` 改进日志 |
| `AVSessionController.ets` | `updateMetadata` 中封面失败后仍调用 `setAVMetadata`（不含 mediaImage） |

---
name: fix-five-bugs-music-player
overview: 修复 5 个 bug：收藏/列表不刷新、MinePage 数量不刷新、MiniPlayerBar 按钮无效、延迟消失、系统媒体中心无封面/歌词/进度条
todos:
  - id: fix-refresh-mechanism
    content: Index.ets restoreBarVisibility 递增 musicListRefreshKey 和 mineCountRefreshKey 计数器；MusicList NavDestination 传 refreshKey；MinePage @Monitor 监听 mineCountRefreshKey；MusicListPage @Param refreshKey + @Monitor 重载
    status: completed
  - id: fix-minibar-buttons
    content: Index.ets MiniPlayerBar 补充 onPlayPause→togglePlay() 和 onNext→playNext() 回调
    status: completed
  - id: fix-playback-delay
    content: Index.ets Playback onAppear 去掉 setTimeout 直接隐藏 MiniPlayerBar；PlayerInfoComponent.ets 去掉 playbackEntering 的 500ms 定时器
    status: completed
  - id: fix-avsession-metadata
    content: AVSessionController.updateMetadata 加入封面 PixelMap（getMediaContent+createPixelMap）+ LRC 歌词（getRawFileContent）；AudioPlayerController.timeUpdate 中调用 setProgressState 同步进度
    status: completed
---

## 问题概述
修复 5 个 bug：

1. **收藏/最近播放列表不实时刷新**：在列表页→进入播放页→取消收藏→返回，列表数据不更新，需要退出重进才刷新
2. **MinePage 三格数量不实时刷新**：从子页面 pop 回 tab 后，收藏/最近播放数量不变，需切换 tab 才刷新
3. **MiniPlayerBar 播放/暂停和下一首按钮无效**：MiniPlayerBar 定义了 onPlayPause 和 onNext 事件，但 Index.ets 未传入回调
4. **控制栏进入播放页时 MiniPlayerBar 延迟消失**：Playback NavDestination onAppear 中 setTimeout 500ms 延迟隐藏
5. **系统媒体中心无封面、歌词、进度条**：AVSessionController.updateMetadata 只设 title/artist/duration，缺少 mediaImage 和 lyric；timeUpdate 未调用 setProgressState 同步进度

## 参考项目
`C:\Users\PoXia\DevEcoStudioProjects\avplayer-play-formatted-audio-arkts` 的 AVSessionController 实现了完整的封面 PixelMap（resourceManager.getMediaContent→image.createImageSource→createPixelMap）、歌词 rawfile 读取（getRawFileContent→LRC 字符串→metadata.lyric）、进度同步（timeUpdate→setAVPlaybackState position）


## 技术方案

### Bug1+Bug2：刷新机制

**策略**：使用 AppStorage 计数器作为刷新信号。
- Index.ets 的 `restoreBarVisibility()` 中（pop 回到 tab 时执行），递增两个 AppStorage 计数器：`musicListRefreshKey` 和 `mineCountRefreshKey`
- MusicListPage 新增 `@Param refreshKey: number = 0` + `@Monitor('refreshKey')` 重新加载数据
- MusicList NavDestination 中传入 `refreshKey: AppStorage.get('musicListRefreshKey') ?? 0`
- MinePage 新增 `@Monitor('mineCountRefreshKey')` 调用 refreshCounts()

### Bug3：MiniPlayerBar 按钮

**策略**：Index.ets 补充 onPlayPause 和 onNext 回调。
```typescript
MiniPlayerBar({
  barWidth: ...,
  onPlayPause: () => AudioPlayerController.getInstance().togglePlay(),
  onNext: () => AudioPlayerController.getInstance().playNext(),
  onTap: () => { ... }
})
```

### Bug4：去掉延迟

**策略**：
- Index.ets Playback onAppear：`setTimeout` 改为直接 `miniPlayerVisible = false`
- PlayerInfoComponent.ets aboutToAppear：去掉 `setTimeout(() => { this.playbackEntering = false }, 500)`

### Bug5：AVSession 封面+歌词+进度

**策略**：
- AVSessionController.updateMetadata 新增封面 PixelMap（从 MusicAppState.getCurrentSongItem().label Resource 获取）和歌词（rawfile 读取 LRC 字符串）
- AudioPlayerController.timeUpdateCallback 中调用 avSessionController.setProgressState(time)
- AudioPlayerController.initSessionMetadata 中传递 SongItem 给 updateMetadata

**封面获取**（参考 avplayer-play-formatted）：
```typescript
const resourceMgr = context.resourceManager
const fileData = await resourceMgr.getMediaContent(labelResource.id)
const mediaImage = await image.createImageSource(fileData.buffer).createPixelMap()
```

## 改动文件

| 文件 | 改动 |
|------|------|
| `Index.ets` | Bug1: MusicList NavDestination 传 refreshKey；restoreBarVisibility 递增计数器；Bug2: 同上；Bug3: MiniPlayerBar 补充 onPlayPause/onNext；Bug4: 去掉 setTimeout |
| `MusicListPage.ets` | Bug1: 新增 @Param refreshKey + @Monitor 重载 |
| `MinePage.ets` | Bug2: 新增 @Monitor('mineCountRefreshKey') 刷新 |
| `AVSessionController.ets` | Bug5: updateMetadata 加封面 PixelMap + 歌词；新增 setProgressState |
| `AudioPlayerController.ets` | Bug5: timeUpdate 中调 setProgressState；initSessionMetadata 传 SongItem |
| `PlayerInfoComponent.ets` | Bug4: 去掉 playbackEntering setTimeout |


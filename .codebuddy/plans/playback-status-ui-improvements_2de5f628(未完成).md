---
name: playback-status-ui-improvements
overview: 修复搜索点击后播放状态不更新的问题，添加播放状态反馈机制，重新设计 MiniPlayerBar 布局（歌名-歌手 + 滚动歌词/状态），在播放详情页进度条上方显示状态信息
todos:
  - id: add-getplayurl-api
    content: 在 MusicApiService.ets 中添加 getPlayUrl() 方法，实现五大平台的播放 URL 获取
    status: pending
  - id: add-playback-status
    content: 在 MusicAppState.ets 中添加 playbackStatus 和 playbackStatusMessage 字段，在 AudioPlayerController.ets 中更新状态
    status: pending
  - id: fix-search-play-flow
    content: 重写 SearchResultViewModel.playSong()：获取播放 URL 后设置 PlaybackIntentState 远程字段，在 SearchPage.ets 中添加列表点击反馈
    status: pending
    dependencies:
      - add-getplayurl-api
      - add-playback-status
  - id: fix-dispatcher-remote
    content: 修改 PlaybackIntentDispatcher.ets：检测 remoteUrl 非空时创建 remoteSongItem 并赋值给 appState.remoteSongItem
    status: pending
    dependencies:
      - fix-search-play-flow
  - id: redesign-minibar
    content: 重新设计 MiniPlayerBar.ets 为双行布局：上行歌名-歌手，下行歌词滚动或状态信息
    status: pending
    dependencies:
      - add-playback-status
  - id: add-status-to-control
    content: 在 ControlAreaComponent.ets 进度条上方添加播放状态文字显示
    status: pending
    dependencies:
      - add-playback-status
  - id: verify-audiosource-init
    content: 验证 AudioSourceSection.ets 的初始化状态逻辑完整性，确保导入后选中显示初始化中→成功/失败
    status: pending
---

## 用户需求

1. **音源导入后无初始化状态**：导入音源后选中时，应显示初始化状态（初始化中/成功/失败）
2. **搜索点击后播放信息不更新**：点击搜索结果后直接跳出播放详情页，但信息一直是"Dream It Possible"，没有更新为所选歌曲
3. **列表需要点击反馈**：搜索结果列表点击时应有视觉反馈（高亮）
4. **控制栏（MiniPlayerBar）UI 改造**：上方显示"歌名-歌手"，下方显示歌词（显示不下时滚动），播放请求时下方显示状态信息
5. **播放详情页进度条上方显示状态**：请求播放时在进度条上方显示当前信息（请求中/请求URL/请求失败等）

## 核心功能

- **搜索结果→播放 URL→远程播放完整链路**：点击搜索结果→调用平台 API 获取播放 URL→通过 `PlaybackIntentState` 远程字段传递→`PlaybackIntentDispatcher` 创建 `remoteSongItem`→`AudioPlayerController` 播放
- **播放状态追踪**：在 `MusicAppState` 中添加 `playbackStatus` 和 `playbackStatusMessage`，贯穿"请求URL→加载→就绪→错误"全生命周期
- **MiniPlayerBar 双行布局**：上行歌名-歌手（省略号溢出），下行歌词或状态信息（超长滚动）
- **ControlAreaComponent 状态提示**：进度条上方条件显示播放状态文字
- **列表点击反馈**：搜索结果项点击时短暂高亮

## 技术方案

### 整体策略

核心思路是打通"搜索结果→可播放音频"的完整数据链路。目前搜索只返回歌曲元数据（歌名、歌手、封面等），缺少 `src` 字段。需要在 `MusicApiService` 中新增 `getPlayUrl()` 方法，利用已有的 `PlaybackIntentState.remote*` 字段将播放 URL 和歌曲信息传递给播放器。

### 数据流

```
用户点击搜索结果
  ↓
SearchResultViewModel.playSong(item)
  ├── 设置 appState.playbackStatus = 'loading'
  ├── await MusicApiService.getPlayUrl(item.songId, item.source)
  ├── intentState.remoteUrl = url
  ├── intentState.remoteSongName = item.title
  ├── intentState.remoteSongSinger = item.singer
  ├── intentState.remoteSongCover = item.coverUrl
  └── intentState.requestVersion++
        ↓
Index.ets @Monitor → dispatchShellPlaybackIntent()
  ├── 检测 remoteUrl 非空 → 创建 remoteSongItem
  ├── appState.remoteSongItem = { id, title, singer, src, coverUrl }
  ├── intentState.resetRemote()
  └── onOpenPlayerUi() → push PlaybackPage
        ↓
AudioPlayerController.loadAndPlay(url)
  ├── appState.playbackStatus = 'preparing'
  ├── AVPlayer 状态机 → prepared/playing/error
  └── appState.playbackStatus = 'ready' / 'error'
```

### 关键设计决策

1. **播放 URL 获取放在 SearchResultViewModel**：用户在搜索结果页点击时执行，下载播放 URL 是异步操作，不影响 UI 响应
2. **使用已有 remote* 字段**：`PlaybackIntentState` 已有 `remoteUrl`/`remoteSongName`/`remoteSongSinger`/`remoteSongCover`，无需新增字段
3. **状态追踪在 MusicAppState**：与播放相关的全局状态放在 `MusicAppState`（已通过 AppStorageV2 全局共享），各 UI 组件通过 `@Local` 订阅
4. **歌词滚动使用 textOverflow MARQUEE**：ArkUI 原生支持 `TextOverflow.MARQUEE`，无需额外动画逻辑

### 实现要点

- `MusicApiService.getPlayUrl()` 为每个平台实现：Kugou（hash 查 URL）、QQ（songmid 查 URL）、网易云（songid 查 URL）、酷我（musicrid 查 URL）、咪咕（copyrightId 查 URL），均参考 lx-music-mobile
- `dispatchShellPlaybackIntent()` 中创建 `remoteSongItem`：构造 `SongItem` 对象，设置 `id`、`title`、`singer`、`src`、`coverUrl`
- `AudioPlayerController` 在 `loadAndPlay`/`stateChangeCallback`/`errorCallback` 中更新 `playbackStatus`
- `MiniPlayerBar` 重构 `miniBarContent`：Column 内两个 Row，上行 Text 省略号，下行 Text 根据状态切换内容（歌词 MARQUEE 或状态文本）
- `ControlAreaComponent` 在进度条 Column 顶部添加 `if (playbackStatus)` 条件 Text

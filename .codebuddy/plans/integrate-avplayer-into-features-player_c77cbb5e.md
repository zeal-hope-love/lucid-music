---
name: integrate-avplayer-into-features-player
overview: 参考 avplayer 架构，将公共播放状态/播放列表管理整合到 common/musicbasic，UI 直接使用 avplayer 的完整视图层，PlaybackPage 用默认滑入动画，补全 AVSession 的 loopMode/favorite 功能。
todos:
  - id: copy-constants
    content: 复制 avplayer 5 个常量文件到 features/player/src/main/ets/constants：PlayerConstants.ets（含 MusicPlayMode 枚举）、LyricConst.ets、BreakpointConstants.ets、StyleConstants.ets、ContentConstants.ets
    status: completed
  - id: copy-model
    content: 复制 avplayer 数据层 5 个文件：SongListData.ets（model/）、SongData.ets+SongDataSource.ets+SongItemBuilder.ets+LrcEntry.ets（viewmodel/）
    status: completed
  - id: copy-utils
    content: 复制 avplayer 5 个工具文件到 features/player/src/main/ets/utils：LrcUtils.ets、ColorConversion.ets、BreakpointSystem.ets、PreferencesUtil.ets、ResourceConversion.ets，创建 LoggerAdapter.ets 重导出 musicbasic Logger
    status: completed
  - id: copy-views
    content: 复制 avplayer 6 个 View 文件到 features/player/src/main/ets/view：PlayerInfoComponent.ets、MusicInfoComponent.ets、ControlAreaComponent.ets、LyricsComponent.ets、LrcView.ets、CustomButton.ets，全局替换 MediaControlCenter→AudioPlayerController，修复 LrcView 的 TAG 导入错误
    status: completed
    dependencies:
      - copy-constants
      - copy-model
      - copy-utils
  - id: enhance-audio-controller
    content: 扩展 AudioPlayerController.ets：新增 setSpeed(speedMap)、setPlayMode(mode)（影响 playNext/playPrevious 切歌逻辑）、getCurrentVolume()、setMuted() 方法
    status: completed
    dependencies:
      - copy-constants
  - id: enhance-avsession
    content: 增强 AVSessionController.ets：添加 on('setLoopMode') 和 on('toggleFavorite') 事件监听，新增 setLoopModeState()、updateFavoriteState(assetId, isFavorite)、getAndUpdateFavoriteState() 方法，增强 setAVMetadata 添加 mediaImage 和 lyric
    status: completed
  - id: add-entry-resources
    content: 在 entry/src/main/resources/base/element 中添加 avplayer UI 依赖的 float.json(50+项)、string.json(20+项)、color.json(20+项) 资源值，同时添加 cover 占位图片资源
    status: completed
    dependencies:
      - copy-views
  - id: rebuild-playback-page
    content: 重建 PlaybackPage.ets 为桥接层：@Monitor MusicAppState 全字段同步到 AppStorage，从 playQueueIds 构造 avplayer 格式 songList，build() 直接渲染 PlayerInfoComponent，管理 isFavorite/isSilentMode/playMode 本地状态
    status: completed
    dependencies:
      - copy-views
      - enhance-audio-controller
      - enhance-avsession
      - add-entry-resources
  - id: fix-miniplayer-tap
    content: 修改 MiniPlayerBar.ets：外层 Row 增加 onClick 通过 @Event onTap 跳转 PlaybackPage，三个控制按钮（播放暂停/下一首/播放列表）onClick 用 event.stopPropagation 防止冒泡
    status: completed
  - id: update-index-exports
    content: 更新 features/player/Index.ets 导出清单：新增 PlayerInfoComponent、MusicInfoComponent、ControlAreaComponent、LyricsComponent、LrcView、LrcEntry、LrcUtils、LyricConst、ColorConversion、PreferencesUtil、SongListData、avSongItem 类名
    status: completed
    dependencies:
      - rebuild-playback-page
  - id: compile-verify
    content: 编译验证整体项目，检查 lint 错误并修复
    status: completed
    dependencies:
      - update-index-exports
      - fix-miniplayer-tap
---

## 用户需求
将 avplayer-play-formatted-audio-arkts 项目的完整播放 UI（PlayerInfoComponent 视图树）集成到 lucid_music 的 features/player 模块。

## 核心功能
- **UI 全部用 avplayer 的**：PlaybackPage 直接渲染 avplayer 的 PlayerInfoComponent（封面页 Swiper + 歌词页 + ControlAreaComponent 完整控制区）
- **媒体控制中心功能全部实现**：
  - 播放模式切换（顺序/随机/单曲循环），同步到 AppStorage 和 AVSession
  - 歌单列表 Sheet（LazyForEach + 点击切歌）
  - 静音模式（AudioConcurrencyMode 切换）
  - 倍速播放（0.25x-2.0x，Slider + Tips）
  - 音量调节（0-100，Slider Sheet）
  - 收藏（heart 图标 + preferences 持久化 + AVSession favorite 同步）
  - Canvas 歌词渲染（LrcView，支持 LRC/KRC 格式）
  - 封面主色提取 + 模糊背景
- **进入播放页使用默认左滑动画**：pushPath 不加 `animated:false`
- **MiniPlayerBar 整条可点击**：外层 Row 加 onClick 跳转，三个控制按钮用 stopPropagation 防止冒泡
- **补全 AVSession 播控中心集成**：loopMode 同步、favorite 同步、封面图(mediaImage)、歌词(lyric)元数据

## 兼容架构
```
MusicAppState (common, AppStorageV2)
    ↓ @Monitor 桥接
PlaybackPage → AppStorage.setOrCreate(key, value) 同步写入
    ↓ @StorageLink 自动绑定
avplayer 原装 UI 组件 (PlayerInfoComponent → MusicInfoComponent/ControlAreaComponent/LyricsComponent → LrcView)
    ↓ 控制调用
AudioPlayerController.getInstance() (已有播放引擎)
    ↓
AVSessionController (增强：loopMode + favorite 同步)
```

## 技术方案

### 项目现状
- **公共状态**：MusicAppState 已在 `common/musicbasic`，管理 playQueueIds、selectIndex、isPlay、progress 等核心播放状态
- **播放引擎**：AudioPlayerController（AVPlayer 封装 + AVSession 同步）已在 features/player
- **路由**：MiniPlayerBar.onTap → HomePage 已调用 `pushPath(PLAYBACK)`，Index.ets 已注册 `Playback` → `PlaybackPage()` NavDestination
- **AVSession**：已有创建/激活、play/pause/next/prev/seek 回调、元数据、播放状态、进度同步 — **缺少 loopMode 和 favorite 同步**

### 桥接层设计
PlaybackPage 作为 `@ComponentV2`，通过 `@Monitor` 监听 MusicAppState 所有关键字段变化，实时同步写入 AppStorage。avplayer UI 组件通过 `@StorageLink/@StorageProp` 自动响应。控制调用全部委托给 `AudioPlayerController.getInstance()`。

### AppStorage Key 桥接清单
| MusicAppState 字段 | AppStorage Key | 说明 |
|---|---|---|
| `selectIndex` | `selectIndex` | 当前播放索引 |
| `isPlay` | `isPlay` | 播放/暂停 |
| `progress` | `progress` | 当前进度(ms) |
| `progressMax` | `progressMax` | 总时长(ms) |
| `currentTime` | `currentTime` | 格式化当前时间 |
| `totalTime` | `totalTime` | 格式化总时长 |
| `playQueueIds` → SongItem[] | `songList` | 播放列表(avplayer 格式) |
| `imageColor` | `imageColor` | 封面主色 |
| `volume` | `currentVolume` | 音量 0-100 |
| — | `isSilentMode` | 静音状态(本地管理) |
| — | `playMode` | 播放模式(本地管理) |
| — | `isFavorite` | 收藏状态(本地管理) |
| — | `currentBreakpoint` | 固定 'sm' |
| — | `isFoldFull` | 固定 false |
| — | `pageShowTime` | 自动隐藏控制区计时 |
| — | `context` | UIAbilityContext |

### 文件整合策略

**需复制的 avplayer 文件（18 个）**：
- View（6 个）：PlayerInfoComponent.ets、MusicInfoComponent.ets、ControlAreaComponent.ets、LyricsComponent.ets、LrcView.ets、CustomButton.ets
- Model/Data（4 个）：SongListData.ets、SongData.ets、SongDataSource.ets、SongItemBuilder.ets
- Utils（5 个）：LrcUtils.ets、ColorConversion.ets、BreakpointSystem.ets、PreferencesUtil.ets、ResourceConversion.ets
- Constants（5 个）：PlayerConstants.ets（含 MusicPlayMode 枚举）、LyricConst.ets、BreakpointConstants.ets、StyleConstants.ets、ContentConstants.ets
- ViewModel（1 个）：LrcEntry.ets

**适配修改**：
- avplayer 组件内 `MediaControlCenter.getInstance()` → `AudioPlayerController.getInstance()`（全局搜索替换）
- avplayer 的 `Logger` import → features/player 本地创建 `LoggerAdapter.ets` 重导出 musicbasic Logger
- LrcView.ets 中错误引用 `import { TAG } from '@ohos/hypium'` → 修复为 `const TAG = 'LrcView'`
- avplayer SongItem 独立保存（title/singer 为 Resource | undefined），桥接层从 lucid_music SongItem 构造

**需增强的现有文件**：
- `AudioPlayerController.ets`：新增 `setSpeed()`、`setPlayMode()`、`getCurrentVolume()`、`setMuted()` 方法
- `AVSessionController.ets`：新增 `on('setLoopMode')`、`on('toggleFavorite')` 监听，`setLoopModeState()`、`updateFavoriteState()`、`getAndUpdateFavoriteState()` 方法，增强 `setAVMetadata()` 添加 mediaImage 和 lyric
- `MiniPlayerBar.ets`：外层 Row 加 onClick，按钮 stopPropagation
- `PlaybackPage.ets`：完全重建为桥接层

### 入口动画策略
PlaybackPage 的 NavDestination 不加 `.transition()` 和 `onBackPressed` 自定义逻辑，使用系统默认左滑动画：
```typescript
NavDestination() {
  PlaybackPage()
}
.hideTitleBar(true)
```
push 时使用 `pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined))` 不加 `animated:false`。

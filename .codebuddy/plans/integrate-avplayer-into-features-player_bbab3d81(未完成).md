---
name: integrate-avplayer-into-features-player
overview: 将 avplayer 项目的完整 UI（PlayerInfoComponent + 所有子组件）和媒体控制中心功能集成到 features/player，PlaybackPage 直接复用 avplayer 的视图层，适配 MusicAppState 数据桥接。MiniPlayerBar 整条可点击（除按钮）。
todos:
  - id: copy-constants
    content: 复制 avplayer 常量文件到 features/player：PlayerConstants.ets（含 MusicPlayMode 枚举）、LyricConst.ets、BreakpointConstants.ets、StyleConstants.ets、ContentConstants.ets，创建 constants 目录
    status: pending
  - id: copy-model-data
    content: 复制 avplayer 数据文件：SongListData.ets、SongData.ets（avplayer 版 SongItem）、SongDataSource.ets、SongItemBuilder.ets、LrcEntry.ets，创建 model 和 viewmodel 目录
    status: pending
  - id: copy-utils
    content: 复制 avplayer 工具文件：LrcUtils.ets、ColorConversion.ets、BreakpointSystem.ets、PreferencesUtil.ets，创建 utils 目录；创建 LoggerAdapter.ets 作为 musicbasic Logger 别名导出
    status: pending
  - id: copy-view-components
    content: 复制 avplayer View 组件：PlayerInfoComponent.ets、MusicInfoComponent.ets、ControlAreaComponent.ets、LyricsComponent.ets、LrcView.ets、CustomButton.ets，全局替换 MediaControlCenter → AudioPlayerController
    status: pending
    dependencies:
      - copy-constants
      - copy-model-data
      - copy-utils
  - id: extend-audio-controller
    content: 扩展 AudioPlayerController：新增 setSpeed()（含 speedMap）、setPlayMode()（影响切歌逻辑）、getCurrentVolume()、setMuted() 方法
    status: pending
    dependencies:
      - copy-constants
  - id: create-entry-resources
    content: 在 entry/src/main/resources 中创建 avplayer UI 依赖的 float.json、string.json、color.json 资源值
    status: pending
    dependencies:
      - copy-view-components
  - id: rebuild-playback-page
    content: 重建 PlaybackPage 为 avplayer 桥接层：@Monitor MusicAppState 同步写入 AppStorage，build() 直接渲染 PlayerInfoComponent，管理 isFavorite 等本地状态
    status: pending
    dependencies:
      - copy-view-components
      - extend-audio-controller
  - id: fix-miniplayer-tap
    content: 修改 MiniPlayerBar.ets：外层 Row 增加 onClick 跳转 PlaybackPage，控制按钮 onClick 用 stopPropagation 防止冒泡，保留现有 onTap 事件兼容
    status: pending
  - id: update-exports
    content: 更新 features/player/Index.ets 导出清单：新增 LrcView、LrcEntry、LrcUtils、LyricConst、ColorConversion、PreferencesUtil
    status: pending
    dependencies:
      - rebuild-playback-page
---

## 用户需求
将 avplayer-play-formatted-audio-arkts 项目的完整播放 UI 集成到 lucid_music 的 features/player 模块中，最小改动适配现有架构。

## 核心功能
- **UI 全部采用 avplayer 的组件树**：PlayerInfoComponent（主布局） → MusicInfoComponent（封面+收藏） + LyricsComponent（歌词页） + ControlAreaComponent（完整控制区）
- **媒体控制中心功能全部实现**：
  - 播放模式切换：顺序播放(ORDER)、随机播放(RANDOM)、单曲循环(SINGLE_CYCLE)
  - 歌单列表 Sheet：LazyForEach + 点击切歌
  - 静音模式：setMediaMuted + AudioConcurrencyMode 切换
  - 倍速播放：0.25x ~ 2.0x，步进 0.25，Slider + Tips
  - 音量调节：0-100，Slider Sheet
  - 收藏：heart 图标同步至 AVSession 播控中心
  - Canvas 歌词渲染：LrcView 支持 LRC/KRC 格式，含逐字渐变/逐字缩放/星星动画效果
  - 封面主色提取 + 模糊背景
- **MiniPlayerBar 整条可点击**：除播放暂停、下一首、播放列表三个按钮外，其余区域点击均进入 PlaybackPage
- **兼容策略**：avplayer UI 组件保持 @StorageLink/@StorageProp 不变，PlaybackPage 作为桥接层从 MusicAppState 同步数据到 AppStorage

## 技术方案

### 兼容策略（核心架构决策）
avplayer 的 UI 组件内部大量使用 `@StorageLink('isPlay')`、`@StorageProp('selectIndex')` 等直接绑定 AppStorage。为了最小化对 avplayer 源码的改动，采用 **PlaybackPage 桥接模式**：

```
MusicAppState (AppStorageV2, @ObservedV2)
        ↓ @Monitor 监听变化
PlaybackPage (桥接层)
        ↓ AppStorage.setOrCreate() 同步写入
AppStorage (传统 KV)
        ↓ @StorageLink/@StorageProp 自动绑定
avplayer UI 组件 (PlayerInfoComponent → MusicInfoComponent/ControlAreaComponent/LyricsComponent → LrcView)
        ↓ 控制调用
AudioPlayerController.getInstance() (lucid_music 播放引擎)
```

### 需从 avplayer 复制的文件（15 个）
**View 层（6 个）**：PlayerInfoComponent.ets、MusicInfoComponent.ets、ControlAreaComponent.ets、LyricsComponent.ets、LrcView.ets、CustomButton.ets
**Model/Data（4 个）**：SongListData.ets、SongData.ets（avplayer 版 SongItem）、SongDataSource.ets、SongItemBuilder.ets
**Utils（4 个）**：LrcUtils.ets、ColorConversion.ets、BreakpointSystem.ets、PreferencesUtil.ets
**Constants（5 个）**：PlayerConstants.ets（MusicPlayMode 枚举）、LyricConst.ets、BreakpointConstants.ets、StyleConstants.ets、ContentConstants.ets
**ViewModel（1 个）**：LrcEntry.ets

### 适应性修改
1. **Logger**：avplayer 的 `import Logger from '../common/utils/Logger'` → 通过本地 `LoggerAdapter.ets` 别名重导出到 `musicbasic` 的 Logger，不改 avplayer 组件内部的 import 路径
2. **控制调用替换**：`MediaControlCenter.getInstance().xxx()` → `AudioPlayerController.getInstance().xxx()`，在 ControlAreaComponent 和 MusicInfoComponent 中全局替换
3. **$r 资源引用**：avplayer 的 `$r('app.float.xx')` 等资源引用在 HAR 模块中会自动解析到 entry 资源，需要在 entry/resources 中添加对应的 float.json/string.json/color.json 资源值
4. **SongItem 结构差异**：avplayer 的 SongItem（title/singer 为 Resource）与 lucid_music 的 SongItem 不同，PlaybackPage 桥接层负责从 lucid_music playQueueIds 构造 avplayer 格式 SongItem 列表写入 AppStorage
5. **Breakpoint 固定为 'sm'**：不引入响应式断点系统，所有 `currentBreakpoint` 固定为 `'sm'`

### AudioPlayerController 扩展方法
| 方法 | 实现 |
|---|---|
| `setSpeed(speed: number)` | `avPlayer.setSpeed(speedMap.get(speed))` |
| `setPlayMode(mode: MusicPlayMode)` | 存储 playMode，影响 playNext/playPrevious 切歌逻辑 |
| `getCurrentVolume(): number` | 返回 `appState.volume * 100` |
| `setMuted(muted: boolean)` | `avPlayer.setMediaMuted(MEDIA_TYPE_AUD, muted)` |

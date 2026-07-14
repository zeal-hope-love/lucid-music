---
name: integrate-avplayer-into-features-player
overview: 将 avplayer-play-formatted-audio-arkts 项目的播放器 UI 代码集成到 features/player 中，适配 MusicAppState 数据层，确保 MiniPlayerBar 点击可进入增强后的播放详细页。
todos:
  - id: copy-model-files
    content: 复制 avplayer 纯数据文件到 features/player：LrcEntry.ets、LyricConst.ets，创建 model 目录
    status: pending
  - id: copy-utils-files
    content: 复制 avplayer 工具文件：LrcUtils.ets、ColorConversion.ets、BreakpointSystem.ets、PreferencesUtil.ets，创建 utils 目录，适配 Logger import
    status: pending
  - id: copy-lrcview
    content: 复制 avplayer LrcView.ets 到 features/player，适配 Logger 和 LrcEntry import 路径
    status: pending
    dependencies:
      - copy-model-files
  - id: enhance-player-controller
    content: 修改 AudioPlayerController.ets：新增 setSpeed()、setPlayMode()、getCurrentVolume() 方法
    status: pending
    dependencies:
      - copy-utils-files
  - id: merge-player-constants
    content: 扩展 PlayerConstants.ets：合并 avplayer 的 MusicPlayMode 枚举和播放常量
    status: pending
  - id: rebuild-playback-page
    content: 重建 PlaybackPage.ets：Swiper 双页布局（封面页含模糊背景+封面+信息+进度+控制、歌词页含 LrcView），速控/音量/歌单 Sheet，全部对接 AudioPlayerController
    status: pending
    dependencies:
      - enhance-player-controller
      - merge-player-constants
      - copy-lrcview
  - id: update-exports
    content: 更新 features/player/Index.ets：导出 LrcView、LrcEntry、LrcUtils、LyricConst、ColorConversion、PreferencesUtil
    status: pending
    dependencies:
      - rebuild-playback-page
---

## 用户需求
将 avplayer-play-formatted-audio-arkts 项目的播放 UI 能力集成到 lucid_music 的 features/player 模块。现有 MiniPlayerBar → PlaybackPage 路由已通，需要增强 PlaybackPage 的播放体验——增加封面展示、歌词渲染、倍速/音量/播放模式控制等功能。

## 核心功能
- PlaybackPage 使用 Swiper 双页布局（封面页 + 歌词页）
- 封面页：模糊背景、专辑封面、歌曲信息、播放进度、播放控制按钮
- 歌词页：Canvas 渲染的歌词滚动显示（集成 LrcView）
- 控制面板：播放模式切换（顺序/随机/单曲循环）、倍速调节、音量调节
- 歌单列表 Sheet
- 所有控制对接现有 AudioPlayerController 单例

## 不做的事
- 不添加任何转场动画
- 不引入响应式断点系统（保持单屏手机布局）
- 不修改 AudioPlayerController 核心播放逻辑

## 技术方案

### 集成策略
采用"复制纯逻辑文件 + 重建视图层"策略：
- **纯数据/工具文件**：直接复制 avplayer 源码，仅修改 Logger 等外部依赖的 import 路径
- **LrcView**：Canvas 渲染组件直接复制，保持 @Component 不转换
- **PlaybackPage**：重新构建为增强版，融合 avplayer 的 UI 布局模式（Swiper 双页、封面+控制区、歌词区），但全部状态绑定到 lucid_music 的 MusicAppState（AppStorageV2）

### 架构对齐
| avplayer 原始模式 | lucid_music 适配方式 |
|---|---|
| `@StorageLink('isPlay')` | `@Local appState: MusicAppState` → `appState.isPlay` |
| `@StorageLink('songList')` | `appState.playQueueIds` + `appState.resolveSongAtQueueIndex()` |
| `MediaControlCenter.getInstance().pause()` | `AudioPlayerController.getInstance().pause()` |
| `MediaControlCenter.getInstance().playNext()` | `AudioPlayerController.getInstance().playNext()` |
| `MediaControlCenter.getInstance().seek(ms)` | `AudioPlayerController.getInstance().seek(ms)` |
| `MediaControlCenter.getInstance().setSpeed(s)` | `AudioPlayerController.getInstance().setSpeed(s)` — 需要在 AudioPlayerController 新增此方法 |
| `MediaControlCenter.getInstance().setVolume(v)` | `AudioPlayerController.getInstance().setVolume(v)` — 已有 |
| `$r('app.float.xxx')` | 内联数值（如 `$r('app.float.cover_radius')` → `12`） |
| avplayer `Logger.info(TAG, msg)` | lucid_music `Logger.info(TAG, msg)` — 需创建本地 Logger 适配器 |

### 需要新增的方法
在 AudioPlayerController 中添加：
- `setSpeed(speed: number)` — 调用 `avPlayer.setSpeed(speed)`（API 12+ 支持）
- `setPlayMode(mode: MusicPlayMode)` — 设置播放模式，影响 playNext 的切歌逻辑
- `getCurrentVolume(): number` — 返回当前音量

### 目录结构
```
features/player/src/main/ets/
├── controller/
│   └── AudioPlayerController.ets      # [MODIFY] 新增 setSpeed/setPlayMode/getVolume
├── utils/
│   ├── LrcUtils.ets                   # [NEW] 歌词解析（LRC/KRC）
│   ├── ColorConversion.ets            # [NEW] 封面主色提取工具
│   ├── BreakpointSystem.ets           # [NEW] 断点系统（仅 BreakpointType 类）
│   └── PreferencesUtil.ets            # [NEW] 首选项持久化
├── constant/
│   └── PlayerConstants.ets            # [MODIFY] 合并 avplayer 的 MusicPlayMode 枚举和常量
├── model/
│   ├── LrcEntry.ets                   # [NEW] Word + LrcEntry 接口
│   └── LyricConst.ets                 # [NEW] LyricScrollEffect/LyricTopPosition 枚举
├── view/
│   ├── PlaybackPage.ets               # [MODIFY] 增强版播放页主组件
│   └── LrcView.ets                    # [NEW] Canvas 歌词渲染
└── Index.ets                          # [MODIFY] 新增导出
```

### 数据流
```
MiniPlayerBar.onTap → NavPathStack.pushPath(PLAYBACK)
  → Index.navDestinationBuilder → NavDestination → PlaybackPage
    → AppStorageV2.connect(MusicAppState) → 读取歌曲信息/播放状态
    → AudioPlayerController.getInstance() → 播放控制/切歌/seek/倍速/音量
    → LrcView(lyricMilliSecondsTime=progress, mLrcEntryList) → Canvas 渲染
```

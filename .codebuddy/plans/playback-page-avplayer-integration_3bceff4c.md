---
name: playback-page-avplayer-integration
overview: 从参考项目复制并适配 AVPlayer 播放内核（AudioPlayerController + AVSessionController），重写 PlaybackPage 为完整播放 UI（封面/歌曲信息/进度条/控制按钮/歌词区），添加后台播放权限，实现 MiniPlayerBar → 全屏播放页的一镜到底 geometryTransition 动画。搜索点击歌曲已通过 IntentState → openPlayback() 完成触发链。
todos:
  - id: copy-media-tools
    content: 从参考项目移植 MediaTools（时间格式化 msToCountdownTime），放入 entry/src/main/ets/controller/MediaTools.ets
    status: completed
  - id: create-audio-player-controller
    content: 创建 AudioPlayerController.ets：initAVPlayer、loadAndPlay(url)、play/pause/seek/next/prev、stateChange 状态机、timeUpdate 更新 MusicAppState
    status: completed
    dependencies:
      - copy-media-tools
  - id: create-av-session-controller
    content: 创建 AVSessionController.ets：initAVSession、updateMetadata、锁屏控制监听（play/pause/next/prev/seek）
    status: completed
  - id: update-entry-ability
    content: 修改 EntryAbility.ets 将 context 写入 AppStorage，供 AVSessionController 使用
    status: completed
  - id: update-module-json
    content: "修改 entry/src/main/module.json5，添加 backgroundModes: [audioPlayback]"
    status: completed
  - id: build-playback-page-ui
    content: 重写 PlaybackPage.ets：封面（模糊背景+geometryTransition）、歌曲信息、进度条 slider、播放控制按钮、歌词占位区、返回按钮
    status: completed
    dependencies:
      - create-audio-player-controller
      - create-av-session-controller
  - id: add-geometry-transition
    content: MiniPlayerBar 封面改为动态加载歌曲封面并添加 geometryTransition('coverImage')，与 PlaybackPage 封面共享元素
    status: completed
    dependencies:
      - build-playback-page-ui
  - id: wire-up-playback-flow
    content: Index.ets aboutToAppear 初始化 AudioPlayerController，PlaybackPage.aboutToAppear 调用 loadAndPlay，AVSessionController 随播放状态同步
    status: completed
    dependencies:
      - update-entry-ability
      - update-module-json
      - build-playback-page-ui
  - id: export-and-verify
    content: 更新 features/player/Index.ets 导出 AudioPlayerController，全局 lint 验证无编译错误
    status: completed
    dependencies:
      - wire-up-playback-flow
---

## 任务概述
在导航重构完成的基础上，接入 AVPlayer 播放内核，构建完整播放页 UI，实现 Mini 播放条到全屏播放页的一镜到底转场动画，并添加后台播放权限。

## 核心功能
1. **播放内核接入**：从参考项目移植 AVPlayerController（AVPlayer 封装）和 AVSessionController（播控中心/锁屏控制），适配本项目 MusicAppState 状态模型
2. **完整播放页 UI**：替换占位 PlaybackPage，构建封面区（模糊背景）、歌曲信息、进度条（Slider + 时间标签）、播放控制按钮（上一首/播放暂停/下一首）、歌词区域（占位待后续接入）
3. **一镜到底转场**：MiniPlayerBar 封面图与 PlaybackPage 封面图共享 geometryTransition id='coverImage'，配合 responsiveSpringMotion 实现弹性展开效果
4. **后台播放**：module.json5 添加 audioPlayback backgroundModes
5. **整合串联**：搜索点击歌曲 → 写入 IntentState → Index 监听 → push Playback 路由 → AudioPlayerController 加载播放


## 技术栈
- ArkUI: Navigation + NavPathStack 路由，@ComponentV2 组件，geometryTransition 共享元素
- 媒体: @kit.MediaKit (media.AVPlayer)，@kit.AVSessionKit (avSession.AVSession)
- 状态: AppStorageV2 + MusicAppState（@ObservedV2 / @Trace）
- 工具: 从参考项目移植 MediaTools（时间格式化）、Logger 复用本项目现有 musicbasic

## 实现方案

### 播放内核架构

```
Index.ets (aboutToAppear)
  └── AudioPlayerController.getInstance().initAVPlayer()
      
SearchResultViewModel.playSong(item)
  └── intentState.pendingPlaySongId = item.id
  └── intentState.openPlayerUi = true
  └── intentState.requestVersion++

Index.@Monitor('intentState.requestVersion')
  └── dispatchShellPlaybackIntent(appState, intentState, onOpen)
       └── appState.selectIndex = index
       └── onOpen() → openPlayback() → pushPathByName('Playback')

PlaybackPage.aboutToAppear()
  └── AudioPlayerController.getInstance().loadAndPlay(songItem)
       └── avPlayer.url = songItem.src (待音源 JSVM 提供)
       └── prepare() → play()
  └── AVSessionController.getInstance().initAVSession()
       └── setAVMetadata(title, artist, cover)

AVPlayerController (单例)
  ├── initAVPlayer() → media.createAVPlayer()
  ├── loadAndPlay(songItem) → set url → prepare → play
  ├── stateChange 状态机 → 更新 appState.isPlay/totalTime/progressMax
  ├── timeUpdate → 更新 appState.progress/currentTime
  ├── audioInterrupt → 暂停/恢复
  └── completed → 自动下一首

AVSessionController (单例)
  ├── initAVSession() → createAVSession → activate
  ├── setAVMetadata(title, artist, cover, duration)
  ├── setPlayState(isPlay)
  ├── setProgressState(ms)
  └── 监听锁屏回调 → AudioPlayerController.play/pause/next/prev/seek
```

### 关键适配决策

1. **移除 MediaControlCenterCallbackAction**：参考项目用该中间层解耦。本项目直接用 AppStorageV2.connect(MusicAppState) 更新状态（progress, currentTime, totalTime, isPlay, progressMax），减少抽象层。

2. **AVSessionController 数据模型替换**：参考项目依赖 SongItem(SongData)、PreferencesUtil、MediaControlCenter、MusicPlayMode。本项目直接使用 musicbasic 的 SongItem + MusicAppState。收藏状态简化跳出。

3. **loadUrl vs loadSongAssent**：参考项目读 rawFileDescriptor。本项目播放远程音源 URL（由 JSVM 引擎提供），使用 `avPlayer.url = url` 方式加载。

4. **播放页 UI 自建**：参考项目 PlayerInfoComponent 为旧 @Component，依赖 BreakpointConstants/StyleConstants/ControlAreaComponent 等大量子组件。本项目用 @ComponentV2 从零构建单一 PlaybackPage，避免多级依赖。

### 一镜到底转场

```typescript
// MiniPlayerBar 封面
Image(songCover)
  .geometryTransition('coverImage', { follow: true })
  .borderRadius('50%')

// PlaybackPage 封面
Image(songCover)
  .geometryTransition('coverImage', { follow: false })

// 配合 PageTransition 或 Navigation 自带过渡
// 弹簧曲线在 Navigation push 时自动生效
```

MiniPlayerBar 封面当前硬编码 `$r('app.media.ic_music_symbol')`，需改为根据 `appState.getCurrentSongItem()` 动态获取 `label` 资源或 `coverUrl`。

### 性能考量
- AVPlayerController 初始化只在 `aboutToAppear` 执行一次（单例守卫），避免重复创建 AVPlayer 实例
- timeUpdate 回调频率由系统控制，直接更新 @Trace 变量触发 UI 最小粒度刷新
- geometryTransition 使用原生 GPU 合成，不涉及 JS 线程阻塞
- AVSession metadata 更新使用异步 await，不阻塞 UI 线程

## 目录结构

```
entry/src/main/ets/controller/
├── AudioPlayerController.ets   # [NEW] AVPlayer 封装，状态机 + 回调
├── AVSessionController.ets     # [NEW] 播控中心/锁屏控制
└── MediaTools.ets              # [NEW] 时间格式化工具

features/player/
├── Index.ets                   # [MODIFY] 新增导出 AudioPlayerController
└── src/main/ets/view/
    └── PlaybackPage.ets        # [MODIFY] 完整播放页 UI

entry/src/main/
├── module.json5                # [MODIFY] 添加 backgroundModes
├── ets/entryability/
│   └── EntryAbility.ets        # [MODIFY] put 'context' 到 AppStorage
└── ets/pages/
    └── Index.ets               # [MODIFY] 初始化 AudioPlayerController

common/musicbasic/src/main/ets/components/miniplayer/
└── MiniPlayerBar.ets           # [MODIFY] 封面加 geometryTransition
```

## 关键代码结构

### AudioPlayerController（核心接口层）

```typescript
// entry/src/main/ets/controller/AudioPlayerController.ets
export class AudioPlayerController {
  private avPlayer?: media.AVPlayer;
  private currentState: media.AVPlayerState = 'idle';
  private waitPlay: boolean = false;
  static getInstance(): AudioPlayerController;

  async initAVPlayer(): void;                        // createAVPlayer + 注册回调
  async loadAndPlay(songItem: SongItem): Promise<void>; // set url → prepare → play
  async play(): void;                                 // 播放（带状态校验）
  pause(): void;                                      // 暂停
  seek(ms: number): void;                             // 跳转
  setVolume(volume: number): void;                    // 音量 0-1
  playNext(): void;                                   // 下一首
  playPrevious(): void;                               // 上一首
  release(): void;                                    // 销毁
}
```

### AVSessionController（播控中心接口层）

```typescript
// entry/src/main/ets/controller/AVSessionController.ets
export class AVSessionController {
  static getInstance(): AVSessionController;
  async initAVSession(): void;                        // 创建 + 激活 AVSession
  async updateMetadata(songItem: SongItem): void;     // 更新锁屏元数据
  setPlayState(isPlay: boolean): void;                // 播放/暂停状态
  setProgressState(ms: number): void;                 // 进度更新
  destroy(): void;                                    // 销毁
}
```


## SubAgent
- **code-explorer**
  - 用途：在复制参考项目文件时，批量读取参考项目的依赖文件（如 ControlAreaComponent、MusicInfoComponent、LyricsComponent、ColorConversion），评估是否需要移植这些子组件
  - 预期结果：确认本项目是否需要额外移植参考项目的 UI 子组件或样式常量，避免遗漏关键依赖

## Skill
- **typescript-advanced-types**
  - 用途：确保移植的 AudioPlayerController 和 AVSessionController 中 TypeScript 类型定义与项目 MusicAppState/SongItem 模型精确对齐
  - 预期结果：编泽时无类型错误，状态更新链路完整

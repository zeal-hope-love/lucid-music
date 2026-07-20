# Lucid Music 项目长期记忆

## 架构约定
- HarmonyOS ArkUI V2 状态管理：@ComponentV2, @ObservedV2, @Trace, @Local, @Computed
- 导航：NavPathStack.pushPath(new NavPathInfo(name, undefined), { animated: false })
- 底部栏（MiniPlayerBar + LucidTabBar）由 Index.ets 统一管理，通过 BottomBarVisibility 控制显隐
- 路由名使用 RouterUrlConstants 常量
- 各 feature 模块通过 oh-package.json5 声明依赖 musicbasic/search/player

## 模块结构
- common/musicbasic: 公共模型（MusicAppState, SongItem, PlaylistRow 等）、API DTO、DbApi、UI 组件
- features/player: 播放器核心（AudioPlayerController, AVSessionController, JsVmBridge）
- features/search: 搜索功能
- features/home: 首页 Tab
- features/musichall: 音乐厅 Tab
- features/mine: 我的 Tab
- entry: 路由入口 Index.ets

## MusicHall 歌单架构 (2026-07-17)
- 数据模型：MusichallPlaylistItem (playlistId, title, coverImage, playCount, tags[])
- 标签模型：TagFilterGroup (groupName, tags[]) + TagFilterItem (id, name)
- 数据存储：MusicMemoryStore.musichallPlaylists + musichallTagGroups，种子 8 个 demo 歌单
- API 层：MusicDbApi.getMusichallPlaylists() / getMusichallTagGroups()
- UI 组件：SourceTabBar (平台切换) + PlaylistCard (歌单卡片) + TagFilterSheet (标签筛选)
- 吸顶方案：Column 布局 + Grid.onScrollIndex 检测滚动，标题 opacity/height 动画渐隐
- 歌单详情：点击 PlaylistCard → push PlaylistDetailPage → SongListPage({ playlistId })

## 播放详情页一镜到底架构 (2026-07-18)
- 内部歌词↔封面切换：PlayerInfoComponent 使用 **if/else** + geometryTransition 独立驱动（所有元素：封面/歌名/歌手/收藏）
- 不再使用 TransitionEffect（之前 if/if + IDENTITY/translate 会与 geometryTransition 冲突导致动画末尾属性突变）
- Navigation 入场/退场一镜到底：playbackEntering 控制 follow，MiniPlayerBar(follow=false) ↔ MusicInfoComponent(follow=playbackEntering)
- 关键：geometryTransition 共享元素在源和目标组件间属性需一致

## 播放模式状态管理（2026-07-20）
- `MusicPlayMode` 枚举（SINGLE_CYCLE=0, ORDER=1, RANDOM=2）与 `PLAY_MODE_CYCLE_ORDER`（顺序→随机→单曲）定义在 `common/musicbasic/src/main/ets/model/PlayMode.ets`（model 层唯一可信源）。
- `MusicAppState.playMode` 为强类型唯一可信源，提供 `setPlayMode()` / `cyclePlayMode()`；`MusicAppState.currentPlaylistTitle` 记录当前歌单标题（默认"最近播放"）。
- `AudioPlayerController` 不再持有重复 `playMode` 字段，`playNext/playPrevious/setPlayMode/cyclePlayMode` 全部经 `appState` 读取/写入；`PlayerConstants.PlayModeSwitchList` 改为 `PLAY_MODE_CYCLE_ORDER` 的别名。
- `songList`（AppStorage V1）语义为**完整队列**，`selectIndex` 指向真实位置；所有消费者用 `songList[selectIndex]` 取当前曲。

## 播放队列单一数据源（2026-07-20 重构）
- **唯一队列**：`MusicAppState.playQueue: SongItem[]`（完整歌曲对象，本地/在线一视同仁）。已**删除** `playQueueIds: number[]` 与 `remoteSongItem` 外挂字段。`getCurrentSongItem/getQueueLength/resolveSongAtQueueIndex` 均 O(1) 直接索引 playQueue。
- **意图态**：`PlaybackIntentState.pendingQueue: SongItem[]`（取代 pendingQueueIds）+ `pendingPlayIndex`（弹层按索引切歌，取代 pendingPlaySongId）。remoteUrl 系列仅用于搜索单曲远程分支。
- **在线歌逐曲取流**：在线歌 SongItem 携带 `platform`+`remoteSongId`、src 初始为空；`AudioPlayerController.playCurrent` 检测到 src 空但有 platform+remoteSongId 时调 `RemotePlayHelper.resolveUrlForQueue`（JSVM 优先 + ApiSource 兜底）现取流并回填 src/lyricText/coverUrl。
- **最近播放语义**：非歌单点歌（搜索单曲）→ addRecentPlay 后 playQueue=最近播放、标题"最近播放"；歌单内点歌（本地/自建/收藏/在线）→ playQueue=该歌单全部歌曲、标题=歌单名，当前曲经 playCurrent 内 addRecentPlay 入最近播放。
- V1 `songList` 由 syncStateForNewSong/PlaybackPage 直接镜像 playQueue（不再反查），保证详情页/歌词/弹层与迷你条内容一致。

## ArkUI 编译陷阱（HarmonyOS SDK 26.0.0 / ArkTS 严格模式）
- **渐变遮罩无法编译**：`mask(Rect({...}).linearGradient({...}))` 与 `mask(new LinearGradient({...}))` 都会触发 Rollup 错误 `00305015 Unexpected token`（ets-loader 把组件构造器 `Rect` 当表达式用在 `mask()` 参数位，生成非法 JS）。`mask` 的形状遮罩参数自 API 12 已废弃；新 API `maskShape(value: RectShape|...)` 的 `RectShape`（来自 `@ohos.arkui.shape`）只支持 `.fill(ResourceColor)` 纯色，**不支持 linearGradient**。
- **正确做法**：实现“顶部模糊 + 向下渐隐”效果时，用 `backgroundBlurStyle(BlurStyle.BACKGROUND_REGULAR, { adaptiveColor, colorMode: ThemeColorMode.SYSTEM, scale })` 做模糊，再用组件自身的 `.linearGradient({ direction, colors: [[ResourceColor, number], ...] })` 背景做着色渐隐（顶部不透明→底部 Color.Transparent）。
- **枚举修正**（SDK `openharmony/ets/component/common.d.ts`）：`BlurStyle` 背景类为 `BACKGROUND_THIN/REGULAR/THICK`（无 `BACKGROUND_BLUR`）；`ThemeColorMode` 为 `SYSTEM/LIGHT/DARK`（无 `AUTO`，默认 `SYSTEM`）。
- **re-export 不引入本地作用域**：`export { X } from 'mod'` 仅做再导出，不会把 `X` 引入当前模块作用域；若要在本文件内使用 `X`（如 `const Y = X`），必须先 `import { X } from 'mod'` 再 `export { X }`。否则会报 `Cannot find name 'X'`，且其类型退化为 `any` 触发 `arkts-no-any-unknown` 级联错误。（2026-07-20 修复 PlayerConstants.ets 的 `PLAY_MODE_CYCLE_ORDER`/`PlayModeSwitchList` 编译失败）
- **匿名对象字面量/类型限制**：函数返回类型或局部变量类型不能用匿名对象字面量（如 `Promise<{url:string;lyrics:string;cover:string}|null>` 报 `arkts-no-obj-literals-as-types`）；对象字面量 `{url,lyrics,cover}` 必须对应显式声明的**含数据字段的 class**（报 `arkts-no-untyped-obj-literals`）。修复：定义具名 class（如 `class PlayUrlBundle { url=''; lyrics=''; cover='' }`）并用 `new X()` 构造，或对象字面量对应该类。这与 ID 77852936（接口全为方法须改 class）是同一严格模式约束的不同表现。（2026-07-20 换源回退功能触发并修复）
- **`@ohos.request` 下载 API（2026-07-20 播放缓存功能）**：`request` 是**默认导出**（`import request from '@ohos.request'`，不是 `@kit.NetworkKit` 的成员，也不是具名 `{ request }`）；`DownloadTask` **不是具名导出**（无法 `import { DownloadTask }`）。本 SDK 的 `request.downloadFile` 为**旧版回调签名**：`downloadFile(context: BaseContext, config: DownloadConfig, callback?: AsyncCallback<DownloadTask>)` —— context 是**第一个参数**（config 内不要再放 context），且无 Promise 重载（只传 1 个参数会报 "Expected 2-3 arguments"）。回调 `(err: BusinessError, task) => {}` 中 `task` 被推断为 `any`（触发 `arkts-no-any-unknown`），需显式标注；因 `DownloadTask` 不可导入，定义本地最小接口 `interface DownloadTaskLike { on(event:'complete', cb:()=>void):void; on(event:'fail', cb:(err:number)=>void):void }` 并标注 `task: DownloadTaskLike`（`DownloadTask` 结构上是其超集，回调可赋值）。
- **`AppStorage` 是全局对象**：无需 import（项目内 `AppStorage.get('context')` 等用法均无 import，从 `@kit.ArkUI` 导入会报 "has no exported member 'AppStorage'"）。
- **`fileIo` 无 `writeTextSync`**：写文本需用 `openSync(path, OpenMode.CREATE | OpenMode.WRITE_ONLY)` + `writeSync(fd.fd, text, { encoding: 'utf-8' })` + `closeSync(fd)`（可先 `unlinkSync` 旧文件避免残留）；`readTextSync` 可用。`fs.listFile(path)` 返回 `Promise<string[]>`（**异步**），需 `await`，否则 `for...of` 报 "Promise<string[]> must have [Symbol.iterator]"。
- **解构声明不支持（arkts-no-destruct-decls）**：`const [a, b, c] = await Promise.all([...])` 会报 `Destructuring variable declarations are not supported`。修复：先 `const results = await Promise.all([...])` 接收，再用 `const a = results[0]` 等具名 const 索引访问（保留并发，类型安全）。（2026-07-20 修复 MusicDbApi.initPlaylists）
- **`for...in` 不支持（arkts-no-for-in）**：`for (const k in obj)` 报 `"for .. in" is not supported`。修复：改用 `for (const k of Object.keys(obj))`（`Object.keys` 返回 `string[]`，`for...of` 为 ArkTS 支持的遍历）。（2026-07-20 修复 AudioCacheHelper.downloadFile）

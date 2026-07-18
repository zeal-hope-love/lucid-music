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

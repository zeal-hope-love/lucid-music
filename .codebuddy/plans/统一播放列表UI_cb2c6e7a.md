---
name: 统一播放列表UI
overview: 将全屏播放详情页(ControlAreaComponent)的播放列表弹层 UI 改为与迷你控制栏(MiniPlayerBar)的播放列表弹层视觉效果一致。
todos:
  - id: rewrite-musiclist-builder
    content: 重写 musicListBuilder，对齐控制栏标题行/分隔线/列表行与次级背景圆角样式
    status: completed
  - id: remove-dead-builders
    content: 删除 playListTitle 与 MusicListContainer，清理无用导入
    status: completed
    dependencies:
      - rewrite-musiclist-builder
  - id: align-sheet-params
    content: 将 bindSheet 的 showClose 改为 false，对齐控制栏弹层参数
    status: completed
    dependencies:
      - rewrite-musiclist-builder
---

## 用户需求
将全屏播放详情页（ControlAreaComponent）中由 music_note_list 按钮弹出的「播放列表」弹层 UI，改为与底部迷你控制栏（MiniPlayerBar）的「播放列表」弹层完全一致的视觉样式。

## 产品概述
详情页播放列表弹层当前使用白底、双列(LG)、红色高亮当前曲、带 mark 图标、标题左对齐且绝对定位的样式；控制栏播放列表弹层使用系统次级背景、单列、当前曲加粗并带播放中音符图标、标题左+数量右的布局。本次需求是纯视觉对齐，不改变切歌行为。

## 核心特性
- 标题行：左侧歌单标题（fontSize 18 / Bold / font_primary），右侧「N 首」（fontSize 13 / font_secondary），下方 0.5 分隔线。
- 列表行：标题（fontSize 15，当前曲 Bold 否则 Medium，统一 text_primary 色，单行省略）+ 歌手（fontSize 13 / text_secondary / 单行省略）；当前曲且正在播放时右侧显示 play_fill 音符图标（fontSize 18 / primary）。
- 容器：系统次级背景（ohos_id_color_sub_background）+ 顶部 20 圆角。
- 弹层参数：showClose 改为 false，与控制栏一致。
- 点击列表项行为保持现有 switchToIndex(index) 不变。


## 技术栈
- HarmonyOS ArkUI（ArkTS 严格模式），组件化 @Component + @Builder
- 状态：复用 ControlAreaComponent 已有的 @StorageLink（songList / selectIndex / isPlay / currentPlaylistTitle），与控制栏 appState 同源等价，无需引入新状态或 PlaybackIntentState

## 实现方案
### 策略
直接重写 `ControlAreaComponent.musicListBuilder()`，使其内部结构与 `MiniPlayerBar.playlistSheetBuilder()` 逐元素对齐（标题行 → Divider → ForEach 列表行 → 容器背景/圆角），并将 bindSheet 参数对齐。删除仅被本弹层使用的 `playListTitle()` 与 `MusicListContainer` 组件，移除不再使用的 `SongDataSource` 导入，避免死代码。

### 关键技术决策
- **视觉逐元素对齐而非整体替换**：仅替换 `musicListBuilder` 内部构建逻辑，保留 `ControlAreaComponent` 的 @StorageLink 订阅与 `switchToIndex` 点击行为，避免引入行为变更与跨模块耦合（符合 YAGNI/SoC）。
- **保留 LazyForEach 还是改用 ForEach**：控制栏用 `ForEach`，但详情页列表可能较长，`LazyForEach + SongDataSource` 是项目既有高性能模式；视觉上二者无差异。为最小化改动与保留性能，保留 `LazyForEach + SongDataSource`（不删除 SongDataSource 导入），仅替换 `MusicListContainer` 内部行样式为控制栏样式。若改为 ForEach 会丢失懒加载优势，故保留 LazyForEach。
- **点击行为不变**：保持 `AudioPlayerController.switchToIndex(index)`，与控制栏最终切歌效果一致，避免修改 PlaybackIntentDispatcher 链路。

### 性能与可靠性
- 列表渲染沿用 `LazyForEach + SongDataSource` 懒加载，避免长队列一次性构建；`reuseId` 保留组件复用。
- 当前曲高亮依赖 `selectIndex`/`isPlay` 的 @StorageLink，随播放状态实时刷新，无额外轮询。
- 背景/圆角/分隔线颜色直接复用系统资源（font_primary、font_secondary、ohos_id_color_sub_background、#1A000000），与 MiniPlayerBar 完全一致，避免硬编码偏差。

## 实现注意
- 重写时严格对齐控制栏的 padding（标题行 left/right 20, top 16, bottom 8）、字号、字重与图标（SymbolGlyph play_fill）。
- `playListTitle()` 中原有的「· N首」合并文案与绝对定位需移除，改为控制栏的左右分栏标题行。
- 删除 `MusicListContainer` 后，其 `@Reusable` 与 mark 图标逻辑一并移除，行内不再显示 mark 图标（与控制栏一致）。
- bindSheet 仅将 `showClose` 由 true 改为 false，`onWillAppear` 滚动到当前曲（`this.scroller`）保留，不影响视觉。

## 架构设计
本任务为局部 UI 对齐，不引入新架构或新模块。修改集中在 `ControlAreaComponent.ets` 单一文件，复用现有状态订阅与弹层机制，与控制栏共享同一套视觉范式，保证两处播放列表一致性。

## 目录结构
```
features/player/src/main/ets/view/ControlAreaComponent.ets  # [MODIFY]
  - musicListBuilder()：重写为控制栏样式（标题行 + Divider + LazyForEach 列表行 + 次级背景/顶部圆角）
  - playListTitle()：删除（被 musicListBuilder 引用，已内联为控制栏标题行）
  - MusicListContainer 组件：删除（仅 musicListBuilder 使用，行样式内联到 LazyForEach 的 ListItem）
  - bindSheet 参数：showClose 由 true 改为 false
  - import：若 SongDataSource 在删除后无其他使用则移除（当前 LazyForEach 仍使用，保留 SongDataSource 与 SongItem 导入）
```

## 关键代码结构
- 列表行 ListItem 结构（对齐控制栏）：
  - Row { Column{ Text(title) ; Text(singer) }.layoutWeight(1) ; if(selectIndex===index && isPlay) SymbolGlyph(play_fill) }
  - onClick → AudioPlayerController.getInstance().switchToIndex(index)


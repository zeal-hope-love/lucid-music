---
name: musichall-playlist-ui
overview: 实现音乐厅歌单功能 UI：顶部可吸顶的平台切换 Tab 栏 + 标签筛选 Sheet + 3列歌单卡片网格，点击卡片进入已有 SongListPage 歌单详情。
todos:
  - id: create-data-models
    content: 创建 MusichallPlaylistItem 数据模型和 TagFilterGroup/TagFilterItem 标签筛选模型，放入 common/musicbasic
    status: completed
  - id: seed-demo-data
    content: 在 MusicMemoryStore 中种子 8 个演示歌单（含封面、播放量、来源标签）和分类标签树，在 MusicDbApi 中新增 getMusichallPlaylists() 和 getMusichallTagGroups() 方法
    status: completed
    dependencies:
      - create-data-models
  - id: build-source-tab-bar
    content: 实现 SourceTabBar 组件：水平排列的平台 Tab（选中态下划线高亮）+ 最右侧圆形筛选按钮，支持 onSourceChange / onFilterClick 回调
    status: completed
  - id: build-playlist-card
    content: 实现 PlaylistCard 组件：正方形封面图 + 左下角播放量叠加 + 下方歌单名称（最多两行），点击触发射 Push SongListPage
    status: completed
    dependencies:
      - create-data-models
  - id: build-tag-filter-sheet
    content: 实现 TagFilterSheet 组件：BindSheet 内容，按分组展示标签 Chip（flexWrap 横向排列），点击标签触发筛选回调
    status: completed
    dependencies:
      - create-data-models
  - id: rewrite-musichall-page
    content: 重写 MusicHallPage：组合标题（吸顶动画）+ SourceTabBar + Grid 歌单网格 + BindSheet 标签筛选，接入 MusicDbApi 数据，运行验证
    status: completed
    dependencies:
      - seed-demo-data
      - build-source-tab-bar
      - build-playlist-card
      - build-tag-filter-sheet
---

## 产品概述
为 Lucid Music 的音乐厅 Tab 实现歌单浏览功能。用户可以浏览推荐歌单卡片，切换音源平台，按分类标签筛选，点击歌单进入详情页播放。

## 核心功能
- **平台切换 Tab 栏**：顶部水平排列的音源平台标签（kw / kg / tx / wy / mg），初始位于"音乐厅"标题下方。向上滑动后标题渐隐，Tab 栏吸顶保持在屏幕顶部。最右侧圆形按钮点击弹出 medium 高度的 BindSheet 分类标签选择器。
- **歌单卡片网格**：每行 3 个自适应卡片，每张卡片包含正方形封面图（左下角叠加播放量文字）和歌单名称。不支持左右滑动。
- **歌单详情**：点击卡片通过 `PlaylistDetailPage` 路由 Push 到已有 `SongListPage` 组件，传入 playlistId 展示歌单内歌曲列表。
- **分类标签筛选**：圆按钮触发的 BindSheet 内按分组展示标签（热门/风格/语种等），点击标签筛选歌单。
- **排序暂不实现**。


## 技术栈
- UI 框架：HarmonyOS ArkUI V2（@ComponentV2 / @ObservedV2 / @Trace / @Computed / @Local）
- 导航：NavPathStack + NavDestination（禁用动画，适配一镜到底转场约定）
- 状态管理：AppStorageV2.connect 共享状态
- 数据层：MusicMemoryStore 内存种子数据 + MusicDbApi 只读查询 API

## 实现方案

### 整体策略
先 UI 后数据：种子 8 个演示歌单数据驱动 UI 渲染，预留在线 API 扩展点。复用现有 `SongListPage` 作为歌单详情页，通过 `PlaylistDetailPage` 路由串联。

### 吸顶 Tab 栏方案
采用 **Column 固定布局** 而非全页 Scroll 方案，避免 ArkUI Scroller 吸顶实现的复杂性：

```
Column {
  // 标题区 — 受 Grid 滚动偏移量控制透明度/高度
  Text('音乐厅')  .opacity(animated) .height(animated)

  // Tab 栏 — 始终渲染，自然吸顶
  SourceTabBar()

  // 歌单网格 — 唯一可滚动区域
  Grid(scroller) { GridItem × N }
    .layoutWeight(1)
    .onScrollIndex(...)  // 监听滚动，驱动标题动画
}
```

- `layoutWeight(1)` 让 Grid 自动填满剩余空间，Tab 栏自然吸在标题下方。
- Grid 滚动时通过 `onScrollIndex` 检测首个可见项索引。当 `firstIndex > 0`（至少滚过一行卡片）时，标题动画过渡到隐藏（opacity 0 + height 0），顶部仅剩 Tab 栏。

### 歌单卡片网格
使用 ArkUI `Grid` 组件，`columnsTemplate('1fr 1fr 1fr')` 实现每行 3 列自适应。每个 `GridItem` 内为 `Stack` 叠加封面图与播放量标签 + 下方歌单名称文本。

### 数据模型
新建 `MusichallPlaylistItem` 数据类（位于 common/musicbasic/data/），字段：
- `playlistId: number`（关联 PlaylistRow）
- `title: string | Resource`（歌单名）
- `coverImage: Resource`（封面图资源）
- `playCount: string`（播放量文本，如"12.5万"）
- `sourceName: string`（音源标签，如"kw"）

### 平台切换与标签筛选
- **平台切换**：`@Local` 状态 `activeSource`，Tab 栏点击切换。预留 `onSourceChange` 回调，后续对接 API 时传入 source 参数。
- **标签筛选 Sheet**：`@Local` 状态 `isTagSheetVisible` + `activeTags[]`。BindSheet 内按分组渲染 TagChip，点击后更新筛选条件，过滤 `MusichallPlaylistItem` 列表。
- **标签种子数据**：在 MusicMemoryStore 中 seed 分类标签树（热门/风格/语种三组），每组若干标签。

## 目录结构

```
features/musichall/
├── Index.ets                                      # [MODIFY] 导出 MusicHallPage + 新增组件
├── oh-package.json5                               # 不变
└── src/main/ets/
    ├── model/
    │   └── TagFilterModel.ets                     # [NEW] 标签筛选数据模型（TagGroup, TagItem）
    └── view/
        ├── MusicHallPage.ets                      # [MODIFY] 重写：标题 + SourceTabBar + 歌单网格 + BindSheet
        ├── SourceTabBar.ets                       # [NEW] 平台切换 Tab 栏组件（含右侧圆按钮）
        ├── PlaylistCard.ets                       # [NEW] 歌单卡片组件（封面+播放量+名称）
        └── TagFilterSheet.ets                     # [NEW] 标签筛选 BindSheet 内容组件

common/musicbasic/src/main/ets/
├── data/
│   └── MusichallPlaylistItem.ets                  # [NEW] 歌单展示数据模型
├── db/
│   └── MusicMemoryStore.ets                       # [MODIFY] 新增 musichall 歌单 + 标签种子数据
├── util/
│   └── MusicDbApi.ets                             # [MODIFY] 新增 getMusichallPlaylists() / getMusichallTags()
└── Index.ets                                      # [MODIFY] 导出 MusichallPlaylistItem
```

## 关键代码结构

### MusichallPlaylistItem（数据模型）
```typescript
export class MusichallPlaylistItem {
  playlistId: number = 0
  title: string | Resource = ''
  coverImage: Resource = $r('app.media.ic_avatar1')
  playCount: string = '0'
  sourceName: string = 'kw'
  tags: string[] = []  // 关联标签 ID 列表，用于筛选
}

export class TagFilterGroup {
  groupName: string
  tags: TagFilterItem[]
}

export class TagFilterItem {
  id: string
  name: string
}
```

### MusicDbApi 新增方法
```typescript
// 获取歌单展示列表
getMusichallPlaylists(): MusichallPlaylistItem[]
// 获取分类标签树
getMusichallTagGroups(): TagFilterGroup[]
```

### SourceTabBar 组件接口
```typescript
@ComponentV2
export struct SourceTabBar {
  @Param activeSource: string = 'kw'
  @Param sources: string[] = ['kw', 'kg', 'tx', 'wy', 'mg']
  @Event onSourceChange: (source: string) => void
  @Event onFilterClick: () => void  // 打开标签筛选 Sheet
}
```


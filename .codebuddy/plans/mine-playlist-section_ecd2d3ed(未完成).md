---
name: mine-playlist-section
overview: 在"我的"页面中，三个快捷入口框与设置栏之间，新增一个歌单区域组件（PlaylistSection）。包含自建歌单/收藏歌单切换按钮和歌单列表，点击进入歌单详情页（PlaylistDetailPage），共用 MusicListPage 的歌曲列表 UI 模式。
todos:
  - id: extend-playlist-model
    content: 扩展 PlaylistRow 数据模型，新增 playlistType 字段，并在 MusicMemoryStore 中添加收藏歌单数组、收藏方法和种子数据
    status: pending
  - id: add-db-api-methods
    content: 在 MusicDbApi 中新增 getOwnPlaylists 和 getCollectedPlaylists 查询方法
    status: pending
    dependencies:
      - extend-playlist-model
  - id: create-playlist-section
    content: 新建 PlaylistSection.ets 组件，实现切换按钮 + 歌单列表 + 空状态，并集成到 MinePage 布局中
    status: pending
    dependencies:
      - add-db-api-methods
  - id: create-playlist-detail-page
    content: 新建 PlaylistDetailPage.ets，复用 MusicListPage UI 模式展示歌单内歌曲列表
    status: pending
    dependencies:
      - add-db-api-methods
  - id: register-route-and-export
    content: 在 Index.ets 注册 PlaylistDetailPage 路由，更新 features/mine/Index.ets 导出
    status: pending
    dependencies:
      - create-playlist-section
      - create-playlist-detail-page
---

## 用户需求
在"我的"页面的三个快捷入口框框与设置栏之间，新增一个歌单区域框框。

## 核心功能
- **切换按钮**：区域顶部左侧放置两个可切换按钮——"自建歌单"和"收藏歌单"，切换后下方列表内容联动更新
- **歌单列表**：显示当前选中类型（自建/收藏）的歌单列表，每行展示歌单标题和歌曲数量，点击进入歌单详情
- **歌单详情页**：复用 MusicListPage 的 UI 模式（标题栏 + 歌曲列表），展示单个歌单内的歌曲，后续可继续完善
- **数据区分**：PlaylistRow 新增类型字段区分自建歌单和收藏歌单，MusicMemoryStore 分别存储


## 技术方案

### 数据模型扩展

**PlaylistRow 新增字段**：`playlistType: number`（0=自建, 1=收藏），与现有 `playlistId`、`title`、`songIds` 并列。

**MusicMemoryStore 新增**：
- `collectedPlaylistIds: number[]` — 收藏歌单 ID 数组（类似 `favoriteSongIds`）
- `toggleCollectPlaylist(id)` / `isCollectedPlaylist(id)` — 收藏歌单的增删查方法
- 种子数据中添加 2-3 个自建歌单和 1-2 个收藏歌单

**MusicDbApi 新增**：
- `getOwnPlaylists(): PlaylistRow[]` — 返回 playlistType === 0 的歌单
- `getCollectedPlaylists(): PlaylistRow[]` — 返回 playlistType === 1 的歌单
- 复用已有的 `getPlaylistSongItems(playlistId)` 获取歌单内歌曲

### 新增组件

**PlaylistSection.ets**（`features/mine/src/main/ets/view/`）：
- 使用 `@ComponentV2` + `@Local` 管理当前选中 tab（0=自建/1=收藏）
- 切换按钮区域：两个 `Text` 按钮，选中态高亮、底部下划线指示器
- 歌单列表：`List` + `ForEach`，每行标题 + 歌曲数量，点击 push `PlaylistDetailPage`
- 监听 `currentTabState.refreshCounter` 以确保数据刷新
- 高度自适应，最小高度约 200vp，避免内容不足时太空

**PlaylistDetailPage.ets**（`features/mine/src/main/ets/view/`）：
- 接收 `PlaylistDetailParam(playlistId: number, title: string)`
- 通过 `MusicDbApi.getPlaylistSongItems(playlistId)` 加载歌曲
- UI 完全复用 MusicListPage 模式：返回按钮 + 标题 + 歌曲数量 + `List` 歌曲列表
- 背景色、间距、字体等样式与 MusicListPage 保持一致

### 路由注册

- 路由名复用已预留的 `RouterUrlConstants.PLAYLIST_DETAIL`（'PlaylistDetailPage'）
- 在 `Index.ets` 的 `navDestinationBuilder` 中新增 `PlaylistDetailPage` 分支
- 退场时恢复 bottom bar 可见性，与 `MusicList` 路由行为一致

### 布局集成

MinePage 中在三个快捷入口 `Row` 之后、设置入口 `Row` 之前插入 `PlaylistSection()`，margin 与现有组件对齐（`width: '90%'`, `margin: { top: 12 }`）。

### 导出更新

- `features/mine/Index.ets`：导出 `PlaylistSection`、`PlaylistDetailPage`、`PlaylistDetailParam`
- `common/musicbasic/Index.ets`：`PlaylistRow` 已导出，无需额外修改

## 目录结构

```
common/musicbasic/src/main/ets/
├── data/
│   └── PlaylistRow.ets          # [MODIFY] 新增 playlistType: number 字段
├── db/
│   └── MusicMemoryStore.ets     # [MODIFY] 新增 collectedPlaylistIds 数组、收藏方法、更多种子歌单
└── util/
    └── MusicDbApi.ets           # [MODIFY] 新增 getOwnPlaylists/getCollectedPlaylists

features/mine/
├── Index.ets                    # [MODIFY] 新增导出 PlaylistSection, PlaylistDetailPage, PlaylistDetailParam
└── src/main/ets/view/
    ├── MinePage.ets             # [MODIFY] 在快捷入口与设置栏之间插入 PlaylistSection
    ├── PlaylistSection.ets      # [NEW] 歌单区域组件：切换按钮 + 歌单列表
    └── PlaylistDetailPage.ets   # [NEW] 歌单详情页：标题栏 + 歌曲列表

entry/src/main/ets/pages/
└── Index.ets                    # [MODIFY] navDestinationBuilder 注册 PlaylistDetailPage 路由
```

## 关键实现细节

- **切换按钮交互**：使用 `@Local currentType: number = 0` 驱动切换，`onClick` 切换值后列表自动刷新。选中按钮加粗 + 底部 2vp 宽度指示条，未选中按钮用次要文字颜色
- **歌单行数据**：每行显示 `playlist.title` 和 `${playlist.songIds.length}首`，点击时构造 `PlaylistDetailParam` 并 push
- **空列表处理**：当某类型下无歌单时，显示空状态提示文本（如"暂无自建歌单"）
- **性能**：歌单数量预计较少（<20），直接 `ForEach` + 全量渲染即可，无需虚拟列表优化
- **日志**：遵循项目现有的 `Logger` 工具类，在歌单加载等关键路径上报


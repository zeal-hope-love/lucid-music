---
name: mine-playlist-section
overview: 在 common/musicbasic 新建共用的 SongListPage 替代原有 MusicListPage，支持按类型(本地/最近/收藏)和按歌单ID加载歌曲。在 MinePage 插入 PlaylistSection 歌单区域，点击歌单进入 SongListPage。
todos:
  - id: extend-data-model
    content: 扩展 PlaylistRow（+playlistType），MusicMemoryStore（+collectedPlaylistIds、收藏方法、种子歌单），MusicDbApi（+getOwnPlaylists/getCollectedPlaylists）
    status: completed
  - id: create-songlist-page
    content: 将 MusicListPage 迁移为共用 SongListPage 放在 common/musicbasic/components/，支持 listType 和 playlistId 两种数据模式，更新 common/musicbasic/Index.ets 导出
    status: completed
    dependencies:
      - extend-data-model
  - id: create-playlist-section
    content: 新建 PlaylistSection.ets 放在 features/mine/view/，实现切换按钮（自建/收藏）+ 歌单列表 + 空状态
    status: completed
    dependencies:
      - extend-data-model
  - id: integrate-and-route
    content: 删除原 MusicListPage.ets；修改 MinePage 导入+插入 PlaylistSection；更新 entry/Index.ets 路由（MusicList 改 SongListPage，新增 PlaylistDetailPage）；更新 features/mine/Index.ets 导出
    status: completed
    dependencies:
      - create-songlist-page
      - create-playlist-section
---

## 用户需求
1. 在 `common/musicbasic` 中新建一个**共用的歌曲列表 UI 组件**（SongListPage），原来的"本地/最近播放/收藏"和新的"歌单详情"都共用这个组件
2. 删除原来的 `MusicListPage.ets`
3. 在 MinePage 三个快捷入口框框和设置栏之间，插入歌单区域框框（PlaylistSection），含切换按钮（自建歌单/收藏歌单）+ 歌单列表，点击进入歌单详情

## 核心功能
- **SongListPage 共用组件**：统一标题栏 + 歌曲列表 UI，支持两种数据模式——按来源加载（本地/最近/收藏）和按歌单加载
- **PlaylistSection**：自建歌单/收藏歌单切换按钮，选中态下划线指示器，歌单列表展示标题 + 歌曲数量
- **歌单详情**：点击歌单进入 SongListPage，展示该歌单内的歌曲
- **数据区分**：PlaylistRow 新增 playlistType 字段（0=自建, 1=收藏），MusicMemoryStore 独立管理收藏歌单 ID 数组


## 技术栈
- 框架：HarmonyOS ArkUI + @ComponentV2 / @ObservedV2
- 语言：ArkTS (ETS)
- 数据层复用：MusicDbApi + MusicMemoryStore 单例模式

## 架构设计

### 组件关系图
```
MinePage（我的页面）
├── 三个快捷入口（本地 / 最近播放 / 收藏）
│     └── 点击 → MusicList 路由 → SongListPage(listType='local'/'recent'/'favorite')
├── PlaylistSection（歌单框框）[NEW]
│     ├── 切换按钮：自建歌单 | 收藏歌单
│     └── 歌单列表 → 点击 → PlaylistDetailPage 路由 → SongListPage(playlistId=xxx)
└── 设置栏
```

### SongListPage 设计（共用组件）
- **位置**：`common/musicbasic/src/main/ets/components/`（与 MiniPlayerBar、LucidTabBar 同级）
- **参数**：`SongListParam` 含 `title`、`listType`（'local'|'recent'|'favorite'）、`playlistId`
- **两种模式**：
  - 来源模式：`listType` 非空时从 MusicDbApi 按类型加载（本地/最近/收藏），监听 `favoriteVersion` 刷新收藏列表
  - 歌单模式：`playlistId > 0` 时调用 `getPlaylistSongItems(playlistId)` 加载歌单歌曲
- **UI 结构**：返回按钮（AreaWithHdsTabBar）+ 标题 + 歌曲数量 + List 歌曲行（序号/歌名/歌手/箭头）

### 数据流
```
MusicMemoryStore.playlists[]  ──→ MusicDbApi.getOwnPlaylists()   ──→ PlaylistSection (自建歌单列表)
                              ──→ MusicDbApi.getCollectedPlaylists() ──→ PlaylistSection (收藏歌单列表)
                              ──→ MusicDbApi.getPlaylistSongItems()   ──→ SongListPage   (歌单详情)
MusicMemoryStore.songs[]      ──→ MusicDbApi.getSongList()        ──→ SongListPage   (本地)
MusicMemoryStore.recentPlayIds──→ MusicDbApi.getRecentPlaySongs() ──→ SongListPage   (最近播放)
MusicMemoryStore.favoriteSongIds→MusicDbApi.getFavoriteSongs()   ──→ SongListPage   (收藏)
```

## 实现细节

### SongListPage 迁移注意事项
- 原有 `MusicListPage` 中 `AudioPlayerController.playSongAt()`、`favoriteVersion` 回调逻辑完整保留
- `appState` 从 AppStorageV2 获取，点击播放逻辑不变
- 删除 `MusicListPage.ets` 后，`MinePage` 中 `MusicListParam` 导入需改为 `SongListParam`
- `features/mine/Index.ets` 移除 `MusicListPage` / `MusicListParam` 导出，新增 `PlaylistSection` 导出
- `entry/Index.ets` 的 `navDestinationBuilder` 中 `MusicList` 路由改用 `SongListPage`

### PlaylistSection 实现细节
- 使用 `@Local currentType: number = 0`（0=自建，1=收藏）驱动切换
- 切换按钮：两个 Text 按钮水平排列，选中态加粗 + 底部 2vp 下划线，未选中用次要颜色
- 歌单行：`Row` 内左边歌单标题（含 @Resource 渲染），右边 `${songIds.length}首`
- 空状态：当某类型下无歌单时显示"暂无自建歌单" / "暂无收藏歌单"
- 监听 `currentTabState.refreshCounter` 确保切回 Mine 页时刷新

### 性能
- 歌单数量少（< 20），直接全量 `ForEach` 渲染即可
- 歌曲列表使用 `List` 组件提供原生滚动优化
- `favoriteVersion` 使用 `@Monitor` 精准监听，不触发无关刷新

## 目录结构
```
common/musicbasic/src/main/ets/
├── components/
│   └── SongListPage.ets         # [NEW] 共用歌曲列表组件，替代原 MusicListPage
├── data/
│   └── PlaylistRow.ets          # [MODIFY] 新增 playlistType: number（0=自建, 1=收藏）
├── db/
│   └── MusicMemoryStore.ets     # [MODIFY] 新增 collectedPlaylistIds[]、收藏方法、更多种子歌单
└── util/
    └── MusicDbApi.ets           # [MODIFY] 新增 getOwnPlaylists/getCollectedPlaylists

common/musicbasic/Index.ets      # [MODIFY] 导出 SongListPage, SongListParam

features/mine/
├── Index.ets                    # [MODIFY] 移除 MusicListPage/MusicListParam 导出，新增 PlaylistSection 导出
└── src/main/ets/view/
    ├── MinePage.ets             # [MODIFY] 导入改为 SongListParam；插入 PlaylistSection（三个框与设置栏之间）
    ├── PlaylistSection.ets      # [NEW] 歌单区域组件：切换按钮 + 歌单列表
    └── MusicListPage.ets        # [DELETE] 被 SongListPage 替代

entry/src/main/ets/pages/
└── Index.ets                    # [MODIFY] 导入改为 SongListPage+SongListParam；MusicList 路由改用 SongListPage；新增 PlaylistDetailPage 路由
```


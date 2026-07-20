---
name: fix-recent-favorite-empty
overview: 修复「我的」页最近播放/收藏显示数量但点进去无歌曲（数量为0）的问题。根因：远程歌曲使用合成负ID存入 recent/favorite，getSongById 无法解析。改为存储完整 SongItem，使本地与远程歌曲都能正确展示与播放。
todos:
  - id: store-songitem
    content: MusicMemoryStore 改存 SongItem（recentPlayItems/favoriteItems）并按 id 去重查找
    status: completed
  - id: dbapi-songitem
    content: MusicDbApi 的 addRecentPlay/toggleFavorite/getRecentPlaySongs/getFavoriteSongs 改为接收/返回 SongItem
    status: completed
    dependencies:
      - store-songitem
  - id: player-toggle
    content: AudioPlayerController、MusicInfoComponent、LyricsComponent 传完整 songItem 给 addRecentPlay/toggleFavorite
    status: completed
    dependencies:
      - dbapi-songitem
  - id: avsession-toggle
    content: AVSessionController.onToggleFavorite 改用当前 SongItem 调用 toggleFavorite
    status: completed
    dependencies:
      - dbapi-songitem
  - id: songlist-render
    content: SongListPage 渲染 rfItems 并支持本地队列/远程缓存回放与计数
    status: completed
    dependencies:
      - dbapi-songitem
---

## 用户需求
「我的」页面中，最近播放、收藏两个快捷入口能正常显示数量（如 3、5），但点击进入后歌曲列表为空、显示「0首」，要求修复使其能正确展示对应歌曲。

## 产品概述
修复本地与远程歌曲在「最近播放 / 收藏」列表中的展示与回放问题，保证计数与列表内容一致。

## 核心功能
- 最近播放、收藏列表正确展示歌曲（歌名、歌手、封面），本地与远程歌曲均覆盖。
- 点击列表项可正确回放：本地歌曲走本地队列播放，远程歌曲用缓存地址回放。
- 收藏状态变更后计数与列表实时同步。


## 技术栈
- HarmonyOS ArkUI（ArkTS 严格模式）、ArkUI 状态管理（@ObservedV2 / @Trace / @Local / @Monitor）
- 现有模块：common/musicbasic（数据层 MusicMemoryStore / MusicDbApi / SongListPage）、features/player（播放控制器与播放器 UI）、features/mine（我的页）

## 根因分析
远程歌曲在 `PlaybackIntentDispatcher.ets` 第46行被赋合成负 ID `songItem.id = -Date.now()`。播放时 `AudioPlayerController.playCurrent()` 第273行 `addRecentPlay(songItem.id)` 把负 ID 存入 `recentPlayIds`；收藏 `MusicInfoComponent.ets`/`LyricsComponent.ets` 第182行 `toggleFavorite(songId)` 把负 ID 存入 `favoriteSongIds`。而详情页 `MusicDbApi.getRecentPlaySongs()/getFavoriteSongs()` 经 `idsToSongDtos` → `getSongById(id)` 仅在 `store.songs`（仅 id=1、2 两首本地 demo）中查找，负 ID 永远解析不到 → 列表为空。Mine 页计数取数组 `.length`，故显示非零、点进去却 0 首。

## 实现方案
将「最近播放 / 收藏」从「仅存 ID」改为「存完整 SongItem」，使本地与远程歌曲都保留展示信息（title、singer、coverUrl、src 等），详情列表直接渲染存储的 SongItem，不再依赖 `getSongById` 解析。

### 关键技术决策
- **存储完整 SongItem 而非 ID**：一次修改同时覆盖本地与远程，避免为远程歌曲再建一套 ID→SongItem 映射（减少冗余、降低出错面）。`SongItem` 已含 `id/title/singer/label/coverUrl/src/lyricText`，足够列表展示与回放。
- **计数不变**：`getRecentPlayCount()/getFavoriteCount()` 仍返回 `recentPlayItems.length / favoriteItems.length`，Mine 页无需改动。
- **回放策略**：本地项（id 能在 `store.songs` 解析）构建本地队列 `pendingQueueIds` 播放；远程项用缓存地址 `item.src` 直接回放（设置 `intentState.remoteUrl/remoteSongName/...` + `openPlayerUi`）。远程 URL 可能过期，属既有设计限制，需向用户说明。
- **播放器爱心态**：`isFavorite(id)` 保留，按 id 在 `favoriteItems` 中查找；`toggleFavorite` 改为接收 `SongItem` 以存储完整项。

## 实现注意事项
- 保持 `idsToSongDtos` 仅用于 playlist 本地解析，不改动其用途，避免影响歌单详情。
- `SongListPage` 的 `@Monitor('currentTabState.favoriteVersion')` 已覆盖 recent/favorite 重载，需确认分支判断 `listType === 'favorite' || listType === 'recent'`，保证收藏变更后刷新。
- `AVSessionController.onToggleFavorite` 当前仅拿到 media 传来的 assetId（远程为临时负 ID，无法匹配），改为连接 `MusicAppState` 取 `getCurrentSongItem()` 对当前歌曲 `toggleFavorite(item)`，本地/远程均正确。
- 不删除 `.codebuddy` 目录；修改前先读取目标文件完整内容再编辑（遵循项目约定）。

## 架构设计
```mermaid
flowchart TD
  A[播放/收藏行为] --> B[AudioPlayerController.addRecentPlay songItem]
  A --> C[MusicInfo/Lyrics/AVSession.toggleFavorite songItem]
  B --> D[MusicMemoryStore.recentPlayItems: SongItem[]]
  C --> E[MusicMemoryStore.favoriteItems: SongItem[]]
  D --> F[MusicDbApi.getRecentPlaySongs/FavoriteSongs 返回 SongItem[]]
  E --> F
  F --> G[SongListPage.rfItems 渲染 + 点击回放]
  G --> H[本地: pendingQueueIds 播放 | 远程: intentState 缓存地址回放]
```

## 目录结构与文件改动
```
common/musicbasic/src/main/ets/db/MusicMemoryStore.ets   # [MODIFY] 引入 SongItem；recentPlayIds→recentPlayItems: SongItem[]；favoriteSongIds→favoriteItems: SongItem[]；addRecentPlay(item)/toggleFavorite(item)/isFavorite(id) 按 id 去重与查找。
common/musicbasic/src/main/ets/util/MusicDbApi.ets        # [MODIFY] addRecentPlay(songItem)/toggleFavorite(songItem)；getRecentPlaySongs()/getFavoriteSongs() 返回 SongItem[]；getRecentPlayCount()/getFavoriteCount() 返回 .length；isFavorite(id) 不变。
features/player/src/main/ets/controller/AudioPlayerController.ets   # [MODIFY] 第273行 addRecentPlay(songItem.id)→addRecentPlay(songItem)。
features/player/src/main/ets/view/MusicInfoComponent.ets             # [MODIFY] 第181-182行 传 songItem 给 toggleFavorite；isFavorite(songId) 保持。
features/player/src/main/ets/view/LyricsComponent.ets               # [MODIFY] 第181-182行 同上改为传 songItem。
features/player/src/main/ets/controller/AVSessionController.ets     # [MODIFY] onToggleFavorite 连接 MusicAppState，取 getCurrentSongItem() 后 toggleFavorite(item)，保持 favoriteVersion++ 与 updateFavoriteState。
common/musicbasic/src/main/ets/components/SongListPage.ets          # [MODIFY] 新增 rfItems: SongItem[]；loadData 中 recent/favorite 赋值；build 增加第三分支渲染 rfItems；onRfSongTap 本地队列/远程缓存回放；顶部数量取 rfItems.length。
```


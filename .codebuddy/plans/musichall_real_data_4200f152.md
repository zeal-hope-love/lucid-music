---
name: musichall_real_data
overview: 将音乐厅（MusicHall）的歌单列表、标签筛选、列表排序、歌单详情歌曲，全部替换为 5 大平台（网易云/酷狗/酷我/QQ/咪咕）真实 API 数据，并打通"点击真实歌曲可播放"的全链路。参考 lx-music-mobile 的 songList 实现与现有 musicSdk。
todos:
  - id: sdk-order-source
    content: musicSdk 全平台 getPlaylists 增加 order 参数并填充 item.source；wy getPlaylistTags 的 id 改为分类名
    status: completed
  - id: hall-real-data
    content: MusicHallPage 改为平台切换/选标签/切排序均重新请求真实数据，种子仅作错误兜底
    status: completed
    dependencies:
      - sdk-order-source
  - id: card-tag-source
    content: PlaylistCard 点击传递 source 与字符串 playlistId；核对 TagFilterSheet 选中用 tag.id
    status: completed
    dependencies:
      - sdk-order-source
  - id: songlist-remote
    content: SongListParam.playlistId 改 string 加 source；SongListPage 新增远程歌单模式加载真实歌曲
    status: completed
    dependencies:
      - sdk-order-source
  - id: remote-play
    content: 抽取共享远程播放 helper 并接入 SongListPage 点击播放，复用 SearchResultViewModel 逻辑
    status: completed
    dependencies:
      - songlist-remote
  - id: verify-chain
    content: 联调 5 平台列表/标签/排序/详情/播放全链路与离线兜底
    status: completed
    dependencies:
      - hall-real-data
      - card-tag-source
      - songlist-remote
      - remote-play
---

## 用户需求
将音乐厅（MusicHall）内所有数据替换为 5 大平台（网易云/酷狗/酷我/QQ音乐/咪咕）的真实 API 数据，并打通"点击真实歌曲可播放"的全链路。

## 核心功能
- **歌单网格列表**：各平台切换均展示该平台真实歌单（封面、名称、播放量来自接口）。
- **平台切换**：底部平台 Tab 切换时重新拉取对应平台真实歌单。
- **列表排序**：推荐/热门/最新/收藏 映射到接口 order 参数（网易云 hot/new；其余平台按需透传）。
- **标签筛选**：使用真实分类标签，选中后按 tag 重新请求接口（而非仅本地过滤）。
- **歌单详情**：点击歌单进入详情，展示该歌单内真实歌曲列表（来自 getPlaylistSongs）。
- **真实播放**：点击详情内歌曲，走与搜索一致的远程取流（JSVM 优先 + API 兜底）真正播放。
- **离线兜底**：网络异常时回退到本地种子数据，保证可用性。


## 技术栈
- HarmonyOS ArkUI（ArkTS），现有 musicSdk + ApiSource 调度层，MusicDbApi/MusicMemoryStore 本地兜底。
- 播放复用既有 PlaybackIntentState 远程播放通道（remoteUrl + openPlayerUi + requestVersion）。
- 不引入新框架，全部基于现有架构扩展。

## 实现方案
### 总体策略
以现有 musicSdk 已实现的 getPlaylists/getPlaylistTags/getPlaylistSongs 为基础，补齐"数据驱动"与"类型贯通"两处断点：
1. **统一 cat 语义**：各平台 getPlaylistTags 返回的 `id` 必须等同于其 getPlaylists(cat) 应接收的值。网易云分类用"分类名"（对齐 lx：tag.id===name），其余平台已是分类 id，保持不变；这样 MusicHallPage 选中标签时直接把 `tag.id` 作为 cat 重新请求即可。
2. **order 透传**：getPlaylists 增加 order 参数，网易云映射 hot/new，其余平台按需透传或忽略。
3. **source 贯通**：MusichallPlaylistItem 增加 `source` 字段，由各平台 getPlaylists 填充，使详情页知道去哪个平台拉歌曲、播放时知道用哪个音源。
4. **string playlistId**：真实歌单 id（尤其网易云）超出 JS 安全整数，SongListParam.playlistId 由 number 改为 string，避免精度丢失。
5. **远程播放复用**：抽取 SearchResultViewModel.playSong 的取流逻辑为共享 helper，SongListPage 点击歌曲直接复用，避免重复代码与行为不一致。

### 关键技术决策
- **为何重新请求而非本地过滤**：真实 item.tags 是标签名数组、而选中态是 tag.id，二者不匹配；且各平台 getPlaylists(cat) 本就支持按分类拉取，服务端过滤更准确。故标签/排序均触发重新请求。
- **为何保留种子兜底**：网络失败时回退 MusicMemoryStore 种子，保证 UI 不空白；但主路径为真实数据。
- **为何抽取共享播放 helper**：搜索与歌单详情播放逻辑完全一致（取流→设 remoteUrl→openPlayerUi），抽公共函数符合 DRY，且后续排行榜等模块也可复用。

### 性能与可靠性
- 每次平台/标签/排序变更触发一次网络请求；避免 Grid 重渲染抖动：用 `@Local playlists` 整体替换，ForEach key 用 playlistId。
- 网络/解析异常在 musicSdk 内 try-catch 返回空数组，ApiSource 再兜一层，MusicHallPage 最终回退种子，避免白屏。
- 远程歌曲列表上限 1000（对齐 lx limit_song），详情页 List 懒加载渲染。

## 实现注意
- 仅修改数据/播放链路，不改动 MusicHallPage/PlaylistCard/TagFilterSheet/SongListPage 的视觉结构与样式。
- wy getPlaylistTags 当前取 `playlistTag.id`（数字）与 cat 不匹配，必须改为 `id = name`（分类名）。
- 各平台 getPlaylists 映射 MusichallPlaylistItem 时务必赋值 `item.source = platform`。
- tx 平台需确认 getPlaylistTags 返回的 id 与其 getPlaylists(cat) 语义一致（参考 kg/kw/mg 的 id=分类id 模式），不一致则对齐。
- 播放 helper 复用 AudioSourceExecutor（JSVM）优先、ApiSource.getPlayUrl 兜底，并设置 remoteSongName/Singer/Cover/lyric。

## 架构设计
数据流向（音乐厅全链路）：

```mermaid
flowchart TD
  A[MusicHallPage] -->|平台切换/标签/排序| B[ApiSource.getPlaylists(platform,cat,order)]
  B --> C[musicSdk 各平台 getPlaylists]
  C --> D[MusichallPlaylistItem[] 含 source]
  A -->|点击歌单| E[SongListPage 远程模式]
  E --> F[ApiSource.getPlaylistSongs(platform,playlistId)]
  F --> G[SearchResultItem[]]
  G -->|点击歌曲| H[共享远程播放 helper]
  H --> I[AudioSourceExecutor / ApiSource.getPlayUrl]
  I --> J[PlaybackIntentState.remoteUrl + openPlayerUi]
  J --> K[播放内核消费]
```

## 目录结构与文件清单
```
common/musicbasic/src/main/ets/
├── data/MusichallPlaylistItem.ets        # [MODIFY] MusichallPlaylistItem 增加 source: string 字段
├── util/musicSdk/
│   ├── types.ets                         # [MODIFY] MusicPlatform.getPlaylists 签名增加 order 参数
│   ├── ApiSource.ets                     # [MODIFY] getPlaylists 增加 order 并透传；getPlaylistSongs 已存在
│   ├── wy/songList.ets                   # [MODIFY] getPlaylists 加 order + 设 item.source；getPlaylistTags 的 id 改为分类名
│   ├── tx/songList.ets                   # [MODIFY] getPlaylists 加 order + 设 item.source；核对 tags id 语义
│   ├── kg/songList.ets                   # [MODIFY] getPlaylists 加 order + 设 item.source
│   ├── kw/songList.ets                   # [MODIFY] getPlaylists 加 order + 设 item.source
│   └── mg/songList.ets                   # [MODIFY] getPlaylists 加 order + 设 item.source
├── util/RemotePlayHelper.ets             # [NEW] 共享远程播放函数：取流→设 PlaybackIntentState→openPlayerUi
└── components/SongListPage.ets           # [MODIFY] SongListParam.playlistId 改 string + 加 source；新增远程歌单模式

features/musichall/src/main/ets/view/
├── MusicHallPage.ets                     # [MODIFY] 平台切换/选标签/切排序均重新请求；种子仅作错误兜底
├── PlaylistCard.ets                      # [MODIFY] 点击传递 source 与字符串 playlistId
└── TagFilterSheet.ets                    # [确认] 选中态用 tag.id（与 getPlaylists cat 一致）

features/search/src/main/ets/viewmodel/
└── SearchResultViewModel.ets            # [MODIFY] playSong 改为调用共享 RemotePlayHelper（消除重复）
```

## 关键代码结构
```typescript
// MusichallPlaylistItem 新增字段
export class MusichallPlaylistItem {
  playlistId: string = ''
  title: string | Resource = ''
  coverImage: Resource | string = $r('app.media.ic_avatar1')
  playCount: string = ''
  tags: string[] = []
  source: string = ''   // 新增：所属平台，用于详情拉歌与播放取流
}

// SongListParam 改为支持远程歌单
export class SongListParam {
  title: string = ''
  listType: string = ''
  playlistId: string = ''   // 由 number 改为 string，避免大整数精度丢失
  source: string = ''       // 新增：平台标识
}

// musicSdk 统一签名（types.ets / ApiSource.ets）
getPlaylists!: (cat: string, page: number, limit: number, order?: string) => Promise<Array<MusichallPlaylistItem>>
```


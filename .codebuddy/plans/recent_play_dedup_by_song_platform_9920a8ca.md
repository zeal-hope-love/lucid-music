---
name: recent_play_dedup_by_song_platform
overview: 修复"最近播放"远程歌曲重播产生重复：把(平台,歌曲)稳定身份带进 SongItem，addRecentPlay 按复合 key 去重并提到最前。
todos:
  - id: songitem-fields
    content: SongItem 新增 platform 与 remoteSongId 字段（songData.ets）
    status: completed
  - id: intent-state-fields
    content: PlaybackIntentState 新增 remoteSongSource/remoteSongId 并在 resetRemote 重置
    status: completed
  - id: remote-helper-pass
    content: RemotePlayHelper.playSong 写入 intentState 的 source 与 songId
    status: completed
    dependencies:
      - songitem-fields
      - intent-state-fields
  - id: dispatcher-build
    content: PlaybackIntentDispatcher 构造远程 SongItem 时设置 platform/remoteSongId
    status: completed
    dependencies:
      - intent-state-fields
  - id: store-dedup
    content: MusicMemoryStore.addRecentPlay 改为复合 key 去重并置顶
    status: completed
    dependencies:
      - songitem-fields
---

## 用户需求
在"最近播放"列表中，同一首歌曲、同一平台再次播放时，应把该条目移动到列表最前面，而不是新增一条重复项。

## 产品概述
"最近播放"展示用户近期播放过的歌曲。当前远程歌曲（来自搜索/音乐厅等平台）每次播放都会生成新的负 id，导致去重失效、列表出现重复。需要按"歌曲相同 + 平台相同"这一稳定身份进行去重，命中则置顶、未命中才新增。

## 核心功能
- 本地歌曲（id 稳定）重播：仍按原逻辑去重并置顶。
- 远程歌曲（如酷狗/QQ/网易云/酷我/咪咕）重播同平台同歌曲：去重并置顶，不新增。
- 同歌曲但不同平台：视为不同条目（符合"平台相同才合并"的语义）。
- 收藏、播放器其它基于 id 的逻辑不受影响。


## 技术栈
- HarmonyOS ArkUI（ArkTS 严格模式），@ObservedV2 / @Trace
- 数据层：MusicMemoryStore 内存单例 + MusicDbApi 封装（最近播放为内存态，重启重置，与现状一致，本次不引入持久化）

## 实现方案

### 问题根因
`MusicMemoryStore.addRecentPlay`（第 162-167 行）按 `s.id === item.id` 去重。本地歌 id 稳定，去重有效；远程歌每次播放都经 `PlaybackIntentDispatcher` 重建 `SongItem` 并赋 `id = -Date.now()`（第 46 行），每次 id 不同 → `findIndex` 永远 -1 → 永远 `unshift` 新增 → 重复。

根因在于：`SearchResultItem` 本就携带稳定的 `songId` + `source`（平台），但 `PlaybackIntentState` 只透传了 name/singer/cover/lyric/url，**未透传 source/songId**，导致 `SongItem` 丢失"平台 + 歌曲身份"，无法做"歌曲+平台"去重。

### 修复策略
沿现有播放分发链路，把平台与原始 songId 透传到 `SongItem`，并将去重 key 改为复合身份：

1. **SongItem 增加身份字段**：`platform: string = ''`（远程来源平台，本地为空）、`remoteSongId: string = ''`（远程原始 songId，用于去重）。
2. **PlaybackIntentState 透传**：新增 `remoteSongSource: string = ''`、`remoteSongId: string = ''`；`resetRemote()` 一并重置。
3. **RemotePlayHelper.playSong**：在写入 intentState 时补充 `intentState.remoteSongSource = item.source`、`intentState.remoteSongId = item.songId`。
4. **PlaybackIntentDispatcher**：构造远程 `SongItem` 时设置 `songItem.platform = intentState.remoteSongSource`、`songItem.remoteSongId = intentState.remoteSongId`。
5. **MusicMemoryStore.addRecentPlay**：改为按复合 key 去重。新增私有 `recentKey(s: SongItem)`：远程（`platform !== ''`）返回 `platform + '#' + (remoteSongId || (title + '#' + singer))`；本地返回 `'local#' + id`。`findIndex` 用 key 比较，命中则 `splice` 后 `unshift`（置顶，逻辑不变）。

### 关键决策
- 用 `(platform, songId)` 作为远程歌稳定身份，精确对应"歌曲相同 + 平台相同"；`songId` 为空时退化为 `title#singer` 兜底，避免同平台空 id 互相合并。
- 本地歌保持 `local#id` 去重（等价于原 id 去重，且与远程 key 命名空间隔离，不会冲突）。
- 仅改去重 key，不引入持久化（最近播放本就是内存态，与现状一致，用户未要求持久化）。
- 不影响收藏（`favoriteSongIds` 按 id 独立逻辑）与播放器其它基于 id 的逻辑（PlayerPage / AVSessionController / MusicInfoComponent 不改）。

### 性能与兼容性
- 去重为 O(n) 线性查找，最近播放列表通常很短，开销可忽略；`unshift` 为 O(n) 数组前插，规模小无压力。
- 沿用现有 `ForEach` key（`recentPlayItems` 索引/对象），增量更新正常。
- 保持现有 Toast、刷新、本地/远程两类分支不变，仅扩展 `SongItem` 身份字段与去重链路。

## 架构设计
沿用现有播放分发链：`SearchResultViewModel/SearchPage → RemotePlayHelper → PlaybackIntentState → PlaybackIntentDispatcher → AudioPlayerController.playCurrent → MusicDbApi.addRecentPlay → MusicMemoryStore.recentPlayItems`。本次仅在链路上补充"平台 + 原始 songId"透传，并在末端把去重 key 从单一 id 升级为复合身份。

```mermaid
flowchart LR
  VM[SearchResultViewModel.playSong] --> RH[RemotePlayHelper.playSong]
  RH -->|写入 name/singer/cover/lyric/url + source/songId| IS[PlaybackIntentState]
  IS --> PD[PlaybackIntentDispatcher]
  PD -->|构造 SongItem: id/platform/remoteSongId| SI[SongItem]
  SI --> AC[AudioPlayerController.playCurrent]
  AC --> API[MusicDbApi.addRecentPlay]
  API --> ST[MusicMemoryStore.recentPlayItems]
  ST -->|复合 key 去重 + unshift 置顶| ST
```

## 目录结构
```
common/musicbasic/src/main/ets/
├── model/
│   ├── songData.ets            # [MODIFY] SongItem 新增 platform / remoteSongId 字段
│   └── PlaybackIntentState.ets # [MODIFY] 新增 remoteSongSource / remoteSongId，resetRemote 一并重置
├── util/
│   ├── RemotePlayHelper.ets   # [MODIFY] playSong 写入 intentState.remoteSongSource / remoteSongId
│   └── MusicDbApi.ets        # [不变] addRecentPlay 签名不变，仅底层 store 去重逻辑变更
└── db/
    └── MusicMemoryStore.ets   # [MODIFY] addRecentPlay 改为复合 key 去重（新增私有 recentKey）

features/player/src/main/ets/service/
└── PlaybackIntentDispatcher.ets # [MODIFY] 构造远程 SongItem 时设置 platform / remoteSongId
```


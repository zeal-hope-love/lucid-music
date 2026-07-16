---
name: fix-musiclist-audio-playback
overview: 修复 MusicListPage 三个入口显示相同列表的 bug，以及 AVPlayer 不自动播放导致没声音/进度条为 0 的状态机 bug
todos:
  - id: fix-musiclist-param
    content: 在 MusicListParam 中新增 listType 字段，类型为 string，默认值为 'local'
    status: completed
  - id: fix-musiclist-filter
    content: MusicListPage.aboutToAppear 按 listType 加载数据：'local' 调用 getSongList，'recent'/'favorite' 返回空数组
    status: completed
    dependencies:
      - fix-musiclist-param
  - id: fix-minepage-onclick
    content: MinePage.ets 三个入口 onClick 中创建 MusicListParam 时传入对应 listType（'local'/'recent'/'favorite'）
    status: completed
    dependencies:
      - fix-musiclist-param
  - id: fix-prepared-play
    content: AudioPlayerController.stateChangeCallback 'prepared' 分支末尾检查 waitPlay 并调用 avPlayer.play()
    status: completed
---

## 用户需求
1. MinePage 三个快捷入口（本地/最近播放/收藏）点击后应展示不同数据：本地显示全部歌曲(2首)，最近播放和收藏显示空列表
2. 点击歌曲后应有声音播放，进度条应正常走动

## 根因
1. **列表相同**：`MusicListPage.aboutToAppear` 始终调用 `MusicDbApi.getInstance().getSongList()` 获取全部歌曲，`param.title` 仅用于标题文字，未按入口类型过滤数据
2. **无声音/进度条为0**：`AudioPlayerController.loadAndPlay()` 设置 `waitPlay=true` 后，AVPlayer 自动流转到 `prepared` 状态，但 `stateChangeCallback` 的 `'prepared'` 分支只设置了 `duration`/`totalTime`，从未检查 `waitPlay` 并调用 `avPlayer.play()`，导致音频加载完成但从未实际播放

## 技术方案

### 修复1：MusicListPage 按入口类型加载不同数据

**策略**：在 `MusicListParam` 中新增 `listType` 字段（`'local' | 'recent' | 'favorite'`），`MusicListPage.aboutToAppear` 根据类型决定数据来源。

**改动文件**：
- `MusicListPage.ets` — `MusicListParam` 新增 `listType`，`aboutToAppear` 按类型加载数据
- `MinePage.ets` — `onClick` 传递 `MusicListParam` 时带上 `listType`

**数据策略**：
| listType | 数据来源 | 说明 |
|----------|---------|------|
| `'local'` | `MusicDbApi.getInstance().getSongList()` | 全部本地歌曲 |
| `'recent'` | 空数组 `[]` | 暂无最近播放存储 |
| `'favorite'` | 空数组 `[]` | 暂无收藏存储 |

### 修复2：prepared 后触发 play

**策略**：在 `AudioPlayerController.stateChangeCallback` 的 `'prepared'` 分支末尾，检查 `this.waitPlay` 标志，若为 `true` 则调用 `await this.avPlayer!.play()`。

**改动文件**：
- `AudioPlayerController.ets` — `'prepared'` 分支追加 waitPlay 检查

**状态机流转**：
```
avPlayer.url = url → initialized → prepare() → prepared
                                                  ↓ (新增)
                                          if waitPlay → play() → playing
```

### 改动量
仅涉及 3 个文件，合计约 15 行代码变更，无新增文件，复用现有架构模式。

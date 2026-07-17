---
name: fix-qqplay-seek-netease-cover-ui
overview: 修复三个问题：1）QQ音乐seek操作无状态守卫导致播放失败；2）网易云封面缺失——从搜索API提取封面作为兜底；3）播放状态提示字移出进度条容器，独立对齐。
todos:
  - id: fix-seek-guard
    content: AudioPlayerController.ets：seek() 添加 allowedStates 白名单守卫，非 prepared/playing/paused/completed 状态拒绝 seek 并打日志
    status: completed
  - id: fix-preparing-timeout
    content: AudioPlayerController.ets：loadAndPlay() 添加 15 秒超时兜底，超时未到 prepared 则设置 error 状态提示用户重试
    status: completed
    dependencies:
      - fix-seek-guard
  - id: fix-netease-cover
    content: WyMusicApi.ets mapList()：从搜索 API 响应的 album.picUrl 提取封面 URL 填入 coverUrl/cover 作为兜底
    status: completed
  - id: fix-ui-layout
    content: ControlAreaComponent.ets：将播放状态文字从进度条 Column 内移出为独立 Row，与时间数字行高度平齐
    status: completed
---

## 用户需求

### 问题一：QQ音乐 Seek 报错 + "正在准备播放"卡住
- QQ音乐播放时一直显示"正在准备播放"，无法进入播放状态
- 拖动进度条报错：`Operate Not Permit: current state is not prepared/playing/paused/completed, unsupport seek operation`
- 根因：`AudioPlayerController.seek()` 无状态守卫，AVPlayer 在 `preparing`（`initialized`）状态下调用 seek 会抛异常

### 问题二：网易云封面不显示
- 搜索结果和播放详情页都不显示网易云歌曲封面
- 根因：`WyMusicApi.mapList()` 故意将 `coverUrl`/`cover` 留空（搜索 API 只返回 `picId`），封面依赖 EAPI 异步获取，但 EAPI 请求可能失败
- 搜索 API 响应中实际包含 `album.picUrl` 字段可作为兜底

### 问题三：播放状态文字布局位置不当
- "正在准备播放..."等状态文字位于进度条容器内部
- 要求：独立出来，与进度条时间数字（`00:00 / 03:45`）高度对齐


## 技术方案

### 1. QQ Music Seek 状态守卫 + Preparing 超时兜底

**策略**：在 `AudioPlayerController.seek()` 中添加 AVPlayer 状态白名单检查，只允许 `prepared`/`playing`/`paused`/`completed` 状态下执行 seek。同时在 `loadAndPlay()` 后添加超时机制，若 15 秒内未到达 `prepared` 状态则报告错误。

**修改文件**：`features/player/src/main/ets/controller/AudioPlayerController.ets`

**seek 状态守卫**：
```typescript
public seek(ms: number): void {
  if (!this.avPlayer) { return }
  const allowed = ['prepared', 'playing', 'paused', 'completed']
  if (!allowed.includes(this.currentState)) {
    Logger.warn(`${TAG}: seek denied, state=${this.currentState}`)
    return
  }
  this.avPlayer.seek(ms)
}
```

**Preparing 超时**：在 `loadAndPlay()` 中设置 15 秒定时器，若超时未进入 `prepared`，设置 `playbackStatus = 'error'` 并提示"播放准备超时，请重试"。

### 2. 网易云封面兜底方案

**策略**：在 `WyMusicApi.mapList()` 中从搜索 API 响应的 `album.picUrl` 字段提取封面 URL，填入 `coverUrl` 和 `cover` 字段。保留 EAPI 封面获取流程作为高品质封面覆盖。

**修改文件**：`features/search/src/main/ets/service/platform/WyMusicApi.ets`

**mapList 修改**（第32-37行附近）：
从 `item['album']['picUrl']` 提取封面 URL：
```typescript
const album = item['album'] as Record<string, Object>
result.album = album ? (album['name'] as string) || '' : ''
// 从搜索API提取封面URL作为兜底
const picUrl = album ? (album['picUrl'] as string) || '' : ''
result.coverUrl = picUrl; result.cover = picUrl
```
EAPI 封面 (`getCoverViaEapi`) 在 `getPlayUrl` 中返回的 `result.cover` 会通过 `SearchResultViewModel` 覆盖此兜底值，因此不影响高优封面。

### 3. 播放状态文字布局重构

**策略**：将 `ControlAreaComponent` 中的状态文字 `Text` 从进度条 `Column` 内移到其外部，放在进度条容器和播放控制按钮之间，使用 `Row` 包裹并用居中对齐与时间数字高度平齐。

**修改文件**：`features/player/src/main/ets/view/ControlAreaComponent.ets`

**布局变更**（第136-145行 → 移到第146行 `}` 之后，第153行之前）：
```
Column (外层)
├── Column (进度条容器: Slider + 时间Row)  — 移除状态文字
├── Row (状态文字独立行，居中对齐)  ← 新增
└── Row (播放控制按钮)
```

状态文字 `Row` 设置 `.width('100%')` `.justifyContent(FlexAlign.Center)`，保持与时间行视觉平齐。字体大小 12、颜色白色 0.7 透明度保持不变。


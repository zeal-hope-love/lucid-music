---
name: fix-flash-and-layout
overview: 修复三个问题：1) 歌词↔封面切换时歌手和封面阴影闪烁（geometryTransition follow 值逻辑错误）；2) 内容区在 Stack 中因默认居中导致歌名不靠上，需改为顶部对齐。
todos:
  - id: fix-follow-logic
    content: PlayerInfoComponent.ets 修正 MusicInfoComponent 和 LyricsComponent 的 follow 表达式；Stack 添加 .alignContent(Alignment.Top)
    status: completed
  - id: align-singer-fontsize
    content: LyricsComponent.ets SM 分支歌手 Text 的 fontSize 从 singer_font_sm(12vp) 对齐为 font_fourteen(14fp)
    status: completed
---

## 用户需求
1. 从歌词页滑动到封面页时，歌手文本和封面底部阴影会闪烁
2. 封面页中，当底部控制栏不显示歌词状态文字时，歌名/歌手/封面区域不应垂直居中，应保持在顶部

## 核心修复

### 闪烁根因：geometryTransition follow 逻辑错误
在 `PlayerInfoComponent.ets` 中，两组件（MusicInfoComponent 和 LyricsComponent）各含 4 个 geometryTransition 标记（封面、歌名、歌手、收藏）。当前 `animateTo` 切换 `showLyrics` 时：
- 新出现的组件 `follow` 始终计算为 `playbackEntering`（false），即被标记为 source
- 离开的组件被 `if` 移除，其 geometry 无法被捕获
- 系统无 destination 元素，geometryTransition 异常导致闪烁

修正 follow 表达式使之在任何切换方向下都产生正确的 source→destination 配对。

### 歌名居中根因：Stack 默认 alignContent = Center
封面页内容区 Stack 未设置 `alignContent`，HarmonyOS Stack 默认值 `Alignment.Center` 导致 MusicInfoComponent 在剩余空间内垂直居中。当底部控制栏状态文字不显示时空间变大，居中偏移更明显。

修正为 `.alignContent(Alignment.Top)`。

### 辅助修复：歌手文字字号对齐
封面页歌手字号为 14fp（`font_fourteen`），歌词页歌手字号为 12vp（`singer_font_sm`），字号差异导致 geometryTransition 变形时发生额外的视觉跳动。对齐歌词页歌手字号为 14fp 消除此影响。


## 技术方案

### 修改文件及变更

#### `PlayerInfoComponent.ets` — follow 逻辑修正 + Stack 顶部对齐

**第 187 行** — MusicInfoComponent follow：
```
旧: follow: this.showLyrics || this.playbackEntering
新: follow: !this.showLyrics || this.playbackEntering
```

**第 193 行** — LyricsComponent follow：
```
旧: follow: !this.showLyrics || this.playbackEntering
新: follow: this.showLyrics && !this.playbackEntering
```

**第 202 行** — Stack alignContent（`.layoutWeight(1)` 之前添加）：
```typescript
.alignContent(Alignment.Top)
.layoutWeight(1)
```

#### `LyricsComponent.ets` — 歌手字号对齐

**第 146-150 行** — 歌手 Text 的 fontSize 从 BreakpointType 动态选择改为直接使用 `font_fourteen`（14fp）：
```
旧: .fontSize(new BreakpointType({ sm: $r('app.float.singer_font_sm'), ... }).getValue(this.currentBreakpoint))
新: .fontSize($r('app.float.font_fourteen'))
```
注：歌词页 SM 模式下之前已设置歌名 fontSize 为 `title_font_play`(20vp)，此分支仅在 SM 断点渲染，故直接硬编码无副作用。

### 验证矩阵

| 场景 | MusicInfo follow | Lyrics follow | 结果 |
|------|-----------------|---------------|------|
| MiniPlayerBar 进入 (playbackEntering=true) | !false ∥ true = true ✓ | — | 进入动画正常 |
| lyrics→cover (showLyrics: true→false) | !false = true (dest) | false | 从歌词歌手/封面变形到封面页 ✓ |
| cover→lyrics (showLyrics: false→true) | !true = false (src) | true (dest) | 从封面歌手/封面变形到歌词页 ✓ |
| 仅封面页 (steady) | !false = false | — | stay ✓ |
| 仅歌词页 (steady) | — | false | stay ✓ |

### 边界情况
- `playbackEntering` 为 true 时（从 MiniPlayerBar 进入），LyricsComponent 不渲染（`showLyrics` 为 false），其 follow 表达式不必关注
- Stack `alignContent(Top)` 不影响 LyricsComponent 的 slide 转场效果（LyricsComponent 有独立 `.margin({ top })` 控制位置）


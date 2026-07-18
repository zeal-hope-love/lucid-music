---
name: fix-playback-one-shot-transition-flicker
overview: 修复播放详情页歌词/封面切换时封面阴影闪烁和歌名歌手闪烁问题。根因是同一页面内的两个组件（MusicInfoComponent 和 LyricsComponent）对封面、歌名、歌手、收藏按钮使用了相同的 geometryTransition ID，导致内部切换时两个组件共存产生冲突。
todos:
  - id: fix-lyrics-component
    content: 修复 LyricsComponent.ets：移除全部5处 geometryTransition 绑定（封面×2、歌名、歌手、收藏按钮），移除不再使用的 @Prop follow 属性
    status: completed
  - id: fix-musicinfo-component
    content: 修复 MusicInfoComponent.ets：移除歌名、歌手、收藏按钮的3处 geometryTransition 绑定，仅保留封面 PLAYBACK_COVER_TRANSITION
    status: completed
  - id: fix-playerinfo-component
    content: 修复 PlayerInfoComponent.ets：简化 follow 传递逻辑，MusicInfoComponent 仅在 playbackEntering 时 follow=true，LyricsComponent 移除 follow 参数
    status: completed
    dependencies:
      - fix-lyrics-component
      - fix-musicinfo-component
  - id: verify-transition
    content: 验证 Navigation 入场/退场一镜到底（MiniPlayerBar↔封面）和歌词↔封面内部切换均正常无闪烁
    status: completed
    dependencies:
      - fix-playerinfo-component
---

## 问题描述
播放详情页从歌词页切换到封面页时，出现以下视觉闪烁问题：
1. **封面阴影闪烁**：切换瞬间封面出现双阴影（两个阴影重叠后消失）
2. **歌名、歌手文本闪烁**：切换瞬间歌名和歌手文本出现抖动/闪烁

## 根因分析
`PlayerInfoComponent.ets` 在 Stack 内使用 `if` 块 + `TransitionEffect` 控制 `MusicInfoComponent`（封面页）和 `LyricsComponent`（歌词页）切换。TransitionEffect 动画期间两个组件短暂共存于渲染树中。

两个组件对以下元素绑定了**完全相同的 `geometryTransition` ID**：
- `PLAYBACK_COVER_TRANSITION` — 封面图（两个组件各2处）
- `PLAYBACK_TITLE_TRANSITION` — 歌名文本
- `PLAYBACK_SINGER_TRANSITION` — 歌手文本
- `PLAYBACK_FAVORITE_TRANSITION` — 收藏按钮

动画期间 geometryTransition 系统检测到同一帧内有多个元素绑定相同 ID，尝试在它们之间做几何变形插值，导致：
- 两个封面 Image 各自渲染 `.shadow()` 叠加 → 双阴影闪烁
- 两个歌名/歌手 Text 的矩阵变换冲突 → 文本抖动

进一步发现：`MiniPlayerBar` 仅对封面做了 `geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: false })`，歌名、歌手、收藏按钮均无 geometryTransition。这意味着 `PLAYBACK_TITLE_TRANSITION`、`PLAYBACK_SINGER_TRANSITION`、`PLAYBACK_FAVORITE_TRANSITION` 这三个 ID 纯粹是同一页面内部冲突，没有任何跨页面用途。

## 参考项目结论（transitions-collection-master）
- geometryTransition 的正确用法：仅在两个不同 Navigation 页面间使用配对（源页面 `follow: true`，目标页面默认 `false`）
- 从不在同一页面内两个共存组件上使用相同 geometryTransition ID
- 未发现 `.shadow()` 与 `geometryTransition` 组合使用的场景


## 技术方案

### 修复策略
将 geometryTransition 的用途严格限定在 **Navigation 入场/退场的一镜到底转场**（MiniPlayerBar ↔ PlaybackPage 封面），移除所有同一页面内部切换场景下的 geometryTransition 绑定。

### 具体修改

#### 1. LyricsComponent.ets — 移除全部 geometryTransition
移除歌词页封面、歌名、歌手、收藏按钮的 geometryTransition 绑定（共5处），保留 `.shadow()` 和所有其他样式。

修改位置：
- 第115行：移除 `.geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })`
- 第135行：移除 `.geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })`
- 第152行：移除 `.geometryTransition('PLAYBACK_TITLE_TRANSITION', { follow: this.follow })`
- 第161行：移除 `.geometryTransition('PLAYBACK_SINGER_TRANSITION', { follow: this.follow })`
- 第171行：移除 `.geometryTransition('PLAYBACK_FAVORITE_TRANSITION', { follow: this.follow })`
- 移除不再使用的 `@Prop follow: boolean = false` 属性声明（第44行）

#### 2. MusicInfoComponent.ets — 仅保留封面 geometryTransition
保留封面的 `PLAYBACK_COVER_TRANSITION`（用于 Navigation 入场/退场一镜到底），移除歌名、歌手、收藏按钮的 geometryTransition。

修改位置：
- 第152行：移除 `.geometryTransition('PLAYBACK_TITLE_TRANSITION', { follow: this.follow })`
- 第164行：移除 `.geometryTransition('PLAYBACK_SINGER_TRANSITION', { follow: this.follow })`
- 第173行：移除 `.geometryTransition('PLAYBACK_FAVORITE_TRANSITION', { follow: this.follow })`

#### 3. PlayerInfoComponent.ets — 简化 follow 逻辑
- 第195行：`MusicInfoComponent({ follow: !this.showLyrics || this.playbackEntering })` → 改为 `MusicInfoComponent({ follow: this.playbackEntering })`
  - 封面页仅当 Navigation 入场/退场时设置 follow=true，内部切换不再触发
- 第201行：`LyricsComponent({ isTablet: this.isTabletFalse, follow: this.showLyrics && !this.playbackEntering })` → 改为 `LyricsComponent({ isTablet: this.isTabletFalse })`
  - 歌词页不再需要 follow 参数

### 影响范围
- **Navigation 入场一镜到底**（MiniPlayerBar → PlaybackPage 封面）：不受影响，MusicInfoComponent 封面在 `playbackEntering=true` 时仍设置 `follow=true`
- **Navigation 退场一镜到底**（PlaybackPage 封面 → MiniPlayerBar）：不受影响，同上
- **歌词↔封面内部切换**：TransitionEffect（translate 滑入/滑出）正常运作，仅移除冲突的 geometryTransition，视觉效果更干净
- **歌名/歌手/收藏按钮**：移除后不再闪烁，这些元素原本就没有跨页面的 geometryTransition 锚点

### 符合参考项目模式
修改后与 transitions-collection-master 项目模式完全一致：geometryTransition 仅用于不同 Navigation 页面间的共享元素转场。


---
name: fix-playback-one-shot-transition-flicker
overview: 修复播放详情页歌词↔封面内部切换时封面阴影闪烁（双阴影）和歌名/歌手闪烁问题。不删除 geometryTransition 架构，而是修复 .shadow() 与 geometryTransition 在同元素上的冲突，以及检查 .clip(false) 的影响。
todos:
  - id: fix-musicinfo-shadow
    content: 修复 MusicInfoComponent.ets：将封面 shadow 从 Image 移至外层 Stack 容器，删除 coverUrl 和 label 分支中 Image 上的 .shadow()，改为在 Image 外包裹 Stack 并设置 .shadow()
    status: pending
  - id: fix-musicinfo-geometry
    content: 修复 MusicInfoComponent.ets：移除歌名 Text（第152行）、歌手 Text（第164行）、收藏 SymbolGlyph（第173行）的 .geometryTransition() 绑定
    status: pending
  - id: fix-lyrics-shadow
    content: 修复 LyricsComponent.ets：将封面 shadow 从 Image 移至外层 Stack 容器，删除 coverUrl 和 label 分支中 Image 上的 .shadow()；同时将硬编码 borderRadius(6) 改为 $r('app.float.cover_radius_label') 统一
    status: pending
  - id: fix-lyrics-geometry
    content: 修复 LyricsComponent.ets：移除歌名 Text（第152行）、歌手 Text（第161行）、收藏 SymbolGlyph（第171行）的 .geometryTransition() 绑定
    status: pending
  - id: fix-clip-false
    content: 修复 MusicInfoComponent.ets：移除 Column（第78行）和 Row（第135行）上的 .clip(false)，shadow 移至容器后不再需要防止裁剪
    status: pending
    dependencies:
      - fix-musicinfo-shadow
  - id: verify-transition
    content: 验证完整流程：Navigation 入场一镜到底（MiniPlayerBar→封面）、内部歌词↔封面切换、Navigation 退场一镜到底，确保均无闪烁
    status: pending
    dependencies:
      - fix-musicinfo-shadow
      - fix-musicinfo-geometry
      - fix-lyrics-shadow
      - fix-lyrics-geometry
      - fix-clip-false
---

## 用户需求
播放详情页从歌词页切换到封面页时，封面阴影闪一下（似有两个阴影重叠），歌名和歌手也会闪一下。用户确认之前是正常的，后来某次修改后才出现问题。

## 产品概述
修复播放详情页内部歌词视图与封面视图切换时的视觉闪烁问题，保持 Navigation 入场/退场一镜到底（MiniPlayerBar 封面到播放页封面）不受影响。

## 核心功能修复
- 封面阴影：将 `.shadow()` 从 Image 元素移至外层容器，使 geometryTransition 仅作用于 Image 本身，避免两个带阴影的 Image 同时渲染导致阴影叠加闪烁
- 歌名/歌手/收藏：移除内部两个组件间的 geometryTransition 绑定（这些 ID 在 MiniPlayerBar 无匹配元素，只在同页内部产生冲突）
- 保持 Navigation 入场/退场一镜到底：MiniPlayerBar 封面的 geometryTransition 与 MusicInfoComponent 封面的配对不受影响

## 技术栈
- 框架：HarmonyOS ArkUI V2（@ComponentV2, @ObservedV2, @Trace, @Local, @Computed）
- 语言：ArkTS/TypeScript
- 状态管理：AppStorage + @StorageLink/@StorageProp
- 导航：NavPathStack（pushPath 入场、pop 退场，均 { animated: false }）
- 转场：geometryTransition + TransitionEffect

## 根因分析

### 封面双阴影
两个组件的封面 Image 同时绑定了 `.shadow()` 和 `.geometryTransition('PLAYBACK_COVER_TRANSITION')`：

| 属性 | MusicInfoComponent（封面页） | LyricsComponent（歌词页） |
|------|---------------------------|------------------------|
| shadow | radius:12vp, color:#66000000, y:8 | **完全相同** |
| geometryTransition ID | PLAYBACK_COVER_TRANSITION | PLAYBACK_COVER_TRANSITION |
| 尺寸 | 100% 宽 | 48vp 宽 |
| borderRadius | 8vp | 6（硬编码） |

歌词↔封面切换时，两个 Image 在 transition 动画期间共存，各自渲染 shadow，导致阴影叠加 → "两个阴影"闪烁。

**对比 MiniPlayerBar**：封面只有 geometryTransition（`follow: false`），**无 .shadow()**。因此 Navigation 入场/退场时只有 MusicInfoComponent 单方面渲染 shadow → 不会出现双阴影。

### 歌名/歌手/收藏闪烁
两个组件的 Text/SymbolGlyph 绑定相同的 geometryTransition ID（PLAYBACK_TITLE_TRANSITION、PLAYBACK_SINGER_TRANSITION、PLAYBACK_FAVORITE_TRANSITION）。MiniPlayerBar 没有对应匹配元素，这些 ID 仅在内部两个组件间使用。切换时两个位置/尺寸不同的元素尝试 geometry-morph，产生闪烁。

## 实现方案

### 封面 shadow 修复策略
将 `.shadow()` 从 Image 移至外层容器（Stack），使 geometryTransition 只影响 Image 像素内容，不携带阴影。外层容器的 shadow 不受 geometryTransition 影响，保持稳定。

```
修复前: Image → .shadow() + .geometryTransition() → 双阴影闪烁
修复后: Stack(.shadow()) → Image → .geometryTransition() → 阴影稳定
```

### 歌名/歌手/收藏修复策略
直接移除两个组件中 title/singer/favorite 上的 `.geometryTransition()`。内部切换依赖已有的 `TransitionEffect`（歌词页 translate 滑入/滑出）提供视觉过渡。

### MusicInfoComponent .clip(false) 处理
检查并移除不必要的 `.clip(false)`（第78行 Column、第135行 Row）。修复后 shadow 在 Stack 容器上，不再需要 `.clip(false)` 来防止裁剪。默认 `clip(true)` 行为更安全。

### LyricsComponent borderRadius 统一
将硬编码 `borderRadius(6)` 改为使用资源引用或与封面页一致的 `$r('app.float.cover_radius_label')`（8vp），消除 geometryTransition 时的形状差异。

### PlayerInfoComponent follow 简化
移除 title/singer/favorite 的 geometryTransition 后，follow 参数仅影响封面的 geometryTransition。逻辑保持不变：内部切换时 `showLyrics` 控制是否 follow，Navigation 出入场时 `playbackEntering` 控制。

## 修改文件清单

```
features/player/src/main/ets/view/
├── MusicInfoComponent.ets   # [MODIFY] 封面 shadow 移至容器；移除 title/singer/favorite 的 geometryTransition
├── LyricsComponent.ets      # [MODIFY] 封面 shadow 移至容器；移除 title/singer/favorite 的 geometryTransition；统一 borderRadius
└── PlayerInfoComponent.ets  # [MODIFY] 检查 follow 传递逻辑是否需要调整（移除 title/singer/favorite geometryTransition 后无实质变化）
```

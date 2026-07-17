---
name: fix-cover-shadow-lyrics-transition
overview: 修复四个问题：1) 内置歌曲（如 Dream It Possible）封面不显示（coverUrl 空时需 fallback 到 label）；2) 封面页阴影可能被父容器裁切；3) 歌词页无封面时移除临时图标改为透明占位；4) 歌名一镜到底因两页 fontSize 不同（20vp vs 16vp）导致跳动。
todos:
  - id: fix-cover-fallback
    content: MusicInfoComponent.ets CoverInfo 增加 label 兜底：coverUrl 空时回退到 label Image；父 Row 加 .clip(false) 确保阴影不裁切
    status: completed
  - id: fix-lyrics-cover
    content: LyricsComponent.ets 去掉 ic_music_symbol 临时图标，改为 label 兜底 + 透明占位；SM 歌名 fontSize 从 title_font_sm(16vp) 对齐 title_font_play(20vp)
    status: completed
---

## 产品概述
修复播放器详细页四个 UI 和交互问题，覆盖内置歌曲封面显示、阴影效果、歌词页临时图标、歌名一镜到底动画跳动。

## 核心功能
- **内置歌曲封面兜底**：Dream It Possible 等本地歌曲（coverUrl 为空但 label 有真实封面图如 ic_dream）在 CoverInfo 和歌词页中正确显示封面
- **封面阴影可见**：CoverInfo 父容器 Row 添加 `.clip(false)` 防止阴影被裁切，确保圆形封面阴影正常渲染
- **歌词页去掉临时图标**：无封面时不再显示 `ic_music_symbol` 音符图标，改用 label 兜底或透明占位
- **歌名一镜到底平滑**：歌词页 SM 模式歌名字号从 `title_font_sm`(16vp) 对齐到封面页的 `title_font_play`(20vp)，消除 geometryTransition 切换时的文字大小跳动

## 技术方案

### 实现方案

四个修复均集中在两个文件，修改方式轻量且对齐现有 `MiniPlayerBar.ets` 的封面 fallback 模式（coverUrl → label → 兜底图标）。

#### 1. 内置歌曲封面显示
**策略**：`MusicInfoComponent.CoverInfo()` 和 `LyricsComponent` 封面区增加 `coverUrl → label` 两级 fallback。

现有 `MiniPlayerBar.coverSource` 已实现此模式：
```typescript
if (song?.coverUrl) return song.coverUrl
if (song?.label) return song.label
return $r('app.media.ic_music_symbol')
```

CoverInfo 和歌词页采用相同逻辑：
- `coverUrl` 非空 → 显示网络封面
- `coverUrl` 空但 `label` 有效 → 显示 label（内置歌曲的专辑图）
- 两者都空 → 透明占位 Row（不显示任何图标）

注意：`label` 字段在 ArkUI 中类型为 `Resource`（内置歌曲才是真实图片资源），远程歌曲的 label 可能是 `$r('app.string.page_show')` 等非图片资源。判断 `label` 有效性只需确认 `this.songList[this.selectIndex].label` 存在即可，`Image()` 组件渲染 Resource 会自动处理。

#### 2. 封面阴影
**根因**：ArkUI 中 Row/Column 默认 clip 子元素溢出内容，`.shadow()` 的阴影扩散超出元素边界，被父 Row 裁切。

**修复**：CoverInfo 的包裹 Row 添加 `.clip(false)`，让阴影完整渲染。同时确保 Image 的 `.borderRadius()` 仍在 Image 本身上设置。

#### 3. 歌词页临时图标移除
**修复**：LyricsComponent SM 模式中，将 `else { Image($r('app.media.ic_music_symbol')) ... }` 分支替换为 `else if (this.songList[this.selectIndex].label) { Image(this.songList[this.selectIndex].label) ... }`，最后 else 分支为透明占位 Row。

#### 4. 歌名一镜到底对齐
**根因**：geometryTransition 要求两个标记元素具有相同的尺寸属性，否则动画会从一个大尺寸"跳"到另一个。当前封面页歌名 20vp，歌词页歌名 16vp，切换时字体突然变大/变小。

**修复**：LyricsComponent SM 模式下歌名 fontSize 改为直接使用 `$r('app.float.title_font_play')`（20vp），去掉 BreakpointType 动态选择。由于歌词页仅 SM/LG 下渲染 SM 分支，此改动不影响其他断点。

### 实现细节

#### 性能考量
- label fallback 仅为本地 Resource 引用切换，无网络请求，零性能开销
- `.clip(false)` 是静态属性，不影响布局性能
- fontSize 对齐消除 geometryTransition 重算开销

#### 日志
- 无需额外日志，改动为纯 UI 渲染层

#### 兼容性
- 不影响 MiniPlayerBar 的封面显示逻辑
- 不影响远程歌曲（coverUrl 存在时优先走 coverUrl 分支）
- 不影响 LG/Fold 断点布局

---
name: rewrite-playback-one-shot-transition
overview: 重写播放详情页内部歌词↔封面切换的一镜到底动画。将当前的 if/if + TransitionEffect + geometryTransition 混合方案改为 if/else，让 geometryTransition 独立驱动共享元素的 morph 动画，避免多动画冲突导致的突变。
todos:
  - id: fix-playerinfo-if-else
    content: 重写 PlayerInfoComponent.ets 内容区：if/if 改为 if/else，删除 TransitionEffect.IDENTITY 和 translate，简化 follow 传递逻辑
    status: pending
  - id: fix-musicinfo-remove-geo
    content: 精简 MusicInfoComponent.ets：删除歌名(152行)、歌手(164行)、收藏(173行)的 .geometryTransition()，仅保留封面 PLAYBACK_COVER_TRANSITION
    status: pending
  - id: fix-lyrics-remove-geo
    content: 精简 LyricsComponent.ets：删除歌名(152行)、歌手(161行)、收藏(171行)的 .geometryTransition()，仅保留封面 PLAYBACK_COVER_TRANSITION
    status: pending
  - id: verify-all-transitions
    content: 验证完整链路：Navigation入场一镜到底、歌词↔封面内部切换双向、Navigation退场一镜到底
    status: pending
    dependencies:
      - fix-playerinfo-if-else
      - fix-musicinfo-remove-geo
      - fix-lyrics-remove-geo
---

## 用户需求
重写播放详情页歌词视图与封面视图之间的内部切换动画。当前从歌词页切换到封面页时，在动画末尾封面阴影变浅、歌名歌手字体变细。封面页切换到歌词页正常。

## 核心功能要求
- R1: 封面图片在内部切换时平滑 morph（小变大 / 大变小），无属性突变
- R2: 歌名、歌手、收藏按钮在切换时不闪烁不突变
- R3: 歌词文本区域有自然的出现/消失过渡效果
- R4: Navigation 入场/退场一镜到底（MiniPlayerBar 圆形封面 ↔ 播放页大封面）保持不变
- R5: 水平滑动切换手势行为不变

## 根因分析

当前架构使用 `if/if` 双分支 + `TransitionEffect` + `geometryTransition` 三种动画机制混合，三者互相冲突：

1. **if/if 双分支共存**：`showLyrics` 切换时两个 if 块同时激活，两个组件的封面/歌名/歌手/收藏都绑定相同 geometryTransition ID（PLAYBACK_COVER_TRANSITION / PLAYBACK_TITLE_TRANSITION / PLAYBACK_SINGER_TRANSITION / PLAYBACK_FAVORITE_TRANSITION），系统无法确定以谁为源谁为目标

2. **TransitionEffect.IDENTITY + geometryTransition 时序冲突**：MusicInfoComponent 使用 IDENTITY（瞬间出现），geometryTransition 还在逐帧插值封面从小到大的形态。动画末尾 geometryTransition 结束，框架将渲染权交还给组件自身 → 属性从插值状态跳变到最终状态（阴影/字体）

3. **TransitionEffect.translate + geometryTransition 空间冲突**：translate({x:400}) 移动整个 LyricsComponent（包括封面 Image），同时 geometryTransition 也在变形封面位置 → 双重位置变换相互叠加

4. **歌名/歌手/收藏 geometryTransition 纯内部冲突**： MiniPlayerBar 仅绑定了 PLAYBACK_COVER_TRANSITION（follow=false），没有匹配 PLAYBACK_TITLE_TRANSITION / PLAYBACK_SINGER_TRANSITION / PLAYBACK_FAVORITE_TRANSITION。这三个 ID 仅在内部两个组件间使用，移除后不影响任何跨页面功能

## 重写方案

### 核心思路：if/else + geometryTransition 独立驱动

将 `if/if + TransitionEffect + geometryTransition` 三重冲突架构替换为 `if/else + geometryTransition` 单一驱动：

- **if/else** 确保同一时刻只有一个组件在渲染树上，geometryTransition 明确知道源（旧组件元素）和目标（新组件元素）
- **移除所有 TransitionEffect**，让 geometryTransition 独立处理封面的几何过渡
- **移除歌名/歌手/收藏的 geometryTransition**，这些元素用 if/else 的原生分支切换效果或简单 opacity 动画过渡即可
- **animateTo + springMotion 驱动 showLyrics** 状态变化，geometryTransition 在状态变化时自动捕获旧/新元素形态差异并平滑插值

### 数据流

```
用户滑动手势 → animateTo(springMotion) { showLyrics = !showLyrics }
  → if/else 分支切换
    → LyricsComponent 销毁 / MusicInfoComponent 创建（或反之）
      → geometryTransition 捕获前后两个封面的位置/大小/圆角差异
        → 自动插值过渡
```

### Navigation 一镜到底不受影响

- MiniPlayerBar 封面：`geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: false })` 不变
- MusicInfoComponent 封面：`geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })`，follow 由 playbackEntering 控制
- LyricsComponent 封面：同样保留 PLAYBACK_COVER_TRANSITION，参与 if/else 切换时的封面 morph
- 退场时 playbackEntering=true，MiniPlayerBar 可见，封面从播放页 morph 回 MiniPlayerBar

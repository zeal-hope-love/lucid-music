---
name: rewrite-playback-one-shot-transition
overview: 将 PlayerInfoComponent 内容区的 if/if + TransitionEffect 改为 if/else，让 geometryTransition 独立驱动封面、歌名、歌手、收藏的全部元素 morph，消除多动画冲突。
todos:
  - id: fix-content-area
    content: 修复 PlayerInfoComponent.ets 第192-210行：if/if 改为 if/else，删除两个 .transition() 调用
    status: completed
  - id: verify-transition
    content: 验证歌词页到封面页切换动画无阴影变浅和字体变细突变，双向切换平滑
    status: completed
    dependencies:
      - fix-content-area
---

## 用户需求
修复播放详情页歌词页到封面页切换时的一镜到底动画瑕疵。多个元素（封面、歌名、歌手、收藏按钮）应同时参与 geometryTransition 平滑过渡，不冲突。当前歌词页到封面页方向动画末尾出现封面阴影变浅、字体变细的突变。

## 核心修复
将内容区从 `if/if` 双分支 + TransitionEffect 混合架构改为 `if/else` 单一分支 + geometryTransition 独立驱动。仅修改 PlayerInfoComponent.ets 一个文件，不动 MusicInfoComponent 和 LyricsComponent 的 geometryTransition 绑定。


## 技术方案

### 问题根因
当前 PlayerInfoComponent.ets 第192-210行使用 `if/if` 双分支，切换时两个组件同时存在，且各自绑定了 TransitionEffect（MusicInfoComponent 用 IDENTITY 瞬间出现，LyricsComponent 用 translate 滑出）。TransitionEffect 与 geometryTransition 在相同时刻作用于相同元素，产生动画时序冲突，导致过渡末尾属性跳变。

### 修复策略
将 `if/if` 改为 `if/else`，删除两个 TransitionEffect，让 `animateTo(springMotion)` 驱动 `showLyrics` 状态切换，geometryTransition 自动捕获新旧元素形态差异并平滑插值。

### 改动详情

仅修改 `features/player/src/main/ets/view/PlayerInfoComponent.ets` 第192-210行：

**修改前（第192-210行）：**
```typescript
// === 内容区（if/if + transition + geometryTransition） ===
Stack() {
  if (!this.showLyrics) {
    MusicInfoComponent({ follow: !this.showLyrics || this.playbackEntering })
      .transition(TransitionEffect.IDENTITY)
      .margin({ bottom: $r('app.float.music_component_bottom') })
  }

  if (this.showLyrics) {
    LyricsComponent({ isTablet: this.isTabletFalse, follow: this.showLyrics && !this.playbackEntering })
      .transition(
        TransitionEffect.asymmetric(
          TransitionEffect.translate({ x: 400 }).animation({ curve: curves.springMotion() }),
          TransitionEffect.translate({ x: 400 }).animation({ duration: 400, curve: Curve.EaseInOut })
        )
      )
      .margin({ top: $r('app.float.margin_lyric') })
  }
}
```

**修改后：**
```typescript
// === 内容区（if/else + geometryTransition 独立驱动） ===
Stack() {
  if (!this.showLyrics) {
    MusicInfoComponent({ follow: !this.showLyrics || this.playbackEntering })
      .margin({ bottom: $r('app.float.music_component_bottom') })
  } else {
    LyricsComponent({ isTablet: this.isTabletFalse, follow: this.showLyrics && !this.playbackEntering })
      .margin({ top: $r('app.float.margin_lyric') })
  }
}
```

### 数据流
```
手势滑动 → animateTo(springMotion) { showLyrics 切换 }
  → if/else 分支切换（旧组件销毁，新组件创建）
    → geometryTransition 检测 PLAYBACK_COVER_TRANSITION / PLAYBACK_TITLE_TRANSITION / PLAYBACK_SINGER_TRANSITION / PLAYBACK_FAVORITE_TRANSITION 前后元素差异
      → 自动插值：封面(大小+圆角+阴影)、歌名(字号+位置)、歌手(字号+位置)、收藏(位置)
```

### 不变项
- MusicInfoComponent 四个 geometryTransition 绑定不变
- LyricsComponent 四个 geometryTransition 绑定不变
- follow 参数传递逻辑不变（playbackEntering 控制 Navigation 一镜到底）
- 手势滑动逻辑不变
- ControlAreaComponent 及其他布局不变

## 技术风险
无。if/else 是 ArkUI 原生分支语法，geometryTransition 本身就是为跨分支元素过渡设计的。移除的 TransitionEffect 原用于歌词页滑入滑出效果，现由 geometryTransition 的几何 morph 替代，视觉效果更统一。


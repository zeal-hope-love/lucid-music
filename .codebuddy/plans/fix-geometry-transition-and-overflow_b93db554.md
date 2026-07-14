---
name: fix-geometry-transition-and-overflow
overview: 恢复一镜到底动画（push/pop 加回 animated:false），修复搜索框溢出（AreaWithHdsTabBar 内部移除固定宽度改为 '100%'，但各调用方外部显式指定宽度保持原有布局）
todos:
  - id: fix-geometry-transition
    content: "恢复一镜到底：HomePage pushPath 加 { animated: false }，SearchPage pop 加 undefined, false"
    status: completed
  - id: fix-area-width
    content: AreaWithHdsTabBar.ets 第 25 行 .width(this.barWidth) 改为 .width('100%')，解除强制固定宽度
    status: completed
  - id: fix-miniplayer-width
    content: MiniPlayerBar.ets AreaWithHdsTabBar 后补 .width(this.barWidth) 保持固定宽度
    status: completed
    dependencies:
      - fix-area-width
  - id: fix-tabbar-width
    content: LucidTabBar.ets AreaWithHdsTabBar 后补 .width(this.barWidth) 保持固定宽度
    status: completed
    dependencies:
      - fix-area-width
  - id: fix-back-btn-width
    content: SearchPage.ets 返回按钮 AreaWithHdsTabBar 后补 .width(40) 保持固定宽度
    status: completed
    dependencies:
      - fix-area-width
---

## 用户需求

1. **恢复一镜到底转场动画**：首页点击搜索框后，应使用 geometryTransition 实现搜索框平滑变形过渡（一镜到底），而非 Navigation 默认的左滑动画。
2. **修复首页搜索框右侧溢出**：搜索框右边缘超出屏幕，需要修复宽度适配。

## 根因分析

**一镜到底问题**：上一轮对话中 `{ animated: false }` 被误移除，恢复为默认动画。实际上 geometryTransition 需要禁用 Navigation 默认动画才能独占转场——否则默认左滑会覆盖 geometryTransition 的变形效果。

**溢出问题**：`AreaWithHdsTabBar` 内部第 25 行 `.width(this.barWidth)` 强制固定宽度。当 `SearchInputArea` 在 HomePage 被 `.width('90%')` 约束时（约 324dp），内部 `HdsTabs` 仍保持 `barWidth: 360`（默认值），导致约 36dp 溢出屏幕右侧。

## 技术方案

### 修复一镜到底转场

在 `NavPathStack.pushPath` 和 `NavPathStack.pop` 中传入动画禁用参数，阻止 Navigation 默认滑动动画，让 geometryTransition 独占转场：

- **HomePage.ets 第 41 行**：`pushPath` 添加 `{ animated: false }` 选项对象
- **SearchPage.ets 第 71 行**：`pop` 添加 `undefined, false` 参数（pop 的第二参数类型为 `boolean`，非对象）

### 修复搜索框溢出

核心改动在 `AreaWithHdsTabBar`：将内部 `.width(this.barWidth)`（第 25 行）改为 `.width('100%')`，使其自适应父容器宽度。然后为原本依赖固定宽度的三个调用方显式添加外部宽度约束：

| 调用方 | 文件 | 添加内容 |
|--------|------|----------|
| MiniPlayerBar | `MiniPlayerBar.ets` 第 221 行 | `.width(this.barWidth)` |
| LucidTabBar | `LucidTabBar.ets` 第 68 行 | `.width(this.barWidth)` |
| SearchPage 返回按钮 | `SearchPage.ets` 第 295 行 | `.width(40)` |

`SearchInputArea` 已在 build 末尾有 `.width('100%')`，无需额外修改，它会自动填满父容器。

### 影响范围

- `AreaWithHdsTabBar` 的修改影响所有调用方，但通过外部显式宽度约束保持了 MiniPlayerBar、LucidTabBar、SearchPage 返回按钮的原有固定宽度行为
- `SearchInputArea` 在 HomePage 中由 `.width('90%')` 约束，内部 `AreaWithHdsTabBar` 改为 `'100%'` 后自动适配，不再溢出
- 一镜到底的 `{ animated: false }` 仅影响首页→搜索页的 push/pop 路由动画

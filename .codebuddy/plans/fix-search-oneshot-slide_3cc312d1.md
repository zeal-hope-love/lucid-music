---
name: fix-search-oneshot-slide
overview: 修复搜索框一镜到底转场中叠加的 Navigation 左滑动画：移除 push/pop 外层的 animateTo 包裹、去掉冲突的组件级 transition、并修正 geometryTransition 的 follow 方向，使其对齐能正常工作的播放器一镜到底实现。
todos:
  - id: fix-search-input-area
    content: SearchInputArea 改 isFollow 默认 false 并删除冲突 transition
    status: completed
  - id: fix-homepage-push
    content: HomePage 移除 animateTo 包裹 pushPath 并显式 isFollow:false
    status: completed
    dependencies:
      - fix-search-input-area
  - id: fix-pop-paths
    content: Index 与 SearchPage 移除 animateTo 包裹 pop 并设 SearchPage isFollow:true
    status: completed
    dependencies:
      - fix-search-input-area
  - id: verify-transition
    content: 验证打开/返回两方向仅一镜到底无左滑
    status: completed
    dependencies:
      - fix-homepage-push
      - fix-pop-paths
---

## 用户需求
消除搜索框一镜到底转场中叠加的 Navigation 默认左滑动画，恢复搜索框从首页到搜索页、以及搜索页返回首页两个方向的丝滑「一镜到底」共享元素转场。

## 核心特性
- 首页点击搜索框 → 搜索页：搜索框以共享元素方式平滑放大/位移至搜索页顶部，无左滑页面转场叠加。
- 搜索页返回首页（返回键与系统返回）：搜索框以共享元素方式平滑收回到首页原位，无左滑页面转场叠加。
- 不影响播放器一镜到底及其他路由（Settings / MusicList / PlaylistDetailPage）的既有转场表现。


## 技术栈
- HarmonyOS ArkUI（ArkTS / .ets），现有项目，沿用 `@ComponentV2` + `geometryTransition` 共享元素转场方案。
- 导航：`NavPathStack` + `navDestination` builder，转场由 `{ animated: false }` / `pop(false)` 禁用 Navigation 默认页面动画。

## 根因分析
左滑是 Navigation 的默认页面转场（左右滑入）。搜索的 push/pop 被包在 `animateTo({ curve: interpolatingSpring(...) })` 闭包中——在 `animateTo` 上下文内调用 `pushPath`/`pop` 时，`{ animated: false }` 与 NavDestination 上的 `.transition(...)` 均被忽略，animateTo 会强制 Navigation 用其默认滑入转场，从而与 `geometryTransition` 叠加成「左滑 + 一镜到底」。

对照播放器一镜到底（已验证正常）：`openPlayback()` 直接 `pushPath(..., { animated: false })`，**不包 animateTo**，`MiniPlayerBar` 源 `follow:false` / `MusicInfoComponent` 目标 `follow:this.follow(=true)`，系统自动驱动 geometryTransition 动画。搜索实现与这一范式有三处偏差：
1. push/pop 被 `animateTo` 包裹（根因，导致左滑）。
2. `SearchInputArea` 额外 `.transition(TransitionEffect.opacity(0.99))` 与 geometryTransition 冲突（会加剧动画末尾属性突变）。
3. `follow` 方向反了：首页源应为 `false`、搜索页目标应为 `true`，当前首页默认 `true`、搜索页 `false`。

## 实现方案
对齐播放器已验证范式，做最小改动：
- **移除 animateTo 包裹**：`HomePage.onTap`、`Index.ets` Search `onBackPressed`、`SearchPage` onBack 中，直接调用 `pushPath(..., { animated: false })` / `pop(false)`，不再用 `animateTo` 包裹。系统会在 `animated:false` 下自动播放 geometryTransition 动画。
- **删除冲突 transition**：移除 `SearchInputArea` 根节点的 `.transition(TransitionEffect.opacity(0.99))`。
- **修正 follow 方向**：`SearchInputArea` 的 `isFollow` 默认值改为 `false`（首页源锚点）；`SearchPage` 显式传 `isFollow: true`（跟随目标）；`HomePage` 显式传 `isFollow: false` 以保持清晰。

## 实现注意
- 仅改动搜索一镜到底相关逻辑，禁止触碰播放器（`MiniPlayerBar`/`MusicInfoComponent`/`openPlayback`）与其他路由。
- 编辑前先读取文件完整内容，避免误改；保留 `animated: false` / `pop(false)` 不可省略，否则会重新出现页面转场。
- `SearchPage` onBack 有两处返回路径（结果模式返回建议列表、普通返回），均需保持 `pop(false)` 且无 animateTo 包裹。
- 修改后需真机/模拟器验证两个方向：打开搜索页、点返回键返回、系统左滑手势返回，确认只剩一镜到底、无左滑。

## 架构设计
本修复不改变现有导航架构，仅纠正搜索共享元素转场的动画驱动方式与 follow 方向。转场数据流保持：
首页 SearchInputArea(follow:false) --push(animated:false)--> 搜索页 SearchInputArea(follow:true)，共享 `SEARCH_ONE_SHOT_TRANSITION_ID` 由系统在导航瞬间自动补间宽高/位置。

## 目录结构与改动文件
```
common/musicbasic/src/main/ets/components/search/SearchInputArea.ets   # [MODIFY] isFollow 默认值 false；删除根节点 .transition(TransitionEffect.opacity(0.99))
features/home/src/main/ets/view/HomePage.ets                          # [MODIFY] SearchInputArea 显式 isFollow:false；onTap 移除 animateTo 包裹，直接 pushPath(..., { animated: false })
entry/src/main/ets/pages/Index.ets                                     # [MODIFY] Search NavDestination 的 onBackPressed 移除 animateTo 包裹，直接 navPathStack.pop(false)
features/search/src/main/ets/view/SearchPage.ets                      # [MODIFY] SearchInputArea 显式 isFollow:true；onBack 移除 animateTo 包裹，直接 navPathStack.pop(false)
```

## 关键代码结构
```ts
// SearchInputArea.ets —— follow 默认值改为 false（首页源锚点）
@Param isFollow: boolean = false

// HomePage.ets —— 源：follow:false，直接 push（无 animateTo）
SearchInputArea({ isFollow: false, /* ... */ onTap: () => {
  this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.SEARCH, undefined), { animated: false })
}})

// SearchPage.ets —— 目标：follow:true，直接 pop（无 animateTo）
SearchInputArea({ isFollow: true, /* ... */ })
this.navPathStack.pop(false)
```


---
name: fix-navigation-push-white-screen
overview: 修复 push 页面白屏、返回键偏移、封面错位三个连锁问题。核心：pushPathByName → pushPath，builder 中用 NavDestination 包裹页面控制属性。
todos:
  - id: fix-index-builder
    content: Index.ets：openPlayback 的 pushPathByName 改为 pushPath(NavPathInfo)，navDestinationBuilder 中 SearchPage/PlaybackPage 用 NavDestination(){}.hideTitleBar(true) 包裹
    status: completed
  - id: fix-homepage-pushes
    content: HomePage.ets：SearchInputArea onTap + MiniPlayerBar onTap 两处 pushPathByName 改为 pushPath(NavPathInfo)
    status: completed
    dependencies:
      - fix-index-builder
  - id: fix-musichall-push
    content: MusicHallPage.ets：MiniPlayerBar onTap 的 pushPathByName 改为 pushPath
    status: completed
    dependencies:
      - fix-index-builder
  - id: fix-mine-push
    content: MinePage.ets：MiniPlayerBar onTap 的 pushPathByName 改为 pushPath
    status: completed
    dependencies:
      - fix-index-builder
  - id: fix-searchpage-push
    content: SearchPage.ets：MiniPlayerBar onTap 的 pushPathByName 改为 pushPath
    status: completed
    dependencies:
      - fix-index-builder
  - id: lint-all
    content: 全量 lint 验证 6 个文件编译无错误
    status: completed
    dependencies:
      - fix-homepage-pushes
      - fix-musichall-push
      - fix-mine-push
      - fix-searchpage-push
---

## 现象
1. 主页点击搜索框 → 白屏，仅状态栏处返回键（被遮挡）
2. 点击 MiniPlayerBar → 同白屏
3. 返回后 MiniPlayerBar 封面在屏幕上部很大

## 根因
日志 `can't find name in config file: Search → create empty node`：`pushPathByName` 要求路由在系统路由表中注册，未注册时 Navigation 创建空 NavDestination（无内容、无 hideTitleBar），仅渲染系统默认返回键。

## 核心修复
1. 全部 6 处 `pushPathByName` → `pushPath(new NavPathInfo(...))` — pushPath 直接通过 navDestination builder 解析，无需系统路由注册
2. Index.ets 的 `navDestinationBuilder` 显式包裹 `NavDestination() { ... }.hideTitleBar(true)` — 确保 Search/Playback 页面作为完整 NavDestination 渲染
3. geometryTransition 已有正确配置（MiniPlayerBar follow:true, PlaybackPage follow:false），修复 push 路径后动画自动恢复

## 技术方案

### pushPathByName vs pushPath 差异
| API | 行为 | 问题 |
|-----|------|------|
| `pushPathByName(name, param)` | 先查系统 route_map.json → 再调 builder | 未注册时创建空 NavDestination |
| `pushPath(new NavPathInfo(name, param))` | 直接通过 builder 解析 name → 创建 NavDestination | 无需系统注册 |

### 修改清单（6 个文件，8 处改动）

#### 1. entry/.../Index.ets
**openPlayback 方法**：`pushPathByName(PLAYBACK, undefined)` → `pushPath(new NavPathInfo(PLAYBACK, undefined))`

**navDestinationBuilder**：返回到渲染的 SearchPage/PlaybackPage 显式包裹 NavDestination：
```typescript
@Builder
navDestinationBuilder(name: string, _param: Object) {
  if (name === 'Search') {
    NavDestination() {
      SearchPage()
    }.hideTitleBar(true)
  } else if (name === 'Playback') {
    NavDestination() {
      PlaybackPage()
    }.hideTitleBar(true)
  }
}
```

#### 2. features/home/.../HomePage.ets（2 处）
- 第 41 行 SearchInputArea onTap：`pushPathByName(SEARCH, undefined)` → `pushPath(new NavPathInfo(SEARCH, undefined))`
- 第 60 行 MiniPlayerBar onTap：`pushPathByName(PLAYBACK, undefined)` → `pushPath(new NavPathInfo(PLAYBACK, undefined))`

#### 3. features/musichall/.../MusicHallPage.ets
- 第 49 行 MiniPlayerBar onTap：同上改为 pushPath

#### 4. features/mine/.../MinePage.ets
- 第 52 行 MiniPlayerBar onTap：同上改为 pushPath

#### 5. features/search/.../SearchPage.ets
- 第 398 行 MiniPlayerBar onTap：同上改为 pushPath

### geometryTransition 验证
- MiniPlayerBar.ets:155 — `geometryTransition('coverImage', { follow: true })` ✓
- PlaybackPage.ets:188 — `geometryTransition('coverImage', { follow: false })` ✓
- 修复 push 路径后 shared element 动画自动恢复正常

### NavPathInfo 导入
需在各修改文件导入 `NavPathInfo`（来自 `@kit.ArkUI`）。

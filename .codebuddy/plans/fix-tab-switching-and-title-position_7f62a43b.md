---
name: fix-tab-switching-and-title-position
overview: 修复三个问题：1) Tab 指示器始终显示"首页"（currentTab 未同步 V1/V2 状态）2) 添加 Swiper 水平滑动切换 Tab 3) 音乐厅/我的页面标题 margin.top 从 16vp 改为 64vp
todos:
  - id: fix-tab-state
    content: 修复三个页面的 Tab 状态同步：将 HomePage/MusicHallPage/MinePage 的 currentTab 从 V1 AppStorage.get 改为 V2 AppStorageV2.connect(CurrentTabState)，LucidTabBar 绑定改为 currentTabState.index
    status: completed
  - id: add-swiper
    content: 在 Index.ets 的 tabContent() 中用 Swiper 包裹三个页面，绑定 currentTabState.index 实现滑动切换，移除 @Monitor 并将 navPathStack.clear() 移入 Swiper.onChange
    status: completed
    dependencies:
      - fix-tab-state
  - id: fix-title-margin
    content: 修正 MusicHallPage 和 MinePage 标题 margin.top 从 16vp 改为 64vp
    status: completed
---

## 用户需求
修复音乐播放器三个 UI/交互问题：

### 1. Tab 指示器状态不同步
- **现象**：底部 Tab 切换页面时，Tab 栏的高亮指示始终停留在"首页"，其他 Tab 不会高亮，但页面实际内容已切换成功
- **根因**：三个页面的 `@Local currentTab` 通过 V1 `AppStorage.get` 初始化（始终为 0），而 Tab 点击 `onChange` 写入的是 V2 `CurrentTabState.index`，V1/V2 状态不同步

### 2. 页面中部不能滑动切换
- **现象**：在页面主体区域水平滑动无法切换 Tab 页面
- **根因**：Index.ets 使用 `if/else` 条件渲染页面，未使用 Swiper 组件，无滑动手势支持

### 3. 音乐厅和我的页面标题被状态栏遮挡
- **现象**：音乐厅页标题"音乐厅"和我的页标题"我的"定位在状态栏区域，与系统状态栏重叠
- **根因**：MusicHallPage 和 MinePage 标题的 `margin.top = 16vp` 太小，未预留状态栏高度；正确值应与 HomePage 一致为 `margin.top = 64vp`


## 技术方案

### 修复 1：统一 V2 状态管理（解决 Tab 指示器问题）

**策略**：三个页面（HomePage / MusicHallPage / MinePage）的 `currentTab` 从 V1 `AppStorage.get` 改为通过 `AppStorageV2.connect(CurrentTabState)` 获取，与 Index.ets 使用同一个 V2 状态实例。

**改动**：
- 将 `@Local currentTab: number = AppStorage.get<number>(AppStorageKeys.CURRENT_TAB) ?? 0`
- 替换为 `@Local currentTabState: CurrentTabState = AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!`
- `LucidTabBar.currentIndex` 绑定改为 `this.currentTabState.index`
- `onChange` 简化为 `this.currentTabState.index = index`，移除重复的 `AppStorageV2.connect` 调用

### 修复 2：引入 Swiper 实现滑动切换

**策略**：在 Index.ets 的 `tabContent()` builder 中用 `Swiper` 包裹三个页面，绑定 `currentTabState.index` 实现点击切换 + 滑动手势双向同步。

**关键设计**：
- Swiper 的 `.index(this.currentTabState.index)` 绑定状态，实现双向同步
- Swiper 的 `.onChange((index: number) => { ... })` 回写 `currentTabState.index` 并调用 `navPathStack.clear()`
- 移除原有 `@Monitor('currentTabState.index')` 装饰器方法，将 `navPathStack.clear()` 移入 `Swiper.onChange`
- `.disableSwipe(false)` 启用滑动（默认就是开启的）
- `.indicator(false)` 隐藏 Swiper 自带指示器（已有 LucidTabBar）
- `.loop(false)` 不循环
- `.cachedCount(1)` 缓存相邻页优化性能
- `.itemSpace(0)` 对齐无间隙

### 修复 3：修正标题 margin

**策略**：MusicHallPage 和 MinePage 标题 `margin.top` 从 16vp 改为 64vp，与 HomePage 对齐。

## 影响文件

```
entry/src/main/ets/pages/Index.ets                         # [MODIFY] Swiper 替换 if/else + 移除 @Monitor
features/home/src/main/ets/view/HomePage.ets               # [MODIFY] V1→V2 状态同步
features/musichall/src/main/ets/view/MusicHallPage.ets      # [MODIFY] V1→V2 状态同步 + 标题 margin
features/mine/src/main/ets/view/MinePage.ets                # [MODIFY] V1→V2 状态同步 + 标题 margin
```


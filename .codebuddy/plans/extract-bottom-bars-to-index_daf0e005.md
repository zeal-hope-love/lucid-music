---
name: extract-bottom-bars-to-index
overview: 将 MiniPlayerBar 和 LucidTabBar 从三个 Tab 页面中提取到 Index.ets 的统一层（Navigation 外层的 Stack 底部），通过 NavDestination 生命周期回调按页面类型控制显隐。Tab 页和搜索页显示 MiniPlayerBar，仅 Tab 页显示 LucidTabBar，播放页两者都不显示。
todos:
  - id: create-visibility-state
    content: 在 common/musicbasic 中新建 BottomBarVisibility.ets 状态类，并在 musicbasic/Index.ets 中导出
    status: completed
  - id: refactor-index
    content: 改造 Index.ets：添加 barVisibility 状态，用 Stack 包裹 Navigation + 底部 Column（MiniPlayerBar + LucidTabBar），在 navDestinationBuilder 中为 Search/Playback NavDestination 添加 onAppear/onDisAppear/onBackPressed 控制显隐
    status: completed
    dependencies:
      - create-visibility-state
  - id: simplify-tab-pages
    content: 简化三个 Tab 页面（HomePage/MusicHallPage/MinePage）：移除底部 Column（MiniPlayerBar+LucidTabBar），移除相关 import（CurrentTabState/AppStorageV2/AppStorageKeys/LucidTabBar），Stack 改 Column，调整 padding.bottom
    status: completed
    dependencies:
      - refactor-index
  - id: simplify-search-page
    content: 简化 SearchPage：移除底部 MiniPlayerBar 和相关 import，调整 padding.bottom 从 126 改为 72
    status: completed
    dependencies:
      - refactor-index
---

## 产品概述
将 MiniPlayerBar（迷你播放条）和 LucidTabBar（Tab 导航栏）从各个页面内部提取到 Index.ets 统一层，使其固定在屏幕底部不再跟随 Swiper 滑动，并按页面类型智能控制显隐。

## 核心功能
- 底部栏固定在屏幕底部，Swiper 滑动和页面导航时保持不动
- Tab 页面（首页/音乐厅/我的）：同时显示 MiniPlayerBar 和 LucidTabBar
- 搜索页和二级页面：仅显示 MiniPlayerBar，隐藏 LucidTabBar
- 播放详细页（PlaybackPage）：两者全部隐藏
- MiniPlayerBar 无歌曲时自动隐藏（已有逻辑，无需改动）


## 技术方案

### 实现策略
1. 新增 `BottomBarVisibility` V2 状态类，`@ObservedV2` + `@Trace` 管理 miniPlayerVisible / tabBarVisible
2. 在 Index.ets 中将 MiniPlayerBar + LucidTabBar 放入 Navigation 外层的 Column 底部（fixed 定位）
3. 利用 `NavDestination.onAppear()` / `onDisAppear()` 生命周期回调自动切换显隐状态
4. 各页面移除内部底部栏，简化为纯内容布局

## 架构设计

### 数据流
```
Tab 页面加载 → barVisibility 初始为 (true, true)
搜索页 push → NavDestination.onAppear → (true, false)
播放页 push → NavDestination.onAppear → (false, false)
返回上一页  → NavDestination.onDisAppear → 根据栈剩余内容恢复状态
```

### 页面结构变化

**Index.ets 新布局：**
```
Stack
├── Navigation(navPathStack)
│   ├── Swiper (tab 页)
│   │   ├── HomePage (纯内容，底部栏已移除)
│   │   ├── MusicHallPage (纯内容，底部栏已移除)
│   │   └── MinePage (纯内容，底部栏已移除)
│   └── NavDestination (Search / Playback)
└── Column (固定在底部，不受 Navigation 影响)
    ├── MiniPlayerBar (if barVisibility.miniPlayerVisible)
    └── LucidTabBar (if barVisibility.tabBarVisible)
```

**各页面简化：**
- Tab 页：`Stack(底部对齐)` → `Column`，完全移除底部 Column（MiniPlayerBar + LucidTabBar），`padding.bottom` 从 150 调整为 160（为外层底部栏留空间）
- SearchPage：移除底部 MiniPlayerBar，`padding.bottom` 从 126 调整为 72（仅留 MiniPlayerBar 高度空间，LucidTabBar 不显示）

### 堆栈恢复逻辑
在 PlaybackPage 的 NavDestination 上设置 `onBackPressed`，pop 后检查 `navPathStack.getAllPathName().length`：
- 为 0 → 回到 Tab 页 → miniPlayerVisible=true, tabBarVisible=true
- 为 1（底层是 SearchPage）→ miniPlayerVisible=true, tabBarVisible=false

## 目录结构

```
common/musicbasic/
├── src/main/ets/model/
│   └── BottomBarVisibility.ets        # [NEW] 显隐状态类
├── Index.ets                          # [MODIFY] 导出 BottomBarVisibility
entry/src/main/ets/pages/
└── Index.ets                          # [MODIFY] 添加底栏层 + 生命周期控制
features/home/src/main/ets/view/
└── HomePage.ets                       # [MODIFY] 移除底部栏 + 简化布局
features/musichall/src/main/ets/view/
└── MusicHallPage.ets                  # [MODIFY] 同上
features/mine/src/main/ets/view/
└── MinePage.ets                       # [MODIFY] 同上
features/search/src/main/ets/view/
└── SearchPage.ets                     # [MODIFY] 移除 MiniPlayerBar + 调整 padding
```

## 关键代码结构

### BottomBarVisibility 状态类
```typescript
// common/musicbasic/src/main/ets/model/BottomBarVisibility.ets
@ObservedV2
export class BottomBarVisibility {
  @Trace miniPlayerVisible: boolean = true
  @Trace tabBarVisible: boolean = true
}
```

### Index.ets 核心改动
```typescript
// 新增状态
@Provider() barVisibility: BottomBarVisibility = new BottomBarVisibility()

// build 结构变为 Stack 包裹 Navigation + 底部 Column
build() {
  Stack({ alignContent: Alignment.Bottom }) {
    Navigation(this.navPathStack) { this.tabContent() }
    // ...
    Column() {
      if (this.barVisibility.miniPlayerVisible) {
        MiniPlayerBar({ ... })
      }
      if (this.barVisibility.tabBarVisible) {
        LucidTabBar({ ... })
      }
    }
  }
}

// navDestinationBuilder 中添加生命周期
// Search NavDestination:
.onAppear(() => {
  this.barVisibility.miniPlayerVisible = true
  this.barVisibility.tabBarVisible = false
})
.onDisAppear(() => { this.restoreBarVisibility() })

// Playback NavDestination:
.onAppear(() => {
  this.barVisibility.miniPlayerVisible = false
  this.barVisibility.tabBarVisible = false
})
.onBackPressed(() => {
  this.navPathStack.pop()
  this.restoreBarVisibility()
  return true
})
```


---
name: refactor-navigation-architecture
overview: 将 Index.ets 从"上帝组件"重构为 Navigation 路由壳，每个 Feature 页面自行管理底部栏（MiniPlayerBar + LucidTabBar），搜索改为 Navigation 路由而非 Stack 覆盖层。
todos:
  - id: add-route-constants
    content: 在 RouterUrlConstants 中新增 'Home'、'MusicHall'、'Mine'、'Search' 路由名常量，以及 AppStorageKeys 中新增 CURRENT_TAB 键
    status: completed
  - id: refactor-index
    content: 重构 entry/Index.ets：移除 Swiper/IndexFooter/搜索覆盖层，改为 Navigation + NavPathStack + @Provide，navDestination builder 映射 4 个路由，aboutToAppear 初始化 AppStorage.currentTab 并 pushHome
    status: completed
    dependencies:
      - add-route-constants
  - id: refactor-home-page
    content: 重构 features/home/HomePage.ets：底部加入 MiniPlayerBar + LucidTabBar（currentTab 从 AppStorage 读取），搜索框 onTap 改为 navPathStack.pushPathByName('Search')，移除不再需要的 currentTab 和 isSearchOverlayShowing 参数
    status: completed
    dependencies:
      - refactor-index
  - id: refactor-musichall-page
    content: 重构 features/musichall/MusicHallPage.ets：底部加入 MiniPlayerBar + LucidTabBar
    status: completed
    dependencies:
      - refactor-index
  - id: refactor-mine-page
    content: 重构 features/mine/MinePage.ets：底部加入 MiniPlayerBar + LucidTabBar
    status: completed
    dependencies:
      - refactor-index
  - id: refactor-search-page
    content: 修改 features/search/SearchPage.ets：onClose 改为 navPathStack.pop()，移除 transition 动画，保留内部 isResultMode 搜索/结果切换及平台 Tab 和 MiniPlayerBar
    status: completed
    dependencies:
      - refactor-index
  - id: delete-search-result-page
    content: 删除 features/search/SearchResultPage.ets 并更新 features/search/Index.ets 移除其导出
    status: completed
    dependencies:
      - refactor-search-page
---

## 用户需求

### 核心目标
将项目从"上帝组件 Index.ets"架构重构为 Navigation + NavPathStack 模块化路由架构，实现 Feature 模块自给自足。

### 具体任务
1. **Index.ets 瘦身为路由壳**：去掉 Swiper、IndexFooter、搜索覆盖层，改为 Navigation + NavPathStack 纯路由入口，只保留 AppState 初始化 + Intent 分发
2. **每个页面自管底部栏**：HomePage、MusicHallPage、MinePage 各自在底部加入 MiniPlayerBar + LucidTabBar，不再依赖 Index.ets 的 IndexFooter
3. **搜索改为路由进入**：SearchPage 从 Stack 覆盖层改为 NavPathStack.push 进入的 NavDestination 路由页面，保留内部 isResultMode 搜索/结果切换
4. **SearchResultPage 合并删除**：SearchResultPage.ets 为冗余代码，其功能已被 SearchPage 的 isResultMode 模式覆盖，直接删除
5. **Tab 切换机制**：LucidTabBar.onChange 通过 NavPathStack.clear() + pushPathByName(target) 实现 Tab 页切换；当前 Tab 索引通过 AppStorage 全局共享

### 视觉效果
- 页面切换使用 Navigation 默认过渡动画（不影响用户感知）
- 底部 MiniPlayerBar 和 LucidTabBar 在每个 Tab 页内保持一致布局，有歌曲时显示迷你播放条

## 技术栈
- HarmonyOS ArkUI（Navigation、NavPathStack、AppStorageV2）
- 项目已有组件：LucidTabBar、MiniPlayerBar、SearchInputArea、AreaWithHdsTabBar
- 状态管理：AppStorageV2 + MusicAppState

## 实现方案

### 架构对比

**重构前（反模式）：**
```
Index.ets（上帝组件）
├── Swiper（管理 3 个 Tab 页的布局）
├── IndexFooter（MiniPlayerBar + LucidTabBar，所有页面共用）
├── [条件渲染] SearchPage（Stack 覆盖层）
└── [未实现] PlaybackPage
```

**重构后（模块化）：**
```
Index.ets（路由壳，只含逻辑）
├── NavPathStack 初始化
├── NavPathStack.getPathByName('Home') → HomePage（自带底部栏）
├── NavPathStack.getPathByName('MusicHall') → MusicHallPage（自带底部栏）
├── NavPathStack.getPathByName('Mine') → MinePage（自带底部栏）
├── NavPathStack.pushPathByName('Search') → SearchPage（路由 push）
└── NavPathStack.pushPathByName('Playback') → PlaybackPage（未来扩展）
```

### 关键设计决策

1. **NavPathStack 共享方式**：Index.ets 创建 NavPathStack，通过 `@Provide` 传递。子页面通过 `@Consume` 获取，用于 Tab 切换和路由 push/pop。

2. **Tab 切换策略**：LucidTabBar.onChange → `navPathStack.clear()` → `navPathStack.pushPathByName(目标Tab)` → `AppStorage.set('currentTab', index)`。clear 确保栈内只有一个 Tab 页，避免回退到另一个 Tab。

3. **currentTab 全局共享**：通过 AppStorage.setOrCreate('currentTab', 0) 实现，各页面的 LucidTabBar 读写同一个键。避免原先 Index.ets 通过 Swiper 管理的耦合。

4. **MiniPlayerBar 重复实例**：每个页面独立创建 MiniPlayerBar 实例，它们都订阅同一个 MusicAppState（AppStorageV2.connect），状态天然同步。无额外开销。

5. **SearchPage 内部 isResultMode**：保留搜索/结果二合一设计，搜索框和平台 Tab 共享，输入后原地切换为结果列表。点击搜索框或返回键退回搜索状态，点击导航返回键 pop 回前页。

### 实现细节

**Navigation 路由表（navDestination builder）：**
| 路径名 | 对应页面 | 说明 |
|--------|----------|------|
| `Home` | HomePage | 默认首页 Tab |
| `MusicHall` | MusicHallPage | 音乐厅 Tab |
| `Mine` | MinePage | 我的 Tab |
| `Search` | SearchPage | 搜索页（push 进入） |
| `Playback` | PlaybackPage | 播放页（未来 push 进入） |

**底部栏布局（各 Tab 页统一结构）：**
```
Stack({ alignContent: Alignment.Bottom }) {
  Column() {
    页面内容...
  }
  .width('100%').height('100%')
  .padding({ bottom: 150 })

  Column() {
    MiniPlayerBar({ barWidth, onTap → push playback })
    .margin({ bottom: 30 })
    LucidTabBar({ currentIndex, barWidth, onChange → Tab切换 })
  }
}
```

**SearchPage 从覆盖层改为路由后的变化：**
- 移除 `transition(TransitionEffect.OPACITY)`（路由自带过渡）
- `onClose` 改为 `navPathStack.pop()`
- MiniPlayerBar 已在 SearchPage 中存在，保持不动
- 竖屏顶部 margin 调整为 `top: 44`（NavDestination 自带标题栏区域）

**aboutToAppear 初始化顺序（Index.ets）：**
```
1. AppStorage.setOrCreate('currentTab', 0)
2. MusicDbApi 加载歌曲列表
3. JsVmBridge.init()
4. NavPathStack.pushPathByName('Home') → 显示首页
```

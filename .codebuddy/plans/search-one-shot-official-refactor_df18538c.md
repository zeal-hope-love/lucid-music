---
name: search-one-shot-official-refactor
overview: 将搜索一镜到底转场改为官方 transitions-collection-master 的写法：getUIContext().animateTo + interpolatingSpring + boolean false，同时保留所有 HDSTab 沉浸光感代码。
todos:
  - id: fix-homepage-push
    content: HomePage.ets：pushPath 改为 getUIContext().animateTo + interpolatingSpring + 布尔 false
    status: completed
  - id: fix-searchpage-pop
    content: SearchPage.ets：pop 改为 getUIContext().animateTo + interpolatingSpring + pop(false)，添加 curves import
    status: completed
  - id: add-anti-flicker
    content: SearchInputArea.ets：根节点添加 .transition(TransitionEffect.opacity(0.99)) 防闪烁
    status: completed
---

## 用户需求

按官方 `transitions-collection-master` 项目的搜索一镜到底写法改造当前项目，具体改动：

1. 将 `animateTo` 调用从全局改为 `this.getUIContext().animateTo()`
2. 动画曲线从 `Curve.EaseIn` + `duration: 300` 改为 `curves.interpolatingSpring(0, 1, 342, 38)`
3. `pushPath` 和 `pop` 的 animated 参数从对象形式 `{ animated: false }` 改为纯布尔值 `false`
4. 保留所有 HDSTab 沉浸光感部分（`AreaWithHdsTabBar` 包裹搜索框和返回键）

## 核心特性

- 完全按官方推荐的最佳实践实现一镜到底转场
- 保留项目独有的 HDSTab 毛玻璃沉浸光感效果
- 搜索框 geometryTransition ID 通过共享 `SearchInputArea` 组件自动传递，无需额外处理
- 搜索页返回键保持 HDSTab 光感包裹


## 技术栈

- 框架：HarmonyOS ArkUI (API 23+)
- 语言：ArkTS (TypeScript 超集)
- 关键 API：`geometryTransition`、`NavPathStack.pushPath/pop`、`UIContext.animateTo`、`curves.interpolatingSpring`

## 实现方案

### 改动策略

三文件按官方写法对齐，改动范围极小，每个文件只改导航调用处的几行代码：

1. **HomePage.ets**（第 42-44 行）：`onTap` 回调中的 pushPath 调用
2. **SearchPage.ets**（第 71-73 行）：`onBack` 方法中的 pop 调用
3. **SearchInputArea.ets**（可选）：给根节点加防闪烁 transition

### 官方写法核心公式

```typescript
// push
this.getUIContext().animateTo({
  curve: curves.interpolatingSpring(0, 1, 342, 38)
}, () => {
  this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.SEARCH, undefined), false)
})

// pop
this.getUIContext().animateTo({
  curve: curves.interpolatingSpring(0, 1, 342, 38)
}, () => {
  this.navPathStack.pop(false)
})
```

### 关键差异对照

| 维度 | 当前 | 改为 |
|------|------|------|
| animateTo | 全局 `animateTo({ duration: 300, curve: Curve.EaseIn }, ...)` | `this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 342, 38) }, ...)` |
| pushPath animated | `{ animated: false }` 对象 | `false` 布尔 |
| pop animated | `pop(undefined, false)` | `pop(false)` |

### 不变部分

- `AreaWithHdsTabBar.ets`：HDSTab 毛玻璃组件，零修改
- `entry/Index.ets`：Navigation 路由入口，零修改
- `SearchInputArea.ets`：geometryTransition ID `'SEARCH_ONE_SHOT_TRANSITION_ID'` 和 `{ follow: isFollow }` 保持不变，HomePage 传 `isFollow: true`，SearchPage 传 `isFollow: false`
- 搜索页返回键的 `AreaWithHdsTabBar` 包裹和 `backButtonContent` Builder，零修改

## 目录结构

```
lucid_music/
├── features/home/src/main/ets/view/
│   └── HomePage.ets          # [MODIFY] pushPath 调用改为官方写法
├── features/search/src/main/ets/view/
│   └── SearchPage.ets        # [MODIFY] pop 调用改为官方写法，添加 curves import
└── common/musicbasic/src/main/ets/components/search/
    └── SearchInputArea.ets   # [MODIFY] 可选：根节点加 .transition(Opacity(0.99)) 防闪烁
```


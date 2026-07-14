---
name: fix-one-shot-back-gesture
overview: 为 SearchPage 的 NavDestination 添加 onBackPressed 拦截，阻止系统默认左滑动画与 geometryTransition 一镜到底冲突。
todos:
  - id: add-provide-index
    content: 在 Index.ets 中添加 @Provide searchBackVersion，并为 Search 的 NavDestination 添加 onBackPressed 回调
    status: completed
  - id: add-consume-search
    content: 在 SearchPage.ets 中添加 @Consumer searchBackVersion 和 @Monitor 监听，触发 onBack
    status: completed
    dependencies:
      - add-provide-index
  - id: verify-build
    content: 编译验证，确认无 ERROR 且左滑一镜到底正常
    status: completed
    dependencies:
      - add-consume-search
---

## 问题
左滑返回手势触发 Navigation 默认的 slide 动画，与 geometryTransition 一镜到底动画并行执行，导致一镜到底动画被截断、显示异常。

## 根因
`Index.ets` 中 Search 的 `NavDestination` 没有设置 `.onBackPressed()`，无法拦截系统默认的左滑转场动画。

## 修复目标
拦截左滑手势的默认动画，使用 `animateTo` + `pop(false)` 驱动 geometryTransition 完成流畅的一镜到底过渡。

## 行为要求
- 搜索结果模式下左滑：先退出结果模式回到搜索模式（不 pop 页面）
- 搜索模式下左滑：执行 `animateTo({ spring })` + `pop(false)` 返回首页


## 技术方案

### 参考模式（transitions-collection-master）
```typescript
// SearchLongTakeTransitionPageTwo — NavDestination 内直接 onBackPressed
NavDestination() { /* UI */ }
  .onBackPressed(() => {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38),
    }, () => {
      this.pageInfos.pop(false);
    })
    return true;  // 拦截系统默认动画
  })
```

### lucid_music 差异与方案
参考项目中 `NavDestination` 和页面内容在同一个组件内，`onBackPressed` 可直接访问 `isResultMode`。lucid_music 中 `NavDestination` 在 `Index.ets` 的 `navDestinationBuilder` 内创建，无法直接访问 `SearchPage.isResultMode`。

**方案：通过 `@Provide`/`@Consumer` 传递背压信号**

- `Index.ets`：声明 `@Provide() searchBackVersion: number`，`onBackPressed` 中递增该值
- `SearchPage`：声明 `@Consumer() searchBackVersion: number`，`@Monitor` 检测变化后调用已有 `onBack()` 方法
- `SearchPage.onBack()` 已有完整的双重逻辑（结果模式回退 / 搜索模式 pop），无需修改

### 数据流
```
用户左滑 → NavDestination.onBackPressed
  → searchBackVersion++  →  return true（阻止默认动画）
  → SearchPage.@Monitor 检测到 searchBackVersion 变化
  → 调用 this.onBack()（已有逻辑）
    → 结果模式: isResultMode = false（留在页面）
    → 搜索模式: animateTo({ spring }) + pop(false)（返回首页）
```

### 修改文件
| 文件 | 修改内容 |
|------|---------|
| `entry/src/main/ets/pages/Index.ets` | 1. 添加 `@Provide() searchBackVersion` 2. Search NavDestination 添加 `.onBackPressed()` |
| `features/search/src/main/ets/view/SearchPage.ets` | 添加 `@Consumer() searchBackVersion` + `@Monitor` 监听 |


---
name: fix-local-count-reactivity
overview: 修复 MinePage 本地歌曲数量显示 0 的 bug：@Local 数组元素赋值不触发响应式更新，改为整体替换数组
todos:
  - id: fix-local-count
    content: 修改 MinePage.aboutToAppear：将数组元素赋值改为整体替换数组引用
    status: completed
---

## 问题
MinePage 本地入口歌曲数量始终显示 **0**，但 MusicMemoryStore 已配置 2 首歌（Dream It Possible + Journey of Light）。

## 根因
`MinePage.ets` 的 `aboutToAppear` 方法中使用了数组元素直接赋值：
```typescript
this.quickEntries[0].count = localCount
```

ArkUI V2 的 `@Local` 装饰器只追踪数组引用变化，不追踪数组内部元素的属性变更。因此 `quickEntries[0].count` 被修改后，UI 不会重绘，始终显示初始值 0。

## 修复
将数组元素赋值改为整体重建数组引用，触发 `@Local` 的引用变化检测，使 UI 正确更新为实际歌曲数量。

## 技术方案

### 改动范围
仅修改 1 个文件、1 个方法：

**文件**：`features/mine/src/main/ets/view/MinePage.ets`

**方法**：`aboutToAppear()` — 将第 26-27 行的数组元素赋值改为整体替换：

```typescript
aboutToAppear(): void {
  const localCount = MusicDbApi.getInstance().getSongList().length
  this.quickEntries = [
    { icon: $r('sys.symbol.folder_fill'), label: '本地', count: localCount },
    { icon: $r('sys.symbol.clock_fill'), label: '最近播放', count: 0 },
    { icon: $r('sys.symbol.heart_fill'), label: '收藏', count: 0 }
  ]
}
```

### 原理
ArkUI V2 状态管理机制：
- `@Local` 追踪变量引用的变化（浅比较）
- `this.quickEntries = newArray` 触发引用变化 → ForEach 重渲染
- `this.quickEntries[0].count = n` 引用不变 → 不触发重渲染

### 影响面
- 无新增/删除文件
- 不改动接口或类型定义
- 不影响其他页面
- 与现有架构完全一致

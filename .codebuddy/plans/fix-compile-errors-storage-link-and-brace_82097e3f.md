---
name: fix-compile-errors-storage-link-and-brace
overview: 修复 3 个编译错误：1) @StorageLink 改 @ObservedV2+AppStorageV2.connect 模式；2) PlaybackPage 多余花括号；3) @Monitor 目标变量不存在
todos:
  - id: create-tabstate
    content: 新建 common/musicbasic/.../model/CurrentTabState.ets，添加 AppStorageKeys.CURRENT_TAB_STATE，并在 musicbasic/Index.ets 导出
    status: completed
  - id: fix-index-storagelink
    content: 修复 Index.ets：@StorageLink → @Local + AppStorageV2.connect(CurrentTabState)，@Monitor 改为监听 currentTabState.index
    status: completed
    dependencies:
      - create-tabstate
  - id: fix-three-pages
    content: 修复 HomePage/MusicHallPage/MinePage 的 TabBar onChange，从 V1 AppStorage 切换到 V2 AppStorageV2.connect(CurrentTabState)
    status: completed
    dependencies:
      - create-tabstate
  - id: fix-playback-brace
    content: 修复 PlaybackPage.ets 删除多余花括号（line 299）
    status: completed
  - id: lint-verify
    content: 全局 lint 验证所有修改文件无错误
    status: completed
    dependencies:
      - fix-index-storagelink
      - fix-three-pages
      - fix-playback-brace
---

## 问题
Clean build 出现 3 个编译错误：
1. Index.ets 使用 `@StorageLink` 但 `@ComponentV2` 不支持 V1 装饰器
2. `@Monitor('currentTab')` 因目标不存在而报警
3. PlaybackPage.ets 在 Stack 关闭后多了一个多余的 `}`，导致语法错误

## 修复目标
- 创建 `CurrentTabState` @ObservedV2 类，改用 `AppStorageV2.connect` 模式（与现有 `MusicAppState` 一致）
- 3 个 Tab 页的 TabBar onChange 切换到 V2 AppStorage
- 删除 PlaybackPage.ets 多余花括号
- 不改动任何架构结构


## 技术方案

### 1. CurrentTabState 观察类（新建文件）
参照 `MusicAppState` 模式，创建最小化的观察类：
- `@ObservedV2 export class CurrentTabState { @Trace public index: number = 0 }`
- 仅含一个 `@Trace` 字段，变更时自动通知所有 AppStorageV2.connect 订阅者

### 2. AppStorageKeys 新增键
在 `Constants.ets` 的 `AppStorageKeys` 中添加 `CURRENT_TAB_STATE` 常量，遵循 `musichome_` 前缀约定。

### 3. Index.ets 修复
- 移除 `@StorageLink(AppStorageKeys.CURRENT_TAB) currentTab: number`
- 新增 `@Local currentTabState: CurrentTabState = AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!`
- `@Monitor('currentTabState.index')` 监听变化并 `navPathStack.clear()`
- `tabContent()` 中 `this.currentTab` 改为 `this.currentTabState.index`
- `aboutToAppear` 中 `AppStorage.setOrCreate(AppStorageKeys.CURRENT_TAB, 0)` 改为 `this.currentTabState.index = 0`

### 4. 三个 Tab 页修复
每个页面的 `LucidTabBar` 的 `onChange` 回调从：
```typescript
onChange: (index: number): void => {
  AppStorage.setOrCreate(AppStorageKeys.CURRENT_TAB, index)
}
```
改为：
```typescript
onChange: (index: number): void => {
  const tabState = AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
  tabState.index = index
}
```
需要新增 `AppStorageV2` 和 `CurrentTabState` 导入。

### 5. PlaybackPage.ets 修复
Lines 295-305 当前结构：
```
295:  .padding({ bottom: 40 })
296:}          ← 关闭 inner Column（10空格）
297:.width('100%')    ← inner Column 链
298:.height('100%')   ← inner Column 链
299:}          ← 多余！（8空格，无对应打开）
300:.width('100%')
301:.height('100%')
302:}          ← 关闭 Stack（6空格）
303:}          ← 关闭 else（4空格）
304:}          ← 关闭 build（2空格）
305:}          ← 关闭 struct
```
删除 line 299 即可，lines 300-301 的 `.width/height` 会自动变为 Stack 的链式调用。


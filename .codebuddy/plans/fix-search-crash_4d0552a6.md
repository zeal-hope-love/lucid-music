---
name: fix-search-crash
overview: 删除 SearchInputArea.ets 中 aboutToAppear 的 requestFocus 调用，defaultFocus 已覆盖自动聚焦需求
todos:
  - id: remove-requestfocus
    content: 删除 SearchInputArea.ets 第 23-29 行的 aboutToAppear 方法
    status: completed
  - id: lint-verify
    content: 验证 SearchInputArea.ets lint 0 错误
    status: completed
    dependencies:
      - remove-requestfocus
---

## 问题
点击主页搜索框后闪退。崩溃位于 `SearchInputArea.ets:26`，错误码 150003。

## 根因
`SearchInputArea.ets` 的 `aboutToAppear()` 方法中，当 `autoFocus=true` 时通过 `setTimeout(350ms)` 调用 `requestFocus('search_text_input')`。SearchPage 作为 NavDestination push 时，焦点系统尚未完全初始化导致调用失败崩溃。

## 修复
删除 `aboutToAppear()` 方法（第 23-29 行）。`defaultFocus(this.autoFocus)`（第 55 行）已声明默认焦点行为，无需冗余的 `requestFocus` 调用。


## 修改范围
仅修改 1 个文件，删除 7 行代码。

### 文件
`common/musicbasic/src/main/ets/components/search/SearchInputArea.ets`

### 修改内容
删除第 23-29 行的 `aboutToAppear()` 方法：
```typescript
  aboutToAppear(): void {
    if (this.autoFocus) {
      setTimeout(() => {
        this.getUIContext().getFocusController().requestFocus('search_text_input')
      }, 350)
    }
  }
```

### 理由
- 第 55 行 `.defaultFocus(this.autoFocus)` 已在 ArkUI 层面声明组件的默认焦点优先级，当页面渲染完成后系统会自动将焦点分配给该 TextInput
- `requestFocus` 是强制式焦点请求，需要在目标组件完全挂载且焦点树就绪后才安全；NavDestination push 场景下 350ms 的硬编码延迟不可靠
- 删除 `aboutToAppear` 后，TextInput 的 `defaultFocus(true)` + `focusOnTouch(true)` + `focusable(true)` 组合仍能正常工作


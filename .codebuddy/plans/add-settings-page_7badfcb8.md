---
name: add-settings-page
overview: 在"我的"页面添加设置菜单入口，点击后导航到设置二级页面，包含一个简单的设置列表。
todos:
  - id: add-route-constant
    content: 在 RouterUrlConstants 新增 SETTINGS 路由常量
    status: completed
  - id: create-settings-page
    content: 新建 SettingsPage.ets 设置二级页面（标题"设置"+返回功能）
    status: completed
    dependencies:
      - add-route-constant
  - id: export-settings-page
    content: 在 mine/Index.ets 导出 SettingsPage
    status: completed
    dependencies:
      - create-settings-page
  - id: add-settings-row
    content: 在 MinePage 添加设置菜单行（图标+文字+箭头，点击 push）
    status: completed
    dependencies:
      - add-route-constant
  - id: register-nav-destination
    content: 在 Index.ets navDestinationBuilder 注册 Settings NavDestination
    status: completed
    dependencies:
      - export-settings-page
---

## 用户需求
在「我的」（MinePage）页面新增设置菜单入口，点击后进入设置二级页面。

## 核心功能
- MinePage 页面添加设置行（图标 + "设置"文字 + 箭头），位于 AudioSourceSection 下方
- 点击设置行 push SettingsPage 到 NavPathStack
- SettingsPage 为独立二级页面，含返回按钮、标题"设置"，内容后续扩展
- 路由常量统一注册在 RouterUrlConstants.SETTINGS


## 技术栈
- ArkUI (HarmonyOS NEXT)
- ArkTS + @ComponentV2
- NavPathStack 路由导航

## 实现方案

完全遵循现有项目架构和路由注册模式，参考 Playback 的 NavDestination 注册。

### 改动文件

1. **RouterUrlConstants**：新增 `SETTINGS` 路由常量
2. **SettingsPage**：新建设置二级页面，结构参考 PlaybackPage 的 NavDestination 模式
3. **MinePage**：在 AudioSourceSection 下方添加设置菜单行，点击 push
4. **mine/Index.ets**：导出 SettingsPage
5. **Index.ets**：在 navDestinationBuilder 注册 Settings NavDestination

### 路由注册模式（参考 Playback）
```ets
} else if (name === 'Settings') {
  NavDestination() {
    SettingsPage()
  }
  .hideTitleBar(true)
  .transition(TransitionEffect.OPACITY)
  .onAppear(() => {
    this.barVisibility.miniPlayerVisible = false
    this.barVisibility.tabBarVisible = false
  })
  .onDisAppear(() => {
    this.restoreBarVisibility()
  })
  .onBackPressed(() => {
    this.navPathStack.pop(false)
    return true
  })
}
```

### 设置菜单行样式（MinePage 内）
Row 布局：SymbolGlyph(齿轮图标) + Text("设置") + Blank + 右箭头，对齐 AudioSourceSection 宽度，带 onClick 触发 push。

## 目录结构
```
features/mine/
├── Index.ets                                    # [MODIFY] 新增 export { SettingsPage }
├── src/main/ets/view/
│   ├── MinePage.ets                             # [MODIFY] 新增设置菜单行
│   ├── AudioSourceSection.ets                   # [UNCHANGED]
│   └── SettingsPage.ets                         # [NEW] 设置二级页面

common/musicbasic/
├── src/main/ets/constants/Constants.ets         # [MODIFY] 新增 SETTINGS 路由常量

entry/src/main/ets/pages/
└── Index.ets                                     # [MODIFY] 注册 Settings NavDestination
```


---
name: settings-audio-source-ui
overview: 重写 AudioSourceSection.ets 并在 SettingsPage.ets 中嵌入，实现完整的音源管理 UI：包括音源选择列表（Radio 单选+初始化状态）、音源管理 Sheet（本地/在线导入、左滑删除）、在线导入 Dialog。
todos:
  - id: create-model
    content: 新建 AudioSourceModel.ets：定义 AudioSourceInfo 接口、InitStatus 枚举、假数据数组
    status: completed
  - id: rewrite-audio-section
    content: 重写 AudioSourceSection.ets：Radio dot 单选列表 + 初始化状态模拟 + bindSheet 管理面板 + swipeAction 删除 + 在线导入 Dialog + 本地导入文件选择器
    status: completed
    dependencies:
      - create-model
  - id: integrate-settings
    content: 修改 SettingsPage.ets：内容区引入 AudioSourceSection，添加「自定义音源」二级标题和「音源管理」按钮
    status: completed
    dependencies:
      - rewrite-audio-section
---

## 用户需求
在设置页面（一级标题"设置"）下实现完整的音源管理 UI，包含以下功能层级：

### 设置页主体
- 二级标题「自定义音源」
- 「音源管理」按钮（跳转管理面板）
- 已导入音源的 Radio dot 单选列表：主体为音源名称，副标题为版本号
- 选中音源需显示初始化状态（初始化中 / 初始化成功 / 初始化失败），选中即触发初始化，无"未初始化"状态

### 音源管理面板（bindSheet，高度 MEDIUM）
- 顶部左侧「本地导入」按钮，右侧「在线导入」按钮
- 下方已导入音源详细列表：名称、版本号、作者、备注
- 列表项支持左滑显示删除按钮

### 导入流程
- 点击「本地导入」→ 调用文件选择器（DocumentViewPicker）
- 点击「在线导入」→ 弹出带 TextInput 的 CustomDialog，提交后用 Toast 提示成功/失败

### 数据
所有音源数据使用假数据（编造的），先完成 UI，后续再接入真实数据源。


## 技术方案

### 技术栈
- ArkTS + ArkUI V2（`@ComponentV2` + `@Local` + `@Builder`）
- 仅修改 `features/mine` 模块

### 架构设计

```
SettingsPage.ets (保留现有标题栏 + 返回按钮)
└── Scroll / Column 内容区
    ├── 二级标题：「自定义音源」
    ├── 「音源管理」按钮
    ├── AudioSourceSection.ets (重写为完整组件)
    │   ├── Radio dot 单选列表（已导入音源）
    │   ├── bindSheet（音源管理面板）
    │   │   ├── 顶部按钮行（本地导入 / 在线导入）
    │   │   └── 音源详细列表（swipeAction 删除）
    │   └── CustomDialog（在线导入 URL 输入）
    └── ...
```

**关键决策**：
- `AudioSourceSection` 改为自包含组件，内部管理 bindSheet 状态和对话框
- 初始化状态通过 `@Local` 数组跟踪，选中时自动触发模拟初始化
- 文件选择器使用 `DocumentViewPicker` API
- 在线导入对话框使用 `CustomDialogController` + `@CustomDialog`

### 数据模型

```typescript
// 音源信息
interface AudioSourceInfo {
  id: string
  name: string          // 主体
  version: string       // 副标题
  author: string
  description: string   // 备注
}

// 初始化状态枚举
enum InitStatus {
  INITIALIZING = 'initializing',
  SUCCESS = 'success',
  FAILED = 'failed'
}
```

### 实现细节

**文件选择器**：
```typescript
const picker = new picker.DocumentViewPicker()
await picker.select({ maxSelectNumber: 1 })
```

**bindSheet**：
```typescript
.bindSheet($$this.isSheetShow, this.sheetBuilder, {
  detents: [SheetSize.MEDIUM],
  showClose: true,
  title: { title: '音源管理' }
})
```

**Radio dot**：
```typescript
Radio({ value: source.id, group: 'audioSourceGroup' })
  .indicatorType(RadioIndicatorType.DOT)
```

**swipeAction**：
```typescript
.swipeAction({
  end: {
    builder: () => {
      Button('删除').backgroundColor(Color.Red).onClick(() => { ... })
    }
  }
})
```

**CustomDialog**：
```typescript
@CustomDialog
struct OnlineImportDialog {
  controller: CustomDialogController
  @Local url: string = ''
  // TextInput + 确认/取消按钮
}
```

### 目录结构
```
features/mine/src/main/ets/
├── view/
│   ├── SettingsPage.ets          # [MODIFY] 内容区加入 AudioSourceSection
│   └── AudioSourceSection.ets    # [REWRITE] 完整音源管理 UI 组件
└── model/
    └── AudioSourceModel.ets      # [NEW] 数据模型定义（假数据）
```


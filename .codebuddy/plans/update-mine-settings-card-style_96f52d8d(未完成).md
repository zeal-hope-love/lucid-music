---
name: update-mine-settings-card-style
overview: 将 MinePage 中设置入口"框框"的视觉样式替换为 HarmonyOSComponentUXExamples 项目的卡片风格（borderRadius 16 + comp_background_list_card 背景色），同时告知 Spatialization 项目实际上没有一镜到底效果。
todos:
  - id: update-card-style
    content: 修改 MinePage.ets 设置框的 borderRadius(16)、backgroundColor(comp_background_list_card)、padding(12vp) 三个样式属性
    status: pending
---

## 需求
将"我的"页面中设置入口框的样式对齐 HarmonyOSComponentUXExamples 项目的卡片规范（`CardWrapperModifier`），仅修改以下 3 个样式属性：

1. **圆角**：`borderRadius(12)` → `borderRadius(16)`
2. **背景色**：`ohos_id_color_foreground_contrary` → `comp_background_list_card`
3. **内边距**：`padding({ left: 16, right: 16 })` → `padding({ left: 12, right: 12 })`

一镜到底（`geometryTransition('SETTINGS_TITLE_TRANSITION')`）和 SettingsPage 联动保持不动。

## 技术方案

### 修改范围
仅修改 `features/mine/src/main/ets/view/MinePage.ets` 第 55-57 行，调整 3 个样式属性值。

### 修改前后对比

| 属性 | 修改前 | 修改后 | 来源 |
|------|--------|--------|------|
| `borderRadius` | `12` | `16` | UX `CORNER_RADIUS_16` |
| `backgroundColor` | `ohos_id_color_foreground_contrary` | `comp_background_list_card` | UX `CardWrapperModifier` |
| `padding` | `{ left: 16, right: 16 }` | `{ left: 12, right: 12 }` | UX `PADDING_12VP` |

### 不改动的内容
- `geometryTransition('SETTINGS_TITLE_TRANSITION', { follow: false })` 保持不变
- `onClick` 路由逻辑保持不变
- SettingsPage.ets 不做任何修改

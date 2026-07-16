---
name: fix-audiosource-crash-and-layout
overview: 修复闪退（swipeAction 中 height('100%') 导致 backgroundColor 崩溃），并调整布局：音源管理改长条 button、版本号移到名称后、整个区域上移。
todos:
  - id: fix-all
    content: 修复闪退 + 布局调整（AudioSourceSection.ets 3处 + SettingsPage.ets 2处）
    status: completed
---

## 用户需求
1. 修复闪退：点击「音源管理」后进入 Sheet，左滑列表项时闪退
2. 整个自定义音源区域上移
3. 「音源管理」改为全宽长条卡片按钮（参考 MinePage 设置入口样式）
4. Radio 列表中版本号从名称下方移到名称同行
5. 字体大小保持不变

## 闪退根因
`AudioSourceSection.ets:317`：`swipeAction.end.builder` 中 Button 使用了 `.height('100%')`，在 swipeAction 构建上下文中 `'100%'` 高度不可解析，导致后续 `.backgroundColor()` 调用时 target 为 undefined，触发 `TypeError: Cannot read property backgroundColor of undefined`。

## 修改方案

仅修改 2 个文件，共 5 处改动：

### AudioSourceSection.ets（3 处）

**1. 修复闪退（第 317 行）**
```
// 修改前
.height('100%')

// 修改后
.height(56)
```
swipeAction 中删除按钮使用固定高度 56vp。

**2. 音源管理改为长条卡片按钮（第 340-352 行）**
```
// 修改前：右对齐纯文字 Row
Row() {
  Text('音源管理')
  SymbolGlyph($r('sys.symbol.chevron_right'))
}
.width('100%')
.justifyContent(FlexAlign.End)
.padding({ right: 4, bottom: 10 })

// 修改后：全宽卡片 Row（参考 MinePage 设置入口）
Row() {
  SymbolGlyph($r('sys.symbol.gearshape'))
    .fontSize(22)
    .fontColor([$r('sys.color.ohos_id_color_text_primary')])
  Text('音源管理')
    .fontSize(15)
    .fontColor($r('sys.color.ohos_id_color_text_primary'))
    .margin({ left: 12 })
  Blank()
  SymbolGlyph($r('sys.symbol.chevron_right'))
    .fontSize(18)
    .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
}
.width('100%')
.height(48)
.borderRadius(12)
.backgroundColor($r('sys.color.comp_background_list_card'))
.padding({ left: 14, right: 12 })
.margin({ bottom: 12 })
```
卡片样式：带 gearshape 图标、背景色、圆角、chevron 箭头，与项目设置入口风格一致。

**3. 版本号移到名称同行（第 365-376 行）**
```
// 修改前：Column 两行
Column() {
  Text(item.name)...
  Text('版本 ' + item.version)...  // 第二行
}

// 修改后：Row 同行
Row() {
  Text(item.name)
    .layoutWeight(1)  // 占剩余空间，长文本省略
    .maxLines(1)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  Text('v' + item.version)  // 跟在名称后面
    .margin({ left: 8 })
}
```
去掉原来的 Column 包装和下行版本文字，将名称和版本号放在同一 Row 内。

### SettingsPage.ets（2 处）

**4. 标题栏上移（第 50 行）**
```
// 修改前
.margin({ top: 48 })
// 修改后
.margin({ top: 40 })
```

**5. 内容区去除顶部 padding（第 67 行）**
```
// 修改前
.padding({ top: 8 })
// 修改后
.padding({ top: 0 })
```

---
name: 修复 MusicHallPage 顶部模糊浮层编译错误
overview: 修复 features/musichall/src/main/ets/view/MusicHallPage.ets 中 LAYER 2 顶部渐变模糊浮层的 5 个 ArkTS 编译错误，使 entry 模块能正常编译。
todos:
  - id: fix-overlay-enums
    content: 修改 MusicHallPage.ets 第259-272行：BlurStyle.BACKGROUND_REGULAR 与 ThemeColorMode.SYSTEM 修正
    status: completed
  - id: fix-gradient-mask
    content: 将 .mask(new LinearGradient(...)) 改为 Rect().linearGradient(...) 形状遮罩实现底部渐隐
    status: completed
    dependencies:
      - fix-overlay-enums
  - id: verify-build
    content: 重新构建 entry 模块 assembleHap，确认 ArkTS ERROR 归零
    status: completed
    dependencies:
      - fix-gradient-mask
---

## 用户需求
修复 `features/musichall/src/main/ets/view/MusicHallPage.ets` 中顶部渐变模糊浮层（LAYER 2）导致的 entry 模块 ArkTS 编译失败。构建日志显示 `COMPILE RESULT:FAIL {ERROR:6 WARN:201}`，其中 5 个 ERROR 全部集中在该文件的第 259-272 行，其余 201 个 WARN 均为其他文件的历史告警，不影响编译。

## 核心问题
顶部浮层原本意图：用 `backgroundBlurStyle` 模糊背后滚动内容，并通过渐变遮罩让模糊在底部渐隐，同时用 `background_fourth` 着色，复刻 HarmonyOS `GradientBlurTabBar` 的沉浸观感。当前代码存在三处 SDK 不兼容写法导致编译错误：
- `BlurStyle.BACKGROUND_BLUR` 不是合法枚举值
- `ThemeColorMode.AUTO` 不是合法枚举值
- `.mask(new LinearGradient(...))` 中 `LinearGradient` 不是 `mask()` 支持的遮罩类型，且对象字面量不匹配构造签名

## 修复后预期效果
顶部浮层仍保持“顶部清晰模糊、向下渐隐至透明”的沉浸光感，编译错误归零，entry 模块可正常打包。


## 技术栈
- 框架：HarmonyOS ArkUI（ArkTS，严格模式 strictMode + useNormalizedOHMUrl）
- 目标 SDK：HarmonyOS 26.0.0（API 已对照 `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\component\common.d.ts` 核实）

## 实现方案
仅修改单个文件 `MusicHallPage.ets` 的第 259-272 行（LAYER 2 浮层 Column 的链式属性），不涉及架构调整、不新增 import、不改动其他模块。

### 关键修正（均经 SDK d.ts 核实）
1. **BlurStyle 枚举**：`common.d.ts:9659-9697` 定义背景模糊成员为 `BACKGROUND_THIN=3`、`BACKGROUND_REGULAR=4`、`BACKGROUND_THICK=5`，无 `BACKGROUND_BLUR`。改为 `BlurStyle.BACKGROUND_REGULAR`（中等景深，贴合顶部栏观感）。
2. **ThemeColorMode 枚举**：`common.d.ts:9899-9935` 定义成员为 `SYSTEM=0`、`LIGHT=1`、`DARK=2`；且 `BlurStyleOptions.colorMode` 默认值即为 `ThemeColorMode.SYSTEM`（`common.d.ts:10280-10300`）。`AUTO` 不存在，改为 `ThemeColorMode.SYSTEM`。
3. **渐变遮罩**：`mask()` 仅接受 `ProgressMask | CircleAttribute | EllipseAttribute | PathAttribute | RectAttribute`（`common.d.ts:28810`），`LinearGradient` 非法。改用形状遮罩 `Rect({width:'100%',height:'100%'}).linearGradient({...})` 实现渐变遮罩。形状 `linearGradient` 属性签名 `linearGradient(value: LinearGradientOptions)`（`common.d.ts:28087`），其 `colors` 类型为 `Array<[ResourceColor, number]>`（`common.d.ts:5152`），与现有 `[[Color.White,0.0],...]` 写法完全一致。

### 遮罩逻辑
顶部 `Color.White`（alpha=1，模糊可见）→ 底部 `Color.Transparent`（alpha=0，模糊隐藏），`direction: GradientDirection.Bottom`，实现“底部渐隐”，与原始设计意图一致。`HEADER_HEIGHT=164`、`HEADER_FADE=76` 常量已定义（第 12-16 行），算术 `(HEADER_HEIGHT - HEADER_FADE) / HEADER_HEIGHT` 合法。`backgroundColor` 仍受遮罩作用，仅在顶部不透明区显示着色。

## 实施注意
- 不引入新的 import（`Rect`、`GradientDirection`、`Color`、`BlurStyle`、`ThemeColorMode`、`AdaptiveColor` 均为 ArkUI 内置）。
- 不改动浮层之外的任何代码，控制改动范围，避免回归。
- 修改后仅需重新执行 entry 模块 `assembleHap` 构建验证 ERROR 归零；201 个 WARN 为既有历史告警，可忽略。


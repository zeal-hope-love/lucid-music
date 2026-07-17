---
name: musichall-ui-revamp
overview: 重构 MusicHall 页面 UI：对齐标题位置、平台切换改为 ChipGroup 胶囊样式、筛选 Sheet 加入排序 + Chip 标签、歌单卡片样式对齐 MusicHome 参考项目。
todos:
  - id: align-title
    content: "MusicHallPage 标题对齐首页：添加 Row 容器 + .margin({ top: 64 })，标题高度改为 56vp"
    status: completed
  - id: rewrite-source-tab
    content: 重写 SourceTabBar：ChipGroup 胶囊样式单选 + 右侧 IconGroupSuffix 沉浸光感图标
    status: completed
  - id: rewrite-sheet
    content: 重写 TagFilterSheet：顶部 ChipGroup 排序单选 + 下方 Chip 标签分组筛选
    status: completed
  - id: refine-card-style
    content: PlaylistCard 样式对齐 MusicHome-master：ImageFit.Fill、clip(true)、play_round_triangle_fill、fontSize 调整
    status: completed
  - id: seed-sort-data
    content: MusicMemoryStore 种子排序选项数据，MusicHallPage 新增 activeSortIndex 状态，Sheet 传参扩展
    status: completed
---

## 用户需求

### 标题对齐
"音乐厅"标题当前靠上，需要与首页标题对齐（HomePage 使用 `.margin({ top: 64 })` 上方留白）。

### 平台切换 Tab 栏
参考 HarmonyOSComponentUXExamples 项目的 subtab 胶囊样式-单选，使用 `ChipGroup` + `ChipItemStyle` 重写 `SourceTabBar`，替换当前手写的 Row+Button 方案。样式配置：选中态 `ohos_id_color_emphasize` 背景 + `ohos_id_color_text_primary_contrary` 文字，未选中态 `ohos_id_color_button_normal` 背景。

### 右侧筛选图标
右侧圆形按钮使用沉浸光感风格（hdstab）：`SymbolGlyph` 图标 + `.backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)` 毛玻璃效果 + 半透明背景，营造沉浸式视觉感受。

### Sheet 改造
标签筛选 Sheet 重新设计：
- 顶部增加排序选择区，使用 ChipGroup 单选（推荐/热门/最新/收藏）
- 下方标签筛选改为 Chip 组件（FilterTypeChip.ets 风格），`ChipSize.SMALL`，`multiple: false` 单选模式
- 每组标签前显示分组标题

### 歌单卡片样式
对齐 MusicHome-master 的 ForYouSection 歌单卡片样式：
- 封面 `objectFit: Fill`，外层 `clip(true)` 裁切
- 播放量图标改为 `play_round_triangle_fill`（`fontSize(20)`）
- 播放量文字 `fontSize(10)`，白色
- 标题 `fontSize(14)`，`margin({ top: 4 })`，`maxLines(2)`，`lineHeight(19)`
- 仅网格布局，不左右滑动

## 技术栈
- HarmonyOS ArkUI V2（@ComponentV2, @ObservedV2, @Trace, @Local, @Computed）
- @kit.ArkUI: ChipGroup, ChipGroupItemOptions, ChipItemStyle, ChipSize, IconGroupSuffix, SymbolGlyphModifier, BlurStyle
- musicbasic 模块: MusichallPlaylistItem, TagFilterGroup, TagFilterItem, MusicDbApi, Platform, PlatformLabels

## 实现方案

### 标题对齐策略
在 MusicHallPage 的标题 Text 外层包 Row + `.margin({ top: 64 })`，与 HomePage 完全一致。同时标题高度由 40vp 改为 56vp（28px 字体 + 适量 padding），与首页视觉效果对齐。

### 来源切换 ChipGroup 实现
重写 SourceTabBar：
- 用 `ChipGroup` 替代手写 Row+Button，复用 `COMMON_CHIP_STYLE`（选中: emphasize 背景，未选中: button_normal 背景）
- 通过 `@Computed` 生成 `ChipGroupItemOptions[]`（每个平台标签一个 item，`allowClose: false`）
- 右侧筛选按钮用 `IconGroupSuffix` + `SymbolGlyph`，叠加 `backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)` 和透明背景
- `onChange` 回调中根据 `activatedChipsIndex[0]` 切换 `activeSource`

### Sheet 双层结构
TagFilterSheet 内部分为两层：
- **排序行**：ChipGroup 单选，items 为 ["推荐", "热门", "最新", "收藏"]，`ChipSize.NORMAL`，胶囊风格
- **标签筛选区**：按分组遍历，每组用 Column 包裹，内部 ChipGroup（`ChipSize.SMALL`，`multiple: false`），FilterTypeChip 风格

### 卡片样式对齐
PlaylistCard 关键修改：
1. Image `objectFit: ImageFit.Fill`（从 Cover 改为 Fill）
2. 外层 Stack 加 `.clip(true)`
3. 播放图标改为 `play_round_triangle_fill`（`fontSize(20)`）
4. 播放量文字 `fontSize(10)` + `fontWeight(FontWeight.Medium)` + `lineHeight(13)`
5. 标题 `fontSize(14)` + `lineHeight(19)` + `margin({ top: 4 })`
6. Row 内 `space: 6`，`padding(4)`

## 目录结构

```
features/musichall/src/main/ets/view/
├── MusicHallPage.ets     # [MODIFY] 标题对齐，Sheet 传参扩展
├── SourceTabBar.ets      # [REWRITE] ChipGroup 胶囊样式 + 沉浸光感图标
├── TagFilterSheet.ets    # [REWRITE] ChipGroup 排序 + Chip 标签筛选
├── PlaylistCard.ets      # [MODIFY] 对齐 MusicHome-master 样式

common/musicbasic/src/main/ets/
├── data/MusichallPlaylistItem.ets  # [MODIFY] 可选扩展排序字段
├── db/MusicMemoryStore.ets         # [MODIFY] 种子排序选项数据
```

## 实现细节

### 性能
- ChipGroup 使用 `@Computed` 动态生成 items，选中态切换仅更新 `selectedIndexes`，避免全量重建
- 卡片网格保持 3 列 `1fr 1fr 1fr`，歌单数据通过 `@Local` + `filter` 控制，O(n) 过滤

### 兼容性
- 保持 `bindSheet` 使用 `@Builder` 包装模式
- 保持 `NavPathStack.pushPath` + `{ animated: false }` 路由约定
- 保持底部 `padding({ bottom: 160 })` 为 MiniPlayerBar+LucidTabBar 留空间

### 数据模型扩展
- MusicMemoryStore 新增 `musichallSortOptions: string[]` = ["推荐", "热门", "最新", "收藏"]
- MusicHallPage 新增 `@Local activeSortIndex: number = 0`
- TagFilterSheet 接收 `sortOptions`, `activeSortIndex`, `onSortChange` 参数

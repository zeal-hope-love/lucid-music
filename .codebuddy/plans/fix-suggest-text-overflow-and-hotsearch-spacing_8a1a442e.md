---
name: fix-suggest-text-overflow-and-hotsearch-spacing
overview: 三处修复：(1) 搜索建议文本单行省略 (2) 热门搜索 top padding 恢复 (3) 热门搜索 Scroll 改 Flex 布局消除内容较小时的居中感
todos:
  - id: fix-suggest-text-ellipsis
    content: suggestionContent 中 Text(item.text) 添加 maxLines(1) 和 textOverflow 省略号
    status: completed
  - id: fix-hotsearch-spacing
    content: hotSearchTags 恢复 top:8 padding，CapsuleSegmentButtonV2 恢复 bottom:4 margin
    status: completed
  - id: fix-hotsearch-layout
    content: HOT/SUGGESTING 布局重构：Scroll 移去 layoutWeight(1)，外层 Column 统一管理高度和顶部对齐
    status: completed
---

## 用户需求
1. **搜索建议文本溢出省略**：建议项文本只显示一行，超出部分用省略号（...）截断
2. **热门搜索展开后间距**：展开状态与平台切换 Tab 之间需要保留适当距离，当下紧贴太近
3. **热门搜索收起后顶部对齐**：收起状态内容不应悬浮在 Swiper 区域中间，应靠顶部自然排列

## 核心修复
- `suggestionContent()` 中 `Text(item.text)` 缺少 `maxLines(1)` 和 `textOverflow`
- `hotSearchTags` padding 无 `top` 值导致贴 Tab
- HOT state 的 `Scroll` 有 `layoutWeight(1)`，内容少时大量空白使内容视觉居中
- `CapsuleSegmentButtonV2` 缺 `bottom` margin 使 Swiper 紧贴

## 技术方案

仅修改 `features/search/src/main/ets/view/SearchPage.ets`，共 3 处改动。

### 改动 1：搜索建议文本省略（第 237-240 行）
```typescript
// 修改前
Text(item.text)
  .fontSize(15)
  .fontColor($r('sys.color.ohos_id_color_text_primary'))
  .layoutWeight(1)

// 修改后
Text(item.text)
  .fontSize(15)
  .fontColor($r('sys.color.ohos_id_color_text_primary'))
  .layoutWeight(1)
  .maxLines(1)
  .textOverflow({ overflow: TextOverflow.Ellipsis })
```

### 改动 2：恢复热门搜索顶部间距（第 183 行）
```typescript
// 修改前（无 top）
.padding({ left: 16, right: 16, bottom: 8 })

// 修改后（恢复 top: 8）
.padding({ left: 16, right: 16, top: 8, bottom: 8 })
```

同时恢复 `CapsuleSegmentButtonV2` 的 `bottom: 4` margin（第 431 行）：
```typescript
// 修改前
.margin({ left: 16, right: 16, top: 4 })

// 修改后
.margin({ left: 16, right: 16, top: 4, bottom: 4 })
```

### 改动 3：HOT/SUGGESTING 布局重构（第 460-474 行）
**根因**：`Scroll` 有 `layoutWeight(1)` 导致占满 Swiper 全高，内容少时视觉上居中悬浮。

**修复**：将 `layoutWeight(1)` 从 `Scroll` 移到外层 `Column`，并加 `justifyContent(FlexAlign.Start)` 强制顶部对齐：

```typescript
// 修改前
if (this.viewModel.currentState === SearchState.HOT) {
  Scroll() {
    Column() {
      this.hotSearchTags()
      this.searchHistoryContent()
    }
  }
  .width('100%').layoutWeight(1).scrollBar(BarState.Off)
} else if (this.viewModel.currentState === SearchState.SUGGESTING) {
  Scroll() {
    this.suggestionContent()
  }
  .width('100%').scrollBar(BarState.Off)
}

// 修改后
Column() {
  if (this.viewModel.currentState === SearchState.HOT) {
    Scroll() {
      Column() {
        this.hotSearchTags()
        this.searchHistoryContent()
      }
    }
    .width('100%').scrollBar(BarState.Off)
  } else if (this.viewModel.currentState === SearchState.SUGGESTING) {
    Scroll() {
      this.suggestionContent()
    }
    .width('100%').scrollBar(BarState.Off)
  }
}
.width('100%').layoutWeight(1).justifyContent(FlexAlign.Start)
```

切换逻辑提到外层 `Column` 内，`Scroll` 不再有高度约束，内容自然靠顶。

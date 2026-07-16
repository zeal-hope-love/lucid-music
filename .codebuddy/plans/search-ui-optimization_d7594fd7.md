---
name: search-ui-optimization
overview: 优化搜索功能：修复网易云热搜显示、热门搜索折叠展开UI、平台切换内容闪烁、搜索结果添加音质字段、搜索提示位置与格式修正
todos:
  - id: fix-hotsearch-163
    content: 修复网易云热搜不显示：增强 hotSearchNetease 请求头、refreshHotSearches 增加降级回退链
    status: completed
  - id: add-quality-field
    content: SearchResultItem 新增 quality 字段，MusicApiService 5个平台的 mapXxxList 中提取音质并赋值
    status: completed
  - id: simplify-suggest-text
    content: 简化搜索提示文本：suggestQQ/suggestMigu 去掉歌手拼接，suggestNetease 只保留歌曲名，统一左侧对齐布局
    status: completed
  - id: hotsearch-collapse
    content: 热门搜索折叠展开：SearchViewModel 新增 hotSearchExpanded，SearchPage 实现6行折叠+展开箭头+Scroll
    status: completed
    dependencies:
      - fix-hotsearch-163
  - id: fix-platform-switch-flicker
    content: 修复平台切换闪烁：SearchResultViewModel 新增 clearResults()，onPlatformSelectedChange 立即清空旧结果再搜索
    status: completed
    dependencies:
      - add-quality-field
  - id: result-ui-quality
    content: 搜索结果 UI 更新：在歌手名前渲染音质标签，调整行布局间距
    status: completed
    dependencies:
      - add-quality-field
      - fix-platform-switch-flicker
---

## 用户需求

### 1. 修复网易云热搜不显示
切换到网易云平台时，热门搜索词无法正常加载显示。需要排查 `hotSearchNetease()` API 调用及 `initHotSearches()`/`refreshHotSearches()` 的回退链。

### 2. 热门搜索折叠展开
热门搜索标签超过6行时，默认只显示6行，末尾显示展开箭头提示。点击展开后，全部标签可滚动浏览。

### 3. 平台切换闪烁修复
在搜索结果页左右滑动切换平台时，Swiper 切换动画期间会短暂显示上一个平台的旧结果，需在切换瞬间立即清空结果列表并显示加载态。

### 4. 搜索结果添加音质字段
在每首搜索结果中，于歌手名前显示音质标签（如"无损"、"HQ"、"SQ"、"标准"等），从各平台 API 原始数据中提取。

### 5. 搜索提示优化
- 提示列表位置从居中改为左对齐，对齐平台 Tab
- 提示文本简化为纯联想关键词，TX/MG 不再拼接"歌名 - 歌手"格式
- 修复提示偶尔不显示的问题


## 技术方案

### 1. 网易云热搜修复

**问题分析**：`hotSearchNetease()` 调用公开 API `music.163.com/api/search/hot/detail`，但该接口可能因反爬策略返回空或失败。且 `initHotSearches()` 启动时默认请求酷狗平台，切换到网易云时才走 `refreshHotSearches()`。

**修复方案**：
- 在 `initHotSearches()` 中增加网易云 API 的显式调试日志
- `refreshHotSearches()` 失败时追加回退逻辑：先尝试网易云公开 API，再降级到默认数据
- 为 `hotSearchNetease()` 添加更完整的 Referer/UA header

### 2. 热门搜索折叠展开

**方案**：在 `SearchViewModel` 新增 `@Trace hotSearchExpanded: boolean = false`。SearchPage 中用 `Flex` 配合 `constraintSize({ maxHeight })` 限制默认高度为 6 行（约 200vp），展开后移除限制并用 `Scroll` 包裹。

**关键参数**：每个标签按钮高度约 `13(fontSize) + 12(padding) + 8(margin) ≈ 33vp`，6 行约 `200vp`。

### 3. 平台切换闪烁修复

**根因**：`onPlatformSelectedChange()` 中通过 `setTimeout(() => this.resultVM.doSearch(kw), 300)` 延迟执行搜索，300ms 内旧结果仍存在。

**修复方案**：在 `@Monitor('platformSelectedIndex')` 回调中，立即执行 `this.resultVM.results = []` 和 `this.resultVM.isLoading = true`，然后延迟发起搜索请求。同时在 `SearchResultViewModel` 新增 `clearResults()` 方法统一处理。

### 4. 搜索结果音质提取

**各平台音质字段映射**：

| 平台 | 原始字段 | 音质判定逻辑 |
|------|---------|-------------|
| 酷狗 | `SQFileHash`/`HQFileHash` | SQ 非空→"SQ"，HQ 非空→"HQ"，否则→"" |
| QQ | `size320`/`sizesq`/`sizehr` | sizehr>0→"Hi-Res"，sizesq>0→"SQ"，size320>0→"HQ" |
| 网易云 | `privilege.maxbr` | maxbr≥999000→"SQ"，maxbr≥320000→"HQ" |
| 酷我 | `FORMATS` 或 `N_MINFOMATION` | 包含"无损"→"SQ"，包含"320"→"HQ" |
| 咪咕 | `rateFormats` 或比特率 | 含"flac"→"SQ"，含"320"→"HQ" |

在 `SearchResultItem` 新增 `@Trace quality: string = ''`。各 `mapXxxList` 方法中提取并赋值。

### 5. 搜索提示优化

- **文本简化**：修改 `suggestQQ()`/`suggestMigu()` 中的 text 拼接逻辑，从 `singer ? \`${name} - ${singer}\` : name` 改为仅 `name`
- **左对齐**：suggestionContent() 中 `.width('90%')` 改为 `.width('100%').padding({ left: 16, right: 16 })`
- **不显示问题**：在 `debounceFetchSuggestions` 中增加空关键词检查，`fetchSuggestions` 中增加请求前 `kw` 验证

### 受影响文件 (5个)

- `SearchResultItem.ets` — 新增 quality 字段
- `MusicApiService.ets` — 各平台音质提取 + 建议文本简化
- `SearchViewModel.ets` — 新增 hotSearchExpanded + 热搜回退逻辑
- `SearchResultViewModel.ets` — 新增 clearResults() + 修复闪烁
- `SearchPage.ets` — 热搜折叠UI + 音质显示 + 建议布局调整


---
name: search-fix-round2
overview: 修复热搜折叠失效、网易云热搜用EAPI加密、搜索提示触发、平台切换闪烁(保留滑动)、音质标签增加24bit
todos:
  - id: eapi-encrypt
    content: MusicApiService.ets：实现 MD5 + AES-ECB-NoPadding EAPI 加密方法，重写 hotSearchNetease 为 POST /eapi/batch，5平台音质升级（24bit/SQ/HQ）
    status: completed
  - id: resume-suggesting
    content: SearchViewModel.ets 新增 resumeSuggesting()；SearchPage.ets 中 onSearchInputTap/onBack 返回时触发联想
    status: completed
  - id: hotsearch-collapse-v2
    content: SearchPage.ets：热搜改用 visibleHotSearches.slice(0,24) 截断，移入 Swiper 内 Scroll，HOT state 统一可滚动
    status: completed
  - id: fix-swipe-flicker-v2
    content: SearchPage.ets：Swiper 各页面按 currentPlatform 匹配渲染，非当前平台页显示 LoadingProgress 替代旧数据
    status: completed
---

## 用户需求

### 1. 热搜折叠展开修复 + 页面可滚动
当前 `constraintSize({ maxHeight })` 对 `Flex({ wrap: FlexWrap.Wrap })` 无效，折叠不生效。且热搜在 Swiper 外部，展开后页面不可滚动。需改用 `.slice(0, 24)` 实际截断热词数量，并将热搜区域移入 Swiper 内部的 Scroll 容器中。

### 2. 网易云热搜改用 EAPI 加密
公开 API `music.163.com/api/search/hot/detail` 已不可用。需对齐 lx-music-mobile 的 EAPI 加密 POST 方案，调用 `http://interface.music.163.com/eapi/batch`。

### 3. 搜索提示自动恢复显示
从搜索结果页返回热搜模式时，如果搜索框内有内容，应自动显示联想建议。当前 `onSearchInputTap()` 和 `onBack()` 返回后不触发联想。

### 4. Swiper 平台切换闪烁（保留滑动）
不用禁用 Swiper 滑动。每个 Swiper 页面按 `resultVM.currentPlatform === _platform.platform` 匹配渲染，非当前平台的页面不显示共享的 resultVM.results，改为显示加载态。这样滑动时目标页不会闪现旧数据。

### 5. 音质标签升级
对齐 lx-music-mobile 的 24bit/SQ/HQ 三级体系。QQ 平台当前的 "Hi-Res" 改为 "24bit"，酷狗新增 `ResFileHash` 检测 24bit。


## 技术方案

### 修改文件清单（3 个文件）

#### 1. MusicApiService.ets — EAPI 加密 + hotSearchNetease 重写 + 5平台音质升级

**新增 EAPI 加密方法**：
- `md5Hex(input: string): Promise<string>` — 用 `cryptoFramework.createMd('MD5')` 计算 MD5，输出 hex 小写
- `aesEcbEncrypt(plainBase64: string): Promise<string>` — AES-128-ECB-NoPadding 加密，输出 hex 大写。NoPadding 要求 16 字节对齐：将 plainBase64 字符串转 UTF-8 bytes 后，手动 PKCS7 padding 补齐 16 的倍数
- `eapiEncrypt(url: string, data: Record<string, Object>): Promise<string>` — 组合完整 EAPI 加密流程

**重写 hotSearchNetease()**：
- URL: `http://interface.music.163.com/eapi/batch`
- Method: POST
- EAPI 参数: `{ id: 'HOT_SEARCH_SONG#@#' }`，url 参数: `/api/search/chart/detail`
- Headers: `User-Agent: Mozilla/5.0...`, `Origin: https://music.163.com`
- Content-Type: `application/x-www-form-urlencoded`
- Body: `params=<eapiEncrypt 结果>`
- 响应解析: `body.data.itemList[].searchWord`

**音质升级（5 平台 map 函数）**：
- 酷狗 `mapKugouList`：新增 `ResFileHash` → "24bit"，`SQFileHash` → "SQ"，`HQFileHash` → "HQ"
- QQ `mapQQList`：`sizehr` → "24bit"（替换 "Hi-Res"），`sizesq` → "SQ"，`size320` → "HQ"
- 网易云 `mapNeteaseList`：保持 `privilege.maxbr` 判断 SQ/HQ，当前搜索 API 无 24bit 字段
- 酷我 `mapKuwoList`/咪咕 `mapOneMiguSong`：保持现有逻辑

#### 2. SearchViewModel.ets — 新增 resumeSuggesting()

```typescript
/** 从结果模式返回时恢复联想建议 */
public resumeSuggesting(): void {
  if (this.keyword.trim().length > 0) {
    this.currentState = SearchState.SUGGESTING
    this.debounceFetchSuggestions(this.keyword)
  }
}
```

#### 3. SearchPage.ets — 四大改动

**A. 热搜折叠 v2**：
- 新增 `@Computed get visibleHotSearches(): string[]` — 按 `hotSearchExpanded` 返回全量或 `.slice(0, 24)`
- `hotSearchTags()` 中 `ForEach` 的源数据从 `this.viewModel.hotSearches` 改为 `this.visibleHotSearches`
- 移除无效的 `constraintSize({ maxHeight })`
- 展开阈值保持 `hotSearches.length > 24`

**B. 热搜移入 Swiper Scroll**：
- 将热搜区域从 Swiper 外部（build() 中 line 420-423）移入 Swiper 内 HOT state 的 Column 中
- HOT state 的 Scroll 包裹 `hotSearchTags()` + `searchHistoryContent()`，实现展开后可滚动

**C. Swiper 平台匹配渲染（保留滑动）**：
每个 Swiper 页面的结果区域增加平台匹配检查：
```typescript
if (this.resultVM.currentPlatform === _platform.platform) {
  // 显示结果 / 加载 / 空状态（当前逻辑）
} else {
  LoadingProgress().width(40).height(40).margin({ top: 100 })
}
```
这样 Swiper 滑动切换时，目标页不会使用旧平台的 resultVM.results，而是显示加载态。

**D. 搜索提示自动恢复**：
- `onSearchInputTap()` 返回后追加 `this.viewModel.resumeSuggesting()`
- `onBack()` 返回后追加 `this.viewModel.resumeSuggesting()`


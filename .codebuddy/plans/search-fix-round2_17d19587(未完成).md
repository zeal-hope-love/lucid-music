---
name: search-fix-round2
overview: 修复第二轮问题：热搜折叠失效/页面不能滑动、网易云热搜换EAPI加密接口、搜索提示触发逻辑、平台切换闪烁彻底修复、音质类型确认
todos:
  - id: eapi-encrypt
    content: MusicApiService.ets：实现 MD5 + AES-ECB-PKCS7 EAPI 加密方法，重写 hotSearchNetease 为 POST /eapi/batch
    status: pending
  - id: resume-suggesting
    content: SearchViewModel.ets：新增 resumeSuggesting 方法；SearchPage.ets 中 onSearchInputTap/onBack 返回时触发联想
    status: pending
  - id: hotsearch-collapse-v2
    content: SearchPage.ets：热搜索改用 visibleHotSearches.slice(0,24) 控制折叠，移入 Swiper 内部 Scroll
    status: pending
  - id: fix-swipe-flicker
    content: SearchPage.ets：结果模式下 disableSwipe(true) 禁用滑动切换，消除过渡动画闪烁
    status: pending
---

## 问题1：热搜折叠展开失效
收起状态仍显示全部标签，内容溢出不裁剪，页面不可滚动。

**期望**：未展开时只显示前24条（约6行），折叠生效；展开后显示全部，整体放入 Scroll 可滑动。

## 问题2：网易云热搜无法获取
切换网易云平台时热搜为空。需对齐 lx-music-mobile 的 EAPI 加密 POST 方案，替代已失效的公开 GET API。

## 问题3：搜索提示难以触发
从结果页返回搜索框有内容时不显示联想。期望搜索框聚焦且有内容时始终显示联想建议。

## 问题4：平台切换闪烁
结果页 Swiper 滑动切换平台时，过渡动画中闪现旧平台内容。

## 问题5：音质分类确认
当前已实现的音质标签：酷狗(SQ/HQ)、QQ(Hi-Res/SQ/HQ)、网易云(SQ/HQ)、酷我(SQ/HQ)、咪咕(SQ/HQ)。显示为橙色小标签置于歌手名前。


## 实施方案

### 修改文件清单（4个文件）

#### 1. MusicApiService.ets — 新增 EAPI 加密 + 重写 hotSearchNetease

**新增私有静态方法**：
- `md5Hash(input: string): Promise<string>` — 用 `cryptoFramework.createMd('MD5')` 计算 MD5 hex 摘要
- `aesEcbEncrypt(plainBase64: string, keyBase64: string): Promise<string>` — 用 `cryptoFramework.createCipher('AES128|ECB|NoPadding')` 做 AES-ECB-NoPadding 加密，输出 hex 大写
- `eapiEncrypt(url: string, data: Record<string, Object>): Promise<string>` — 组合 EAPI 完整加密流程

**EAPI 加密实现细节**：
```
步骤1: message = 'nobody' + url + 'use' + JSON.stringify(data) + 'md5forencrypt'
步骤2: digest = MD5(message) → hex 小写
步骤3: plainText = url + '-36cd479b6b5-' + JSON.stringify(data) + '-36cd479b6b5-' + digest
步骤4: plainBase64 = base64Encode(plainText)
步骤5: keyBytes = base64Decode('e82ckenh8dichen8')  // 解码为 8 字节
步骤6: encrypted = AES-ECB-NoPadding(plainBase64, keyBytes)
步骤7: params = encrypted → hex 大写
```
注意：AES-ECB-NoPadding 要求输入是 16 字节对齐。plainBase64 字符串需先转 ArrayBuffer（utf-8 encode），若输入长度不足 16 倍数则 AES 会报错。ArkTS `cryptoFramework` 的 NoPadding 模式严格要求输入是 blockSize 的整数倍。因此需要手动 PKCS7 padding 或不使用 base64 编码而直接对原始文本加密。

**更安全的 ArkTS 实现方式**：使用 `AES128|ECB|PKCS7`（如果 ArkTS 支持）或手动在 base64 编码后补足 16 字节对齐再使用 NoPadding。推荐直接用 `PKCS7` 填充模式（ArkTS `cryptoFramework` 支持 `AES128|ECB|PKCS7`）。

**重写 hotSearchNetease()**：
- URL: `http://interface.music.163.com/eapi/batch`
- Method: POST
- Content-Type: `application/x-www-form-urlencoded`
- Headers: `User-Agent`, `Origin: https://music.163.com`
- Body: `params=<eapiEncrypt结果>`
- 响应解析: `body.data.itemList[].searchWord`

#### 2. SearchViewModel.ets — 新增 resumeSuggesting 方法

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

**A. 热搜折叠**：
- 新增 `@Computed get visibleHotSearches(): string[]` 按 `hotSearchExpanded` 返回全量或 `.slice(0, 24)`
- `hotSearchTags()` 中 `ForEach` 改用 `visibleHotSearches`
- 热搜区从 Swiper 外部（line 420-423）移入 Swiper 内部 HOT state Column 中
- HOT state 内 Scroll 包裹 hotSearchTags() + searchHistoryContent()，统一可滚动

**B. 搜索提示触发**：
- `onSearchInputTap()` 返回时调用 `this.viewModel.resumeSuggesting()`
- `onBack()` 从结果返回时也调用 `this.viewModel.resumeSuggesting()`

**C. 平台切换闪烁**：
- 新增 `@Computed get swipeEnabled(): boolean { return !this.isResultMode }`
- Swiper: `.disableSwipe(!this.swipeEnabled)`
- 同时保留 `onPlatformSelectedChange` 中的 `clearResults()` 调用作为双重保障

**D. Swiper 内部布局重构**（HOT state 改为）：
```typescript
// 展开模式下：hotSearch + history 统一在 Scroll 内
Scroll() {
  Column() {
    this.hotSearchTags()
    this.searchHistoryContent()
  }
}
.width('100%').layoutWeight(1).scrollBar(BarState.Off).margin({ top: 8 })
```


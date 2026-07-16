---
name: fix-hotsearch-suggest-apis
overview: 根据 lx-music-mobile 的真实 API 修正 MusicApiService 中的热搜和搜索建议方法，使所有 5 个平台的热搜和建议都使用正确的 API 端点和响应解析
todos:
  - id: fix-dispatch
    content: 修正 hotSearch 和 suggest 的 dispatch switch，新增 kw/mg 独立 case
    status: completed
  - id: fix-hotsearch
    content: 重写 4 个平台热搜方法：hotSearchQQ(POST+JSON body)、hotSearchKugou(签名+完整headers)、hotSearchKuwo(原生API)、hotSearchMigu(新增，过滤resourceType==song)
    status: completed
    dependencies:
      - fix-dispatch
  - id: fix-suggest
    content: 重写 4 个平台搜索提示方法：suggestKugou(解析body[0].RecordDatas)、suggestQQ(补全URL参数)、suggestKuwo(tips.kuwo.cn)、suggestMigu(新增)
    status: completed
    dependencies:
      - fix-dispatch
---


## 修正目标

仅修改 `features/search/src/main/ets/service/MusicApiService.ets` 一个文件，对齐 lx-music-mobile 的真实 API 实现：

### 热搜修正（4 个方法）
- **酷我 `hotSearchKuwo()`**：当前 fallback 到网易云 → 改为酷我原生热搜 API `http://hotword.kuwo.cn/hotword.s`
- **咪咕 `hotSearchMigu()`**：当前不存在 → 新增 `http://jadeite.migu.cn:7090/music_search/v3/search/hotword`
- **QQ `hotSearchQQ()`**：当前用简化版 `gethotkey.fcg` → 改为 POST `u.y.qq.com/cgi-bin/musicu.fcg` 带 `HotkeyService`
- **酷狗 `hotSearchKugou()`**：当前 fallback 到网易云 → 改为 `gateway.kugou.com/api/v3/search/hot_tab` 带签名和完整 headers

### 搜索提示修正（4 个方法）
- **酷我 `suggestKuwo()`**：当前用搜索 API 代替 → 改为 `tips.kuwo.cn/t.s` 原生提示接口
- **咪咕 `suggestMigu()`**：当前不存在 → 新增 `music.migu.cn/v3/api/search/suggest`
- **酷狗 `suggestKugou()`**：响应解析错误（`data.tip[]` → `body[0].RecordDatas[].HintInfo`），URL 加 `MusicTipCount=10`
- **QQ `suggestQQ()`**：URL 参数补全 `is_xml=0&loginUin=0&hostUin=0&notice=0&platform=yqq&needNewCode=0`

### dispatch 修正
- `hotSearch()` switch 新增 `kw` 和 `mg` case
- `suggest()` switch 新增 `mg` case



## 技术方案

### 修改范围
仅修改 `features/search/src/main/ets/service/MusicApiService.ets`

### 具体改动点

**1. dispatch 层（第 59-91 行）**
- `hotSearch()` switch：新增 `case 'kw': return MusicApiService.hotSearchKuwo()` 和 `case 'mg': return MusicApiService.hotSearchMigu()`
- `suggest()` switch：新增 `case 'mg': return MusicApiService.suggestMigu(keyword)`

**2. hotSearch 方法替换**

| 方法 | API 端点 | HTTP | 响应解析 | 特殊要求 |
|------|----------|------|----------|----------|
| `hotSearchKuwo` | `http://hotword.kuwo.cn/hotword.s?prod=...` | GET | `{status:'ok', tagvalue:[{key}]}` → `item.key` | UA: `Dalvik/2.1.0` |
| `hotSearchMigu` | `http://jadeite.migu.cn:7090/music_search/v3/search/hotword` | GET | `{code:'000000', data:{hotwords:[{hotwordList}]}}` → 过滤 `resourceType=='song'` → `item.word` | 无 |
| `hotSearchQQ` | `https://u.y.qq.com/cgi-bin/musicu.fcg` | POST JSON | `{code:0, hotkey:{data:{vec_hotkey:[{query}]}}}` → `item.query` | JSON body 含 `comm` 和 `hotkey` 模块参数 |
| `hotSearchKugou` | `http://gateway.kugou.com/api/v3/search/hot_tab?signature=...` | GET | `{errcode:0, data:{list:[{keywords:[{keyword}]}]}}` → 展平 `keywords` → `item.keyword` | 6 个特定 headers |

**3. suggest 方法替换**

| 方法 | API 端点 | 响应解析 | 特殊要求 |
|------|----------|----------|----------|
| `suggestKuwo` | `https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&...w=${keyword}` | `{WORDITEMS:[{RELWORD}]}` → `item.RELWORD` | Referer: `http://www.kuwo.cn/` |
| `suggestMigu` | `https://music.migu.cn/v3/api/search/suggest?keyword=${keyword}` | `{songs:[{name, singerName}]}` → `name - singerName` | referer: `https://music.migu.cn/v3` |
| `suggestKugou` | URL 加 `MusicTipCount=10`，headers 加 `referer` | `body[0].RecordDatas[].HintInfo` | referer: `https://www.kugou.com/` |
| `suggestQQ` | URL 补全参数 | 不变（`data.song.itemlist[]`） | 额外参数: `is_xml=0, loginUin=0, notice=0, platform=yqq, needNewCode=0` |

### 性能与可靠性
- 所有方法保持 try-catch + fallback 空数组模式
- 超时统一 5000ms，与搜索 API 的 10000ms 区分（热搜/建议非核心路径）
- Logger 日志记录每个平台的错误信息


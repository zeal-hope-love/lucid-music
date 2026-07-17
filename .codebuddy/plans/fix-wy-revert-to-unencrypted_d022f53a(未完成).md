---
name: fix-wy-revert-to-unencrypted
overview: 放弃 eapi 加密路径，回退到网易云未加密 API：搜索恢复旧版 /api/search/get，封面通过未加密 song/detail 批量获取，热搜废弃 eapi 改用简单 API 或备用列表。
todos:
  - id: revert-search-mapList
    content: 回退 WyMusicApi.ets 的 search() 和 mapList() 到旧版未加密 GET API 格式
    status: pending
  - id: add-fetch-song-covers
    content: 新增 fetchSongCovers() 批量歌曲详情 API 方法，封面缺失时兜底补全
    status: pending
    dependencies:
      - revert-search-mapList
  - id: simplify-hotsearch
    content: 简化 hotSearch() 直接返回空数组，触发 SearchViewModel 已有默认兜底链
    status: pending
  - id: remove-eapi-deadcode
    content: 删除 WyMusicApi.ets 中 eapiRequest() 方法和 eapiEncrypt 导入
    status: pending
    dependencies:
      - simplify-hotsearch
  - id: cleanup-musicapi-utils
    content: 清理 MusicApiUtils.ets 中 eapi 死代码（eapiEncrypt、md5Hex、AES 函数、unused imports）
    status: pending
    dependencies:
      - remove-eapi-deadcode
---

## 用户需求
上轮修改后网易云搜索和热搜全部不可用，需恢复到修改前可工作的状态并解决封面问题。

## 核心目标
1. 搜索恢复可用（回退到未加密 GET API）
2. 搜索结果包含封面（通过批量歌曲详情 API 补全）
3. 热搜恢复显示（利用已有默认兜底机制）

## 根因
eapi 加密端点 `interface.music.163.com/eapi/batch` 在 HarmonyOS 上完全不通（HTTP和HTTPS均失败）。上轮修改将原本可用的未加密搜索 `/api/search/get` 改为 eapi 加密搜索，导致搜索结果全部消失。热搜原本就走 eapi，本来就不可用。


## 技术方案

### 策略：完全放弃加密，回归未加密 API

修改前已验证可用的未加密端点全部保留不动（歌词/播放URL/联想），仅改动搜索和热搜两个失败路径。

### 修改文件及内容

#### 1. WyMusicApi.ets — 回退搜索 + 简化热搜 + 删除 eapi 死代码

**search()** — 回退到原来的 GET 请求：
- API：`https://music.163.com/api/search/get?s=${keyword}&type=1&offset=${(page-1)*limit}&limit=${limit}`
- 响应解析：`body.result.songs[]`
- 从 songs 解析 SearchResultItem，提取封面字段 `album.picUrl` 或 `al.picUrl`
- 封面缺失的歌曲收集 songId，搜索完成后批量调用 `fetchSongCovers()` 补全

**mapList()** — 回退解析旧 API 数据结构：
- 输入：`result.songs[]`（平铺结构，不是嵌套的 baseInfo.simpleSongData）
- 歌手：`item.artists[]` join `/`
- 封面：优先 `album.picUrl` → `al.picUrl` → 批量详情API兜底
- 时长：`item.duration / 1000`（毫秒）
- 音质：`item.privilege.maxbr / maxBrLevel`

**fetchSongCovers()** — 新增批量封面获取：
- 输入：songId 数组
- 请求：`GET https://music.163.com/api/song/detail?ids=${ids.join(',')}`
- 解析：`body.songs[].al.picUrl`
- 返回：`Map<string, string>` 映射 songId → coverUrl
- 超时 8 秒，单次最多 50 个 ID

**hotSearch()** — 直接返回空数组：
- 移除 eapi 加密请求
- 返回 `[]`，由 SearchViewModel 已有兜底链处理：空 → 尝试其他平台 → `defaultHotSearches()`

**删除**：`eapiRequest()` 私有方法、`eapiEncrypt` import

#### 2. MusicApiUtils.ets — 清理 eapi 死代码

删除以下无其他引用的导出和内部函数：
- `eapiEncrypt()`（仅 WyMusicApi 使用）
- `md5Hex()`（仅 eapiEncrypt 使用）
- `EAPI_KEY` 常量
- `zeroPad()` 内部函数
- `aesEcbEncryptBase64()` 内部函数

清理不再需要的 import：
- `http` from `@kit.NetworkKit`（整个 MusicApiUtils 无 HTTP 调用，仅类型定义）
- `cryptoFramework` from `@kit.CryptoArchitectureKit`（仅 eapi 加密使用）
- `buffer` from `@kit.ArkTS`（仅 eapi 加密使用）；保留 `util`（`decodeBase64Lyric` 使用）

### 性能分析
- 搜索：1 次 GET 请求（回退前 1 次 POST，不变）
- 封面：0~1 次批量 GET（之前 eapi 模式下 0 次，但 eapi 不通导致搜索全挂；现在兜底最多 1 次 /song/detail 批量请求覆盖 50 首）
- 热搜：0 次请求（回退前 1 次 eapi POST，但始终失败；现在直接走默认列表）


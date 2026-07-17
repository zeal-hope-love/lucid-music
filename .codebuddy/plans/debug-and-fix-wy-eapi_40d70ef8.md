---
name: debug-and-fix-wy-eapi
overview: 不放弃 eapi，通过添加详细诊断日志定位失败根因，同时修复已知的 header 差异（User-Agent、Accept），并加固请求容错（http/https 自动 fallback、请求重试）。
todos:
  - id: fix-headers
    content: "修复 eapiRequest 和 hotSearch 中的请求头：User-Agent 补全 (KHTML, like Gecko)、添加 Accept: application/json、origin 改为小写"
    status: completed
  - id: add-diag-logs
    content: 在 eapiRequest 中增加完整诊断日志：记录 httpCode、result 类型/长度、响应体前 200 字符、异常详情
    status: completed
  - id: add-legacy-fallback
    content: search() 中增加未加密兜底路径：eapi 失败后自动回退到 https://music.163.com/api/search/get，新增 parseLegacyResult() 解析旧版数据结构
    status: completed
    dependencies:
      - fix-headers
  - id: fix-hotsearch-diag
    content: hotSearch() 添加诊断日志，保持 eapi 路径，失败返回空数组触发已有默认兜底链
    status: completed
    dependencies:
      - fix-headers
---

## 用户需求
修复网易云音乐 eapi 加密路径，使搜索和热搜功能恢复正常。用户明确要求不要放弃 eapi 方案，坚持排查修复。

## 核心问题
当前 eapi POST 到 `http://interface.music.163.com/eapi/batch` 在 HarmonyOS 上失败，但 AES 加密算法已验证正确，HTTP POST 用法也符合 HarmonyOS 规范。**缺失的关键信息**：实际的 HTTP 响应状态码和 body 内容不明，导致无法定位根因。

## 修复策略
1. **添加完整诊断日志**：记录 `eapiRequest` 中 `responseCode`、`result` 类型/长度/前 200 字符、异常详情，通过日志暴露真实失败原因
2. **对齐 lx-music 请求头**：修复 User-Agent 缺少的 `(KHTML, like Gecko)` 片段，添加 `Accept: application/json`，header key 统一小写
3. **搜索增加未加密兜底**：eapi 搜索失败时自动回退到 `https://music.163.com/api/search/get`，解析旧版数据结构保证搜索结果不丢失（封面可缺失但搜索能出结果）
4. **热搜增加兜底链利用**：保持现有 fallback 机制（SearchViewModel 已有空数组→其他平台→defaultHotSearches 三级兜底）

## 技术方案

### 1. 请求头对齐 lx-music

lx-music 的 `handleRequestData` 函数在 `options.form` 存在时自动设置的请求头：

| 差异项 | lx-music | 当前代码 | 修复 |
|--------|----------|---------|------|
| User-Agent | `...AppleWebKit/537.36 (KHTML, like Gecko) Chrome/...` | `...AppleWebKit/537.36 Chrome/...`（缺少 KHTML） | 补全 |
| Accept | `application/json` | 未设置 | 添加 |
| origin | 小写 `origin` | 大写 `Origin` | 改为小写避免某些边缘服务端敏感 |

### 2. eapiRequest 诊断日志

在 `eapiRequest` 中加入三级日志：
- **成功路径**：记录 `responseCode` 和 body 的 code/keys/长度
- **失败路径**：记录 `responseCode`、`result` 类型、`result` 前 200 字符（截断防止日志爆炸）
- **异常路径**：记录异常类型和 message

### 3. 搜索未加密兜底

`search()` 中 eapi 失败后自动回退：
1. 先尝试 eapi `/api/search/song/list/page`（有封面，数据全）
2. eapi 失败（`body === null` 或 `code !== 200`）则回退到 `https://music.163.com/api/search/get`（旧版未加密 GET，无封面但搜索结果可用）
3. 回退路径解析旧版数据结构：`result.songs[]` 中的 `name/artists/album.name/album.picUrl/al.picUrl/duration/privilege`

### 4. hotSearch 精简

`hotSearch()` 维持 eapi 加密路径 + 诊断日志，失败返回空数组，触发 `SearchViewModel` 已有兜底链：
```
空数组 → 尝试其他平台 → MusicApiService.defaultHotSearches()
```

### 性能分析
- 正常路径（eapi 可用）：搜索 1 次 POST，热搜 1 次 POST
- 降级路径（eapi 不可用）：搜索 2 次请求（eapi POST + 兜底 GET），热搜 0 次请求（直接默认列表）
- 封面在 eapi 路径直接返回，无需额外请求

### 目录结构
```
features/search/src/main/ets/service/platform/
└── WyMusicApi.ets  # [MODIFY] 主要修改
    # eapiRequest() — 添加完整诊断日志（responseCode/result类型/body前200字符）
    # search() — 增加旧版未加密 API 兜底路径，eapi 失败时回退到 /api/search/get
    # 新增 parseLegacyResult() — 解析旧版 API 的 songs[] 结构
    # hotSearch() — 保留 eapi 路径 + 诊断日志
    # 请求头修复 — User-Agent 补全、Accept、origin 小写
```

## 实现细节

### eapiRequest 诊断日志设计
```
成功: Logger.info(TAG, `eapiRequest: path=${path}, httpCode=200, bodyCode=${body['code']}, hasData=${!!body['data']}`)
失败: Logger.warn(TAG, `eapiRequest: path=${path}, httpCode=${resp.responseCode}, resultType=${typeof resp.result}, resultLen=${len}, resultPreview=${preview}`)
异常: Logger.error(TAG, `eapiRequest: path=${path}, errType=${name}, errMsg=${message}`)
```

### 旧版 API 数据解析
旧版 `https://music.163.com/api/search/get` 返回结构：
```
{ code: 200, result: { songs: [{ name, id, artists: [{name}], album: {name, picUrl}, al: {picUrl}, duration, privilege: {maxbr, maxBrLevel} }] } }
```
与新版 eapi 的 `baseInfo.simpleSongData` 嵌套结构完全不同，需要独立解析方法。

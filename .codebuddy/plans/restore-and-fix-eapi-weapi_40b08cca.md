---
name: restore-and-fix-eapi-weapi
overview: 基于加密正确验证结果，恢复 weapi/eapi 代码并加 HTTP body 诊断日志，定位 form body 构造差异。
todos:
  - id: restore-crypto
    content: 恢复 MusicApiUtils.ets 中完整 eapi/weapi 加密代码（MD5、AES-ECB、AES-CBC、RSA-1024-NoPadding）及 WeapiResult 接口导出
    status: completed
  - id: restore-wyapi-body
    content: 恢复 WyMusicApi.ets 中 eapiRequest/weapiRequest/getSongDetail/extractCoverFromDetail，extraData 用 ArrayBuffer，weapiRequest 中加入 formBody 字符串/字节长度/hex 预览诊断日志
    status: completed
    dependencies:
      - restore-crypto
  - id: restore-wyapi-search
    content: 恢复 WyMusicApi.ets 中 search() 的 fillMissingCovers 封面补全、hotSearch() 的 eapi 调用、getPlayUrl() 的 getSongDetail 封面获取
    status: completed
    dependencies:
      - restore-wyapi-body
  - id: verify-lint
    content: 验证两个文件 0 lint 错误，确认编译通过
    status: completed
    dependencies:
      - restore-wyapi-search
---

## 用户需求
恢复网易云 eapi/weapi 加密 API，解决 HarmonyOS 上 httpCode=200 但 resultLen=0（空响应体）的问题。加密层已验证正确，问题锁定在 HTTP body 传递方式。

## 核心功能
- 恢复 weapi 歌曲详情获取（含封面 `al.picUrl`）
- 恢复 eapi 搜索/热搜
- 用 ArrayBuffer 传递 POST body，绕过 HarmonyOS http 模块可能对 string extraData 的二次编码
- 加入 formBody 字节级诊断日志定位根因


## 根因假设
lx-music 用标准 web `fetch()` API 传递 `body: "params=...&encSecKey=..."`（string 类型），浏览器自动设置 Content-Length。HarmonyOS `http.createHttp().request()` 的 `extraData` 参数当传入 string 时，框架可能对 form-urlencoded 内容做额外 URL 编码（如将 `=` 编为 `%3D`），导致服务端无法解析 form 参数键值对。

**验证策略**：用 `ArrayBuffer` 传递 body（跳过框架对 string 的处理），同时在日志中打印 body 的完整字符串和 hex 前 100 字节，验证 body 是否被篡改。

## 修改文件

### 1. MusicApiUtils.ets — 恢复完整加密代码
从当前 74 行恢复为 ~180 行，包含：
- eapi 加密：`eapiEncrypt(url, data)` — AES-128-ECB-NoPadding + MD5
- weapi 加密：`weapiEncrypt(data)` — 双 AES-128-CBC-PKCS7 + RSA-1024-NoPadding
- `WeapiResult` 接口导出
- 所有加密辅助函数（zeroPad, md5Hex, aesEcb, aesCbc, rsaEnc, generateRandomString, pemToDer, bytesToLowerHex）
- 保留已有接口和工具函数

### 2. WyMusicApi.ets — 恢复加密请求层 + 诊断日志
从当前 122 行恢复为 ~250 行：

**新增/恢复方法：**
- `eapiRequest(path, data)` — 用 `buffer.from(formBody, 'utf-8')` 构建 `Uint8Array`，取 `.buffer` 作为 `extraData`，设 `Content-Length` 头
- `weapiRequest(path, data)` — 同上，加入 formBody 诊断日志（完整字符串、字节长度、hex 预览）
- `getSongDetail(songId)` — 调用 weapiRequest('v3/song/detail', ...)
- `extractCoverFromDetail(detail)` — 提取 `detail.al.picUrl`

**修改方法：**
- `search()` — 先走 legacy API，结果有封面缺失时调 `fillMissingCovers` 补全
- `hotSearch()` — 恢复 eapiRequest 调用
- `getPlayUrl()` — 恢复并行获取歌词 + getSongDetail 封面

**诊断日志格式（weapiRequest 中）：**
```
WEAPI_BODY: formBodyStr="params=...&encSecKey=..."
WEAPI_BODY: byteLen=XXX, hexPreview="ABCD1234..."
WEAPI_RESP: httpCode=XXX, resultLen=XXX
```

### 3. 性能分析
- 搜索：1 次 legacy GET + 按需 N 次 weapi POST（仅封面缺失的歌曲）
- 播放：2 次请求（GET 播放URL + weapi POST 歌曲详情，并行）
- 热搜：1 次 eapi POST
- 封面在 weapi 成功后直接从 `al.picUrl` 提取，无额外请求


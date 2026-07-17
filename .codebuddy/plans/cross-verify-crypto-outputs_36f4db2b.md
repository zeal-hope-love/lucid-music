---
name: cross-verify-crypto-outputs
overview: 交叉验证 HarmonyOS weapi/eapi 加密输出 vs Node.js 标准结果，尝试 HTTP POST body 的 ArrayBuffer 替代方案，修复 200 空响应问题。
todos:
  - id: add-crypto-logs
    content: 在 MusicApiUtils.ets 的 eapiEncrypt 和 weapiEncrypt 末尾添加 Logger.info，输出 params/encSecKey 前 100 字符作为加密对照
    status: completed
  - id: fix-eapi-arraybuffer
    content: 修改 eapiRequest：extraData 从 string 改为 ArrayBuffer，显式加 Content-Length 头
    status: completed
    dependencies:
      - add-crypto-logs
  - id: fix-weapi-arraybuffer
    content: 修改 weapiRequest：extraData 从 string 改为 ArrayBuffer，显式加 Content-Length 头
    status: completed
    dependencies:
      - add-crypto-logs
---

## 问题
eapi (`interface.music.163.com/eapi/batch`) 和 weapi (`music.163.com/weapi/v3/song/detail`) 两个独立 POST 端点均返回 `httpCode=200` 但 `resultLen=0`（空响应体）。

## 根因分析
两种完全不同的加密算法（AES-ECB vs AES-CBCx2+RSA）、两个独立的服务域名、完全相同的症状 → **问题不在加密算法**，而在 **HarmonyOS `http.createHttp().request()` 以 `extraData: string` 发送 form-urlencoded POST body 时，body 未被服务端正确接收**。

## 修复目标
1. 在加密函数末尾输出 params 前 100 字符用于与 Node.js 参考值对照
2. 将 `extraData` 从 string 改为 ArrayBuffer 类型传递 POST body
3. 显式设置 Content-Length 头

## 技术方案

### 1. 加密对照日志 (MusicApiUtils.ets)

在 `eapiEncrypt` 和 `weapiEncrypt` 返回前，用 `Logger.info` 输出 params 前 100 字符。因为 Node.js 已有可复现的参考输出（来自 lx-music 的 cryptoTest），可直接对照验证加密正确性。

**eapi 固定输入对照：** 取热搜请求为例，data=`{id:'HOT_SEARCH_SONG#@#'}`, url=`/api/search/chart/detail`，输出前 100 字符应与 Node.js 计算结果一致。

**weapi 对照：** 取 songId=123456 的 song detail 请求，输出 params/encSecKey 前 100 字符。

### 2. POST body 改为 ArrayBuffer (WyMusicApi.ets)

当前模式（返回空响应）：
```typescript
extraData: `params=${params}`  // string 类型
```

改为 ArrayBuffer：
```typescript
// 构建 form body string → Uint8Array → ArrayBuffer
const formBody = `params=${params}`
const bodyBytes = new Uint8Array(buffer.from(formBody, 'utf-8').buffer)
// 显式 Content-Length
const headers = {
  'Content-Type': 'application/x-www-form-urlencoded',
  'Content-Length': String(bodyBytes.length),
  // ...
}
const resp = await http.createHttp().request(url, {
  method: http.RequestMethod.POST,
  header: headers,
  extraData: bodyBytes.buffer,  // ArrayBuffer 类型
  // ...
})
```

### 3. 回退方案

如果 ArrayBuffer 仍不行，备选方案：
- 尝试将 form 参数拼到 URL query string（?params=...）
- 尝试 JSON body 包装（`{params: "..."}` + `Content-Type: application/json`），看服务端是否兼容

### 涉及文件
- `MusicApiUtils.ets` — eapiEncrypt/weapiEncrypt 末尾加 Logger.info(params前100字符)
- `WyMusicApi.ets` — eapiRequest/weapiRequest 中 extraData string → ArrayBuffer，加 Content-Length

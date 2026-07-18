---
name: fix-eapi-http-to-https
overview: 将 eapiRequest 中的 HTTP 明文 URL 改为 HTTPS，解决 HarmonyOS 阻止明文流量导致热点搜索失败的问题。
todos:
  - id: fix-eapi-url
    content: WyMusicApi.ets 第 193 行：将 eapiRequest URL 从 http 改为 https
    status: completed
  - id: verify-build
    content: 编译验证，运行后确认热搜功能正常
    status: completed
    dependencies:
      - fix-eapi-url
---

## 问题
eapi 请求 `hotSearch` 使用 HTTP 明文协议 `http://interface.music.163.com/eapi/batch`，HarmonyOS API 26 默认阻止 HTTP 明文流量，导致热搜功能失败。

## 修复
将 eapiRequest 的 URL 从 `http://` 改为 `https://`，一行修改。如果 NetEase 服务端不支持 HTTPS 访问该端点，则回退到在 `module.json5` 中添加 `cleartextTraffic` 白名单配置。

## 修改内容

### 文件：`features/search/src/main/ets/service/platform/WyMusicApi.ets`
- **第 193 行**：URL 从 `http://interface.music.163.com/eapi/batch` 改为 `https://interface.music.163.com/eapi/batch`

### 回退方案（若 HTTPS 不可用）
在 `entry/src/main/module.json5` 的 `module` 对象中添加：
```json5
"network": {
  "securityConfig": {
    "domainSwitch": {}
  }
}
```
或更精确地为 `interface.music.163.com` 配置 cleartext 白名单。

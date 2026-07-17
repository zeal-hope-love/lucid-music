---
name: fix-qq-music-url-protocol
overview: 修复 TxMusicApi.extractUrl() 生成的音频URL缺少https://协议前缀导致AVPlayer无法播放的问题
todos:
  - id: fix-extract-url
    content: 修复 TxMusicApi.ets extractUrl() 第127-128行：修正 fallback 拼接逻辑 + 补充 https:// 协议前缀
    status: completed
---

## 用户需求
修复 QQ 音乐源播放无音频的问题。根因已通过日志确认。

## 诊断结果
- JSVM 脚本 `scriptInited=false`，走直接 API 兜底路径
- API 获取 URL 成功（length=410），但格式为 `C400003mAan70zUy5O.m4a?guid=...`，缺少 `https://` 协议前缀
- `AudioPlayerController.loadAndPlay()` 中 url 不满足 `startsWith('http://') || startsWith('https://')`，被当成 rawfile 本地资源
- `resourceManager.getRawFd()` 失败 `Failed to get descriptor`，15 秒后超时

## 根因
`TxMusicApi.ets` 第 127 行 `extractUrl()` 拼接逻辑有问题：
1. `sip[0]` 不含协议前缀，且 `${server}qqmusic.qq.com/` 这个 fallback 拼接有误（两个域名拼在一起）
2. 最终返回的 URL 没有 `http://` 或 `https://`


## 技术方案

### 修改范围
仅修改 `features/search/src/main/ets/service/platform/TxMusicApi.ets` 的 `extractUrl()` 方法第 127-128 行。

### 修复策略
1. 修正 fallback 逻辑：移除错误的 `${server}qqmusic.qq.com/` 拼接，改为直接用 `server`（即 `sip[0]` 本身）
2. 确保最终 URL 带有 `https://` 协议前缀：如果 `server`（或 `testfile2g`）不含 `http://`/`https://`，自动补充 `https://`
3. 将 `http://` 统一替换为 `https://`（延续之前的 HTTPS 升级约定）

### 修改前
```typescript
const server = sip[0] as string; const prefix = testfile2g || `${server}qqmusic.qq.com/`
return prefix + purl
```

### 修改后
```typescript
const server = sip[0] as string
let prefix: string = testfile2g || server
if (!prefix.startsWith('http://') && !prefix.startsWith('https://')) {
  prefix = 'https://' + prefix
}
let url = prefix + purl
url = url.replace('http://', 'https://')
return url
```

### 关键设计决策
- **用 `server` 而非 `${server}qqmusic.qq.com/`**：`sip[0]` 本身已经是正确的服务器域名，不需要拼接额外的后缀
- **防御性协议补充**：无论 `testfile2g` 还是 `sip[0]` 是否有协议前缀，都确保最终 URL 以 `https://` 开头
- **HTTP→HTTPS 统一替换**：保持项目 HTTPS 升级约定，同时兼容 `testfile2g` 可能包含 `http://` 的情况


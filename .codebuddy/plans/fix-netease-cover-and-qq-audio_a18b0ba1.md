---
name: fix-netease-cover-and-qq-audio
overview: 修复网易云封面加载和 QQ 音频播放：对齐 lx-music-mobile 的 EAPI 加密实现，对齐 MusicHome 的 QQ 音频获取，增加封面加载失败时的兜底显示
todos:
  - id: fix-eapi-base64
    content: MusicApiUtils.ets：eapiEncrypt 中 encodeToString 改为 encodeToStringSync，对齐 lx-music 同步 base64
    status: completed
  - id: fix-qq-https
    content: TxMusicApi.ets：extractUrl 去除 replace(http→https)，对齐 MusicHome 原始 URL 格式
    status: completed
  - id: fix-cover-fallback-musicinfo
    content: MusicInfoComponent.ets：coverUrl 分支 Image 加 onError 回调，失败时回退到 ic_music_symbol 本地图
    status: completed
  - id: fix-cover-fallback-lyrics
    content: LyricsComponent.ets：SM 分支 coverUrl Image 加 onError 回调，失败时回退到 ic_music_symbol 本地图
    status: completed
---

## 用户需求
1. 网易云封面在播放详细页不显示，临时兜底图（ic_music_symbol）也不出现
2. QQ 音乐音频不可用（获取播放地址后无法播放），参考 MusicHome 项目中可用的 QQ 实现

## 根因分析

### 网易云封面
EAPI 加密与 lx-music-mobile 对比已对齐（message → md5 → plain → base64 → AES-ECB-NoPadding → hex），加密逻辑本身无差异。但 `util.Base64Helper.encodeToString()` 使用异步 await，而 lx-music 的 `Buffer.toString('base64')` 是同步的。在 HarmonyOS ArkTS 中应改用 `encodeToStringSync()` 避免异步时序问题。此外，MusicInfoComponent 和 LyricsComponent 的远程封面 Image 组件缺少 onError 回调，封面 HTTP 加载失败时没有回退到本地 ic_music_symbol。

### QQ 音频
与 MusicHome 逐行对比发现唯一差异：我们的 `extractUrl` 强制对返回 URL 做了 `replace('http://', 'https://')`，而 MusicHome 直接返回原始 URL。QQ 部分 CDN 节点不支持 HTTPS，升级后导致 404 或连接超时，AVPlayer 无法加载音频流。


## 技术栈
- HarmonyOS ArkUI (TypeScript)
- @kit.NetworkKit (http)
- @kit.CryptoArchitectureKit (MD5, AES)
- @kit.ArkTS (util.Base64Helper)

## 实现方案

### 修改文件：4 个

| 文件 | 改动 | 原因 |
|------|------|------|
| `MusicApiUtils.ets` | `encodeToString` → `encodeToStringSync` | 对齐 lx-music 同步 base64，消除异步时序差异 |
| `TxMusicApi.ets` | `extractUrl` 去除 `replace('http://', 'https://')` | 对齐 MusicHome，QQ CDN 不支持 HTTPS |
| `MusicInfoComponent.ets` | 封面 Image 加 `onError` 兜底到 `ic_music_symbol` | 远程封面失败时显示本地默认图 |
| `LyricsComponent.ets` | 封面 Image 加 `onError` 兜底到 `ic_music_symbol` | 同上 |

### 修改详情

**1. MusicApiUtils.ets — eapiEncrypt**
```
// 旧
const plainBase64 = await helper.encodeToString(new Uint8Array(buffer.from(plain, 'utf-8').buffer))
// 新
const plainBase64 = helper.encodeToStringSync(new Uint8Array(buffer.from(plain, 'utf-8').buffer))
```

**2. TxMusicApi.ets — extractUrl**
```
// 旧
return rawUrl.replace('http://', 'https://')
// 新
return rawUrl
```
保留 testfile2g fallback 和 prefix 拼接逻辑不变。

**3. MusicInfoComponent.ets — CoverInfo builder**
在 coverUrl 分支的 Image 上增加 `onError` 回调，加载失败时切换显示 `$r('app.media.ic_music_symbol')`：
```
Image(this.songList[this.selectIndex].coverUrl)
  .onError(() => { this.coverLoadFailed = true })
// 配合 @State coverLoadFailed 控制条件渲染
```

**4. LyricsComponent.ets — SM 分支封面**
同 MusicInfoComponent，在 coverUrl 分支 Image 加 onError 兜底。

### 性能与风险
- `encodeToStringSync` 同步调用，EAPI 加密不再被 await 阻塞，加快 cover 获取
- QQ URL 不升级 HTTPS 可能被 AVPlayer 拒绝（已知问题），但 MusicHome 已验证原始 URL 可播放
- onError 回调仅在封面加载失败时触发，不影响正常渲染性能


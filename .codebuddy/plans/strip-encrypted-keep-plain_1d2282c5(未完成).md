---
name: strip-encrypted-keep-plain
overview: 清理失败加密代码，精简 WyMusicApi 为仅未加密 API，快速恢复正常功能。封面暂时留空。
todos:
  - id: cleanup-musicapi-utils
    content: "MusicApiUtils.ets: 删除 import{http,cryptoFramework,buffer}、eapi 全部加密函数、weapi 全部加密函数(~100行)，保留纯接口+工具函数(~80行)"
    status: pending
  - id: cleanup-wymusicapi
    content: "WyMusicApi.ets: 删除 import{buffer,WeapiResult,eapiEncrypt,weapiEncrypt}、eapiRequest/weapiRequest/getSongDetail/fillMissingCovers/batchFetchCoversDirect/extractCoverFromDetail/mapList，简化 search/getPlayUrl/hotSearch"
    status: pending
    dependencies:
      - cleanup-musicapi-utils
  - id: verify-lint
    content: 验证两个文件 0 lint 错误
    status: pending
    dependencies:
      - cleanup-wymusicapi
---

## 目标
删除 MusicApiUtils.ets 和 WyMusicApi.ets 中所有 eapi/weapi 加密代码，精简为纯未加密 API 实现。

## 背景
经过多轮测试验证：HarmonyOS 上 eapi 和 weapi 均返回 httpCode=200 但 resultLen=0，string/ArrayBuffer 均无改善。此平台无法使用加密 API。

## 可用 API
- 搜索: https://music.163.com/api/search/get
- 播放URL: https://music.163.com/api/song/enhance/player/url
- 歌词: https://music.163.com/api/song/lyric
- 联想: https://music.163.com/api/search/suggest/web

## 技术方案

### MusicApiUtils.ets（236行→~80行）
**删除全部：**
- `import { http } from '@kit.NetworkKit'`
- `import { cryptoFramework } from '@kit.CryptoArchitectureKit'`
- `import { buffer } from '@kit.ArkTS'`（保留 `import { util }`）
- EAPI_KEY 常量、zeroPad、md5Hex、aesEcbEncryptBase64、eapiEncrypt
- 所有 weapi 代码：WEAPI_PRESET_KEY/WEAPI_IV/WEAPI_RSA_PUBLIC_PEM 常量、generateRandomString、pemToDer、aesCbcEncryptBase64、rsaEncryptNoPadding、bytesToLowerHex、bytesToUpperHex、WeapiResult 接口、weapiEncrypt

**保留：**
- TAG、QQVkeyParam/QQVkeyModule/QQVkeyBody、PlayUrlResult
- QQHotKeyComm/QQHotKeyParam/QQHotKeyModule/QQHotKeyBody
- platformToId、formatDuration、decodeBase64Lyric

### WyMusicApi.ets（341行→~120行）
**删除全部：**
- `import { buffer } from '@kit.ArkTS'`
- `import { WeapiResult, eapiEncrypt, weapiEncrypt }`（保留 TAG/PlayUrlResult/formatDuration）
- search() 中的 eapi 兜底分支
- mapList() 整个方法
- fillMissingCovers() 整个方法
- batchFetchCoversDirect() 整个方法
- eapiRequest() 整个方法
- weapiRequest() 整个方法
- getSongDetail() 整个方法
- extractCoverFromDetail() 整个方法

**修改：**
- search() → 直接调用 searchLegacy()
- hotSearch() → 直接 return []（触发 SearchViewModel 默认兜底）
- getPlayUrl() → 删除 Promise.all 中的 getSongDetail，只并行获取歌词

**保留不变：**
- searchLegacy() / parseLegacySongs()
- suggest()
- getLyrics()

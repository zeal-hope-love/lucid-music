---
name: fix-search-quality-v2
overview: 从根本上修复音质标签：网易云切换为 eapi 主路径（含 privilege 数据），QQ音乐实现 zzcSign 签名并换用 DoSearchForQQMusicMobile API（含 file.size_hires/size_flac/size_320mp3）。
todos:
  - id: add-zzcsign
    content: 在 MusicApiUtils.ets 中新增 sha1Hex 和 zzcSign 函数并导出
    status: completed
  - id: swap-wy-priority
    content: 修改 WyMusicApi.ets 的 search 方法：eapi 主路径 + legacy 兜底，移除旧的优先级注释
    status: completed
  - id: rewrite-tx-search
    content: 重写 TxMusicApi.ets：search 方法切换为 zzcSign + DoSearchForQQMusicMobile API，mapList 适配新响应格式，删除 resolveQuality，确保 rawFields 兼容 getPlayUrl
    status: completed
    dependencies:
      - add-zzcsign
---

## 用户需求
修复搜索结果中音质标签全部显示错误的问题：
- **网易云音乐**：所有搜索结果都标注为"标准"，实际应区分 24bit（Hi-Res）、SQ（无损）、HQ（高品质）、标准
- **QQ音乐**：只有"HQ"和"标准"两种标签，缺少"SQ"和"24bit"

## 根因（对比 lx-music-mobile 确认）
| 维度 | lucid_music（当前，错误） | lx-music-mobile（专案参考，正确） |
|------|----------------------|-------------------------------|
| 网易云搜索API | legacy `music.163.com/api/search/get` — **不返回任何音质数据** | eapi `interface.music.163.com/eapi/batch` + `/api/search/song/list/page` — 返回 `privilege.maxbr`/`maxBrLevel` |
| QQ搜索API | `c.y.qq.com/soso/fcgi-bin/client_search_cp` — 仅返回 `size320` | zzcSign 签名 `u.y.qq.com/cgi-bin/musics.fcg` + `DoSearchForQQMusicMobile` — 返回 `file.size_hires`/`size_flac`/`size_320mp3` |

## 核心修改
1. **网易云**：交换搜索API优先级 —— eapi 做主路径、legacy 做兜底，eapi 返回自带 `privilege` 音质数据
2. **QQ音乐**：实现 zzcSign 签名算法，切换为新的搜索 API，解析含完整音质字段的响应格式
3. **MusicApiUtils**：新增 SHA1 和 zzcSign 工具函数


## 技术方案

### 1. MusicApiUtils.ets — 新增 SHA1 + zzcSign

**sha1Hex**：使用项目已有的 `@kit.CryptoArchitectureKit` 的 `cryptoFramework.createMd('SHA1')`，参照现有 `md5Hex` 函数模式实现。

**zzcSign**：完全对齐 lx-music-mobile `crypto.js` 算法：
```
输入 text → sha1Hex(text) → 40位小写hex
PART1: hash[23,14,6,36,16,40,7,19] → 8字符拼接
PART2: hash[16,1,32,12,19,27,8,5] → 8字符拼接  
SCRAMBLE: [89,39,179,150,218,82,58,252,177,52,186,123,120,64,242,133,143,161,121,179]
part3Bytes: SCRAMBLE[i] XOR parseInt(hash[i*2..i*2+2], 16)
b64: base64(part3Bytes) 去除 [/+=]
result: ("zzc" + PART1 + b64 + PART2).toLowerCase()
```
导入 `@kit.ArkTS` 的 `util.Base64Helper` 做 Base64 编码。

### 2. WyMusicApi.ets — 交换搜索优先级

**search() 方法改写**：
```
主路径: eapiRequest('/api/search/song/list/page', ...) → mapList()
兜底: searchLegacy() → parseLegacySongs()
```
eapi 响应格式已是 `data.resources[].baseInfo.simpleSongData`，`mapList` 逻辑无需改动，其中的 `privilege.maxbr`/`maxBrLevel` 会正常工作产生正确的音质标签。保留 `resolveQuality` 方法不变。

### 3. TxMusicApi.ets — 切换搜索 API + 重写解析

**search() 方法改写**：
- 构建请求体（对齐 lx-music）：`{ comm: { ct:'11', cv:'14090508', v:'14090508', tmeAppID:'qqmusic', ... }, req: { module:'music.search.SearchCgiService', method:'DoSearchForQQMusicMobile', param: { search_type:0, searchid, query, page_num, num_per_page, ... } } }`
- POST `https://u.y.qq.com/cgi-bin/musics.fcg?sign={zzcSign(JSON.stringify(body))}`
- Header: `User-Agent: QQMusic 14090508(android 12)`
- 解析响应：`body.req.data.body.item_song[]` 和 `body.req.data.meta.estimate_sum`

**mapList() 方法重写**（新响应格式）：
```typescript
// 新字段映射：
title       ← item.title
singer      ← item.singer[].name.join('/')
album       ← item.album.name
songId      ← item.mid（同时存 rawFields.songmid）
duration    ← formatDuration(item.interval)
coverUrl    ← album.mid ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${album.mid}.jpg`
quality     ← file.size_hires>0?'24bit' : file.size_flac>0?'SQ' : file.size_320mp3>0?'HQ':'标准'
rawFields   ← { songmid: item.mid, albummid: item.album?.mid }（兼容 getPlayUrl）
```

**删除** `resolveQuality()` 方法（新 API 直接以 `file.size_*` 为主路径，不再需要 fallback）。

**保持兼容性**：`rawFields` 必须含 `songmid` 和 `albummid`，确保 `getPlayUrl()` / `getLyrics()` / `suggest()` / `hotSearch()` 等现有方法不受影响。


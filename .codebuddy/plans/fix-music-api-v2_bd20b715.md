---
name: fix-music-api-v2
overview: 重写 MusicApiService 中酷狗封面、QQ音频/歌词、网易云封面的 API 实现，对齐 lx-mobile 已验证的端点和参数
todos:
  - id: fix-kg-pic
    content: 实现酷狗专用封面 API getKugouPic（media.store.kugou.com/v1/get_res_privilege），在 getKugouPlayUrl 成功后调用，替换失效的 data.img
    status: completed
  - id: fix-qq-vkey
    content: 回退 QQ vkey 模块名为 vkey.GetVkeyServer，保留 getQQSongDetail 获取的 strMediaMid 作为 songmid 参数
    status: completed
  - id: fix-qq-lyrics
    content: QQ 歌词 API 更换 UA 为 lx-mobile 默认值
    status: completed
  - id: fix-wy-cover
    content: 修复网易云封面：新增从 player/url 接口提取封面，或改用备选公开接口
    status: completed
  - id: unify-ua
    content: 统一所有平台 UA 为 lx-mobile 默认值
    status: completed
---

## 问题
上一轮修复后四个问题仍然存在：
1. 酷狗封面永远是同一张图（`getKugouPlayUrl` 的 `data.img` 是固定占位图，非专辑封面）
2. QQ 音频无法获取（上次将 vkey 模块名改为 `music.vkey.GetVkey` 是错误推测）
3. QQ 歌词获取不到（端点与 lx-mobile 一致，可能 UA/Headers 被拒绝）
4. 网易云封面获取不到（公开 `/api/song/detail` 可能已废弃）

## 修复目标
- 酷狗：实现 lx-mobile 的专用封面 API `POST media.store.kugou.com/v1/get_res_privilege`
- QQ 音频：回退 vkey 模块名为 `vkey.GetVkeyServer`，保留歌曲详情获取 strMediaMid 作备选
- QQ 歌词：更换 UA 为 lx-mobile 默认值，修复解码
- 网易云封面：尝试替代公开接口或从增强播放器接口提取

## 修改文件
仅 `features/search/src/main/ets/service/MusicApiService.ets`，约 4 处改动。

## 1. 酷狗封面修复
新增 `getKugouPic` 方法，对齐 lx-mobile `kg/pic.js`：
- **API**: `POST http://media.store.kugou.com/v1/get_res_privilege`
- **Headers**: `KG-RC: 1`, `KG-THash: expand_search_manager.cpp:852736169:451`, `User-Agent: KuGou2012-9020-ExpandSearchManager`
- **Body**: `appid:1001, area_code:1, behavior:'play', clientver:'9020', need_hash_offset:1, relate:1, resource:[{album_audio_id, album_id, hash, id:0, name, type:'audio'}], token:'', userid:2626431536, vip:1`
- **响应**: `data[0].info.image` → 替换 `{size}` 为 `imgsize[0]` → 最终封面 URL

在 `getKugouPlayUrl` 成功获取音频后并行调用 `getKugouPic` 取封面，回退链：pic API → 原 `data.img` → 空。

## 2. QQ 音频修复
回退 vkey 模块名为原始值 `vkey.GetVkeyServer`（非 `music.vkey.GetVkey`）。保留 `getQQSongDetail` 获取 `strMediaMid` 作为备选参数。vkey 请求体恢复为原始结构：
```
module: 'vkey.GetVkeyServer', method: 'CgiGetVkey'
param: { guid, songmid: [strMediaMid], songtype: [0], uin: '0', loginflag: 1, platform: '20' }
```
若 strMediaMid 为空则回退使用搜索结果的 songmid。

## 3. QQ 歌词修复
- 更换 `User-Agent` 为 lx-mobile 默认：`Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36`
- 歌词解码保持现有 `buffer.from + TextDecoder('utf-8')` 方式（经核查与 lx-mobile 的 b64DecodeUnicode 等效）

## 4. 网易云封面修复
公开 `/api/song/detail` 可能已废弃。改为从 `getNeteasePlayUrl` 的主 API 响应中提取封面：
- `music.163.com/api/song/enhance/player/url` 的 base URL 拼接：`http://p2.music.126.net/{picId}/{picId}.jpg`
- 或尝试 `music.163.com/api/song/detail?ids=` 的无加密版本
- 回退：从搜索阶段保持的 `album.picUrl`（若 API 有返回）

## 5. 全部 API 统一 UA
对所有平台的 HTTP 请求统一使用 lx-mobile 的默认 User-Agent：
`Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36`

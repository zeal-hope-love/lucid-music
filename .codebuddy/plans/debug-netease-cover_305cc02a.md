---
name: debug-netease-cover
overview: 为网易云封面添加诊断日志，根据日志结果修复：若搜索无封面则用 eapi/wapi 加密接口获取，若有则修复数据流覆盖问题
todos:
  - id: add-logs
    content: 在 mapNeteaseList、playSong、PlaybackIntentDispatcher 三处加日志打印封面URL定位数据流断点
    status: completed
  - id: eapi-cover
    content: 扩展 EapiData 为 Record
    status: completed
---

## 需求
网易云音乐封面仍未实现，lx-music 能正常抓取。需要：
1. 加日志定位封面数据流断点
2. 按 lx-mobile 方案用 eapi 加密 API 兜底获取封面

## 核心功能
- 在搜索映射、播放触发、意图分发三处加日志，打印封面 URL
- 扩展 eapiEncrypt 支持任意字段，新增 getNeteaseCoverViaEapi 方法
- 在 getNeteasePlayUrl 中调用 eapi 封面兜底


## 修改文件
仅 `features/search/src/main/ets/service/MusicApiService.ets`

## 修改方案

### 1. 日志注入（三处）

**mapNeteaseList（第422行后）**：
```
Logger.info(TAG, `wy map: name=${result.title}, album=${!!album}, albumCover=${albumCover.substring(0,50)}, coverUrl=${result.coverUrl.substring(0,50)}`)
```
目的：确认搜索 API 是否返回 `album.picUrl`

**playSong（SearchResultViewModel.ets 第71行后）**：
```
Logger.info(`${TAG}: remoteSongCover set from item: ${(item.coverUrl || item.cover).substring(0, 50)}`)
```
目的：确认 `remoteSongCover` 初始值

**dispatchShellPlaybackIntent（PlaybackIntentDispatcher.ets 第34行后）**：
```
Logger.info(`${TAG}: songItem.coverUrl=${songItem.coverUrl.substring(0, 50)}`)
```
目的：确认 `songItem.coverUrl` 最终值

### 2. EAPI 封面获取

参考现有 `hotSearchNetease` 的 eapi 模式，新增 `getNeteaseCoverViaEapi`：

**扩展 EapiData**：改为 `Record<string, string>` 支持任意字段
**新增方法**：
```
POST http://interface.music.163.com/eapi/song/detail
params = eapiEncrypt('/api/song/detail', { id: songId })
extraData: `params=${params}`
响应: body.code===200 → body.songs[0].al.picUrl
```

### 3. getNeteasePlayUrl 调用

在现有 `getNeteaseLyrics` 之后增加：
```
const cover = await MusicApiService.getNeteaseCoverViaEapi(songId)
return { url, lyrics, cover }
```

## 数据流
```
搜索API album.picUrl → mapNeteaseList → coverUrl → playSong → remoteSongCover
                                         ↓（如果搜索为空）
                                    getNeteaseCoverViaEapi → eapiEncrypt → 封面URL
                                         ↓
                              dispatchShellPlaybackIntent → songItem.coverUrl → UI
```


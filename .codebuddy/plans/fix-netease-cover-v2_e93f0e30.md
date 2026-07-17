---
name: fix-netease-cover-v2
overview: 在搜索 API 和 EAPI 两处加更细粒度日志，查看 album 对象实际字段和 EAPI resp.result 是否为空，据此修复封面获取。
todos:
  - id: fix-maplist-cover
    content: mapList()：添加 item.al.picUrl 兜底来源 + 无封面时打印 album/al keys 定位字段名
    status: completed
  - id: fix-eapi-diag
    content: getCoverViaEapi()：增强 resp.result 诊断日志（打印 typeof）+ 失败时回退到直接 API
    status: completed
  - id: add-cover-direct
    content: 新增 getCoverDirect() 方法：用 /api/song/detail?ids= 无加密请求获取封面
    status: completed
---

## 问题定位
1. **搜索阶段**：`album.picUrl` 全空 — 网易云 API 可能把封面放到了 `item['al']['picUrl']`（歌曲级专辑对象），而不是 `item['album']['picUrl']`
2. **EAPI 阶段**：HTTP 200 但 `resp.result` 为空 — EAPI 加密请求失败，服务端返回空 body
3. **兜底缺失**：JSVM 路径命中跳过了直接 API 封面获取，导致封面完全丢失

## 修复内容
1. **mapList() 搜索封面**：添加 `item['al']['picUrl']` 兜底；无封面时打印 album/al 对象的 keys 定位字段名
2. **EAPI 诊断**：打印 `resp.result` 的类型和长度，定位为何为 falsy
3. **添加直接 API 封面兜底**：EAPI 失败时用 `/api/song/detail?ids=${songId}` 无加密请求获取封面


## 修改范围
仅修改 `features/search/src/main/ets/service/platform/WyMusicApi.ets`

## 修改方案

### 1. mapList() — 搜索封面双来源 + keys 诊断（第37-41行）
```
// 旧：只读 album['picUrl']
const rawPicUrl = album ? (album['picUrl'] as string) || '' : ''
```
改为：
```
// 新：优先 album.picUrl，回退 item.al.picUrl
let rawPicUrl = album ? (album['picUrl'] as string) || '' : ''
if (!rawPicUrl) {
  const al = item['al'] as Record<string, Object>
  rawPicUrl = al ? (al['picUrl'] as string) || '' : ''
  // 仍为空时打印 album/al 的 keys 定位字段名
  if (!rawPicUrl) {
    Logger.warn(TAG, `wy mapList no cover: album keys=[${album ? Object.keys(album).join(',') : 'null'}], al keys=[${al ? Object.keys(al).join(',') : 'null'}]`)
  }
}
```

### 2. getCoverViaEapi() — 增强 `resp.result` 诊断 + 添加直接 API 回退（第120-121行）
```
// 旧：仅打印 http code
if (resp.responseCode !== 200 || !resp.result) { Logger.warn(TAG, `wy eapi cover: http ${resp.responseCode}`); return '' }
```
改为：
```
if (resp.responseCode !== 200) { Logger.warn(TAG, `wy eapi cover: http ${resp.responseCode}`); return '' }
if (!resp.result) {
  Logger.warn(TAG, `wy eapi cover: result empty, typeof=${typeof resp.result}`)
  // 回退：直接 API 获取封面
  return WyMusicApi.getCoverDirect(songId)
}
```

### 3. 新增 getCoverDirect() — 无加密直接 API 兜底
```typescript
/** 直接 API 获取封面（无需 EAPI 加密） */
static async getCoverDirect(songId: string): Promise<string> {
  try {
    const url = `https://music.163.com/api/song/detail?ids=${songId}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
      connectTimeout: 6000, readTimeout: 6000
    })
    if (resp.responseCode !== 200 || !resp.result) { return '' }
    const body = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200 || !body['songs']) { return '' }
    const songs = body['songs'] as Record<string, Object>[]
    if (songs.length === 0) { return '' }
    const al = songs[0]['al'] as Record<string, Object>
    const cover = al ? (al['picUrl'] as string) || '' : ''
    Logger.info(TAG, `wy coverDirect: got=${cover.substring(0, 50)}`)
    return cover.replace('http://', 'https://')
  } catch (e) { return '' }
}
```

### 4. getPlayUrl() — 更新 EAPI 调用链路
`getCoverViaEapi` 内部已有回退逻辑，`getPlayUrl` 无需修改。

## 关键设计决策
- `item['al']` 是网易云 API 常见的歌曲级简化专辑对象，部分环境下 `album` 字段缺失但 `al` 存在
- `/api/song/detail?ids=` 是网易云未加密公开 API，无需 EAPI 加密，可作为稳定的兜底封面源
- EAPI 失败时静默回退到直接 API，不阻塞播放流程


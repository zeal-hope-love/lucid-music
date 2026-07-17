---
name: fix-netease-cover-album-api
overview: picId 拼接 URL 返回占位图，改为用 album.id 请求 /api/album/{albumId} 获取完整的 picUrl
todos:
  - id: search-await
    content: 第20行：search() 中 mapList 调用前加 await
    status: completed
  - id: maplist-async
    content: 第24行：mapList 签名改为 static async，返回类型改为 Promise<SearchResultItem[]>
    status: completed
  - id: collect-pending
    content: 第43-48行：删除 picId 拼接逻辑，改为收集 pendingCovers 数组（album.id + result 引用）
    status: completed
    dependencies:
      - maplist-async
  - id: batch-fetch
    content: 第61行 return 前：Promise.all 调用 fetchAlbumCover，结果回填 coverUrl/cover
    status: completed
    dependencies:
      - collect-pending
  - id: add-fetch-method
    content: 类末尾：新增 fetchAlbumCover(albumId) 静态异步方法
    status: completed
---

## 问题
1. `https://p1.music.126.net/${picId}.jpg` 返回灰色占位图，不是真实专辑封面
2. 占位图导致 MiniPlayerBar → MusicInfoComponent 的 `PLAYBACK_COVER_TRANSITION` 一镜到底几何转场失效

## 修复目标
将 picId 拼接 URL 替换为通过 `/api/album` 接口异步获取真实封面 URL（含 CDN hash 前缀），使封面图片显示为真实专辑封面，恢复一镜到底效果。


## 修改文件
仅 `features/search/src/main/ets/service/platform/WyMusicApi.ets`

## 改动1：第20行 search() 中 mapList 加 await
```
// 旧
return WyMusicApi.mapList((body['result'] as Record<string, Object>)['songs'] as object[] || [])

// 新
return await WyMusicApi.mapList((body['result'] as Record<string, Object>)['songs'] as object[] || [])
```

## 改动2：第24行 mapList 改为 async
```
// 旧
static mapList(rawList: object[]): SearchResultItem[] {

// 新
static async mapList(rawList: object[]): Promise<SearchResultItem[]> {
```

## 改动3：第43-48行 picId 拼接替换为异步 fetch + Promise.all
在 for 循环内，用数组收集需要异步获取封面的条目（album.id + result 引用），循环结束后统一 `Promise.all` 请求 `fetchAlbumCover`：

```
// 删除第43-48行的 if (!rawPicUrl && album) { picId 拼接 }
// 改为：收集需要异步获取封面的条目
const pendingCovers: Array<{ item: SearchResultItem; albumId: number }> = []
if (!rawPicUrl && album) {
  const albumId = album['id'] as number
  if (albumId) {
    pendingCovers.push({ item: result, albumId })
  }
}
```

在 for 循环结束后（第61行 return 之前），新增：
```
if (pendingCovers.length > 0) {
  Logger.info(TAG, `wy mapList: fetching ${pendingCovers.length} album covers via API`)
  const coverResults = await Promise.all(pendingCovers.map(p =>
    WyMusicApi.fetchAlbumCover(p.albumId).catch(_ => '')
  ))
  for (let i = 0; i < pendingCovers.length; i++) {
    const cover = coverResults[i]
    if (cover) {
      pendingCovers[i].item.coverUrl = cover
      pendingCovers[i].item.cover = cover
    }
  }
}
```

## 改动4：新增 fetchAlbumCover 方法（在 getCoverDirect 之后，类结束括号 `}` 之前）
```
/** 通过专辑 ID 获取真实封面 URL（含 CDN hash 前缀） */
static async fetchAlbumCover(albumId: number): Promise<string> {
  try {
    const url = `https://music.163.com/api/album/${albumId}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200 || !resp.result) { return '' }
    const body = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200 || !body['album']) { return '' }
    const album = body['album'] as Record<string, Object>
    const picUrl = (album['picUrl'] as string) || ''
    Logger.info(TAG, `wy fetchAlbumCover: albumId=${albumId}, picUrl=${picUrl.substring(0, 80)}`)
    return picUrl.replace('http://', 'https://')
  } catch (_) { return '' }
}
```

## 数据结构说明
- `album.keys` 已有 `id` 字段（确认来自诊断日志）
- 专辑 API 返回 `{ code: 200, album: { picUrl: "https://p1.music.126.net/<hash>/<id>.jpg" } }`
- `picUrl` 为含 hash 前缀的完整真实封面 URL

## 一镜到底恢复原理
`fetchAlbumCover` 返回的 `https://p1.music.126.net/<hash>/<id>.jpg` 是网易云 CDN 真实封面图。`SearchResultItem.coverUrl` → `intentState.remoteSongCover` → `songItem.coverUrl` → `MusicInfoComponent` 和 `MiniPlayerBar` 共用同一 URL 加载同一张图，`PLAYBACK_COVER_TRANSITION` geometryTransition 正常生效。


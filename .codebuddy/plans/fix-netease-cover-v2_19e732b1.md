---
name: fix-netease-cover-v2
overview: 为网易云添加封面获取：在 getNeteasePlayUrl 中新增公开 API 调用，获取 al.picUrl 作为 songItem 封面
todos:
  - id: get-netease-cover
    content: 在 getNeteasePlayUrl 中添加 getNeteaseCover 公开 API 调用，从 /api/song/detail 获取 al.picUrl 封面
    status: completed
---

## 问题
网易云音乐搜不到封面。MusicHome 项目也未实现此功能。

## 修复
在 `getNeteasePlayUrl` 中添加公开 API 调用获取封面：
- 调用 `GET https://music.163.com/api/song/detail?ids=[songId]`
- 从 `songs[0].al.picUrl` 提取封面 URL
- 无需 weapi 加密（lx-mobile 使用加密版 `/weapi/v3/song/detail`，ArkTS 改用公开端点的无加密版本）


## 修改范围
仅 `features/search/src/main/ets/service/MusicApiService.ets` 一处。

## 实现方案

### 新增 getNeteaseCover 方法
```typescript
private static async getNeteaseCover(songId: string): Promise<string> {
  try {
    const url = `https://music.163.com/api/song/detail?ids=[${songId}]`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
      connectTimeout: 6000, readTimeout: 6000
    })
    if (resp.responseCode !== 200 || !resp.result) return ''
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200 || !body['songs']) return ''
    const songs = body['songs'] as Record<string, Object>[]
    if (songs.length === 0) return ''
    const al = songs[0]['al'] as Record<string, Object>
    return al ? (al['picUrl'] as string) || '' : ''
  } catch (_) { return '' }
}
```

### 修改 getNeteasePlayUrl 返回
将 `return { url: playUrl, lyrics: lyrics, cover: '' }` 改为：
```typescript
const cover = await MusicApiService.getNeteaseCover(songId)
return { url: playUrl, lyrics: lyrics, cover: cover }
```


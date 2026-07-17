---
name: fix-netease-cover-v3
overview: 用 album.picId 拼接封面 URL + 修复 getCoverDirect 没有诊断日志的问题
todos:
  - id: fix-picid-cover
    content: WyMusicApi.mapList()：album.picUrl/al.picUrl 为空时用 album.picId 拼接 https://p2.music.126.net/${picId}.jpg
    status: completed
  - id: fix-direct-log
    content: WyMusicApi.getCoverDirect()：return '' 前加日志打印 http code 和 result 状态
    status: completed
---

## 问题定位
1. 搜索 API `album` 对象有 `picId` 字段但无 `picUrl`，`item['al']` 为 `null`
2. EAPI 返回空字符串 body（`typeof=string, isUndefined=false`），`getCoverDirect` 同样返回空 body 导致无日志
3. 封面三级来源全部失效，渲染时无封面

## 修复内容
- mapList() 增加 `album.picId` 拼接封面 URL：`https://p2.music.126.net/${picId}.jpg`
- getCoverDirect() 在 return '' 前加诊断日志打印 `resp.responseCode` 和 `resp.result` 状态


## 修改文件
仅 `features/search/src/main/ets/service/platform/WyMusicApi.ets`

## 修改点

### 1. mapList() 第37-46行：三级封面来源
将当前的 `album.picUrl → item.al.picUrl` 两级改为三级 `album.picUrl → item.al.picUrl → album.picId拼接`：

```typescript
let rawPicUrl = album ? (album['picUrl'] as string) || '' : ''
if (!rawPicUrl) {
  const al = item['al'] as Record<string, Object>
  rawPicUrl = al ? (al['picUrl'] as string) || '' : ''
}
if (!rawPicUrl) {
  const picId = album ? (album['picId'] as string) || (album['picId'] as number)?.toString() || '' : ''
  if (picId) {
    rawPicUrl = `https://p2.music.126.net/${picId}.jpg`
  }
}
if (!rawPicUrl) {
  Logger.warn(TAG, `wy mapList no cover: album keys=..., picId=..., al keys=...`)
}
```

### 2. getCoverDirect() 第155行：增加诊断日志
```typescript
if (resp.responseCode !== 200 || !resp.result) {
  Logger.warn(TAG, `wy coverDirect: http ${resp.responseCode}, resultEmpty=${!resp.result}, resultType=${typeof resp.result}`)
  return ''
}
```


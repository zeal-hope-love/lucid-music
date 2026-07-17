---
name: fix-platform-api-issues
overview: 修复 MusicApiService 中酷狗/QQ/网易云三个平台的封面、音频URL、歌词获取问题，对齐 lx-music-mobile 参考项目的 API 端点和参数。
todos:
  - id: extend-playurl-result
    content: 扩展 PlayUrlResult 接口添加 cover 字段，并更新所有平台的 empty 初始化和返回结构
    status: completed
  - id: fix-kugou-cover
    content: 修复酷狗封面：mapKugouList 移除失效 URL，getKugouPlayUrl 和 backup 从 data.img 提取封面
    status: completed
    dependencies:
      - extend-playurl-result
  - id: fix-qq-audio-lyrics
    content: 修复 QQ 音频和歌词：新增 getQQSongDetail 获取 strMediaMid 和封面，改写 getQQPlayUrl 使用 media_mid 请求 vkey，歌词改用歌曲详情 songmid
    status: completed
    dependencies:
      - extend-playurl-result
  - id: fix-netease-cover
    content: 修复网易云封面：新增 getNeteaseSongDetail 从 /api/song/detail 获取 al.picUrl
    status: completed
    dependencies:
      - extend-playurl-result
  - id: fix-viewmodel-fallback
    content: 在 SearchResultViewModel.playSong 中用 result.cover 兜底覆盖 remoteSongCover
    status: completed
    dependencies:
      - fix-kugou-cover
      - fix-qq-audio-lyrics
      - fix-netease-cover
---

## 问题概述
修复 MusicApiService 中三个音乐平台的 API 调用缺陷：酷狗封面获取失效、QQ 无法返回音频 URL 和歌词、网易云封面获取失效。这些都是普遍问题而非偶然现象。

## 核心修复

### 1. 扩展 PlayUrlResult 接口
新增 `cover` 字段，让 `getPlayUrl` 能够将封面 URL 回传给调用方。当搜索阶段的封面 URL 失效时，由播放阶段的 API 返回有效封面替代。

### 2. 酷狗封面修复
- **移除搜索阶段的无效封面**：`mapKugouList` 中不再拼接 `imge.kugou.com/stdmusic/240/{id}.png`（该域名已失效），搜索阶段 `coverUrl` 留空
- **从播放 API 提取封面**：`getKugouPlayUrl` 主端点 `wwwapi.kugou.com/yy/index.php?r=play/getdata` 返回的 JSON 中 `data.img` 包含有效封面 URL，存入 `result.cover`
- 备用端点 `getKugouPlayUrlBackup` 同上处理

### 3. QQ 音频 URL 修复
- **新增 `getQQSongDetail`**：在请求 vkey 之前先调用 `u.y.qq.com/cgi-bin/musicu.fcg`，使用模块 `music.pf_song_detail_svr.get_song_detail_yqq` 获取 `track_info.file.media_mid`（strMediaMid）和专辑封面 `track_info.album.mid`
- **修改 vkey 请求**：用 `strMediaMid` 替代搜索返回的 `songmid` 作为 vkey 请求参数
- **歌词同步修复**：同样使用歌曲详情返回的 `songmid`（而非搜索返回的 `songmid`）请求歌词 API

### 4. 网易云封面修复
- **搜索阶段留空**：`mapNeteaseList` 不再依赖搜索 API 的 `album.picUrl`（可能为空）
- **新增 `getNeteaseSongDetail`**：在 `getNeteasePlayUrl` 中额外调用公开接口 `music.163.com/api/song/detail?ids=[]` 获取 `songs[0].al.picUrl` 作为封面

### 5. 调用方兜底
`SearchResultViewModel.playSong()` 中，当 `item.coverUrl` 为空时，使用 `result.cover` 回填 `remoteSongCover`。

## 技术方案

### 修改文件清单
| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `features/search/src/main/ets/service/MusicApiService.ets` | 修改 | 主要修改目标 |
| `features/search/src/main/ets/viewmodel/SearchResultViewModel.ets` | 修改 | 一行兜底改动 |

### 详细修改点

#### A. PlayUrlResult 接口扩展 (line 42-46)
```typescript
export interface PlayUrlResult {
  url: string
  lyrics: string
  cover: string  // 新增
}
```
所有 `empty: PlayUrlResult` 初始化改为 `{ url: '', lyrics: '', cover: '' }`

#### B. 酷狗封面 (mapKugouList 第 286-290 行)
移除 `imge.kugou.com` 拼接，`coverUrl` 和 `cover` 均设为空字符串。封面稍后由 `getPlayUrl` 回传。

#### C. 酷狗 getKugouPlayUrl (第 1078-1116 行)
从 `data.img` 提取封面：
```
const cover = (data['img'] as string) || ''
return { url: playUrl, lyrics: lyrics, cover: cover }
```
备用端点 `getKugouPlayUrlBackup` 同样处理。

#### D. QQ 新增 getQQSongDetail 方法
```
POST https://u.y.qq.com/cgi-bin/musicu.fcg
Body: { comm: { ct:'19', cv:'1859', uin:'0' }, req: { module:'music.pf_song_detail_svr', method:'get_song_detail_yqq', param: { song_type:0, song_mid:songmid } } }
```
解析返回值：
- `data.req.data.track_info.file.media_mid` → strMediaMid
- `data.req.data.track_info.album.mid` → albumMid（用于拼接封面）
- `data.req.data.track_info.mid` → 歌曲详情 songmid（用于歌词请求）

#### E. QQ getQQPlayUrl 改造
- 先调用 `getQQSongDetail` 获取 `strMediaMid` 和封面
- vkey 请求的 `songmid` 参数改用 `strMediaMid`
- 从 `albumMid` 拼接封面：`https://y.gtimg.cn/music/photo_new/T002R500x500M000{albumMid}.jpg`
- 歌词请求改用歌曲详情的 `songmid`

#### F. QQ getQQLyrics 保持现状
当前 base64 解码逻辑（`buffer.from(content, 'base64')` + `TextDecoder('utf-8')`）经核查正确，无需修改。歌词获取不成功的问题随音频 URL 修复一并解决（改用正确的 songmid）。

#### G. 网易云 getNeteaseSongDetail 新增
```
GET https://music.163.com/api/song/detail?ids=[{songId}]
```
解析 `body.songs[0].al.picUrl` 作为封面。

#### H. 网易云 getNeteasePlayUrl 改造
在现有逻辑之后，额外调用 `getNeteaseSongDetail` 获取封面。

#### I. SearchResultViewModel.playSong() (第 71 行)
```typescript
// 原：this.intentState.remoteSongCover = item.coverUrl || item.cover
// 改为：
const result = await MusicApiService.getPlayUrl(...)
// ... 现有 url/lyrics 处理 ...
if (result.cover) {
  this.intentState.remoteSongCover = result.cover
} else if (!this.intentState.remoteSongCover) {
  this.intentState.remoteSongCover = item.coverUrl || item.cover
}
```

### 数据流
```
搜索阶段: coverUrl/cover 置空（KG/WY）
    ↓
播放阶段: getPlayUrl → get*SongDetail → 提取 cover → 存入 result.cover
    ↓
SearchResultViewModel: result.cover 覆盖 remoteSongCover
    ↓
SongItem.coverUrl → UI 封面显示
```

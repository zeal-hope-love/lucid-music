---
name: fix-apis-from-lxmobile
overview: 基于 lx-music-mobile 源码修复酷狗封面/歌词、QQ 封面/播放/歌词、网易云歌词
todos:
  - id: fix-kugou-cover
    content: 修复酷狗封面：改回 https/imge.kugou.com/stdmusic/240/ 格式
    status: completed
  - id: fix-kugou-lyrics
    content: 新增两步法 getKugouLyrics(hash, name) 替代 data.lyrics 提取
    status: completed
  - id: fix-qq-cover
    content: 修复 QQ 封面：无专辑时用歌手 mid 构造封面 URL
    status: completed
  - id: fix-qq-lyrics
    content: 修复 QQ 歌词：补全 API 参数 g_tk/loginUin/hostUin/platform + Referer
    status: completed
  - id: fix-qq-audio
    content: 修复 QQ 音频：getQQPlayUrl 恢复 GET 方式
    status: completed
---


## 用户需求

参考 lx-music-mobile 开源项目，修复 lucid_music 中音乐平台 API 的以下问题：
1. **酷狗、网易云封面抓取不到** — 搜索结果显示的歌单封面图片无法加载
2. **QQ 没有音频** — 点击 QQ 音乐搜索结果无法播放
3. **酷狗、QQ 没有歌词** — 播放页和控制栏不显示歌词

## 核心改动

### 1. Kugou 封面修复
- 更换为 `https://imge.kugou.com/stdmusic/240/{AlbumID}.png`（恢复 240px，用 https）
- 参考 lx-music-mobile，AlbumID 非空时优先使用；回退到 FileHash

### 2. Kugou 歌词修复（两步流程）
- 替换当前 `play/getdata` 中提取 lyrics 的简单方式
- 新增 `getKugouLyrics(hash, songName)` 方法：
  - Step 1: GET `http://lyrics.kugou.com/search?ver=1&client=pc&keyword=${name}&hash=${hash}&lrctxt=1`
  - Step 2: GET `http://lyrics.kugou.com/download?ver=1&client=pc&id=${id}&accesskey=${key}&fmt=lrc&charset=utf8`
- `getKugouPlayUrl` 调用此方法替代 `data.lyrics`

### 3. QQ 封面修复
- 当前 mapQQList 中只使用了 `albummid`，未处理无专辑时的歌手图
- 新增 fallback：无专辑时从 singer 数组提取 `mid` 构造 `T001R500x500M000{singerMid}.jpg`

### 4. QQ 歌词修复
- 当前 `getQQLyrics` 参数不完整，缺少 `g_tk`、`loginUin`、`hostUin`、`platform=yqq`
- 添加 `Referer: https://y.qq.com/portal/player.html` 请求头
- 确认 base64 解码逻辑正确

### 5. QQ 音频修复
- 当前 POST 方式可能因 zzcSign 缺失而失败
- 回退到 GET 方式（更简单的参数），添加完整请求头



## 技术方案

### 修改文件
仅修改一个文件：`features/search/src/main/ets/service/MusicApiService.ets`

### 1. Kugou 封面
修改 `mapKugouList` 第 289-290 行，将 `http://imge.kugou.com/stdmusic/150/` 改为 `https://imge.kugou.com/stdmusic/240/`。移除备用 `kugou.com/yy/albumcover/` 逻辑（该域名不可用）。

### 2. Kugou 歌词 — 两步 API
在 `getKugouPlayUrl` 中，不再从 `data.lyrics` 提取，改为调用新方法 `getKugouLyrics(hash, name)`：
- **Step 1 搜索歌词**: GET `http://lyrics.kugou.com/search` 带 KG-RC、KG-THash 头
- **Step 2 下载歌词**: GET `http://lyrics.kugou.com/download?id=ID&accesskey=KEY&fmt=lrc`，响应 content 字段为 base64 编码的歌词文本

### 3. QQ 封面
修改 `mapQQList`，在 `albumMid` 之外新增 singerMid fallback：
- 从 `item['singer']` 数组中提取首个歌手的 `mid` 字段
- URL 模板：`https://y.gtimg.cn/music/photo_new/T001R500x500M000{singerMid}.jpg`

### 4. QQ 歌词
修改 `getQQLyrics` 方法：
- URL 补充参数：`g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`
- 添加 `Referer: https://y.qq.com/portal/player.html`
- 确认 `decodeToString` 替代已废弃的 `decodeWithStream`

### 5. QQ 音频
`getQQPlayUrl` 恢复 GET 方式（移除 POST），补充完整参数使 vkey API 更可靠。


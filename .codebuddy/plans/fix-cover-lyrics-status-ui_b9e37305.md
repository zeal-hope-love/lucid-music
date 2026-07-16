---
name: fix-cover-lyrics-status-ui
overview: 修复背景闪烁、歌词页远程封面不显示、状态文字颜色、酷狗封面抓取、全平台歌词获取、搜索页点击波纹反馈
todos:
  - id: fix-background-flicker
    content: 修复背景闪烁：Index.ets onTap 预设 imageColor 默认深色；PlaybackPage 不覆盖已有值；NavDestination transition 改用 50ms opacity
    status: completed
  - id: fix-lyrics-cover
    content: 修复歌词页远程封面：LyricsComponent.ets SM 模式封面优先检测 coverUrl，存在时使用网络 Image
    status: completed
  - id: fix-status-colors
    content: 修复状态文字颜色：MiniPlayerBar 改用主题色（浅色黑/深色白）；ControlAreaComponent 改为白色+上移与时间行平齐
    status: completed
  - id: fix-kugou-cover
    content: 修复酷狗封面：改用 480px 尺寸 URL；getKugouPlayUrl 添加备用封面 URL 构造逻辑
    status: completed
  - id: fix-all-platforms-lyrics
    content: 修复全平台歌词：网易云/酷我/咪咕新增歌词 API；QQ 解码改用非废弃 API；Kugou 备用端点也提取 lyrics
    status: completed
    dependencies:
      - fix-kugou-cover
  - id: fix-search-ripple
    content: 修复搜索点击反馈：移除持久高亮，改为 200ms 短暂高亮后自动恢复
    status: completed
---

## 用户需求

1. **背景闪烁修复**：从控制栏点击进入播放详细页时背景闪黑色，需彻底解决，改为平滑过渡
2. **歌词页远程封面缺失**：Dream It Possible 封面一镜到底正常，但远程歌曲封面页显示正常、歌词页封面不显示
3. **状态文字主题色**：详细页进度条下方状态提示用主题色或白色，上移与播放时长平齐；控制栏状态提示浅色主题用黑色、深色主题用白色
4. **酷狗封面抓取**：coverUrl 可能被防盗链阻挡，无法正常加载封面
5. **全平台歌词抓取**：酷狗/QQ 歌词 API 待调试，网易云/酷我/咪咕未实现歌词获取
6. **搜索点击反馈**：点击后不需要持久高亮，改为短暂水波式视觉反馈后自动消除


## 技术方案

### 1. 背景闪烁修复

**根因**：PlaybackPage NavDestination 使用 `TransitionEffect.IDENTITY.animation({ duration: 0 })` 零时长过渡，页面瞬间出现。此时 `imageColor` 在 PlayerInfoComponent 中异步提取封面主色尚未完成，导致先渲染黑色背景再跳变。

**方案**：在 Index.ets 中 `onTap` 推页面之前，同步设置 PlaybackPage 的初始背景色为深色默认值（`'rgba(18,18,25,1.00)'` 暗蓝灰），而非纯黑。同时将 NavDestination transition 改为极短的 opacity 过渡（50ms），让颜色跳变被淡入掩盖。

### 2. 歌词页远程封面

`LyricsComponent.ets` SM 模式下行 99 只使用 `Image(this.songList[this.selectIndex].label)`，远程歌曲的 label 是默认占位符。参照 MusicInfoComponent 的做法：当 coverUrl 非空时优先使用网络 Image，否则回退到 label Resource。

### 3. 状态文字主题色

- **ControlAreaComponent**：改为白色（`Color.White`），与时间文字颜色一致，7-8px padding。
- **MiniPlayerBar**：使用 `$r('sys.color.ohos_id_color_text_primary')` 或直接检测系统深色模式。
- 两个组件中拿掉硬编码 `#FF6B35`。

### 4. Kugou 封面

当前 URL `imge.kugou.com/stdmusic/240/` 的 240px 缩略图可能被防盗链阻挡。改为 `https://imge.kugou.com/stdmusic/480/{hash}.png`（480px 更大尺寸），同时 HTTP 请求添加 `Referer: https://www.kugou.com/` 请求头。在 `getKugouPlayUrl` 中增加备用封面获取逻辑，若主 API 返回的 AlbumID 无效，使用 FileHash 构造 cover URL。

### 5. 全平台歌词

- **Kugou**：备用端点 `m.kugou.com` 也尝试提取 lyrics；若均无歌词，record 日志
- **QQ**：`getQQLyrics()` 已实现 base64 解码，但 decodeWithStream 已废弃，改用 `decodeToString`
- **网易云**：新增 `getNeteaseLyrics()`，调用 `https://music.163.com/api/song/lyric?id={songId}&lv=1`
- **酷我**：新增 `getKuwoLyrics()`，通过 `https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId={id}`
- **咪咕**：新增 `getMiguLyrics()`，通过歌词 API 或返回空

歌词返回类型统一为 `string`，在各平台 `getPlayUrl` 中调用并合并到 `PlayUrlResult.lyrics`。

### 6. 搜索点击反馈

移除 `activeResultIndex` 持久高亮。改为点击时通过 `animateTo` 短暂改变 item 背景透明度，200ms 后自动恢复。使用 `@Local activeResultIndex` + `setTimeout` 清理。


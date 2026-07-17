---
name: fix-ui-shift-qq-url-netease-cover
overview: 修复三个新问题：1）状态文字显示/隐藏导致上方内容（封面/歌名/进度条）位置跳动——改用固定高度+visibility；2）QQ音乐播放持续超时——URL可能是HTTP导致AVPlayer拒绝加载，升级为HTTPS并添加诊断日志；3）网易云封面仍不显示——搜索API的album字段可能不含picUrl或加密有偏差，增加多字段兜底提取+EAPI端点升级HTTPS。
todos:
  - id: fix-layout-shift
    content: ControlAreaComponent.ets：状态文字 if 条件渲染改为固定高度Row + visibility 控制显隐
    status: completed
  - id: fix-qq-https
    content: TxMusicApi.ets extractUrl()：返回前将 http:// 升级为 https://
    status: completed
  - id: fix-netease-cover-https
    content: WyMusicApi.ets 三处修改：mapList 封面URL、hotSearch EAPI endpoint、getCoverViaEapi endpoint与返回封面URL 全部升级HTTPS
    status: completed
---

## 用户需求

### 问题一：布局抖动
- 详细页封面/歌名/进度条位置不稳定：有播放状态文字时整体升高，无状态文字时整体下降
- 根因：ControlAreaComponent.ets 第142-153行使用 `if` 条件渲染状态文字，占据/释放布局空间
- 要求：固定高度容器 + `visibility()` 控制显隐，布局稳定不抖动

### 问题二：QQ音乐播放一直超时
- 每次播放QQ音乐都在preparing状态卡住，15秒后触发超时错误
- 根因：TxMusicApi.extractUrl() 构造的URL使用HTTP scheme（如 `http://ws.stream.qqmusic.qq.com/...`），HarmonyOS AVPlayer拒绝HTTP音频流
- 要求：将播放URL升级为HTTPS

### 问题三：网易云封面仍不显示
- 搜索结果列表和播放详情页均无封面
- 根因：从 `album.picUrl` 提取的封面URL为HTTP，HarmonyOS Image组件无法加载；EAPI请求端点也使用HTTP可能被拦截
- 要求：搜索封面URL升级HTTPS，EAPI请求端点升级HTTPS，返回的封面URL也升级HTTPS


## 技术方案

### 1. 布局抖动修复

**策略**：将 `if` 条件渲染改为始终渲染的 `Row`，设置固定高度 `.height(16)`，通过 `.visibility()` 控制显隐。

**修改文件**：`ControlAreaComponent.ets` 第142-153行

**修改前**：
```typescript
if (this.playbackStatus !== 'idle' && this.playbackStatus !== 'ready') {
  Row() { Text(...) }
  .width(...).justifyContent(...).margin(...)
}
```

**修改后**：
```typescript
Row() {
  Text(this.playbackStatusMessage || this.playbackStatus)
    .fontSize(12).fontColor(Color.White).opacity(0.7)
}
.width(StyleConstants.FULL_WIDTH)
.justifyContent(FlexAlign.Center)
.height(16)
.visibility(this.playbackStatus !== 'idle' && this.playbackStatus !== 'ready' ?
  Visibility.Visible : Visibility.Hidden)
```

固定高度 16vp 对应 fontSize(12) + 行高的视觉高度，margin 下沉到控制按钮Row。

### 2. QQ音乐URL升级HTTPS

**策略**：在 `TxMusicApi.extractUrl()` 的 `return prefix + purl` 处，对构造完成的URL执行 `replace('http://', 'https://')`。

**修改文件**：`TxMusicApi.ets` 第128行

```typescript
const rawUrl = prefix + purl
return rawUrl.replace('http://', 'https://')
```

QQ音乐CDN（`ws.stream.qqmusic.qq.com`、`isure.stream.qqmusic.qq.com`）均支持HTTPS，无需额外改动。

### 3. 网易云封面HTTPS升级

**修改文件**：`WyMusicApi.ets` 三处

**3a. mapList() 封面URL升级**（第38-39行）：
```typescript
const rawPicUrl = album ? (album['picUrl'] as string) || '' : ''
const picUrl = rawPicUrl.replace('http://', 'https://')
result.coverUrl = picUrl; result.cover = picUrl
```

**3b. hotSearch() EAPI endpoint升级**（第54行）：
```typescript
'https://interface.music.163.com/eapi/batch'  // http → https
```

**3c. getCoverViaEapi() EAPI endpoint + 封面URL升级**（第117行 + 第126行）：
```typescript
// endpoint
'https://interface.music.163.com/eapi/batch'  // http → https
// 返回封面URL
const cover = al ? (al['picUrl'] as string) || '' : ''
return cover.replace('http://', 'https://')
```

### 实现要点

- 所有URL `http://` → `https://` 转换使用 `replace` 方法，安全幂等
- visibility 使用 `Visibility.Visible` / `Visibility.Hidden`，Hidden 时占位但不可见
- Row 固定高度保证布局不随状态文字显隐而抖动


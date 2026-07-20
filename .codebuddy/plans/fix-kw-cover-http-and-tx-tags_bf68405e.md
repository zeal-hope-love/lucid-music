---
name: fix-kw-cover-http-and-tx-tags
overview: 解决两问题：① 酷我封面 SSL 证书校验失败(2300060)——根因是上轮 normalizeCover 把原始 http 强转 https，而酷我图片 CDN 的 https 证书 HarmonyOS 不信任；改回 http 明文下载即可（工程内其它 http 明文请求已验证可用）。② QQ 标签仍失败——tx getPlaylistTags 的 data 顶层键误用 playlist，应改为 tags 对齐 lx tagsUrl。
todos:
  - id: fix-kw-cover-http
    content: 修改 kw/songList.ets 的 normalizeCover 保持 http 明文，修复酷我封面 SSL 2300060
    status: completed
  - id: harden-cover-download
    content: MusicCoverImage 对 kw 来源 https URL 兜底回退 http 防止旧缓存触发 SSL
    status: completed
    dependencies:
      - fix-kw-cover-http
  - id: fix-tx-tags-key
    content: tx/songList.ets 的 getPlaylistTags dataStr 顶层键 playlist 改为 tags 对齐 lx
    status: completed
---

## 用户需求
音乐厅存在两个运行期问题需修复：

## 核心功能
- **酷我封面显示**：酷我歌单封面 URL 经上一轮 `normalizeCover` 被强制由 `http://` 转为 `https://`，而酷我图片 CDN（`img1.kwcdn.kuwo.cn`）的 SSL 证书不被 HarmonyOS 系统信任库认可，导致下载时报 `2300060 Invalid SSL peer certificate`，封面全部加载失败。需改回 `http://` 明文下载（工程内 kw/kg 等大量明文 HTTP 请求已验证可用）。
- **QQ（tx）标签抓取**：`tx getPlaylistTags` 的 data 参数顶层键误用 `playlist`（从列表端点照搬），而 lx 的 `tagsUrl` 用的是 `tags` 键；QQ `musicu.fcg` 响应按请求顶层键回显，导致响应落在 `body.playlist` 而非 `body.tags`，解析失败回退默认标签。需改为 `tags` 键对齐 lx。


## 技术栈
- HarmonyOS ArkUI / ArkTS 严格模式（arkts-no-any-unknown、arkts-no-untyped-obj-literals 等生效）。
- 网络：`@kit.NetworkKit`（`http.createHttp`）；图片：`@kit.ImageKit`（`image.createImageSource`/`createPixelMap`）。
- 复用现有分层：`PlaylistCard` → `MusicCoverImage` → `http` 下载；`ApiSource.getPlaylistTags` → `tx getPlaylistTags`。

## 实现方案

### 关键决策
1. **酷我封面改回 http 明文（根因修复）**：`kw/songList.ets` 的 `normalizeCover` 当前 `url.replace('http://','https://')` 把原始 `http://img1.kwcdn.kuwo.cn/...` 强转 https 触发 SSL 校验失败。改为保持 http 明文——协议相对 `//` 补 `http:`（而非 `https:`），删除 http→https 转换，空值仍回退 `$r('app.media.ic_avatar1')`。返回值为 `http://` URL。
   - 佐证：工程内 `http://wapi.kuwo.cn`、`http://www2.kugou.kugou.com`、`http://nplserver.kuwo.cn` 等明文请求均成功（用户确认各平台数据正常），证明 NetworkKit 明文 HTTP 在当前工程可用，无需在 `module.json5` 额外配置 cleartext。
   - 其它平台（tx/yw/mg/kg）的封面 CDN 的 https 证书受信任、显示正常，故仅改 kw，不动其它平台端点与已验证请求，零回归。
2. **MusicCoverImage 兜底（保险）**：`downloadCover` 内对 kw 来源 URL 做 `https://`→`http://` 兜底，防止旧的/缓存的 https URL 再次触发 SSL 错误；保留 KW_HEADER 的 Referer/UA（防盗链）。非 kw 来源仍走原生 `Image(url)`（https 正常）。
3. **QQ 标签顶层键对齐 lx**：`tx/songList.ets` line 88 `dataStr` 由 `{"comm":{...},"playlist":{"method":"get_all_categories",...}}` 改为 `{"tags":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}`（保留已修正的 module 名）。解析逻辑 `body.tags.data.v_group` / `group_name` / `v_item[].id/name` 已正确，无需改动。

### 实现要点（执行细节）
- **kw/songList.ets**：`normalizeCover` 函数体改为 `//`→`http:` 且不再做 http→https 转换。
- **MusicCoverImage.ets**：`downloadCover` 开头 `const fetchUrl = this.source === 'kw' && this.url.startsWith('https://') ? 'http://' + this.url.slice(8) : this.url`，后续用 `fetchUrl` 请求。
- **tx/songList.ets**：仅替换 line 88 字符串常量；请求 URL 拼接、响应解析、`getDefaultPlaylistTags` 兜底与返回类型均不变。

### 回归控制
- 单文件、最小字符串/逻辑改动；端点 host/路径与请求头不变。
- tx 列表端点（用 `playlist` 键，用户已确认正常）不动；kg 标签/分页（上轮已修）不动。
- `read_lints` 对 arkts 严格规则不可靠，最终以 DevEco CompileArkTS 为准。

## 目录结构与关键文件
```
common/musicbasic/src/main/ets/util/musicSdk/kw/songList.ets   # [MODIFY] normalizeCover 改为保持 http 明文（修复 SSL 2300060）
common/musicbasic/src/main/ets/components/MusicCoverImage.ets  # [MODIFY] downloadCover 对 kw https URL 兜底回退 http
common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets   # [MODIFY] getPlaylistTags dataStr 顶层键 playlist→tags 对齐 lx
```


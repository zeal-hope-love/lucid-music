---
name: musichall-fix-covers-tags-paging
overview: 修复音乐厅三个运行期问题：① 酷我封面 CDN 防盗链（需带 Referer 下载为 PixelMap 渲染）；② 酷狗/QQ 标签抓取缺失（kg 未实现真实端点、tx module 名 typo）；③ 酷狗分页过早到底（缺 total 导致 hasMore 误判）。对齐 lx-music-mobile 参考实现。
todos:
  - id: add-music-cover-image
    content: 新增 MusicCoverImage 组件（kw 带 Referer 下载 PixelMap+缓存+兜底）并在 musicbasic 导出
    status: completed
  - id: use-cover-image
    content: PlaylistCard 字符串封面改调 MusicCoverImage 并传 source
    status: completed
    dependencies:
      - add-music-cover-image
  - id: fix-tx-tag-module
    content: 修正 tx getPlaylistTags 的 module 名 typo（PlayList→Playlist）
    status: completed
  - id: kg-real-tags
    content: kg getPlaylistTags 实现真实端点（is_smarty getSpecial 解析 hotTag/tagids）
    status: completed
  - id: kg-paging-total
    content: kg getPlaylists 加 pagesize 并请求信息端点计算精确 hasMore
    status: completed
    dependencies:
      - kg-real-tags
---


## 用户需求
音乐厅运行后出现三个问题，需对照 lx-music-mobile 参考实现修复：

## 核心功能
- **酷我封面显示**：酷我歌单封面 URL 已正确规范化为合法 `https://img1.kwcdn.kuwo.cn/...`，但大量不显示。根因为酷我 CDN 防盗链——HarmonyOS `Image(url)` 网络请求无法携带 `Referer` 被返回 403。需改为携带 `Referer` 下载图片字节并渲染为 `PixelMap`，其它平台封面保持原样避免回归。
- **QQ（tx）标签抓取**：当前 `tx/songList.ets` 标签请求 `module` 名拼错（`PlayListAllCategoriesServer` 应为 `PlaylistAllCategoriesServer`），导致请求失败回退默认标签，需修正。
- **酷狗（kg）标签抓取**：当前 `kg/songList.ets` 的 `getPlaylistTags` 直接返回默认兜底，未实现真实端点。需改为请求 `getSpecial?is_smarty=1&` 并解析 `data.hotTag` 与 `data.tagids`。
- **酷狗（kg）分页过早到底**：当前 `getSongListUrl` 未传 `pagesize`，酷狗默认每页约 20 条，而 `hasMore = results.length >= 30` 恒为 false，导致第 1 页后即停止。需请求信息端点取 `data.params.total/pagesize` 精确计算 `hasMore`。



## 技术栈
- HarmonyOS ArkUI / ArkTS 严格模式（arkts-no-any-unknown、arkts-no-untyped-obj-literals、arkts-no-destruct-decls 均生效）。
- 复用现有分层：`PlaylistCard`（UI）→ `ApiSource.getPlaylists` → 各平台 `getPlaylists`/`getPlaylistTags`。
- 图片下载：`@kit.NetworkKit`（`http`）+ `@kit.ImageKit`（`image.createImageSource`/`createPixelMap`）。

## 实现方案

### 关键决策
1. **酷我封面用「下载为 PixelMap」而非原生 `Image(url)`**：HarmonyOS `Image` 组件无法为网络请求附加 `Referer` 头，而酷我 CDN 对无 `Referer` 的热链返回 403。唯一可靠方案是 `http.createHttp().request(url, { header: { Referer } })` 取 `ArrayBuffer` → `image.createImageSource(buffer).createPixelMap()` → `Image(pixelMap)`。非 kw 来源仍走原生 `Image(url)`（其它平台已正常，零回归风险）。
2. **模块级 `Map<string, image.PixelMap>` 缓存**：避免 Grid 滚动/重渲染时重复下载与像素图泄漏；键为封面 URL。
3. **kg 标签对齐 lx**：`getPlaylistTags` 改请求 `http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&`，解析 `body.data.hotTag.data`（遍历 `Object.keys`，取 `special_id`/`special_name` 作热门组）与 `body.data.tagids`（遍历分组名，`group.data` 每项取 `id`/`name` 作分类组）。
4. **kg 分页精确化**：`getPlaylists` 内 `Promise.all([列表请求, 信息请求])`，信息请求复用 `getSpecial?is_smarty=1&...`，解析 `body.data.params.total` 与 `pagesize`，`hasMore = (page+1)*pagesize < total`；信息缺失时回退 `results.length >= limit`。列表 URL 追加 `pagesize=${limit}` 提升每页条数。
5. **tx 标签**：仅修正 `module` 名 typo（`PlayListAllCategoriesServer` → `PlaylistAllCategoriesServer`），解析逻辑 `body.tags.data.v_group` 已正确，无需改动。

### 实现要点（执行细节）
- **MusicCoverImage 组件**：`@ComponentV2 struct`，`@Param url: string`、`@Param source: string`、`@Param placeholder: Resource = $r('app.media.ic_avatar1')`；内部 `@Local pixelMap: image.PixelMap | null = null`、`@Local failed: boolean = false`。`aboutToAppear` 触发加载：`source !== 'kw'` 时直接渲染原生 `Image(url)`（不下载）；kw 时先查缓存，未命中则带 `Referer: 'http://www.kuwo.cn/playlist'` + `User-Agent` 下载，`createPixelMap` 后入缓存并 `set` 状态；异常置 `failed` 显示 `placeholder`。`build` 中 `pixelMap` 存在渲染 `Image(pixelMap)`，否则渲染 `Image(placeholder)`（加载/失败态统一兜底）。
- **PlaylistCard**：字符串封面分支由 `Image(this.item.coverImage)` 改为 `MusicCoverImage({ url: this.item.coverImage, source: this.item.source })`；本地资源分支不变。
- **回归控制**：端点 URL 与请求参数仅 kg 增补 `pagesize` 与信息请求（对齐 lx `getListInfo`），其余平台 URL 不变；`getPlaylists(cat,page,limit,order)` 与 `getPlaylistTags()` 签名保持不变，`MusichallPlaylistPage` 返回结构不变。
- **日志**：kw 下载失败打印 `coverDownload err` 样本（含 URL/HTTP 码），便于确认是否仍 403 或 Geo 拦截。

## 目录结构与关键文件
```
common/musicbasic/src/main/ets/components/MusicCoverImage.ets   # [NEW] 下载式封面组件：kw 带 Referer 下载为 PixelMap + 模块级缓存 + 失败兜底；非 kw 走原生 Image
common/musicbasic/Index.ets                                     # [MODIFY] 导出 MusicCoverImage，供 PlaylistCard 引用
features/musichall/src/main/ets/view/PlaylistCard.ets           # [MODIFY] 字符串封面改调 MusicCoverImage（传 item.source），本地资源分支不变
common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets    # [MODIFY] getPlaylistTags 的 module 名 PlayListAllCategoriesServer → PlaylistAllCategoriesServer
common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets    # [MODIFY] getPlaylistTags 实现真实端点（is_smarty getSpecial 解析 hotTag/tagids）；getPlaylists 加 pagesize 并请求信息端点计算精确 hasMore
common/musicbasic/src/main/ets/util/musicSdk/kw/songList.ets    # [不变] 封面 URL 已由 normalizeCover 规范化为 https，实际渲染交由 MusicCoverImage 带 Referer 下载
```

## 架构说明
- 仅新增一个可复用封面组件并替换 `PlaylistCard` 渲染路径，数据层（`getPlaylists`/`getPlaylistTags` 返回类型与 `MusicHallPage` 分页消费）保持上轮已落地结构不变。
- `MusicCoverImage` 对 kw 专用下载路径做隔离，其它平台完全走既有原生 `Image`，确保不引入跨平台回归。


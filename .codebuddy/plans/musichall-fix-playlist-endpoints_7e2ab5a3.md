---
name: musichall-fix-playlist-endpoints
overview: 修复 5 个平台（kw/kg/tx/wy/mg）MusicHall 歌单/标签接口失效问题：逐项对齐 lx-music-mobile 最新端点与解析，并移除刚加的 MusichallCache 持久化缓存。
todos:
  - id: remove-musichall-cache
    content: 删除 MusichallCache 文件并清理 Index/EntryAbility/MusicHallPage 三处引用
    status: completed
  - id: fix-kw-endpoints
    content: 修正 kw getPlaylists/getPlaylistTags 端点与解析对齐 lx-music-mobile
    status: completed
  - id: fix-kg-endpoints
    content: 修正 kg getPlaylists 端点(返回HTML)与 special_db 解析
    status: completed
  - id: fix-tx-endpoints
    content: 修正 tx getPlaylists 参数与 module 及 v_playlist/basic 解析
    status: completed
  - id: fix-wy-endpoints
    content: 修正 wy getPlaylists weapi 路径与标签端点 catalogue/hottags
    status: completed
  - id: fix-mg-endpoints
    content: 修正 mg getPlaylists 模板端点与 musiclistplaza 标签端点
    status: completed
  - id: verify-all-platforms
    content: 跑日志逐平台确认 count>0 与 groups>0 并迭代修复
    status: completed
    dependencies:
      - fix-kw-endpoints
      - fix-kg-endpoints
      - fix-tx-endpoints
      - fix-wy-endpoints
      - fix-mg-endpoints
---


## 用户需求
让 MusicHall 真正能从 5 个音乐平台（酷我 kw、酷狗 kg、QQ tx、网易云 wy、咪咕 mg）拉取歌单与分类标签。问题根因是移植自 lx-music-mobile 的歌单/标签接口在本项目中的 URL、请求参数或返回结构解析有偏差（端点并没死，lx-music 5 平台都能正常加载），并非网络或权限问题。同时移除用户刚加的 MusichallCache 持久化缓存（不需要）。

## 核心功能
- 逐平台修正 getPlaylists 端点、请求参数与返回结构解析，使每个平台都能返回 count>0 的歌单列表。
- 逐平台修正 getPlaylistTags 端点与解析，使标签分组 groups>0（无可用端点时回退默认兜底）。
- 删除 MusichallCache 类及其在 Index.ets、EntryAbility.ets、MusicHallPage.ets 的全部引用，恢复为每次直接请求 API。
- 复用已加的 `[musichome]` 诊断日志，逐平台改完跑日志确认 count>0 后再推进，残留问题迭代修复。



## 技术栈
- HarmonyOS ArkUI（ArkTS 严格模式），沿用现有 musicSdk 分层：`common/musicbasic/src/main/ets/util/musicSdk/<platform>/songList.ets` 暴露 `getPlaylists / getPlaylistTags / getPlaylistSongs`，由 `ApiSource.ets` 统一分发。
- 网络层：`@kit.NetworkKit` 的 `http.createHttp().request`（kw/kg/tx/mg）；wy 走 `weapiRequest`（已验证加密链路正常，仅业务路径错）。
- 参考基准：`C:\Users\PoXia\Documents\lx-mobile\lx-music-mobile\src\utils\musicSdk\<platform>\songList.js`（最新可加载实现）。

## 实现方案
逐平台对齐 lx-music-mobile 的 `getListUrl / getList / getTag / getHotTag` 与对应 `filter*` 解析，仅修正「端点 URL + 请求参数 + 返回字段映射」，不改动 `getPlaylistSongs`（mg 的歌曲详情端点已与参考一致，其余平台仅歌单列表/标签失效）。移除 MusichallCache 后，MusicHallPage 改为每次访问直接调用 `ApiSource.getPlaylists/getPlaylistTags`，首屏用本地 MemoryStore 种子数据兜底（已有机制，不白屏）。

### 各平台关键修正
**kw（当前 404）**
- 列表：无分类 `http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=${page}&rn=${limit}&order=${sortId}`；有分类 `.../getTagPlayList?...&pn=${page}&id=${id}&rn=${limit}`。
- 解析：`body.code===200`，列表在 `body.data.data`（`listencnt/name/img`）。
- 标签：`tagsUrl=http://wapi.kuwo.cn/api/pc/classify/playlist/getTagList?cmd=rcm_keyword_playlist&user=0&prod=kwplayer_pc_9.0.5.0&vipver=9.0.5.0&source=kwplayer_pc_9.0.5.0&loginUid=0&loginSid=0&appUid=76039576`；`hotTagUrl=.../getRcmTagList?loginUid=0&loginSid=0&appUid=76039576`。解析 `body.data`（filterTagInfo/filterInfoHotTag，id 形如 `${item.id}-${item.digest}`）。

**kg（当前返回 HTML）**
- 列表：`http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=${sortId}&c=${tagId}&p=${page}`（sortId 取 lx sortList：推荐=5/最热=...）。
- 解析：`body.status===1`，列表在 `body.special_db`（`specialid`/前缀 `id_`、`specialname`、`img||imgurl`、`total_play_count||play_count`）。
- 标签：lx kg 未直接暴露稳定 tagsUrl；优先检索 lx kg 标签端点，若无可用的则保留 `getDefaultPlaylistTags()` 兜底，确保 getPlaylists 先修好。

**tx（当前 no data）**
- 无分类(广场)：`method=get_playlist_by_tag`，`param={id:10000000, sin:limit*(page-1), size:limit, order:sortId, cur_page:page}`，`module=playlist.PlayListPlazaServer`。解析 `body.playlist.data.v_playlist`（`tid/title/cover_url_medium/access_num`）。
- 有分类：`method=get_category_content`，`param={titleid:id, caller:'0', category_id:id, size:limit, page:page-1, use_page:1}`，`module=playlist.PlayListCategoryServer`。解析 `body.playlist.data.content.v_item[].basic`（`tid/title/cover.medium_url||default_url/play_cnt`）。
- 当前错误：`id:5`、缺 `module`、字段名 `sin/num` 与参考不符，需对齐。

**wy（当前 weapi 业务 404）**
- 列表 weapi 路径 `top/playlist` → 改为 `playlist/list`，params `{cat, order, limit, offset:limit*page, total:true}`。解析 `body.playlists` / `body.code===200`。
- 标签：`playlist/hot`+`playlist/catlist` → 改为 `playlist/hottags`（解析 `body.tags[].playlistTag.name`）与 `playlist/catalogue`（解析 `body.sub` + `body.categories`）。

**mg（当前模板不存在）**
- 无分类(广场推荐)：`https://app.c.nf.migu.cn/pc/bmw/page-data/playlist-square-recommend/v1.0?templateVersion=2&pageNo=${page}`。
- 有分类：`https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-listbytag/release?pageNumber=${page}&templateVersion=2&tagId=${tagId}`。
- 解析：`body.code==='000000`，列表 `body.data.contents`（filterList2：`resType==='2021'`，`resId/txt/img`）或 `body.data.contentItemList[1].itemList`（filterList：`logEvent.contentId/title/imageUrl`）。
- 标签：`https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-taglist/release`，解析 `body.data[0].content`（texts:[name,id]）为 hotTag，其余为分组（header.title + content[].texts）。

## 实现注意
- 复用现有 `Logger` 的 `[musichome]`/`TAG` 日志与 `getDefaultPlaylistTags()` 兜底，避免改动调用方契约（`MusichallPlaylistItem` / `TagFilterGroup` / `TagFilterItem` 字段不变）。
- 保持各平台 `getPlaylists(cat, page, limit, order)` 与 `getPlaylistTags()` 签名不变，仅改内部 URL/params/解析，降低回归面。
- 移除缓存后 MusicHallPage 的 `isLoading` 逻辑回退为「直接请求 + MemoryStore 种子兜底」，不保留缓存命中分支。
- 端点正确性依赖各平台当前真实接口，按「改一个→跑日志→确认 count>0」迭代，不假设一次全对。

## 架构设计
维持现有 musicSdk 分层不变：`ApiSource.getPlaylists(source,...) → platform/songList.getPlaylists(...)`。本次仅替换叶子节点的请求实现与解析，不引入新模块/新状态管理。删除 MusichallCache 后，数据流向回归为 `UI → ApiSource → platform SDK → http/weapi → 解析 → MusichallPlaylistItem[]`。

## 目录结构与受影响文件
```
common/musicbasic/src/main/ets/util/musicSdk/kw/songList.ets  # [MODIFY] 改 getPlaylists 端点(getRcmPlayList/getTagPlayList)+解析(body.data.data)；改 getPlaylistTags 端点(getTagList/getRcmTagList)
common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets  # [MODIFY] 改 getPlaylists 端点(getSpecial?is_ajax)+解析(body.special_db/status===1)
common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets  # [MODIFY] 对齐 get_playlist_by_tag/get_category_content 的 param+module；解析 v_playlist / content.v_item.basic
common/musicbasic/src/main/ets/util/musicSdk/wy/songList.ets  # [MODIFY] weapi 路径 top/playlist→playlist/list；标签 playlist/hot+catlist→playlist/hottags+catalogue
common/musicbasic/src/main/ets/util/musicSdk/mg/songList.ets  # [MODIFY] 改 getPlaylists 端点(playlist-square-recommend / musiclistplaza-listbytag)+解析；改 getPlaylistTags 端点(musiclistplaza-taglist)
common/musicbasic/src/main/ets/db/MusichallCache.ets          # [DELETE] 删除整个缓存类文件
common/musicbasic/Index.ets                                   # [MODIFY] 移除 MusichallCache 导出(行 107-108)
entry/src/main/ets/entryability/EntryAbility.ets              # [MODIFY] 移除 import 与 MusichallCache.getInstance().init(context)(行 6、46)
features/musichall/src/main/ets/view/MusicHallPage.ets        # [MODIFY] 移除缓存读写分支(import、getCached*/save* 调用、hasCache 逻辑)，改为直接请求
```

## 关键代码结构（端点契约，供实现对齐）
```ts
// 各平台统一签名（保持不变）
export async function getPlaylists(cat: string, page: number, limit: number, order?: string): Promise<MusichallPlaylistItem[]>
export async function getPlaylistTags(): Promise<TagFilterGroup[]>
```


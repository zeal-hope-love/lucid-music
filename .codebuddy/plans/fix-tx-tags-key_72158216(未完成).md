---
name: fix-tx-tags-key
overview: 修正 tx getPlaylistTags 的 data 参数结构：lx 的 tagsUrl 用顶层 `tags` 键（非 `comm`+`playlist`），当前代码用错键导致响应落在 body.playlist 而非 body.tags、解析失败回退默认标签。改为 `{"tags":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}` 对齐 lx，使 body.tags.data.v_group 正确解析出 QQ 分类标签。
todos:
  - id: fix-tx-tag-key
    content: 将 tx/songList.ets 的 getPlaylistTags dataStr 顶层键由 playlist 改为 tags 以对齐 lx，使 QQ 标签正确回显
    status: pending
---

## 用户需求
音乐厅 QQ（tx）平台标签仍未抓取到。上一轮已修正 `module` 名 typo（`PlayListAllCategoriesServer`→`PlaylistAllCategoriesServer`），但标签依旧回退默认。本次需定位真正根因并修复，使 QQ 歌单分类标签能正常抓取并展示。

## 核心功能
- QQ 平台 `getPlaylistTags` 请求结构对齐 lx-music-mobile，使响应能正确回显 `body.tags.data.v_group`，从而解析出全部分类标签（语种/风格/场景/心情等分组）。
- 修复后 `MusicHallPage` 筛选面板可正常显示 QQ 标签，选中后作为 `cat` 重新请求歌单。


## 技术栈
- HarmonyOS ArkUI / ArkTS 严格模式（arkts-no-any-unknown、arkts-no-untyped-obj-literals 等生效）
- 复用现有分层：`MusicHallPage` → `ApiSource.getPlaylistTags` → `tx getPlaylistTags`

## 实现方案

### 关键决策
- **根因（已调研确认）**：`tx/songList.ets` line 88 的 `dataStr` 顶层键误用 `playlist`，而 lx `tagsUrl` 解码后结构为 `{"tags":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}`（顶层键是 `tags`，无 `comm` 包裹）。QQ `musicu.fcg` 响应按请求 data 的顶层键回显：用 `playlist` 键请求 → 响应落在 `body.playlist`，`body.tags` 为 `undefined` → 触发 `if (!tags) return getDefaultPlaylistTags()` 回退默认。module typo 已修，但键结构错误仍在，故标签仍失败。
- **修复方式**：仅将 line 88 的 `dataStr` 顶层键由 `playlist` 改为 `tags`，保留已修正的 `module` 名 `playlist.PlaylistAllCategoriesServer`，完全对齐 lx `tagsUrl`。
- **解析逻辑无需改动**：现有 line 97-101 已正确读 `body.tags.data.v_group`，且 `group_name`/`v_item[].id/name` 映射与 lx `filterTagInfo` 一致；`getDefaultPlaylistTags` 兜底与返回类型均不变。

### 实现要点（执行细节）
- 改动文件：`common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets`
- 改动内容：line 88 `dataStr` 由
  `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}`
  改为
  `{"tags":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}`
- 其余代码（请求 URL 拼接、响应解析、`groups.length>0 ? groups : getDefaultPlaylistTags()` 兜底）保持不变。
- 回归控制：单文件单行字符串改动，端点 host/路径与请求头不变，不影响其它平台（wy/kw/kg/mg）及已验证的 tx 歌单列表端点（列表端点用的是 `playlist` 键，用户已确认正常，不动）。

### 验证
- 改动后 `read_lints` 复查该文件（0 错误；但 read_lints 对 arkts 严格规则不可靠，最终以 DevEco CompileArkTS 为准）。
- DevEco 编译运行确认：切换 QQ 平台后筛选面板 `tx getPlaylistTags success: groups=N`（N>0，分类分组齐全）；选中某标签后歌单按该 `cat` 重新请求并刷新。
- 可选增强（本次不做，避免扩大范围）：lx 另有 `getHotTag` 抓 `category_playlist.html` 热门标签（需正则解析 HTML），当前仅取分类标签已满足「抓到/抓全」；若后续要「热门」分组再单独处理。


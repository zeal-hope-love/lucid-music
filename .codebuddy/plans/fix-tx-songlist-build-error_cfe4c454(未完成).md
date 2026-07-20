---
name: fix-tx-songlist-build-error
overview: 修复 tx/songList.ets 因上次部分替换留下的语法错误（残留的对象字面量行），并复核所有已改文件确保 ArkTS 编译通过。
todos:
  - id: fix-tx-tags-leftover
    content: 删除 tx/songList.ets 第 84-86 行残留对象字面量，使 dataStr 成为独立语句
    status: completed
  - id: verify-lints
    content: 对 tx/kw/kg/wy/mg songList.ets、MusicHallPage.ets、EntryAbility.ets、Index.ets 调用 read_lints 确认 0 ArkTS 错误
    status: completed
    dependencies:
      - fix-tx-tags-leftover
  - id: user-rebuild-verify
    content: 提示用户在 DevEco Studio 重新构建并运行 App，通过日志确认各平台 count>0 / groups>0
    status: in_progress
    dependencies:
      - verify-lints
---


## 用户需求
收尾修复 DevEco Studio 构建失败（hvigor CompileArkTS ERROR，exit code -1）。根因是此前为规避 ArkTS 严格模式 `arkts-no-untyped-obj-literals`，把 `tx/songList.ets` 的 `getPlaylistTags` 中 `JSON.stringify({...})` 首行替换成模板字符串时，残留了旧对象字面体的后续三行，导致语法错误。需删除残留行，使函数可编译；随后验证全部改动文件 0 ArkTS 错误，最终由用户重新构建并运行 App，通过 `[musichome]` 日志确认 5 个平台 `getPlaylists` 返回 `count>0`、`getPlaylistTags` 返回 `groups>0`。

## 核心功能
- 删除 `tx/songList.ets` 第 84-86 行残留的 `comm:` / `playlist:` / `})`，使 `dataStr` 成为独立完整语句。
- 全量静态检查（read_lints）已改动文件，确保无 ArkTS 编译错误。
- 用户侧重新构建并真机验证各平台歌单/标签数据拉取成功。



## 技术栈
- HarmonyOS ArkUI / ArkTS 严格模式（arkts-no-untyped-obj-literals、arkts-no-destruct-decls 等规则生效）。
- 改动文件：`common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets`（唯一残留破损点），其余文件（kw/kg/wy/mg songList.ets、MusicHallPage.ets、EntryAbility.ets、Index.ets）已在前序步骤修复并经 read_lints 确认 0 错误。

## 实现方案
### 关键修复点
- 文件 `tx/songList.ets` 的 `getPlaylistTags()` 当前第 83-86 行处于破损状态：
  ```
  83:    const dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlayListAllCategoriesServer"}}`
  84:      comm: { cv: 1602, ct: 20 },
  85:      playlist: { method: 'get_all_categories', param: { qq: '' }, module: 'playlist.PlayListAllCategoriesServer' }
  86:    })
  ```
  第 83 行已是正确模板字符串；第 84-86 行是旧 `JSON.stringify` 对象体的残留，必须整体删除，使第 83 行成为完整独立语句，函数其余逻辑（url 拼接、请求、解析 `body.tags.data.v_group`）保持不变。

### 验证策略（性能与可靠性）
- 删除残留行后，对以下文件调用 read_lints 逐一确认 0 ArkTS 错误：
  - `tx/songList.ets`、`kw/songList.ets`、`kg/songList.ets`、`wy/songList.ets`、`mg/songList.ets`
  - `features/musichall/src/main/ets/view/MusicHallPage.ets`
  - `entry/src/main/ets/entryability/EntryAbility.ets`
  - `common/musicbasic/Index.ets`
- 若 read_lints 或用户重新构建仍报同类严格模式错误，按既定模式继续修：嵌套对象字面量 → 模板字符串 JSON；数组解构 → 索引访问；不安全的 `Record`→数组转换 → `as unknown as`。
- 构建通过后，用户运行 App，依据各平台 `KwMusicApi`/`KgMusicApi`/`TxMusicApi`/`WyMusicApi`/`MgMusicApi` 及 `ApiSource` 的 `getPlaylists success: count=...` / `getPlaylistTags success: groups=...` 日志，确认每平台 `count>0` 与 `groups>0`；任一平台仍为 0 则按「改一个→跑日志→确认」迭代。

### 架构与回归控制
- 仅做局部语法修复，不改变任何端点 URL、请求参数或返回解析逻辑（已在前面步骤对齐 lx-music-mobile）。
- 不引入新模块/新状态；`getPlaylists(cat,page,limit,order)` 与 `getPlaylistTags()` 签名保持不变，调用方 `ApiSource` / `MusicHallPage` 无回归风险。


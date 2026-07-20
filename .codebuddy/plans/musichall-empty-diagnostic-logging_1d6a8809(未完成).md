---
name: musichall-empty-diagnostic-logging
overview: 在 MusicHall 歌单加载的完整调用链（页面→ApiSource→各平台 songList.getPlaylists/getPlaylistTags）埋入详细诊断日志，覆盖所有静默 return [] 分支，让用户运行后回传 hilog 日志以定位"全部平台暂无歌单"的根因（网络/权限/接口返回码/解析）。
todos:
  - id: log-page-load
    content: MusicHallPage.loadData 增加入口/出口诊断日志
    status: pending
  - id: log-apisource
    content: ApiSource.getPlaylists/getPlaylistTags 增加参数与结果日志
    status: pending
  - id: log-platform-songlist
    content: kw/mg/kg/wy/tx songList.getPlaylists 补齐静默分支与请求 URL 日志
    status: pending
  - id: build-and-guide
    content: 构建并用 [musichome] 过滤输出 hilog 复现指引
    status: pending
    dependencies:
      - log-page-load
      - log-apisource
      - log-platform-songlist
---

## 用户需求
MusicHall（音乐厅）页面在所有平台都显示"暂无歌单"空状态，怀疑真实 API 没能正确返回歌单数据。用户要求：在歌单加载的完整调用链上补充诊断日志（不改动业务逻辑），随后由用户运行 App 复现并把 hilog 日志回传，以便定位根因。

## 核心功能
- 在页面层、API 调度层、各平台 SDK 层的关键决策点补充结构化日志
- 日志需覆盖所有"静默返回空数组"的分支（HTTP 非 200、body.code 异常、data 为空、list 为空），并输出响应码、body.code、data/list 是否存在、截断后的原始响应片段、请求 URL
- 统一使用项目已有 Logger（hilog，前缀 `[musichome]`，domain 0x0000），便于用该 tag 过滤
- 交付后告知用户如何用 `[musichome]` 关键字过滤日志并复现


## 技术栈
- HarmonyOS ArkTS（严格模式），DevEco Studio / hvigor 构建
- 日志：项目内 `Logger`（封装 hilog，domain 0x0000，前缀 `[musichome]`，info/warn/error 均可用；多参数以 " | " 拼接）

## 实现方案
### 策略
在歌单加载链路的三个层级插入诊断日志，全程复用已有 `Logger`，不改动任何业务/解析逻辑，仅把"静默 return []"的分支补上 warn 日志，并在入口/出口打印关键参数与最终数量。日志量极低（仅网络响应到达时触发，非热路径），不影响性能。

### 调用链与落点
```mermaid
flowchart TD
  A[MusicHallPage.loadData] -->|log source/tag/order| B[ApiSource.getPlaylists]
  B -->|log raw platform + mapped source + result count| C[apis(platformToId).getPlaylists]
  C --> D[kw/tx/kg/wy/mg songList.getPlaylists]
  D -->|每个静默 return 补 warn: respCode/body.code/data/list/raw| E[返回 MusichallPlaylistItem[]]
  A -->|log final playlists.length / tagGroups.length / errorMessage| F[UI 三态]
```

### 关键决策
1. 复用 `Logger` 而非 `console`：保证所有诊断日志带 `[musichome]` 前缀，用户可在 DevEco Log 面板或 `hilog | grep [musichome]` 一键过滤。
2. 仅补日志、零逻辑改动：避免引入回归；所有 `return []` 分支改为 `Logger.warn(...); return []`，保持原有返回语义。
3. 原始响应截断：打印 `JSON.stringify(body).slice(0, 200)`，既暴露结构又避免 hilog 刷屏与敏感信息外泄。
4. 优先 KW（默认平台 `Platform.KW`）：其 `getPlaylists` 四个 early-return 全部无日志，是"暂无歌单"最可能的黑盒；kw/mg/kg 缺日志，wy/tx 已有 warn/info，仅补请求 URL 即可。

### 性能与可靠性
- 日志仅在 HTTP 响应回调后执行，单次请求 1~4 条，开销可忽略；不引入额外网络/IO。
- 截断 + 仅 warn/info 级别，避免大量 error 刷屏影响日志可读性。

### 实现注意
- 注意 KW 请求使用 `http://`（明文），HarmonyOS 默认可能拦截明文流量，导致 `responseCode !== 200` 或请求异常——这是"全部平台空"的高度可疑根因，日志的 responseCode/result 字段将直接证伪或证实，无需现在改代码。
- 编辑前先 `read_file` 取精确内容再 `replace`，遵循 ArkTS 严格模式与既有 import（各 songList 已 import Logger）。
- 不删除任何已有日志，仅追加。


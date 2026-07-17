---
name: fix-wy-music-api
overview: "Fix NetEase (Wy) music API: replace deprecated search API with eapi-based `/api/search/song/list/page` to get covers, and fix hot search URL protocol (https→http) to restore hot search."
todos:
  - id: add-eapi-request
    content: 在 WyMusicApi.ets 中新增 eapiRequest 私有方法，封装 eapi 加密 + HTTP POST 请求
    status: completed
  - id: rewrite-search-api
    content: 重写 search() 方法，使用新版 eapi 搜索 API /api/search/song/list/page 替换旧版 /api/search/get
    status: completed
    dependencies:
      - add-eapi-request
  - id: rewrite-map-list
    content: 重写 mapList() 解析逻辑，适配新版嵌套数据结构 baseInfo.simpleSongData，封面直接从 al.picUrl 提取
    status: completed
    dependencies:
      - rewrite-search-api
  - id: cleanup-cover-fallback
    content: 删除不再需要的 PendingCover 接口、fetchAlbumCover()、getCoverViaEapi()、getCoverDirect() 方法
    status: completed
    dependencies:
      - rewrite-map-list
  - id: fix-hotsearch-url
    content: 修复 hotSearch() 中 eapi 请求 URL 从 https 改为 http
    status: completed
---

## 用户需求
修复网易云音乐（WyMusicApi）两个 API 问题：
1. 搜索结果封面获取不到，始终显示空或占位图
2. 热门搜索功能不工作，不显示热搜关键词

## 根因分析

### 封面获取失败
- 当前使用旧版无加密 API `https://music.163.com/api/search/get`，封面从 `item['album']['picUrl']` 提取，但该接口返回数据中通常不包含 `picUrl` 字段
- 回退方案 `fetchAlbumCover()` 通过专辑 API 单独获取封面，但该 API 也可能受限返回空
- lx-music-mobile 使用新版 eapi 加密搜索 API `/api/search/song/list/page`，封面始终在返回数据 `baseInfo.simpleSongData.al.picUrl` 中直接包含，无需二次请求

### 热门搜索不工作
- 热搜 API 的 eapi 加密算法和请求参数均正确（与 lx-music-mobile 一致）
- 但请求 URL 使用了 `https://interface.music.163.com/eapi/batch`
- lx-music-mobile 使用 `http://interface.music.163.com/eapi/batch`（HTTP 而非 HTTPS）
- `interface.music.163.com` 的 eapi/batch 端点不支持 HTTPS，导致请求失败


## Tech Stack
- 语言：ArkTS (HarmonyOS)
- 网络请求：`@kit.NetworkKit` http 模块
- 加密：`@kit.CryptoArchitectureKit` cryptoFramework + `@kit.ArkTS` buffer/util
- 已有基础设施：`MusicApiUtils.eapiEncrypt(url, data)` 已正确实现 AES-128-ECB-NoPadding 加密，无需修改

## 实现方案

### 策略：迁移到新版 eapi 加密搜索 API

**原理**：将网易云搜索从旧版无加密 API 迁移到新版 eapi 加密搜索 API，对标 lx-music-mobile 的实现。新版 API 在返回数据中直接包含封面 URL，解决封面获取问题。同时对热搜 URL 做协议修正。

**关键决策**：
1. 搜索 API 端点从 `/api/search/get`（旧版 GET）切换到 `/api/search/song/list/page`（eapi POST）
2. 封面直接从搜索结果中提取 `al.picUrl`，删除回退至专辑 API 的复杂逻辑
3. 热搜 URL 从 HTTPS 改为 HTTP

### 实现细节

#### 1. 搜索 API 重构
- 添加 `eapiRequest()` 方法封装 eapi 加密 + HTTP POST 请求
- 修改 `search()` 方法：用 eapi 加密的新 API 替换旧版 GET API
- 请求体：`{ keyword, needCorrect:'1', channel:'typing', offset, scene:'normal', total: page==1, limit }`

#### 2. 搜索结果解析重写
- 新版响应数据路径：`result.data.resources[]` → 每项展开 `item.baseInfo.simpleSongData`
- 字段映射：
  - 歌曲名 → `simpleSongData.name`
  - 歌手 → `simpleSongData.ar[].name` (join '、')
  - 专辑名 → `simpleSongData.al.name`
  - 封面图 → `simpleSongData.al.picUrl`（直接可用，含 CDN hash 前缀）
  - 时长 → `simpleSongData.dt / 1000`（毫秒转秒）
  - 音质 → `simpleSongData.privilege.maxbr / maxBrLevel`
  - 歌曲ID → `simpleSongData.id`
- 删除 `fetchAlbumCover()` 和 `PendingCover` 接口（不再需要）
- 删除 `mapList()` 中的封面回退逻辑

#### 3. 热搜 URL 修复
- `hotSearch()` 中 eapi 请求 URL 从 `https://interface.music.163.com/eapi/batch` 改为 `http://interface.music.163.com/eapi/batch`

#### 4. 性能优化
- 封面在搜索结果中直接获取，消除 N 次额外 HTTP 请求（N = 缺失封面的歌曲数）
- 不再需要 `pendingCovers` 数组和 `Promise.all` 批量专辑请求

### 架构设计

```mermaid
flowchart LR
    A[SearchViewModel] --> B[MusicApiService.search]
    B --> C[WyMusicApi.search]
    C --> D[eapiRequest]
    D --> E[eapiEncrypt]
    D --> F[http POST]
    E --> G[AES-128-ECB-NoPadding]
    F --> H[interface.music.163.com/eapi/batch]
    H --> I[parse results]
    I --> J[simpleSongData.al.picUrl → cover]
```

### 目录结构

```
features/search/src/main/ets/service/platform/
└── WyMusicApi.ets  # [MODIFY] 主要修改文件
    # - 新增 eapiRequest() 私有方法：封装 eapi 加密 POST 请求
    # - 重写 search()：使用 /api/search/song/list/page 新版 API
    # - 重写 mapList()：解析新版嵌套数据结构 baseInfo.simpleSongData
    # - 删除 PendingCover 接口、fetchAlbumCover()、getCoverViaEapi()、getCoverDirect()
    # - 修改 hotSearch()：eapi 请求 URL 从 https 改为 http
```


## Agent Extensions

### SubAgent
- **code-explorer**
  - Purpose: 在 lx-music-mobile 项目中查找和验证网易云搜索 API 的完整实现细节，包括返回数据结构、字段路径、加密方式
  - Expected outcome: 确认新版搜索 API 的请求参数、响应数据结构路径 (`result.data.resources[].baseInfo.simpleSongData`)、封面字段 (`al.picUrl`) 的正确性

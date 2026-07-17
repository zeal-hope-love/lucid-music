---
name: fix-netease-cover
overview: 在网易云封面流转路径的关键节点添加诊断日志，定位封面丢失的环节，然后针对性修复。
todos:
  - id: log-maplist
    content: WyMusicApi.mapList() 第40行后添加搜索封面提取日志
    status: completed
  - id: log-getplayurl
    content: WyMusicApi.getPlayUrl() 第95行后添加 EAPI 封面结果日志
    status: completed
  - id: log-viewmodel
    content: SearchResultViewModel.playSong() 第101行前添加直接 API cover 字段日志
    status: completed
---

## 用户需求
网易云音乐播放时封面缺失，需先添加诊断日志定位根因，再根据日志修复。

## 封面流转链路
1. **搜索阶段**：`WyMusicApi.mapList()` 从 `album.picUrl` 提取封面 → `SearchResultItem.coverUrl/cover`
2. **播放阶段**：`WyMusicApi.getPlayUrl()` → `getCoverViaEapi()` 通过 EAPI 获取 `songs[0].al.picUrl`
3. **ViewModel**：`SearchResultViewModel.playSong()` 先设搜索封面，后拿 EAPI 封面覆盖
4. **Dispatcher**：`PlaybackIntentDispatcher` → `songItem.coverUrl`

## 已有日志
- `getCoverViaEapi()`：raw response、code/key、cover URL
- `SearchResultViewModel`：JSVM result 各字段可用性

## 缺失日志（3个缺口）
1. `mapList()` 未打印搜索封面是否提取到
2. `getPlayUrl()` 未打印 EAPI 封面最终结果
3. `SearchResultViewModel` 未打印直接 API 兜底路径 cover 是否为空


## 修改策略
在 3 个缺口节点各添加一行 `Logger.info` 日志，便于定位封面在哪一步丢失。

## 修改文件与具体位置

### 1. WyMusicApi.ets — mapList() 搜索封面日志
**位置**：第40行 `result.coverUrl = picUrl; result.cover = picUrl` 之后
**添加**：
```typescript
Logger.info(TAG, `wy mapList: title=${(result.title as string).substring(0, 20)}, picUrl=${picUrl.substring(0, 80) || '<empty>'}`)
```
**目的**：确认搜索 API 返回的 `album.picUrl` 是否有值

### 2. WyMusicApi.ets — getPlayUrl() EAPI 封面结果日志
**位置**：第95行 `const cover = await WyMusicApi.getCoverViaEapi(songId)` 之后、第96行 return 之前
**添加**：
```typescript
Logger.info(TAG, `wy getPlayUrl: songId=${songId}, playUrl=${playUrl.substring(0, 50) || '<empty>'}, cover=${cover.substring(0, 50) || '<empty>'}`)
```
**目的**：确认 EAPI 封面是否返回、与播放 URL 并列对比

### 3. SearchResultViewModel.ets — 直接 API 兜底路径 cover 日志
**位置**：第101行 `if (result.cover)` 之前
**添加**：
```typescript
Logger.info(`${TAG}: API result - hasCover=${!!result.cover}, coverLen=${result.cover?.length ?? 0}, coverPreview=${(result.cover || '').substring(0, 50)}`)
```
**目的**：确认直接 API 路径 PlayUrlResult.cover 是否为空


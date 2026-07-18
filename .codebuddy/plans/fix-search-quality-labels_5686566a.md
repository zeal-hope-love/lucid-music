---
name: fix-search-quality-labels
overview: 参考 lx-music-mobile 项目的音质解析逻辑，修复网易云和QQ音乐搜索结果中音质标签问题。网易云增加 h/m/l 子对象 fallback，QQ音乐改用 file 子对象字段。
todos:
  - id: fix-wy-quality
    content: 修复 WyMusicApi.ets：在 parseLegacySongs 和 mapList 中增加 h/m/l 品质子对象 fallback 诊断日志和 bitrate 检测逻辑
    status: completed
  - id: fix-tx-quality
    content: 修复 TxMusicApi.ets：在 mapList 中增加 file 子对象 fallback 诊断日志和 size_hires/size_flac/size_320mp3 检测逻辑
    status: completed
---

## 用户需求
修复网易云和QQ音乐搜索结果中音质标签显示不正确的问题：
- 网易云所有搜索结果都显示"标准"（实际应区分 24bit、SQ、HQ、标准）
- QQ音乐只显示"HQ"和"标准"（实际应有 SQ 和 24bit）

## 核心修改
1. **WyMusicApi.ets**：在 `parseLegacySongs`（第62-65行）和 `mapList`（第92-95行）中，增加从 song item 的 `h`/`m`/`l` 品质子对象（含 `br` bitrate 字段）获取音质的 fallback 逻辑，当 `privilege.maxbr` 不可用时自动降级使用
2. **TxMusicApi.ets**：在 `mapList`（第36行）中，增加从 `item.file` 子对象（含 `size_hires`/`size_flac`/`size_320mp3`）获取音质的 fallback 逻辑，当顶层 `sizehr`/`sizesq` 字段不可用时自动降级使用
3. 添加诊断日志打印原始音质字段值，便于后续验证和排查


## 技术方案

### 网易云修复 - WyMusicApi.ets

**参考**: lx-music-mobile 的 `wy/musicSearch.js`，其同时依赖 `privilege.maxbr` 和 `item.hr`/`sq`/`h`/`l` 品质子对象

**修改位置**: 两处（`parseLegacySongs` 第62-65行，`mapList` 第92-95行），逻辑一致

**新音质解析策略**（保持向后兼容）：

```typescript
// 优先路径：privilege（保持不变）
const privilege = item['privilege'] as Record<string, Object>
const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''

// fallback：从 h/m/l 品质子对象获取 bitrate
if (maxbr === 0 && !maxBrLevel) {
  const hItem = item['h'] as Record<string, Object>
  const mItem = item['m'] as Record<string, Object>
  const lItem = item['l'] as Record<string, Object>
  const hBr = hItem ? (hItem['br'] as number) || 0 : 0
  const mBr = mItem ? (mItem['br'] as number) || 0 : 0
  const lBr = lItem ? (lItem['br'] as number) || 0 : 0
  const bestBr = Math.max(hBr, mBr, lBr)
  result.quality = bestBr >= 999000 ? 'SQ' : bestBr >= 320000 ? 'HQ' : '标准'
} else {
  result.quality = maxBrLevel === 'hires' ? '24bit' : maxbr >= 999000 ? 'SQ' : maxbr >= 320000 ? 'HQ' : '标准'
}
```

**诊断日志**: 打印 `privilege` 存在性、`maxbr`、`maxBrLevel`，以及 fallback 时的 `hBr`/`mBr`/`lBr` 值

### QQ音乐修复 - TxMusicApi.ets

**参考**: lx-music-mobile 的 `tx/musicSearch.js`，其依赖 `item.file.size_320mp3` / `size_flac` / `size_hires`

**修改位置**: `mapList` 第36行

**新音质解析策略**（保持向后兼容）：

```typescript
// 优先路径：顶层字段（保持不变）
let quality = (item['sizehr'] as number) > 0 ? '24bit' :
              (item['sizesq'] as number) > 0 ? 'SQ' :
              (item['size320'] as number) > 0 ? 'HQ' : ''

// fallback：file 子对象字段
if (quality === '') {
  const file = item['file'] as Record<string, Object>
  if (file) {
    quality = (file['size_hires'] as number) > 0 ? '24bit' :
              (file['size_flac'] as number) > 0 ? 'SQ' :
              (file['size_320mp3'] as number) > 0 ? 'HQ' : '标准'
  } else {
    quality = '标准'
  }
}
result.quality = quality
```

**诊断日志**: 打印顶层 `sizehr`/`sizesq`/`size320` 值，以及 fallback 时的 `file` 子对象字段值

### 实现要点
- 使用项目已有的 `Logger.info(TAG, ...)` 添加日志，TAG 为 `'MusicApiService'`
- 每条日志控制在 300 字符内避免截断
- 不修改 `SearchResultItem.ets` 数据模型和 `SearchPage.ets` UI 显示逻辑
- 保留现有逻辑作为优先路径，fallback 仅在优先路径无法判定时生效
- `mapList` 方法在 `parseLegacySongs` 和 eapi 兜底两个场景复用同一逻辑


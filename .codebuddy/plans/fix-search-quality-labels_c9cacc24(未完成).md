---
name: fix-search-quality-labels
overview: 修复网易云和QQ音乐搜索结果中音质标签全部显示"标准"或只有HQ/标准的问题。先添加调试日志验证API实际返回字段，再根据实际数据修正解析逻辑。
todos:
  - id: fix-wy-quality
    content: 修复 WyMusicApi.ets：在 parseLegacySongs 和 mapList 中添加音质字段的诊断日志，并增加 h/m/l 品质子对象的 fallback 检测逻辑
    status: pending
  - id: fix-tx-quality
    content: 修复 TxMusicApi.ets：在 mapList 中添加 sizehr/sizesq/size320 的诊断日志和 item key 枚举，并增加 file 子对象的 fallback 检测逻辑
    status: pending
---


## 问题描述
音乐搜索结果中音质标签显示不正确：
- **网易云音乐**：所有搜索结果都显示"标准"，实际应区分 24bit、SQ（无损）、HQ（高品质）、标准
- **QQ音乐**：只有"HQ"和"标准"两种标签显，缺少"SQ"和"24bit"

## 根因分析
- **WyMusicApi.ets** 第65行依赖 `item['privilege']['maxbr']` 和 `maxBrLevel` 字段判断音质，但 legacy API `/api/search/get` 返回的歌曲数据中 `privilege` 字段可能不存在或其 `maxbr` 始终为 0，导致所有结果落入兜底分支"标准"
- **TxMusicApi.ets** 第36行依赖 `item['sizehr']`/`item['sizesq']`/`item['size320']` 文件大小字段，但 `client_search_cp` API 可能不返回 `sizehr` 和 `sizesq` 字段（或其值始终为 0），导致只有 `size320 > 0` 的情况显HQ，其余全是"标准"

## 修复目标
1. 为网易云和QQ音乐搜索添加诊断日志，捕获音质相关原始字段
2. 网易云：增加 fallback 逻辑——当 privilege 不可用时，通过 song 对象的 h/m/l 品质子对象判断音质
3. QQ音乐：增加 fallback 逻辑——当 sizehr/sizesq 缺失时，通过其他可用字段判断音质



## 实现方案

### 修改策略
在两个平台 API 的音质解析处添加 Logger.info 日志（来源为已有的 `Logger` from 'musicbasic'，TAG 为 'MusicApiService'），同时增加 fallback 检测路径。

### 具体修改

#### 1. WyMusicApi.ets（网易云）— parseLegacySongs 方法（第62-65行）和 mapList 方法（第92-95行）

**当前逻辑**：
```typescript
const privilege = item['privilege'] as Record<string, Object>
const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
result.quality = maxBrLevel === 'hires' ? '24bit' : maxbr >= 999000 ? 'SQ' : maxbr >= 320000 ? 'HQ' : '标准'
```

**修复方案**：
- 添加诊断日志打印 `privilege` 对象及 `maxbr`/`maxBrLevel` 值
- 添加 fallback 检测：检查 song item 下的 `h`、`m`、`l` 子对象（网易云标准 song 结构中的高品质/中品/低品质信息），其内含 `br`(bitrate) 字段：
  - `h.br >= 999000` → SQ 或 24bit
  - `m.br >= 320000` → HQ
  - 否则 → 标准
- 保留原有 privilege 检测作为优先路径

#### 2. TxMusicApi.ets（QQ音乐）— mapList 方法（第36行）

**当前逻辑**：
```typescript
result.quality = (item['sizehr'] as number) > 0 ? '24bit' : (item['sizesq'] as number) > 0 ? 'SQ' : (item['size320'] as number) > 0 ? 'HQ' : '标准'
```

**修复方案**：
- 添加诊断日志打印 `sizehr`/`sizesq`/`size320` 原始值，以及 item 所有 key 名（方便发现嵌套字段）
- 添加 fallback 检测：检查 `item['file']` 对象（部分QQ API 将音质文件信息放在 file 子对象内），可能有 `file.size_320`、`file.size_sq`、`file.size_hr` 等字段
- 保留原有顶层字段检测作为优先路径

### 修改文件清单
```
features/search/src/main/ets/service/platform/WyMusicApi.ets   # [MODIFY] parseLegacySongs(第62-65行) + mapList(第92-95行)：添加日志+fallback
features/search/src/main/ets/service/platform/TxMusicApi.ets    # [MODIFY] mapList(第36行)：添加日志+fallback
```

### 注意事项
- 使用已有的 `Logger` from 'musicbasic'，TAG 使用 'MusicApiService' 与项目一致
- 日志级别用 `Logger.info`，每条日志不超过 300 字符避免截断
- 不改动 `SearchPage.ets` 的音质标签 UI 显示逻辑和 `SearchResultItem.ets` 的数据模型
- fallback 逻辑不改变已有正常工作的路径优先级


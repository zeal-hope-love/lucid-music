---
name: split-music-api-platforms
overview: 将 MusicApiService.ets 按平台拆分为 KgMusicApi/TxMusicApi/WyMusicApi/KwMusicApi/MgMusicApi + MusicApiUtils，MusicApiService 变为纯调度层
todos:
  - id: create-files
    content: 在 DevEco Studio 中 features/search/src/main/ets/service/platform/ 下新建 KgMusicApi.ets、TxMusicApi.ets、WyMusicApi.ets、KwMusicApi.ets、MgMusicApi.ets 五个空文件
    status: completed
  - id: create-utils
    content: 新建 features/search/src/main/ets/service/MusicApiUtils.ets
    status: completed
  - id: extract-utils
    content: 将 MusicApiService.ets 第 1-134 行（imports、interfaces、工具函数）移入 MusicApiUtils.ets
    status: completed
    dependencies:
      - create-utils
  - id: extract-kg
    content: 将酷狗相关方法（searchKugou、mapKugouList、hotSearchKugou、suggestKugou、getKugouPlayUrl、tryKugou*、fetchKugouPic、getKugouLyrics）移入 KgMusicApi.ets
    status: completed
    dependencies:
      - create-files
  - id: extract-tx
    content: 将QQ相关方法（searchQQ、mapQQList、hotSearchQQ、suggestQQ、getQQPlayUrl、tryQQ*、extractQQUrl、getQQLyrics）移入 TxMusicApi.ets
    status: completed
    dependencies:
      - create-files
  - id: extract-wy
    content: 将网易云相关方法（searchNetease、mapNeteaseList、hotSearchNetease、suggestNetease、getNeteasePlayUrl、getNeteaseLyrics、getNeteaseCoverViaEapi）移入 WyMusicApi.ets
    status: completed
    dependencies:
      - create-files
  - id: extract-kw
    content: 将酷我相关方法（searchKuwo、mapKuwoList、hotSearchKuwo、suggestKuwo、getKuwoPlayUrl、getKuwoLyrics、normalizeKuwoJson）移入 KwMusicApi.ets
    status: completed
    dependencies:
      - create-files
  - id: extract-mg
    content: 将咪咕相关方法（searchMigu、mapMiguList、mapOneMiguSong、hotSearchMigu、suggestMigu、getMiguPlayUrl）移入 MgMusicApi.ets
    status: completed
    dependencies:
      - create-files
  - id: rewrite-service
    content: 重写 MusicApiService.ets 为调度层：import 各平台类，search/hotSearch/suggest/getPlayUrl 方法 switch 分发到对应平台
    status: completed
    dependencies:
      - extract-kg
      - extract-tx
      - extract-wy
      - extract-kw
      - extract-mg
  - id: build-verify
    content: 编译验证，确保 SearchResultViewModel.ets 和 SearchViewModel.ets 无需修改即可正常工作
    status: completed
    dependencies:
      - rewrite-service
---

## 需求
将 MusicApiService.ets（~1660行）按平台拆分为独立文件，每个平台一个文件，提取公共工具函数，保留 MusicApiService 为薄调度层。外部调用方无需修改。

## 目标目录结构
```
features/search/src/main/ets/service/
├── MusicApiService.ets          # 调度层（search/suggest/hotSearch/getPlayUrl 分发）
├── MusicApiUtils.ets            # 共享：接口、工具函数、平台映射
└── platform/
    ├── KgMusicApi.ets           # 酷狗：搜索/热词/联想/播放URL/歌词/封面
    ├── TxMusicApi.ets           # QQ音乐：搜索/热词/联想/播放URL/歌词
    ├── WyMusicApi.ets           # 网易云：搜索/热词/联想/播放URL/歌词/封面EAPI
    ├── KwMusicApi.ets           # 酷我：搜索/热词/联想/播放URL/歌词
    └── MgMusicApi.ets           # 咪咕：搜索/热词/联想/播放URL
```

## 拆分方案

### 1. MusicApiUtils.ets — 共享层
从 MusicApiService.ets 抽取第 1-134 行到新文件：
- **imports**：`http`, `cryptoFramework`, `buffer`, `util`, `Logger`
- **interfaces**：`EapiData`, `QQVkeyParam`, `QQVkeyModule`, `QQVkeyBody`, `PlayUrlResult`(export), `QQHotKeyComm`, `QQHotKeyParam`, `QQHotKeyModule`, `QQHotKeyBody`
- **工具函数**：`EAPI_KEY`, `pkcs7Pad`, `md5Hex`, `aesEcbEncrypt`, `eapiEncrypt`(export), `platformToId`(export), `formatDuration`(export), `decodeBase64Lyric`(export)
- **常量**：`MUSIC_TAG = 'MusicApiService'`
- **logger 封装**：`export async function logInfo(msg)` 等，避免各平台文件重复定义 TAG

### 2. 各平台文件模板
每个文件结构：
```typescript
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { Logger } from 'musicbasic';
import { SearchResultItem } from '../../model/SearchResultItem';
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem';
import { formatDuration, MUSIC_TAG, PlayUrlResult, eapiEncrypt, EapiData, decodeBase64Lyric, platformToId } from '../MusicApiUtils';

const TAG = MUSIC_TAG;

export class KgMusicApi {
  static async search(keyword, page, limit) { /* searchKugou + mapKugouList */ }
  static async hotSearch() { /* hotSearchKugou */ }
  static async suggest(keyword) { /* suggestKugou */ }
  static async getPlayUrl(hash, rawFields) { /* getKugouPlayUrl + helpers */ }
  // ...
}
```

### 3. MusicApiService.ets — 调度层
仅保留分发方法和 public API：
- `search(keyword, platform, page, limit)` — switch 分发到 `KgMusicApi.search()` 等
- `hotSearch(platform)` — switch 分发
- `suggest(keyword, platform)` — switch 分发 + 降级回退链
- `getPlayUrl(songId, source, rawFields)` — switch 分发
- `defaultHotSearches()` — 保持
- `searchSongs()` — 保持（deprecated）
- imports 改为从 MusicApiUtils 和各 platform 模块

### 4. 数据流不变
`SearchResultViewModel` → `MusicApiService.getPlayUrl()` → `KgMusicApi.getPlayUrl()` → 返回 `PlayUrlResult`，调用方无需改动。

### 5. 执行步骤
1. 在 `platform/` 目录下新建 5 个空 `.ets` 文件
2. 新建 `MusicApiUtils.ets`
3. 从 MusicApiService.ets 逐段抽取代码到对应文件
4. 修改 MusicApiService.ets 为调度层
5. 编译验证

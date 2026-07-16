---
name: fix-suggest-source-to-kuwo
overview: 将搜索联想建议从"跟随当前平台"改为"始终使用酷我源"，与 lx-music-mobile 对齐。同时简化之前添加的多平台降级回退链。
todos:
  - id: fix-suggest-source
    content: 修改 SearchViewModel.fetchSuggestions()：将 suggest 调用和日志中的 this.currentPlatform 改为 SearchPlatform.KUWO
    status: completed
---

## Product Overview
按 lx-music-mobile 的架构，将搜索联想建议从「跟随当前搜索平台」改为「固定使用酷我平台」。lx-music 中 tipSearch 的 source 字段 (temp_source) 独立于搜索平台 (source)，固定为 kw（酷我），其他平台的 tipSearch 均未启用。当前 lucid_music 错误地将建议 API 与 currentPlatform 绑定，导致切换平台后建议不可用。

## Core Features
- 搜索联想建议固定使用酷我 (kuwo) 平台的 suggest API
- 不再跟随用户当前选择的搜索平台 Tab
- MusicApiService.suggest() 的降级回退链保留作为安全网

## Tech Stack
- 语言：ArkTS
- 涉及文件：仅 `SearchViewModel.ets`

## Implementation Approach
仅修改 `fetchSuggestions()` 方法中的两处 `this.currentPlatform` 引用，改为固定值 `SearchPlatform.KUWO`：

1. **第 214 行** 日志：`this.currentPlatform` → `SearchPlatform.KUWO`
2. **第 216 行** API 调用：`MusicApiService.suggest(kw, this.currentPlatform)` → `MusicApiService.suggest(kw, SearchPlatform.KUWO)`

`MusicApiService.suggest()` 及其降级回退链保持不变——酷我 API 正常工作时直接返回，若失败则依次回退到 QQ/网易云/酷我/咪咕（但主要是安全兜底）。

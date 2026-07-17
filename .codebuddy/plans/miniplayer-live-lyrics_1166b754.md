---
name: miniplayer-live-lyrics
overview: 修复 MiniPlayerBar 控制栏歌词只显示第一行的问题，使 subLine 根据播放进度实时显示当前对应的歌词行。
todos:
  - id: fix-subline-lrc
    content: 在 MiniPlayerBar.ets 中添加内联 LRC 解析缓存和 progress 驱动的当前行查找，替换 subLine 的静态首行取法
    status: completed
---

## 问题
MiniPlayerBar 的歌词行（subLine）始终只显示第一句歌词，不随播放进度实时更新。

## 根因
`subLine` @Computed 中只取 `lyric.split('\n')[0]`，未搜索当前进度对应的歌词行；且未读取 `this.appState.progress`，导致进度变化时不触发重新计算。

## 修复目标
让 MiniPlayerBar 的 subLine 随播放进度实时显示当前对应的歌词行。


## 修改范围
仅修改 `common/musicbasic/src/main/ets/components/miniplayer/MiniPlayerBar.ets`

## 实现方案

### 1. 内联轻量 LRC 解析器
在 MiniPlayerBar 结构体内部添加私有方法和缓存字段，实现自包含的 LRC 解析：

- **缓存字段**：`cachedLyricText: string` 和 `cachedLrcEntries: Array<{time: number, text: string}>`
- **`parseLrcLyricForMiniBar(text: string)`**：用正则 `\[(\d+):(\d+(?:\.\d+)?)\](.*)` 逐行提取时间（分:秒转换为毫秒）和歌词文本，按时间升序排序后返回

### 2. 修改 subLine @Computed
```
1. 保持原有的 status 判断逻辑不变
2. 获取 lyricText，若为空则按原逻辑返回
3. 读取 this.appState.progress（使 @Computed 追踪进度变化）
4. 若 lyricText 与缓存不同 → 重新解析并更新缓存
5. 若无解析条目 → 回退到原首行逻辑
6. 遍历缓存条目，找到 lineStartTime <= progress 的最后一行 → 返回其 text
7. 若进度在所有行之前 → 返回首行 text
```

### 3. 性能考量
- `progress` 每 ~100ms 更新一次，`subLine` 随之重新计算
- 解析结果缓存在私有字段中，只在 `lyricText` 变化时触发解析
- 每次 @Computed 重算只做一次 ~O(n) 的缓行遍历（n 通常 < 100），无性能问题


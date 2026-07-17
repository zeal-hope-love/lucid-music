---
name: qq-music-audio-debug-logging
overview: 在 QQ 音乐音频播放链路的关键节点添加诊断日志，定位"QQ 源无声音"的根因。覆盖 AudioSourceExecutor → JsVmBridge → AudioEngine → PlaybackIntentDispatcher 全链路。
todos:
  - id: log-executor
    content: AudioSourceExecutor.ets getPlayUrl()：引擎/脚本未就绪时打印状态，sendRequest 返回后打印 result 结构
    status: completed
  - id: log-searchvm
    content: SearchResultViewModel.ets playSong()：jsvmResult 打印完整可用性（是否 null、各字段是否存在）
    status: completed
  - id: log-dispatcher
    content: PlaybackIntentDispatcher.ets dispatchShellPlaybackIntent()：打印 songItem.src 前100字符和长度
    status: completed
  - id: log-player
    content: AudioPlayerController.ets playCurrent()：打印传给 loadAndPlay 的 URL 前缀和长度
    status: completed
---

## 用户需求
QQ 音乐源点击播放后无音频输出，需要在播放链路的关键节点添加诊断日志，定位根因。

## 问题背景
QQ 音频播放有两条路径：
- **路径A（优先）**：JSVM 音源脚本 → AudioSourceExecutor → JsVmBridge → AudioEngine（C++ JSVM 引擎）
- **路径B（兜底）**：直接 HTTP API → TxMusicApi.getPlayUrl()

底层 AudioEngine 和 TxMusicApi 已有较完善的日志，但中间层的 AudioSourceExecutor、SearchResultViewModel、PlaybackIntentDispatcher、AudioPlayerController 存在关键日志缺口——当数据在这些层传递时若为空，完全没有痕迹。

## 修改目标
在 4 个关键缺口节点添加 Logger.info/warn 日志，打印引擎就绪状态、JSVM 返回结果结构、最终传入 AVPlayer 的 URL。

## 修改文件与策略

所有日志使用项目现有的 `Logger`（从 `musicbasic` 导入），日志级别：
- `info`：正常流程数据（引擎状态、URL 前缀）
- `warn`：异常但可恢复（返回 null、URL 为空）
- `error`：已有异常处理，不额外添加

### 1. AudioSourceExecutor.ets — getPlayUrl()
**缺口**：引擎/脚本就绪状态未打印，返回 null 时无痕迹；sendRequest 返回的 result 完整内容未打印。

**添加**：
- 第32行：返回 null 前打印 `engineReady` 和 `scriptInited` 状态
- 第43行前：打印 `result.url` 和 `result.data` 的 keys（用于诊断 JS 脚本返回结构）

### 2. SearchResultViewModel.ets — playSong()
**缺口**：jsvmResult 有 url 时仅打印长度，无 url 时完全不打印结构信息（无法判断是 JSVM 整体返回 null 还是 url 字段为空）。

**添加**：
- 第77行后：无论结果如何，都打印 `jsvmResult` 是否为 null，以及 `url/lyrics/cover` 是否存在

### 3. PlaybackIntentDispatcher.ets — dispatchShellPlaybackIntent()
**缺口**：第33行 `songItem.src = intentState.remoteUrl` 未打印，无法确认 AVPlayer 收到什么 URL。

**添加**：
- 第33行后：打印 `remoteUrl` 的前 100 字符和长度

### 4. AudioPlayerController.ets — playCurrent()
**缺口**：第275行 `const url: string = songItem.src` 后未打印实际 URL。

**添加**：
- 第275行后：打印 URL 前缀和长度

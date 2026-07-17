---
name: integrate-jsvm-audio-path
overview: 接入 JSVM 脚本引擎路径获取 QQ 音频 URL，对齐 MusicHome 的播放流程
todos:
  - id: fix-jsvm-bridge
    content: 把 features/player/src/main/ets/service/JsVmBridge.ets 从空壳改为功能完整模块（包装 AudioEngine，实现 init/sendRequest/executeScript/isEngineReady/isScriptInited）
    status: completed
  - id: fix-audio-executor
    content: 把 features/search/src/main/ets/service/AudioSourceExecutor.ets 从空壳改为通过 JsVmBridge 获取播放 URL 的服务
    status: completed
    dependencies:
      - fix-jsvm-bridge
  - id: integrate-playsong
    content: 修改 SearchResultViewModel.playSong()：优先走 AudioSourceExecutor.getPlayUrl()，失败回退 MusicApiService.getPlayUrl()
    status: completed
    dependencies:
      - fix-audio-executor
---

## 问题
QQ/网易云音频无法播放。MusicHome 能播放是因为用了 JSVM 引擎路径（C++ JSVM 执行 LX Music 音源脚本 → raw TCP socket 发 HTTP 请求获取音频 URL），而我们只有直接 API 路径。

## 现有资源
- `jsaudioengine` 模块的 `AudioEngine.ets` 已完整实现（init/executeScript/sendRequestToScript/isReady/isScriptInited/reset 等）
- 已通过 `Index.ets` 导出 `AudioEngine`
- `JsVmBridge.ets` 存在但为空壳（init 注释掉，无 AudioEngine 引用）
- `AudioSourceExecutor.ets` 存在但为空壳

## 修复目标
1. 用 `AudioEngine` 激活 `JsVmBridge`，实现 `sendRequest`/`executeScript`/`isEngineReady`/`isScriptInited` 等方法
2. 实现 `AudioSourceExecutor.getPlayUrl()`，通过 `JsVmBridge.sendRequest(source, 'musicUrl', info)` 获取音频 URL
3. `SearchResultViewModel.playSong()` 优先走 `AudioSourceExecutor`，失败时 fallback 到 `MusicApiService`


## 技术栈
- HarmonyOS ArkUI TypeScript
- C++ JSVM 引擎 (`libjsaudioengine.so`)
- LX Music 音源脚本
- AppStorageV2 状态管理

## 架构改造

### 修改前
```
SearchResultViewModel.playSong()
  → MusicApiService.getPlayUrl()       // 直接 API
    → TxMusicApi.tryJson/tryForm       // 只有这层
```

### 修改后
```
SearchResultViewModel.playSong()
  → AudioSourceExecutor.getPlayUrl()    // 【新】优先路径
    → JsVmBridge.sendRequest(source, 'musicUrl', info)
      → AudioEngine.sendRequestToScript()
        → C++ JSVM 执行音源脚本
          → raw TCP socket HTTP 请求 → 音频 URL
  → MusicApiService.getPlayUrl()        // fallback
```

## 修改文件：3 个

### 1. `features/player/src/main/ets/service/JsVmBridge.ets`

从空壳改为功能完整模块，对齐 MusicHome 的实现：

```typescript
import { AudioEngine } from 'jsaudioengine'
import { Logger } from 'musicbasic'

export interface ScriptRequestResult {
  source?: string; action?: string
  data?: Record<string, Object>; url?: string
}

export class JsVmBridge {
  private static instance: JsVmBridge | undefined
  private engine: AudioEngine = AudioEngine.getInstance()

  public static getInstance(): JsVmBridge { ... }
  public async init(): Promise<void> { await this.engine.init() }
  public async executeScript(script: string, id: string): Promise<boolean> { ... }
  public async sendRequest(source: string, action: string, info: object): Promise<ScriptRequestResult | null> { ... }
  public isEngineReady(): boolean { return this.engine.isReady() }
  public isScriptInited(): boolean { return this.engine.isScriptInited() }
}
```

关键方法：
- `init()` — 调用 `AudioEngine.init()` 创建 C++ JSVM 引擎
- `sendRequest(source, action, info)` — 通过 `AudioEngine.sendRequestToScript()` 向脚本发送请求，返回 `ScriptRequestResult`
- `executeScript(script, id)` — 执行音源脚本

### 2. `features/search/src/main/ets/service/AudioSourceExecutor.ets`

从空壳改为播放 URL 获取服务：

```typescript
import { JsVmBridge, ScriptRequestResult } from 'player'
import { Logger } from 'musicbasic'

export class AudioSourceExecutor {
  private static instance: AudioSourceExecutor | undefined
  private bridge: JsVmBridge = JsVmBridge.getInstance()

  public static getInstance(): AudioSourceExecutor { ... }
  public async getPlayUrl(songId: string, source: string): Promise<string | null> {
    if (!this.bridge.isEngineReady() || !this.bridge.isScriptInited()) { return null }
    const result = await this.bridge.sendRequest(source, 'musicUrl', {
      hash: songId, source: source, type: '128k'
    })
    return result?.url || (result?.data?.['url'] as string) || null
  }
}
```

### 3. `features/search/src/main/ets/viewmodel/SearchResultViewModel.ets`

修改 `playSong()` 方法，在 `MusicApiService.getPlayUrl()` 之前先尝试 `AudioSourceExecutor`：

```typescript
// 优先：通过 JSVM 音源脚本获取 URL
const jsvmUrl = await AudioSourceExecutor.getInstance().getPlayUrl(item.songId, item.source)
if (jsvmUrl) {
    this.intentState.remoteUrl = jsvmUrl
    // 封面和歌词仍走直接 API
    const fallback = await MusicApiService.getPlayUrl(item.songId, item.source, item.rawFields)
    if (fallback.lyrics) { this.intentState.remoteLyricText = fallback.lyrics }
    if (fallback.cover) { this.intentState.remoteSongCover = fallback.cover }
} else {
    // fallback：直接 API
    const result = await MusicApiService.getPlayUrl(item.songId, item.source, item.rawFields)
    // ... 原有逻辑 ...
}
```

### 设计要点
- `AudioSourceExecutor.getPlayUrl()` 返回 `null` 时（引擎未就绪/脚本未初始化/请求失败），自动 fallback
- 封面和歌词仍走直接 API（JSVM 脚本必须单独请求，增加延迟）
- 不影响酷狗等其他平台的现有逻辑
- `Index.aboutToAppear()` 中已调用 `JsVmBridge.getInstance().init()`，引擎在应用启动时初始化


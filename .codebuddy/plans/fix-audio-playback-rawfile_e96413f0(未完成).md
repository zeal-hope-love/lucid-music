---
name: fix-audio-playback-rawfile
overview: 修复音频不播放：AVPlayer.url 不能用纯文件名，改为 getRawFd + avPlayer.fdSrc 方式播放 rawfile 中的 mp3
todos:
  - id: fix-load-and-play
    content: 修改 AudioPlayerController.ets 的 loadAndPlay 方法：网络 URL 用 avPlayer.url，本地文件用 resourceManager.getRawFd + avPlayer.fdSrc
    status: pending
---

## 用户需求
修复点击歌曲后没有声音、进度条一直为 0 的问题。

## 根因
mp3 音频文件存放在 `common/musicbasic/src/main/resources/rawfile/`（HAR 模块），而 `entry/src/main/resources/rawfile/` 目录为空。`AudioPlayerController.loadAndPlay()` 方法中直接将纯文件名（如 `'Dream_It_Possible-Delacey.mp3'`）赋值给 `avPlayer.url`。AVPlayer.url 不支持裸文件名解析，无法定位到 HAR 模块的 rawfile 资源，导致播放失败。

## 核心功能
- 将 `loadAndPlay()` 中的 `avPlayer.url` 播放方式改为 `avPlayer.fdSrc`（通过 `resourceManager.getRawFd()` 获取文件描述符）
- 保留网络 URL 的 `avPlayer.url` 播放路径（当 src 以 `http://` 或 `https://` 开头时）

## 技术方案

### 实现思路
在 `loadAndPlay()` 中根据 src 类型分叉：
- **网络 URL**（以 `http://` / `https://` 开头）：沿用 `avPlayer.url` 设置
- **本地 rawfile 文件名**：通过 `resourceManager.getRawFd(filename)` 获取 `RawFileDescriptor`，设置 `avPlayer.fdSrc`

### 关键 API

| API | 用途 |
|-----|------|
| `resourceManager.getRawFd(filename)` | 打开 rawfile，返回 `RawFileDescriptor { fd, offset, length }` |
| `avPlayer.fdSrc` | AVPlayer 的文件描述符播放源属性 |

### 获取 Context
`EntryAbility.onCreate()` 第 14 行已执行 `AppStorage.setOrCreate('context', this.context)`，`loadAndPlay()` 中通过 `AppStorage.get('context') as common.UIAbilityContext` 即可获取。

### 改动文件
仅 1 个文件：`features/player/src/main/ets/controller/AudioPlayerController.ets`

### 改动内容
1. `loadAndPlay(url)` 中，判读 `url` 是否以 `http://` / `https://` 开头
2. 是网络 URL → `avPlayer.url = url`（保持原逻辑）
3. 否则 → `resourceManager.getRawFd(url)` → `avPlayer.fdSrc = { fd: rawFileDescriptor.fd, offset: rawFileDescriptor.offset, length: rawFileDescriptor.length }`
4. 需导入 `common` from `@kit.AbilityKit`

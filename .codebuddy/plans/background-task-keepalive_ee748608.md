---
name: background-task-keepalive
overview: 为 lucid_music 音乐播放器添加后台长时任务保活机制。参考 avplayer-play-formatted-audio-arkts 项目，实现播放时申请后台长时任务、暂停/停止时取消后台任务，防止后台播放 1-2 分钟后被系统杀死。
todos:
  - id: add-permission-config
    content: 在 module.json5 中添加 ohos.permission.KEEP_BACKGROUND_RUNNING 权限声明及 reason 字符串资源
    status: completed
  - id: create-background-util
    content: 新建 BackgroundUtil.ets 后台任务工具类，封装 startContinuousTask 和 stopContinuousTask
    status: completed
  - id: integrate-player-controller
    content: 在 AudioPlayerController 的 play/pause/release 方法中集成后台长时任务启停
    status: completed
    dependencies:
      - create-background-util
  - id: export-background-util
    content: 在 features/player/Index.ets 中导出 BackgroundUtil
    status: completed
    dependencies:
      - create-background-util
---

## 用户需求
解决音乐播放器进入后台 1-2 分钟后被系统杀死的问题。需要利用 `backgroundTaskManager` 申请音频播放长时任务（Continuous Task），确保后台播放稳定保活。

## 核心功能
- 申请 `ohos.permission.KEEP_BACKGROUND_RUNNING` 权限，声明音频播放后台模式
- 创建 `BackgroundUtil` 工具类，封装 `backgroundTaskManager.startBackgroundRunning` 和 `stopBackgroundRunning` 调用
- 在 `AudioPlayerController` 播放时启动后台长时任务，暂停/停止/释放时取消后台长时任务
- 提供权限授权说明文案

## 技术方案

### 实现策略
参考华为官方示例项目 `avplayer-play-formatted-audio-arkts` 的实现模式：通过 `backgroundTaskManager` 在播放/暂停时申请/取消 `BackgroundMode.AUDIO_PLAYBACK` 类型的连续任务，结合 `wantAgent` 提供回跳入口，确保系统不会在后台杀死音频播放进程。

### 关键技术决策

1. **权限声明**：在 `module.json5` 中同时配置 `requestPermissions`（`ohos.permission.KEEP_BACKGROUND_RUNNING`）和 `backgroundModes: ["audioPlayback"]`，两者缺一不可
2. **任务生命周期**：严格与播放状态绑定 —— play 时 start，pause/release 时 stop。避免空闲时持有后台任务导致不必要的电量消耗
3. **Context 获取**：通过 `AppStorage.get('context')` 获取 `UIAbilityContext`（项目已在 `EntryAbility.onCreate` 中存入），无需修改 EntryAbility
4. **工具类位置**：放在 `features/player/src/main/ets/utils/` 下，与现有 utils 目录结构一致，通过 `features/player/Index.ets` 统一导出

### 性能与可靠性
- `wantAgent.getWantAgent` 为异步操作，不影响播放主流程；创建后缓存 wantAgent 不重复创建
- 使用 try-catch 包裹所有 API 调用，避免后台任务申请失败时影响正常播放
- `stopBackgroundRunning` 在 `release()` 中确保资源释放，防止内存泄漏

### 代码影响范围
| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `entry/src/main/module.json5` | 修改 | 添加权限声明 |
| `entry/src/main/resources/base/element/string.json` | 修改 | 添加权限说明文案 |
| `features/player/src/main/ets/utils/BackgroundUtil.ets` | 新建 | 后台任务工具类 |
| `features/player/src/main/ets/controller/AudioPlayerController.ets` | 修改 | 集成后台任务启停 |
| `features/player/Index.ets` | 修改 | 导出 BackgroundUtil |

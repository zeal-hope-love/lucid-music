---
name: fix-playback-order-switching
overview: 修复媒体中心切换播放顺序只能同步显示不能实际切换的问题。核心原因是 lucid_music 的 AVSessionController.onSetLoopMode 中使用了"直接映射"，而参考项目使用了"错位映射"。
todos:
  - id: fix-loopmode-mapping
    content: 修改 AVSessionController.ets 中 onSetLoopMode 的映射逻辑，将直接映射改为错位映射（SINGLE→ORDER, SEQUENCE→RANDOM, SHUFFLE→SINGLE_CYCLE），并使用 switch 语句对齐参考项目风格
    status: completed
---

## 用户需求
修复媒体中心（系统控制中心/锁屏）播放顺序切换功能：当前在控制中心点击播放模式按钮时，播放图标能同步显示当前模式，但点击后无法实际切换到下一个播放模式。

## 核心问题
`AVSessionController.ets` 中 `onSetLoopMode` 回调使用了直接映射（`avSession.LoopMode` → `MusicPlayMode`），而参考项目使用错位映射。系统控制中心的三态循环（SEQUENCE→SHUFFLE→SINGLE→SEQUENCE）与 App 内部的三态循环（ORDER→RANDOM→SINGLE_CYCLE→ORDER）需要通过错位映射对齐，才能确保用户在控制中心每次点击都能实际推进播放模式。

## 修复范围
- 修改 `AVSessionController.ets` 中 `onSetLoopMode` 回调的映射逻辑，从直接映射改为错位映射

## 技术方案

### 修复方式
将 `AVSessionController.ets` 中 `onSetLoopMode` 的回调映射从直接映射改为错位映射，对齐参考项目 `avplayer-play-formatted-audio-arkts` 的实现。

### 映射对照

**当前（直接映射 - 有问题）：**
| 系统 LoopMode | → | App MusicPlayMode |
|---|---|---|
| LOOP_MODE_SINGLE | → | SINGLE_CYCLE |
| LOOP_MODE_SEQUENCE | → | ORDER |
| LOOP_MODE_SHUFFLE | → | RANDOM |

**目标（错位映射 - 正确）：**
| 系统 LoopMode | → | App MusicPlayMode |
|---|---|---|
| LOOP_MODE_SINGLE | → | ORDER |
| LOOP_MODE_SEQUENCE | → | RANDOM |
| LOOP_MODE_SHUFFLE | → | SINGLE_CYCLE |

### 原理
系统控制中心三态循环：SEQUENCE → SHUFFLE → SINGLE → SEQUENCE

App 内部三态循环：ORDER → RANDOM → SINGLE_CYCLE → ORDER

用户在控制中心每点击一次，系统自动循环到下一模式并触发回调。错位映射确保 App 也推进到下一模式，且 `setPlayModeToAVSession` 写回的 LoopMode 与系统当前状态不同（因为映射是错位的），系统能正确检测到状态变化并应用。

### 修改文件
- `features/player/src/main/ets/controller/AVSessionController.ets`：仅修改第194-208行的 `onSetLoopMode` 方法体

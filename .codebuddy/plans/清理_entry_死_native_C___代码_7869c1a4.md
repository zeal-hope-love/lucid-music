---
name: 清理 entry 死 native C++ 代码
overview: 删除 entry 模块中无用的 Native C++（DevEco 默认模板 add 函数），仅清理 native 部分；应用入口 EntryAbility 保留在 entry 不动。真正的 native 音频引擎在 js_audio_engine（libjsaudioengine.so），不受影响。
todos:
  - id: delete-entry-cpp
    content: 删除 entry/src/main/cpp 整个目录（napi_init.cpp、CMakeLists.txt、types/libentry）
    status: completed
  - id: clean-entry-config
    content: 移除 entry/build-profile.json5 的 externalNativeOptions 与 oh-package.json5 的 libentry.so 依赖
    status: completed
    dependencies:
      - delete-entry-cpp
  - id: verify-cleanup
    content: 全局搜索 libentry 验证无残留，并确认 entry 模块可正常编译
    status: completed
    dependencies:
      - clean-entry-config
---

## 用户需求
清理 `entry` 模块中无用的 Native C++ 代码，降低构建复杂度，且不影响应用运行。

## 产品概述
`entry/src/main/cpp/` 是 DevEco Studio 创建工程时自动生成的默认 Native C++ 模板，仅实现演示用的 `add(a,b)` 函数并注册模块名 `"entry"`，全工程无任何 ArkTS 代码调用它，属于死代码。真正的 native 音频引擎独立存在于 `js_audio_engine` 模块（`libjsaudioengine.so`），与本次改动无关。

## 核心特性
- 删除 `entry/src/main/cpp/` 整个目录（含 `napi_init.cpp`、`CMakeLists.txt`、`types/libentry/`）。
- 移除 `entry/build-profile.json5` 中指向已删 `CMakeLists.txt` 的 `externalNativeOptions` 配置块。
- 移除 `entry/oh-package.json5` 中对 `libentry.so` 的依赖声明。
- 应用入口 `EntryAbility`、pages、resources 全部保留，应用入口行为不变。
- 真正的 native 链路（`js_audio_engine` → `libjsaudioengine.so` → `AudioEngine.ets` → `JsVmBridge.ets`）不受影响。

## 技术栈
- 平台：HarmonyOS ArkUI（Stage 模型），原生模块通过 NAPI + CMake 构建。
- 受影响模块：`entry`（仅清理其 native 部分）。
- 不受影响模块：`js_audio_engine`（真实 native 引擎）、`features/player`、`features/search`、`common/musicbasic`。

## 实现方案
采用「删除死代码 + 解除配置引用」的最小化清理策略。不改动任何运行时代码，仅移除从未被调用的 native 产物及其构建/依赖声明，使 `entry` 回归纯 ArkTS entry 模块。

### 关键决策
1. **只删 native 部分，不删 entry 模块**：经用户确认，应用入口 `EntryAbility` 暂不迁移，保留 entry 作为 entry HAP。
2. **整目录删除 `entry/src/main/cpp`**：该目录所有文件（`napi_init.cpp`、`CMakeLists.txt`、`types/libentry/Index.d.ts`、`types/libentry/oh-package.json5`）均只为生成 `libentry.so` 服务，无任何其他引用，可整体移除。
3. **同步清理两处配置**：`build-profile.json5` 的 `externalNativeOptions`（path 指向已删的 CMakeLists，不删会导致构建报错）；`oh-package.json5` 的 `libentry.so` 依赖（否则包依赖解析会失败）。

### 性能与可靠性
- 删除后 `entry` 不再触发 CMake/native 编译，构建时间缩短，产物体积减小。
- 无运行时行为变化，零回归风险；`js_audio_engine` 的 native 编译完全独立，不受影响。
- 验证手段：全局搜索 `libentry` 应无残留；重新编译 `entry` 模块应成功。

## 实现注意事项
- 删除前确认全局无 `libentry` / `import 'libentry.so'` / `from 'libentry.so'` 引用（已查证命中数为 0）。
- `entry/src/main/module.json5` 无 `nativeLib` 引用，ability 配置与 native 无关，无需改动。
- `build-profile.json5` 中 `buildOptionSet.release.nativeLib.debugSymbol` 属于无害配置，native 移除后失效但不会影响构建，可保留也可一并清理（建议保留以避免无关改动扩散）。
- 禁止删除 `.codebuddy` 目录及无关文件，仅针对 entry native 相关文件。

## 架构影响
清理后模块依赖关系不变：
- `entry`（纯 ArkTS）→ 依赖 `musicbasic`/`player`/`search`/`home`/`musichall`/`mine`。
- `player`/`search` → 依赖 `jsaudioengine` HAR（独立 native）。

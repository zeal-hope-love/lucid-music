---
name: fix-kg-songlist-build-errors
overview: 修复 kg/songList.ets 中 decodeGcid 函数的变量重名导致的 4 个 ArkTS 编译错误，使 entry 模块 assembleHap 构建通过。
todos:
  - id: fix-kg-songlist-body
    content: 重命名 decodeGcid 行 243 body 为 respBody 并同步行 244 索引访问
    status: completed
  - id: remove-duplicate-return
    content: 删除 resolveKgLinkAndFetch 行 348 重复的 return 语句
    status: completed
    dependencies:
      - fix-kg-songlist-body
  - id: verify-build
    content: 重新执行 assembleHap 确认 kg/songList.ets 无 ERROR 且构建成功
    status: completed
    dependencies:
      - fix-kg-songlist-body
      - remove-duplicate-return
---

## 用户需求
修复 lucid_music 项目 `entry` 模块 `assembleHap` 构建失败的问题。

## 核心问题
构建失败并非通用构建流程问题，而是 `common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets` 中 `decodeGcid` 函数存在 4 个真实 ArkTS 编译错误，导致 `CompileArkTS` 阶段失败。日志中其余 202 条均为 WARN（确定赋值断言、可能抛异常、弃用 API），不会阻断构建。

## 修复内容
- 解决 `decodeGcid` 函数内 `body` 变量在同一作用域被重复声明（行 229 与行 243）导致的重名错误。
- 修复因重名导致 `body['list']` 被解析为 `KgBatchDecodeBody` 类实例、触发索引访问受限（`arkts-no-props-by-index`）错误。
- 清理 `resolveKgLinkAndFetch` 函数中行 347-348 重复的 `return parseOutputJson(data, limit)`（第二行不可达）。
- 修复后重新构建，确认该文件无 ERROR、整体构建 COMPILE RESULT 为 SUCCESS。


## 技术栈
- HarmonyOS ArkUI / ArkTS（严格模式），hvigor 构建工具
- 目标文件：`common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets`

## 实现方案
### 问题根因
`decodeGcid`（行 223-255）函数作用域内：
- 行 229：`const body = new KgBatchDecodeBody()` 第一次声明 `body`，用于构造请求体（`body.ret_info = 1`、`body.data = [item]`、`JSON.stringify(body)`）。
- 行 243：`const body: Record<string, Object> = JSON.parse(...)` 第二次声明 `body`，与行 229 冲突，触发 `Cannot redeclare block-scoped variable 'body'` 与 Rollup `Identifier 'body' has already been declared`。
- 行 244：`const rlist = body['list'] as Record<string, Object>[]`，因 `body` 被解析为第一个 `KgBatchDecodeBody` 类型（无 `list` 字段），类实例的索引访问不被 ArkTS 允许，触发 `arkts-no-props-by-index`。

### 关键决策
1. **重命名而非重构**：将行 243 的 `const body` 改为 `const respBody`，行 244 的 `body['list']` 同步改为 `respBody['list']`。`Record<string, Object>` 的索引访问在 ArkTS 中合法（与文件其余处 `body['xxx']` 用法一致），重名消除后索引访问错误一并消失。最小改动、零风险，避免引入新逻辑。
2. **清理不可达代码**：删除行 348 重复的 `return parseOutputJson(data, limit)`，保留行 347 的有效返回，消除冗余。

### 实现要点
- 仅修改 `decodeGcid` 与 `resolveKgLinkAndFetch` 两处，不涉及其它模块，blast radius 极小。
- 保持 `KgBatchDecodeBody` 类与 `signatureParams` 请求逻辑不变，行为完全等价。
- 不处理 WARN（非阻断），避免无关改动引入回归。

## 目录结构（受影响文件）
```
common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets  # [MODIFY] decodeGcid 内 body 重命名为 respBody（行 243-244）；删除 resolveKgLinkAndFetch 行 348 重复 return
```


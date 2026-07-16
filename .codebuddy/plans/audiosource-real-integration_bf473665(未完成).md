---
name: audiosource-real-integration
overview: 将假数据音源管理接入真实功能：基于 MusicHome 项目的 AudioSourceManager/AudioSourceDb 架构，实现脚本文件导入（在线/本地）、JSDoc 元数据解析、Preferences 持久化、激活切换、删除等完整生命周期。
todos:
  - id: extend-model
    content: 扩展 search/.../model/AudioSourceModel.ets：添加 version、author、source、url、filePath、enabled、importedAt、description 字段
    status: pending
  - id: create-db
    content: 新建 search/.../model/AudioSourceDb.ets：Preferences 单例，getAll/saveAll + JSON 序列化/反序列化 + 内存缓存
    status: pending
    dependencies:
      - extend-model
  - id: rewrite-manager
    content: 重写 search/.../service/AudioSourceManager.ets：importFromUrl、importFromLocal、saveScript、parseScriptMeta(JSDoc)、toggleEnabled、deleteSource、getActiveScript
    status: pending
    dependencies:
      - create-db
  - id: update-search-index
    content: 更新 search/Index.ets：导出 AudioSourceDb
    status: pending
    dependencies:
      - rewrite-manager
  - id: rewrite-ui-and-delete-fake
    content: 删除 mine/.../model/AudioSourceModel.ets，重写 mine/.../view/AudioSourceSection.ets：从 search 导入，对接 AudioSourceManager 真实数据
    status: pending
    dependencies:
      - update-search-index
---

## 用户需求
将音源管理从假数据升级为真实功能，参考 lx-music-mobile 和 MusicHome 的架构。实现：在线导入（URL 下载 JS 脚本）、本地导入（文件选择器）、JSDoc 元数据解析、Preferences 持久化存储、互斥激活、删除。

## 实现范围
利用 lucid_music 已有的骨架（`search` 模块的 `AudioSourceManager`、`AudioSourceModel`），填充真实逻辑。`EntryAbility` 已初始化 `AudioSourceManager` 和 `JsVmBridge`，无需改动入口。脚本执行（JSVM）暂留骨架，后续接入。

## 核心功能
- 在线导入：输入 URL → HTTP 下载 JS 脚本 → 解析 JSDoc 元数据 → 保存到沙箱 → 持久化
- 本地导入：文件选择器选 .js 文件 → 读取内容 → 解析 JSDoc → 保存
- JSDoc 解析：支持 LX Music 格式块注释 `/* @name/@version/@author/@description */` 和行注释 `// @key value`
- Preferences 持久化：JSON 序列化存储，单例内存缓存
- 互斥激活：同时只能一个音源 `enabled=true`
- 删除：清理沙箱文件 + 持久化记录

## 技术栈
- ArkTS + ArkUI V2
- `@kit.ArkData` (preferences)
- `@kit.CoreFileKit` (fileIo, picker)
- `@kit.NetworkKit` (http)
- 单例模式 (AudioSourceManager, AudioSourceDb)

## 架构设计

```
search 模块（数据 + 服务层）
├── model/
│   ├── AudioSourceModel.ets  [EXTEND]  完整字段
│   └── AudioSourceDb.ets     [NEW]     Preferences 单例
├── service/
│   ├── AudioSourceManager.ets [REWRITE] 导入/激活/删除/JSDoc
│   └── AudioSourceExecutor.ets [KEEP]  脚本执行（后续接入）

mine 模块（UI 层）
├── model/AudioSourceModel.ets [DELETE]  假数据文件删除
└── view/AudioSourceSection.ets [REWRITE] 对接 search 模块
```

## 数据模型扩展

```typescript
export class AudioSourceModel {
  public id: string = ''          // 唯一ID (src_timestamp)
  public name: string = ''        // JSDoc @name
  public version: string = ''     // JSDoc @version
  public author: string = ''      // JSDoc @author
  public source: 'online' | 'local' = 'local'
  public url: string = ''         // 在线导入原始URL
  public filePath: string = ''    // 沙箱中脚本路径
  public enabled: boolean = false // 是否激活
  public importedAt: number = 0   // 导入时间戳
  public description: string = '' // JSDoc @description
}
```

## 实现细节

### AudioSourceDb.ets（持久化层）
- `init(context)`：`preferences.getPreferences(context, 'audiosource_store')`
- `getAll()`：从 Preferences 读 JSON 反序列化，内存缓存加速
- `saveAll(sources)`：JSON 序列化 + `put` + `flush`，同步更新缓存

### AudioSourceManager.ets（业务逻辑层）
- `importFromUrl(url)`：HTTP GET 下载脚本（Referer 头 + UA），调用 `saveScript`
- `importFromLocal(filePath)`：`fs.readTextSync` 读取，调用 `saveScript`
- `saveScript(name, content, source, url)`：写文件到 `{filesDir}/audiosources/` → 解析 JSDoc → 创建 Model → 持久化
- `parseScriptMeta(content)`：先匹配 `/* ... */` 块注释，再回退 `// @key value` 行注释，提取 @name/@version/@author/@description
- `toggleEnabled(id, enabled)`：互斥逻辑（启用时禁用其他所有）
- `deleteSource(id)`：`fs.unlinkSync` 删文件 + 持久化删除记录
- `getActiveScript()`：查找 `enabled` 的源，读取文件内容返回

### AudioSourceSection.ets（UI 改造）
- 删除 `import { ... } from '../model/AudioSourceModel'`
- 改为 `import { AudioSourceModel, AudioSourceManager } from 'search'`
- `aboutToAppear` 改为 `AudioSourceManager.getInstance().getAll()` 加载数据
- `onLocalImport` 改为调用 `manager.importFromLocal(filePath)`
- `onOnlineImport` 改为调用 `manager.importFromUrl(url)`
- `onDelete` 改为调用 `manager.deleteSource(id)`
- `onSelect` 改为调用 `manager.toggleEnabled(id, true)`
- `InitStatus` 枚举保留在 AudioSourceSection 内部（UI 状态与业务分离）
- 初始化状态模拟暂时保留（后续接入 JsVmBridge 后改为真实状态）

### 文件存储目录
```
{context.filesDir}/audiosources/
  source_1700000000000.js
  source_1700000000001_my_source.js
```

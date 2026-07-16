---
name: audiosource-real-integration
overview: 在 common/musicbasic 中新建音源管理核心（Model/DB/Manager），mine 模块 UI 对接真实数据，实现脚本导入/JSDoc解析/持久化/互斥激活/删除完整生命周期。
todos:
  - id: create-common-model
    content: 在 common/musicbasic/src/main/ets/model 新建 AudioSourceModel.ets
    status: completed
  - id: create-common-db
    content: 在 common/musicbasic/src/main/ets/service 新建 AudioSourceDb.ets
    status: completed
    dependencies:
      - create-common-model
  - id: create-common-manager
    content: 在 common/musicbasic/src/main/ets/service 新建 AudioSourceManager.ets
    status: completed
    dependencies:
      - create-common-db
  - id: update-musicbasic-index
    content: 更新 common/musicbasic/Index.ets 导出新类
    status: completed
    dependencies:
      - create-common-manager
  - id: cleanup-search-and-entry
    content: 清理 search 模块旧文件 + 更新 EntryAbility import 路径
    status: completed
    dependencies:
      - update-musicbasic-index
  - id: rewrite-mine-ui
    content: 删除 mine 假数据文件 + 重写 AudioSourceSection.ets 对接真实数据
    status: completed
    dependencies:
      - cleanup-search-and-entry
---

## 产品概述
将音源管理从假数据升级为真实功能，核心逻辑迁移到 common/musicbasic 模块，参考 MusicHome 项目的 AudioSourceManager/AudioSourceDb 完整实现。

## 核心功能
- 在线导入：URL 下载 JS 脚本 → HTTP GET（Referer+UA，60s 超时）→ JSDoc 解析 → 保存沙箱 → Preferences 持久化
- 本地导入：DocumentViewPicker 选文件 → fs.readTextSync 读取 → JSDoc 解析 → 保存
- JSDoc 解析：支持 LX Music 块注释 /* @name/@version/@description */ 和行注释 // @key value
- Preferences 持久化：JSON 序列化 + flush，单例内存缓存
- 互斥激活：同时仅一个音源 enabled=true
- 删除：fs.unlinkSync 清理文件 + 持久化移除记录

## 架构调整
所有 AudioSource 核心从 search 模块迁移到 common/musicbasic，search 保留 MusicApiService 不动（只做搜索元数据）。

## 技术栈
- ArkTS + ArkUI V2
- @kit.ArkData (preferences)
- @kit.CoreFileKit (fileIo, picker)
- @kit.NetworkKit (http)
- 单例模式 (AudioSourceManager, AudioSourceDb)

## 文件改动

### 新建文件
```
common/musicbasic/src/main/ets/model/AudioSourceModel.ets    # 数据模型
common/musicbasic/src/main/ets/service/AudioSourceDb.ets     # Preferences 持久化
common/musicbasic/src/main/ets/service/AudioSourceManager.ets # 业务逻辑
```

### 修改文件
```
common/musicbasic/Index.ets                    # 新增导出
entry/entryability/EntryAbility.ets             # import 从 search 改 musicbasic
features/search/Index.ets                       # 移除过期导出
features/mine/src/main/ets/view/AudioSourceSection.ets  # 对接真实数据
```

### 删除文件
```
features/search/src/main/ets/model/AudioSourceModel.ets     # 旧空壳
features/search/src/main/ets/service/AudioSourceManager.ets  # 旧空壳
features/mine/src/main/ets/model/AudioSourceModel.ets       # 假数据
```

### 保留不动
```
features/search/src/main/ets/service/MusicApiService.ets    # 搜索API
features/search/src/main/ets/service/AudioSourceExecutor.ets # JSVM执行器骨架
features/mine/src/main/ets/view/SettingsPage.ets            # 设置页
```

## 数据模型
```typescript
class AudioSourceModel {
  id: string = ''          // src_timestamp
  name: string = ''        // JSDoc @name
  version: string = ''     // JSDoc @version
  source: 'online'|'local' = 'local'
  url: string = ''         // 在线导入原始URL
  filePath: string = ''    // 沙箱路径
  enabled: boolean = false // 互斥激活
  importedAt: number = 0   // 时间戳
  description: string = '' // JSDoc @description
}
```

## AudioSourceSection UI 对接改动
- import 从 `../model/AudioSourceModel` 改为 `from 'musicbasic'` 导入 AudioSourceModel 和 AudioSourceManager
- `@Local sources` 类型改为 `AudioSourceModel[]`，初始化空数组
- `aboutToAppear`：调用 `AudioSourceManager.getInstance().getAll()` 异步加载
- `onLocalImport`：调用 `manager.importFromLocal(filePath)`，then 刷新列表
- `onOnlineImport`：调用 `manager.importFromUrl(url)`，then 刷新列表
- `onDelete`：调用 `manager.deleteSource(id)`，then 刷新列表
- `onSelect`：调用 `manager.toggleEnabled(id, true)`，then 刷新列表
- InitStatus 枚举保留在 AudioSourceSection 内部（UI 状态与业务分离）
- 初始化状态模拟暂时保留（后续接入 JsVmBridge 改为真实）

## Agent Extensions

### SubAgent
- **code-explorer**
  - Purpose: 验证 common/musicbasic 的服务目录结构和现有文件
  - Expected outcome: 确认 service 目录存在或需创建，确认无文件冲突

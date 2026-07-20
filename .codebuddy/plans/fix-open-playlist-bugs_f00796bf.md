---
name: fix-open-playlist-bugs
overview: 修复两个 bug：(1) 打开歌单弹窗未跟随当前平台 Tab 切换，导致 source 写死为初始值 kw；(2) kg/tx 解析返回 0 首，是因 source 错误导致平台 SDK 调度错误。
todos:
  - id: fix-dialog-source
    content: 修复 MusicHallPage 弹窗 source 动态化：onConfirm 内直接取 this.activeSource，PlaylistOpenModal builder 移除 source 传参
    status: completed
  - id: simplify-modal
    content: "精简 PlaylistOpenModal：移除 source 属性，新增 sourceLabel 展示当前平台名，onConfirm 签名简化为 (id: string) => void"
    status: completed
    dependencies:
      - fix-dialog-source
  - id: enhance-kg-parse
    content: 增强 kg/songList.ets parsePlaylistId：增加 special/single/{id} 的显式正则匹配
    status: completed
  - id: enhance-tx-parse
    content: 增强 tx/songList.ets parsePlaylistId：增加 taoge.html?id={id} 的显式正则匹配
    status: completed
---


## 问题背景
用户发现两个 Bug：
1. 打开歌单弹窗的 source 不跟随音乐厅平台 Tab 切换，始终固定为初始值 `'kw'`
2. 在酷狗、QQ 音乐平台输入分享链接后，返回 0 首歌曲

## 根因
`MusicHallPage.ets` 在 `aboutToAppear()` 中创建 `CustomDialogController` 时，`PlaylistOpenModal({ source: this.activeSource, ... })` 将当时的 `this.activeSource`（默认 `'kw'`）固定传入弹窗。后续用户切换到 kg/tx 平台，弹窗内部 `source` 仍为 `'kw'`。

错误链路：用户选 kg → 输入 kg 链接 → `onConfirm('kw', kgUrl)` → `SongListParam` 的 `source='kw'` → `ApiSource.getPlaylistSongs('kw', kgUrl)` → kw 的 `parsePlaylistId` 无法解析 kg URL 格式 → kw API 失败 → 返回 0 首。

## 修复要点
1. 弹窗 source 动态化：onConfirm 内取 `this.activeSource` 而非固化参数
2. PlaylistOpenModal 简化回调签名：`(id: string) => void`，移除冗余 source 参数
3. 弹窗内显示当前平台名称，便于用户确认平台对应关系



## 修复方案

### 修复 1：MusicHallPage — 弹窗 source 动态化
- **文件**：`features/musichall/src/main/ets/view/MusicHallPage.ets`
- **改动**：
  - `PlaylistOpenModal` builder 不再传入 `source` 属性
  - `onConfirm` 回调不再接收 `source` 参数，改为内部直接使用 `this.activeSource`（运行时当前值）
  - `onConfirm` 签名从 `(source: string, id: string) => void` 简化为 `(id: string) => void`

### 修复 2：PlaylistOpenModal — 签名精简 + 平台显示
- **文件**：`features/musichall/src/main/ets/view/PlaylistOpenModal.ets`
- **改动**：
  - 移除 `source: string` 属性，新增 `sourceLabel: string = ''`（纯展示，不参与逻辑）
  - `onConfirm` 签名为 `(id: string) => void`
  - 弹窗标题下方增加当前平台标签：`行 · 当前平台：酷狗`，帮助用户确认跨源限制
  - 确认按钮直接调用 `this.onConfirm(id)`

### 修复 3：parsePlaylistId 鲁棒性增强
kg 和 tx 的 `parsePlaylistId` 其实现有正则已覆盖常见格式（纯数字、带 playlsit/{id} 路径、带 ?id={id} 参数）。但需在 **结尾兜底处加约束**：当未匹配任何已知格式且输入明显不是纯数字时，保留 URL 中的 path 最后一段数字作为 ID 尝试。

- **文件**：`common/musicbasic/src/main/ets/util/musicSdk/kg/songList.ets`
  - 对包含 `special/single/{id}` 的 URL 增加显式正则以覆盖酷狗 PC 分享链接
- **文件**：`common/musicbasic/src/main/ets/util/musicSdk/tx/songList.ets`
  - 对 `/share/details/taoge.html?id={id}` 格式增加显式正则

## 变更文件清单

```
features/musichall/src/main/ets/view/MusicHallPage.ets    [MODIFY] 弹窗创建逻辑：动态取 activeSource
features/musichall/src/main/ets/view/PlaylistOpenModal.ets [MODIFY] 移除 source 参数，新增 sourceLabel，简化 onConfirm
common/musicbasic/.../musicSdk/kg/songList.ets            [MODIFY] parsePlaylistId 增加 special/single 正则
common/musicbasic/.../musicSdk/tx/songList.ets            [MODIFY] parsePlaylistId 增加 taoge.html 正则
```


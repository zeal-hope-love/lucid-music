---
name: player-background-cover-image
overview: 修复播放详细页背景：对远程歌曲使用 coverUrl 下载封面图来提取背景色和生成模糊背景，替换当前使用 label 默认占位符导致的黑色背景问题。
todos:
  - id: fix-background-cover
    content: 修改 PlayerInfoComponent.ets：getImageColor() 增加 coverUrl 分支（http 下载封面 → PixelMap → 提取主色调 + 模糊背景），label 作为兜底；LG 布局封面图同步适配 coverUrl
    status: completed
---

## 用户需求
播放详细页背景颜色：远程歌曲（在线搜索播放）背景显示为黑色，只有本地歌曲 "Dream It Possible" 背景正常。要求背景使用歌曲真实封面图。

## 产品概述
将播放详细页背景从基于本地 Resource 取色改为优先使用远程封面 URL（coverUrl），下载封面图提取主色调并生成模糊背景。

## 核心功能
- 远程歌曲播放时，通过 http 下载 coverUrl 对应的封面图
- 从下载的封面 PixelMap 中提取主色调作为页面背景色
- 将封面图模糊处理后作为背景图叠加层
- coverUrl 不可用时回退到原有 label 逻辑
- LG 大屏布局的封面图同步适配 coverUrl

## 技术栈
- HarmonyOS ArkUI (TypeScript)
- @kit.NetworkKit (http) - 下载远程封面图
- @kit.ImageKit (image) - 创建 PixelMap
- @kit.ArkGraphics2D (effectKit) - 提取主色调 + 模糊处理

## 实现方案

### 核心策略
修改 `getImageColor()` 方法，增加 coverUrl 优先分支。当 `songItem.coverUrl` 存在且非空时，通过 http 下载图片二进制数据，创建 ImageSource → PixelMap，然后复用现有的颜色提取和模糊处理逻辑。coverUrl 不可用或下载失败时回退到原有 `label` Resource 逻辑。

### 关键决策
1. **下载方式**：使用 `http.createHttp().request(url, { expectDataType: http.HttpDataType.ARRAY_BUFFER })` 获取封面图二进制数据，与现有 `getMediaContent` 返回 Uint8Array 的处理方式一致，可复用已有 PixelMap 处理流程
2. **回退策略**：coverUrl 存在但下载失败时，回退到 label 逻辑，保证不出现无背景情况
3. **状态更新**：下载完成后的 `imageLabel`（模糊后 PixelMap）和 `imageColor` 通过 @State 响应式更新触发 UI 重绘

### 实现细节
- `imageLabel` 类型已是 `PixelMap | Resource`，下载后设置为 PixelMap 无需改类型
- `getImageColor()` 为 async 链式调用，添加 http 下载后用 `.then()` 串联现有 PixelMap 处理逻辑
- 封面图下载仅触发一次（通过 `@Watch('selectIndex')` 控制），避免重复请求
- LG 布局第 138 行封面图改为三级 fallback：`coverUrl → label → 空白`

## 文件结构
```
features/player/src/main/ets/view/
└── PlayerInfoComponent.ets  # [MODIFY] getImageColor() 增加 coverUrl 下载分支；LG 布局封面适配
```

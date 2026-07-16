---
name: fix-musiclist-param-and-audio
overview: 修复 MusicListPage 三个入口显示同一列表和音频不播放两个 bug
todos:
  - id: fix-index-param
    content: Index.ets 中 MusicListPage 接收 _param 并传入
    status: completed
  - id: fix-musiclist-prop
    content: MusicListPage.ets 改为 @Prop 接收 param，移除兜底分支
    status: completed
    dependencies:
      - fix-index-param
  - id: fix-audio-rawfd
    content: AudioPlayerController.ets loadAndPlay 改为网络 URL/本地 rawfile 分叉处理
    status: completed
---

## 问题描述
1. **三个入口列表相同**：点击"本地""最近播放""收藏"三个入口进入 MusicListPage，始终显示相同的歌曲列表（本地2首）
2. **收藏不按红心过滤**：点亮红心收藏的歌曲没有单独出现在收藏列表中
3. **没有音频播放**：点击歌曲后无声音，进度条不动

## 根因分析

| Bug | 根因 | 涉及文件 |
|-----|------|----------|
| 列表相同 | `Index.ets` 的 `navDestinationBuilder(_, _param)` 中 `MusicListPage()` 没有接收 `_param`，导致 `aboutToAppear` 永远收到 `undefined`，触发兜底分支 `getSongList()` | Index.ets, MusicListPage.ets |
| 没音频 | mp3 在 `common/musicbasic` HAR 模块的 rawfile 中，`entry` 模块 rawfile 为空。`AudioPlayerController.loadAndPlay()` 将纯文件名 `'Dream_It_Possible-Delacey.mp3'` 赋值给 `avPlayer.url`，AVPlayer 不支持裸文件名解析 rawfile 资源 | AudioPlayerController.ets |


## 技术方案

### Bug1 修复：传递 NavPathInfo param 到 MusicListPage

**方案**：在 `navDestinationBuilder` 的 `MusicList` 分支中，将 `_param` 传递给 `MusicListPage`。

**Index.ets 改动**（第174-192行）：
```
NavDestination() {
  MusicListPage({ param: _param as MusicListParam })
}
```

**MusicListPage.ets 改动**：
- `aboutToAppear(param?)` 改为 `@Prop param: MusicListParam | undefined = undefined`
- 在 `aboutToAppear()` 无参版本中读取 `this.param` 进行数据加载
- 移除兜底分支（param 现在可靠传入，不再需要 fallback）

### Bug2 修复：getRawFd + avPlayer.fdSrc

**方案**：在 `loadAndPlay()` 中判断 url 类型：
- 以 `http://` 或 `https://` 开头 → `avPlayer.url = url`（网络音频）
- 否则 → `resourceManager.getRawFd(url)` → `avPlayer.fdSrc = { fd, offset, length }`

**AudioPlayerController.ets 改动**（`loadAndPlay` 方法）：
```
public async loadAndPlay(url: string): Promise<void> {
  if (!this.avPlayer || !url) return
  if (this.currentState !== 'idle') await this.avPlayer.reset()
  
  if (url.startsWith('http://') || url.startsWith('https://')) {
    this.avPlayer.url = url
  } else {
    const ctx = AppStorage.get('context') as common.UIAbilityContext
    const rawFd = await ctx.resourceManager.getRawFd(url)
    this.avPlayer.fdSrc = { fd: rawFd.fd, offset: rawFd.offset, length: rawFd.length }
  }
  this.waitPlay = true
}
```

需要新增导入：`import { common } from '@kit.AbilityKit'`

**Context 可用性确认**：`EntryAbility.onCreate()` 第14行已执行 `AppStorage.setOrCreate('context', this.context)`，`AudioPlayerController` 中可直接获取。


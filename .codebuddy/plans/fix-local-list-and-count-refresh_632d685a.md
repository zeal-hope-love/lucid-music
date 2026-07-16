---
name: fix-local-list-and-count-refresh
overview: 修复 MusicListPage 本地列表为空和 MinePage 收藏/最近播放数量不实时刷新的两个 bug
todos:
  - id: fix-musiclist-fallback
    content: MusicListPage.ets 的 aboutToAppear 增加 param===undefined 兜底分支，默认加载 getSongList()
    status: completed
  - id: fix-minepage-refresh
    content: MinePage.ets 连接 CurrentTabState，提取 refreshCounts()，添加 @Monitor 监听 tab 切回时刷新
    status: completed
---

## 问题描述
两个 bug 需要修复：

1. **本地列表为空**：MinePage 本地入口显示 2 首歌曲，但点击进入 MusicListPage 后列表显示 0 首
2. **收藏数量不刷新**：在播放页点亮爱心收藏歌曲后，返回"我的"tab，收藏入口数量仍为 0，不自动更新

## 根因
- **Bug1**：MusicListPage 是 `@ComponentV2` 组件，`aboutToAppear(param?: MusicListParam)` 无法接收到 NavPathInfo 传入的 `MusicListParam` 对象，`param` 始终为 `undefined`，导致整个数据加载分支不执行，`songs` 保持空数组
- **Bug2**：MinePage 位于 Swiper 中（`cachedCount=1`），首次 `aboutToAppear` 后不再重建。在播放页收藏/播放歌曲只修改了 MusicMemoryStore，MinePage 不感知数据变化，需要在切回 MinePage tab（index=2）时主动刷新计数


## 技术方案

### Bug1 修复：MusicListPage 添加 param 兜底

**文件**：`features/mine/src/main/ets/view/MusicListPage.ets`

当 `param === undefined` 时（NavPathInfo param 未传到 @ComponentV2），回退到默认行为：加载全部歌曲。

```typescript
aboutToAppear(param?: MusicListParam): void {
    if (param !== undefined) {
      if (param.title.length > 0) {
        this.pageTitle = param.title
      }
      const api = MusicDbApi.getInstance()
      if (param.listType === 'local') {
        this.songs = api.getSongList()
      } else if (param.listType === 'recent') {
        this.songs = api.getRecentPlaySongs()
      } else if (param.listType === 'favorite') {
        this.songs = api.getFavoriteSongs()
      } else {
        this.songs = []
      }
    } else {
      // 兜底：param 未传入时默认加载本地歌曲
      this.songs = MusicDbApi.getInstance().getSongList()
    }
  }
```

### Bug2 修复：MinePage 监听 tab 切换刷新计数

**文件**：`features/mine/src/main/ets/view/MinePage.ets`

策略：
1. 通过 `AppStorageV2.connect` 连接 `CurrentTabState`
2. 提取 `refreshCounts()` 方法
3. 使用 `@Monitor('currentTabState.index')` 监听 tab 切换，当 index 变为 2 时刷新

```typescript
import { AppStorageKeys, CurrentTabState, MusicDbApi, RouterUrlConstants } from 'musicbasic'

@ComponentV2
export struct MinePage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  private currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
  
  @Local quickEntries: QuickEntry[] = [...]

  aboutToAppear(): void {
    this.refreshCounts()
  }

  @Monitor('currentTabState.index')
  onTabIndexChanged(): void {
    if (this.currentTabState.index === 2) {
      this.refreshCounts()
    }
  }

  private refreshCounts(): void {
    const api = MusicDbApi.getInstance()
    this.quickEntries = [
      { icon: $r('sys.symbol.folder_fill'), label: '本地', count: api.getSongList().length },
      { icon: $r('sys.symbol.clock_fill'), label: '最近播放', count: api.getRecentPlayCount() },
      { icon: $r('sys.symbol.heart_fill'), label: '收藏', count: api.getFavoriteCount() }
    ]
  }
}
```

### 改动范围
仅 2 个文件，无需新增文件，复用现有 `CurrentTabState` + `AppStorageV2` 模式。


/*
 * Lucid Music - 全屏播放页 (avplayer UI 桥接层)
 * 从 MusicAppState 读取当前歌曲信息，实时同步到 AppStorage 供子组件消费
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys, getStatusBarTopVpFromWindowUtil, MusicAppState, MusicDbApi, WindowUtil } from 'musicbasic'
import { PlayerInfoComponent } from './PlayerInfoComponent'
import { BreakpointConstants } from '../constants/BreakpointConstants'
import { SongItem as PlayerSongItem } from 'musicbasic'

@Component
export struct PlaybackPage {
  @StorageLink('isShowPlay') isShowPlay: boolean = false
  @StorageLink('selectIndex') selectIndex: number = 0
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  private inited: boolean = false

  aboutToAppear(): void {
    if (!this.inited) {
      this.inited = true
      this.syncStaticConfig()
    }
    // 每次出现都同步当前歌曲（支持返回后再进入）
    this.syncCurrentSongToAppStorage()
  }

  /** 一次性静态配置（不覆盖已有 imageColor） */
  private syncStaticConfig(): void {
    AppStorage.setOrCreate('currentBreakpoint', BreakpointConstants.BREAKPOINT_SM)
    AppStorage.setOrCreate('isFoldFull', false)
    AppStorage.setOrCreate('pageShowTime', 0)
    AppStorage.setOrCreate('topHeight', getStatusBarTopVpFromWindowUtil())
    AppStorage.setOrCreate('bottomHeight', WindowUtil.getInstance().mainWindowInfo.navigationBarBottomVp)
    if (AppStorage.get('imageColor') === undefined) {
      AppStorage.setOrCreate('imageColor', 'rgba(0, 0, 2, 1.00)')
    }
    // 从 V2 同步到 V1
    AppStorage.setOrCreate('isPlay', this.appState.isPlay)
    AppStorage.setOrCreate('progress', this.appState.progress)
    AppStorage.setOrCreate('progressMax', this.appState.progressMax)
    AppStorage.setOrCreate('currentTime', this.appState.currentTime)
    AppStorage.setOrCreate('totalTime', this.appState.totalTime)
    AppStorage.setOrCreate('playMode', this.appState.playMode)
    AppStorage.setOrCreate('isSilentMode', this.appState.isSilentMode)
    AppStorage.setOrCreate('currentVolume', this.appState.currentVolume)
    if (!AppStorage.get('context')) {
      AppStorage.setOrCreate('context', getContext(this) as common.UIAbilityContext)
    }
  }

  /** 将当前歌曲信息写入 AppStorage */
  private syncCurrentSongToAppStorage(): void {
    const songItem = this.appState.getCurrentSongItem()
    if (!songItem) {
      return
    }
    // 构建 songItem（现在 common 和 player 共用同一个 SongItem 类型）
    const playerSongItem = new PlayerSongItem()
    playerSongItem.id = songItem.id
    playerSongItem.title = songItem.title
    playerSongItem.singer = songItem.singer
    playerSongItem.src = songItem.src
    playerSongItem.label = songItem.label
    playerSongItem.lyric = songItem.lyric
    playerSongItem.coverUrl = songItem.coverUrl || ''
    playerSongItem.lyricText = songItem.lyricText || ''
    playerSongItem.isDarkBackground = songItem.isDarkBackground

    // 写入 songList（替换已有同 ID 条目，插入首位）
    const existingList = AppStorage.get('songList') as Object[]
    let newList: Object[] = [playerSongItem]
    if (existingList && Array.isArray(existingList)) {
      const filtered = existingList.filter((s: Object) =>
        ((s as Record<string, Object>)['id'] as number) !== playerSongItem.id) as Object[]
      newList = [playerSongItem as Object, ...filtered]
    }
    AppStorage.setOrCreate('songList', newList)
    // 同步 selectIndex 从 V2（不再强制置 0）
    AppStorage.setOrCreate('selectIndex', 0)
    AppStorage.setOrCreate('isFavorite', this.appState.isFavorite)
  }

  build() {
    PlayerInfoComponent({ isShowPlay: this.isShowPlay })
  }
}

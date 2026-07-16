/*
 * Lucid Music - 全屏播放页 (avplayer UI 桥接层)
 * 初始化 AppStorage 后渲染 avplayer 完整的 PlayerInfoComponent
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys, getStatusBarTopVpFromWindowUtil, MusicAppState, MusicDbApi, WindowUtil } from 'musicbasic'
import { PlayerInfoComponent } from './PlayerInfoComponent'
import { MusicPlayMode, DEFAULT_VOLUME } from '../constants/PlayerConstants'
import { BreakpointConstants } from '../constants/BreakpointConstants'
import { songList as defaultSongList } from '../model/SongListData'

@Component
export struct PlaybackPage {
  @StorageLink('isShowPlay') isShowPlay: boolean = false
  @StorageLink('selectIndex') selectIndex: number = 0
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  private inited: boolean = false

  aboutToAppear(): void {
    if (this.inited) {
      return
    }
    this.inited = true
    this.syncToAppStorage()
  }

  private syncToAppStorage(): void {
    AppStorage.setOrCreate('songList', defaultSongList)
    AppStorage.setOrCreate('currentBreakpoint', BreakpointConstants.BREAKPOINT_SM)
    AppStorage.setOrCreate('isFoldFull', false)
    AppStorage.setOrCreate('pageShowTime', 0)
    AppStorage.setOrCreate('topHeight', getStatusBarTopVpFromWindowUtil())
    AppStorage.setOrCreate('bottomHeight', WindowUtil.getInstance().mainWindowInfo.navigationBarBottomVp)
    AppStorage.setOrCreate('imageColor', 'rgba(0, 0, 2, 1.00)')
    const songItem = this.appState.resolveSongAtQueueIndex(this.appState.selectIndex)
    const initFav = songItem ? MusicDbApi.getInstance().isFavorite(songItem.id) : false
    AppStorage.setOrCreate('isFavorite', initFav)
    AppStorage.setOrCreate('selectIndex', this.appState.selectIndex)
    AppStorage.setOrCreate('isPlay', this.appState.isPlay)
    AppStorage.setOrCreate('progress', this.appState.progress)
    AppStorage.setOrCreate('progressMax', this.appState.progressMax)
    AppStorage.setOrCreate('currentTime', this.appState.currentTime)
    AppStorage.setOrCreate('totalTime', this.appState.totalTime)
    AppStorage.setOrCreate('playMode', MusicPlayMode.ORDER)
    AppStorage.setOrCreate('isSilentMode', false)
    AppStorage.setOrCreate('currentVolume', DEFAULT_VOLUME)
    if (!AppStorage.get('context')) {
      AppStorage.setOrCreate('context', getContext(this) as common.UIAbilityContext)
    }
  }

  build() {
    PlayerInfoComponent({ isShowPlay: this.isShowPlay })
  }
}

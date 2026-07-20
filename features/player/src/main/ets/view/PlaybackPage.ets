/*
 * Lucid Music - 全屏播放页 (avplayer UI 桥接层)
 * 从 MusicAppState 读取当前歌曲信息，实时同步到 AppStorage 供子组件消费
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys, getStatusBarTopVpFromWindowUtil, MusicAppState, MusicDbApi, WindowUtil } from 'musicbasic'
import { PlayerInfoComponent } from './PlayerInfoComponent'
import { BreakpointConstants } from '../constants/BreakpointConstants'

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

  /** 将当前歌曲信息写入 AppStorage（完整队列，songList[selectIndex] 即当前曲） */
  private syncCurrentSongToAppStorage(): void {
    const current = this.appState.getCurrentSongItem()
    if (!current) {
      return
    }
    // 构建完整队列（与 AudioPlayerController.syncStateForNewSong 保持一致），供播放列表弹层浏览/切歌
    const queueList: Object[] = []
    for (let i = 0; i < this.appState.playQueue.length; i++) {
      queueList.push(this.appState.playQueue[i] as Object)
    }
    AppStorage.setOrCreate('songList', queueList)
    // 同步 selectIndex 从 V2（不再强制置 0）
    AppStorage.setOrCreate('selectIndex', this.appState.selectIndex)
    AppStorage.setOrCreate('isFavorite', this.appState.isFavorite)
  }

  build() {
    PlayerInfoComponent({ isShowPlay: this.isShowPlay })
  }
}

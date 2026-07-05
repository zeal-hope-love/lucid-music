/*
 * Lucid Music - 主页面 (纯 Tab 容器)
 */
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, getWindowInfoState, MusicAppState, MusicDbApi,
  PlaybackIntentState, PlaybackShellConstants, SearchPageExtraInfo, SongApiDto, StyleConstants, WindowInfo
} from 'musicbasic'
import { dispatchShellPlaybackIntent, JsVmBridge } from 'player'
import { HomePage } from 'home'
import { MusicHallPage } from 'musichall'
import { MinePage } from 'mine'
import { SearchPage } from 'search'

@Entry
@ComponentV2
struct Index {
  @Provider('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack()
  @Local currentTab: number = 0
  @Local showSearch: boolean = false
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local windowInfo: WindowInfo = getWindowInfoState()

  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto: SongApiDto): number => dto.id)
    JsVmBridge.getInstance().init()
  }

  @Builder
  navDestinationBuilder(name: string, param: Object): void {
    if (name === 'SearchLongTakeTransitionPageTwo') {
      SearchPage({ param: param as SearchPageExtraInfo })
    }
  }

  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged(): void {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      this.getUIContext().animateTo({
        duration: PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS,
        curve: Curve.EaseInOut
      }, () => { this.appState.isShowPlay = true })
    })
  }

  build() {
    Navigation(this.pageIndexInfos) {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() { HomePage() }
          .tabBar('首页')

        TabContent() { MusicHallPage() }
          .tabBar('音乐厅')

        TabContent() { MinePage() }
          .tabBar('我的')
      }
      .barMode(BarMode.Fixed)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
  }
}

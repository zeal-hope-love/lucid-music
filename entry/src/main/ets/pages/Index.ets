/*
 * Lucid Music - 路由入口
 * 架构：管理 tab 状态（CurrentTabState） + 路由（Search/Playback push） + 初始化。
 * 底部栏 UI 由各 Tab 页面自行管理。
 */
import { AppStorageV2, curves } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, MusicAppState, MusicDbApi,
  PlaybackIntentState, RouterUrlConstants
} from 'musicbasic'
import { dispatchShellPlaybackIntent, JsVmBridge } from 'player'
import { AudioPlayerController } from 'player'
import { AVSessionController } from 'player'
import { HomePage } from 'home'
import { MusicHallPage } from 'musichall'
import { MinePage } from 'mine'
import { SearchPage } from 'search'
import { PlaybackPage } from 'player'

@Entry
@ComponentV2
struct Index {
  @Provider() navPathStack: NavPathStack = new NavPathStack()
  @Provider() searchBackVersion: number = 0
  @Provider() isSearchResultMode: boolean = false
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  /** Tab 状态，各页面 TabBar onChange 写入后自动感知 */
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!

  /** Tab 切换时清除 Search/Playback 残留路由 */
  @Monitor('currentTabState.index')
  onTabChanged(): void {
    this.navPathStack.clear()
  }

  aboutToAppear() {
    this.currentTabState.index = 0
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto): number => dto.id)
    JsVmBridge.getInstance().init()
    AudioPlayerController.getInstance().initAVPlayer()
    this.wireAVSessionCallbacks()
  }

  private wireAVSessionCallbacks(): void {
    const avs = AVSessionController.getInstance()
    const player = AudioPlayerController.getInstance()
    avs.onPlayRequested = () => player.play()
    avs.onPauseRequested = () => player.pause()
    avs.onNextRequested = () => player.playNext()
    avs.onPrevRequested = () => player.playPrevious()
    avs.onSeekRequested = (ms: number) => player.seek(ms)
    avs.onSetLoopModeRequested = (loopMode) => {
      if (loopMode === 0) { // LOOP_MODE_SEQUENCE
        player.setPlayMode(1) // MusicPlayMode.ORDER
      } else if (loopMode === 1) { // LOOP_MODE_SINGLE
        player.setPlayMode(0) // MusicPlayMode.SINGLE_CYCLE
      } else if (loopMode === 2) { // LOOP_MODE_SHUFFLE
        player.setPlayMode(2) // MusicPlayMode.RANDOM
      }
    }
    avs.onToggleFavoriteRequested = (assetId: string) => {
      avs.updateFavoriteState(assetId, true)
    }
  }

  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged(): void {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      this.openPlayback()
    })
  }

  private openPlayback(): void {
    if (this.navPathStack.getIndexByName(RouterUrlConstants.PLAYBACK).length > 0) {
      return
    }
    this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined))
  }

  @Builder
  navDestinationBuilder(name: string, _param: Object) {
    if (name === 'Search') {
      NavDestination() {
        SearchPage()
      }
      .hideTitleBar(true)
      .transition(TransitionEffect.OPACITY)
      .onBackPressed(() => {
        if (this.isSearchResultMode) {
          this.searchBackVersion++
          return true
        }
        this.getUIContext().animateTo({
          curve: curves.interpolatingSpring(0, 1, 342, 38)
        }, () => {
          this.navPathStack.pop(false)
        })
        return true
      })
    } else if (name === 'Playback') {
      NavDestination() {
        PlaybackPage()
      }
      .hideTitleBar(true)
    }
  }

  @Builder
  tabContent() {
    if (this.currentTabState.index === 0) {
      HomePage()
    } else if (this.currentTabState.index === 1) {
      MusicHallPage()
    } else {
      MinePage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
      this.tabContent()
    }
    .navDestination(this.navDestinationBuilder)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

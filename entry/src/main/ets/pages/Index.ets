/*
 * Lucid Music - 路由入口
 * 架构：管理 tab 状态（CurrentTabState） + 路由（Search/Playback push） + 初始化。
 * 底部栏（MiniPlayerBar + LucidTabBar）由 Index 统一管理，按页面类型控制显隐。
 */
import { AppStorageV2, curves, display } from '@kit.ArkUI'
import {
  AppStorageKeys, BottomBarVisibility, CurrentTabState, MusicAppState, MusicDbApi,
  PlaybackIntentState, RouterUrlConstants, AudioSourceManager, JsVmBridge
} from 'musicbasic'
import { LucidTabBar, MiniPlayerBar } from 'musicbasic'
import {
  dispatchShellPlaybackIntent, AudioPlayerController, AVSessionController
} from 'player'
import { HomePage } from 'home'
import { MusicHallPage } from 'musichall'
import { MinePage, SettingsPage } from 'mine'
import { SongListPage, SongListParam } from 'musicbasic'
import { SearchPage } from 'search'
import { PlaybackPage } from 'player'

@Entry
@ComponentV2
struct Index {
  @Provider() navPathStack: NavPathStack = new NavPathStack()
  @Provider() searchBackVersion: number = 0
  @Provider() isSearchResultMode: boolean = false
  @Provider() barVisibility: BottomBarVisibility = new BottomBarVisibility()
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  /** Tab 状态，LucidTabBar onChange 写入后自动感知 */
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!

  @Computed
  get screenWidth(): number {
    try {
      const d = display.getDefaultDisplaySync()
      return Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      return 360
    }
  }

  aboutToAppear() {
    this.currentTabState.index = 0
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto): number => dto.id)
    JsVmBridge.getInstance().init()
    AudioPlayerController.getInstance().initAVPlayer()
    AVSessionController.getInstance().initAVSession()
    this.wireAVSessionCallbacks()
    this.autoInitAudioSource()
  }

  /** 启动时自动激活第一个已启用的音源（若无则激活第一个） */
  private async autoInitAudioSource(): Promise<void> {
    try {
      const manager = AudioSourceManager.getInstance()
      const activeScript = await manager.getActiveScript()
      if (activeScript) {
        return // 已有激活的音源
      }
      const all = await manager.getAll()
      if (all.length > 0) {
        await manager.toggleEnabled(all[0].id, true)
      }
    } catch (_) {
      // 静默处理
    }
  }

  private wireAVSessionCallbacks(): void {
    const avs = AVSessionController.getInstance()
    const player = AudioPlayerController.getInstance()
    avs.onPlayRequested = () => player.play()
    avs.onPauseRequested = () => player.pause()
    avs.onNextRequested = () => player.playNext()
    avs.onPrevRequested = () => player.playPrevious()
    avs.onSeekRequested = (ms: number) => player.seek(ms)
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
    AppStorage.setOrCreate('playbackEntering', true)
    this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined), { animated: false })
  }

  /** 根据当前导航栈状态恢复底部栏显隐 */
  private restoreBarVisibility(): void {
    if (this.navPathStack.getAllPathName().length === 0) {
      // 回到 Tab 页
      this.barVisibility.miniPlayerVisible = true
      this.barVisibility.tabBarVisible = true
    } else {
      // 栈中仍有页面（如从 Playback 回退到 Search）
      this.barVisibility.miniPlayerVisible = true
      this.barVisibility.tabBarVisible = false
    }
    // 通知 MinePage 和 SongListPage 刷新数据
    this.currentTabState.refreshCounter++
    this.currentTabState.favoriteVersion++
  }

  @Builder
  navDestinationBuilder(name: string, _param: Object) {
    if (name === 'Search') {
      NavDestination() {
        SearchPage()
      }
      .hideTitleBar(true)
      .transition(TransitionEffect.OPACITY)
      .onAppear(() => {
        this.barVisibility.miniPlayerVisible = true
        this.barVisibility.tabBarVisible = false
      })
      .onDisAppear(() => {
        this.restoreBarVisibility()
      })
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
      .transition(TransitionEffect.OPACITY.animation({ duration: 50 }))
      .onAppear(() => {
        this.barVisibility.tabBarVisible = false
        this.barVisibility.miniPlayerVisible = false
      })
      .onDisAppear(() => {
        AppStorage.setOrCreate('playbackEntering', false)
        this.restoreBarVisibility()
      })
      .onBackPressed(() => {
        // 退场一镜到底：先让 MiniPlayerBar 可见，作为目标位置
        AppStorage.setOrCreate('playbackEntering', true)
        this.barVisibility.miniPlayerVisible = true
        this.navPathStack.pop(false)
        return true
      })
    } else if (name === 'Settings') {
      NavDestination() {
        SettingsPage()
      }
      .hideTitleBar(true)
      .transition(TransitionEffect.OPACITY)
      .backgroundColor(Color.Transparent)
      .onAppear(() => {
        this.barVisibility.miniPlayerVisible = false
        this.barVisibility.tabBarVisible = false
      })
      .onDisAppear(() => {
        this.restoreBarVisibility()
      })
      .onBackPressed(() => {
        this.navPathStack.pop()
        return true
      })
    } else if (name === 'MusicList') {
      NavDestination() {
        SongListPage({ param: _param as SongListParam })
      }
      .hideTitleBar(true)
      .transition(TransitionEffect.OPACITY)
      .backgroundColor(Color.Transparent)
      .onAppear(() => {
        this.barVisibility.miniPlayerVisible = true
        this.barVisibility.tabBarVisible = false
      })
      .onDisAppear(() => {
        this.restoreBarVisibility()
      })
      .onBackPressed(() => {
        this.navPathStack.pop()
        return true
      })
    } else if (name === 'PlaylistDetailPage') {
      NavDestination() {
        SongListPage({ param: _param as SongListParam })
      }
      .hideTitleBar(true)
      .transition(TransitionEffect.OPACITY)
      .backgroundColor(Color.Transparent)
      .onAppear(() => {
        this.barVisibility.miniPlayerVisible = true
        this.barVisibility.tabBarVisible = false
      })
      .onDisAppear(() => {
        this.restoreBarVisibility()
      })
      .onBackPressed(() => {
        this.navPathStack.pop()
        return true
      })
    }
  }

  @Builder
  tabContent() {
    Swiper() {
      HomePage()
      MusicHallPage()
      MinePage()
    }
    .index(this.currentTabState.index)
    .onChange((index: number) => {
      this.currentTabState.index = index
      this.navPathStack.clear()
    })
    .indicator(false)
    .loop(false)
    .cachedCount(1)
    .itemSpace(0)
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Navigation(this.navPathStack) {
        this.tabContent()
      }
      .navDestination(this.navDestinationBuilder)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // === 底部栏（固定在屏幕底部，不受 Swiper 滑动 / Navigation 导航影响） ===
      Column() {
        if (this.barVisibility.miniPlayerVisible) {
          MiniPlayerBar({
            barWidth: this.screenWidth - 40,
            bottomOffset: 10,
            onPlayPause: (): void => {
              AudioPlayerController.getInstance().togglePlay()
            },
            onNext: (): void => {
              AudioPlayerController.getInstance().playNext()
            },
            onTap: (): void => {
              if (this.navPathStack.getIndexByName(RouterUrlConstants.PLAYBACK).length > 0) {
                return
              }
              AppStorage.setOrCreate('playbackEntering', true)
              // 预设默认深色背景，避免进入播放页时闪烁黑色
              AppStorage.setOrCreate('imageColor', 'rgba(18, 18, 25, 1.00)')
              this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined), { animated: false })
            }
          })
          .margin({ bottom: 30 })
        }

        if (this.barVisibility.tabBarVisible) {
          LucidTabBar({
            currentIndex: this.currentTabState.index,
            barWidth: this.screenWidth - 40,
            bottomOffset: 30,
            onChange: (index: number): void => {
              this.currentTabState.index = index
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}

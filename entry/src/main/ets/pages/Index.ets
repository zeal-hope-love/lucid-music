/*
 * Lucid Music - 主页面（重构后）
 * 架构：Swiper（首页/音乐厅/我的）+ 搜索覆盖层 + 共享底部栏
 * 一镜到底转场：SearchInputArea 的 geometryTransition
 */
import { AppStorageV2, curves, display } from '@kit.ArkUI'
import {
  AppStorageKeys, getWindowInfoState, MusicAppState, MusicDbApi,
  PlaybackIntentState, PlaybackShellConstants, StyleConstants, WindowInfo
} from 'musicbasic'
import { LucidTabBar } from 'musicbasic'
import { MiniPlayerBar } from 'musicbasic'
import { dispatchShellPlaybackIntent, JsVmBridge } from 'player'
import { HomePage } from 'home'
import { MusicHallPage } from 'musichall'
import { MinePage } from 'mine'
import { SearchPage } from 'search'

@ComponentV2
struct IndexFooter {
  @Param @Require currentTab: number
  @Param @Require isVisible: boolean
  @Event onTabChange: (index: number) => void = (_index: number) => {}
  @Event onMiniPlayerTap?: () => void
  @Event onPlayPause?: () => void
  @Event onNext?: () => void
  @Local screenWidth: number = 360

  aboutToAppear(): void {
    try {
      const d = display.getDefaultDisplaySync()
      this.screenWidth = Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      this.screenWidth = 360
    }
  }

  build() {
    Column() {
      MiniPlayerBar({
        barWidth: this.screenWidth - 40,
        bottomOffset: 10,
        onTap: (): void => {
          this.onMiniPlayerTap?.()
        },
        onPlayPause: (): void => {
          this.onPlayPause?.()
        },
        onNext: (): void => {
          this.onNext?.()
        }
      })
      .margin({ bottom: 30 })

      LucidTabBar({
        currentIndex: this.currentTab,
        barWidth: this.screenWidth - 40,
        bottomOffset: 30,
        onChange: (index: number): void => {
          this.onTabChange(index)
        }
      })
      .visibility(this.isVisible ? Visibility.Visible : Visibility.Hidden)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = 0
  @Local isSearchOverlayShowing: boolean = false
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local windowInfo: WindowInfo = getWindowInfoState()
  private swiperController: SwiperController = new SwiperController()

  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto): number => dto.id)
    JsVmBridge.getInstance().init()
  }

  onBackPress(): boolean | void {
    if (this.isSearchOverlayShowing) {
      this.onSearchClose()
      return true
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

  @Monitor('currentTab')
  onTabChanged(): void {
    this.swiperController.changeIndex(this.currentTab)
  }

  private onSearchClick(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isSearchOverlayShowing = true
    })
  }

  private onSearchClose(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isSearchOverlayShowing = false
    })
  }

  private onMiniPlayerTap(): void {
    this.appState.isShowPlay = true
  }

  private onTabChange(index: number): void {
    this.currentTab = index
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // === 主内容区：Swiper 三页 ===
      Swiper(this.swiperController) {
        HomePage({
          currentTab: this.currentTab,
          isSearchOverlayShowing: this.isSearchOverlayShowing,
          onSearchClick: (): void => {
            this.onSearchClick()
          }
        })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))

        MusicHallPage({
          currentTab: this.currentTab,
          onTabChange: (index: number): void => { this.currentTab = index }
        })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))

        MinePage({
          currentTab: this.currentTab,
          onTabChange: (index: number): void => { this.currentTab = index }
        })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
      .index(this.currentTab)
      .indicator(false)
      .loop(false)
      .disableSwipe(false)
      .cachedCount(0)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .onChange((index: number): void => {
        this.currentTab = index
      })

      // === 底部共享栏：迷你播放条 + Tab导航 ===
      IndexFooter({
        currentTab: this.currentTab,
        isVisible: !this.isSearchOverlayShowing,
        onTabChange: (index: number): void => {
          this.onTabChange(index)
        },
        onMiniPlayerTap: (): void => {
          this.onMiniPlayerTap()
        }
      })
      .width(StyleConstants.FULL_WIDTH)

      // === 搜索覆盖层（含搜索+结果，内部切换） ===
      if (this.isSearchOverlayShowing) {
        SearchPage({
          onClose: (): void => {
            this.onSearchClose()
          }
        })
        .transition(TransitionEffect.OPACITY
          .animation({ duration: 350, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) }))
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

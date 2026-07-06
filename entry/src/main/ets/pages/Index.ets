/*
 * Lucid Music - 主页面
 * 方案：独立 HdsTabs 组件做迷你栏 + 主 HdsTabs 做底部导航
 */
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, getWindowInfoState, MusicAppState, MusicDbApi,
  PlaybackIntentState, PlaybackShellConstants, SearchPageExtraInfo, SongApiDto, StyleConstants, WindowInfo
} from 'musicbasic'
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { dispatchShellPlaybackIntent, JsVmBridge } from 'player'
import { HomePage } from 'home'
import { MusicHallPage } from 'musichall'
import { MinePage } from 'mine'
import { SearchPage } from 'search'

@ComponentV2
struct FloatingMiniBar {
  @BuilderParam @Require content: () => void
  @Param @Require barHeight: number
  @Param @Require barWidth: number

  build() {
    HdsTabs() {
      TabContent() {
      }
      .tabBar(this.content)
    }
    .width(this.barWidth + 10)
    .height(this.barHeight + 20)
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .barHeight(this.barHeight)
    .barWidth(this.barWidth)
    .barFloatingStyle({
      barBottomMargin: 10,
      gradientMask: { maskColor: '#00000000', maskHeight: 20 },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      }
    })
  }
}

@Entry
@ComponentV2
struct Index {
  @Provider('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack()
  @Local currentTab: number = 0
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local windowInfo: WindowInfo = getWindowInfoState()
  private tabsController: HdsTabsController = new HdsTabsController()

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

  @Builder
  miniBarContent(): void {
    Row() {
      Column() {
        Image($r('app.media.startIcon'))
          .width('100%').height('100%')
          .borderRadius('50%')
      }
      .padding(1).width(56).aspectRatio(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 6 }) {
        Text(this.appState.getCurrentSongItem()?.title ?? 'Lucid Music')
          .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text(this.appState.getCurrentSongItem()?.singer ?? '未在播放')
          .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .padding({ left: $r('sys.float.padding_level1') })
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      Row({ space: 16 }) {
        SymbolGlyph(this.appState.isPlay ?
          $r('sys.symbol.pause_circle_fill') : $r('sys.symbol.play_circle_fill'))
          .fontSize($r('sys.float.Title_M'))
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize($r('sys.float.Title_M'))
      }
      .padding({ left: $r('sys.float.padding_level4'), right: $r('sys.float.padding_level8') })
    }
  }

  @Builder
  tabBarBuilder(index: number, label: string, icon: Resource): void {
    Column() {
      SymbolGlyph(icon).fontSize(24)
        .fontColor([this.currentTab === index ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary')])
      Text(label).fontSize(11)
        .fontColor(this.currentTab === index ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary'))
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
      Stack({ alignContent: Alignment.Bottom }) {
        HdsTabs({ controller: this.tabsController }) {
          TabContent() { HomePage() }
            .tabBar(this.tabBarBuilder(0, '首页', $r('sys.symbol.house_fill')))
          TabContent() { MusicHallPage() }
            .tabBar(this.tabBarBuilder(1, '音乐厅', $r('sys.symbol.music_note_list')))
          TabContent() { MinePage() }
            .tabBar(this.tabBarBuilder(2, '我的', $r('sys.symbol.person_crop_circle_fill_1')))
        }
        .barOverlap(true).vertical(false).barPosition(BarPosition.End)
        .width(StyleConstants.FULL_WIDTH).height(StyleConstants.FULL_HEIGHT)
        .barFloatingStyle({
          barBottomMargin: 10,
          gradientMask: { maskColor: '#00000000', maskHeight: 20 },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        })
        .onChange((index: number) => { this.currentTab = index })

        FloatingMiniBar({
          content: (): void => { this.miniBarContent() },
          barHeight: 56,
          barWidth: 360
        })
        .margin({ bottom: 70 })
      }
      .width(StyleConstants.FULL_WIDTH).height(StyleConstants.FULL_HEIGHT)
    }
    .hideTitleBar(true).mode(NavigationMode.Stack)
    .backgroundColor('#F1F3F5')
    .navDestination(this.navDestinationBuilder)
  }
}

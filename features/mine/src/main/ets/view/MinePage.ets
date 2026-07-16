/*
 * Lucid Music - 我的页面
 * 布局：快捷入口格子 + 设置入口
 * 底部 MiniPlayerBar + LucidTabBar 已提取到 Index.ets 统一管理
 */
import { display } from '@kit.ArkUI'
import { AppStorageV2 } from '@kit.ArkUI'
import { AppStorageKeys, CurrentTabState, MusicDbApi, RouterUrlConstants } from 'musicbasic'
import { MusicListParam } from './MusicListPage'

interface QuickEntry {
  icon: Resource
  label: string
  count: number
}

@ComponentV2
export struct MinePage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
  @Local quickEntries: QuickEntry[] = [
    { icon: $r('sys.symbol.folder_fill'), label: '本地', count: 0 },
    { icon: $r('sys.symbol.clock_fill'), label: '最近播放', count: 0 },
    { icon: $r('sys.symbol.heart_fill'), label: '收藏', count: 0 }
  ]

  aboutToAppear(): void {
    this.refreshCounts()
  }

  @Monitor('currentTabState.refreshCounter')
  onRefreshCounterChanged(): void {
    this.refreshCounts()
  }

  private refreshCounts(): void {
    const api = MusicDbApi.getInstance()
    this.quickEntries = [
      { icon: $r('sys.symbol.folder_fill'), label: '本地', count: api.getSongList().length },
      { icon: $r('sys.symbol.clock_fill'), label: '最近播放', count: api.getRecentPlayCount() },
      { icon: $r('sys.symbol.heart_fill'), label: '收藏', count: api.getFavoriteCount() }
    ]
  }

  @Computed
  get screenWidth(): number {
    try {
      const d = display.getDefaultDisplaySync()
      return Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      return 360
    }
  }

  build() {
    Column() {
      Text('我的')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('90%')
        .margin({ top: 64 })

      // === 快捷入口：本地 / 最近播放 / 收藏 ===
      Row({ space: 10 }) {
        ForEach(this.quickEntries, (entry: QuickEntry) => {
          Column({ space: 6 }) {
            SymbolGlyph(entry.icon)
              .fontSize(24)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])

            Text(entry.label)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            Text(entry.count.toString())
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .borderRadius(14)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .layoutWeight(1)
          .onClick(() => {
            const typeMap: Record<string, string> = {
              '本地': 'local',
              '最近播放': 'recent',
              '收藏': 'favorite'
            }
            this.navPathStack.pushPath(
              new NavPathInfo(RouterUrlConstants.MUSIC_LIST, new MusicListParam(entry.label, typeMap[entry.label] ?? 'local'))
            )
          })
        })
      }
      .width('90%')
      .margin({ top: 24 })

      // === 设置入口 ===
      Row() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(24)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])

        Text('设置')
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 12 })

        Blank()

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
      .width('90%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .borderRadius(16)
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .onClick(() => {
        if (this.navPathStack.getIndexByName(RouterUrlConstants.SETTINGS).length > 0) {
          return
        }
        this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.SETTINGS, undefined))
      })
      .margin({ top: 12 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 160 })
  }
}

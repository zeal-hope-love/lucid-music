/*
 * Lucid Music - 光感搜索框
 * 共享元素锚点组件：首页和搜索页共用
 * 使用 AreaWithHdsTabBar 包裹获得毛玻璃光感
 * 根节点绑定 geometryTransition ID 实现一镜到底转场
 */
import { AreaWithHdsTabBar } from '../floating/AreaWithHdsTabBar'

@ComponentV2
export struct SearchInputArea {
  @Param placeholder: string = '搜歌曲、歌手、专辑'
  @Param keyword: string = ''
  @Param autoFocus: boolean = false
  @Param isFollow: boolean = true
  @Param barWidth: number = 360
  @Event onKeywordChange?: (text: string) => void
  @Event onSearch?: () => void
  @Event onClear?: () => void
  @Event onTap?: () => void

  @Local inputText: string = this.keyword

  @Monitor('keyword')
  onKeywordUpdate(): void {
    this.inputText = this.keyword
  }

  @Builder
  searchContent(): void {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(18)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
        .margin({ left: 12 })

      TextInput({ text: $$this.inputText, placeholder: this.placeholder })
        .placeholderColor($r('sys.color.mask_secondary'))
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .height(40)
        .fontSize(15)
        .defaultFocus(this.autoFocus)
        .focusOnTouch(this.autoFocus)
        .focusable(this.autoFocus)
        .borderRadius(0)
        .onChange((value: string) => {
          this.inputText = value
          this.onKeywordChange?.(value)
        })
        .onSubmit(() => {
          this.onSearch?.()
        })

      if (this.inputText.length > 0) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(18)
          .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
          .margin({ right: 12 })
          .onClick(() => {
            this.inputText = ''
            this.onClear?.()
          })
      }
    }
    .width('100%')
    .height(44)
    .borderRadius(22)
    .onClick(() => {
      this.onTap?.()
    })
  }

  build() {
    AreaWithHdsTabBar({
      barHeight: 44,
      barWidth: this.barWidth,
      barPlacement: BarPosition.End,
      bottomMargin: 0,
      content: (): void => { this.searchContent() }
    })
    .geometryTransition('SEARCH_ONE_SHOT_TRANSITION_ID', { follow: this.isFollow })
  }
}

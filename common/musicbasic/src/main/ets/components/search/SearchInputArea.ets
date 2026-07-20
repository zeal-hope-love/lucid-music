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
    Row({ space: 0 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(18)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
        .width(18)
        .margin({ left: 0, right: 4 })

      // 文字区域
      Stack({ alignContent: Alignment.Start }) {
        // 底层：TextInput 做输入，首页隐藏搜索页显示
        TextInput({ text: $$this.inputText, placeholder: '' })
          .id('search_text_input')
          .backgroundColor(Color.Transparent)
          .width('100%')
          .height(32)
          .fontSize(15)
          .fontColor(Color.Transparent)
          .defaultFocus(this.autoFocus)
          .focusOnTouch(this.autoFocus)
          .focusable(this.autoFocus)
          .hitTestBehavior(this.autoFocus ? HitTestMode.Default : HitTestMode.None)
          .borderRadius(0)
          .padding({ left: 4 })
          .visibility(this.autoFocus ? Visibility.Visible : Visibility.Hidden)
          .onChange((value: string) => {
            this.inputText = value
            this.onKeywordChange?.(value)
          })
          .onSubmit(() => {
            this.onSearch?.()
          })

        // 顶层：Text 显示文字，随系统色自适应深浅模式
        if (this.autoFocus) {
          // 搜索页：显示输入内容或 placeholder
          Text(this.inputText || this.placeholder)
            .fontSize(15)
            .fontColor(this.inputText ? $r('sys.color.font_primary') : $r('sys.color.ohos_id_color_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 4 })
            .hitTestBehavior(HitTestMode.None)
        } else {
          // 首页：只显示 placeholder
          Text(this.placeholder)
            .fontSize(15)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 4 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .layoutWeight(1)

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
    .padding({ top: 8, bottom: 8 })
    .borderRadius(20)
    .onClick(() => {
      this.onTap?.()
    })
  }

  build() {
    AreaWithHdsTabBar({
      barHeight: 40,
      barWidth: this.barWidth,
      barPlacement: BarPosition.End,
      bottomMargin: 8,
      content: (): void => { this.searchContent() }
    })
    .geometryTransition('SEARCH_ONE_SHOT_TRANSITION_ID', { follow: this.isFollow })
    .width('100%')
  }
}

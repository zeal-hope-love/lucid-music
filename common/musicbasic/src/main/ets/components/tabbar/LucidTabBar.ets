/*
 * Lucid Music - Tab 导航栏
 * 使用 AreaWithHdsTabBar 包裹实现沉浸光感，渲染 3 个 Tab（首页/音乐厅/我的）
 */
import { AreaWithHdsTabBar } from '../floating/AreaWithHdsTabBar'

interface TabConfig {
  index: number
  label: string
  icon: Resource
}

@ComponentV2
export struct LucidTabBar {
  @Param @Require currentIndex: number
  @Param @Require barWidth: number
  @Event onChange: (index: number) => void = (_index: number) => {}
  @Param bottomOffset: number = 10

  @Local tabConfigs: TabConfig[] = [
    { index: 0, label: '首页', icon: $r('sys.symbol.house_fill') },
    { index: 1, label: '音乐厅', icon: $r('sys.symbol.music_note_list') },
    { index: 2, label: '我的', icon: $r('sys.symbol.person_crop_circle_fill_1') }
  ]

  @Builder
  tabBarContent(): void {
    Row() {
      ForEach(this.tabConfigs, (cfg: TabConfig) => {
        Column() {
          SymbolGlyph(cfg.icon)
            .fontSize(24)
            .fontColor([
              this.currentIndex === cfg.index
                ? $r('sys.color.ohos_id_color_text_primary')
                : $r('sys.color.ohos_id_color_text_tertiary')
            ])
          Text(cfg.label)
            .fontSize(11)
            .fontColor(
              this.currentIndex === cfg.index
                ? $r('sys.color.ohos_id_color_text_primary')
                : $r('sys.color.ohos_id_color_text_tertiary')
            )
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        .height(64)
        .onClick(() => {
          this.onChange(cfg.index)
        })
      })
    }
    .width(this.barWidth)
    .height(64)
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    AreaWithHdsTabBar({
      barHeight: 64,
      barWidth: this.barWidth,
      barPlacement: BarPosition.End,
      bottomMargin: this.bottomOffset,
      content: (): void => { this.tabBarContent() }
    })
  }
}

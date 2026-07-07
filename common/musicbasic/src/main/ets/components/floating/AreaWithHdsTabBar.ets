/*
 * Lucid Music - 毛玻璃容器
 * 封装 HdsTabs 的 barFloatingStyle 沉浸光感材质，作为纯容器使用
 * 曲线救国：利用 HdsTabs 的 TabContent 留空，只取 tabBar 插槽实现光感效果
 */
import { HdsTabs } from '@kit.UIDesignKit'
import { hdsMaterial } from '@kit.UIDesignKit'

@ComponentV2
export struct AreaWithHdsTabBar {
  @BuilderParam @Require content: () => void
  @Param @Require barHeight: number
  @Param @Require barWidth: number
  @Param barPlacement: BarPosition = BarPosition.End
  @Param bottomMargin: number = 10

  build() {
    HdsTabs() {
      TabContent() {
      }
      .tabBar(this.content)
    }
    .width(this.barWidth + 10)
    .height(this.barHeight + 20)
    .barOverlap(true)
    .barPosition(this.barPlacement)
    .vertical(false)
    .barHeight(this.barHeight)
    .barWidth(this.barWidth)
    .barFloatingStyle({
      barBottomMargin: this.bottomMargin,
      gradientMask: { maskColor: '#00000000', maskHeight: 20 },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      }
    })
  }
}

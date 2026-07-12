/*
 * Lucid Music - 毛玻璃容器
 * 基于 HdsMiniBarButton 思路：Row 包裹 HdsTabs + .clip(false) 消除裁剪
 * 参考：SummerKaze/HdsButton_Component + 华为开发者联盟文章
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
  @Param contentPadding: number = 8

  build() {
    HdsTabs() {
      TabContent() {
      }
      .tabBar(this.content)
    }
    .clip(false)
    .width(this.barWidth)
    .height(this.barHeight)
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
    .onTabBarClick(() => {
      // 点击穿透，由内层 content 处理
    })
  }
}

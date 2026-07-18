/*
 * Lucid Music - 平台切换 Tab 栏组件（ChipGroup 胶囊样式 + 右侧 IconGroupSuffix）
 * 完全对齐 HarmonyOSComponentUXExamples CapsuleStyle 实现：
 * ChipGroup 原生处理水平滚动 + 右侧 suffix 固定 + 边缘渐隐过渡。
 */
import { Platform, PlatformLabels } from 'musicbasic'
import { ChipGroup, ChipGroupItemOptions, ChipGroupSpaceOptions,
  ChipItemStyle, ChipSize, IconGroupSuffix, SymbolGlyphModifier } from '@kit.ArkUI'

/** 胶囊 Chip 统一样式 */
const CAPSULE_STYLE: ChipItemStyle = {
  size: ChipSize.NORMAL,
  backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
  fontColor: $r('sys.color.ohos_id_color_text_primary'),
  selectedBackgroundColor: $r('sys.color.ohos_id_color_emphasize'),
  selectedFontColor: $r('sys.color.ohos_id_color_text_primary_contrary'),
}

const CHIP_SPACE: ChipGroupSpaceOptions = {
  itemSpace: 8,
  startSpace: 16,
  endSpace: 32
}

/** IconGroupSuffix 的包装组件（参考 CapsuleStyle ChipGroupSuffixComp） */
@ComponentV2
struct FilterSuffixComp {
  @Event onFilterClick: () => void

  build() {
    IconGroupSuffix({
      items: [
        new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2'))
          .fontSize(18)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          .onClick(() => {
            this.onFilterClick()
          })
      ]
    })
      .margin({ right: 16 })
  }
}

@ComponentV2
export struct SourceTabBar {
  @Param activeSource: string = Platform.KW
  @Param sources: string[] = [Platform.KW, Platform.KG, Platform.TX, Platform.WY, Platform.MG]
  @Event onSourceChange: (source: string) => void
  @Event onFilterClick: () => void

  @Computed
  get selectedIndexes(): number[] {
    const idx = this.sources.indexOf(this.activeSource)
    return idx !== -1 ? [idx] : [0]
  }

  @Computed
  get chipItems(): ChipGroupItemOptions[] {
    return this.sources.map((source: string): ChipGroupItemOptions => {
      const label: string = (PlatformLabels[source as Platform] ?? source) as string
      return { label: { text: label }, allowClose: false }
    })
  }

  @LocalBuilder
  ChipGroupSuffixWrapper(): void {
    FilterSuffixComp({ onFilterClick: this.onFilterClick })
  }

  build() {
    ChipGroup({
      items: this.chipItems,
      itemStyle: CAPSULE_STYLE,
      selectedIndexes: this.selectedIndexes,
      multiple: false,
      chipGroupSpace: CHIP_SPACE,
      onChange: (activatedChipsIndex: number[]): void => {
        if (activatedChipsIndex.length > 0) {
          const idx = activatedChipsIndex[0]
          const source = this.sources[idx]
          if (source !== undefined && source !== this.activeSource) {
            this.onSourceChange(source)
          }
        }
      },
      suffix: this.ChipGroupSuffixWrapper
    })
  }
}

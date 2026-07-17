/*
 * Lucid Music - 标签筛选 BindSheet 内容组件
 * 顶部排序 ChipGroup（胶囊单选） + 下方 Chip 标签分组筛选（SMALL 单选）。
 */
import { TagFilterGroup, TagFilterItem } from 'musicbasic'
import { ChipGroup, ChipGroupItemOptions, ChipGroupSpaceOptions,
  ChipItemStyle, ChipSize } from '@kit.ArkUI'

/** 排序 Chip 样式 */
const SORT_CHIP_STYLE: ChipItemStyle = {
  size: ChipSize.NORMAL,
  backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
  fontColor: $r('sys.color.ohos_id_color_text_primary'),
  selectedBackgroundColor: $r('sys.color.ohos_id_color_emphasize'),
  selectedFontColor: $r('sys.color.ohos_id_color_text_primary_contrary'),
}

const SORT_CHIP_SPACE: ChipGroupSpaceOptions = {
  itemSpace: 8,
  startSpace: 0,
}

/** 标签 Chip 样式（SMALL） */
const TAG_CHIP_STYLE: ChipItemStyle = {
  size: ChipSize.SMALL,
  backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
  fontColor: $r('sys.color.ohos_id_color_text_primary'),
  selectedBackgroundColor: $r('sys.color.ohos_id_color_emphasize'),
  selectedFontColor: $r('sys.color.ohos_id_color_text_primary_contrary'),
}

const TAG_CHIP_SPACE: ChipGroupSpaceOptions = {
  itemSpace: 8,
  startSpace: 0,
}

@ComponentV2
export struct TagFilterSheet {
  @Param tagGroups: TagFilterGroup[] = []
  @Param activeTagId: string = ''
  @Param sortOptions: string[] = ['推荐', '热门', '最新', '收藏']
  @Param activeSortIndex: number = 0
  @Event onTagSelect: (tagId: string) => void
  @Event onSortChange: (index: number) => void

  @Computed
  get sortChipItems(): ChipGroupItemOptions[] {
    return this.sortOptions.map((opt: string): ChipGroupItemOptions => {
      return { label: { text: opt }, allowClose: false }
    })
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // ====== 排序 ChipGroup ======
        Text('排序方式')
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))

        ChipGroup({
          items: this.sortChipItems,
          itemStyle: SORT_CHIP_STYLE,
          chipGroupSpace: SORT_CHIP_SPACE,
          selectedIndexes: [this.activeSortIndex],
          multiple: false,
          onChange: (activated: number[]): void => {
            if (activated.length > 0) {
              this.onSortChange(activated[0])
            }
          }
        })

        // ====== 分隔 ======
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.ohos_id_color_list_separator'))

        // ====== 标签筛选 ======
        Text('风格标签')
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))

        // "全部" 标签
        Row() {
          Text('全部')
            .fontSize(13)
            .fontColor(this.activeTagId === ''
              ? Color.White
              : $r('sys.color.ohos_id_color_text_primary'))
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        }
        .borderRadius(16)
        .backgroundColor(this.activeTagId === ''
          ? $r('sys.color.ohos_id_color_emphasize')
          : $r('sys.color.ohos_id_color_button_normal'))
        .onClick(() => {
          this.onTagSelect('')
        })

        // 各分组标签
        ForEach(this.tagGroups, (group: TagFilterGroup) => {
          Column({ space: 8 }) {
            Text(group.groupName)
              .fontSize(11)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .alignSelf(ItemAlign.Start)

            // 每组标签 Chip 手动布局
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              ForEach(group.tags, (tag: TagFilterItem) => {
                Text(tag.name)
                  .fontSize(12)
                  .fontColor(this.activeTagId === tag.id
                    ? Color.White
                    : $r('sys.color.ohos_id_color_text_primary'))
                  .padding({ left: 14, right: 14, top: 5, bottom: 5 })
                  .borderRadius(14)
                  .backgroundColor(this.activeTagId === tag.id
                    ? $r('sys.color.ohos_id_color_emphasize')
                    : $r('sys.color.ohos_id_color_button_normal'))
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.onTagSelect(tag.id)
                  })
              })
            }
            .width('100%')
          }
          .width('100%')
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}

/*
 * Lucid Music - 播放缓存区域组件
 * 展示已用缓存大小、缓存歌曲数量，并提供"清理缓存"按钮。
 * 缓存功能默认直接启用（无限缓存），无开关。
 */
import { promptAction } from '@kit.ArkUI'
import { AudioCacheHelper } from 'musicbasic'

@ComponentV2
export struct CacheSection {
  @Local usedSize: number = 0
  @Local songCount: number = 0
  @Local clearing: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  private async refresh(): Promise<void> {
    const helper = AudioCacheHelper.getInstance()
    this.usedSize = await helper.getTotalSize()
    this.songCount = helper.getCachedSongCount()
  }

  private async onClear(): Promise<void> {
    if (this.clearing) {
      return
    }
    this.clearing = true
    await AudioCacheHelper.getInstance().clearAll()
    this.refresh()
    this.clearing = false
    promptAction.showToast({ message: '缓存已清理', duration: 2000 })
  }

  private formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '0 KB'
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(0)} KB`
    }
    const mb = bytes / (1024 * 1024)
    if (mb < 1024) {
      return `${mb.toFixed(0)} MB`
    }
    return `${(mb / 1024).toFixed(2)} GB`
  }

  build() {
    Column() {
      // 已用缓存（含歌曲 + 图片 + 歌词）
      Row() {
        Text('已用缓存')
          .fontSize(15)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Blank()
        Text(this.formatSize(this.usedSize))
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()
        .strokeWidth(0.5)
        .color('#1A000000')
        .margin({ left: 16, right: 16 })

      // 缓存歌曲数量
      Row() {
        Text('缓存歌曲')
          .fontSize(15)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Blank()
        Text(`${this.songCount} 首`)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()
        .strokeWidth(0.5)
        .color('#1A000000')
        .margin({ left: 16, right: 16 })

      // 清理缓存（保持按钮样式，宽度 90%）
      Button(this.clearing ? '清理中...' : '清理缓存')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.ROUNDED_RECTANGLE)
        .width('90%')
        .height(40)
        .fontSize(15)
        .alignSelf(ItemAlign.Center)
        .margin({ top: 12, bottom: 12 })
        .enabled(!this.clearing)
        .onClick(() => {
          this.onClear()
        })
    }
    .borderRadius(14)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .width('100%')
  }
}

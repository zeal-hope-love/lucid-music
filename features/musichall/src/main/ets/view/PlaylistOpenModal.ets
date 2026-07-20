/*
 * PlaylistOpenModal - 打开歌单输入弹窗
 * 对齐 lx-music-mobile SongList/HeaderBar/OpenList/Modal.tsx
 * 用户粘贴分享链接或歌单 ID，确认后跳转歌单详情页
 */
import { promptAction } from '@kit.ArkUI'

@CustomDialog
export struct PlaylistOpenModal {
  controller: CustomDialogController
  /** 当前平台名（纯展示，如「酷狗」「QQ音乐」） */
  sourceLabel: string = ''
  /** 确认回调：(用户输入) */
  onSubmit: (id: string) => void = () => {}

  build() {
    Column() {
      // 标题
      Text('打开歌单')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 8 })

      // 当前平台提示
      Text(`当前平台：${this.sourceLabel}  |  不支持跨源打开歌单`)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .margin({ bottom: 16 })

      // 输入框
      TextInput({ placeholder: '输入歌单链接或歌单 ID' })
        .width('100%')
        .height(44)
        .fontSize(15)
        .borderRadius(10)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 12 })
        .onChange((value: string) => { this._inputText = value })

      // 提示文案
      Text('1. 不支持跨源打开歌单，请确认要打开的歌单与当前选择的歌单来源是否对应\n2. 酷狗源歌单不支持用歌单 ID 或概念版链接打开，但支持用普通版链接或酷狗码打开\n3. 若遇到无法打开的歌单链接，欢迎反馈')
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .lineHeight(18)
        .margin({ bottom: 20 })

      // 按钮行
      Row({ space: 12 }) {
        Button('取消')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => { this.controller.close() })

        Button('确认')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => {
            const text = this._inputText.trim()
            if (text.length === 0) {
              promptAction.showToast({ message: '请输入歌单链接或 ID', duration: 2000 })
              return
            }
            const id = text.length > 500 ? text.substring(0, 500) : text
            this.controller.close()
            this.onSubmit(id)
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  private _inputText: string = ''
}

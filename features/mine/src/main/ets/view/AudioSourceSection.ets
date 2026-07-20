/*
 * Lucid Music - 音源管理区域组件
 * 对接 common/musicbasic AudioSourceManager 真实数据
 * 包含：Radio dot 单选列表、初始化状态、bindSheet 管理面板、
 *       删除、在线导入 Dialog、本地导入文件选择器
 */
import { promptAction } from '@kit.ArkUI'
import { picker } from '@kit.CoreFileKit'
import { AudioSourceModel, AudioSourceManager, ImportResult } from 'musicbasic'

/** 音源初始化状态（UI 层，与业务分离） */
enum InitStatus {
  IDLE = 'idle',
  INITIALIZING = 'initializing',
  SUCCESS = 'success',
  FAILED = 'failed'
}

/** 音源初始化状态条目 */
interface InitStatusEntry {
  id: string
  status: InitStatus
}

// ==================== 在线导入 Dialog ====================

@CustomDialog
struct OnlineImportDialog {
  controller: CustomDialogController
  confirm: (url: string) => void = () => {}

  build() {
    Column() {
      Text('在线导入音源')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 16 })

      TextInput({ placeholder: '请输入音源地址/URL' })
        .width('100%')
        .height(44)
        .fontSize(15)
        .borderRadius(10)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 20 })
        .onChange((value: string) => { this._inputText = value })

      Row({ space: 12 }) {
        Button('取消')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => { this.controller.close() })

        Button('确认导入')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close()
            this.confirm(this._inputText.trim())
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  _inputText: string = ''
}

// ==================== 音源管理区域 ====================

@ComponentV2
export struct AudioSourceSection {
  @Local sources: AudioSourceModel[] = []
  @Local selectedId: string = ''
  @Local initStatusList: InitStatusEntry[] = []
  @Local isSheetShow: boolean = false
  private manager: AudioSourceManager = AudioSourceManager.getInstance()
  private dialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.refreshSourceList()
  }

  /** 重新加载音源列表 */
  private async refreshSourceList(): Promise<void> {
    try {
      const all = await this.manager.getAll()
      this.sources = all
      // 默认选中已激活的音源
      let found = false
      for (let i = 0; i < all.length; i++) {
        if (all[i].enabled) {
          this.selectedId = all[i].id
          this.setStatus(all[i].id, InitStatus.SUCCESS)
          found = true
          break
        }
      }
      if (!found && all.length > 0) {
        this.selectedId = all[0].id
      }
    } catch (_) {
      this.sources = []
    }
  }

  /** 获取指定音源的初始化状态 */
  statusFor(id: string): InitStatus {
    for (let i = 0; i < this.initStatusList.length; i++) {
      if (this.initStatusList[i].id === id) {
        return this.initStatusList[i].status
      }
    }
    return InitStatus.IDLE
  }

  private setStatus(id: string, status: InitStatus): void {
    const newList: InitStatusEntry[] = []
    for (let i = 0; i < this.initStatusList.length; i++) {
      if (this.initStatusList[i].id !== id) {
        newList.push(this.initStatusList[i])
      }
    }
    newList.push({ id: id, status: status })
    this.initStatusList = newList
  }

  // ==================== 选择 ====================

  private async onSelect(id: string): Promise<void> {
    if (this.selectedId === id) {
      return
    }
    this.selectedId = id
    this.setStatus(id, InitStatus.INITIALIZING)
    try {
      await this.manager.toggleEnabled(id, true)
      this.setStatus(id, InitStatus.SUCCESS)
    } catch (_) {
      this.setStatus(id, InitStatus.FAILED)
      promptAction.showToast({ message: '音源初始化失败', duration: 2000 })
    } finally {
      await this.refreshSourceList()
    }
  }

  // ==================== 删除 ====================

  private async onDelete(id: string): Promise<void> {
    try {
      await this.manager.deleteSource(id)
    } catch (_) {
      // 静默处理
    }
    if (this.selectedId === id) {
      this.selectedId = this.sources.length > 1 ? this.sources[0].id !== id ? this.sources[0].id : this.sources[1].id : ''
    }
    await this.refreshSourceList()
  }

  // ==================== 导入 ====================

  private async onLocalImport(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker()
      docPicker.select({ maxSelectNumber: 1 }).then(async (results: string[]) => {
        if (results && results.length > 0) {
          const result = await this.manager.importFromLocal(results[0])
          if (result.success) {
            promptAction.showToast({ message: '导入成功', duration: 2000 })
            this.refreshSourceList()
          } else {
            promptAction.showToast({ message: result.message, duration: 2000 })
          }
        }
      }).catch(() => {
        promptAction.showToast({ message: '未选择文件', duration: 2000 })
      })
    } catch (_) {
      promptAction.showToast({ message: '导入失败', duration: 2000 })
    }
  }

  private onOnlineImport(): void {
    this.dialogController = new CustomDialogController({
      builder: OnlineImportDialog({
        confirm: async (url: string) => {
          if (url.length === 0) {
            promptAction.showToast({ message: '请输入有效的地址', duration: 2000 })
            return
          }
          promptAction.showToast({ message: '正在下载...', duration: 1500 })
          try {
            const result: ImportResult = await this.manager.importFromUrl(url)
            promptAction.showToast({ message: result.message, duration: 2000 })
            if (result.success) {
              this.refreshSourceList()
            }
          } catch (_) {
            promptAction.showToast({ message: '导入失败', duration: 2000 })
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this.dialogController.open()
  }

  // ==================== 初始化状态标签 ====================

  @Builder
  initStatusChip(status: InitStatus): void {
    if (status === InitStatus.INITIALIZING) {
      Row({ space: 4 }) {
        LoadingProgress().width(12).height(12)
        Text('初始化中')
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
    } else if (status === InitStatus.SUCCESS) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(14)
          .fontColor(['#34C759'])
        Text('就绪')
          .fontSize(11)
          .fontColor('#34C759')
      }
    } else if (status === InitStatus.FAILED) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(14)
          .fontColor(['#FF3B30'])
        Text('失败')
          .fontSize(11)
          .fontColor('#FF3B30')
      }
    }
  }

  // ==================== 左滑删除 Builder ====================

  @Builder
  swipeTrashBuilder(id: string): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .fontSize(20)
        .fontColor(['#FF4444'])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(44)
    .height(44)
    .margin({ right: 12 })
    .onClick(() => { this.onDelete(id) })
  }

  // ==================== Sheet 内容 Builder ====================

  @Builder
  sheetContent(): void {
    Column() {
      Row({ space: 12 }) {
        Button('本地导入')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .fontSize(14)
          .onClick(() => { this.onLocalImport() })

        Button('在线导入')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .fontSize(14)
          .onClick(() => { this.onOnlineImport() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      if (this.sources.length === 0) {
        Column() {
          Text('暂无已导入的音源')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .margin({ top: 60 })
        }
        .width('100%').layoutWeight(1)
      } else {
        Divider().strokeWidth(0.5).color('#1A000000').margin({ top: 8 })

        List() {
          ForEach(this.sources, (item: AudioSourceModel) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(' v' + item.version)
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                  Blank()
                }
                .width('100%')

                Row({ space: 6 }) {
                  Text(item.source === 'online' ? '在线' : '本地')
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  if (item.description.length > 0) {
                    Text('·')
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                    Text(item.description)
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .alignItems(HorizontalAlign.Start)
            }
            .swipeAction({
              end: {
                builder: () => {
                  // 通过闭包参数直接传入当前项的 item.id，避免共享状态被覆盖
                  this.swipeTrashBuilder(item.id)
                }
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (item: AudioSourceModel) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 16, endMargin: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 音源选择列表 Builder ====================

  @Builder
  sourceRadioList(): void {
    Column() {
      // 音源管理按钮（纳入卡片内，与其他设置区块统一，宽度 90%）
      Button('音源管理')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.ROUNDED_RECTANGLE)
        .width('90%')
        .height(40)
        .fontSize(15)
        .alignSelf(ItemAlign.Center)
        .margin({ top: 12, bottom: 12 })
        .onClick(() => { this.isSheetShow = true })

      Divider()
        .strokeWidth(0.5)
        .color('#1A000000')
        .margin({ left: 16, right: 16 })

      Column() {
        ForEach(this.sources, (item: AudioSourceModel) => {
        Row() {
          Radio({ value: item.id, group: 'audioSourceGroup', indicatorType: RadioIndicatorType.DOT })
            .checked(this.selectedId === item.id)
            .radioStyle({ checkedBackgroundColor: $r('sys.color.ohos_id_color_emphasize') })
            .hitTestBehavior(HitTestMode.None)

          Row() {
            Text(item.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('v' + item.version)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ left: 8 })
            Blank()
          }
          .alignItems(VerticalAlign.Center)
          .margin({ left: 10 })
          .layoutWeight(1)

          if (this.selectedId === item.id) {
            this.initStatusChip(this.statusFor(item.id))
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => { this.onSelect(item.id) })
          }, (item: AudioSourceModel) => item.id)
      }
    }
    .borderRadius(14)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .bindSheet($$this.isSheetShow, this.sheetContent, {
      detents: [SheetSize.MEDIUM],
      showClose: true,
      title: { title: '音源管理' }
    })
  }

  // ==================== build ====================

  build() {
    Column() {
      this.sourceRadioList()
    }
    .width('100%')
  }
}

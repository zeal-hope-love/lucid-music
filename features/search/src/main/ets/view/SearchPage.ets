/*
 * Lucid Music - 搜索页面 (一镜到底目标页)
 */
import { curves } from '@kit.ArkUI';
import { SearchPageExtraInfo } from 'musicbasic';

// [Start bind_id]
@Component
export struct SearchPage {
  @Prop param: SearchPageExtraInfo = new SearchPageExtraInfo();
  private pageInfos: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Column() {
        Row({ space: 8 }) {
          Image($r('app.media.startIcon'))
            .width(40)
            .height(40)
            .borderRadius(20)
            .onClick(() => {
              this.onArrowClicked();
            })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .animation({ duration: 200, delay: 150, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) }),
              TransitionEffect.OPACITY
                .animation({ duration: 200, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) })
            ))

          Search({ placeholder: 'DevEco Studio' })
            .height(40)
            .placeholderColor($r('sys.color.mask_secondary'))
            .width('85%')
            .backgroundColor('#0D000000')
            .height(40)
            // bind geometry id — 目标页搜索框设为"锚点"
            .geometryTransition('SEARCH_ONE_SHOT_DEMO_TRANSITION_ID')
            .transition(TransitionEffect.opacity(0.99))
            .defaultFocus(true)
            .focusOnTouch(true)
        }
        .width('100%')
        .height(50)
        .alignItems(VerticalAlign.Center)
        .padding(16)
      }
      .size({
        width: '100%',
        height: '100%'
      })
      .margin({ top: 16 })
    }
    .transition(TransitionEffect.OPACITY)
    .hideTitleBar(true)
    .backgroundColor('#F1F3F5')
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
    .onBackPressed(() => {
      this.getUIContext().animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38),
      }, () => {
        this.pageInfos.pop(false);
      })
      return true;
    })
  }

  // 返回按钮 — 弹簧曲线反向转场
  private onArrowClicked(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.pageInfos.pop(false);
    })
  }
}
// [End bind_id]

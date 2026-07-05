/*
 * Lucid Music - 首页 (含搜索一镜到底转场)
 */
import { curves } from '@kit.ArkUI';
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';

// [Start set_geometry_transition]
@Component
export struct HomePage {
  @State isSearching: boolean = false;
  @State transitionEffect: TransitionEffect = TransitionEffect.IDENTITY;
  private pageInfos: NavPathStack = new NavPathStack();

  build() {
    Stack() {
      // 搜索详情页 — HdsNavDestination + systemMaterialEffect 沉浸光感
      if (this.isSearching) {
        HdsNavDestination() {
          Column() {
            Row({ space: 8 }) {
              Search({ placeholder: 'DevEco Studio' })
                .height(40)
                .placeholderColor($r('sys.color.mask_secondary'))
                .width('100%')
                .backgroundColor('#0D000000')
                .geometryTransition('SEARCH_ONE_SHOT_DEMO_TRANSITION_ID')
                .transition(TransitionEffect.opacity(0.99))
                .defaultFocus(true)
                .focusOnTouch(true)
            }
            .width('100%')
            .height(55)
            .alignItems(VerticalAlign.Center)
            .padding({ top: 16, bottom: 16, left: 65, right: 20 })
          }
          .size({ width: '100%', height: '100%' })
        }
        .transition(TransitionEffect.OPACITY)
        .backgroundColor('#F1F3F5')
        .titleBar({
          content: {
            title: { mainTitle: '' },
            backIcon: {
              action: () => {
                this.onBackClicked();
              }
            }
          },
          style: {
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.ADAPTIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            },
            scrollEffectOpts: {
              enableScrollEffect: true,
              scrollEffectType: ScrollEffectType.GRADIENT_BLUR
            }
          }
        })
        .hideBackButton(false)
        .onReady((context: NavDestinationContext) => {
          this.pageInfos = context.pathStack;
        })
        .onBackPressed(() => {
          this.getUIContext().animateTo({
            curve: curves.interpolatingSpring(0, 1, 342, 38),
          }, () => {
            this.isSearching = false;
          })
          return true;
        })
      }

      // 首页内容
      if (!this.isSearching) {
        Column({ space: 20 }) {
          // [Start Search_start]
          Search({ placeholder: 'Search' })
            .height(40)
            .placeholderColor($r('sys.color.mask_secondary'))
            .width('100%')
            .geometryTransition('SEARCH_ONE_SHOT_DEMO_TRANSITION_ID', { follow: true })
            .backgroundColor('#0D000000')
            .defaultFocus(false)
            .focusOnTouch(false)
            .focusable(false)
            // [End Search_start]
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Up) {
                this.showSearchPage();
              }
            })

          Text('Lucid Music')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
        }
        .size({ width: '90%', height: '100%' })
        .backgroundColor('#F1F3F5')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
  }

  // [Start showSearchPage_start]
  private showSearchPage(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isSearching = true;
    })
  }
  // [End showSearchPage_start]

  private onBackClicked(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isSearching = false;
    })
  }
}
// [End set_geometry_transition]

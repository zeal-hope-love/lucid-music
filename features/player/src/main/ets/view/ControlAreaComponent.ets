/*
 * Lucid Music - 控制区域组件 (avplayer-cpp 版本)
 * 进度条：SliderStyle.NONE + springMotion 拖动动画
 * 播放按钮：保留 SymbolGlyph（因 Image 资源不存在）
 */
import { curves, PromptAction } from '@kit.ArkUI';
import { BreakpointConstants } from '../constants/BreakpointConstants';
import { ContentConstants } from '../constants/ContentConstants';
import { MusicPlayMode, PlayerConstants, PlayModeSwitchList, SILENT_ID, VOLUME_ID } from '../constants/PlayerConstants';
import { StyleConstants } from '../constants/StyleConstants';
import { BreakpointType } from '../utils/BreakpointSystem';
import Logger from '../utils/LoggerAdapter';
import { ResourceConversion } from '../utils/ResourceConversion';
import { SongItem, SongDataSource } from 'musicbasic';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { common } from '@kit.AbilityKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { MediaTools } from '../controller/MediaTools';

const TAG = 'ControlAreaComponent';

@Component
export struct ControlAreaComponent {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageLink('isPlay') isPlay: boolean = false;
  @StorageLink('currentTime') currentTime: string = '00:00';
  @StorageLink('totalTime') totalTime: string = '00:00';
  @StorageLink('progress') value: number = 0;
  @StorageLink('progressMax') max: number = 0;
  @State playModeIndex: number = 0;
  @StorageLink('imageColor') imageColor: string = '';
  @StorageLink('pageShowTime') pageShowTime: number = 0;
  @StorageLink('songList') songList: SongItem[] = [];
  @StorageLink('currentPlaylistTitle') currentPlaylistTitle: string = '最近播放';
  @State isShowPlayList: boolean = false;
  @StorageLink('playMode') @Watch('syncPlayModeIndex') playMode: MusicPlayMode = PlayModeSwitchList[this.playModeIndex];
  @StorageLink('selectIndex') selectIndex: number = 0;
  @StorageProp('playbackStatus') playbackStatus: string = 'idle';
  @StorageProp('playbackStatusMessage') playbackStatusMessage: string = '';
  @StorageLink('isSilentMode') @Watch('isSilentModeChange') isSilentMode: boolean = false;
  @State speed: number = 1;
  @StorageLink('currentVolume') @Watch('currentVolumeChange') volume: number = 0;
  @State isShowSpeedBuild: boolean = false;
  @State isShowVolumeBuild: boolean = false;
  @State songTimeFontSize: number = 10;
  @State songTimeFontColor: Resource = $r('app.color.play_text_color');
  @State trackThickness: number = 6;
  private scroller: Scroller = new Scroller();
  private resourceConversion: ResourceConversion = new ResourceConversion();
  private context: common.UIAbilityContext | undefined = AppStorage.get('context');
  uiContext: UIContext = this.getUIContext();
  promptAction: PromptAction = this.uiContext.getPromptAction();
  private playerController: AudioPlayerController = AudioPlayerController.getInstance();

  isSilentModeChange() {
    this.playerController.setMuted(this.isSilentMode)
  }

  currentVolumeChange() {
    this.playerController.setVolume(this.volume / 100)
  }

  syncPlayModeIndex() {
    const idx = PlayModeSwitchList.indexOf(this.playMode)
    if (idx >= 0) {
      this.playModeIndex = idx
    }
  }

  switchPlayMode() {
    const next = this.playerController.cyclePlayMode();
    this.promptAction.openToast({
      message: `${next === MusicPlayMode.ORDER ?
        this.resourceConversion.getStringValueFromResource($r('app.string.sequential_playback')) :
        next === MusicPlayMode.RANDOM ?
          this.resourceConversion.getStringValueFromResource($r('app.string.random_playback')) :
          this.resourceConversion.getStringValueFromResource($r('app.string.single_playback'))}`
    });
  }

  build() {
    Column() {
      // === 进度条（SlidingStyle.NONE + springMotion 拖动动画）===
      Column() {
        Slider({ min: 0, max: this.max, step: 1, style: SliderStyle.NONE, value: this.value })
          .trackThickness(this.trackThickness)
          .selectedColor($r('app.color.slider_select'))
          .trackColor($r('app.color.slider_track'))
          .onChange((val: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.End) {
              this.playerController.seek(val);
              this.getUIContext()?.animateTo({ curve: curves.springMotion() }, () => {
                this.trackThickness = 6;
                this.songTimeFontSize = 10;
                this.songTimeFontColor = $r('app.color.play_text_color');
              })
            }
            if (mode === SliderChangeMode.Moving) {
              this.currentTime = MediaTools.msToCountdownTime(val)
              this.getUIContext()?.animateTo({ curve: curves.springMotion() }, () => {
                this.trackThickness = 10;
                this.songTimeFontSize = 12;
                this.songTimeFontColor = $r('app.color.slider_select');
              })
            }
            this.pageShowTime = 0;
          })
          .height($r('app.float.slider_height'))
          .margin({
            left: new BreakpointType({
              sm: $r('app.float.slider_margin_sm'), md: $r('app.float.slider_margin_md'), lg: $r('app.float.slider_margin_lg')
            }).getValue(this.currentBreakpoint),
            right: new BreakpointType({
              sm: $r('app.float.slider_margin_sm'), md: $r('app.float.slider_margin_md'), lg: $r('app.float.slider_margin_lg')
            }).getValue(this.currentBreakpoint)
          })
          .width(StyleConstants.FULL_WIDTH)
          .hitTestBehavior(HitTestMode.Block)

        Row() {
          Text(this.currentTime)
            .fontColor(this.songTimeFontColor).fontSize(this.songTimeFontSize)
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK).lineHeight('14vp')
          Text(this.totalTime)
            .fontColor(this.songTimeFontColor).fontSize(this.songTimeFontSize)
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK).lineHeight('14vp')
        }
        .width(StyleConstants.FULL_WIDTH).justifyContent(FlexAlign.SpaceBetween)
      }
      .margin({
        top: $r('app.float.slider_margin_top'),
        bottom: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
          $r('app.float.slider_margin_bottom_lg') : $r('app.float.slider_margin_bottom')
      })

      // === 播放状态文字（固定高度 + visibility 控制显隐，避免布局抖动） ===
      Row() {
        Text(this.playbackStatusMessage || this.playbackStatus)
          .fontSize(12)
          .fontColor(Color.White)
          .opacity(0.7)
      }
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.Center)
      .height(16)
      .margin({ top: 0 })
      .offset({ y: -28 })
      .visibility(this.playbackStatus !== 'idle' && this.playbackStatus !== 'ready' ?
        Visibility.Visible : Visibility.Hidden)

      // === 播放控制按钮 ===
      Row() {
        SymbolGlyph(this.playMode === MusicPlayMode.ORDER ? $r('sys.symbol.order_play') :
          this.playMode === MusicPlayMode.RANDOM ? $r('sys.symbol.shuffle') : $r('sys.symbol.repeat_1'))
          .fontSize(20).renderingStrategy(SymbolRenderingStrategy.SINGLE).fontColor([Color.White]).opacity(0.5)
          .onClick(() => { this.switchPlayMode() })

        Image($r('app.media.ic_public_forward'))
          .controlImageBuilder()
          .width(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
            $r('app.float.control_width_lg') : $r('app.float.control_width'))
          .onClick(() => { this.playerController.playPrevious(); this.pageShowTime = 0; })

        Image(this.isPlay ? $r('app.media.ic_public_play') : $r('app.media.ic_public_pause'))
          .controlImageBuilder()
          .width(new BreakpointType({
            sm: $r('app.float.image_play_width'), md: $r('app.float.image_play_width'), lg: $r('app.float.image_play_width_lg')
          }).getValue(this.currentBreakpoint))
          .onClick(() => {
            this.isPlay ? this.playerController.pause() : this.playerController.play();
            this.pageShowTime = 0;
          })

        Image($r('app.media.ic_public_next'))
          .controlImageBuilder()
          .width(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
            $r('app.float.control_width_lg') : $r('app.float.control_width'))
          .onClick(() => { this.playerController.playNext(); this.pageShowTime = 0; })

        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(20).renderingStrategy(SymbolRenderingStrategy.SINGLE).fontColor([Color.White]).opacity(0.5)
          .onClick(() => { this.isShowPlayList = true; })
          .bindSheet($$this.isShowPlayList, this.musicListBuilder(), {
            detents: [SheetSize.MEDIUM], dragBar: false, showClose: false, preferType: SheetType.CENTER,
            onWillAppear: () => { this.scroller.scrollToIndex(this.selectIndex, false, ScrollAlign.CENTER); }
          })
      }
      .width(StyleConstants.FULL_WIDTH).justifyContent(FlexAlign.SpaceBetween)
    }
  }

  @Builder musicListBuilder() {
    Column() {
      // 标题栏（对齐控制栏 MiniPlayerBar.playlistSheetBuilder）
      Row() {
        Text(this.currentPlaylistTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.songList.length} 首`)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Divider().strokeWidth(0.5).color('#1A000000')

      // 歌曲列表
      if (this.songList.length > 0) {
        List({ scroller: this.scroller }) {
          LazyForEach(new SongDataSource(this.songList), (item: SongItem, index: number) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(item.title as string)
                    .fontSize(15)
                    .fontWeight(this.selectIndex === index ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                  Text(item.singer as string)
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)

                if (this.selectIndex === index && this.isPlay) {
                  SymbolGlyph($r('sys.symbol.play_fill'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_primary')])
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 14, bottom: 14 })
              .onClick(() => {
                this.playerController.switchToIndex(index)
              })
            }
          }, (item: SongItem, index: number) => item.toString() + index.toString())
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Off)
        .listDirection(Axis.Vertical)
        .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 20, endMargin: 20 })
      } else {
        Column() {
          Text('播放列表为空')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 40 })
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  @Builder volumeBuilder() {
    Column() {
      this.volumeTitle()
      Row() {
        Slider({ value: this.volume, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
          .showTips(false).layoutWeight(1)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.volume = value;
            if (this.volume === 0) { this.isSilentMode = true } else { this.isSilentMode = false; }
          })
      }
      .padding({ left: 8, right: 8 })
    }
    .backgroundColor(Color.White)
    .padding({
      top: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? 0 : $r('app.float.list_area_padding_top'),
      bottom: $r('app.float.list_area_padding_bottom')
    })
  }

  @Builder volumeTitle() {
    Row() {
      Text($r('app.string.volume_setting'))
        .maxLines(ContentConstants.PLAY_ALL_MAX_LINES).fontColor(Color.Black).fontWeight(FontWeight.Bold)
        .fontSize(new BreakpointType({
          sm: $r('app.float.play_font_sm'), md: $r('app.float.play_font_md'), lg: $r('app.float.play_font_lg')
        }).getValue(this.currentBreakpoint))
    }
    .height($r('app.float.play_all_area_height')).width(StyleConstants.FULL_WIDTH).backgroundColor(Color.White)
    .padding({ top: 18, left: $r('app.float.play_all_area_padding'), right: $r('app.float.play_all_area_padding') })
    .borderRadius({ topRight: $r('app.float.play_all_border_radius'), topLeft: $r('app.float.play_all_border_radius') })
  }

  @Builder speedBuilder() {
    Column() {
      this.speedTitle()
      Row() {
        Text($r('app.string.playback_speed'))
          .fontSize(16).fontWeight(FontWeight.Bold)
        Text(` ${this.speed.toString()}x`)
          .fontSize(16).fontWeight(FontWeight.Bold).layoutWeight(1)
      }
      .padding({ top: 20, left: 12, right: 12, bottom: 10 })

      Row() {
        Slider({ value: this.speed, min: 0.25, max: 2, step: 0.25, style: SliderStyle.InSet })
          .blockSize({ width: 28, height: 28 }).trackThickness(35)
          .trackColor($r('sys.color.button_background_color_transparent'))
          .selectedColor(Color.Transparent)
          .layoutWeight(1).width('100%').showTips(false).showSteps(true)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.speed = value;
            this.playerController.setSpeed(this.speed);
          })
      }
      .padding({ left: 8, right: 8 })
    }
    .backgroundColor(Color.White)
    .padding({
      top: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? 0 : $r('app.float.list_area_padding_top'),
      bottom: $r('app.float.list_area_padding_bottom')
    })
  }

  @Builder speedTitle() {
    Row() {
      Text($r('app.string.speed_setting'))
        .maxLines(ContentConstants.PLAY_ALL_MAX_LINES).fontColor(Color.Black).fontWeight(FontWeight.Bold)
        .fontSize(new BreakpointType({
          sm: $r('app.float.play_font_sm'), md: $r('app.float.play_font_md'), lg: $r('app.float.play_font_lg')
        }).getValue(this.currentBreakpoint))
    }
    .height($r('app.float.play_all_area_height')).width(StyleConstants.FULL_WIDTH).backgroundColor(Color.White)
    .padding({ top: 18, left: $r('app.float.play_all_area_padding'), right: $r('app.float.play_all_area_padding') })
    .borderRadius({ topRight: $r('app.float.play_all_border_radius'), topLeft: $r('app.float.play_all_border_radius') })
  }
}

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}

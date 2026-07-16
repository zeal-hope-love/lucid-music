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
import { SongItem } from '../viewmodel/SongData';
import { SongDataSource } from '../viewmodel/SongDataSource';
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
    if (this.playModeIndex === PlayModeSwitchList.length - 1) {
      this.playModeIndex = 0;
    } else {
      this.playModeIndex++;
    }
    this.playMode = PlayModeSwitchList[this.playModeIndex];
    this.promptAction.openToast({
      message: `${this.playMode === MusicPlayMode.ORDER ?
        this.resourceConversion.getStringValueFromResource($r('app.string.sequential_playback')) :
        this.playMode === MusicPlayMode.RANDOM ?
          this.resourceConversion.getStringValueFromResource($r('app.string.random_playback')) :
          this.resourceConversion.getStringValueFromResource($r('app.string.single_playback'))}`
    });
    this.playerController.setPlayMode(this.playMode);
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

        // === 播放状态文字（紧贴时间行） ===
        if (this.playbackStatus !== 'idle' && this.playbackStatus !== 'ready') {
          Text(this.playbackStatusMessage || this.playbackStatus)
            .fontSize(12)
            .fontColor(Color.White)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 0 })
        }
      }
      .margin({
        top: $r('app.float.slider_margin_top'),
        bottom: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
          $r('app.float.slider_margin_bottom_lg') : $r('app.float.slider_margin_bottom')
      })

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
            detents: [SheetSize.MEDIUM], dragBar: false, showClose: true, preferType: SheetType.CENTER,
            onWillAppear: () => { this.scroller.scrollToIndex(this.selectIndex, false, ScrollAlign.CENTER); }
          })
      }
      .width(StyleConstants.FULL_WIDTH).justifyContent(FlexAlign.SpaceBetween)
    }
  }

  @Builder musicListBuilder() {
    Column() {
      this.playListTitle();
      List({ scroller: this.scroller }) {
        LazyForEach(new SongDataSource(this.songList), (item: SongItem, index: number) => {
          ListItem() {
            MusicListContainer({ item: item, index: index })
              .reuseId(`song_${item.id}`);
          }
        }, (item: SongItem, index: number) => item.toString() + index.toString())
      }
      .height(StyleConstants.FULL_HEIGHT).width(StyleConstants.FULL_WIDTH)
      .backgroundColor(Color.White).margin({ top: $r('app.float.list_area_margin_top') })
      .lanes(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
        ContentConstants.COL_TWO : ContentConstants.COL_ONE)
      .layoutWeight(1)
      .divider({
        color: $r('app.color.list_divider'), strokeWidth: $r('app.float.stroke_width'),
        startMargin: $r('app.float.list_item_padding'), endMargin: $r('app.float.list_item_padding')
      })
    }
    .padding({
      top: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? 0 : $r('app.float.list_area_padding_top'),
      bottom: $r('app.float.list_area_padding_bottom')
    })
    .backgroundColor(Color.White)
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

  @Builder playListTitle() {
    Row() {
      Text($r('app.string.play_list', this.songList.length))
        .maxLines(ContentConstants.PLAY_ALL_MAX_LINES).padding({ left: $r('app.float.play_all_text_padding') })
        .fontColor(Color.Black).fontWeight(FontWeight.Bold)
        .fontSize(new BreakpointType({
          sm: $r('app.float.play_font_sm'), md: $r('app.float.play_font_md'), lg: $r('app.float.play_font_lg')
        }).getValue(this.currentBreakpoint))
    }
    .height($r('app.float.play_all_area_height')).width(StyleConstants.FULL_WIDTH).backgroundColor(Color.White)
    .padding({ top: 18, left: $r('app.float.play_all_area_padding'), right: $r('app.float.play_all_area_padding') })
    .borderRadius({ topRight: $r('app.float.play_all_border_radius'), topLeft: $r('app.float.play_all_border_radius') })
    .position({ x: 0, y: 0 })
  }
}

@Reusable
@Component
struct MusicListContainer {
  @StorageLink('isPlay') isPlay: boolean = false;
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageLink('selectIndex') selectIndex: number = 0;
  item: SongItem | undefined = undefined;
  index: number | undefined = undefined;

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.item!.title)
            .fontColor(this.selectIndex === this.index && this.isPlay ? Color.Red : Color.Black)
            .fontSize(new BreakpointType({
              sm: $r('app.float.item_font_sm'), md: $r('app.float.item_font_md'), lg: $r('app.float.item_font_lg')
            }).getValue(this.currentBreakpoint))
            .margin({ bottom: $r('app.float.list_item_title_margin') })
          Row() {
            Image(this.item!.mark)
              .width($r('app.float.list_item_image_size')).height($r('app.float.list_item_image_size'))
              .margin({ right: $r('app.float.list_item_image_margin') })
            Text(this.item!.singer)
              .opacity($r('app.float.singer_opacity'))
              .fontColor(this.selectIndex === this.index && this.isPlay ? Color.Red : Color.Black)
              .fontSize(new BreakpointType({
                sm: $r('app.float.singer_title_sm'), md: $r('app.float.singer_title_md'), lg: $r('app.float.singer_title_lg')
              }).getValue(this.currentBreakpoint))
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .onClick(() => {
        AppStorage.setOrCreate('selectIndex', this.index!)
        AppStorage.setOrCreate('pendingPlayIndex', this.index!)
      })
      .height($r('app.float.list_item_height')).width(StyleConstants.FULL_WIDTH)
    }
    .padding({ left: $r('app.float.list_item_padding'), right: $r('app.float.list_item_padding') })
  }
}

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}

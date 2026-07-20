/*
 * Lucid Music - AVSession 播控中心 / 锁屏控制
 */
import { common, wantAgent } from '@kit.AbilityKit'
import { avSession } from '@kit.AVSessionKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { image } from '@kit.ImageKit'
import { util } from '@kit.ArkTS'
import { AppStorageV2 } from '@kit.ArkUI'
import { AppStorageKeys, CurrentTabState, Logger, MusicAppState, MusicDbApi } from 'musicbasic'
import { MusicPlayMode, PlayModeSwitchList } from '../constants/PlayerConstants'
import { AudioPlayerController } from './AudioPlayerController'

const TAG = 'AVSessionController'

export class AVSessionController {
  private avSessionImpl?: avSession.AVSession
  private context: common.UIAbilityContext | undefined = undefined
  private static instance: AVSessionController

  /** 外部注入的锁屏回调 */
  public onPlayRequested?: () => void
  public onPauseRequested?: () => void
  public onNextRequested?: () => void
  public onPrevRequested?: () => void
  public onSeekRequested?: (ms: number) => void
  /** 用于 favoriteVersion 递增通知 MusicListPage 刷新 */
  private currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!

  public static getInstance(): AVSessionController {
    if (!AVSessionController.instance) {
      AVSessionController.instance = new AVSessionController()
    }
    return AVSessionController.instance
  }

  public async initAVSession(): Promise<void> {
    if (this.avSessionImpl) {
      return
    }
    this.context = AppStorage.get('context')
    if (!this.context) {
      Logger.error(`${TAG}: context undefined, AVSession init failed`)
      return
    }
    this.avSessionImpl = await avSession.createAVSession(this.context, 'PLAY_AUDIO', 'audio')
    await this.avSessionImpl.activate()
    Logger.info(`${TAG}: AVSession created, sessionId=${this.avSessionImpl.sessionId}`)
    this.setLaunchAbility()
    this.setListenerForControllerEvents()
  }

  public async updateMetadata(
    songId: number,
    titleStr: string | Resource,
    artistStr: string | Resource,
    labelRes: Resource,
    lyricFile: string,
    duration: number,
    lyricText?: string,
    coverUrl?: string
  ): Promise<void> {
    if (!this.avSessionImpl) {
      return
    }
    const title = typeof titleStr === 'string' ? titleStr : '未知歌曲'
    const artist = typeof artistStr === 'string' ? artistStr : '未知歌手'

    // ===== 步骤①：立即设置基本信息（title/artist/duration 必达媒体中心） =====
    const baseMeta: avSession.AVMetadata = {
      assetId: `${songId}`,
      title: title,
      artist: artist,
      duration: duration,
      avQueueName: 'AudioPlayerQueue',
      avQueueId: `${songId}`
    }
    this.avSessionImpl.setAVMetadata(baseMeta)
    Logger.info(`${TAG}: setAVMetadata(base) success, title=${title}, artist=${artist}, duration=${duration}`)

    // ===== 步骤②：异步加载封面和歌词，成功后再更新 =====
    if (this.context) {
      let mediaImage: PixelMap | undefined = undefined
      let lyric: string | undefined = undefined

      try {
        if (coverUrl && coverUrl.length > 0) {
          const httpResp = await http.createHttp().request(coverUrl, {
            method: http.RequestMethod.GET,
            connectTimeout: 5000,
            readTimeout: 5000
          })
          if (httpResp.responseCode === 200 && httpResp.result) {
            const imageSource = image.createImageSource(httpResp.result as ArrayBuffer)
            mediaImage = await imageSource.createPixelMap()
          }
        } else if (this.context) {
          try {
            const fileData: Uint8Array = await this.context.resourceManager.getMediaContent(labelRes.id)
            mediaImage = await image.createImageSource(fileData.buffer as ArrayBuffer).createPixelMap()
          } catch (_) { /* label 资源不可用，跳过 */ }
        }
      } catch (_) {
        Logger.warn(`${TAG}: failed to get cover image`)
      }

      if (lyricText && lyricText.length > 0) {
        lyric = lyricText
      } else if (lyricFile && lyricFile.length > 0) {
        try {
          const lyricData: Uint8Array = await this.context.resourceManager.getRawFileContent(lyricFile)
          const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
          lyric = decoder.decodeToString(lyricData, { stream: false })
        } catch (_) {
          Logger.warn(`${TAG}: failed to get lyric`)
        }
      }

      // ===== 步骤③：有封面或歌词则更新完整元数据 =====
      if (mediaImage || lyric) {
        const fullMeta: avSession.AVMetadata = {
          assetId: `${songId}`,
          title: title,
          artist: artist,
          duration: duration,
          mediaImage: mediaImage,
          avQueueName: 'AudioPlayerQueue',
          avQueueId: `${songId}`
        }
        if (lyric) {
          fullMeta.lyric = lyric
        }
        this.avSessionImpl.setAVMetadata(fullMeta)
        Logger.info(`${TAG}: setAVMetadata(full) success, hasCover=${mediaImage !== undefined}, hasLyric=${lyric !== undefined}`)
      }
    }
  }

  public setPlayState(isPlay: boolean): void {
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.setAVPlaybackState({
      state: isPlay
        ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
        : avSession.PlaybackState.PLAYBACK_STATE_PAUSE
    }, (err: BusinessError) => {
      if (err) {
        Logger.error(`${TAG}: setPlayState error code=${err.code}`)
      }
    })
  }

  public setProgressState(ms: number): void {
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.setAVPlaybackState({
      position: {
        elapsedTime: ms,
        updateTime: new Date().getTime()
      }
    }, (err: BusinessError) => {
      if (err) {
        Logger.error(`${TAG}: setProgressState error code=${err.code}`)
      }
    })
  }

  public destroy(): void {
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.off('play')
    this.avSessionImpl.off('pause')
    this.avSessionImpl.off('playNext')
    this.avSessionImpl.off('playPrevious')
    this.avSessionImpl.off('seek')
    this.avSessionImpl.off('setLoopMode')
    this.avSessionImpl.off('toggleFavorite')
    this.avSessionImpl.destroy()
    this.avSessionImpl = undefined
  }

  // ==================== 私有 ====================

  private setLaunchAbility(): void {
    if (!this.context) {
      return
    }
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name
      }],
      operationType: wantAgent.OperationType.START_ABILITIES,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }
    wantAgent.getWantAgent(info)
      .then((agent) => {
        if (this.avSessionImpl) {
          this.avSessionImpl.setLaunchAbility(agent)
        }
      })
      .catch((err: BusinessError) =>
        Logger.error(`${TAG}: getWantAgent failed: ${err.message}`))
  }

  private setListenerForControllerEvents(): void {
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.on('play', () => this.onPlayRequested?.())
    this.avSessionImpl.on('pause', () => this.onPauseRequested?.())
    this.avSessionImpl.on('playNext', () => this.onNextRequested?.())
    this.avSessionImpl.on('playPrevious', () => this.onPrevRequested?.())
    this.avSessionImpl.on('seek', (ms: number) => this.onSeekRequested?.(ms))
    this.avSessionImpl.on('setLoopMode', this.onSetLoopMode)
    this.avSessionImpl.on('toggleFavorite', this.onToggleFavorite)
  }

  private onSetLoopMode: (loopMode: avSession.LoopMode) => void = (loopMode) => {
    let mappedMode: MusicPlayMode
    switch (loopMode) {
      case avSession.LoopMode.LOOP_MODE_SINGLE:
        mappedMode = MusicPlayMode.ORDER
        break
      case avSession.LoopMode.LOOP_MODE_SEQUENCE:
        mappedMode = MusicPlayMode.RANDOM
        break
      case avSession.LoopMode.LOOP_MODE_SHUFFLE:
        mappedMode = MusicPlayMode.SINGLE_CYCLE
        break
      default:
        mappedMode = MusicPlayMode.ORDER
        break
    }
    AudioPlayerController.getInstance().setPlayMode(mappedMode)
    const idx = PlayModeSwitchList.indexOf(mappedMode)
    if (idx >= 0) {
      AppStorage.setOrCreate('playModeIndex', idx)
    }
  }

  private onToggleFavorite: (assetId: string) => void = (assetId: string) => {
    const appState = AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE,
      () => new MusicAppState())!
    const item = appState.getCurrentSongItem()
    if (!item) {
      return
    }
    const nowFav = MusicDbApi.getInstance().toggleFavorite(item)
    this.updateFavoriteState(assetId, nowFav)
    this.currentTabState.favoriteVersion++
  }

  // ==================== loopMode ====================

  public setPlayModeToAVSession(currentPlayMode: MusicPlayMode): void {
    let avSessionLoopMode: avSession.LoopMode = avSession.LoopMode.LOOP_MODE_SEQUENCE
    switch (currentPlayMode) {
      case MusicPlayMode.SINGLE_CYCLE:
        avSessionLoopMode = avSession.LoopMode.LOOP_MODE_SINGLE
        break
      case MusicPlayMode.ORDER:
        avSessionLoopMode = avSession.LoopMode.LOOP_MODE_SEQUENCE
        break
      case MusicPlayMode.RANDOM:
        avSessionLoopMode = avSession.LoopMode.LOOP_MODE_SHUFFLE
        break
    }
    this.setLoopModeState(avSessionLoopMode)
  }

  public setLoopModeState(avSessionLoopMode: avSession.LoopMode): void {
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.setAVPlaybackState({ loopMode: avSessionLoopMode }, (err: BusinessError) => {
      if (err) {
        Logger.error(`${TAG}: setLoopModeState error code=${err.code}`)
      } else {
        Logger.info(`${TAG}: setLoopModeState success`)
      }
    })
  }

  // ==================== favorite ====================

  public async updateFavoriteState(assetId: string, isFavorite: boolean): Promise<void> {
    AppStorage.setOrCreate('isFavorite', isFavorite)
    if (!this.avSessionImpl) {
      return
    }
    this.avSessionImpl.setAVPlaybackState({ isFavorite }, (err: BusinessError) => {
      if (err) {
        Logger.error(`${TAG}: setFavoriteState error code=${err.code}`)
      }
    })
  }

  public async getAndUpdateFavoriteState(assetId: string): Promise<void> {
    const isFavorite = AppStorage.get<boolean>('isFavorite') ?? false
    AppStorage.setOrCreate('isFavorite', isFavorite)
    if (this.avSessionImpl) {
      this.avSessionImpl.setAVPlaybackState({ isFavorite }, (err: BusinessError) => {
        if (err) {
          Logger.error(`${TAG}: getAndUpdateFavoriteState error code=${err.code}`)
        }
      })
    }
  }
}

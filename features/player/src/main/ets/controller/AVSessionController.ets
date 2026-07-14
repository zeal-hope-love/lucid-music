/*
 * Lucid Music - AVSession 播控中心 / 锁屏控制
 */
import { common, wantAgent } from '@kit.AbilityKit'
import { avSession } from '@kit.AVSessionKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from 'musicbasic'
import { MusicPlayMode } from '../constants/PlayerConstants'

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
  public onSetLoopModeRequested?: (loopMode: avSession.LoopMode) => void
  public onToggleFavoriteRequested?: (assetId: string) => void

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

  public updateMetadata(title: string, artist: string, duration: number): void {
    if (!this.avSessionImpl) {
      return
    }
    const metadata: avSession.AVMetadata = {
      assetId: '0',
      title: title,
      artist: artist,
      duration: duration
    }
    this.avSessionImpl.setAVMetadata(metadata)
      .then(() => Logger.info(`${TAG}: setAVMetadata success, title=${title}`))
      .catch((err: BusinessError) =>
        Logger.error(`${TAG}: setAVMetadata failed, code=${err.code}`))
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
    this.avSessionImpl.on('setLoopMode', (loopMode: avSession.LoopMode) => {
      this.onSetLoopModeRequested?.(loopMode)
    })
    this.avSessionImpl.on('toggleFavorite', (assetId: string) => {
      this.onToggleFavoriteRequested?.(assetId)
    })
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

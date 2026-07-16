/*
 * Lucid Music - AVPlayer 封装控制器
 */
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  AppStorageKeys, Logger, MusicAppState, MusicDbApi
} from 'musicbasic'
import { AppStorageV2 } from '@kit.ArkUI'
import { MediaTools } from './MediaTools'
import { AVSessionController } from './AVSessionController'
import { MusicPlayMode } from '../constants/PlayerConstants'

const TAG = 'AudioPlayerController'
const speedMap: Map<number, media.PlaybackSpeed> = new Map([
  [0.25, media.PlaybackSpeed.SPEED_FORWARD_0_25_X],
  [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
  [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X],
  [1.0, media.PlaybackSpeed.SPEED_FORWARD_1_00_X],
  [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X],
  [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X],
  [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X],
  [2.0, media.PlaybackSpeed.SPEED_FORWARD_2_00_X],
])

export class AudioPlayerController {
  public avPlayer?: media.AVPlayer
  private avSessionController: AVSessionController = AVSessionController.getInstance()
  private currentState: media.AVPlayerState = 'idle'
  private waitPlay: boolean = false
  private static instance: AudioPlayerController | undefined
  private appState: MusicAppState
  private playMode: MusicPlayMode = MusicPlayMode.ORDER
  private isMuted: boolean = false

  private constructor() {
    this.appState = AppStorageV2.connect(
      MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState()
    )!
  }

  public static getInstance(): AudioPlayerController {
    if (!AudioPlayerController.instance) {
      AudioPlayerController.instance = new AudioPlayerController()
    }
    return AudioPlayerController.instance
  }

  // ==================== 初始化 ====================

  public async initAVPlayer(): Promise<void> {
    if (this.avPlayer) {
      Logger.info(`${TAG}: avPlayer already created`)
      return
    }
    this.avPlayer = await media.createAVPlayer()
    Logger.info(`${TAG}: createAVPlayer success, state=${this.avPlayer.state}`)
    this.setAVPlayerCallbacks()
  }

  // ==================== 加载并播放 ====================

  public async loadAndPlay(url: string): Promise<void> {
    if (!this.avPlayer) {
      Logger.error(`${TAG}: avPlayer not initialized`)
      return
    }
    if (!url) {
      Logger.error(`${TAG}: url is empty`)
      this.syncPlaybackStatus('error', '播放地址为空')
      return
    }
    if (this.currentState !== 'idle') {
      await this.avPlayer.reset()
    }
    this.syncPlaybackStatus('preparing', '正在准备播放...')
    if (url.startsWith('http://') || url.startsWith('https://')) {
      this.avPlayer.url = url
    } else {
      const ctx = AppStorage.get('context') as common.UIAbilityContext
      const rawFd = await ctx.resourceManager.getRawFd(url)
      this.avPlayer.fdSrc = { fd: rawFd.fd, offset: rawFd.offset, length: rawFd.length }
      Logger.info(`${TAG}: loadAndPlay fdSrc set, fd=${rawFd.fd}, length=${rawFd.length}`)
    }
    this.waitPlay = true
    Logger.info(`${TAG}: loadAndPlay done, state=${this.avPlayer.state}`)
  }

  // ==================== 播放控制 ====================

  public async play(): Promise<void> {
    if (!this.avPlayer) {
      return
    }
    if (this.currentState !== 'prepared' && this.currentState !== 'paused' &&
        this.currentState !== 'stopped' && this.currentState !== 'completed') {
      this.waitPlay = true
      Logger.info(`${TAG}: play deferred, state=${this.currentState}`)
      return
    }
    await this.avPlayer.play()
    this.waitPlay = false
    this.updateIsPlay(true)
  }

  public pause(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.pause()
    this.updateIsPlay(false)
  }

  public togglePlay(): void {
    if (this.appState.isPlay) {
      this.pause()
    } else {
      this.play()
    }
  }

  public seek(ms: number): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.seek(ms)
  }

  // ==================== 切歌 ====================

  public playNext(): void {
    const len = this.appState.getQueueLength()
    if (len === 0) {
      return
    }
    let nextIndex = this.appState.selectIndex
    switch (this.playMode) {
      case MusicPlayMode.SINGLE_CYCLE:
        // 单曲循环：不改变索引
        break
      case MusicPlayMode.ORDER:
        nextIndex = this.appState.selectIndex >= len - 1 ? 0 : this.appState.selectIndex + 1
        break
      case MusicPlayMode.RANDOM:
        nextIndex = Math.floor(Math.random() * len)
        if (nextIndex === this.appState.selectIndex && len > 1) {
          nextIndex = (nextIndex + 1) % len
        }
        break
    }
    this.appState.selectIndex = nextIndex
    this.appState.remoteSongItem = null
    AppStorage.setOrCreate('selectIndex', nextIndex)
    this.playCurrent()
  }

  public playPrevious(): void {
    const len = this.appState.getQueueLength()
    if (len === 0) {
      return
    }
    let prevIndex = this.appState.selectIndex
    switch (this.playMode) {
      case MusicPlayMode.SINGLE_CYCLE:
        break
      case MusicPlayMode.ORDER:
        prevIndex = this.appState.selectIndex <= 0 ? len - 1 : this.appState.selectIndex - 1
        break
      case MusicPlayMode.RANDOM:
        prevIndex = Math.floor(Math.random() * len)
        if (prevIndex === this.appState.selectIndex && len > 1) {
          prevIndex = (prevIndex + 1) % len
        }
        break
    }
    this.appState.selectIndex = prevIndex
    this.appState.remoteSongItem = null
    AppStorage.setOrCreate('selectIndex', prevIndex)
    this.playCurrent()
  }

  public async playCurrent(): Promise<void> {
    const songItem = this.appState.getCurrentSongItem()
    if (!songItem) {
      Logger.warn(`${TAG}: playCurrent, no current song`)
      return
    }
    MusicDbApi.getInstance().addRecentPlay(songItem.id)
    try {
      const url: string = songItem.src
      if (url) {
        await this.loadAndPlay(url)
      } else {
        Logger.warn(`${TAG}: no audio source for current song`)
      }
    } catch (e) {
      Logger.error(`${TAG}: playCurrent error ${JSON.stringify(e)}`)
    }
  }

  // ==================== 音量 ====================

  public setVolume(volume: number): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.setVolume(volume)
    this.appState.volume = volume
  }

  // ==================== 倍速 / 播放模式 / 静音 ====================

  public setSpeed(speed: number): void {
    if (!this.avPlayer) {
      return
    }
    const playbackSpeed = speedMap.get(speed)
    if (playbackSpeed !== undefined) {
      this.avPlayer.setSpeed(playbackSpeed)
    }
  }

  public setPlayMode(mode: MusicPlayMode): void {
    this.playMode = mode
    AppStorage.setOrCreate('playMode', mode)
    this.avSessionController.setPlayModeToAVSession(mode)
  }

  public getCurrentVolume(): number {
    return Math.round(this.appState.volume * 100)
  }

  public setMuted(muted: boolean): void {
    if (!this.avPlayer) {
      return
    }
    this.isMuted = muted
    this.avPlayer.setMediaMuted(media.MediaType.MEDIA_TYPE_AUD, muted)
  }

  // ==================== 释放 ====================

  public async release(): Promise<void> {
    if (!this.avPlayer) {
      return
    }
    await this.avPlayer.release()
    this.avPlayer = undefined
    this.currentState = 'idle'
    Logger.info(`${TAG}: avPlayer released`)
  }

  // ==================== AVPlayer 回调 ====================

  private setAVPlayerCallbacks(): void {
    this.stateChangeCallback()
    this.errorCallback()
    this.timeUpdateCallback()
    this.audioInterruptCallback()
    this.durationUpdateCallback()
  }

  private stateChangeCallback(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on('stateChange', async (state: media.AVPlayerState) => {
      this.currentState = state
      Logger.info(`${TAG}: stateChange → ${state}`)
      switch (state) {
        case 'initialized':
          this.setAudioRendererInfo()
          await this.avPlayer!.prepare()
          break
        case 'prepared':
          this.appState.progressMax = this.avPlayer!.duration
          this.appState.totalTime = MediaTools.msToCountdownTime(this.avPlayer!.duration)
          this.syncPlaybackStatus('ready', '')
          await this.initSessionMetadata()
          if (this.waitPlay) {
            await this.avPlayer!.play()
            this.waitPlay = false
          }
          break
        case 'playing':
          this.updateIsPlay(true)
          break
        case 'paused':
          this.updateIsPlay(false)
          break
        case 'completed':
          this.updateIsPlay(false)
          this.playNext()
          break
        case 'stopped':
          this.updateIsPlay(false)
          break
      }
    })
  }

  private errorCallback(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on('error', (error: BusinessError) => {
      Logger.error(`${TAG}: error code=${error.code} msg=${error.message}`)
      this.syncPlaybackStatus('error', `播放失败: ${error.message || '未知错误'}`)
    })
  }

  private timeUpdateCallback(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.appState.progress = time
      const currentTimeStr: string = MediaTools.msToCountdownTime(time)
      this.appState.currentTime = currentTimeStr
      AppStorage.setOrCreate('progress', time)
      AppStorage.setOrCreate('currentTime', currentTimeStr)
      this.avSessionController.setProgressState(time)
    })
  }

  private durationUpdateCallback(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on('durationUpdate', (duration: number) => {
      this.appState.progressMax = duration
      const totalTimeStr: string = MediaTools.msToCountdownTime(duration)
      this.appState.totalTime = totalTimeStr
      AppStorage.setOrCreate('progressMax', duration)
      AppStorage.setOrCreate('totalTime', totalTimeStr)
    })
  }

  private audioInterruptCallback(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
          case audio.InterruptHint.INTERRUPT_HINT_STOP:
            this.pause()
            break
        }
      } else if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
        if (interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
          this.play()
        }
      }
    })
  }

  // ==================== 音频配置 ====================

  private setAudioRendererInfo(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.audioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0,
      volumeMode: audio.AudioVolumeMode.SYSTEM_GLOBAL
    }
  }

  // ==================== AVSession ====================

  private async initSessionMetadata(): Promise<void> {
    try {
      await this.avSessionController.initAVSession()
      this.avSessionController.setPlayModeToAVSession(this.playMode)
      const songItem = this.appState.getCurrentSongItem()
      if (songItem) {
        const title = typeof songItem.title === 'string' ? songItem.title : '未知歌曲'
        const artist = typeof songItem.singer === 'string' ? songItem.singer : '未知歌手'
        this.avSessionController.updateMetadata(
          songItem.id, title, artist, songItem.label, songItem.lyric,
          this.appState.progressMax, songItem.lyricText || '', songItem.coverUrl || ''
        )
        // 远程歌曲：预设置默认深色背景（避免闪烁）
        if (songItem.coverUrl) {
          this.appState.imageColor = 'rgba(20, 20, 30, 1.00)'
          AppStorage.setOrCreate('imageColor', 'rgba(20, 20, 30, 1.00)')
        }
      }
    } catch (e) {
      Logger.warn(`${TAG}: AVSession init skipped: ${JSON.stringify(e)}`)
    }
  }

  private updateIsPlay(isPlay: boolean): void {
    this.appState.isPlay = isPlay
    this.avSessionController.setPlayState(isPlay)
    AppStorage.setOrCreate('isPlay', isPlay)
  }

  private syncPlaybackStatus(status: string, message: string): void {
    this.appState.playbackStatus = status
    this.appState.playbackStatusMessage = message
    AppStorage.setOrCreate('playbackStatus', status)
    AppStorage.setOrCreate('playbackStatusMessage', message)
  }
}

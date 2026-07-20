/*
 * Lucid Music - AVPlayer 封装控制器
 */
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  AppStorageKeys, Logger, MusicAppState, MusicDbApi, MusicPlayMode, SongItem, RemotePlayHelper, AudioCacheHelper
} from 'musicbasic'
import { AppStorageV2 } from '@kit.ArkUI'
import { MediaTools } from './MediaTools'
import { AVSessionController } from './AVSessionController'
import { BackgroundUtil } from '../utils/BackgroundUtil'

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
  private preparingTimer: number = -1
  private static instance: AudioPlayerController | undefined
  private appState: MusicAppState
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
    // 清除旧超时，设置15秒兜底超时
    this.clearPreparingTimer()
    this.preparingTimer = setTimeout(() => {
      Logger.warn(`${TAG}: loadAndPlay timeout, state=${this.currentState}`)
      this.syncPlaybackStatus('error', '播放准备超时，请重试')
    }, 15000)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      this.avPlayer.url = url
    } else if (url.startsWith('/')) {
      // 本地缓存文件（绝对路径），直接按 url 播放
      this.avPlayer.url = url
      Logger.info(`${TAG}: loadAndPlay local cached file, path=${url}`)
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
    this.startBgTask()
  }

  public pause(): void {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.pause()
    this.updateIsPlay(false)
    this.stopBgTask()
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
    const allowedStates = ['prepared', 'playing', 'paused', 'completed']
    if (!allowedStates.includes(this.currentState)) {
      Logger.warn(`${TAG}: seek denied, current state=${this.currentState} not in [${allowedStates.join(',')}]`)
      return
    }
    this.avPlayer.seek(ms)
  }

  /**
   * 从外部（如 MusicListPage）发起播放：设置队列 + 选中索引 + 开始播放。
   * 这是统一的外部播放请求入口。
   */
  public async playSongAt(queue: SongItem[], index: number): Promise<void> {
    this.appState.playQueue = [...queue]
    this.appState.selectIndex = index
    this.appState.isPlay = true
    this.syncStateForNewSong()
    AppStorage.setOrCreate('isPlay', true)
    await this.playCurrent()
  }

  /**
   * 从播放列表内点击切歌：只更新索引并播放。
   */
  public switchToIndex(index: number): void {
    if (index < 0 || index >= this.appState.getQueueLength()) {
      return
    }
    this.appState.selectIndex = index
    this.syncStateForNewSong()
    this.playCurrent()
  }

  /**
   * 切换收藏状态。
   */
  public toggleFavorite(): void {
    this.appState.isFavorite = !this.appState.isFavorite
  }

  /**
   * 切歌时统一同步状态到 V1 和 V2：
   * 1. 进度归零（防止旧进度残留）
   * 2. songList 同步到 V1（解决详细页显示旧歌曲问题）
   * 3. isFavorite 同步到 V1
   */
  public syncStateForNewSong(): void {
    // 1. 进度归零 (V2 + V1)
    this.appState.progress = 0
    this.appState.currentTime = '00:00'
    this.appState.progressMax = 0
    this.appState.totalTime = '00:00'
    AppStorage.setOrCreate('progress', 0)
    AppStorage.setOrCreate('currentTime', '00:00')
    AppStorage.setOrCreate('progressMax', 0)
    AppStorage.setOrCreate('totalTime', '00:00')

    // 2. 同步 songList 到 V1（完整队列，供播放列表弹层浏览/切歌）
    const queueList: Object[] = []
    for (let i = 0; i < this.appState.playQueue.length; i++) {
      queueList.push(this.appState.playQueue[i] as Object)
    }
    AppStorage.setOrCreate('songList', queueList)
    AppStorage.setOrCreate('selectIndex', this.appState.selectIndex)

    // 3. 同步 isFavorite 到 V1
    const item = this.appState.getCurrentSongItem()
    if (item) {
      const fav = MusicDbApi.getInstance().isFavorite(item.id)
      this.appState.isFavorite = fav
      AppStorage.setOrCreate('isFavorite', fav)
    }
  }

  // ==================== 切歌 ====================

  public playNext(): void {
    const len = this.appState.getQueueLength()
    if (len === 0) {
      return
    }
    let nextIndex = this.appState.selectIndex
    switch (this.appState.playMode) {
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
    this.syncStateForNewSong()
    this.playCurrent()
  }

  public playPrevious(): void {
    const len = this.appState.getQueueLength()
    if (len === 0) {
      return
    }
    let prevIndex = this.appState.selectIndex
    switch (this.appState.playMode) {
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
    this.syncStateForNewSong()
    this.playCurrent()
  }

  public async playCurrent(): Promise<void> {
    const songItem = this.appState.getCurrentSongItem()
    if (!songItem) {
      Logger.warn(`${TAG}: playCurrent, no current song`)
      return
    }
    try {
      let url: string = songItem.src
      const isRemote = !!songItem.platform && !!songItem.remoteSongId
      const cacheKey: string = isRemote ? `${songItem.platform}_${songItem.remoteSongId}` : ''

      // 1. 命中磁盘缓存 → 直接播本地文件，并离线回填歌曲信息/歌词/封面，跳过取流
      if (cacheKey) {
        const cached = AudioCacheHelper.getInstance().getCachedAudio(cacheKey)
        if (cached) {
          // 注意：不修改 songItem.src（保留远程 URL/空），以便缓存被清理后能正确回退在线取流
          songItem.lyricText = cached.meta.lyricText
          songItem.coverUrl = cached.imagePath || cached.meta.coverUrl
          if (typeof cached.meta.title === 'string') {
            songItem.title = cached.meta.title
          }
          if (typeof cached.meta.artist === 'string') {
            songItem.singer = cached.meta.artist
          }
          Logger.info(`${TAG}: playCurrent cache hit key=${cacheKey}`)
          MusicDbApi.getInstance().addRecentPlay(songItem)
          await this.loadAndPlay(cached.audioPath)
          return
        }
      }

      // 2. 在线歌：src 为空但有 platform + remoteSongId → 现取流并回填
      if (!url && isRemote) {
        this.syncPlaybackStatus('requesting_url', '正在请求播放地址...')
        const resolved = await RemotePlayHelper.resolveUrlForQueue(songItem, (status, message) => {
          this.syncPlaybackStatus(status, message)
        })
        if (resolved) {
          url = resolved
          songItem.src = resolved
        }
      }
      MusicDbApi.getInstance().addRecentPlay(songItem)
      Logger.info(`${TAG}: playCurrent srcUrl - prefix=${url.substring(0, 100)}, len=${url.length}, id=${songItem.id}`)
      if (url) {
        await this.loadAndPlay(url)
        // 3. 后台落盘（仅在线歌且未命中缓存时）：音频+封面+歌词+歌曲信息
        if (cacheKey && (url.startsWith('http://') || url.startsWith('https://'))) {
          AudioCacheHelper.getInstance().cacheRemoteSong(cacheKey, songItem, url)
        }
      } else {
        Logger.warn(`${TAG}: no audio source for current song`)
        this.syncPlaybackStatus('error', '获取播放地址失败')
        this.appState.isPlay = false
        this.stopBgTask()
        this.updateIsPlay(false)
        if (this.avPlayer && this.currentState !== 'idle') {
          await this.avPlayer.reset()
        }
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
    this.appState.setPlayMode(mode)
    this.avSessionController.setPlayModeToAVSession(mode)
  }

  /**
   * 推进到下一播放模式（顺序 → 随机 → 单曲循环），经 {@link MusicAppState.cyclePlayMode} 统一处理。
   * @returns 切换后的新模式
   */
  public cyclePlayMode(): MusicPlayMode {
    const next = this.appState.cyclePlayMode()
    this.avSessionController.setPlayModeToAVSession(next)
    return next
  }

  public getCurrentVolume(): number {
    return Math.round(this.appState.volume * 100)
  }

  public setMuted(muted: boolean): void {
    if (!this.avPlayer) {
      return
    }
    this.isMuted = muted
    this.appState.isSilentMode = muted
    this.avPlayer.setMediaMuted(media.MediaType.MEDIA_TYPE_AUD, muted)
  }

  // ==================== 后台长时任务 ====================

  private startBgTask(): void {
    const ctx = AppStorage.get('context') as common.UIAbilityContext
    if (ctx) {
      BackgroundUtil.startContinuousTask(ctx)
    }
  }

  private stopBgTask(): void {
    const ctx = AppStorage.get('context') as common.UIAbilityContext
    if (ctx) {
      BackgroundUtil.stopContinuousTask(ctx)
    }
  }

  // ==================== 超时清理 ====================

  private clearPreparingTimer(): void {
    if (this.preparingTimer !== -1) {
      clearTimeout(this.preparingTimer)
      this.preparingTimer = -1
    }
  }

  // ==================== 释放 ====================

  public async release(): Promise<void> {
    if (!this.avPlayer) {
      return
    }
    this.clearPreparingTimer()
    this.stopBgTask()
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
          this.clearPreparingTimer()
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
          this.startBgTask()
          break
        case 'paused':
          this.updateIsPlay(false)
          this.stopBgTask()
          break
        case 'completed':
          this.updateIsPlay(false)
          this.stopBgTask()
          this.playNext()
          break
        case 'stopped':
          this.updateIsPlay(false)
          this.stopBgTask()
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
      if (this.currentState !== 'playing') {
        return
      }
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
      this.avSessionController.setPlayModeToAVSession(this.appState.playMode)
      const songItem = this.appState.getCurrentSongItem()
      if (songItem) {
        const title = typeof songItem.title === 'string' ? songItem.title : '未知歌曲'
        const artist = typeof songItem.singer === 'string' ? songItem.singer : '未知歌手'
        await this.avSessionController.updateMetadata(
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
      Logger.error(`${TAG}: AVSession init failed: ${JSON.stringify(e)}`)
    }
  }

  private updateIsPlay(isPlay: boolean): void {
    this.appState.isPlay = isPlay
    this.avSessionController.setPlayState(isPlay)
    AppStorage.setOrCreate('isPlay', isPlay)
  }

  public syncPlaybackStatus(status: string, message: string): void {
    this.appState.playbackStatus = status
    this.appState.playbackStatusMessage = message
    AppStorage.setOrCreate('playbackStatus', status)
    AppStorage.setOrCreate('playbackStatusMessage', message)
  }
}

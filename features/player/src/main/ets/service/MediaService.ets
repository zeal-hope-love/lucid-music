/*
 * MediaService - 媒体播放服务（单例）
 */
import { Logger, getAppRuntime, AppRuntimeStorage } from 'musicbasic'

const TAG = 'MediaService'

export class MediaService {
  private static instance: MediaService | null = null
  private isActive: boolean = false

  public static getInstance(): MediaService {
    if (!MediaService.instance) {
      MediaService.instance = new MediaService()
    }
    return MediaService.instance
  }

  /**
   * 应用进入后台时调用，处理后台音频播放策略
   */
  public onApplicationBackground(): void {
    Logger.info(`${TAG}: onApplicationBackground`)
    try {
      this.isActive = true
      // 预留：后台音频播放保活策略
      // AVSession / background task / long-term task
    } catch (e) {
      Logger.error(`${TAG}: onApplicationBackground error ${JSON.stringify(e)}`)
    }
  }

  /**
   * 应用回到前台时调用
   */
  public onApplicationForeground(): void {
    Logger.info(`${TAG}: onApplicationForeground`)
    this.isActive = false
  }
}

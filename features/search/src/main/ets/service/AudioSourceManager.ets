/*
 * AudioSourceManager - 音频源管理器（单例）
 */
import { common } from '@kit.AbilityKit'
import { Logger } from 'musicbasic'

const TAG = 'AudioSourceManager'

export class AudioSourceManager {
  private static instance: AudioSourceManager | null = null

  public static getInstance(): AudioSourceManager {
    if (!AudioSourceManager.instance) {
      AudioSourceManager.instance = new AudioSourceManager()
    }
    return AudioSourceManager.instance
  }

  public init(context: common.UIAbilityContext): void {
    Logger.info(`${TAG}: init`)
  }
}

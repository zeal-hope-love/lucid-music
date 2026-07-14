/*
 * Lucid Music - 媒体工具类
 */
import { Logger } from 'musicbasic'

const TAG = 'MediaTools'

export class MediaTools {
  private static fill(value: number): string {
    return value.toString().padStart(2, '0')
  }

  /** 毫秒 → mm:ss 格式 */
  static msToCountdownTime(ms: number): string {
    if (!ms || ms <= 0) {
      return '00:00'
    }
    const totalSeconds = Math.floor(ms / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${MediaTools.fill(minutes)}:${MediaTools.fill(seconds)}`
  }
}

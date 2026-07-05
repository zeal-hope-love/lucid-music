/*
 * AudioSourceExecutor - 音频源执行器
 */
import { Logger } from 'musicbasic'

const TAG = 'AudioSourceExecutor'

export class AudioSourceExecutor {
  public async execute(sourceId: string, params: Record<string, Object>): Promise<Object | null> {
    Logger.info(`${TAG}: execute source=${sourceId}`)
    return null
  }
}

/*
 * AudioSourceExecutor - 音源执行器
 * 通过 JsVmBridge 调用 C++ JSVM 引擎执行 LX Music 音源脚本获取播放 URL
 */
import { JsVmBridge } from 'player'
import { Logger } from 'musicbasic'

const TAG = 'AudioSourceExecutor'

export interface ExecutorPlayResult {
  url: string
  lyrics: string
  cover: string
}

export class AudioSourceExecutor {
  private static instance: AudioSourceExecutor | undefined
  private bridge: JsVmBridge = JsVmBridge.getInstance()

  public static getInstance(): AudioSourceExecutor {
    if (!AudioSourceExecutor.instance) {
      AudioSourceExecutor.instance = new AudioSourceExecutor()
    }
    return AudioSourceExecutor.instance
  }

  /**
   * 通过 JSVM 音源脚本获取播放 URL
   * @returns 播放 URL，引擎未就绪或脚本未初始化时返回 null
   */
  public async getPlayUrl(songId: string, source: string): Promise<ExecutorPlayResult | null> {
    const engineReady = this.bridge.isEngineReady()
    const scriptInited = this.bridge.isScriptInited()
    if (!engineReady || !scriptInited) {
      Logger.warn(`${TAG}: getPlayUrl not ready - engineReady=${engineReady}, scriptInited=${scriptInited}, songId=${songId}, source=${source}`)
      return null
    }
    try {
      const params: Record<string, Object> = {
        'hash': songId as Object, 'source': source as Object, 'type': '128k' as Object
      }
      const result = await this.bridge.sendRequest(source, 'musicUrl', params)
      if (!result) {
        Logger.warn(`${TAG}: sendRequest returned null/undefined for songId=${songId}, source=${source}`)
        return null
      }
      Logger.info(`${TAG}: sendRequest result keys=[${Object.keys(result).join(',')}], url=${(result.url || '').substring(0, 100)}, dataKeys=[${result.data ? Object.keys(result.data).join(',') : 'N/A'}]`)
      return {
        url: result.url || (result.data?.['url'] as string) || '',
        lyrics: (result.data?.['lyrics'] as string) || (result.data?.['lyric'] as string) || '',
        cover: (result.data?.['cover'] as string) || (result.data?.['pic'] as string) || ''
      }
    } catch (e) {
      Logger.error(`${TAG}: getPlayUrl error ${JSON.stringify(e)}`)
      return null
    }
  }

  /**
   * 检查引擎是否可用于请求
   */
  public isAvailable(): boolean {
    return this.bridge.isEngineReady() && this.bridge.isScriptInited()
  }
}

/*
 * JsVmBridge - JSVM 音源脚本引擎桥接层
 * 包装 AudioEngine（C++ JSVM），提供脚本执行和音频 URL 获取
 */
import { AudioEngine } from 'jsaudioengine'
import { Logger } from 'musicbasic'

const TAG = 'JsVmBridge'

export interface ScriptRequestResult {
  source?: string
  action?: string
  data?: Record<string, Object>
  url?: string
}

export class JsVmBridge {
  private static instance: JsVmBridge | null = null
  private engine: AudioEngine = AudioEngine.getInstance()

  public static getInstance(): JsVmBridge {
    if (!JsVmBridge.instance) {
      JsVmBridge.instance = new JsVmBridge()
    }
    return JsVmBridge.instance
  }

  /**
   * 初始化 C++ JSVM 音频引擎
   */
  public async init(): Promise<void> {
    try {
      Logger.info(`${TAG}: init`)
      await this.engine.init()
      Logger.info(`${TAG}: init done, ready=${this.engine.isReady()}`)
    } catch (e) {
      Logger.error(`${TAG}: init error ${JSON.stringify(e)}`)
    }
  }

  /**
   * 执行音源脚本并等待初始化完成
   */
  public async executeScript(script: string, id: string): Promise<boolean> {
    Logger.info(`${TAG}: executeScript id=${id}, len=${script.length}`)
    return await this.engine.executeScript(script, id)
  }

  /**
   * 向音源脚本发送请求（如获取播放 URL）
   * @param source 平台标识 (kg/tx/wy/kw/mg)
   * @param action 动作 (musicUrl)
   * @param info 请求参数 { hash, source, type }
   */
  public async sendRequest(source: string, action: string, info: Record<string, Object>): Promise<ScriptRequestResult | null> {
    Logger.info(`${TAG}: sendRequest source=${source} action=${action}`)
    const result = await this.engine.sendRequestToScript(source, action, info)
    if (!result) {
      Logger.warn(`${TAG}: sendRequest returned null for ${source}/${action}`)
      return null
    }
    const r = result as Record<string, Object>
    const res: ScriptRequestResult = {
      source: r['source'] as string,
      action: r['action'] as string,
      data: r['data'] as Record<string, Object>,
      url: r['url'] as string
    }
    Logger.info(`${TAG}: sendRequest result hasUrl=${res.url ? true : false}`)
    return res
  }

  public isEngineReady(): boolean {
    return this.engine.isReady()
  }

  public isScriptInited(): boolean {
    return this.engine.isScriptInited()
  }
}

/*
 * JsVmBridge - JS 与 C++ 音频引擎之间的通信桥接
 */
import { Logger } from 'musicbasic'


const TAG = 'JsVmBridge'

export class JsVmBridge {
  private static instance: JsVmBridge | null = null

  public static getInstance(): JsVmBridge {
    if (!JsVmBridge.instance) {
      JsVmBridge.instance = new JsVmBridge()
    }
    return JsVmBridge.instance
  }

  /**
   * 初始化 JS 音频引擎虚拟机桥接
   */
  public init(): void {
    try {
      Logger.info(`${TAG}: init`)
      // 预留：初始化 native 音频引擎通信通道
      // jsaudioengine.initEngine()
    } catch (e) {
      Logger.error(`${TAG}: init error ${JSON.stringify(e)}`)
    }
  }
}

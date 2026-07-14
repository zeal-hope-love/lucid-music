/*
 * LoggerAdapter - 适配 avplayer Logger 调用风格到 musicbasic Logger
 * avplayer: Logger.info(TAG, message)
 * lucid_music: Logger.info(`TAG: message`)
 */
import { Logger } from 'musicbasic'

class LoggerAdapter {
  public static info(tag: string, ...args: string[]): void {
    Logger.info(`${tag}: ${args.join('')}`)
  }
  public static error(tag: string, ...args: string[]): void {
    Logger.error(`${tag}: ${args.join('')}`)
  }
  public static warn(tag: string, ...args: string[]): void {
    Logger.warn(`${tag}: ${args.join('')}`)
  }
  public static debug(tag: string, ...args: string[]): void {
    Logger.debug(`${tag}: ${args.join('')}`)
  }
}

export default LoggerAdapter

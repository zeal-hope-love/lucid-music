/*
 * mg/lyric.ets - 咪咕音乐歌词（占位，咪咕歌词需登录态，暂返回空）
 */
import { Logger } from 'musicbasic'

const TAG = 'MgMusicApi'

export async function getLyrics(songId: string): Promise<string> {
  // 咪咕歌词接口需登录态签名，公开端点不稳定；保持返回空字符串
  Logger.info(TAG, `mg getLyrics: 暂不支持公开歌词获取 songId=${songId}`)
  return ''
}

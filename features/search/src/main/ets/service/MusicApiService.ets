/*
 * MusicApiService - 音乐 API 服务
 */
import { Logger, SongApiDto } from 'musicbasic'

const TAG = 'MusicApiService'

export class MusicApiService {
  /**
   * 搜索歌曲（占位实现）
   */
  public static async searchSongs(keyword: string): Promise<SongApiDto[]> {
    Logger.info(`${TAG}: searchSongs keyword=${keyword}`)
    return []
  }
}

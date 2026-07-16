/*
 * PlaybackIntentDispatcher - 播放意图分发器
 */
import {
  Logger, MusicAppState, PlaybackIntentState, SongItem,
  PlaybackIntentLogEvent, PlaybackShellConstants
} from 'musicbasic'
import { AudioPlayerController } from '../controller/AudioPlayerController'

const TAG = 'PlaybackIntentDispatcher'

/**
 * 播放意图分发：当 PlaybackIntentState 变化时，更新 MusicAppState 并触发回调
 * @param appState 全局播放状态
 * @param intentState 播放意图状态
 * @param onOpenPlayerUi 打开全屏播放器 UI 的回调
 */
export async function dispatchShellPlaybackIntent(
  appState: MusicAppState,
  intentState: PlaybackIntentState,
  onOpenPlayerUi: () => void
): Promise<void> {
  Logger.info(`${TAG}: dispatchShellPlaybackIntent version=${intentState.requestVersion}`)

  try {
    // 处理远程播放（搜索结果、音源等外部来源）
    if (intentState.remoteUrl || intentState.remoteSongName) {
      Logger.info(`${TAG}: remote playback - url=${intentState.remoteUrl}, name=${intentState.remoteSongName}`)
      const songItem = new SongItem()
      songItem.id = -Date.now()  // 负数 ID 区分远程歌曲
      songItem.title = intentState.remoteSongName || '未知歌曲'
      songItem.singer = intentState.remoteSongSinger || '未知歌手'
      songItem.src = intentState.remoteUrl || ''
      songItem.coverUrl = intentState.remoteSongCover || ''
      songItem.lyricText = intentState.remoteLyricText || ''
      appState.remoteSongItem = songItem
      intentState.resetRemote()

      // 有播放地址则触发播放
      if (songItem.src) {
        await AudioPlayerController.getInstance().playCurrent()
      }
    }

    // 处理本地歌曲播放
    if (intentState.pendingPlaySongId >= 0) {
      const index = appState.playQueueIds.indexOf(intentState.pendingPlaySongId)
      if (index >= 0) {
        appState.selectIndex = index
        Logger.info(`${TAG}: song found in queue at index=${index}`)
      }
      intentState.pendingPlaySongId = -1
    }

    // 打开全屏播放器 UI
    if (intentState.openPlayerUi) {
      Logger.info(`${TAG}: openPlayerUi`)
      intentState.openPlayerUi = false
      onOpenPlayerUi()
    }
  } catch (e) {
    Logger.error(`${TAG}: dispatch error ${JSON.stringify(e)}`)
  }
}

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
    // 处理本地歌曲队列切换（来自 SongListPage 等公共组件的播放请求）
    if (intentState.pendingQueueIds.length > 0) {
      const queueIds = [...intentState.pendingQueueIds]
      const selectIndex = intentState.pendingSelectIndex
      intentState.pendingQueueIds = []
      intentState.pendingSelectIndex = 0
      appState.playQueueIds = queueIds
      appState.selectIndex = selectIndex
      AudioPlayerController.getInstance().syncStateForNewSong()
      appState.isPlay = true
      await AudioPlayerController.getInstance().playCurrent()
      Logger.info(`${TAG}: playSongAt queueLen=${queueIds.length} index=${selectIndex}`)
    }

    // 处理远程播放（搜索结果、音源等外部来源）
    if (intentState.remoteUrl || intentState.remoteSongName) {
      const urlPreview = intentState.remoteUrl ? intentState.remoteUrl.substring(0, 100) : '<empty>'
      const urlLen = intentState.remoteUrl ? intentState.remoteUrl.length : 0
      Logger.info(`${TAG}: remote playback - urlPreview=${urlPreview}, urlLen=${urlLen}, name=${intentState.remoteSongName}`)
      const songItem = new SongItem()
      songItem.id = -Date.now()  // 负数 ID 区分远程歌曲
      songItem.title = intentState.remoteSongName || '未知歌曲'
      songItem.singer = intentState.remoteSongSinger || '未知歌手'
      songItem.src = intentState.remoteUrl || ''
      songItem.coverUrl = intentState.remoteSongCover || ''
      songItem.lyricText = intentState.remoteLyricText || ''
      Logger.info(`${TAG}: songItem built: coverUrl=${songItem.coverUrl.substring(0, 50)}, lyricLen=${songItem.lyricText.length}`)
      appState.remoteSongItem = songItem
      intentState.resetRemote()
      AudioPlayerController.getInstance().syncStateForNewSong()

      // 有播放地址则触发播放
      if (songItem.src) {
        appState.isPlay = true
        await AudioPlayerController.getInstance().playCurrent()
      } else {
        // 无播放地址：停止旧播放、清理媒体中心、设错误状态
        Logger.warn(`${TAG}: remote url is empty, stopping playback`)
        appState.isPlay = false
        AppStorage.setOrCreate('isPlay', false)
        AudioPlayerController.getInstance().pause()
        AudioPlayerController.getInstance().syncPlaybackStatus('error', '获取播放地址失败')
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

/*
 * PlaybackIntentDispatcher - 播放意图分发器
 */
import {
  Logger, MusicAppState, PlaybackIntentState, SongItem, MusicDbApi,
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
    // 处理队列切换（歌单内点歌：本地/自建/收藏/在线歌单，队列=该歌单全部歌曲）
    if (intentState.pendingQueue.length > 0) {
      const queue = [...intentState.pendingQueue]
      const selectIndex = intentState.pendingSelectIndex
      intentState.pendingQueue = []
      intentState.pendingSelectIndex = 0
      appState.playQueue = queue
      appState.selectIndex = (selectIndex >= 0 && selectIndex < queue.length) ? selectIndex : 0
      AudioPlayerController.getInstance().syncStateForNewSong()
      // 应用当前歌单标题（点击歌单内歌曲后切换为当前歌单）
      if (intentState.pendingPlaylistTitle) {
        appState.currentPlaylistTitle = intentState.pendingPlaylistTitle
        AppStorage.setOrCreate('currentPlaylistTitle', appState.currentPlaylistTitle)
      }
      intentState.pendingPlaylistTitle = ''
      appState.isPlay = true
      await AudioPlayerController.getInstance().playCurrent()
      Logger.info(`${TAG}: queue switched len=${queue.length} index=${appState.selectIndex}`)
    }

    // 处理远程单曲播放（搜索结果等非歌单来源）：加入最近播放，队列切换为“最近播放”
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
      // 补上平台与远程 ID：使 playCurrent 判定为在线歌并触发磁盘缓存落盘（cacheKey=platform_remoteSongId）
      songItem.platform = intentState.remotePlatform || ''
      songItem.remoteSongId = intentState.remoteSongId || ''
      Logger.info(`${TAG}: songItem built: coverUrl=${songItem.coverUrl.substring(0, 50)}, lyricLen=${songItem.lyricText.length}, platform=${songItem.platform}, remoteId=${songItem.remoteSongId}`)
      intentState.resetRemote()

      const hasTitle = intentState.pendingPlaylistTitle !== ''
      const title = hasTitle ? intentState.pendingPlaylistTitle : '最近播放'
      intentState.pendingPlaylistTitle = ''

      if (songItem.src) {
        // 加入最近播放，并把队列切换为最近播放列表（新歌位于首位）
        MusicDbApi.getInstance().addRecentPlay(songItem)
        appState.playQueue = [...MusicDbApi.getInstance().getRecentPlaySongs()]
        appState.selectIndex = 0
        appState.currentPlaylistTitle = title
        AppStorage.setOrCreate('currentPlaylistTitle', title)
        AudioPlayerController.getInstance().syncStateForNewSong()
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

    // 处理播放列表弹层内点击切歌（按队列索引）
    if (intentState.pendingPlayIndex >= 0) {
      const index = intentState.pendingPlayIndex
      if (index < appState.getQueueLength()) {
        appState.selectIndex = index
        AudioPlayerController.getInstance().syncStateForNewSong()
        appState.isPlay = true
        await AudioPlayerController.getInstance().playCurrent()
        Logger.info(`${TAG}: switch to queue index=${index}`)
      }
      intentState.pendingPlayIndex = -1
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
